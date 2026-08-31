package markit.tests.unit.plugins.standard.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.tests.utils.ParseModeTestKit

@Test
class ParagraphTests {
    @TestCase
    func preservesSoftBreaksInMultilineChineseParagraph() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "第一行\n第二行\n\n",
            "<p>第一行\n第二行</p>"
        )
    }

    @TestCase
    func trimsLeadingIndentButKeepsTrailingSpaces() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "   中文段落   \n",
            "<p>中文段落 <br /></p>"
        )
    }

    @TestCase
    func rendersSingleLineTrailingSpacesAsTerminalHardBreak() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "This paragraph has trailing spaces.   \n",
            "<p>This paragraph has trailing spaces. <br /></p>"
        )
    }

    @TestCase
    func tabIndentedParagraphIsStillParagraph() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "\t这是一段中文\n",
            "<p>这是一段中文</p>"
        )
    }

    @TestCase
    func mixedIndentationOnlyTrimsTheFront() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            " \t Mixed indentation  \n",
            "<p>Mixed indentation<br /></p>"
        )
    }

    @TestCase
    func specialCharactersAndUnicodeStayLiteral() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "段落包含中文字符 and émojis 🚀.\n",
            "<p>段落包含中文字符 and émojis 🚀.</p>"
        )
    }

    @TestCase
    func whitespaceOnlyInputProducesEmptyHtml() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "   \t  \n  ",
            ""
        )
    }
}
