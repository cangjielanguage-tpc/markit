package markit.core.session

import markit.core.nodes.{DocumentNode, Node, TextNode}
import markit.core.source.{LineIndex, SourceBuffer, SourceLine, SourceSpan}
import std.collection.ArrayList

public class ParseSession {
    public let source: SourceBuffer
    public let options: ParseOptions
    public let symbolTables: SessionSymbolTableStore
    public let root: Node
    public let lineIndex = LineIndex()
    public let patches = SessionPatchQueue()
    public let pendingParagraphLines = ArrayList<SourceLine>()
    public var finalized: Bool = false
    private var activeLine: ?SourceLine = None
    private var paragraphSpan: ?SourceSpan = None
    private var nextId: Int64 = 1
    private var detachedParseDepth: Int64 = 0
    private var topLevelIndentedBlockStartsAllowed: Bool = false
    private var detachedBlockParser: ?(ArrayList<SourceLine>) -> ArrayList<Node> = None
    private var registeredBlockStartDetector: ?(ParseSession, String) -> Bool = None
    private var paragraphNodeFactory: ?(ArrayList<SourceLine>, SourceSpan, ParagraphTermination) -> Node = None
    private var inlineParser: ?(ParseSession, String, SourceSpan) -> ArrayList<Node> = None
    private var inlineRangeParser: ?(ParseSession, String, Int64, Int64, SourceSpan) -> ArrayList<Node> = None

    public init(
        source: SourceBuffer,
        options: ParseOptions,
        symbolTables: SessionSymbolTableStore
    ) {
        this.source = source
        this.options = options
        this.symbolTables = symbolTables
        this.root = DocumentNode(source)
    }

    public func allocateNodeId(): Int64 {
        let id = nextId
        nextId += 1
        return id
    }

    public func beginLine(line: SourceLine): Unit {
        activeLine = Some(line)
    }

    public func recordSourceLine(line: SourceLine): Unit {
        lineIndex.add(line)
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

    public func setDetachedBlockParser(parser: (ArrayList<SourceLine>) -> ArrayList<Node>): Unit {
        detachedBlockParser = Some(parser)
    }

    public func parseDetachedLines(lines: ArrayList<SourceLine>): ArrayList<Node> {
        if (let Some(parser) <- detachedBlockParser) {
            detachedParseDepth += 1
            let nodes = parser(lines)
            detachedParseDepth -= 1
            return nodes
        }
        return ArrayList<Node>()
    }

    public func allowDeepIndentedBlockStart(): Bool {
        return detachedParseDepth > 0 || topLevelIndentedBlockStartsAllowed
    }

    public func setTopLevelIndentedBlockStartsAllowed(allowed: Bool): Unit {
        topLevelIndentedBlockStartsAllowed = allowed
    }

    public func setRegisteredBlockStartDetector(detector: (ParseSession, String) -> Bool): Unit {
        registeredBlockStartDetector = Some(detector)
    }

    public func startsRegisteredBlock(line: String): Bool {
        if (let Some(detector) <- registeredBlockStartDetector) {
            detachedParseDepth += 1
            let starts = detector(this, line)
            detachedParseDepth -= 1
            return starts
        }
        return false
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
