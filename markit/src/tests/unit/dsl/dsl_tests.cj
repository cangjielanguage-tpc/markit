package markit.tests.unit.dsl

import std.io.{ByteBuffer, readToEnd}
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.nodes.{Node, TextNode}
import markit.dsl.*
import markit.plugins.gfm.block.table.TableAlignment
import markit.plugins.gfm.inline.strikethrough.StrikethroughNode
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.inline.inline_code.InlineCodeNode
import markit.plugins.standard.inline.link.LinkConfig
import markit.tests.utils.AstTestKit

@Test
class DslTests {
    @TestCase
    func buildsTypedAstWithChineseOffsetsAndRenderers() {
        let doc = md(
            h1("中文标题"),
            p(text("Use "), code("markit"), text(" 构建"))
        )
        let root = doc.root()

        AstTestKit.expectRoot(root, 2)
        AstTestKit.expectSpan(root, 0, 29, 0, 17)
        @Expect(doc.toHtml(), "<h1 id=\"中文标题\">中文标题</h1><p>Use <code>markit</code> 构建</p>")
        @Expect(doc.toMarkdown(), "# 中文标题\n\nUse `markit` 构建\n\n")
        @Expect(doc.toTypst(), "= 中文标题 <中文标题>\n\nUse #markit-inline-code(\"markit\")\\u{2060} 构建\n\n")
        @Expect(doc.toJson(), root.toJson())

        let headingNode = AstTestKit.child(root, 0, "Heading1Node")
        if (let heading: HeadingNode <- headingNode) {
            @Expect(heading.content, "中文标题")
            @Expect(heading.slug, "中文标题")
            AstTestKit.expectSpan(heading, 0, 12, 0, 4)
            expectText(AstTestKit.child(heading, 0, "TextNode"), "中文标题", 0, 12, 0, 4)
        }

        let paragraphNode = AstTestKit.child(root, 1, "ParagraphNode")
        if (let paragraph: ParagraphNode <- paragraphNode) {
            @Expect(paragraph.content, "Use markit 构建")
            AstTestKit.expectSpan(paragraph, 12, 29, 4, 17)
            expectText(AstTestKit.child(paragraph, 0, "TextNode"), "Use ", 12, 16, 4, 8)
            if (let codeNode: InlineCodeNode <- AstTestKit.child(paragraph, 1, "InlineCodeNode")) {
                @Expect(codeNode.content, "markit")
                @Expect(codeNode.fenceLength, 1)
                AstTestKit.expectSpan(codeNode, 16, 22, 8, 14)
            }
            expectText(AstTestKit.child(paragraph, 2, "TextNode"), " 构建", 22, 29, 14, 17)
        }
    }

    @TestCase
    func pipelineAddsBlocksWithoutMutableBuilderSyntax() {
        let doc = emptyDoc() |> add(h2("Pipeline")) |> add(p(text("组合 "), strong(text("AST"))))

        let root = doc.root()
        AstTestKit.expectRoot(root, 2)
        @Expect(doc.toHtml(), "<h2 id=\"pipeline\">Pipeline</h2><p>组合 <strong>AST</strong></p>")

        let paragraph = AstTestKit.child(root, 1, "ParagraphNode")
        @Expect(paragraph.children.size, 2)
        AstTestKit.child(paragraph, 0, "TextNode")
        AstTestKit.child(paragraph, 1, "BoldNode")
    }

    @TestCase
    func linkConfigControlsDslMarkdownLinkExtension() {
        let htmlDefault = md(p(link("Counter.md", "Counter")))
        @Expect(htmlDefault.toMarkdown(), "[Counter](Counter.html)\n\n")

        let markdownLinks = md(
            DslOptions(linkConfig: LinkConfig(outputExtension: "md")),
            [p(link("Counter.md", "Counter"))]
        )
        @Expect(markdownLinks.toMarkdown(), "[Counter](Counter.md)\n\n")
    }

    @TestCase
    func buildsGfmTableTaskFootnoteAndStrikeAst() {
        let doc = md(
            taskList(
                task(true, p(text("完成 "), code("feedBytes"))),
                task(false, "补测试")
            ),
            table(
                header(cell("API", alignment: TableAlignment.Left), cell("说明", alignment: TableAlignment.Center)),
                row(cell(code("feed")), cell(strike(text("旧输出")))),
                alignments: [TableAlignment.Left, TableAlignment.Center]
            ),
            p(text("引用脚注"), footnoteRef("note")),
            footnoteDef("note", text("中文脚注"))
        )
        let root = doc.root()

        AstTestKit.expectRoot(root, 4)
        @Expect(
            doc.toHtml(),
            "<ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> 完成 <code>feedBytes</code></li><li class=\"task-list-item\"><input type=\"checkbox\" /> 补测试</li></ul>" +
            "<table><thead><tr><th class=\"text-left\">API</th><th class=\"text-center\">说明</th></tr></thead><tbody><tr><td class=\"text-left\"><code>feed</code></td><td class=\"text-center\"><del>旧输出</del></td></tr></tbody></table>" +
            "<p>引用脚注<a id=\"fnref:note\" href=\"#fn:note\" class=\"footnote-ref\">1</a></p><div id=\"fn:note\" class=\"footnote-definition\">中文脚注</div>"
        )

        let taskListNode = AstTestKit.child(root, 0, "TaskListNode")
        @Expect(taskListNode.children.size, 2)
        let tableNode = AstTestKit.child(root, 1, "TableNode")
        @Expect(tableNode.children.size, 2)
        AstTestKit.expectNodeCount(root, "InlineCodeNode", 2)
        AstTestKit.expectNodeCount(root, "FootnoteReferenceNode", 1)
        AstTestKit.expectNodeCount(root, "FootnoteDefinitionNode", 1)

        if (let Some(strike) <- findFirst(root, "StrikethroughNode")) {
            if (let strikeNode: StrikethroughNode <- strike) {
                @Expect(strikeNode.content, "旧输出")
            }
        }
    }

    @TestCase
    func buildsI18nAndTocNodes() {
        let doc = md(
            toc(
                title: "目录",
                items: [tocItem("中文标题", 1, "中文标题")]
            ),
            i18nBlock("zh", p("中文内容")),
            universalBlock(p("所有语言"))
        )

        let root = doc.root()
        AstTestKit.expectRoot(root, 3)
        AstTestKit.child(root, 0, "TocNode")
        AstTestKit.child(root, 1, "I18nBlockNode")
        AstTestKit.child(root, 2, "UniversalBlockNode")
        @Expect(
            doc.toHtml(),
            "<h2>目录</h2><nav class=\"toc\" role=\"navigation\" aria-label=\"Table of contents\"><ul><li class=\"toc-level-1\"><a href=\"#中文标题\">中文标题</a></li></ul></nav><p>中文内容</p><p>所有语言</p>"
        )
    }

    @TestCase
    func streamWritersMatchDirectOutput() {
        let doc = md(h1("输出"), p("中文"))
        let html = ByteBuffer()
        let markdown = ByteBuffer()
        let typst = ByteBuffer()
        let json = ByteBuffer()

        doc.writeHtml(html)
        doc.writeMarkdown(markdown)
        doc.writeTypst(typst)
        doc.writeJson(json)

        @Expect(String.fromUtf8(readToEnd(html)), doc.toHtml())
        @Expect(String.fromUtf8(readToEnd(markdown)), doc.toMarkdown())
        @Expect(String.fromUtf8(readToEnd(typst)), doc.toTypst())
        @Expect(String.fromUtf8(readToEnd(json)), doc.toJson())
    }

    @TestCase
    func rendersCompleteArticleToExactMarkdown() {
        let article = md(
            h1("Markit DSL 完整文章"),
            p(
                text("这是一篇由 "),
                strong(text("markit.dsl")),
                text(" 直接构造 AST 的文章，最终输出为 Markdown。")
            ),
            h2("为什么使用 EDSL"),
            ul(
                item("类型系统限制非法嵌套"),
                item(p(text("行内内容可以组合 "), code("text"), text("、"), code("code"), text(" 和链接"))),
                item(p(text("输出能力覆盖 "), link("https://example.com/docs", "HTML / Markdown / Typst / JSON")))
            ),
            h2("输出能力"),
            table(
                header("能力", "说明"),
                row(cell(strong(text("AST-first"))), cell("直接构造节点树")),
                row(cell(code("writeMarkdown")), cell("输出到流或文件")),
                alignments: [TableAlignment.Left, TableAlignment.Center]
            ),
            h2("生成流程"),
            blockquote(
                p("AI 输出可以持续追加，DSL 也能直接构造最终 AST。")
            ),
            codeBlock(
                "cangjie",
                "let article = md(h1(\"标题\"), p(\"正文\"))\narticle.dumpMarkdown(\"dist\", filename: \"article.md\")"
            ),
            taskList(
                task(true, "完成 AST 构造"),
                task(false, "补充更多文章样例")
            ),
            p(text("复杂度可以写成 "), inlineMath("O(n)"), text("。更多细节见脚注"), footnoteRef("note")),
            footnoteDef("note", "DSL 文档会保留为 AST，再由 renderer 输出。")
        )

        @Expect(
            article.toMarkdown(),
            "# Markit DSL 完整文章\n\n" +
            "这是一篇由 **markit.dsl** 直接构造 AST 的文章，最终输出为 Markdown。\n\n" +
            "## 为什么使用 EDSL\n\n" +
            "- 类型系统限制非法嵌套\n" +
            "- 行内内容可以组合 `text`、`code` 和链接\n" +
            "- 输出能力覆盖 [HTML / Markdown / Typst / JSON](https://example.com/docs)\n\n" +
            "## 输出能力\n\n" +
            "| 能力 | 说明 |\n" +
            "| :--- | :---: |\n" +
            "| **AST-first** | 直接构造节点树 |\n" +
            "| `writeMarkdown` | 输出到流或文件 |\n\n" +
            "## 生成流程\n\n" +
            "> AI 输出可以持续追加，DSL 也能直接构造最终 AST。\n\n" +
            "```cangjie\n" +
            "let article = md(h1(\"标题\"), p(\"正文\"))\n" +
            "article.dumpMarkdown(\"dist\", filename: \"article.md\")\n" +
            "```\n\n" +
            "- [x] 完成 AST 构造\n" +
            "- [ ] 补充更多文章样例\n\n" +
            "复杂度可以写成 $O(n)$。更多细节见脚注[^note]\n\n" +
            "[^note]: DSL 文档会保留为 AST，再由 renderer 输出。\n\n"
        )

        let root = article.root()
        AstTestKit.expectRoot(root, 12)
        AstTestKit.child(root, 0, "Heading1Node")
        AstTestKit.child(root, 7, "BlockquoteNode")
        AstTestKit.child(root, 8, "FencedCodeBlockNode")
        AstTestKit.child(root, 9, "TaskListNode")
        AstTestKit.child(root, 11, "FootnoteDefinitionNode")
    }

    private func expectText(
        node: Node,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let textNode: TextNode <- node) {
            @Expect(textNode.content, content)
            AstTestKit.expectSpan(textNode, startByte, endByte, startRune, endRune)
            AstTestKit.expectLeaf(textNode)
        }
    }

    private func findFirst(root: Node, name: String): ?Node {
        if (root.name == name) {
            return Some(root)
        }
        for (child in root.children) {
            if (let Some(found) <- findFirst(child, name)) {
                return Some(found)
            }
        }
        return None
    }
}
