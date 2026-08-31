package markit.tests.unit.bundles

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.commonmark.inline.html_inline.HtmlInlineTagPairingConfig
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class CommonMarkBundleTests {
    @TestCase
    func exposesBundleMetadata() {
        let bundle = CommonMarkBundle()

        @Expect(bundle.name, "CommonMarkBundle")
        @Expect(bundle.version, "2.0.0")
        @Expect(bundle.includesStandardMarkdown, true)
        @Expect(bundle.plugins.size > 0, true)
    }

    @TestCase
    func canDisableHtmlInlineTagPairingAtBundleConstruction() {
        let bundle = CommonMarkBundle(
            htmlInlineTagPairingConfig: HtmlInlineTagPairingConfig(enabled: false)
        )

        @Expect(bundle.name, "CommonMarkBundle")
    }

    @TestCase
    func registersSetextHeadingWithExactAstAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit(CommonMarkBundle()) },
            "Heading Level 1\n===============\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<h1 id=\"heading-level-1\">Heading Level 1</h1>")
                expectSetextHeadingDocument(result.root)
            }
        )
    }

    @TestCase
    func registersHtmlBlockAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(CommonMarkBundle()) },
            "<div>\n  <p>HTML content</p>\n</div>\n",
            "<div>\n  <p>HTML content</p>\n</div>\n"
        )
    }

    @TestCase
    func registersCommonMarkInlineFeaturesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(CommonMarkBundle()) },
            "Text with <span>inline HTML</span> and <https://example.com> plus &amp;.\n",
            "<p>Text with <span>inline HTML</span> and <a href=\"https://example.com\">https://example.com</a> plus &amp;.</p>"
        )
    }

    @TestCase
    func retainsStandardMarkdownFeaturesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(CommonMarkBundle()) },
            "# Heading",
            "<h1 id=\"heading\">Heading</h1>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(CommonMarkBundle()) },
            "**Bold** and *italic* with `code`.",
            "<p><strong>Bold</strong> and <em>italic</em> with <code>code</code>.</p>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(CommonMarkBundle()) },
            "- List item\n- Another item",
            "<ul><li>List item</li><li>Another item</li></ul>"
        )
    }

    @TestCase
    func differsFromStandardBundleForSetextHeadingAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(CommonMarkBundle()) },
            "Heading\n=======\n",
            "<h1 id=\"heading\">Heading</h1>"
        )

        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "Heading\n=======\n",
            "<p>Heading\n=======</p>"
        )
    }

    @TestCase
    func parsingIsDeterministicAcrossNewBundleInstances() {
        let markdown = "# CommonMark Test\n\nHeading\n=======\n\n&amp; **bold**\n"
        let first = Markit(CommonMarkBundle()).parse(markdown).toJson()
        let second = Markit(CommonMarkBundle()).parse(markdown).toJson()

        @Expect(first, second)
    }

    private func expectSetextHeadingDocument(root: Node): Unit {
        @Expect(root.name, "DocumentNode")
        @Expect(root.children.size, 1)
        if (let heading: HeadingNode <- root.children[0]) {
            @Expect(heading.level, 1)
            @Expect(heading.content, "Heading Level 1")
            @Expect(heading.slug, "heading-level-1")
            @Expect(heading.children.size, 1)
            if (let text: TextNode <- heading.children[0]) {
                @Expect(text.content, "Heading Level 1")
                @Expect(text.children.size, 0)
            } else {
                @Expect(heading.children[0].name, "TextNode")
            }
        } else {
            @Expect(root.children[0].name, "Heading1Node")
        }
    }
}
