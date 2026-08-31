package markit.tests.unit.plugins.gfm.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.gfm.block.math_block.MathBlockConfig
import markit.plugins.gfm.inline.inline_math.{InlineMathConfig, InlineMathNode}
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle(
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false),
        inlineMathConfig: InlineMathConfig(enableHtmlMathtex: false)
    ))
}

@Test
class InlineMathTests {
    @TestCase
    func rendersInlineMathAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "The formula $E=mc^2$ is famous.\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>The formula <span class=\"math inline\">E=mc^2</span> is famous.</p>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectSpan(result.root, 0, 31, 0, 31)
                AstTestKit.expectNodeCount(result.root, "InlineMathNode", 1)

                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 0, 31, 0, 31)
                @Expect(paragraph.children.size, 4)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "The formula ", 0, 12, 0, 12)
                expectInlineMath(AstTestKit.child(paragraph, 1, "InlineMathNode"), "E=mc^2", 12, 20, 12, 20)
                expectText(AstTestKit.child(paragraph, 2, "TextNode"), " is famous.", 20, 31, 20, 31)
                expectSoftBreak(AstTestKit.child(paragraph, 3, "SoftBreakNode"), 31, 32, 31, 32)
            }
        )
    }

    @TestCase
    func preservesMarkdownSyntaxInsideMathAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "$**bold** _italic_ `code`$\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><span class=\"math inline\">**bold** _italic_ `code`</span></p>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectSpan(result.root, 0, 26, 0, 26)
                AstTestKit.expectNodeCount(result.root, "InlineMathNode", 1)

                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 0, 26, 0, 26)
                @Expect(paragraph.children.size, 2)
                expectInlineMath(
                    AstTestKit.child(paragraph, 0, "InlineMathNode"),
                    "**bold** _italic_ `code`",
                    0,
                    26,
                    0,
                    26
                )
                expectSoftBreak(AstTestKit.child(paragraph, 1, "SoftBreakNode"), 26, 27, 26, 27)
                AstTestKit.expectNoNode(result.root, "BoldNode")
                AstTestKit.expectNoNode(result.root, "ItalicNode")
                AstTestKit.expectNoNode(result.root, "InlineCodeNode")
            }
        )
    }

    @TestCase
    func supportsUnicodeEscapedDollarAndEmptyMathAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "$π ≈ 3.14159$ and $price \\$ 100$ and $$\n",
            "<p><span class=\"math inline\">π ≈ 3.14159</span> and <span class=\"math inline\">price \\$ 100</span> and <span class=\"math inline\"></span></p>"
        )
    }

    @TestCase
    func rejectsMultilineAndUnclosedMathAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "$x = \ny$\n$unclosed math\n",
            "<p>$x = \ny$\n$unclosed math</p>"
        )
    }

    @TestCase
    func rendersTypstMathAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "$x = y$\n",
            { result: ParseModeResult =>
                @Expect(result.typst, "$x = y$\n\n")
            }
        )
    }

    private func expectInlineMath(
        node: Node,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let math: InlineMathNode <- node) {
            @Expect(math.content, content)
            AstTestKit.expectSpan(math, startByte, endByte, startRune, endRune)
            AstTestKit.expectLeaf(math)
            return
        }
        throw IllegalArgumentException("Expected InlineMathNode, actual ${node.name}")
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

    private func expectSoftBreak(
        node: Node,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        AstTestKit.expectSpan(node, startByte, endByte, startRune, endRune)
        AstTestKit.expectLeaf(node)
    }
}
