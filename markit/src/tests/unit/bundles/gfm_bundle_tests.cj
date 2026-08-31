package markit.tests.unit.bundles

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.commonmark.inline.html_inline.HtmlInlineTagPairingConfig
import markit.tests.utils.ParseModeTestKit

@Test
class GFMBundleTests {
    @TestCase
    func exposesBundleMetadata() {
        let bundle = GFMBundle()

        @Expect(bundle.name, "GFMBundle")
        @Expect(bundle.version, "2.0.0")
        @Expect(bundle.includesStandardMarkdown, true)
        @Expect(bundle.plugins.size > 0, true)
    }

    @TestCase
    func canDisableHtmlInlineTagPairingAtBundleConstruction() {
        let bundle = GFMBundle(
            htmlInlineTagPairingConfig: HtmlInlineTagPairingConfig(enabled: false)
        )

        @Expect(bundle.name, "GFMBundle")
    }

    @TestCase
    func registersGfmInlineAndTaskListFeaturesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(GFMBundle()) },
            "~~strikethrough~~ text\n\n- [x] task list\n",
            "<p><del>strikethrough</del> text</p><ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> task list</li></ul>"
        )
    }

    @TestCase
    func registersTableAutolinkAndFootnoteFeaturesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(GFMBundle()) },
            "| Header 1 | Header 2 |\n|----------|----------|\n| Cell 1   | Cell 2   |\n\nVisit https://github.com or email test@example.com with footnote[^1].\n\n[^1]: This is the footnote.\n",
            "<table><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table><p>Visit <a href=\"https://github.com\">https://github.com</a> or email <a href=\"mailto:test@example.com\">test@example.com</a> with footnote<a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\">1</a>.</p><div id=\"fn:1\" class=\"footnote-definition\">This is the footnote.</div>"
        )
    }

    @TestCase
    func inheritsCommonMarkAndStandardFeaturesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(GFMBundle()) },
            "# Heading\n\nHeading Level 1\n===============\n\nVisit <https://example.com> and **bold** with `code`.\n",
            "<h1 id=\"heading\">Heading</h1><h1 id=\"heading-level-1\">Heading Level 1</h1><p>Visit <a href=\"https://example.com\">https://example.com</a> and <strong>bold</strong> with <code>code</code>.</p>"
        )
    }

    @TestCase
    func differsFromStandardBundleForGfmExtensionsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(GFMBundle()) },
            "~~strikethrough~~ and snake_case_variable\n",
            "<p><del>strikethrough</del> and snake_case_variable</p>"
        )

        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "~~strikethrough~~ and snake_case_variable\n",
            "<p>~~strikethrough~~ and snake_case_variable</p>"
        )
    }

    @TestCase
    func parsingIsDeterministicAcrossNewBundleInstances() {
        let markdown = "# GFM Test\n\n~~strikethrough~~ and **bold**\n\n- [x] Task\n"
        let first = Markit(GFMBundle()).parse(markdown).toJson()
        let second = Markit(GFMBundle()).parse(markdown).toJson()

        @Expect(first, second)
    }
}
