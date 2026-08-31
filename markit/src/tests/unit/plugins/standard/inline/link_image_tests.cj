package markit.tests.unit.plugins.standard.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.Node
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class LinkImageTests {
    @TestCase
    func rendersBasicLinksAndTitlesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[link text](http://example.com) [with title](http://example.com \"Link Title\")\n",
            "<p><a href=\"http://example.com\">link text</a> <a href=\"http://example.com\" title=\"Link Title\">with title</a></p>"
        )
    }

    @TestCase
    func rendersLinksInSentenceAndRelativeTargetsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "This is a [link](http://example.com) in text. [relative link](../path/to/file.html)\n",
            "<p>This is a <a href=\"http://example.com\">link</a> in text. <a href=\"../path/to/file.html\">relative link</a></p>"
        )
    }

    @TestCase
    func preservesLegacyNestedParenthesisDestinationShapeAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[link](http://example.com/path(with)parens)\n",
            "<p><a href=\"http://example.com/path(with\">link</a>parens)</p>"
        )
    }

    @TestCase
    func rendersLinksWithUnicodeTextAndTitleAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[中文链接](https://example.com \"标题\")\n",
            "<p><a href=\"https://example.com\" title=\"标题\">中文链接</a></p>"
        )
    }

    @TestCase
    func rendersImagesWithUnicodeAltAndTitleAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "![示例图](images/demo.png \"图题\")\n",
            "<p><img src=\"images/demo.png\" alt=\"示例图\" title=\"图题\" /></p>"
        )
    }

    @TestCase
    func rendersBasicImagesAndTitlesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "![alt text](http://example.com/image.jpg) ![with title](http://example.com/image.jpg \"Image Title\")\n",
            "<p><img src=\"http://example.com/image.jpg\" alt=\"alt text\" /> <img src=\"http://example.com/image.jpg\" alt=\"with title\" title=\"Image Title\" /></p>"
        )
    }

    @TestCase
    func rendersImagesInSentenceRelativeTargetsAndSpecialAltAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "This is an ![image](http://example.com/img.jpg) in text. ![relative image](../images/photo.png) ![alt !@#$%^&*() text](http://example.com/image.jpg)\n",
            "<p>This is an <img src=\"http://example.com/img.jpg\" alt=\"image\" /> in text. <img src=\"../images/photo.png\" alt=\"relative image\" /> <img src=\"http://example.com/image.jpg\" alt=\"alt !@#$%^&amp;*() text\" /></p>"
        )
    }

    @TestCase
    func rendersLinksWithSingleQuoteTitleAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[link text](http://example.com 'Link Title')\n",
            "<p><a href=\"http://example.com\" title=\"Link Title\">link text</a></p>"
        )
    }

    @TestCase
    func rendersLinksWithNestedBracketsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[link [with] brackets](http://example.com)\n",
            "<p><a href=\"http://example.com\">link [with] brackets</a></p>"
        )
    }

    @TestCase
    func rendersMultipleLinksInSameParagraphAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[first link](http://first.com) and [second link](http://second.com)\n",
            "<p><a href=\"http://first.com\">first link</a> and <a href=\"http://second.com\">second link</a></p>"
        )
    }

    @TestCase
    func rendersLinkWithFragmentAndQueryAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[fragment](http://example.com#section) [query](http://example.com?param=value&other=123)\n",
            "<p><a href=\"http://example.com#section\">fragment</a> <a href=\"http://example.com?param=value&amp;other=123\">query</a></p>"
        )
    }

    @TestCase
    func keepsEscapedLinkBracketsLiteralAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "\\[not a link\\](http://example.com)\n",
            "<p>[not a link](http://example.com)</p>"
        )
    }

    @TestCase
    func keepsEscapedImageBracketsLiteralAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "!\\[not an image\\](http://example.com/image.jpg)\n",
            "<p>![not an image](http://example.com/image.jpg)</p>"
        )
    }

    @TestCase
    func processesEscapesInsideLinkTextWithoutParsingThemAsEmphasisAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "[link \\*with\\* escapes](http://example.com)\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><a href=\"http://example.com\">link *with* escapes</a></p>")
                @Expect(countNodes(result.root, "ItalicNode"), 0)
            }
        )
    }

    @TestCase
    func supportsEmptyLinkTextAndUrlAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[](http://example.com) and [link text]()\n",
            "<p><a href=\"http://example.com\"></a> and <a href=\"\">link text</a></p>"
        )
    }

    @TestCase
    func rendersImagesWithSingleQuoteTitleAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "![alt text](http://example.com/image.jpg 'Image Title')\n",
            "<p><img src=\"http://example.com/image.jpg\" alt=\"alt text\" title=\"Image Title\" /></p>"
        )
    }

    @TestCase
    func rendersMultipleImagesAndDifferentExtensionsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "![png](image.png) ![jpg](image.jpg) ![gif](image.gif) ![svg](image.svg)\n",
            "<p><img src=\"image.png\" alt=\"png\" /> <img src=\"image.jpg\" alt=\"jpg\" /> <img src=\"image.gif\" alt=\"gif\" /> <img src=\"image.svg\" alt=\"svg\" /></p>"
        )
    }

    @TestCase
    func rendersImageAltWithNestedBracketsEscapesAndEmptyFieldsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "![alt [with] \\*escapes\\*](http://example.com/image.jpg) ![alt text]() ![](http://example.com/empty-alt.png)\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<p><img src=\"http://example.com/image.jpg\" alt=\"alt [with] *escapes*\" /> <img src=\"\" alt=\"alt text\" /> <img src=\"http://example.com/empty-alt.png\" alt=\"\" /></p>"
                )
                @Expect(countNodes(result.root, "ImageNode"), 3)
            }
        )
    }

    @TestCase
    func rendersImageWithQueryAndDataUrlAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "![image](http://example.com/image.jpg?size=large&format=png) ![data image](data:image/png;base64,abc123)\n",
            "<p><img src=\"http://example.com/image.jpg?size=large&amp;format=png\" alt=\"image\" /> <img src=\"data:image/png;base64,abc123\" alt=\"data image\" /></p>"
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
