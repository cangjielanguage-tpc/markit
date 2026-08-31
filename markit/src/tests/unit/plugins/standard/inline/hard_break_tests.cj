package markit.tests.unit.plugins.standard.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.Node
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class HardBreakTests {
    @TestCase
    func rendersTwoSpaceHardBreakWithChineseAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "中文  \n文本\n",
            "<p>中文<br />文本</p>"
        )
    }

    @TestCase
    func rendersBackslashHardBreakAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "Line 1\\\nLine 2\n",
            "<p>Line 1<br />Line 2</p>"
        )
    }

    @TestCase
    func rendersMultipleHardBreakFormsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "Line 1  \nLine 2\\\nLine 3\n",
            "<p>Line 1<br />Line 2<br />Line 3</p>"
        )
    }

    @TestCase
    func acceptsMoreThanTwoTrailingSpacesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "Line 1   \nLine 2\n",
            "<p>Line 1 <br />Line 2</p>"
        )
    }

    @TestCase
    func acceptsBackslashWithTrailingSpacesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "Line 1\\  \nLine 2\n",
            "<p>Line 1<br />Line 2</p>"
        )
    }

    @TestCase
    func keepsEscapedBackslashAsSoftBreakAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "Line 1\\\\\nLine 2\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Line 1\\\nLine 2</p>")
                @Expect(countNodes(result.root, "HardBreakNode"), 0)
                @Expect(countNodes(result.root, "SoftBreakNode"), 2)
            }
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
