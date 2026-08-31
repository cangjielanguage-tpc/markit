package markit.tests.unit.plugins.gfm.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.TextNode
import markit.plugins.gfm.inline.strikethrough.StrikethroughNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle())
}

@Test
class StrikethroughTests {
    @TestCase
    func rendersBasicStrikethroughAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "~~strikethrough text~~\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><del>strikethrough text</del></p>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectSpan(result.root, 0, 22, 0, 22)
                AstTestKit.expectNodeCount(result.root, "StrikethroughNode", 1)

                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 0, 22, 0, 22)
                @Expect(paragraph.children.size, 2)
                if (let strike: StrikethroughNode <- AstTestKit.child(paragraph, 0, "StrikethroughNode")) {
                    @Expect(strike.content, "strikethrough text")
                    AstTestKit.expectSpan(strike, 0, 22, 0, 22)
                    @Expect(strike.children.size, 1)
                    if (let text: TextNode <- AstTestKit.child(strike, 0, "TextNode")) {
                        @Expect(text.content, "strikethrough text")
                        AstTestKit.expectSpan(text, 2, 20, 2, 20)
                        AstTestKit.expectLeaf(text)
                    }
                }
                let softBreak = AstTestKit.child(paragraph, 1, "SoftBreakNode")
                AstTestKit.expectSpan(softBreak, 22, 23, 22, 23)
                AstTestKit.expectLeaf(softBreak)
            }
        )
    }

    @TestCase
    func rendersMultipleAndNestedInlineAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "~~first~~ and ~~second **bold**~~\n",
            "<p><del>first</del> and <del>second <strong>bold</strong></del></p>"
        )
    }

    @TestCase
    func supportsChineseAndEscapedTildesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "~~中文删除线 with \\~~ escaped tildes~~\n",
            "<p><del>中文删除线 with \\~~ escaped tildes</del></p>"
        )
    }

    @TestCase
    func rejectsSingleAndUnclosedTildesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "~not strikethrough~\n~~unclosed strikethrough\n",
            "<p>~not strikethrough~\n~~unclosed strikethrough</p>"
        )
    }

    @TestCase
    func fourTildesRemainAStandardEmptyFenceAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "~~~~\n",
            "<pre><code></code></pre>"
        )
    }

    @TestCase
    func rendersTypstStrikeAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "This is ~~deleted~~ text.\n",
            { result: ParseModeResult =>
                @Expect(result.typst, "This is #strike[deleted] text.\n\n")
            }
        )
    }
}
