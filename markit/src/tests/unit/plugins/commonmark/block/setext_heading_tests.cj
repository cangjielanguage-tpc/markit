package markit.tests.unit.plugins.commonmark.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.plugins.standard.block.heading.HeadingNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func commonMark(): Markit {
    return Markit(CommonMarkBundle())
}

@Test
class SetextHeadingTests {
    @TestCase
    func rendersSetextH1AcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Heading 1\n=========\n",
            "<h1 id=\"heading-1\">Heading 1</h1>"
        )
    }

    @TestCase
    func rendersSetextH2AcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Heading 2\n---------\n",
            "<h2 id=\"heading-2\">Heading 2</h2>"
        )
    }

    @TestCase
    func supportsUnicodeAndTrailingSpacesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "中文标题 with émojis 🚀   \n======================\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<h1 id=\"中文标题-with-émojis\">中文标题 with émojis 🚀</h1>")
                let headingNode = AstTestKit.child(result.root, 0, "Heading1Node")
                if (let heading: HeadingNode <- headingNode) {
                    @Expect(heading.level, 1)
                    @Expect(heading.content, "中文标题 with émojis 🚀")
                    @Expect(heading.slug, "中文标题-with-émojis")
                }
            }
        )
    }

    @TestCase
    func supportsLeadingAndTrailingMarkerWhitespaceAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Heading Text\n   =========   \n",
            "<h1 id=\"heading-text\">Heading Text</h1>"
        )
    }

    @TestCase
    func dividerWithoutPendingParagraphRemainsDividerAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "---\n",
            "<hr />"
        )
    }
}
