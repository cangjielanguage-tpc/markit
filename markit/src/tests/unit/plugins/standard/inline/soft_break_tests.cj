package markit.tests.unit.plugins.standard.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.Node
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class SoftBreakTests {
    @TestCase
    func rendersParagraphInternalNewlinesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "Line 1\nLine 2\nLine 3",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Line 1\nLine 2\nLine 3</p>")
                @Expect(countNodes(result.root, "SoftBreakNode"), 2)
            }
        )
    }

    @TestCase
    func preservesUnicodeAroundSoftBreakAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "中文\n文本\nText 🚀\n🎉 More",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>中文\n文本\nText 🚀\n🎉 More</p>")
                @Expect(countNodes(result.root, "SoftBreakNode"), 3)
            }
        )
    }

    @TestCase
    func rendersSoftBreakInsideInlineContainersAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[Link\ntext](http://example.com) and **Bold\ntext**",
            "<p><a href=\"http://example.com\">Link\ntext</a> and <strong>Bold\ntext</strong></p>"
        )
    }

    @TestCase
    func singleTrailingSpaceStillCreatesSoftBreakAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "Line 1 \nLine 2",
            "<p>Line 1 \nLine 2</p>"
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
