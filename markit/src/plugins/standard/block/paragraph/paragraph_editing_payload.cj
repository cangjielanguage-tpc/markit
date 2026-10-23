package markit.plugins.standard.block.paragraph

import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.*
import markit.core.source.{SourceBuffer, SourceSpan}
import markit.plugins.standard.editing.*

// Only editing nodes carry the initial child-session handoff. Published payloads
// own immutable views; the legacy ParagraphNode keeps its original layout.
public class EditingParagraphNode <: ParagraphNode & StandardBlockRecoveryCarrier {
    public EditingParagraphNode(id: Int64, span: SourceSpan,
        public let inlineView: StandardParagraphInlineView, public let immutableSource: EditableSourceVersion,
        public let plan: StandardInlinePlan, public let engine: InlineEditingSession,
        public let recovery: StandardBlockRecovery, public let boundary: ParagraphBlockBoundary) { super(id, span, "") }
    public var initialSnapshot: ?InlineEditingSnapshot = None
    public var rawFollowsMappedView: Bool = false
    public prop blockRecovery: ?StandardBlockRecovery { get() { return Some(recovery) } }
    public override prop content: String {
        get() { return inlineView.sliceBytes(0, contentEnd) }
    }
    public var contentEnd: Int64 = 0
    public override func rawContent(): String {
        return if (rawFollowsMappedView) { inlineView.sliceBytes(0, contentEnd) }
            else { overriddenRawContent() ?? immutableSource.sliceBytes(sourceSpan.startByte, sourceSpan.endByte) }
    }
}

public class ParagraphPayload <: MaterializableNodePayload & StandardBlockRecoveryCarrier {
    private let base: Node
    private let initialChildren: ?Array<PersistentNodeBundle>
    public prop codecId: String { get() { return "standard.paragraph.view.v1" } }
    public ParagraphPayload(base: Node, initialChildren: ?Array<PersistentNodeBundle>,
        public let view: StandardParagraphInlineView, public let source: EditableSourceVersion,
        public let plan: StandardInlinePlan, public let engine: InlineEditingSession,
        public let snapshot: InlineEditingSnapshot, public let recovery: StandardBlockRecovery,
        public let span: SourceSpan, public let contentEnd: Int64, public let boundary: ParagraphBlockBoundary,
        public let rawFollowsMappedView!: Bool = false) {
        let frozen = Node("Paragraph", id: base.id, sourceSpan: span)
        base.copyBaseTo(frozen)
        this.base = frozen
        this.initialChildren = initialChildren.map({ values => values.clone() })
    }
    public func clonePayload(): SyntaxNodePayload { return this }
    public prop blockRecovery: ?StandardBlockRecovery { get() { return Some(recovery) } }
    public func references(): Array<Int64> { return [] }
    public func captureChildren(): ?Array<PersistentNodeBundle> {
        return initialChildren.map({ values => values.clone() })
    }
    public func originalSpan(): ?SourceSpan { return Some(span) }
    public func restore(_: Node, references: Array<Node>): Unit {
        if (!references.isEmpty()) { throw IllegalArgumentException("Unexpected paragraph references") }
    }
    public func materializeShallow(): Node {
        let content = view.sliceBytes(0, contentEnd)
        let node = ParagraphNode(base.id, span, content)
        base.copyBaseTo(node)
        node.sourceSpan = span; node.literal = content
        node.setRawContent(if (rawFollowsMappedView) { view.sliceBytes(0, contentEnd) }
            else { source.sliceBytes(span.startByte, span.endByte) })
        return node
    }
    public func updated(nextView: StandardParagraphInlineView, nextSource: EditableSourceVersion,
        nextSnapshot: InlineEditingSnapshot, nextSpan: SourceSpan, nextContentEnd: Int64): ParagraphPayload {
        return ParagraphPayload(base, None, nextView, nextSource, plan, engine, nextSnapshot, recovery, nextSpan, nextContentEnd, boundary,
            rawFollowsMappedView: rawFollowsMappedView)
    }
}

public class ParagraphNodeCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "standard.paragraph" } }
    public func accepts(node: Node): Bool { return node is ParagraphNode }
    public func createShallow(node: Node): Node {
        let paragraph = (node as ParagraphNode).getOrThrow()
        return ParagraphNode(node.id, node.sourceSpan, paragraph.content)
    }
    public func capturePayload(node: Node, _: SourceVersionIdentity): ?SyntaxNodePayload {
        if (let paragraph: EditingParagraphNode <- node) {
            let snapshot = paragraph.initialSnapshot.getOrThrow()
            return Some(ParagraphPayload(paragraph, Some(snapshot.childrenEdit.inserted),
                paragraph.inlineView, paragraph.immutableSource, paragraph.plan, paragraph.engine,
                snapshot, paragraph.recovery, paragraph.sourceSpan, paragraph.contentEnd, paragraph.boundary,
                rawFollowsMappedView: paragraph.rawFollowsMappedView))
        }
        return None
    }
}

// Document/Text are the parser's existing concrete nodes, not kind-name decoders.
private class ParagraphCoreNodeCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "standard.paragraph.core" } }
    public func accepts(node: Node): Bool { return node is DocumentNode || node is TextNode }
    public func createShallow(node: Node): Node {
        if (let text: TextNode <- node) { return TextNode(text.id, text.sourceSpan, text.content) }
        return DocumentNode(SourceBuffer())
    }
    public func rawContentFollowsSource(_: Node): Bool { return true }
}
public func registerParagraphEditingCodecs(codec: NodeCodec): Unit {
    codec.register(ParagraphNodeCodec()); codec.register(ParagraphCoreNodeCodec())
}
