package markit.tests.unit.property

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.list.{
    OrderedListItemNode,
    OrderedListNode,
    UnorderedListItemNode,
    UnorderedListNode
}
import markit.plugins.standard.inline.bold.BoldNode
import markit.plugins.standard.inline.image.ImageNode
import markit.plugins.standard.inline.inline_code.InlineCodeNode
import markit.plugins.standard.inline.italic.ItalicNode
import markit.plugins.standard.inline.link.LinkNode
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func standard(): Markit {
    return Markit(StandardMarkdownBundle())
}

@Test
class StandardPropertyTests {
    @TestCase
    func headingLevelsPreserveLevelContentSlugAndOffsetsAcrossModes() {
        let markdown = "# Level 1\n## Level 2\n### Level 3\n#### Level 4\n##### Level 5\n###### Level 6\n"
        let expectedHtml = "<h1 id=\"level-1\">Level 1</h1><h2 id=\"level-2\">Level 2</h2><h3 id=\"level-3\">Level 3</h3><h4 id=\"level-4\">Level 4</h4><h5 id=\"level-5\">Level 5</h5><h6 id=\"level-6\">Level 6</h6>"

        ParseModeTestKit.assertAcrossModes(
            standard,
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html, expectedHtml)
                AstTestKit.expectRoot(result.root, 6)
                for (i in 0..6) {
                    let level = i + 1
                    let headingNode = AstTestKit.child(result.root, i, "Heading${level}Node")
                    if (let heading: HeadingNode <- headingNode) {
                        @Expect(heading.level, level)
                        @Expect(heading.content, "Level ${level}")
                        @Expect(heading.slug, "level-${level}")
                        @Expect(heading.startOffset() < heading.endOffset(), true)
                    }
                }
            }
        )
    }

    @TestCase
    func invalidHeadingBoundariesRemainOneParagraphAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "####### Too many\n#NoSpace\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>####### Too many\n#NoSpace</p>")
                AstTestKit.expectNoNode(result.root, "Heading1Node")
                AstTestKit.expectNoNode(result.root, "Heading6Node")
                AstTestKit.expectNodeCount(result.root, "ParagraphNode", 1)
                AstTestKit.expectNodeCount(result.root, "TextNode", 2)
            }
        )
    }

    @TestCase
    func paragraphsJoinLinesAndSplitOnlyOnBlankLinesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "First line\nSecond line\n\n第三段\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>First line\nSecond line</p><p>第三段</p>")
                AstTestKit.expectRoot(result.root, 2)
                let firstParagraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                let secondParagraph = AstTestKit.child(result.root, 1, "ParagraphNode")
                @Expect(firstParagraph.children.size, 4)
                @Expect(secondParagraph.children.size, 2)
                expectText(AstTestKit.child(firstParagraph, 0, "TextNode"), "First line")
                AstTestKit.child(firstParagraph, 1, "SoftBreakNode")
                expectText(AstTestKit.child(firstParagraph, 2, "TextNode"), "Second line")
                AstTestKit.child(firstParagraph, 3, "SoftBreakNode")
                expectText(AstTestKit.child(secondParagraph, 0, "TextNode"), "第三段")
                AstTestKit.child(secondParagraph, 1, "SoftBreakNode")
            }
        )
    }

    @TestCase
    func emptyAndWhitespaceInputsCreateNoParagraphNodesAcrossModes() {
        let inputs = ["", " ", "\n", "   \n  \n\t"]

        for (input in inputs) {
            ParseModeTestKit.assertAcrossModes(
                standard,
                input,
                { result: ParseModeResult =>
                    AstTestKit.expectRoot(result.root, 0)
                    AstTestKit.expectNoNode(result.root, "ParagraphNode")
                    @Expect(result.html, "")
                }
            )
        }
    }

    @TestCase
    func unorderedMarkersPreserveItemMarkersAndSharedHtmlShapeAcrossModes() {
        let cases = [
            ("-", "-"),
            ("+", "+"),
            ("*", "*")
        ]

        for ((marker, expectedMarker) in cases) {
            ParseModeTestKit.assertAcrossModes(
                standard,
                "${marker} Item 1\n${marker} Item 2\n",
                { result: ParseModeResult =>
                    @Expect(result.html, "<ul><li>Item 1</li><li>Item 2</li></ul>")
                    let listNode = AstTestKit.child(result.root, 0, "UnorderedListNode")
                    if (let list: UnorderedListNode <- listNode) {
                        @Expect(list.tight, true)
                        @Expect(list.children.size, 2)
                        expectUnorderedItem(AstTestKit.child(list, 0, "UnorderedListItemNode"), expectedMarker, "Item 1")
                        expectUnorderedItem(AstTestKit.child(list, 1, "UnorderedListItemNode"), expectedMarker, "Item 2")
                    }
                }
            )
        }
    }

    @TestCase
    func nestedUnorderedListKeepsHierarchyAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "- 外层\n  - 内层一\n  - 内层二\n- 结束\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ul><li>外层<ul><li>内层一</li><li>内层二</li></ul></li><li>结束</li></ul>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectNodeCount(result.root, "UnorderedListNode", 2)
                AstTestKit.expectNodeCount(result.root, "UnorderedListItemNode", 4)

                let outer = AstTestKit.child(result.root, 0, "UnorderedListNode")
                let firstItem = AstTestKit.child(outer, 0, "UnorderedListItemNode")
                expectItemText(firstItem, "外层")
                let inner = AstTestKit.child(firstItem, 1, "UnorderedListNode")
                expectUnorderedItem(AstTestKit.child(inner, 0, "UnorderedListItemNode"), "-", "内层一")
                expectUnorderedItem(AstTestKit.child(inner, 1, "UnorderedListItemNode"), "-", "内层二")
            }
        )
    }

    @TestCase
    func orderedListsPreserveStartNumbersDelimitersAndContinuationsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "3. 第三项\n4. 第四项\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ol start=\"3\"><li>第三项</li><li>第四项</li></ol>")
                let listNode = AstTestKit.child(result.root, 0, "OrderedListNode")
                if (let list: OrderedListNode <- listNode) {
                    @Expect(list.startNumber, 3)
                    @Expect(String.fromUtf8([list.delimiter]), ".")
                    @Expect(list.children.size, 2)
                    expectOrderedItem(AstTestKit.child(list, 0, "OrderedListItemNode"), 3, ".", "第三项")
                    expectOrderedItem(AstTestKit.child(list, 1, "OrderedListItemNode"), 4, ".", "第四项")
                }
            }
        )
    }

    @TestCase
    func orderedParenDelimiterSplitsFromDotDelimiterAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "1. dot\n2) paren\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ol><li>dot</li></ol><ol start=\"2\"><li>paren</li></ol>")
                AstTestKit.expectRoot(result.root, 2)
                let dotList = AstTestKit.child(result.root, 0, "OrderedListNode")
                let parenList = AstTestKit.child(result.root, 1, "OrderedListNode")
                if (let list: OrderedListNode <- dotList) {
                    @Expect(String.fromUtf8([list.delimiter]), ".")
                    @Expect(list.startNumber, 1)
                }
                if (let list: OrderedListNode <- parenList) {
                    @Expect(String.fromUtf8([list.delimiter]), ")")
                    @Expect(list.startNumber, 2)
                }
            }
        )
    }

    @TestCase
    func emphasisMarkersPreserveDelimiterContentAndNestingAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "**bold** __strong__ *italic* _em_ **outer *inner* tail**\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><strong>bold</strong> <strong>strong</strong> <em>italic</em> <em>em</em> <strong>outer <em>inner</em> tail</strong></p>")
                AstTestKit.expectNodeCount(result.root, "BoldNode", 3)
                AstTestKit.expectNodeCount(result.root, "ItalicNode", 3)

                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                expectBold(AstTestKit.child(paragraph, 0, "BoldNode"), "bold", "**")
                expectBold(AstTestKit.child(paragraph, 2, "BoldNode"), "strong", "__")
                expectItalic(AstTestKit.child(paragraph, 4, "ItalicNode"), "italic", "*")
                expectItalic(AstTestKit.child(paragraph, 6, "ItalicNode"), "em", "_")
                let nestedBold = AstTestKit.child(paragraph, 8, "BoldNode")
                if (let bold: BoldNode <- nestedBold) {
                    @Expect(bold.content, "outer *inner* tail")
                    @Expect(bold.children.size, 3)
                    expectItalic(AstTestKit.child(bold, 1, "ItalicNode"), "inner", "*")
                }
            }
        )
    }

    @TestCase
    func escapedEmphasisMarkersStayLiteralAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "\\*not italic\\* \\_not italic\\_ \\*\\*not bold\\*\\*\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>*not italic* _not italic_ **not bold**</p>")
                AstTestKit.expectNoNode(result.root, "ItalicNode")
                AstTestKit.expectNoNode(result.root, "BoldNode")
                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "*not italic* _not italic_ **not bold**")
            }
        )
    }

    @TestCase
    func inlineCodePreservesMarkupSpacesAndFenceLengthAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "Use `` code with `tick` and **bold** `` then `中文`\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Use <code> code with `tick` and **bold** </code> then <code>中文</code></p>")
                AstTestKit.expectNodeCount(result.root, "InlineCodeNode", 2)
                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                expectInlineCode(AstTestKit.child(paragraph, 1, "InlineCodeNode"), " code with `tick` and **bold** ", 2)
                expectInlineCode(AstTestKit.child(paragraph, 3, "InlineCodeNode"), "中文", 1)
                AstTestKit.expectNoNode(result.root, "BoldNode")
            }
        )
    }

    @TestCase
    func linksAndImagesPreserveFieldsAndDoNotConfuseNodeKindsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standard,
            "[中文链接](https://example.com \"标题\") ![示例图](images/demo.png \"图题\")\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><a href=\"https://example.com\" title=\"标题\">中文链接</a> <img src=\"images/demo.png\" alt=\"示例图\" title=\"图题\" /></p>")
                AstTestKit.expectNodeCount(result.root, "LinkNode", 1)
                AstTestKit.expectNodeCount(result.root, "ImageNode", 1)
                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                if (let link: LinkNode <- AstTestKit.child(paragraph, 0, "LinkNode")) {
                    @Expect(link.content, "中文链接")
                    @Expect(link.url, "https://example.com")
                    @Expect(link.title, "标题")
                }
                if (let image: ImageNode <- AstTestKit.child(paragraph, 2, "ImageNode")) {
                    @Expect(image.alt, "示例图")
                    @Expect(image.src, "images/demo.png")
                    @Expect(image.title, "图题")
                }
            }
        )
    }

    @TestCase
    func invalidLinksKeepLegacyLiteralShapesAcrossModes() {
        let cases = [
            ("[text without url]\n", "<p>[text without url]</p>", 0),
            ("(url without text)\n", "<p>(url without text)</p>", 0),
            ("[]url)\n", "<p>[]url)</p>", 0),
            ("[text(url]\n", "<p>[text(url]</p>", 0),
            ("[link text]()\n", "<p><a href=\"\">link text</a></p>", 1)
        ]

        for ((markdown, expectedHtml, expectedLinkCount) in cases) {
            ParseModeTestKit.assertAcrossModes(
                standard,
                markdown,
                { result: ParseModeResult =>
                    @Expect(result.html, expectedHtml)
                    AstTestKit.expectNodeCount(result.root, "LinkNode", expectedLinkCount)
                }
            )
        }
    }

    @TestCase
    func parentLinksAndChildOffsetsStayConsistentForNestedStandardDocumentAcrossModes() {
        let markdown = "# 标题\n\n- **粗体** item\n  - `代码`\n\n> Quote with [link](guide.md)\n"
        ParseModeTestKit.assertAcrossModes(
            standard,
            markdown,
            { result: ParseModeResult =>
                validateParentLinks(result.root)
                validateNodeOffsets(result.root, markdown.toRuneArray().size)
            }
        )
    }

    private func expectText(node: Node, expected: String): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, expected)
        }
    }

    private func expectUnorderedItem(node: Node, marker: String, content: String): Unit {
        if (let item: UnorderedListItemNode <- node) {
            @Expect(String.fromUtf8([item.marker]), marker)
            @Expect(item.content, content)
            expectItemText(item, content)
        }
    }

    private func expectOrderedItem(node: Node, number: Int64, delimiter: String, content: String): Unit {
        if (let item: OrderedListItemNode <- node) {
            @Expect(item.number, number)
            @Expect(String.fromUtf8([item.delimiter]), delimiter)
            @Expect(item.content, content)
            expectItemText(item, content)
        }
    }

    private func expectItemText(item: Node, content: String): Unit {
        let firstChild = item.children[0]
        if (let text: TextNode <- firstChild) {
            @Expect(text.content, content)
            return
        }

        let paragraph = AstTestKit.child(item, 0, "ParagraphNode")
        expectText(AstTestKit.child(paragraph, 0, "TextNode"), content)
    }

    private func expectBold(node: Node, content: String, delimiter: String): Unit {
        if (let bold: BoldNode <- node) {
            @Expect(bold.content, content)
            @Expect(bold.delimiter, delimiter)
        }
    }

    private func expectItalic(node: Node, content: String, delimiter: String): Unit {
        if (let italic: ItalicNode <- node) {
            @Expect(italic.content, content)
            @Expect(italic.delimiter, delimiter)
        }
    }

    private func expectInlineCode(node: Node, content: String, fenceLength: Int64): Unit {
        if (let code: InlineCodeNode <- node) {
            @Expect(code.content, content)
            @Expect(code.fenceLength, fenceLength)
        }
    }

    private func validateParentLinks(node: Node): Unit {
        for (child in node.children) {
            if (let Some(parent) <- child.parent) {
                @Expect(parent.name, node.name)
                @Expect(parent.startOffset(), node.startOffset())
                @Expect(parent.endOffset(), node.endOffset())
            } else {
                throw IllegalArgumentException("${child.name} has no parent")
            }
            validateParentLinks(child)
        }
    }

    private func validateNodeOffsets(node: Node, maxRuneOffset: Int64): Unit {
        @Expect(node.startOffset() >= 0, true)
        @Expect(node.endOffset() >= node.startOffset(), true)
        @Expect(node.endOffset() <= maxRuneOffset, true)
        for (child in node.children) {
            validateNodeOffsets(child, maxRuneOffset)
        }
    }
}
