package markit.tests.unit.plugins.gfm.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.inline.italic.ItalicNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle())
}

@Test
class RelaxedEmphasisTests {
    @TestCase
    func rendersBasicUnderscoreItalicAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "_italic text_",
            "<p><em>italic text</em></p>"
        )
    }

    @TestCase
    func rendersBasicUnderscoreBoldAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "__bold text__",
            "<p><strong>bold text</strong></p>"
        )
    }

    @TestCase
    func leavesUnderscoresInsideWordsAsTextAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "my_variable_name and var_123_name",
            "<p>my_variable_name and var_123_name</p>"
        )
    }

    @TestCase
    func supportsWordBoundaryPunctuationAndChineseAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "Hello, _world_! 中文 _强调_",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Hello, <em>world</em>! 中文 <em>强调</em></p>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectSpan(result.root, 0, 31, 0, 23)
                AstTestKit.expectNodeCount(result.root, "ItalicNode", 2)

                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                if (let p: ParagraphNode <- paragraph) {
                    @Expect(p.content, "Hello, _world_! 中文 _强调_")
                    @Expect(p.children.size, 4)
                }
                AstTestKit.expectSpan(paragraph, 0, 31, 0, 23)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "Hello, ", 0, 7, 0, 7)
                expectItalic(AstTestKit.child(paragraph, 1, "ItalicNode"), "world", 7, 14, 7, 14)
                expectText(AstTestKit.child(paragraph, 2, "TextNode"), "! 中文 ", 14, 23, 14, 19)
                expectItalic(AstTestKit.child(paragraph, 3, "ItalicNode"), "强调", 23, 31, 19, 23)
            }
        )
    }

    @TestCase
    func supportsNestedUnderscoreEmphasisAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "__bold with _italic_ inside__",
            "<p><strong>bold with <em>italic</em> inside</strong></p>"
        )
    }

    @TestCase
    func unclosedOrEmptyUnderscoreFallsBackToTextAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "__\n_unclosed emphasis",
            "<p>__\n_unclosed emphasis</p>"
        )
    }

    private func expectItalic(
        node: Node,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let italic: ItalicNode <- node) {
            @Expect(italic.content, content)
            @Expect(italic.delimiter, "_")
            @Expect(italic.children.size, 1)
            AstTestKit.expectSpan(italic, startByte, endByte, startRune, endRune)
            expectText(
                AstTestKit.child(italic, 0, "TextNode"),
                content,
                startByte + 1,
                endByte - 1,
                startRune + 1,
                endRune - 1
            )
            return
        }
        throw IllegalArgumentException("Expected ItalicNode, actual ${node.name}")
    }

    private func expectText(
        node: Node,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, content)
            AstTestKit.expectSpan(text, startByte, endByte, startRune, endRune)
            AstTestKit.expectLeaf(text)
            return
        }
        throw IllegalArgumentException("Expected TextNode, actual ${node.name}")
    }
}
