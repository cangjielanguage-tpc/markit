package markit.tests.unit.plugins.standard.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.plugins.standard.inline.link.{FileTree, HeadingInfo, LinkConfig, LinkPlugin, RenderMode}
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func withLinkConfig(config: LinkConfig): Markit {
    return Markit(StandardMarkdownBundle(linkConfig: config))
}

@Test
class LinkSmartResolutionTests {
    @TestCase
    func convertsMarkdownFileLinksAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[guide](guide.md) [section](guide.md#introduction) [PDF](file.pdf) [external](https://example.com)\n",
            "<p><a href=\"guide.html\">guide</a> <a href=\"guide.html#introduction\">section</a> <a href=\"file.pdf\">PDF</a> <a href=\"https://example.com\">external</a></p>"
        )
    }

    @TestCase
    func convertsMarkdownFileLinksWithTitlesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "[guide](guide.md \"User Guide\") [docs](docs/readme.md 'Docs Home')\n",
            "<p><a href=\"guide.html\" title=\"User Guide\">guide</a> <a href=\"docs/readme.html\" title=\"Docs Home\">docs</a></p>"
        )
    }

    @TestCase
    func resolvesTildeAndHashTildeAnchorsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "[My Heading](~) and [Local Only](#~) and [中文标题](~)\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><a href=\"#my-heading\">My Heading</a> and <a href=\"#local-only\">Local Only</a> and <a href=\"#中文标题\">中文标题</a></p>")
                @Expect(result.typst, "#link(<my-heading>)[My Heading] and #link(<local-only>)[Local Only] and #link(<中文标题>)[中文标题]\n\n")
            }
        )
    }

    @TestCase
    func resolvesHeadingTextThroughFileTreeAcrossModes() {
        let fileTree = FileTree(["README.md", "guide.md"])
        fileTree.addHeading(HeadingInfo("中文标题", "中文标题", "README.md", 1))
        fileTree.addHeading(HeadingInfo("Configuration", "configuration", "guide.md", 2))

        ParseModeTestKit.assertHtmlAcrossModes(
            { => withLinkConfig(LinkConfig(fileTree: Some(fileTree))) },
            "[中文标题](~) and [Configuration](~)\n",
            "<p><a href=\"README.html#中文标题\">中文标题</a> and <a href=\"guide.html#configuration\">Configuration</a></p>"
        )
    }

    @TestCase
    func multipleHeadingMatchesRenderWarningAcrossModes() {
        let fileTree = FileTree(["README.md", "guide.md", "tutorial.md"])
        fileTree.addHeading(HeadingInfo("Getting Started", "getting-started", "README.md", 1))
        fileTree.addHeading(HeadingInfo("Getting Started", "getting-started", "guide.md", 2))
        fileTree.addHeading(HeadingInfo("Getting Started", "getting-started", "tutorial.md", 1))

        ParseModeTestKit.assertAcrossModes(
            { => withLinkConfig(LinkConfig(fileTree: Some(fileTree))) },
            "[Getting Started](~)\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><a href=\"README.html#getting-started\">Getting Started <span class=\"link-error\">[❌ Multiple headings match &#39;Getting Started&#39;: README.md, guide.md, tutorial.md]</span></a></p>")
            }
        )
    }

    @TestCase
    func fuzzyMatchResolvesFilesAndWarningsAcrossModes() {
        let fileTree = FileTree(["intro.md", "introduction.md", "intro-guide.md"])

        ParseModeTestKit.assertAcrossModes(
            { => withLinkConfig(LinkConfig(fileTree: Some(fileTree))) },
            "[Introduction](intro*.md#~)\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><a href=\"intro.html#introduction\">Introduction <span class=\"link-error\">[❌ Multiple files match pattern &#39;intro*.md&#39;: intro.md, introduction.md, intro-guide.md]</span></a></p>")
            }
        )
    }

    @TestCase
    func fuzzyMatchReportsMissingFileTreeAndNoMatchesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => withLinkConfig(LinkConfig(fileTree: None)) },
            "[Missing](docs/*#~)\n",
            "<p><a href=\"docs/*#~\">Missing <span class=\"link-error\">[❌ FileTree not available]</span></a></p>"
        )

        let fileTree = FileTree(["README.md", "guide.md"])
        ParseModeTestKit.assertHtmlAcrossModes(
            { => withLinkConfig(LinkConfig(fileTree: Some(fileTree))) },
            "[Not Found](nonexistent*/~)\n",
            "<p><a href=\"nonexistent*/~\">Not Found <span class=\"link-error\">[❌ No files match pattern &#39;nonexistent*&#39;]</span></a></p>"
        )
    }

    @TestCase
    func fuzzyMatchWithSubdirectoryReportsExactMultipleMatchesAcrossModes() {
        let fileTree = FileTree(["docs/en/config.md", "docs/zh/config.md"])

        ParseModeTestKit.assertHtmlAcrossModes(
            { => withLinkConfig(LinkConfig(fileTree: Some(fileTree))) },
            "[Configuration](docs/*/config.md#~)\n",
            "<p><a href=\"docs/en/config.html#configuration\">Configuration <span class=\"link-error\">[❌ Multiple files match pattern &#39;docs/*/config.md&#39;: docs/en/config.md, docs/zh/config.md]</span></a></p>"
        )
    }

    @TestCase
    func fuzzyMatchNumericPatternsResolveAcrossModes() {
        let fileTree = FileTree([
            "Chapter_00_Introduction.md",
            "Chapter_01_Lexical_Sturcture.md",
            "Chapter_02_Types.md"
        ])
        fileTree.addHeading(HeadingInfo("Lexical Structure", "lexical-structure", "Chapter_01_Lexical_Sturcture.md", 1))

        ParseModeTestKit.assertHtmlAcrossModes(
            { => withLinkConfig(LinkConfig(fileTree: Some(fileTree))) },
            "[Lexical Structure](*01*#~)\n",
            "<p><a href=\"Chapter_01_Lexical_Sturcture.html#lexical-structure\">Lexical Structure</a></p>"
        )
    }

    @TestCase
    func fuzzyMatchNumericPatternsUseCurrentRootFileAcrossModes() {
        let fileTree = FileTree([
            "Chapter_00_Introduction.md",
            "Chapter_01_Lexical_Sturcture.md",
            "Chapter_02_Types.md"
        ])
        fileTree.addHeading(HeadingInfo("Lexical Structure", "lexical-structure", "Chapter_01_Lexical_Sturcture.md", 1))

        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => withLinkConfig(LinkConfig(
                    fileTree: Some(fileTree),
                    currentFilePath: "Chapter_02_Types.html"
                ))
            },
            "[Lexical Structure](*01*#~)\n",
            "<p><a href=\"Chapter_01_Lexical_Sturcture.html#lexical-structure\">Lexical Structure</a></p>"
        )
    }

    @TestCase
    func flatModeCollapsesCrossFileLinksAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => withLinkConfig(LinkConfig(renderMode: RenderMode.Flat)) },
            "[Configuration](guide.md#configuration)\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><a href=\"#configuration\">Configuration</a></p>")
                @Expect(result.typst, "#link(<configuration>)[Configuration]\n\n")
            }
        )
    }

    @TestCase
    func flatTypstModeCanPreserveTargetFileAcrossModes() {
        let fileTree = FileTree(["README.md", "guide.md"])
        fileTree.addHeading(HeadingInfo("Configuration", "configuration", "guide.md", 2))
        let config = LinkConfig(
            fileTree: Some(fileTree),
            renderMode: RenderMode.Flat,
            outputExtension: "typ",
            preserveFlatFilePaths: true
        )

        ParseModeTestKit.assertAcrossModes(
            { => withLinkConfig(config) },
            "[Configuration](~) and [Direct](guide.md#configuration)\n",
            { result: ParseModeResult =>
                @Expect(result.typst, "#link(\"guide.typ#configuration\")[Configuration] and #link(\"guide.typ#configuration\")[Direct]\n\n")
            }
        )
    }

    @TestCase
    func pluginInstanceResolverSupportsCurrentFileRelativeFuzzyMatch() {
        let fileTree = FileTree(["dir/aaa.md", "dir/bbb.md", "other/bbb.md"])
        fileTree.addHeading(HeadingInfo("Title", "title", "dir/bbb.md", 1))
        fileTree.addHeading(HeadingInfo("Title", "title", "other/bbb.md", 1))

        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => withLinkConfig(LinkConfig(
                    fileTree: Some(fileTree),
                    currentFilePath: "dir/aaa.html"
                ))
            },
            "[Title](*b*.md#~)\n",
            "<p><a href=\"bbb.html#title\">Title</a></p>"
        )
    }
}
