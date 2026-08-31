package markit.tests.unit.plugins.toc

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.standard.block.heading.HeadingNumberingConfig
import markit.plugins.toc.{Toc, TocItem}
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle())
}

private func numberedGfm(): Markit {
    return Markit(GFMBundle(
        headingNumberingConfig: HeadingNumberingConfig(enabled: true)
    ))
}

@Test
class TocGenerationTests {
    @TestCase
    func buildsHierarchyFromParsedHeadingsAcrossModes() {
        let markdown = "# Introduction\n\n## Getting Started\n\n### Installation\n\n## Usage\n\n# Advanced Features\n"
        ParseModeTestKit.assertAcrossModes(
            gfm,
            markdown,
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.items.size, 2)
                @Expect(tocNode.items[0].text, "Introduction")
                @Expect(tocNode.items[0].anchorId, "introduction")
                @Expect(tocNode.items[0].children.size, 2)
                if (let firstH2: TocItem <- tocNode.items[0].children[0]) {
                    @Expect(firstH2.text, "Getting Started")
                    @Expect(firstH2.children.size, 1)
                    if (let firstH3: TocItem <- firstH2.children[0]) {
                        @Expect(firstH3.text, "Installation")
                        @Expect(firstH3.anchorId, "installation")
                    } else {
                        @Expect(true, false)
                    }
                } else {
                    @Expect(true, false)
                }
                @Expect(tocNode.toHtml(), expectedHierarchyHtml())
                @Expect(tocNode.name, "TocNode")
            }
        )
    }

    @TestCase
    func filtersLevelsAndSupportsCustomTitleAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "# 一\n\n## 二\n\n### 三\n",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root, title: "目录", minLevel: 1, maxLevel: 2)
                @Expect(tocNode.title, "目录")
                @Expect(tocNode.items.size, 1)
                @Expect(tocNode.items[0].children.size, 1)
                if (let child: TocItem <- tocNode.items[0].children[0]) {
                    @Expect(child.text, "二")
                    @Expect(child.children.size, 0)
                } else {
                    @Expect(true, false)
                }
                @Expect(
                    tocNode.toHtml(),
                    "<h2>目录</h2><nav class=\"toc\" role=\"navigation\" aria-label=\"Table of contents\"><ul><li class=\"toc-level-1\"><a href=\"#一\">一</a><ul><li class=\"toc-level-2\"><a href=\"#二\">二</a></li></ul></li></ul></nav>"
                )
            }
        )
    }

    @TestCase
    func includesNumberedHeadingsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            numberedGfm,
            "# Intro\n\n## Start\n\n### Install\n\n## Usage\n\n# Advanced\n",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.items.size, 2)
                @Expect(tocNode.items[0].number, "1")
                @Expect(tocNode.items[0].children.size, 2)
                if (let child: TocItem <- tocNode.items[0].children[0]) {
                    @Expect(child.number, "1.1")
                    @Expect(child.children.size, 1)
                    if (let grandChild: TocItem <- child.children[0]) {
                        @Expect(grandChild.number, "1.1.1")
                    } else {
                        @Expect(true, false)
                    }
                } else {
                    @Expect(true, false)
                }
                @Expect(tocNode.items[1].number, "2")
                @Expect(tocNode.toHtml(), expectedNumberedHierarchyHtml())
                @Expect(Toc.generateTextToc(result.root), "- 1 Intro\n  - 1.1 Start\n    - 1.1.1 Install\n  - 1.2 Usage\n- 2 Advanced\n")
            }
        )
    }

    @TestCase
    func supportsTextTocCustomIndentAndDetailedExtractionAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            numberedGfm,
            "# Intro\n\n## Start\n\n### Install\n\n## Usage\n\n# Advanced\n",
            { result: ParseModeResult =>
                let textToc = Toc.generateTextToc(result.root, indent: "    ")
                @Expect(textToc, "- 1 Intro\n    - 1.1 Start\n        - 1.1.1 Install\n    - 1.2 Usage\n- 2 Advanced\n")

                let allHeadings = Toc.extractHeadingList(result.root)
                let detailedAll = Toc.extractDetailedHeadingList(result.root, minLevel: 1, maxLevel: 3)
                let detailedFiltered = Toc.extractDetailedHeadingList(result.root, minLevel: 1, maxLevel: 2)

                @Expect(allHeadings.size, 5)
                @Expect(detailedAll.size, 5)
                @Expect(detailedFiltered.size, 4)
            }
        )
    }

    @TestCase
    func rendersTocToAllTextFormatsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            numberedGfm,
            "# Intro\n\n## Start\n",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.toString(), "TocNode - Table of Contents\n- 1 Intro (level=1, id=intro)\n  - 1.1 Start (level=2, id=start)")
                @Expect(tocNode.toMarkdown(), "## Table of Contents\n\n- [1 Intro](#intro)\n  - [1.1 Start](#start)\n")
                @Expect(tocNode.toTypst(), "= Table of Contents\n\n- 1 Intro\n  - 1.1 Start\n")
                @Expect(tocNode.toJson(), expectedTocJson())
            }
        )
    }

    @TestCase
    func supportsChineseSlugAndDuplicateSlugEdgesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "# 中文 标题\n\n# 中文 标题\n\n## Café 标题\n",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.items.size, 2)
                @Expect(tocNode.items[0].anchorId, "中文-标题")
                @Expect(tocNode.items[1].anchorId, "中文-标题-2")
                if (let child: TocItem <- tocNode.items[1].children[0]) {
                    @Expect(child.anchorId, "café-标题")
                } else {
                    @Expect(true, false)
                }
            }
        )
    }

    @TestCase
    func emptyDocumentProducesEmptyTocAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "plain paragraph\n",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.items.size, 0)
                @Expect(tocNode.toHtml(), "")
                @Expect(Toc.generateTextToc(result.root), "")
            }
        )
    }

    private func expectedHierarchyHtml(): String {
        return "<h2>Table of Contents</h2><nav class=\"toc\" role=\"navigation\" aria-label=\"Table of contents\"><ul><li class=\"toc-level-1\"><a href=\"#introduction\">Introduction</a><ul><li class=\"toc-level-2\"><a href=\"#getting-started\">Getting Started</a><ul><li class=\"toc-level-3\"><a href=\"#installation\">Installation</a></li></ul></li><li class=\"toc-level-2\"><a href=\"#usage\">Usage</a></li></ul></li><li class=\"toc-level-1\"><a href=\"#advanced-features\">Advanced Features</a></li></ul></nav>"
    }

    private func expectedNumberedHierarchyHtml(): String {
        return "<h2>Table of Contents</h2><nav class=\"toc\" role=\"navigation\" aria-label=\"Table of contents\"><ul><li class=\"toc-level-1\"><a href=\"#intro\">1 Intro</a><ul><li class=\"toc-level-2\"><a href=\"#start\">1.1 Start</a><ul><li class=\"toc-level-3\"><a href=\"#install\">1.1.1 Install</a></li></ul></li><li class=\"toc-level-2\"><a href=\"#usage\">1.2 Usage</a></li></ul></li><li class=\"toc-level-1\"><a href=\"#advanced\">2 Advanced</a></li></ul></nav>"
    }

    private func expectedTocJson(): String {
        return "{\"type\":\"TocNode\",\"startOffset\":0,\"endOffset\":0,\"startByteOffset\":0,\"endByteOffset\":0,\"title\":\"Table of Contents\",\"items\":[{\"type\":\"TocItem\",\"startOffset\":0,\"endOffset\":0,\"startByteOffset\":0,\"endByteOffset\":0,\"text\":\"Intro\",\"level\":1,\"id\":\"intro\",\"number\":\"1\",\"children\":[{\"type\":\"TocItem\",\"startOffset\":0,\"endOffset\":0,\"startByteOffset\":0,\"endByteOffset\":0,\"text\":\"Start\",\"level\":2,\"id\":\"start\",\"number\":\"1.1\",\"children\":[]}]}],\"children\":[]}"
    }
}
