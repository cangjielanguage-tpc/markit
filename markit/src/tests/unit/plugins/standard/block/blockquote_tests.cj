package markit.tests.unit.plugins.standard.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.tests.utils.ParseModeTestKit

@Test
class BlockquoteTests {
    @TestCase
    func rendersBasicBlockquote() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "> 简单引用\n",
            "<blockquote><p>简单引用</p></blockquote>"
        )
    }

    @TestCase
    func supportsLeadingIndentAndMissingSpaceAfterMarker() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "  >前缀后面没有空格\n",
            "<blockquote><p>前缀后面没有空格</p></blockquote>"
        )
    }

    @TestCase
    func supportsLazyContinuationLines() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "> 第一行\n第二行\n",
            "<blockquote><p>第一行\n第二行</p></blockquote>"
        )
    }

    @TestCase
    func blankQuotedLineSplitsParagraphs() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "> 第一段\n>\n> 第二段\n",
            "<blockquote><p>第一段</p><p>第二段</p></blockquote>"
        )
    }

    @TestCase
    func rendersDeeplyNestedBlockquotes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            """
> Level 1
>> Level 2
>>> Level 3
""",
            "<blockquote><p>Level 1</p><blockquote><p>Level 2</p><blockquote><p>Level 3</p></blockquote></blockquote></blockquote>"
        )
    }

    @TestCase
    func rendersNestedBlockquote() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "> 外层\n> > 内层\n",
            "<blockquote><p>外层</p><blockquote><p>内层</p></blockquote></blockquote>"
        )
    }

    @TestCase
    func rendersListInsideBlockquote() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "> - 第一项\n> - 第二项\n",
            "<blockquote><ul><li>第一项</li><li>第二项</li></ul></blockquote>"
        )
    }

    @TestCase
    func closesBeforeFollowingHeading() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "> 引用\n# 标题\n",
            "<blockquote><p>引用</p></blockquote><h1 id=\"标题\">标题</h1>"
        )
    }

    @TestCase
    func blankLineTerminatesBlockquote() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            """
> Quote

Not quote
""",
            "<blockquote><p>Quote</p></blockquote><p>Not quote</p>"
        )
    }

    @TestCase
    func preservesSpecialCharactersUnicodeAndTrailingSpaces() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "> 中文引用 with émojis 🚀 and !@#$%^&*()   \n",
            "<blockquote><p>中文引用 with émojis 🚀 and !@#$%^&amp;*()   </p></blockquote>"
        )
    }

    @TestCase
    func emptyBlockquoteIsStillEmitted() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            ">\n",
            "<blockquote></blockquote>"
        )
    }
}
