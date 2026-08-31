package markit.tests.unit.plugins.gfm.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.gfm.block.math_block.{MathBlockConfig, MathBlockNode}
import markit.plugins.gfm.inline.inline_math.InlineMathConfig
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeFixture, ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle(
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false),
        inlineMathConfig: InlineMathConfig(enableHtmlMathtex: false)
    ))
}

@Test
class MathBlockTests {
    @TestCase
    func rendersBasicMathBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            """
$$
E=mc^2
$$
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div class=\"math-block\">E=mc^2</div>")
                expectMathBlock(result.root, "E=mc^2")
            }
        )
    }

    @TestCase
    func preservesWhitespaceMarkdownAndChineseAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            """
$$
π ≈ 3.14159
中文数学公式
**bold** _italic_ `code`
$$
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div class=\"math-block\">π ≈ 3.14159\n中文数学公式\n**bold** _italic_ `code`</div>")
                AstTestKit.expectNoNode(result.root, "BoldNode")
                AstTestKit.expectNoNode(result.root, "ItalicNode")
                AstTestKit.expectNoNode(result.root, "InlineCodeNode")
                expectMathBlock(result.root, "π ≈ 3.14159\n中文数学公式\n**bold** _italic_ `code`", 0, 64, 0, 49)
            }
        )
    }

    @TestCase
    func handlesByteChunksInsideUnicodeMathAcrossModes() {
        let markdown = """
$$
中文公式 🚀
$$
"""
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            ParseModeFixture(markdown),
            "<div class=\"math-block\">中文公式 🚀</div>"
        )
    }

    @TestCase
    func preservesComplexLatexAndEscapedDollarsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            """
$$
\\begin{align}
x &= a + b \\\\
\\text{Price: \\$100}
\\end{align}
$$
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div class=\"math-block\">\\begin{align}\nx &amp;= a + b \\\\\n\\text{Price: \\$100}\n\\end{align}</div>")
                AstTestKit.expectNoNode(result.root, "BoldNode")
                AstTestKit.expectNoNode(result.root, "InlineMathNode")
            }
        )
    }

    @TestCase
    func preservesLatexEquationEnvironmentsAcrossModes() {
        assertExactMathBlockAcrossModes(
            "$$\n\\begin{equation}\n\\label{eq:euler}\ne^{i\\pi} + 1 = 0\n\\end{equation}\n$$\n",
            "<div class=\"math-block\">\\begin{equation}\n\\label{eq:euler}\ne^{i\\pi} + 1 = 0\n\\end{equation}</div>",
            "$$\n\\begin{equation}\n\\label{eq:euler}\ne^{i\\pi} + 1 = 0\n\\end{equation}\n$$\n\n",
            "\\begin{equation}\n\\label{eq:euler}\ne^{i\\pi} + 1 = 0\n\\end{equation}",
            71,
            71
        )

        assertExactMathBlockAcrossModes(
            "$$\n\\begin{align}\nf(x) &= ax^2 + bx + c \\\\\nf'(x) &= 2ax + b \\\\\nf''(x) &= 2a\n\\end{align}\n$$\n",
            "<div class=\"math-block\">\\begin{align}\nf(x) &amp;= ax^2 + bx + c \\\\\nf&#39;(x) &amp;= 2ax + b \\\\\nf&#39;&#39;(x) &amp;= 2a\n\\end{align}</div>",
            "$$\n\\begin{align}\nf(x) &= ax^2 + bx + c \\\\\nf'(x) &= 2ax + b \\\\\nf''(x) &= 2a\n\\end{align}\n$$\n\n",
            "\\begin{align}\nf(x) &= ax^2 + bx + c \\\\\nf'(x) &= 2ax + b \\\\\nf''(x) &= 2a\n\\end{align}",
            89,
            89
        )

        assertExactMathBlockAcrossModes(
            "$$\nf(x) = \\begin{cases}\nx^2 & \\text{if } x \\geq 0 \\\\\n-x^2 & \\text{if } x < 0\n\\end{cases}\n$$\n",
            "<div class=\"math-block\">f(x) = \\begin{cases}\nx^2 &amp; \\text{if } x \\geq 0 \\\\\n-x^2 &amp; \\text{if } x &lt; 0\n\\end{cases}</div>",
            "$$\nf(x) = \\begin{cases}\nx^2 & \\text{if } x \\geq 0 \\\\\n-x^2 & \\text{if } x < 0\n\\end{cases}\n$$\n\n",
            "f(x) = \\begin{cases}\nx^2 & \\text{if } x \\geq 0 \\\\\n-x^2 & \\text{if } x < 0\n\\end{cases}",
            91,
            91
        )
    }

    @TestCase
    func ignoresEscapedAndIndentedClosingDelimitersAcrossModes() {
        assertExactMathBlockAcrossModes(
            "$$\nSome math\n\\$\\$ not an end\nMore math\n$$\n",
            "<div class=\"math-block\">Some math\n\\$\\$ not an end\nMore math</div>",
            "$$\nSome math\n\\$\\$ not an end\nMore math\n$$\n\n",
            "Some math\n\\$\\$ not an end\nMore math",
            41,
            41
        )

        assertExactMathBlockAcrossModes(
            "$$\nMath content\n  $$ indented, not at line start\nMore content\n$$\n",
            "<div class=\"math-block\">Math content\n  $$ indented, not at line start\nMore content</div>",
            "$$\nMath content\n  $$ indented, not at line start\nMore content\n$$\n\n",
            "Math content\n  $$ indented, not at line start\nMore content",
            64,
            64
        )
    }

    @TestCase
    func preservesMatrixTabsSpacesAndSpecialCharactersAcrossModes() {
        assertExactMathBlockAcrossModes(
            "$$\n\\begin{matrix}\n  a & b \\\\\n  c & d\n\\end{matrix}\n$$\n",
            "<div class=\"math-block\">\\begin{matrix}\n  a &amp; b \\\\\n  c &amp; d\n\\end{matrix}</div>",
            "$$\n\\begin{matrix}\n  a & b \\\\\n  c & d\n\\end{matrix}\n$$\n\n",
            "\\begin{matrix}\n  a & b \\\\\n  c & d\n\\end{matrix}",
            52,
            52
        )

        assertExactMathBlockAcrossModes(
            "$$\n\tindented with tab\n    indented with spaces\n$$\n",
            "<div class=\"math-block\">\tindented with tab\n    indented with spaces</div>",
            "$$\n\tindented with tab\n    indented with spaces\n$$\n\n",
            "\tindented with tab\n    indented with spaces",
            49,
            49
        )

        assertExactMathBlockAcrossModes(
            "$$\n\\alpha + \\beta = \\gamma\n!@#$%^&*()\n$$\n",
            "<div class=\"math-block\">\\alpha + \\beta = \\gamma\n!@#$%^&amp;*()</div>",
            "$$\n\\alpha + \\beta = \\gamma\n!@#$%^&*()\n$$\n\n",
            "\\alpha + \\beta = \\gamma\n!@#$%^&*()",
            40,
            40
        )
    }

    @TestCase
    func preservesEmptyAndWhitespaceOnlyBlocksAcrossModes() {
        assertExactMathBlockAcrossModes(
            "$$\n$$\n",
            "<div class=\"math-block\"></div>",
            "$$\n$$\n\n",
            "",
            5,
            5
        )

        assertExactMathBlockAcrossModes(
            "$$\n   \n\t\n$$\n",
            "<div class=\"math-block\">   \n\t</div>",
            "$$\n   \n\t\n$$\n\n",
            "   \n\t",
            11,
            11
        )
    }

    @TestCase
    func preservesBlankLinesWhitespaceAndMarkdownSyntaxAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            """
$$
line1
  line2 with spaces

**not bold** and `not code`
$$
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div class=\"math-block\">line1\n  line2 with spaces\n\n**not bold** and `not code`</div>")
                AstTestKit.expectNoNode(result.root, "BoldNode")
                AstTestKit.expectNoNode(result.root, "InlineCodeNode")
            }
        )
    }

    @TestCase
    func rejectsNonBlockDelimitersAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            """
text $$
E=mc^2
$$
""",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "MathBlockNode")
            }
        )

        ParseModeTestKit.assertAcrossModes(
            gfm,
            "$$$$",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "MathBlockNode")
            }
        )
    }

    @TestCase
    func topLevelDeepIndentedMathDoesNotStartBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            """
      $$
      x = y + z
      $$
""",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "MathBlockNode")
            }
        )
    }

    @TestCase
    func listIndentedMathBlockStillStartsRelativeToItemAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            """
- Item 1
  $$
  x = y + z
  $$
- Item 2
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<ul><li>Item 1<div class=\"math-block\">x = y + z</div></li><li>Item 2</li></ul>")
                expectNestedMathBlock(result.root, "x = y + z")
            }
        )
    }

    @TestCase
    func unclosedMathFallsBackToParagraphAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            """
$$
E=mc^2
no closing delimiter
""",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "MathBlockNode")
                @Expect(result.html, "<p><span class=\"math inline\"></span>\nE=mc^2\nno closing delimiter</p>")
            }
        )
    }

    private func assertExactMathBlockAcrossModes(
        markdown: String,
        expectedHtml: String,
        expectedMarkdown: String,
        content: String,
        endByte: Int64,
        endRune: Int64
    ): Unit {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html, expectedHtml)
                @Expect(result.markdown, expectedMarkdown)
                expectMathBlock(result.root, content, 0, endByte, 0, endRune)
            }
        )
    }

    private func expectMathBlock(root: Node, content: String): Unit {
        expectMathBlock(root, content, 0, 12, 0, 12)
    }

    private func expectMathBlock(
        root: Node,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        AstTestKit.expectRoot(root, 1)
        AstTestKit.expectSpan(root, startByte, endByte, startRune, endRune)
        if (let math: MathBlockNode <- AstTestKit.child(root, 0, "MathBlockNode")) {
            @Expect(math.content, content)
            @Expect(math.indentLevel, 0)
            AstTestKit.expectSpan(math, startByte, endByte, startRune, endRune)
            AstTestKit.expectLeaf(math)
        }
    }

    private func expectNestedMathBlock(root: Node, content: String): Unit {
        AstTestKit.expectRoot(root, 1)
        AstTestKit.expectSpan(root, 0, 39, 0, 39)

        let list = AstTestKit.child(root, 0, "UnorderedListNode")
        AstTestKit.expectSpan(list, 0, 39, 0, 39)
        @Expect(list.children.size, 2)

        let firstItem = AstTestKit.child(list, 0, "UnorderedListItemNode")
        AstTestKit.expectSpan(firstItem, 0, 30, 0, 30)
        @Expect(firstItem.children.size, 2)

        let paragraph = AstTestKit.child(firstItem, 0, "ParagraphNode")
        AstTestKit.expectSpan(paragraph, 2, 8, 2, 8)
        @Expect(paragraph.children.size, 1)
        let itemText = AstTestKit.child(paragraph, 0, "TextNode")
        if (let text: TextNode <- itemText) {
            @Expect(text.content, "Item 1")
        }
        AstTestKit.expectSpan(itemText, 2, 8, 2, 8)
        AstTestKit.expectLeaf(itemText)

        if (let math: MathBlockNode <- AstTestKit.child(firstItem, 1, "MathBlockNode")) {
            @Expect(math.content, content)
            @Expect(math.indentLevel, 0)
            AstTestKit.expectSpan(math, 9, 30, 9, 30)
            AstTestKit.expectLeaf(math)
        }

        let secondItem = AstTestKit.child(list, 1, "UnorderedListItemNode")
        AstTestKit.expectSpan(secondItem, 31, 39, 31, 39)
        @Expect(secondItem.children.size, 1)
        let secondText = AstTestKit.child(secondItem, 0, "TextNode")
        if (let text: TextNode <- secondText) {
            @Expect(text.content, "Item 2")
        }
        AstTestKit.expectSpan(secondText, 33, 39, 33, 39)
        AstTestKit.expectLeaf(secondText)
    }
}
