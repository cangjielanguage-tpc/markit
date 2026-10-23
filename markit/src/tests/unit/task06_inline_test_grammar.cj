package markit.tests.unit

import std.collection.ArrayList
import markit.core.block.BlockEditingContext
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.*
import markit.core.session.ParseSession
import markit.core.source.{SourceBuffer, SourceSpan}

// Delimiters exist only in this deliberately small test provider. Both public
// parser paths below call the same byte-reader implementation.
private func task06ReadText(read: (Int64) -> ?Byte, start: Int64, end: Int64): String {
    let bytes = ArrayList<Byte>()
    for (i in start..end) { bytes.add(read(i).getOrThrow()) }
    return String.fromUtf8(bytes.toArray())
}
private func task06RuneCount(read: (Int64) -> ?Byte, start: Int64, end: Int64): Int64 {
    var count: Int64 = 0
    for (i in start..end) { let byte = read(i).getOrThrow(); if (byte < 128 || byte >= 192) { count += 1 } }
    return count
}
private func task06Escaped(read: (Int64) -> ?Byte, start: Int64): Bool {
    var at = start; var slashes: Int64 = 0
    while (at > 0) {
        at -= 1
        if (read(at).getOrThrow() != 92) { break }
        slashes += 1
    }
    return slashes % 2 == 1
}
private func task06Match(read: (Int64) -> ?Byte, length: () -> Int64,
    lookup: (String) -> ?String,
    makeNode: (String, Int64, Int64, Int64, ArrayList<Node>) -> Node,
    start: Int64): ?InlineParseResult {
    let first = read(start)
    if (first.isNone() || task06Escaped(read, start)) { return None }
    if (first.getOrThrow() == 36) {
        // A real metadata-only negative branch: do not read the nonexistent
        // suffix merely to manufacture a whole-owner character dependency.
        if (length() - start < 3) { return None }
        for (i in start..start + 3) { if (read(i).getOrThrow() >= 128) { return None } }
        let node = makeNode(task06ReadText(read, start, start + 3), start, start + 3, 3, ArrayList<Node>())
        return Some(InlineParseResult(node, 3, 3))
    }
    if (first.getOrThrow() != 64) { return None }
    let children = ArrayList<Node>()
    var cursor = start + 1
    let semantic = match (read(cursor)) { case Some(byte) => byte == 63; case None => false }
    if (semantic) { cursor += 1 }
    let bodyStart = cursor
    while (let Some(byte) <- read(cursor)) {
        if (byte == 59) {
            let body = task06ReadText(read, bodyStart, cursor)
            var label = body
            if (semantic) {
                if (let Some(value) <- lookup(body)) { label = value } else { return None }
            }
            let end = cursor + 1
            let runes = task06RuneCount(read, start, end)
            return Some(InlineParseResult(makeNode(label, start, end, runes, children), end - start, runes))
        }
        if (!semantic && byte == 64 && !task06Escaped(read, cursor)) {
            if (let Some(nested) <- task06Match(read, length, lookup, makeNode, cursor)) {
                children.add(nested.node); cursor += nested.consumedBytes; continue
            }
        }
        cursor += 1
    }
    return None
}

class Task06InlineNode <: Node {
    public Task06InlineNode(id: Int64, span: SourceSpan, public let label: String) {
        super("Task06Inline", id: id, sourceSpan: span, literal: label)
    }
}
class Task06InlineCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "task06-inline-node" } }
    public func accepts(node: Node): Bool { return node is Task06InlineNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        let typed = (node as Task06InlineNode).getOrThrow()
        return Task06InlineNode(typed.id, typed.sourceSpan, typed.label)
    }
}
private class Task06InlineBaseCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "task06-inline-base" } }
    public func accepts(node: Node): Bool { return node is DocumentNode || node is TextNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        if (node is DocumentNode) { return DocumentNode(SourceBuffer()) }
        if (let text: TextNode <- node) { return TextNode(text.id, text.sourceSpan, text.content) }
        throw IllegalArgumentException("Unknown test base node")
    }
}
func task06Codec(): NodeCodec {
    let codec = NodeCodec()
    codec.register(Task06InlineCodec()); codec.register(Task06InlineBaseCodec())
    return codec
}

private class Task06GrammarPayload <: IncrementalStatePayload {
    private let captured: Array<IncrementalReadDependency>
    public Task06GrammarPayload(reads: Array<IncrementalReadDependency>) { captured = reads.clone() }
    public prop reads: Array<IncrementalReadDependency> { get() { return captured.clone() } }
    public func clonePayload(): IncrementalStatePayload { return Task06GrammarPayload(captured) }
    public func fingerprint(): String {
        var result = "task06-grammar-v1"
        for (read in captured) { result += ":${read.owner}/${read.key}/${read.found}/${read.version}" }
        return result
    }
}

class Task06InlineGrammar <: InlineParser & InlineEditingFacet {
    public var editingCalls: Int64 = 0
    public var legacyCalls: Int64 = 0
    public var failProbe: Bool = false
    private var observedReads: Array<IncrementalReadDependency> = []
    public Task06InlineGrammar(public var legacyLookup!: ?(String) -> ?String = None,
        public var returnsText!: Bool = false) {}
    public prop name: String { get() { return "Task06InlineGrammar" } }
    public prop ownerPlugin: String { get() { return "task06-test" } }
    public prop priority: Int64 { get() { return 10 } }
    public prop startBytes: Array<Byte> { get() { return [64, 36] } }
    public prop owner: String { get() { return "task06-test" } }
    public prop grammarVersion: String { get() { return "task06-grammar-v1" } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(this) } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion,
            Task06GrammarPayload(observedReads), syntaxContext: grammarVersion))
    }
    public func restore(context: IncrementalParserContext, checkpoint: IncrementalCheckpoint): Bool {
        if (checkpoint.documentId != context.documentId || checkpoint.owner != owner ||
            checkpoint.sourceVersion > context.sourceVersion || checkpoint.syntaxContext != grammarVersion) { return false }
        if (let payload: Task06GrammarPayload <- checkpoint.payload) { observedReads = payload.reads; return true }
        return false
    }
    public func rollbackEffects(context: IncrementalParserContext, checkpoint: IncrementalCheckpoint): Bool {
        if (!restore(context, checkpoint)) { return false }
        return context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(previous: IncrementalCheckpoint, current: IncrementalCheckpoint): Bool {
        return previous.documentId == current.documentId && previous.owner == current.owner &&
            previous.syntaxContext == current.syntaxContext && previous.syntaxContext == grammarVersion &&
            (previous.payload is Task06GrammarPayload) && (current.payload is Task06GrammarPayload)
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> {
        let result = ArrayList<IncrementalReadDependency>()
        for (read in observedReads) { result.add(read) }
        return result
    }
    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64,
        baseSpan: SourceSpan): ?InlineParseResult {
        legacyCalls += 1
        let reader = { at: Int64 => if (at < 0 || at >= endByte) { Option<Byte>.None } else { Some(input[at]) } }
        return task06Match(reader, { => endByte }, { key: String =>
            if (let Some(lookup) <- legacyLookup) { lookup(key) } else { Option<String>.None }
        }, { label: String, begin: Int64, end: Int64, runes: Int64, children: ArrayList<Node> =>
            let runeStart = baseSpan.startRune + task06RuneCount(reader, startByte, begin)
            let span = SourceSpan(baseSpan.startByte + begin - startByte, baseSpan.startByte + end - startByte,
                runeStart, runeStart + runes)
            let id = session.allocateNodeId()
            let node: Node = if (returnsText) { session.attachNode(TextNode(id, span, label)) }
                else { session.attachNode(Task06InlineNode(id, span, label)) }
            node.setString("task06-label", label); node.setInt("task06-marker", 31); node.setBool("task06-parser-success", true)
            for (child in children) { node.addChild(child) }
            node
        }, startByte)
    }
    public func parseAttempt(context: InlineAttemptContext, startByte: Int64): ?InlineParseResult {
        editingCalls += 1
        try {
            let parsed = task06Match({ at: Int64 => context.readByteOrEnd(at) }, { => context.endByte },
                { key: String =>
                    if (let Some(effect) <- context.readSemantic(key)) {
                        if (let value: StringEffectPayload <- effect.payload) { Some(value.value) } else { Option<String>.None }
                    } else { Option<String>.None }
                }, { label: String, begin: Int64, end: Int64, _: Int64, children: ArrayList<Node> =>
                    let a = context.block.resolve(context.view.mapByte(begin, AnchorAffinity.Before).getOrThrow()).getOrThrow()
                    let b = context.block.resolve(context.view.mapByte(end, AnchorAffinity.After).getOrThrow()).getOrThrow()
                    let span = SourceSpan(a, b, context.block.source.coordinateAtByte(a).getOrThrow().runeOffset,
                        context.block.source.coordinateAtByte(b).getOrThrow().runeOffset)
                    let session = context.block.session
                    let id = session.allocateNodeId()
                    let node: Node = if (returnsText) { session.attachNode(TextNode(id, span, label)) }
                        else { session.attachNode(Task06InlineNode(id, span, label)) }
                    node.setString("task06-label", label); node.setInt("task06-marker", 31); node.setBool("task06-parser-success", true)
                    for (child in children) { node.addChild(child) }
                    node
                }, startByte)
            if (parsed.isNone() && failProbe) {
                let session = context.block.session
                let leaked = Node("Task06FailedProbe", id: session.allocateNodeId())
                session.root.addChild(leaked); session.patches.replace(leaked)
                context.block.writeState("task06-failed-probe", Task06GrammarPayload([]))
                context.block.effects.add(OwnedSemanticEffect(context.semanticOwner, "task06-failed-probe",
                    StringEffectPayload("must-rollback"), 0))
            }
            return parsed
        } finally { observedReads = context.evidence().dependencies }
    }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow { return task06Recovery(context) }
    public func leftContext(_: InlineAttemptContext, _: Int64): String { return "task06-context-v1" }
    public func rightContext(_: InlineAttemptContext, _: Int64): String { return "task06-context-v1" }
}

private func task06Recovery(context: InlineRecoveryContext): ?InlineRecoveryWindow {
    let change = context.change
    var start = change.startByte; var oldEnd = change.oldEndByte
    for (attempt in context.attempts) {
        if (attempt.readStart < start) { start = attempt.readStart }
        if (attempt.readEnd > oldEnd) { oldEnd = attempt.readEnd }
    }
    while (start > 0 && start < context.previous.byteLength &&
        context.previous.readByte(start) >= 128 && context.previous.readByte(start) < 192) { start -= 1 }
    let delta = change.newEndByte - change.oldEndByte
    var newEnd = oldEnd + delta
    if (newEnd < change.newEndByte) { newEnd = change.newEndByte }
    var cursor = start
    while (cursor < newEnd) {
        let byte = context.current.readByte(cursor)
        if ((byte == 64 || byte == 36) && !task06Escaped({ at: Int64 =>
            if (at < context.current.byteLength) { Some(context.current.readByte(at)) } else { Option<Byte>.None }
        }, cursor)) {
            if (byte == 36) {
                let finish = if (cursor + 3 < context.current.byteLength) { cursor + 3 } else { context.current.byteLength }
                if (finish > newEnd) { newEnd = finish }
            } else {
                var depth: Int64 = 1; var scan = cursor + 1
                while (scan < context.current.byteLength && depth > 0) {
                    let next = context.current.readByte(scan)
                    if (next == 64 && !task06Escaped({ at: Int64 => Some(context.current.readByte(at)) }, scan)) { depth += 1 }
                    if (next == 59) { depth -= 1 }
                    scan += 1
                }
                if (scan > newEnd) { newEnd = scan }
            }
        }
        cursor += 1
    }
    while (newEnd < context.current.byteLength && context.current.readByte(newEnd) >= 128 &&
        context.current.readByte(newEnd) < 192) { newEnd += 1 }
    let corresponding = newEnd - delta
    if (corresponding > oldEnd) { oldEnd = corresponding }
    if (oldEnd > context.previous.byteLength || newEnd > context.current.byteLength || start > oldEnd) { return None }
    return Some(InlineRecoveryWindow(start, oldEnd, newEnd, "task06 actual reads and balanced candidate", "task06-context-v1"))
}

class Task06LiteralFacet <: InlineLiteralFacet {
    public prop grammarVersion: String { get() { return "task06-identity-literal-v1" } }
    public func offsetsFollowLiteral(_: InlineTextView): Bool { return true }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow {
        return Some(InlineRecoveryWindow(context.change.startByte, context.change.oldEndByte,
            context.change.newEndByte, "identity literal offsets", grammarVersion))
    }
    public func decode(view: InlineTextView, startByte: Int64, endByte: Int64): String { return view.sliceBytes(startByte, endByte) }
    public func payload(view: InlineTextView, startByte: Int64, endByte: Int64, _: BlockEditingContext): ?PersistentTextPayload {
        return Some(PersistentTextPayload.withRawSpelling(decode(view, startByte, endByte), view.sliceBytes(startByte, endByte)))
    }
    public func projectRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64 {
        let resolve = { candidate: SourceAnchor =>
            if (candidate.source.documentId == view.source.documentId && candidate.source.version == view.source.version) {
                Some(candidate.byteOffset)
            } else if (view.source.version == context.sourceVersion) { context.resolve(candidate) }
            else if (let Some(previous) <- context.previous) {
                previous.resolveAtVersion(candidate, view.source.version)
            } else { Option<Int64>.None }
        }
        let resolved = resolve(anchor)
        if (resolved.isNone()) { return None }
        let target = resolved.getOrThrow()
        var low: Int64 = 0; var high = view.byteLength
        // This fixture owns an ordered raw mapping. Synthetic/unordered views
        // have no proof here and refuse rather than inventing an inverse map.
        while (low < high) {
            let middle = low + (high - low) / 2
            let mapped = view.mapByte(middle, AnchorAffinity.After)
            if (mapped.isNone()) { return None }
            let value = resolve(mapped.getOrThrow())
            if (value.isNone()) { return None }
            if (value.getOrThrow() < target) { low = middle + 1 } else { high = middle }
        }
        if (let Some(mapped) <- view.mapByte(low, AnchorAffinity.After)) {
            if (resolve(mapped) == Some(target)) { return Some(low) }
        }
        if (let Some(mapped) <- view.mapByte(low, AnchorAffinity.Before)) {
            if (resolve(mapped) == Some(target)) { return Some(low) }
        }
        return None
    }
    public func splice(previous: PersistentTextPayload, context: InlineRecoveryContext): ?InlineLiteralSplice {
        if (previous.byteLength != context.previous.byteLength) { return None }
        return Some(InlineLiteralSplice(context.change.startByte, context.change.oldEndByte,
            context.current.sliceBytes(context.change.startByte, context.change.newEndByte)))
    }
}
