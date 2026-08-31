package markit.tests.unit.config

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.config.HtmlConfig
import markit.core.session.ParseOptions
import markit.core.source.SourceRetentionMode
import markit.plugins.commonmark.block.html_block.HtmlBlockConfig
import markit.plugins.commonmark.inline.html_inline.HtmlInlineTagPairingConfig
import markit.plugins.gfm.block.math_block.MathBlockConfig
import markit.plugins.gfm.block.table.TableConfig
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.plugins.standard.block.heading.{HeadingClosableConfig, HeadingNumberingConfig, HeadingSlugConfig}
import markit.plugins.standard.block.list.ListConfig
import markit.plugins.standard.inline.link.{FileTree, HeadingInfo, LinkConfig, RenderMode}
import markit.tests.utils.ParseModeTestKit

@Test
@Tag[Config]
class ConfigTests {
    @BeforeEach
    func resetBeforeEach() {
        HtmlConfig.reset()
    }

    @AfterEach
    func resetAfterEach() {
        HtmlConfig.reset()
    }

    @TestCase
    func parseOptionsExposeStreamingAndRetentionDefaults() {
        let defaults = ParseOptions()
        @Expect(defaults.inputChunkSize, 8192)
        @Expect(defaults.sourceRetentionMode == SourceRetentionMode.Essential, true)
        @Expect(defaults.emitHtmlFragments, true)
        @Expect(defaults.emitPreview, true)

        let custom = ParseOptions(
            inputChunkSize: 128,
            sourceRetentionMode: SourceRetentionMode.Full,
            emitHtmlFragments: false,
            emitPreview: false
        )
        @Expect(custom.inputChunkSize, 128)
        @Expect(custom.sourceRetentionMode == SourceRetentionMode.Full, true)
        @Expect(custom.emitHtmlFragments, false)
        @Expect(custom.emitPreview, false)
    }

    @TestCase
    func htmlConfigSetAddRemoveSnapshotAndResetAreExact() {
        let classes = ArrayList<String>()
        classes.add("prose")
        classes.add("中文")
        HtmlConfig.setGlobalCssClasses(classes)
        HtmlConfig.addGlobalCssClass("prose")
        HtmlConfig.addGlobalCssClass("wide")
        HtmlConfig.removeGlobalCssClass("中文")

        let rootClasses = ArrayList<String>()
        rootClasses.add("doc")
        HtmlConfig.setRootWrapper(true, tag: "article", classNames: rootClasses)
        HtmlConfig.addNodeClass("ParagraphNode", "paragraph")
        HtmlConfig.addNodeClass("ParagraphNode", "paragraph")
        HtmlConfig.addNodeClass("ParagraphNode", "body")
        HtmlConfig.removeNodeClass("ParagraphNode", "body")

        @Expect(HtmlConfig.getGlobalCssClasses().toArray(), ["prose", "wide"])
        @Expect(HtmlConfig.isRootWrapperEnabled(), true)
        @Expect(HtmlConfig.getRootWrapperTag(), "article")
        @Expect(HtmlConfig.getRootWrapperClasses().toArray(), ["prose", "wide", "doc"])
        @Expect(HtmlConfig.getNodeClasses("ParagraphNode").toArray(), ["prose", "wide", "paragraph"])
        @Expect(HtmlConfig.hasNodeClasses("ParagraphNode"), true)

        let snapshot = HtmlConfig.snapshot()
        HtmlConfig.reset()
        @Expect(HtmlConfig.getGlobalCssClasses().isEmpty(), true)
        @Expect(snapshot.getNodeClasses("ParagraphNode").toArray(), ["prose", "wide", "paragraph"])
    }

    @TestCase
    func pluginConfigsKeepHardPublicFieldsUsable() {
        let fileTree = FileTree(["README.md", "guide.md"])
        let heading = HeadingInfo("中文标题", "中文标题", "README.md", 1)
        fileTree.addHeading(heading)
        let linkConfig = LinkConfig(
            fileTree: Some(fileTree),
            renderMode: RenderMode.Flat,
            currentFilePath: "README.md",
            preserveFlatFilePaths: true
        )

        @Expect(linkConfig.renderMode == RenderMode.Flat, true)
        @Expect(linkConfig.currentFilePath, "README.md")
        @Expect(linkConfig.preserveFlatFilePaths, true)
        @Expect(fileTree.findHeadingsBySlug("中文标题")[0].text, "中文标题")

        @Expect(HeadingNumberingConfig(enabled: true).enabled, true)
        @Expect(HeadingClosableConfig(enabled: true).enabled, true)
        @Expect(HeadingSlugConfig(currentPagePath: "docs/readme.md", enablePathLabels: true).enablePathLabels, true)
        let fencedConfig = FencedCodeBlockConfig(enableGroup: true, autoAnchor: true)
        @Expect(fencedConfig.enableGroup, true)
        @Expect(fencedConfig.autoAnchor, true)
        let tableConfig = TableConfig(enableThreeLineTable: true, autoAnchor: true)
        @Expect(tableConfig.enableThreeLineTable, true)
        @Expect(tableConfig.autoAnchor, true)
        @Expect(MathBlockConfig(autoAnchor: true).autoAnchor, true)
        @Expect(ListConfig(autoAnchor: true).autoAnchor, true)
        @Expect(HtmlBlockConfig(enableInlineMarkdownParsing: true).enableInlineMarkdownParsing, true)
        @Expect(HtmlInlineTagPairingConfig(enabled: false).enabled, false)
        @Expect(I18nConfig(defaultLanguage: "zh", targetLanguage: "en").targetLanguage, "en")
    }

    @TestCase
    func htmlConfigSnapshotIsCapturedWhenSessionIsCreated() {
        HtmlConfig.addGlobalCssClass("before")
        let session = Markit().createSession()
        HtmlConfig.addGlobalCssClass("after")

        session.feed("段落\n")
        session.finalize()
        @Expect(session.renderer().renderHtml(session.snapshot().root), "<p class=\"before\">段落</p>")

        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "段落\n",
            "<p class=\"before after\">段落</p>"
        )
    }
}
