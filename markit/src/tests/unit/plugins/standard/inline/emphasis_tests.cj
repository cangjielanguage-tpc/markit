package markit.tests.unit.plugins.standard.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.tests.utils.ParseModeTestKit

@Test
class EmphasisTests {
    @TestCase
    func rendersBasicBoldFormsAcrossModes() {
        assertHtml("**bold text**", "<p><strong>bold text</strong></p>")
        assertHtml("__bold text__", "<p><strong>bold text</strong></p>")
    }

    @TestCase
    func rendersBoldInSentenceAcrossModes() {
        assertHtml(
            "This is **bold** text.",
            "<p>This is <strong>bold</strong> text.</p>"
        )
    }

    @TestCase
    func rendersBoldWithSpecialNumbersAndUnicodeAcrossModes() {
        assertHtml(
            "**bold !@#$%^&*() text**",
            "<p><strong>bold !@#$%^&amp;*() text</strong></p>"
        )
        assertHtml("**123 bold 456**", "<p><strong>123 bold 456</strong></p>")
        assertHtml("**中文粗体 émojis 🚀**", "<p><strong>中文粗体 émojis 🚀</strong></p>")
    }

    @TestCase
    func keepsEscapedBoldMarkersLiteralAcrossModes() {
        assertHtml("\\*\\*not bold\\*\\*", "<p>**not bold**</p>")
        assertHtml("\\_\\_not bold\\_\\_", "<p>__not bold__</p>")
    }

    @TestCase
    func preservesLegacyPartiallyEscapedBoldShapeAcrossModes() {
        assertHtml("\\**still bold**", "<p>*<em>still bold</em>*</p>")
    }

    @TestCase
    func rendersBoldWithInternalMarkersAndMultipleRunsAcrossModes() {
        assertHtml(
            "**bold * with * asterisks**",
            "<p><strong>bold * with * asterisks</strong></p>"
        )
        assertHtml(
            "**first bold** and **second bold**",
            "<p><strong>first bold</strong> and <strong>second bold</strong></p>"
        )
    }

    @TestCase
    func keepsInvalidBoldFormsLiteralAcrossModes() {
        assertHtml("**  bold with spaces  **", "<p>**  bold with spaces  **</p>")
        assertHtml("****", "<hr />")
    }

    @TestCase
    func rendersBasicItalicFormsAcrossModes() {
        assertHtml("*italic text*", "<p><em>italic text</em></p>")
        assertHtml("_italic text_", "<p><em>italic text</em></p>")
    }

    @TestCase
    func rendersItalicInSentenceAcrossModes() {
        assertHtml(
            "This is *italic* text.",
            "<p>This is <em>italic</em> text.</p>"
        )
    }

    @TestCase
    func rendersItalicWithSpecialNumbersAndUnicodeAcrossModes() {
        assertHtml(
            "*italic !@#$%^&*() text*",
            "<p><em>italic !@#$%^&amp;</em>() text*</p>"
        )
        assertHtml("*123 italic 456*", "<p><em>123 italic 456</em></p>")
        assertHtml("*中文斜体 émojis 🚀*", "<p><em>中文斜体 émojis 🚀</em></p>")
    }

    @TestCase
    func keepsEscapedItalicMarkersLiteralAcrossModes() {
        assertHtml("\\*not italic\\*", "<p>*not italic*</p>")
        assertHtml("\\_not italic\\_", "<p>_not italic_</p>")
    }

    @TestCase
    func keepsPartiallyEscapedItalicLiteralAcrossModes() {
        assertHtml("\\*still italic*", "<p>*still italic*</p>")
    }

    @TestCase
    func keepsWhitespaceSurroundedInternalItalicMarkersInsideRunAcrossModes() {
        assertHtml(
            "*italic * with * asterisks*",
            "<p><em>italic * with * asterisks</em></p>"
        )
    }

    @TestCase
    func rendersMultipleItalicRunsAcrossModes() {
        assertHtml(
            "*first italic* and *second italic*",
            "<p><em>first italic</em> and <em>second italic</em></p>"
        )
    }

    @TestCase
    func keepsInvalidItalicFormsLiteralAcrossModes() {
        assertHtml("*  italic with spaces  *", "<ul><li>italic with spaces  *</li></ul>")
        assertHtml("**", "<p>**</p>")
        assertHtml("word_with_underscores", "<p>word_with_underscores</p>")
    }

    @TestCase
    func rendersBoldItalicAndNestedInlineCodeAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "这是 **粗体 *斜体* 和 `代码`**。\n",
            "<p>这是 <strong>粗体 <em>斜体</em> 和 <code>代码</code></strong>。</p>"
        )
    }

    @TestCase
    func keepsInvalidWhitespaceDelimitedEmphasisLiteralAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "** 粗体失败 ** 和 * 斜体失败 *\n",
            "<p>** 粗体失败 ** 和 * 斜体失败 *</p>"
        )
    }

    private func assertHtml(markdown: String, expectedHtml: String): Unit {
        ParseModeTestKit.assertHtmlAcrossModes({ => Markit() }, markdown, expectedHtml)
    }
}
