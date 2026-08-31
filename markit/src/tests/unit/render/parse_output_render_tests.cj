package markit.tests.unit.render

import std.fs.{File, Path, removeIfExists}
import std.io.{ByteBuffer, readToEnd}
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.{Node, TextNode}
import markit.plugins.standard.block.blockquote.BlockquoteNode
import markit.plugins.standard.block.divider.DividerNode
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockNode
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.list.{OrderedListItemNode, OrderedListNode}
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.tests.utils.{AstTestKit, ParseModeTestKit}

@Test
class ParseOutputRenderTests {
    @TestCase
    func exposesStableRenderTargetsAcrossModes() {
        let fixture = """
# 标题

段落第一行
第二行

> 引用第一行
> 第二行

1) 一项
2) 二项

---

```
let 值 = 1
```"""
        let results = ParseModeTestKit.collect({ => Markit() }, fixture)
        let baseline = results[0]

        @Expect(
            baseline.html,
            "<h1 id=\"标题\">标题</h1><p>段落第一行\n第二行</p><blockquote><p>引用第一行\n第二行</p></blockquote><ol><li>一项</li><li><p>二项</p></li></ol><hr /><pre><code>let 值 = 1</code></pre>"
        )
        @Expect(
            baseline.markdown,
            "# 标题\n\n段落第一行\n第二行\n\n> 引用第一行\n> 第二行\n\n1) 一项\n2) 二项\n\n---\n\n```\nlet 值 = 1\n```\n\n"
        )
        @Expect(
            baseline.typst,
            "= 标题 <标题>\n\n段落第一行 第二行\n\n#quote(block: true)[\n引用第一行 第二行\n]\n\n+ 一项\n+ 二项\n\n#block(above: 0.9em, below: 0.9em)[#line(length: 100%, stroke: 0.7pt + luma(205))]\n\n``````\nlet 值 = 1\n``````\n\n"
        )
        expectRenderFixtureAst(baseline.root)
        @Expect(baseline.json, baseline.root.toJson())
        @Expect(baseline.tree, baseline.root.toString())

        for (result in results) {
            @Expect(result.html, baseline.html)
            @Expect(result.markdown, baseline.markdown)
            @Expect(result.typst, baseline.typst)
            @Expect(result.json, baseline.json)
            @Expect(result.tree, baseline.tree)
        }
    }

    @TestCase
    func parseOutputMethodsExposeConvenienceApis() {
        let out = Markit().parse("# 中文标题")

        expectSingleHeadingAst(out.root())
        @Expect(out.toString(), out.root().toString())
        @Expect(out.toJson(), out.root().toJson())
        @Expect(out.toMarkdown(), "# 中文标题\n\n")
        @Expect(out.toTypst(), "= 中文标题 <中文标题>\n\n")
        @Expect(out.toHtml(), "<h1 id=\"中文标题\">中文标题</h1>")
    }

    @TestCase
    func astNodeRenderMethodsUseRegisteredPluginRenderers() {
        let out = Markit().parse("# 中文标题\n\n段落")
        let root = out.root()

        @Expect(root.toHtml(), out.toHtml())
        @Expect(root.toMarkdown(), out.toMarkdown())
        @Expect(root.toTypst(), out.toTypst())
        @Expect(root.toJson(), out.toJson())
        @Expect(root.children[0].toHtml(), "<h1 id=\"中文标题\">中文标题</h1>")
        @Expect(root.children[1].toHtml(), "<p>段落</p>")
    }

    @TestCase
    func outputStreamsMatchDirectStringApis() {
        let out = Markit().parse("# 中文标题\n\n段落")

        let html = ByteBuffer()
        let markdown = ByteBuffer()
        let typst = ByteBuffer()
        let json = ByteBuffer()
        let tree = ByteBuffer()

        out.writeHtml(html)
        out.writeMarkdown(markdown)
        out.writeTypst(typst)
        out.writeJson(json)
        out.write(tree)

        @Expect(String.fromUtf8(readToEnd(html)), out.toHtml())
        @Expect(String.fromUtf8(readToEnd(markdown)), out.toMarkdown())
        @Expect(String.fromUtf8(readToEnd(typst)), out.toTypst())
        @Expect(String.fromUtf8(readToEnd(json)), out.toJson())
        @Expect(String.fromUtf8(readToEnd(tree)), out.toString())
    }

    @TestCase
    func dumpMethodsWriteFilesForAllFormats() {
        let dir = Path("./test_result/render_output_api")
        removeIfExists(dir, recursive: true)

        let out = Markit().parse("# 中文标题\n\n段落")
        out.dump(dir.toString(), filename: "tree.txt")
        out.dumpHtml(dir.toString(), filename: "doc.html")
        out.dumpMarkdown(dir.toString(), filename: "doc.md")
        out.dumpTypst(dir.toString(), filename: "doc.typ")
        out.dumpJson(dir.toString(), filename: "doc.json")

        @Expect(String.fromUtf8(File.readFrom(dir.join("tree.txt"))), out.toString())
        @Expect(String.fromUtf8(File.readFrom(dir.join("doc.html"))), out.toHtml())
        @Expect(String.fromUtf8(File.readFrom(dir.join("doc.md"))), out.toMarkdown())
        @Expect(String.fromUtf8(File.readFrom(dir.join("doc.typ"))), out.toTypst())
        @Expect(String.fromUtf8(File.readFrom(dir.join("doc.json"))), out.toJson())

        removeIfExists(dir, recursive: true)
    }

    private func expectSingleHeadingAst(root: Node): Unit {
        AstTestKit.expectRoot(root, 1)
        let headingNode = AstTestKit.child(root, 0, "Heading1Node")
        if (let heading: HeadingNode <- headingNode) {
            @Expect(heading.level, 1)
            @Expect(heading.content, "中文标题")
            @Expect(heading.slug, "中文标题")
            @Expect(heading.children.size, 1)
            expectText(AstTestKit.child(heading, 0, "TextNode"), "中文标题")
        }
    }

    private func expectRenderFixtureAst(root: Node): Unit {
        AstTestKit.expectRoot(root, 6)

        let headingNode = AstTestKit.child(root, 0, "Heading1Node")
        if (let heading: HeadingNode <- headingNode) {
            @Expect(heading.level, 1)
            @Expect(heading.content, "标题")
            @Expect(heading.slug, "标题")
            expectText(AstTestKit.child(heading, 0, "TextNode"), "标题")
        }

        let paragraphNode = AstTestKit.child(root, 1, "ParagraphNode")
        if (let paragraph: ParagraphNode <- paragraphNode) {
            @Expect(paragraph.content, "段落第一行\n第二行")
            @Expect(paragraph.children.size, 4)
            expectText(AstTestKit.child(paragraph, 0, "TextNode"), "段落第一行")
            AstTestKit.child(paragraph, 1, "SoftBreakNode")
            expectText(AstTestKit.child(paragraph, 2, "TextNode"), "第二行")
            AstTestKit.child(paragraph, 3, "SoftBreakNode")
        }

        let quoteNode = AstTestKit.child(root, 2, "BlockquoteNode")
        if (let blockquote: BlockquoteNode <- quoteNode) {
            @Expect(blockquote.children.size, 1)
            let quotedParagraphNode = AstTestKit.child(blockquote, 0, "ParagraphNode")
            if (let quotedParagraph: ParagraphNode <- quotedParagraphNode) {
                @Expect(quotedParagraph.content, "引用第一行\n第二行")
            }
        }

        let listNode = AstTestKit.child(root, 3, "OrderedListNode")
        if (let list: OrderedListNode <- listNode) {
            @Expect(list.tight, false)
            @Expect(list.startNumber, 1)
            @Expect(String.fromUtf8([list.delimiter]), ")")
            @Expect(list.children.size, 2)
            expectOrderedItem(AstTestKit.child(list, 0, "OrderedListItemNode"), 1, "一项")
            expectOrderedItem(AstTestKit.child(list, 1, "OrderedListItemNode"), 2, "二项")
        }

        let dividerNode = AstTestKit.child(root, 4, "DividerNode")
        if (let divider: DividerNode <- dividerNode) {
            @Expect(divider.children.size, 0)
        }

        let codeNode = AstTestKit.child(root, 5, "FencedCodeBlockNode")
        if (let code: FencedCodeBlockNode <- codeNode) {
            @Expect(code.language, "")
            @Expect(code.content(), "let 值 = 1")
            @Expect(String.fromUtf8([code.fenceMarker]), "`")
            @Expect(code.fenceLength, 3)
            @Expect(code.children.size, 0)
        }
    }

    private func expectOrderedItem(node: Node, number: Int64, content: String): Unit {
        if (let item: OrderedListItemNode <- node) {
            @Expect(item.number, number)
            @Expect(item.content, content)
            @Expect(String.fromUtf8([item.delimiter]), ")")
        }
    }

    private func expectText(node: Node, content: String): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, content)
            @Expect(text.children.size, 0)
        }
    }
}
