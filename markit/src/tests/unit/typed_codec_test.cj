package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.{Node, NodeCodec, TypedNodeCodec, DocumentNode, TextNode}
import markit.core.source.{SourceBuffer, SourceRetentionMode, SourceSpan}
import markit.core.session.{SessionState, SessionStatePayload, SessionStateSnapshot, RestorableSessionStateSnapshot}
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.block.blockquote.BlockquoteNode
import markit.plugins.standard.inline.link.LinkNode
import markit.plugins.standard.inline.soft_break.SoftBreakNode
import markit.plugins.toc.{TocNode, TocItem}

// Concrete type reconstruction belongs to the provider, never core kind/name
// dispatch. This narrow provider is the executable Task02 prototype; other
// built-in providers are delivered with their owning plugin adaptation tasks.
private class PrototypeTypedCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "typed-prototype" } }
    public func accepts(node: Node): Bool {
        return (node is DocumentNode) || (node is TextNode) || (node is HeadingNode) ||
            (node is LinkNode) || (node is ParagraphNode) || (node is BlockquoteNode) ||
            (node is SoftBreakNode) || (node is TocNode) || (node is TocItem)
    }
    public func createShallow(node: Node): Node {
        if (let typed: DocumentNode <- node) { return DocumentNode(SourceBuffer()) }
        if (let typed: TextNode <- node) { return TextNode(typed.id, typed.sourceSpan, typed.content) }
        if (let typed: HeadingNode <- node) {
            return HeadingNode(typed.id, typed.sourceSpan, typed.content, typed.level, slug: typed.slug)
        }
        if (let typed: LinkNode <- node) { return LinkNode(typed.id, typed.sourceSpan, typed.content, typed.url, typed.title) }
        if (let typed: ParagraphNode <- node) { return ParagraphNode(typed.id, typed.sourceSpan, typed.content) }
        if (let typed: BlockquoteNode <- node) { return BlockquoteNode(typed.id, typed.sourceSpan) }
        if (let typed: SoftBreakNode <- node) { return SoftBreakNode(typed.id, typed.sourceSpan) }
        if (let typed: TocNode <- node) { return TocNode(title: typed.title) }
        if (let typed: TocItem <- node) { return TocItem(typed.text, typed.level, typed.anchorId, number: typed.number) }
        throw IllegalArgumentException("Unsupported prototype type")
    }
    public func additionalReferences(node: Node): Array<Node> {
        if (let toc: TocNode <- node) {
            let result = ArrayList<Node>()
            for (item in toc.items) { result.add(item) }
            return result.toArray()
        }
        return []
    }
    public func restoreReferences(target: Node, references: Array<Node>): Unit {
        if (let toc: TocNode <- target) {
            for (reference in references) {
                if (let item: TocItem <- reference) { toc.addItem(item)
                } else { throw IllegalArgumentException("TOC item type was lost") }
            }
        } else if (!references.isEmpty()) { throw IllegalArgumentException("Unexpected reference payload") }
    }
}

private class CounterStatePayload <: SessionStatePayload {
    public var count: Int64
    public init(count: Int64) { this.count = count }
    public prop fingerprint: String { get() { return "count:${count}" } }
    public func detachedCopy(): SessionStatePayload { return CounterStatePayload(count) }
}

private class RestorableCounterState <: SessionState {
    public var count: Int64 = 0
    public var sourceVersion: Int64 = 1
    public var context: String = "nested:root"
    public func reset(): Unit { count = 0 }
    public func snapshot(): SessionStateSnapshot {
        return RestorableSessionStateSnapshot("test.counter", sourceVersion, context, CounterStatePayload(count))
    }
    public prop supportsStateRestore: Bool { get() { return true } }
    public func restoreSnapshot(snapshot: SessionStateSnapshot): Bool {
        if (snapshot.dynamicName != "test.counter" || snapshot.sourceVersion != sourceVersion ||
            snapshot.contextFingerprint != context) { return false }
        if (let Some(payload) <- snapshot.payloadCopy()) {
            if (let counter: CounterStatePayload <- payload) {
                if (snapshot.fingerprint != counter.fingerprint) { return false }
                count = counter.count
                return true
            }
        }
        return false
    }
}

private class LegacyCounterState <: SessionState {
    public var count: Int64 = 7
    public func reset(): Unit { count = 0 }
    public func snapshot(): SessionStateSnapshot { return SessionStateSnapshot("legacy.name-only") }
}

@Test
@Tag[TypedCodecPrototype]
class TypedCodecPrototypeTests {
    @TestCase
    func realTypedTreeReconstructionPreservesRendererAndDetachedMutableFields() {
        let parsed = Markit().parse("# title\n\n[label](target \"caption\")\n\n> quoted")
        let root = parsed.root()
        let heading = root.children[0]
        heading.setString("shadow", "visible")
        heading.setInt("shadow", 42)
        heading.setBool("shadow", true)
        let beforeHtml = root.toHtml()
        let beforeMarkdown = root.toMarkdown()
        let beforeTypst = root.toTypst()
        let codec = configuredCodec()
        let copied = codec.clone(root)
        @Expect(refEq(copied, root), false)
        @Expect(copied.toHtml(), beforeHtml)
        @Expect(copied.toMarkdown(), beforeMarkdown)
        @Expect(copied.toTypst(), beforeTypst)
        @Expect(copied.toJson(), root.toJson())
        @Expect(copied.sharesSourceBinding(root), true)
        @Expect(copied.children.size, root.children.size)
        let copiedHeading = copied.children[0]
        @Expect(copiedHeading is HeadingNode, true)
        @Expect(copiedHeading.id, heading.id)
        @Expect(copiedHeading.sourceSpan.startByte, heading.sourceSpan.startByte)
        @Expect(copiedHeading.sourceSpan.endRune, heading.sourceSpan.endRune)
        @Expect(copiedHeading.string("shadow"), Some("visible"))
        @Expect(copiedHeading.int("shadow"), Some(42))
        @Expect(copiedHeading.bool("shadow"), Some(true))
        @Expect(refEq(copiedHeading, heading), false)
        @Expect(copiedHeading.parent.isSome(), true)
        if (let Some(parent) <- copiedHeading.parent) { @Expect(refEq(parent, copied), true) }
        copiedHeading.setInt("shadow", 99)
        copiedHeading.setString("shadow", "changed")
        copiedHeading.setBool("shadow", false)
        @Expect(heading.int("shadow"), Some(42))
        @Expect(heading.string("shadow"), Some("visible"))
        @Expect(heading.bool("shadow"), Some(true))
        if (let link: LinkNode <- copied.children[1].children[0]) {
            @Expect(link.content, "label")
            @Expect(link.title, "caption")
            link.url = "new-target"
            @Expect(copied.toHtml().contains("new-target"), true)
            @Expect(root.toHtml(), beforeHtml)
        } else { @Assert(false) }
        @Expect(copied.children[2] is BlockquoteNode, true)
        @Expect(copied.children[2].children[0].children[0] is TextNode, true)
    }

    @TestCase
    func sourceBindingsRawOverrideAndInheritedRenderHooksAreRestoredWithoutAliasing() {
        let source = SourceBuffer(retentionMode: SourceRetentionMode.Full)
        source.append("root")
        let synthetic = SourceBuffer(retentionMode: SourceRetentionMode.Full)
        synthetic.append("字")
        let root = DocumentNode(source)
        let text = TextNode(1, SourceSpan(0, 3, 0, 1), "logical")
        root.addChild(text)
        text.attachSource(synthetic)
        let copy = configuredCodec().clone(root)
        @Expect(copy.sharesSourceBinding(root), true)
        @Expect(copy.children[0].sharesSourceBinding(text), true)
        @Expect(copy.children[0].sharesSourceBinding(root), false)
        @Expect(copy.children[0].rawContent(), "字")
        copy.children[0].setRawContent("new override")
        @Expect(text.rawContent(), "字")
        text.setRawContent("original override")
        let standalone = configuredCodec().clone(text)
        @Expect(standalone.rawContent(), "original override")
        standalone.setRawContent("copy override")
        @Expect(text.rawContent(), "original override")
        let parsed = Markit().parse("# hooked")
        let originalHeading = parsed.root().children[0]
        let detachedHeading = configuredCodec().clone(originalHeading)
        @Expect(detachedHeading.parent.isNone(), true)
        @Expect(detachedHeading.toHtml(), originalHeading.toHtml())
        @Expect(detachedHeading.toMarkdown(), originalHeading.toMarkdown())
        @Expect(detachedHeading.toTypst(), originalHeading.toTypst())
    }

    @TestCase
    func tocItemsAndGrandchildrenPreserveTypedFieldsAliasesAndIndependentMetadata() {
        let toc = TocNode(title: "Contents")
        let first = TocItem("Title", 1, "title", number: "1")
        let second = TocItem("Nested", 2, "nested", number: "1.1")
        first.addChild(second)
        first.setString("shadow", "visible")
        first.setInt("shadow", 3)
        first.setBool("shadow", true)
        toc.addChild(first)
        toc.addItem(first)
        toc.addItem(second)
        let copiedNode = configuredCodec().clone(toc)
        if (let copied: TocNode <- copiedNode) {
            @Expect(copied.items.size, 2)
            @Expect(copied.toHtml(), toc.toHtml())
            @Expect(copied.toMarkdown(), toc.toMarkdown())
            @Expect(copied.toTypst(), toc.toTypst())
            @Expect(refEq(copied.items[0], copied.children[0]), true)
            @Expect(refEq(copied.items[1], copied.items[0].children[0]), true)
            @Expect(refEq(copied.items[0], first), false)
            @Expect(copied.items[0].anchorId, "title")
            @Expect(copied.items[1].number, "1.1")
            @Expect(copied.items[0].int("shadow"), Some(3))
            @Expect(copied.items[0].bool("shadow"), Some(true))
            if (let Some(parent) <- copied.items[1].parent) { @Expect(refEq(parent, copied.items[0]), true)
            } else { @Assert(false) }
            copied.items[0].setInt("shadow", 8)
            copied.items[1].setRawContent("new")
            @Expect(first.int("shadow"), Some(3))
            @Expect(second.rawContent(), "Nested")
        } else { @Assert(false) }
    }

    @TestCase
    func unregisteredNodesAndInvalidShallowReconstructionAreRejected() {
        let codec = configuredCodec()
        let unknown = Node("Heading", id: 99, literal: "cannot impersonate a HeadingNode")
        @Expect(codec.supports(unknown), false)
        var rejected = false
        try { codec.clone(unknown) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        let original = TextNode(4, SourceSpan.empty(), "x")
        let wrongId = TextNode(5, SourceSpan.empty(), "x")
        rejected = false
        try { original.copyBaseTo(wrongId) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try { original.copyBaseTo(original) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
    }

    @TestCase
    func snapshotPayloadIsDetachedAndRestoreRequiresSourceAndContextIdentity() {
        let state = RestorableCounterState()
        state.count = 17
        let snapshot = state.snapshot()
        @Expect(snapshot.hasRestorablePayload, true)
        @Expect(snapshot.fingerprint, "count:17")
        if (let Some(payload) <- snapshot.payloadCopy()) {
            if (let counter: CounterStatePayload <- payload) { counter.count = 99 }
        }
        @Expect(snapshot.fingerprint, "count:17")
        state.count = 31
        @Expect(state.restoreSnapshot(snapshot), true)
        @Expect(state.count, 17)
        state.sourceVersion = 2
        state.count = 31
        @Expect(state.restoreSnapshot(snapshot), false)
        @Expect(state.count, 31)
        state.sourceVersion = 1
        state.context = "nested:other"
        @Expect(state.restoreSnapshot(snapshot), false)
        @Expect(state.count, 31)
    }

    @TestCase
    func oldNameOnlySessionStatesKeepSafeUnsupportedDefault() {
        let state = LegacyCounterState()
        let snapshot = state.snapshot()
        @Expect(state.supportsStateRestore, false)
        @Expect(snapshot.hasRestorablePayload, false)
        @Expect(snapshot.sourceVersion, -1)
        @Expect(snapshot.contextFingerprint, "")
        @Expect(snapshot.fingerprint, "")
        @Expect(state.restoreSnapshot(snapshot), false)
        @Expect(state.count, 7)
    }

    private func configuredCodec(): NodeCodec {
        let codec = NodeCodec()
        codec.register(PrototypeTypedCodec())
        return codec
    }
}
