package markit.tests.unit.render

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.config.HtmlConfig
import markit.tests.utils.ParseModeTestKit

@Test
class HtmlConfigRenderTests {
    @BeforeEach
    func resetBeforeEach() {
        HtmlConfig.reset()
    }

    @AfterEach
    func resetAfterEach() {
        HtmlConfig.reset()
    }

    @TestCase
    func rootWrapperAppliesToRenderedDocumentAcrossModes() {
        let classes = ArrayList<String>()
        classes.add("markdown-body")
        classes.add("中文容器")
        HtmlConfig.setRootWrapper(true, tag: "article", classNames: classes)

        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "# 中文标题\n\n段落",
            "<article class=\"markdown-body 中文容器\"><h1 id=\"中文标题\">中文标题</h1><p>段落</p></article>"
        )
    }

    @TestCase
    func globalCssClassAppliesToRenderedBlocksAcrossModes() {
        HtmlConfig.addGlobalCssClass("prose")
        HtmlConfig.addGlobalCssClass("中文排版")

        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "# 中文标题\n\n段落",
            "<h1 id=\"中文标题\" class=\"prose 中文排版\">中文标题</h1><p class=\"prose 中文排版\">段落</p>"
        )
    }

    @TestCase
    func legacyHeadingNodeClassAppliesToLevelSpecificHeadingAcrossModes() {
        HtmlConfig.addNodeClass("HeadingNode", "article-heading")
        HtmlConfig.addNodeClass("HeadingNode", "中文标题类")

        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "# 中文标题\n## 二级标题\n",
            "<h1 id=\"中文标题\" class=\"article-heading 中文标题类\">中文标题</h1><h2 id=\"二级标题\" class=\"article-heading 中文标题类\">二级标题</h2>"
        )
    }

    @TestCase
    func exactNodeClassCombinesWithGlobalClassAcrossModes() {
        HtmlConfig.addGlobalCssClass("prose")
        HtmlConfig.addNodeClass("ParagraphNode", "paragraph")

        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "中文段落",
            "<p class=\"prose paragraph\">中文段落</p>"
        )
    }
}
