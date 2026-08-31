package markit.tests.unit.plugins.commonmark.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.commonmark.block.html_block.HtmlBlockConfig
import markit.plugins.commonmark.block.html_block.HTMLBlockNode
import markit.plugins.commonmark.inline.html_inline.{HTMLInlineNode, HTMLTagType}
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.list.{UnorderedListItemNode, UnorderedListNode}
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.inline.bold.BoldNode
import markit.plugins.standard.inline.image.ImageNode
import markit.plugins.standard.inline.italic.ItalicNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func commonMark(): Markit {
    return Markit(CommonMarkBundle())
}

private func commonMarkWithHtmlMarkdown(): Markit {
    return Markit(CommonMarkBundle(
        htmlBlockConfig: HtmlBlockConfig(enableInlineMarkdownParsing: true)
    ))
}

@Test
class HtmlBlockTests {
    @TestCase
    func rendersBasicHtmlCommentAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "<!-- This is a comment -->\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<!-- This is a comment -->\n")
                expectHtmlBlock(result.root, "Comment", "")
            }
        )
    }

    @TestCase
    func rendersMultilineHtmlCommentAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "<!-- This is a\nmultiline comment -->\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<!-- This is a\nmultiline comment -->\n")
                @Expect(result.markdown, "<!-- This is a\nmultiline comment -->\n\n")
                AstTestKit.expectRoot(result.root, 1)
                expectRawHtmlBlockAt(
                    result.root,
                    0,
                    "Comment",
                    "",
                    "<!-- This is a\nmultiline comment -->\n",
                    0,
                    36,
                    false,
                    true
                )
            }
        )
    }

    @TestCase
    func preservesMultilineSafeTagRawSpanAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "<div>\n  Content on multiple lines\n</div>\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<div>\n  Content on multiple lines\n</div>\n")
                @Expect(result.markdown, "<div>\n  Content on multiple lines\n</div>\n\n")
                AstTestKit.expectRoot(result.root, 1)
                expectRawHtmlBlockAt(
                    result.root,
                    0,
                    "SafeBlockTag",
                    "div",
                    "<div>\n  Content on multiple lines\n</div>\n",
                    0,
                    40,
                    false,
                    false
                )
            }
        )
    }

    @TestCase
    func rendersProcessingDeclarationAndCdataAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "<?xml version=\"1.0\"?>\n<!DOCTYPE html>\n<![CDATA[Some raw data here]]>\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<?xml version=\"1.0\"?>\n<!DOCTYPE html>\n<![CDATA[Some raw data here]]>\n")
                @Expect(result.markdown, "<?xml version=\"1.0\"?>\n\n<!DOCTYPE html>\n\n<![CDATA[Some raw data here]]>\n\n")
                AstTestKit.expectRoot(result.root, 3)
                expectRawHtmlBlockAt(
                    result.root,
                    0,
                    "Processing",
                    "",
                    "<?xml version=\"1.0\"?>\n",
                    0,
                    21,
                    false,
                    true
                )
                expectRawHtmlBlockAt(
                    result.root,
                    1,
                    "Declaration",
                    "",
                    "<!DOCTYPE html>\n",
                    22,
                    37,
                    false,
                    true
                )
                expectRawHtmlBlockAt(
                    result.root,
                    2,
                    "CDATA",
                    "",
                    "<![CDATA[Some raw data here]]>\n",
                    38,
                    68,
                    false,
                    true
                )
            }
        )
    }

    @TestCase
    func preservesRawHtmlBlockVariantsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "<!-- Comment with special chars: !@#$%^&*() -->\n<div><p>Nested content</p></div>\n<pre>**This should not be bold**</pre>\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<!-- Comment with special chars: !@#$%^&*() -->\n<div><p>Nested content</p></div>\n<pre>**This should not be bold**</pre>\n"
                )
                AstTestKit.expectRoot(result.root, 3)
                expectRawHtmlBlockAt(
                    result.root,
                    0,
                    "Comment",
                    "",
                    "<!-- Comment with special chars: !@#$%^&*() -->\n",
                    0,
                    47,
                    false,
                    true
                )
                expectRawHtmlBlockAt(
                    result.root,
                    1,
                    "SafeBlockTag",
                    "div",
                    "<div><p>Nested content</p></div>\n",
                    48,
                    80,
                    false,
                    false
                )
                expectRawHtmlBlockAt(
                    result.root,
                    2,
                    "SafeBlockTag",
                    "pre",
                    "<pre>**This should not be bold**</pre>\n",
                    81,
                    119,
                    false,
                    true
                )
            }
        )
    }

    @TestCase
    func rendersSafeBlockTagRawByDefaultAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "<div class=\"content\" id=\"main\">Text</div>\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<div class=\"content\" id=\"main\">Text</div>\n")
                expectHtmlBlock(result.root, "SafeBlockTag", "div")
            }
        )
    }

    @TestCase
    func contentProtectedBlockDoesNotParseMarkdownAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            "<pre>\nThis is **bold** text.\n</pre>\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<pre>\nThis is **bold** text.\n</pre>\n")
                AstTestKit.expectNoNode(result.root, "BoldNode")
                expectHtmlBlock(result.root, "SafeBlockTag", "pre")
            }
        )
    }

    @TestCase
    func canParseMarkdownInsideSafeHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            """
<div>
This is **bold** text and *italic* text.
</div>
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div><p>This is <strong>bold</strong> text and <em>italic</em> text.</p></div>")
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 1)
                AstTestKit.expectSpan(block, 0, 53, 0, 53)
                expectRichParagraphWithSpans(AstTestKit.child(block, 0, "ParagraphNode"))
            }
        )
    }

    @TestCase
    func extractsHtmlInlineChildrenFromParsedHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            """
<div>
  <a href="guide.md">指南</a>
</div>
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div><a href=\"guide.html\">指南</a></div>")
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 1)
                AstTestKit.expectSpan(block, 0, 44, 0, 40)
                let inline = expectHtmlInline(
                    AstTestKit.child(block, 0, "HTMLInlineNode"),
                    "a",
                    HTMLTagType.Container,
                    "<a href=\"guide.md\">指南</a>",
                    1
                )
                AstTestKit.expectSpan(inline, 8, 37, 8, 33)
                expectInlineAttribute(inline, "href", "guide.md")
                expectSpannedText(AstTestKit.child(inline, 0, "TextNode"), "指南", 27, 33, 27, 29)
            }
        )
    }

    @TestCase
    func rendersAdditionalSafeBlockTagsRawAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            """
<section><h1>Title</h1></section>
<article>Article content</article>
<details><summary>Summary</summary>Details</details>
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<section><h1>Title</h1></section>\n<article>Article content</article>\n<details><summary>Summary</summary>Details</details>\n"
                )
                AstTestKit.expectRoot(result.root, 3)
                expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "section", 0)
                expectHtmlBlockAt(result.root, 1, "SafeBlockTag", "article", 0)
                expectHtmlBlockAt(result.root, 2, "SafeBlockTag", "details", 0)
            }
        )
    }

    @TestCase
    func leavesMarkdownRawWhenHtmlMarkdownParsingDisabledAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            """
<div>
This is **bold** text and *italic* text.
</div>
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div>\nThis is **bold** text and *italic* text.\n</div>\n")
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 0)
                @Expect(block.rawContent(), "<div>\nThis is **bold** text and *italic* text.\n</div>\n")
                AstTestKit.expectNoNode(result.root, "BoldNode")
                AstTestKit.expectNoNode(result.root, "ItalicNode")
            }
        )
    }

    @TestCase
    func parsesSelfClosingHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "<hr />\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<hr />\n")
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "hr", 0)
                @Expect(block.isSelfClosing, true)
                @Expect(block.isContentProtected, false)
            }
        )
    }

    @TestCase
    func preservesWhitespaceAndAttributesOnRawHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "<div   class=\"test\"   >Content</div>\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<div   class=\"test\"   >Content</div>\n")
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 0)
                expectAttribute(block, "class", "test")
            }
        )
    }

    @TestCase
    func parsesComplexMarkdownInsideSectionAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            """
<section>
# Heading

This is a **bold** paragraph with *italic* text.

- List item 1
- List item 2
</section>
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<section><h1 id=\"heading\">Heading</h1><p>This is a <strong>bold</strong> paragraph with <em>italic</em> text.</p><ul><li>List item 1</li><li>List item 2</li></ul></section>"
                )
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "section", 3)
                expectHeading(block.children[0], 1, "Heading", "heading")
                expectRichParagraph(block.children[1])
                expectTightList(block.children[2], "List item 1", "List item 2")
            }
        )
    }

    @TestCase
    func parsesImageMarkdownInsideHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            "<div>![Alt text](https://example.com/image.png)</div>\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div><p><img src=\"https://example.com/image.png\" alt=\"Alt text\" /></p></div>"
                )
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 1)
                let paragraph = expectParagraph(block.children[0], "![Alt text](https://example.com/image.png)", 1)
                expectImage(paragraph.children[0], "Alt text", "https://example.com/image.png", "")
            }
        )
    }

    @TestCase
    func extractsHtmlImageAndMarkdownImagesInsideHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            "<div align=\"center\"><img src=\"https://example.com/logo.png\" width=\"200\">![License](https://img.shields.io/badge/license-MIT-blue.svg)![Language](https://img.shields.io/badge/language-Cangjie-orange.svg)</div>\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div align=\"center\"><img src=\"https://example.com/logo.png\" width=\"200\"><p><img src=\"https://img.shields.io/badge/license-MIT-blue.svg\" alt=\"License\" /><img src=\"https://img.shields.io/badge/language-Cangjie-orange.svg\" alt=\"Language\" /></p></div>"
                )
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 2)
                expectAttribute(block, "align", "center")
                expectHtmlInline(block.children[0], "img", HTMLTagType.SelfClosing, "<img src=\"https://example.com/logo.png\" width=\"200\">", 0)
                let paragraph = expectParagraph(
                    block.children[1],
                    "<img src=\"https://example.com/logo.png\" width=\"200\">![License](https://img.shields.io/badge/license-MIT-blue.svg)![Language](https://img.shields.io/badge/language-Cangjie-orange.svg)",
                    2
                )
                expectImage(paragraph.children[0], "License", "https://img.shields.io/badge/license-MIT-blue.svg", "")
                expectImage(paragraph.children[1], "Language", "https://img.shields.io/badge/language-Cangjie-orange.svg", "")
            }
        )
    }

    @TestCase
    func extractsIndentedHtmlImageAndMarkdownImagesInsideHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            """
<div align="center">
  <img src="https://example.com/logo.png" width="200">

  ![License](https://img.shields.io/badge/license-MIT-blue.svg)
  ![Language](https://img.shields.io/badge/language-Cangjie-orange.svg)
</div>
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div align=\"center\"><img src=\"https://example.com/logo.png\" width=\"200\"><p><img src=\"https://img.shields.io/badge/license-MIT-blue.svg\" alt=\"License\" />\n<img src=\"https://img.shields.io/badge/language-Cangjie-orange.svg\" alt=\"Language\" /></p></div>"
                )
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 2)
                expectAttribute(block, "align", "center")
                expectHtmlInline(block.children[0], "img", HTMLTagType.SelfClosing, "<img src=\"https://example.com/logo.png\" width=\"200\">", 0)
                let paragraph = expectParagraph(
                    block.children[1],
                    "<img src=\"https://example.com/logo.png\" width=\"200\">\n![License](https://img.shields.io/badge/license-MIT-blue.svg)\n![Language](https://img.shields.io/badge/language-Cangjie-orange.svg)",
                    3
                )
                expectImage(paragraph.children[0], "License", "https://img.shields.io/badge/license-MIT-blue.svg", "")
                AstTestKit.child(paragraph, 1, "SoftBreakNode")
                expectImage(paragraph.children[2], "Language", "https://img.shields.io/badge/language-Cangjie-orange.svg", "")
            }
        )
    }

    @TestCase
    func parsesNestedHtmlBlocksInsideHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            """
<div>
<div>
Nested content
</div>
</div>
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div><div><p>Nested content</p></div></div>")
                let outer = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 1)
                let inner = expectHtmlBlockNode(outer.children[0], "SafeBlockTag", "div", 1)
                expectPlainParagraph(inner.children[0], "Nested content")
            }
        )
    }

    @TestCase
    func parsesIndentedSiblingHtmlBlocksInsideHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            """
<div>
  <div>First div</div>
  <div>Second div</div>
</div>
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div><div><p>First div</p></div><div><p>Second div</p></div></div>")
                let outer = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 2)
                let first = expectHtmlBlockNode(outer.children[0], "SafeBlockTag", "div", 1)
                let second = expectHtmlBlockNode(outer.children[1], "SafeBlockTag", "div", 1)
                expectPlainParagraph(first.children[0], "First div")
                expectPlainParagraph(second.children[0], "Second div")
            }
        )
    }

    @TestCase
    func parsesSiblingHtmlBlocksInsideHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            """
<div>
<div>First div</div>
<div>Second div</div>
</div>
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div><div><p>First div</p></div><div><p>Second div</p></div></div>")
                let outer = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 2)
                let first = expectHtmlBlockNode(outer.children[0], "SafeBlockTag", "div", 1)
                let second = expectHtmlBlockNode(outer.children[1], "SafeBlockTag", "div", 1)
                expectPlainParagraph(first.children[0], "First div")
                expectPlainParagraph(second.children[0], "Second div")
            }
        )
    }

    @TestCase
    func extractsHtmlLinkAsInlineContainerInsideHtmlBlockAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            """
<div>
  <a>hello</a>
</div>
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<div><a>hello</a></div>")
                let block = expectHtmlBlockAt(result.root, 0, "SafeBlockTag", "div", 1)
                let inline = expectHtmlInline(block.children[0], "a", HTMLTagType.Container, "<a>hello</a>", 1)
                expectText(inline.children[0], "hello")
            }
        )
    }

    private func expectHtmlBlock(root: Node, blockType: String, tagName: String): Unit {
        AstTestKit.expectRoot(root, 1)
        let blockNode = AstTestKit.child(root, 0, "HTMLBlockNode")
        if (let block: HTMLBlockNode <- blockNode) {
            @Expect(block.blockType.toString(), blockType)
            @Expect(block.tagName, tagName)
        }
    }

    private func expectHtmlBlockAt(
        root: Node,
        index: Int64,
        blockType: String,
        tagName: String,
        childCount: Int64
    ): HTMLBlockNode {
        let blockNode = AstTestKit.child(root, index, "HTMLBlockNode")
        return expectHtmlBlockNode(blockNode, blockType, tagName, childCount)
    }

    private func expectHtmlBlockNode(
        node: Node,
        blockType: String,
        tagName: String,
        childCount: Int64
    ): HTMLBlockNode {
        if (let block: HTMLBlockNode <- node) {
            @Expect(block.blockType.toString(), blockType)
            @Expect(block.tagName, tagName)
            @Expect(block.children.size, childCount)
            return block
        }
        throw IllegalArgumentException("Expected HTMLBlockNode, actual ${node.name}")
    }

    private func expectRawHtmlBlockAt(
        root: Node,
        index: Int64,
        blockType: String,
        tagName: String,
        raw: String,
        startByte: Int64,
        endByte: Int64,
        isSelfClosing: Bool,
        isContentProtected: Bool
    ): HTMLBlockNode {
        let block = expectHtmlBlockAt(root, index, blockType, tagName, 0)
        @Expect(block.rawContent(), raw)
        @Expect(block.isSelfClosing, isSelfClosing)
        @Expect(block.isContentProtected, isContentProtected)
        AstTestKit.expectSpan(block, startByte, endByte, startByte, endByte)
        return block
    }

    private func expectHeading(node: Node, level: Int64, content: String, slug: String): Unit {
        if (let heading: HeadingNode <- node) {
            @Expect(heading.level, level)
            @Expect(heading.content, content)
            @Expect(heading.slug, slug)
            @Expect(heading.children.size, 1)
            expectText(heading.children[0], content)
            return
        }
        throw IllegalArgumentException("Expected HeadingNode, actual ${node.name}")
    }

    private func expectRichParagraph(node: Node): Unit {
        let paragraph = expectParagraph(
            node,
            "This is a **bold** paragraph with *italic* text.",
            5
        )
        expectText(paragraph.children[0], "This is a ")
        if (let bold: BoldNode <- paragraph.children[1]) {
            @Expect(bold.content, "bold")
            @Expect(bold.children.size, 1)
            expectText(bold.children[0], "bold")
        } else {
            throw IllegalArgumentException("Expected BoldNode, actual ${paragraph.children[1].name}")
        }
        expectText(paragraph.children[2], " paragraph with ")
        if (let italic: ItalicNode <- paragraph.children[3]) {
            @Expect(italic.content, "italic")
            @Expect(italic.children.size, 1)
            expectText(italic.children[0], "italic")
        } else {
            throw IllegalArgumentException("Expected ItalicNode, actual ${paragraph.children[3].name}")
        }
        expectText(paragraph.children[4], " text.")
    }

    private func expectRichParagraphWithSpans(node: Node): Unit {
        let paragraph = expectParagraph(
            node,
            "This is **bold** text and *italic* text.",
            5
        )
        AstTestKit.expectSpan(paragraph, 6, 46, 6, 46)
        expectSpannedText(AstTestKit.child(paragraph, 0, "TextNode"), "This is ", 6, 14, 6, 14)
        if (let bold: BoldNode <- AstTestKit.child(paragraph, 1, "BoldNode")) {
            @Expect(bold.content, "bold")
            @Expect(bold.delimiter, "**")
            AstTestKit.expectSpan(bold, 14, 22, 14, 22)
            @Expect(bold.children.size, 1)
            expectSpannedText(AstTestKit.child(bold, 0, "TextNode"), "bold", 16, 20, 16, 20)
        } else {
            throw IllegalArgumentException("Expected BoldNode, actual ${paragraph.children[1].name}")
        }
        expectSpannedText(AstTestKit.child(paragraph, 2, "TextNode"), " text and ", 22, 32, 22, 32)
        if (let italic: ItalicNode <- AstTestKit.child(paragraph, 3, "ItalicNode")) {
            @Expect(italic.content, "italic")
            @Expect(italic.delimiter, "*")
            AstTestKit.expectSpan(italic, 32, 40, 32, 40)
            @Expect(italic.children.size, 1)
            expectSpannedText(AstTestKit.child(italic, 0, "TextNode"), "italic", 33, 39, 33, 39)
        } else {
            throw IllegalArgumentException("Expected ItalicNode, actual ${paragraph.children[3].name}")
        }
        expectSpannedText(AstTestKit.child(paragraph, 4, "TextNode"), " text.", 40, 46, 40, 46)
    }

    private func expectTightList(node: Node, firstText: String, secondText: String): Unit {
        if (let list: UnorderedListNode <- node) {
            @Expect(list.tight, true)
            @Expect(list.children.size, 2)
            expectListItem(list.children[0], firstText)
            expectListItem(list.children[1], secondText)
            return
        }
        throw IllegalArgumentException("Expected UnorderedListNode, actual ${node.name}")
    }

    private func expectListItem(node: Node, text: String): Unit {
        if (let item: UnorderedListItemNode <- node) {
            @Expect(item.content, text)
            @Expect(item.children.size, 1)
            expectText(item.children[0], text)
            return
        }
        throw IllegalArgumentException("Expected UnorderedListItemNode, actual ${node.name}")
    }

    private func expectPlainParagraph(node: Node, content: String): Unit {
        let paragraph = expectParagraph(node, content, 1)
        expectText(paragraph.children[0], content)
    }

    private func expectParagraph(node: Node, content: String, childCount: Int64): ParagraphNode {
        if (let paragraph: ParagraphNode <- node) {
            @Expect(paragraph.content, content)
            @Expect(paragraph.children.size, childCount)
            return paragraph
        }
        throw IllegalArgumentException("Expected ParagraphNode, actual ${node.name}")
    }

    private func expectImage(node: Node, alt: String, src: String, title: String): Unit {
        if (let image: ImageNode <- node) {
            @Expect(image.alt, alt)
            @Expect(image.src, src)
            @Expect(image.title, title)
            return
        }
        throw IllegalArgumentException("Expected ImageNode, actual ${node.name}")
    }

    private func expectAttribute(block: HTMLBlockNode, name: String, value: String): Unit {
        if (let Some(actual) <- block.attributes.get(name)) {
            @Expect(actual, value)
            return
        }
        throw IllegalArgumentException("Missing HTML block attribute ${name}")
    }

    private func expectInlineAttribute(node: HTMLInlineNode, name: String, value: String): Unit {
        if (let Some(actual) <- node.attributes.get(name)) {
            @Expect(actual, value)
            return
        }
        throw IllegalArgumentException("Missing HTML inline attribute ${name}")
    }

    private func expectHtmlInline(
        node: Node,
        tagName: String,
        tagType: HTMLTagType,
        raw: String,
        childCount: Int64
    ): HTMLInlineNode {
        if (let html: HTMLInlineNode <- node) {
            @Expect(html.tagName, tagName)
            @Expect(html.tagType.toString(), tagType.toString())
            @Expect(html.rawContent(), raw)
            @Expect(html.children.size, childCount)
            return html
        }
        throw IllegalArgumentException("Expected HTMLInlineNode, actual ${node.name}")
    }

    private func expectText(node: Node, content: String): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, content)
            return
        }
        throw IllegalArgumentException("Expected TextNode, actual ${node.name}")
    }

    private func expectSpannedText(
        node: Node,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, content)
            AstTestKit.expectSpan(text, startByte, endByte, startRune, endRune)
            AstTestKit.expectLeaf(text)
            return
        }
        throw IllegalArgumentException("Expected TextNode, actual ${node.name}")
    }
}
