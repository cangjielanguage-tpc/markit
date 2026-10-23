package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.block.LeafBlockParser
import markit.core.editing.*
import markit.core.nodes.*
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.render.RenderRegistry
import markit.core.session.ParseSession
import markit.core.source.{SourceBuffer, SourceLine, SourceSpan, EditableRopeVersion}
import markit.plugins.standard.block.blockquote.*
import markit.plugins.standard.block.paragraph.*
import markit.plugins.standard.block.heading.*
import markit.plugins.standard.inline.soft_break.SoftBreakHtmlRenderer

private class QuoteHeadingCalls { public var count: Int64 = 0 }
// This spy delegates every syntax decision to the real registered ATX parser.
private class QuoteCountingHeadingParser <: LeafBlockParser {
    private let actual = HeadingBlockParser()
    public QuoteCountingHeadingParser(private let calls: QuoteHeadingCalls) {}
    public prop name: String { get() { return actual.name } }
    public prop ownerPlugin: String { get() { return actual.ownerPlugin } }
    public prop priority: Int64 { get() { return actual.priority } }
    public prop startBytes: Array<Byte> { get() { return actual.startBytes } }
    public prop acceptsAnyNonBlank: Bool { get() { return actual.acceptsAnyNonBlank } }
    public prop supportsIncremental: Bool { get() { return actual.supportsIncremental } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return actual.incrementalFacet } }
    public prop incrementalIsolation: ?ParserIsolationProof { get() { return actual.incrementalIsolation } }
    public func tryParse(session: ParseSession, line: String): ?Node {
        calls.count += 1
        return actual.tryParse(session, line)
    }
}
private class QuoteCountingHeadingPlugin <: Plugin {
    public QuoteCountingHeadingPlugin(private let calls: QuoteHeadingCalls) {}
    public prop name: String { get() { return "HeadingPlugin" } }
    public prop version: String { get() { return "quote-test" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerState(HeadingPlugin.stateKey, { => HeadingSessionState() })
        registrar.registerLeafBlockParser(QuoteCountingHeadingParser(calls))
        registrar.registerNodeBatchProcessor(HeadingNodeBatchProcessor())
        registrar.registerNodeEmissionFilter(HeadingNodeEmissionFilter())
        registrar.registerHtmlRenderer("Heading", HeadingHtmlRenderer())
        registrar.registerMarkdownRenderer("Heading", HeadingMarkdownRenderer())
        registrar.registerTypstRenderer("Heading", HeadingTypstRenderer())
    }
}
private func quoteTestCodec(): NodeCodec {
    let codec = NodeCodec()
    registerBlockquoteEditingCodecs(codec); registerParagraphEditingCodecs(codec); registerHeadingEditingCodecs(codec)
    return codec
}
private func quoteTestMarkit(calls: QuoteHeadingCalls): Markit {
    return Markit.empty().use(BlockquotePlugin()).use(ParagraphPlugin()).use(QuoteCountingHeadingPlugin(calls))
}
private func quoteTestHtml(node: Node): String {
    let registry = RenderRegistry()
    registry.registerHtmlRenderer("Blockquote", BlockquoteHtmlRenderer())
    registry.registerHtmlRenderer("Paragraph", ParagraphHtmlRenderer())
    registry.registerHtmlRenderer("Heading", HeadingHtmlRenderer())
    registry.registerHtmlRenderer("SoftBreak", SoftBreakHtmlRenderer())
    return registry.renderHtml(node)
}

@Test
@Tag[BlockquoteEditing, StandardEditing]
class Task07BlockquoteEditingTests {
    @TestCase
    func sharedMatcherRetainsMarkerIndentAndLazyRules() {
        @Expect(blockquoteContentStart("   > 中文"), Some(5))
        @Expect(blockquoteContentStart("\t> text").isNone(), true)
        @Expect(blockquoteContentStart("    > text").isNone(), true)
        @Expect(blockquoteContentStart(">\ttext"), Some(1))
        @Expect(blockquoteContinues("lazy continuation"), true)
        @Expect(blockquoteContinues(""), false)
        @Expect(blockquoteContinues("# outside"), false)
        let source = EditableRopeVersion("quote-matcher", "   > 中文")
        @Expect(blockquoteSourceContentStart(source, 0, source.byteLength), Some(5))
        @Expect(blockquoteSourceContinues(source, 0, source.byteLength), true)
    }
    @TestCase
    func mappedLineRetainsPhysicalUnicodeCoordinates() {
        let line = SourceLine("  > 中文😀", SourceSpan(20, 34, 10, 17), terminated: true)
        let mapped = blockquoteMappedLine(line)
        @Expect(mapped.text, "中文😀")
        @Expect(mapped.span.startByte, 24)
        @Expect(mapped.span.startRune, 14)
        @Expect(mapped.span.endByte, 34)
        @Expect(mapped.terminated, true)
    }
    @TestCase
    func stateCodecAndTypedNodeCodecDetachMutableState() {
        let state = BlockquoteState(SourceSpan(0, 3, 0, 3))
        state.addLine("a", SourceLine("> a", SourceSpan(0, 3, 0, 3)))
        let saved = (state.copyBlockState() as BlockquoteState).getOrThrow()
        state.addLine("b", SourceLine("> b", SourceSpan(4, 7, 4, 7)))
        @Expect(saved.lines.size, 1)
        let codec = NodeCodec(); registerBlockquoteEditingCodecs(codec)
        let node = BlockquoteNode(4, SourceSpan(0, 3, 0, 3)); node.setRawContent("> a")
        let cloned = (codec.clone(node) as BlockquoteNode).getOrThrow()
        @Expect(cloned.id, 4)
        @Expect(cloned.rawContent(), "> a")
        @Expect(refEq(cloned, node), false)
        @Expect(codec.supports(Node("Blockquote")), false)
    }
    @TestCase
    func nestedTextEditSplicesOneChildAndCallsNoUntouchedHeadingParser() {
        let original = "> # outer\r\n>\r\n> > # inner\r\n> >\r\n> > alpha 中文😀\r\n> >\r\n> > # tail\r\n>\r\n> # after\r\n\r\noutside"
        let calls = QuoteHeadingCalls(); let markit = quoteTestMarkit(calls)
        let editing = markit.createEditingSession("quote-nested", original, quoteTestCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot()
        let outer = before.tree.root.childAt(0)
        let inner = outer.childAt(1)
        let oldHeading = inner.childAt(0); let oldTail = inner.childAt(2); let oldAfter = outer.childAt(2)
        let oldTreeText = before.tree.materializeLegacy().toString()
        calls.count = 0
        let prefix = "> # outer\r\n>\r\n> > # inner\r\n> >\r\n> > "
        editing.applyEdits(0, [EditingTextEdit(EditingRange(prefix.size, prefix.size + 5), "bravo")])
        let result = editing.flush()
        @Expect(result.committed, true)
        @Expect(calls.count, 0)
        let after = editing.snapshot()
        @Expect(refEq(after.tree.raw(oldHeading.identity.nodeId).getOrThrow(), oldHeading), true)
        @Expect(refEq(after.tree.raw(oldTail.identity.nodeId).getOrThrow(), oldTail), true)
        @Expect(refEq(after.tree.raw(oldAfter.identity.nodeId).getOrThrow(), oldAfter), true)
        let changed = original.replace("alpha", "bravo")
        let fresh = quoteTestMarkit(QuoteHeadingCalls()).parse(changed)
        @Expect(quoteTestHtml(after.tree.materializeLegacy()), fresh.html())
        @Expect(after.tree.materializeLegacy().toString(), fresh.toString())
        @Expect(before.tree.materializeLegacy().toString(), oldTreeText)
        before.release(); after.release(); editing.close()
    }
    @TestCase
    func separatorEditUsesRealQuoteGrammarAndRetainsOldSnapshot() {
        let text = "> alpha\n>\n> bravo\n\noutside"
        let editing = quoteTestMarkit(QuoteHeadingCalls()).createEditingSession("quote-separator", text,
            quoteTestCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let old = before.tree.materializeLegacy().toString()
        editing.applyEdits(0, [EditingTextEdit(EditingRange(8, 9), "middle")])
        @Expect(editing.flush().committed, true)
        let after = editing.snapshot()
        let changed = text[0..8] + "middle" + text[9..]
        @Expect(quoteTestHtml(after.tree.materializeLegacy()), quoteTestMarkit(QuoteHeadingCalls()).parse(changed).html())
        @Expect(before.tree.materializeLegacy().toString(), old)
        before.release(); after.release(); editing.close()
    }
    @TestCase
    func openingMarkerRemovalIncludesPreviousParagraphAndActualSuffix() {
        let text = "before\n> alpha\n\n# tail\n\noutside"
        let editing = quoteTestMarkit(QuoteHeadingCalls()).createEditingSession("quote-opening", text,
            quoteTestCodec(), policy: EditingPolicy.Strict)
        editing.applyEdits(0, [EditingTextEdit(EditingRange(7, 8), "")])
        @Expect(editing.flush().committed, true)
        let after = editing.snapshot()
        let fresh = quoteTestMarkit(QuoteHeadingCalls()).parse("before\n alpha\n\n# tail\n\noutside")
        @Expect(quoteTestHtml(after.tree.materializeLegacy()), fresh.html())
        @Expect(after.tree.materializeLegacy().toString(), fresh.toString())
        after.release(); editing.close()
    }
    @TestCase
    func giantQuotedParagraphRetainsItsIdentityAcrossLocalInlineEdit() {
        let content = StringBuilder()
        for (_ in 0..4096) { content.append("abcdefgh") }
        let body = content.toString()
        let text = "> # kept\n>\n> " + body + "\n>\n> # tail"
        let calls = QuoteHeadingCalls()
        let editing = quoteTestMarkit(calls).createEditingSession("quote-giant", text, quoteTestCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let quotedNode = before.tree.root.childAt(0)
        let paragraphId = quotedNode.childAt(1).identity.nodeId
        let heading = quotedNode.childAt(0); let tail = quotedNode.childAt(2)
        calls.count = 0
        let at: Int64 = "> # kept\n>\n> ".size + 16384
        editing.applyEdits(0, [EditingTextEdit(EditingRange(at, at + 1), "中😀")])
        @Expect(editing.flush().committed, true)
        let after = editing.snapshot()
        @Expect(after.tree.root.childAt(0).childAt(1).identity.nodeId, paragraphId)
        @Expect(refEq(after.tree.raw(heading.identity.nodeId).getOrThrow(), heading), true)
        @Expect(refEq(after.tree.raw(tail.identity.nodeId).getOrThrow(), tail), true)
        @Expect(calls.count, 0)
        let fresh = quoteTestMarkit(QuoteHeadingCalls()).parse(text[0..at] + "中😀" + text[at + 1..])
        @Expect(quoteTestHtml(after.tree.materializeLegacy()), fresh.html())
        before.release(); after.release(); editing.close()
    }
}
