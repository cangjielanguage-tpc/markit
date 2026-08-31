package markit.tests.unit.plugins.standard.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.Node
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class InlineCodeTests {
    @TestCase
    func rendersUnicodeInlineCodeAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "调用 `print(\"中文\")` 并输出 <tag>\n",
            "<p>调用 <code>print(&quot;中文&quot;)</code> 并输出 &lt;tag&gt;</p>"
        )
    }

    @TestCase
    func supportsLongerBacktickFenceAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "``code ` inside``\n",
            "<p><code>code ` inside</code></p>"
        )
    }

    @TestCase
    func preservesMarkdownSyntaxInsideInlineCodeAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "`**bold** *italic* [link](url)`\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><code>**bold** *italic* [link](url)</code></p>")
                @Expect(countNodes(result.root, "InlineCodeNode"), 1)
                @Expect(countNodes(result.root, "BoldNode"), 0)
                @Expect(countNodes(result.root, "ItalicNode"), 0)
                @Expect(countNodes(result.root, "LinkNode"), 0)
            }
        )
    }

    @TestCase
    func supportsMultipleInlineCodeSpansAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "`first code` and `second code`\n",
            "<p><code>first code</code> and <code>second code</code></p>"
        )
    }

    @TestCase
    func preservesSpacesAndBackslashesInsideInlineCodeAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "`  code\\with\\backslashes  `\n",
            "<p><code>  code\\with\\backslashes  </code></p>"
        )
    }

    @TestCase
    func emptyBackticksRemainLiteralTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "``\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>``</p>")
                @Expect(countNodes(result.root, "InlineCodeNode"), 0)
            }
        )
    }

    @TestCase
    func multilineInlineCodeMatchesLegacyNormalizationAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "`code\nwith\nnewlines`\n",
            "<p><code>code with newlines</code></p>"
        )
    }

    private func countNodes(node: Node, name: String): Int64 {
        var total: Int64 = if (node.name == name) { 1 } else { 0 }
        for (child in node.children) {
            total += countNodes(child, name)
        }
        return total
    }
}
