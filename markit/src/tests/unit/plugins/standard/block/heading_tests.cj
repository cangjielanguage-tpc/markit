package markit.tests.unit.plugins.standard.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.plugins.standard.block.heading.{HeadingClosableConfig, HeadingNumberingConfig, HeadingSlugConfig}
import markit.tests.utils.ParseModeTestKit

@Test
class HeadingTests {
    @TestCase
    func rendersUnicodeHeadingWithLeadingSpaces() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "   ### 中文标题 with slug\n",
            "<h3 id=\"中文标题-with-slug\">中文标题 with slug</h3>"
        )
    }

    @TestCase
    func rendersAllHeadingLevelsAndTrimsTrailingSpaces() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "# H1   \n## H2\n### H3\n#### H4\n##### H5\n###### H6\n",
            "<h1 id=\"h1\">H1</h1><h2 id=\"h2\">H2</h2><h3 id=\"h3\">H3</h3><h4 id=\"h4\">H4</h4><h5 id=\"h5\">H5</h5><h6 id=\"h6\">H6</h6>"
        )
    }

    @TestCase
    func slugDropsEmojiAndSpecialCharacters() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "## Getting Started 🚀\n#### Special Characters: @#$%\n",
            "<h2 id=\"getting-started\">Getting Started 🚀</h2><h4 id=\"special-characters\">Special Characters: @#$%</h4>"
        )
    }

    @TestCase
    func invalidHeadingSyntaxFallsBackToParagraph() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "###中文\n####### too many\n",
            "<p>###中文\n####### too many</p>"
        )
    }

    @TestCase
    func numberingCanBeEnabledThroughCustomStandardBundle() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit(StandardMarkdownBundle(
                    headingNumberingConfig: HeadingNumberingConfig(enabled: true)
                ))
            },
            "# 第一章\n## 第二节\n",
            "<h1 id=\"第一章\" data-number=\"1\">1 第一章</h1><h2 id=\"第二节\" data-number=\"1.1\">1.1 第二节</h2>"
        )
    }

    @TestCase
    func numberingHonorsCustomStartValues() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit(StandardMarkdownBundle(
                    headingNumberingConfig: HeadingNumberingConfig(
                        enabled: true,
                        startFrom: (3, 1, 1, 1, 1, 1)
                    )
                ))
            },
            "# Alpha\n## Beta\n# Gamma\n",
            "<h1 id=\"alpha\" data-number=\"3\">3 Alpha</h1><h2 id=\"beta\" data-number=\"3.1\">3.1 Beta</h2><h1 id=\"gamma\" data-number=\"4\">4 Gamma</h1>"
        )
    }

    @TestCase
    func numberingInitialCountersDoNotBecomeResetStartValues() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit(StandardMarkdownBundle(
                    headingNumberingConfig: HeadingNumberingConfig(
                        enabled: true,
                        initialCounters: Some([1, 2, 0, 0, 0, 0])
                    )
                ))
            },
            "# Next\n## First child\n",
            "<h1 id=\"next\" data-number=\"2\">2 Next</h1><h2 id=\"first-child\" data-number=\"2.1\">2.1 First child</h2>"
        )
    }

    @TestCase
    func numberingCanBeHiddenFromHtml() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit(StandardMarkdownBundle(
                    headingNumberingConfig: HeadingNumberingConfig(
                        enabled: true,
                        includeInHtml: false
                    )
                ))
            },
            "# No Prefix\n",
            "<h1 id=\"no-prefix\" data-number=\"1\">1 No Prefix</h1>"
        )
    }

    @TestCase
    func closableHeadingRemovesItsSection() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit(StandardMarkdownBundle(
                    closableConfig: HeadingClosableConfig(enabled: true)
                ))
            },
            "## 隐藏章节 ##\n\n这一段会被隐藏\n\n### 子节\n\n也会隐藏\n\n## 保留章节\n\n留下来\n",
            "<h2 id=\"保留章节\">保留章节</h2><p>留下来</p>"
        )
    }

    @TestCase
    func closableHeadingDisabledKeepsTrailingMarkers() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit(StandardMarkdownBundle(
                    closableConfig: HeadingClosableConfig(enabled: false)
                ))
            },
            "## Visible ##\n\n内容\n",
            "<h2 id=\"visible\">Visible ##</h2><p>内容</p>"
        )
    }

    @TestCase
    func duplicateHeadingsGetUniqueSlugs() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "# Title\n# Title\n",
            "<h1 id=\"title\">Title</h1><h1 id=\"title-2\">Title</h1>"
        )
    }

    @TestCase
    func headingSlugConfigAddsPathLabelsForTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            {
                => Markit(StandardMarkdownBundle(
                    headingSlugConfig: HeadingSlugConfig(
                        currentPagePath: "docs/指南.typ",
                        enablePathLabels: true
                    )
                ))
            },
            "# 中文标题\n# 中文标题\n",
            "= 中文标题 <docs-指南-中文标题>\n\n= 中文标题 <docs-指南-中文标题-2>\n\n"
        )
    }

    @TestCase
    func headingSlugConfigDoesNotChangeHtmlSlugAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit(StandardMarkdownBundle(
                    headingSlugConfig: HeadingSlugConfig(
                        currentPagePath: "docs/page.typ",
                        enablePathLabels: true
                    )
                ))
            },
            "# Title\n# Title\n",
            "<h1 id=\"title\">Title</h1><h1 id=\"title-2\">Title</h1>"
        )
    }
}
