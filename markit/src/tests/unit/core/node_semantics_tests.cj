package markit.tests.unit.core

import std.io.{ByteBuffer, readToEnd}
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.{Node, TextNode}
import markit.core.session.ParseOptions
import markit.core.source.{SourceRetentionMode, SourceSpan}
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

@Test
class NodeSemanticsTests {
    @TestCase
    func nodeParentInsertReplaceRemoveMaintainRelationships() {
        let parent = Node("Container", sourceSpan: SourceSpan(0, 10, 0, 10), literal: "container")
        let first = TextNode(1, SourceSpan(0, 5, 0, 5), "hello")
        let second = TextNode(2, SourceSpan(6, 10, 6, 10), "world")
        let replacement = TextNode(3, SourceSpan(6, 10, 6, 10), "markit")

        parent.addChild(first)
        @Expect(parent.insertChild(1, second), true)
        @Expect(parent.children.size, 2)
        if (let Some(p) <- second.parent) {
            @Expect(p.name, "ContainerNode")
        } else {
            @Assert(false)
        }

        @Expect(parent.replaceChild(second, replacement), true)
        @Expect(parent.children.size, 2)
        @Expect(parent.children[1].rawContent(), "markit")
        @Expect(second.parent.isNone(), true)
        if (let Some(p) <- replacement.parent) {
            @Expect(p.name, "ContainerNode")
        } else {
            @Assert(false)
        }

        @Expect(parent.removeChild(first), true)
        @Expect(first.parent.isNone(), true)
        @Expect(parent.children.size, 1)
        @Expect(parent.insertChild(3, first), false)
    }

    @TestCase
    func nodeChildMutationUsesReferenceIdentityForEqualNodes() {
        let parent = Node("Container", sourceSpan: SourceSpan(0, 10, 0, 10), literal: "container")
        let first = TextNode(1, SourceSpan(0, 4, 0, 4), "same")
        let second = TextNode(1, SourceSpan(0, 4, 0, 4), "same")
        let replacement = TextNode(2, SourceSpan(5, 9, 5, 9), "next")

        @Expect(first == second, true)
        parent.addChild(first)
        parent.addChild(second)

        @Expect(parent.replaceChild(second, replacement), true)
        @Expect(parent.children[0].rawContent(), "same")
        @Expect(parent.children[1].rawContent(), "next")
        @Expect(second.parent.isNone(), true)
        if (let Some(p) <- first.parent) {
            @Expect(p.name, "ContainerNode")
        } else {
            @Assert(false)
        }

        @Expect(parent.removeChild(first), true)
        @Expect(parent.children.size, 1)
        @Expect(parent.children[0].rawContent(), "next")
    }

    @TestCase
    func parsedNodesExposeSourceSpanRenderAndSeaJsonAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "# 中文标题\n\n段落 text\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<h1 id=\"中文标题\">中文标题</h1><p>段落 text</p>")
                AstTestKit.expectRoot(result.root, 2)
                AstTestKit.expectSpan(result.root, 0, 27, 0, 15)

                let headingNode = AstTestKit.child(result.root, 0, "Heading1Node")
                if (let heading: HeadingNode <- headingNode) {
                    @Expect(heading.content, "中文标题")
                    @Expect(heading.slug, "中文标题")
                    AstTestKit.expectSpan(heading, 0, 14, 0, 6)
                    @Expect(heading.toHtml(), "<h1 id=\"中文标题\">中文标题</h1>")
                    @Expect(heading.toMarkdown(), "# 中文标题\n\n")
                    @Expect(heading.toTypst(), "= 中文标题 <中文标题>\n\n")
                    @Expect(heading.stableHash(), heading.stableHash())
                }

                let paragraphNode = AstTestKit.child(result.root, 1, "ParagraphNode")
                if (let paragraph: ParagraphNode <- paragraphNode) {
                    @Expect(paragraph.content, "段落 text")
                    AstTestKit.expectSpan(paragraph, 16, 27, 8, 15)
                    @Expect(paragraph.toHtml(), "<p>段落 text</p>")
                }

                AstTestKit.expectExactJson(
                    result.root,
                    #"{"type":"DocumentNode","startOffset":0,"endOffset":15,"startByteOffset":0,"endByteOffset":27,"children":[{"type":"Heading1Node","startOffset":0,"endOffset":6,"startByteOffset":0,"endByteOffset":14,"content":"中文标题","level":1,"baseSlug":"中文标题","slugOccurrence":1,"children":[{"type":"TextNode","startOffset":2,"endOffset":6,"startByteOffset":2,"endByteOffset":14,"content":"中文标题","children":[]}],"meta":{"baseSlug":"中文标题","slugOccurrence":1,"typstLabel":"中文标题"}},{"type":"ParagraphNode","startOffset":8,"endOffset":15,"startByteOffset":16,"endByteOffset":27,"content":"段落 text","children":[{"type":"TextNode","startOffset":8,"endOffset":15,"startByteOffset":16,"endByteOffset":27,"content":"段落 text","children":[]},{"type":"SoftBreakNode","startOffset":15,"endOffset":16,"startByteOffset":27,"endByteOffset":28,"children":[]}]}]}"#
                )
            }
        )
    }

    @TestCase
    func defaultAndFullSourceRetentionHaveDifferentRawContentContracts() {
        let defaultOut = Markit().parse("# 标题\n")
        @Expect(defaultOut.root().rawContent(), "")
        @Expect(defaultOut.root().children[0].rawContent(), "标题")

        let session = Markit().createSession(options: ParseOptions(sourceRetentionMode: SourceRetentionMode.Full))
        session.feed("# 标题\n")
        session.finalize()
        let root = session.snapshot().root
        @Expect(root.rawContent(), "# 标题\n")
        @Expect(root.children[0].rawContent(), "# 标题")

        let json = ByteBuffer()
        root.writeJson(json)
        @Expect(String.fromUtf8(readToEnd(json)), root.toJson())
    }
}
