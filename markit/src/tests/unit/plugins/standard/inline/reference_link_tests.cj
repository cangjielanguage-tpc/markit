package markit.tests.unit.plugins.standard.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.tests.utils.ParseModeTestKit

@Test
class ReferenceLinkTests {
    @TestCase
    func basicReferenceLinkWithTitle() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[ref1]: https://example.com \"Example\"\n\n[click here][ref1]\n",
            "<p><a href=\"https://example.com\" title=\"Example\">click here</a></p>"
        )
    }

    @TestCase
    func basicReferenceLinkWithoutTitle() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[ref1]: https://example.com\n\n[click here][ref1]\n",
            "<p><a href=\"https://example.com\">click here</a></p>"
        )
    }

    @TestCase
    func shorthandReferenceLinkEmptyBrackets() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[foo]: /url\n\n[foo][]\n",
            "<p><a href=\"/url\">foo</a></p>"
        )
    }

    @TestCase
    func shorthandReferenceLinkImplicit() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[foo]: /url\n\n[foo]\n",
            "<p><a href=\"/url\">foo</a></p>"
        )
    }

    @TestCase
    func referenceLinkCaseInsensitive() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[REF1]: https://example.com\n\n[click here][ref1]\n",
            "<p><a href=\"https://example.com\">click here</a></p>"
        )
    }

    @TestCase
    func referenceLinkMixedCase() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[ref1]: https://example.com\n\n[click here][REF1]\n",
            "<p><a href=\"https://example.com\">click here</a></p>"
        )
    }

    @TestCase
    func undefinedReferenceLinkFallsBackToText() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[undefined link][nonexistent]\n",
            "<p>[undefined link][nonexistent]</p>"
        )
    }

    @TestCase
    func undefinedShorthandReferenceLinkFallsBackToText() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[undefined][] and ![missing][]\n",
            "<p>[undefined][] and ![missing][]</p>"
        )
    }

    @TestCase
    func referenceLinkWithUnicodeText() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[链接]: https://example.com \"标题\"\n\n[中文链接][链接]\n",
            "<p><a href=\"https://example.com\" title=\"标题\">中文链接</a></p>"
        )
    }

    @TestCase
    func referenceLinkInMiddleOfSentence() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[example]: https://example.com\n\nSee [this example][example] for details.\n",
            "<p>See <a href=\"https://example.com\">this example</a> for details.</p>"
        )
    }

    @TestCase
    func multipleReferenceLinks() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[foo]: /foo\n[bar]: /bar\n\n[foo link][foo] and [bar link][bar]\n",
            "<p><a href=\"/foo\">foo link</a> and <a href=\"/bar\">bar link</a></p>"
        )
    }

    @TestCase
    func duplicateDefinitionFirstWins() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[foo]: /first\n[foo]: /second\n\n[foo]\n",
            "<p><a href=\"/first\">foo</a></p>"
        )
    }

    @TestCase
    func basicImageReference() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[logo]: /images/logo.png \"Logo\"\n\n![alt text][logo]\n",
            "<p><img src=\"/images/logo.png\" alt=\"alt text\" title=\"Logo\" /></p>"
        )
    }

    @TestCase
    func imageReferenceWithoutTitle() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[logo]: /images/logo.png\n\n![alt text][logo]\n",
            "<p><img src=\"/images/logo.png\" alt=\"alt text\" /></p>"
        )
    }

    @TestCase
    func imageReferenceShorthand() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[logo]: /images/logo.png\n\n![logo]\n",
            "<p><img src=\"/images/logo.png\" alt=\"logo\" /></p>"
        )
    }

    @TestCase
    func imageReferenceShorthandEmptyBrackets() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[logo]: /images/logo.png\n\n![logo][]\n",
            "<p><img src=\"/images/logo.png\" alt=\"logo\" /></p>"
        )
    }

    @TestCase
    func imageReferenceCaseInsensitiveAndMixedCaseAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[LOGO]: https://example.com/logo.png\n\n![Company Logo][logo] ![Other Logo][LOGO]\n",
            "<p><img src=\"https://example.com/logo.png\" alt=\"Company Logo\" /> <img src=\"https://example.com/logo.png\" alt=\"Other Logo\" /></p>"
        )
    }

    @TestCase
    func imageReferenceWithSpacesAndSpecialCharactersInLabelAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[logo ref]: https://example.com/logo.png\n[logo-1_test.example]: https://example.com/other.png\n\n![Company Logo][logo ref] ![Other][logo-1_test.example]\n",
            "<p><img src=\"https://example.com/logo.png\" alt=\"Company Logo\" /> <img src=\"https://example.com/other.png\" alt=\"Other\" /></p>"
        )
    }

    @TestCase
    func imageReferenceWithNestedAndEscapedAltTextAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[logo]: https://example.com/logo.png\n\n![Company [nested] Logo][logo] ![Company \\[Logo\\]][logo]\n",
            "<p><img src=\"https://example.com/logo.png\" alt=\"Company [nested] Logo\" /> <img src=\"https://example.com/logo.png\" alt=\"Company [Logo]\" /></p>"
        )
    }

    @TestCase
    func imageReferenceWithEmptyAndUnicodeAltAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[logo]: https://example.com/image.jpg\n\n![][logo] ![中文图片 émojis 🚀][logo]\n",
            "<p><img src=\"https://example.com/image.jpg\" alt=\"\" /> <img src=\"https://example.com/image.jpg\" alt=\"中文图片 émojis 🚀\" /></p>"
        )
    }

    @TestCase
    func multipleImageReferencesAndDuplicateDefinitionsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[logo1]: first.jpg\n[logo2]: second.png\n[logo1]: ignored.jpg\n\n![first][logo1] and ![second][logo2]\n",
            "<p><img src=\"first.jpg\" alt=\"first\" /> and <img src=\"second.png\" alt=\"second\" /></p>"
        )
    }

    @TestCase
    func imageReferenceUndefined() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "![alt][missing]\n",
            "<p>![alt][missing]</p>"
        )
    }

    @TestCase
    func referenceLinksWithEscapedTextResolveAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[ref1]: https://example.com\n\n[link \\[with\\] escapes][ref1]\n",
            "<p><a href=\"https://example.com\">link [with] escapes</a></p>"
        )
    }

    @TestCase
    func forwardReferencesStillResolveAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[example][ref1]\n\n[ref1]: https://example.com \"Example Title\"\n",
            "<p><a href=\"https://example.com\" title=\"Example Title\">example</a></p>"
        )
    }

    @TestCase
    func mixedLinkAndImageReferences() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[ref]: /url \"Title\"\n\n[link text][ref] and ![alt][ref]\n",
            "<p><a href=\"/url\" title=\"Title\">link text</a> and <img src=\"/url\" alt=\"alt\" title=\"Title\" /></p>"
        )
    }

    @TestCase
    func linkDefinitionWithAngleBracketUrl() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[ref]: <https://example.com/path> \"Title\"\n\n[text][ref]\n",
            "<p><a href=\"https://example.com/path\" title=\"Title\">text</a></p>"
        )
    }

    @TestCase
    func linkDefinitionWithParenthesesTitle() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[ref]: /url (title with parens)\n\n[text][ref]\n",
            "<p><a href=\"/url\" title=\"title with parens\">text</a></p>"
        )
    }
}
