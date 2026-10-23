package markit.core.session

import markit.core.nodes.{DocumentNode, Node, TextNode}
import markit.core.source.{LineIndex, SourceBuffer, SourceLine, SourceSpan}
import markit.core.editing.IncrementalParserContext
import std.collection.ArrayList

public class ParseSession {
    public let source: SourceBuffer
    public let options: ParseOptions
    public let symbolTables: SessionSymbolTableStore
    private var sessionRoot: Node
    public prop root: Node { get() { return sessionRoot } }
    public let lineIndex = LineIndex()
    private var sessionPatches = SessionPatchQueue()
    public prop patches: SessionPatchQueue { get() { return sessionPatches } }
    public var editingContext: ?IncrementalParserContext = None
    public let pendingParagraphLines = ArrayList<SourceLine>()
    public var finalized: Bool = false
    private var activeLine: ?SourceLine = None
    private var paragraphSpan: ?SourceSpan = None
    private var nextId: Int64 = 1
    private var detachedParseDepth: Int64 = 0
    private var topLevelIndentedBlockStartsAllowed: Bool = false
    private var detachedBlockParser: ?(ArrayList<SourceLine>) -> ArrayList<Node> = None
    private var sandboxDetachedStates: Bool = false
    private var registeredBlockStartDetector: ?(ParseSession, String) -> Bool = None
    private var sandboxRegisteredDetector: Bool = false
    private var paragraphNodeFactory: ?(ArrayList<SourceLine>, SourceSpan, ParagraphTermination) -> Node = None
    private var inlineParser: ?(ParseSession, String, SourceSpan) -> ArrayList<Node> = None
    private var inlineRangeParser: ?(ParseSession, String, Int64, Int64, SourceSpan) -> ArrayList<Node> = None

    public ParseSession(
        source: SourceBuffer,
        options: ParseOptions,
        symbolTables: SessionSymbolTableStore
    ) {
        this.source = source
        this.options = options
        this.symbolTables = symbolTables
        this.sessionRoot = DocumentNode(source)
    }

    public func allocateNodeId(): Int64 {
        let id = nextId
        nextId += 1
        return id
    }

    public prop nextNodeId: Int64 { get() { return nextId } }
    public prop supportsCompleteCheckpoint: Bool { get() { return symbolTables.supportsCheckpoint } }

    // Old checkpoints may precede reused suffix nodes. The edit engine raises
    // this high-water mark before parsing so new nodes cannot reuse their IDs.
    public func setNextNodeIdForEditing(next: Int64): Unit {
        if (next < 1 || next < nextId) { throw IllegalArgumentException("Node ID high-water mark cannot decrease") }
        nextId = next
    }

    public func checkpoint(): ParseSessionCheckpoint {
        let symbols = symbolTables.checkpoint()
        return ParseSessionCheckpoint(this,
            syntaxCheckpoint(detachEditingRoot: editingContext.isSome()), symbols)
    }

    // The persistent published tree owns editing syntax. Drop only the legacy
    // scratch graph after capture; retain lexical state, source and allocator.
    public func releaseEditingWorkspace(): Unit {
        if (editingContext.isNone()) { throw IllegalArgumentException("Cannot release a legacy parsing workspace") }
        sessionRoot = emptyWorkingRoot()
        sessionPatches = SessionPatchQueue()
    }

    public func restoreCheckpoint(checkpoint: ParseSessionCheckpoint): Bool {
        if (!refEq(checkpoint.scope, this)) { return false }
        // Legacy root recovery is an append cursor, not a graph snapshot. A
        // later cursor cannot recreate children already removed by a rewind.
        if (checkpoint.syntax.root.children.size < checkpoint.syntax.rootChildCount) { return false }
        // Prepare all provider states first; refusal/throw cannot partially
        // publish one restored state alongside another live state.
        if (!symbolTables.restore(checkpoint.symbols)) { return false }
        restoreSyntax(checkpoint.syntax)
        return true
    }

    // Editing snapshots own an immutable persistent syntax tree outside this
    // legacy scratch root. Re-entering an old recovery point must not truncate
    // that point's shared root or destroy a later checkpoint's siblings.
    public func restoreEditingCheckpoint(checkpoint: ParseSessionCheckpoint,
        remapLine!: ?(SourceLine, Bool) -> SourceLine = None): Bool {
        if (!refEq(checkpoint.scope, this)) { return false }
        let currentEditingContext = editingContext
        // Mapping is a pure preflight. Complete every callback and validation
        // before restoring any provider state or publishing local geometry.
        let prepared = if (let Some(mapper) <- remapLine) {
            checkpoint.syntax.remapLines(mapper)
        } else { checkpoint.syntax }
        if (!symbolTables.restore(checkpoint.symbols)) { return false }
        restoreSyntax(prepared, restoreRootChildren: false)
        // Persistent unit checkpoints do not own a previous transaction's
        // context. The caller supplies the current borrowed participant.
        editingContext = currentEditingContext
        sessionRoot = emptyWorkingRoot()
        sessionPatches = SessionPatchQueue()
        return true
    }

    // A real parser candidate runs once. Editing providers read prior syntax
    // through their persistent context; their scratch root is never published.
    public func parserAttempt<T>(attempt: () -> ?T): ?T {
        if (editingContext.isNone()) { return attempt() }
        let saved = syntaxCheckpoint()
        let sandbox = symbolTables.beginLazySandbox()
        var transactionScope: ?ParseSessionTransactionScope = None
        var accepted = false
        try {
            transactionScope = beginTransactionScope()
            sessionRoot = DocumentNode(source)
            sessionPatches = SessionPatchQueue()
            let result = attempt()
            accepted = result.isSome()
            return result
        } finally {
            var keepResults = accepted
            try {
                if (let Some(scope) <- transactionScope) {
                    try { scope.complete(accepted) }
                    catch (error: Exception) {
                        keepResults = false
                        if (accepted) { scope.complete(false) }
                        throw error
                    }
                }
            } finally {
                if (keepResults) {
                    symbolTables.commitSandbox(sandbox)
                    let candidatePatches = sessionPatches
                    sessionRoot = saved.root
                    sessionPatches = saved.patchQueue
                    for (node in candidatePatches.drainReplaceNodes()) { sessionPatches.replace(node) }
                    for (node in candidatePatches.drainRemoveNodes()) { sessionPatches.remove(node) }
                    editingContext = saved.editingContext
                } else {
                    symbolTables.endSandbox(sandbox)
                    restoreSyntax(saved)
                }
            }
        }
    }

    public func sandboxProbe(probe: () -> Bool): Bool {
        let saved = syntaxCheckpoint()
        let sandbox = symbolTables.beginLazySandbox()
        var transactionScope: ?ParseSessionTransactionScope = None
        try {
            transactionScope = beginTransactionScope()
            // No probe may publish nodes by appending to the live legacy root.
            // Actual syntax units are committed by the editing tree transaction.
            sessionRoot = DocumentNode(source)
            sessionPatches = SessionPatchQueue()
            return probe()
        } finally {
            try {
                if (let Some(scope) <- transactionScope) { scope.complete(false) }
            } finally {
                symbolTables.endSandbox(sandbox)
                restoreSyntax(saved)
            }
        }
    }

    public func beginLine(line: SourceLine): Unit {
        activeLine = Some(line)
    }

    public func recordSourceLine(line: SourceLine): Unit {
        if (!lineIndex.isEditableView) { lineIndex.add(line) }
    }

    public func currentLineSpan(): SourceSpan {
        return currentSourceLine().span
    }

    public func currentSourceLine(): SourceLine {
        return activeLine.getOrThrow()
    }

    public func addPendingParagraphLine(line: SourceLine): Unit {
        pendingParagraphLines.add(line)
        paragraphSpan = match (paragraphSpan) {
            case Some(span) => Some(span.merge(line.span))
            case None => Some(line.span)
        }
    }

    public func pendingParagraphSourceSpan(): SourceSpan {
        return paragraphSpan ?? currentLineSpan()
    }

    public func clearPendingParagraph(): Unit {
        pendingParagraphLines.clear()
        paragraphSpan = None
    }

    public func createNode(
        kind: String,
        literal!: String = "",
        level!: Int64 = 0,
        slug!: String = "",
        info!: String = ""
    ): Node {
        return attachNode(Node(
            kind,
            id: allocateNodeId(),
            sourceSpan: currentLineSpan(),
            literal: literal,
            level: level,
            slug: slug,
            info: info
        ))
    }

    public func createNodeWithSpan(
        kind: String,
        sourceSpan: SourceSpan,
        literal!: String = "",
        level!: Int64 = 0,
        slug!: String = "",
        info!: String = ""
    ): Node {
        return attachNode(Node(
            kind,
            id: allocateNodeId(),
            sourceSpan: sourceSpan,
            literal: literal,
            level: level,
            slug: slug,
            info: info
        ))
    }

    public func createTextNode(content: String, sourceSpan: SourceSpan): TextNode {
        return attachNode(TextNode(
            allocateNodeId(),
            sourceSpan,
            content
        ))
    }

    public func attachNode<T>(node: T): T where T <: Node {
        node.attachSource(source)
        return node
    }

    public func setDetachedBlockParser(parser: (ArrayList<SourceLine>) -> ArrayList<Node>,
        sandboxedStates!: Bool = false): Unit {
        detachedBlockParser = Some(parser)
        sandboxDetachedStates = sandboxedStates
    }

    public func parseDetachedLines(lines: ArrayList<SourceLine>): ArrayList<Node> {
        if (let Some(parser) <- detachedBlockParser) {
            let saved = syntaxCheckpoint()
            let isolate = sandboxDetachedStates || editingContext.isSome()
            let sandbox: ?SessionSymbolTableSandbox = if (isolate) {
                Some(symbolTables.beginLazySandbox())
            } else { Option<SessionSymbolTableSandbox>.None }
            var transactionScope: ?ParseSessionTransactionScope = None
            var completed = false
            try {
                if (isolate) {
                    transactionScope = beginTransactionScope()
                    sessionRoot = DocumentNode(source)
                    sessionPatches = SessionPatchQueue()
                    // Editing providers own an independent paragraph context.
                    clearPendingParagraph()
                    activeLine = None
                }
                detachedParseDepth += 1
                let nodes = parser(lines)
                completed = true
                return nodes
            } finally {
                var keepResults = completed
                try {
                    if (let Some(scope) <- transactionScope) {
                        try { scope.complete(completed) }
                        catch (error: Exception) {
                            keepResults = false
                            // A failing participant must leave its unpublished
                            // scope rollback-capable. Local cleanup still runs
                            // even if that rollback also refuses.
                            if (completed) { scope.complete(false) }
                            throw error
                        }
                    }
                } finally {
                    if (let Some(stateSandbox) <- sandbox) {
                        if (keepResults) { symbolTables.commitSandbox(stateSandbox)
                        } else { symbolTables.endSandbox(stateSandbox) }
                    }
                    if (!isolate && keepResults) {
                        // Legacy parsers historically retain successful nested
                        // active-line and paragraph side effects. Only depth is
                        // scoped here; editing providers explicitly isolate them.
                        detachedParseDepth = saved.depth
                    } else {
                        // Successful editing IDs and owned patch records join
                        // the parent transaction; failures restore outer syntax.
                        restoreSyntax(saved, keepAllocatedIds: keepResults, keepPatches: keepResults)
                    }
                }
            }
        }
        return ArrayList<Node>()
    }

    public func allowDeepIndentedBlockStart(): Bool {
        return detachedParseDepth > 0 || topLevelIndentedBlockStartsAllowed
    }

    public func setTopLevelIndentedBlockStartsAllowed(allowed: Bool): Unit {
        topLevelIndentedBlockStartsAllowed = allowed
    }

    public func setRegisteredBlockStartDetector(detector: (ParseSession, String) -> Bool,
        sandboxed!: Bool = false): Unit {
        registeredBlockStartDetector = Some(detector)
        sandboxRegisteredDetector = sandboxed
    }

    public func startsRegisteredBlock(line: String): Bool {
        if (let Some(detector) <- registeredBlockStartDetector) {
            if (sandboxRegisteredDetector) {
                return sandboxProbe({ =>
                    detachedParseDepth += 1
                    detector(this, line)
                })
            }
            detachedParseDepth += 1
            try { return detector(this, line) } finally { detachedParseDepth -= 1 }
        }
        return false
    }

    private func syntaxCheckpoint(detachEditingRoot!: Bool = false): ParseSessionSyntaxCheckpoint {
        let patchSnapshot = patches.snapshot()
        let checkpointQueue = if (detachEditingRoot) {
            let detached = SessionPatchQueue()
            detached.restore(patchSnapshot)
            detached
        } else { sessionPatches }
        let checkpointRoot = if (detachEditingRoot) { emptyWorkingRoot() } else { sessionRoot }
        let checkpointContext: ?IncrementalParserContext = if (detachEditingRoot) {
            Option<IncrementalParserContext>.None
        } else { editingContext }
        return ParseSessionSyntaxCheckpoint(activeLine, paragraphSpan, pendingParagraphLines.toArray(),
            nextId, detachedParseDepth, topLevelIndentedBlockStartsAllowed, finalized,
            patchSnapshot, checkpointQueue, lineIndex.snapshot(), checkpointRoot,
            checkpointRoot.children.size, checkpointContext)
    }

    private func emptyWorkingRoot(): Node {
        let empty = DocumentNode(source)
        sessionRoot.copyBaseTo(empty)
        return empty
    }

    private func restoreSyntax(saved: ParseSessionSyntaxCheckpoint,
        keepAllocatedIds!: Bool = false, keepPatches!: Bool = false,
        restoreRootChildren!: Bool = true): Unit {
        activeLine = saved.activeLine
        paragraphSpan = saved.paragraphSpan
        pendingParagraphLines.clear()
        for (line in saved.pending) { pendingParagraphLines.add(line) }
        if (!keepAllocatedIds) { nextId = saved.nextNodeId }
        detachedParseDepth = saved.depth
        topLevelIndentedBlockStartsAllowed = saved.indentedStarts
        finalized = saved.finalized
        sessionRoot = saved.root
        if (restoreRootChildren && !keepAllocatedIds) {
            while (sessionRoot.children.size > saved.rootChildCount) {
                let removed = sessionRoot.children.remove(at: sessionRoot.children.size - 1)
                removed.parent = None
            }
        }
        let nestedPatches = sessionPatches
        sessionPatches = saved.patchQueue
        if (keepPatches) {
            if (!refEq(nestedPatches, sessionPatches)) {
                for (node in nestedPatches.drainReplaceNodes()) { sessionPatches.replace(node) }
                for (node in nestedPatches.drainRemoveNodes()) { sessionPatches.remove(node) }
            }
        } else { sessionPatches.restore(saved.patches) }
        editingContext = saved.editingContext
        lineIndex.restore(saved.lines)
    }

    private func beginTransactionScope(): ?ParseSessionTransactionScope {
        if (let Some(context) <- editingContext) {
            if (let participant: ParseSessionTransactionParticipant <- context) {
                return Some(participant.beginSessionScope())
            }
            throw IllegalArgumentException("Editing context has no transactional sandbox scope")
        }
        return None
    }

    public func setParagraphNodeFactory(
        factory: (ArrayList<SourceLine>, SourceSpan, ParagraphTermination) -> Node
    ): Unit {
        paragraphNodeFactory = Some(factory)
    }

    public func createParagraphNode(
        lines: ArrayList<SourceLine>,
        sourceSpan: SourceSpan,
        termination: ParagraphTermination
    ): Node {
        if (let Some(factory) <- paragraphNodeFactory) {
            return factory(lines, sourceSpan, termination)
        }
        let parts = ArrayList<String>()
        for (line in lines) {
            parts.add(line.text)
        }
        return createNodeWithSpan("Paragraph", sourceSpan, literal: String.join(parts.toArray(), delimiter: "\n"))
    }

    public func setInlineParser(parser: (ParseSession, String, SourceSpan) -> ArrayList<Node>): Unit {
        inlineParser = Some(parser)
    }

    public func setInlineRangeParser(parser: (ParseSession, String, Int64, Int64, SourceSpan) -> ArrayList<Node>): Unit {
        inlineRangeParser = Some(parser)
    }

    public func parseInline(text: String, sourceSpan: SourceSpan): ArrayList<Node> {
        if (let Some(parser) <- inlineParser) {
            return parser(this, text, sourceSpan)
        }

        let nodes = ArrayList<Node>()
        if (!text.isEmpty()) {
            nodes.add(createTextNode(text, sourceSpan))
        }
        return nodes
    }

    public func parseInlineRange(text: String, startByte: Int64, endByte: Int64, sourceSpan: SourceSpan): ArrayList<Node> {
        if (let Some(parser) <- inlineRangeParser) {
            return parser(this, text, startByte, endByte, sourceSpan)
        }
        if (startByte == 0 && endByte == text.size) {
            return parseInline(text, sourceSpan)
        }

        let nodes = ArrayList<Node>()
        if (startByte < endByte) {
            nodes.add(createTextNode(text[startByte..endByte], sourceSpan))
        }
        return nodes
    }

    public func appendInlineChildren(parent: Node, text: String, sourceSpan: SourceSpan): Unit {
        for (child in parseInline(text, sourceSpan)) {
            parent.addChild(child)
        }
    }

    public func appendInlineChildrenRange(parent: Node, text: String, startByte: Int64, endByte: Int64, sourceSpan: SourceSpan): Unit {
        for (child in parseInlineRange(text, startByte, endByte, sourceSpan)) {
            parent.addChild(child)
        }
    }
}
