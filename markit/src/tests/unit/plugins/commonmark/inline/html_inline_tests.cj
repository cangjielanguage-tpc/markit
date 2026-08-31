package markit.tests.unit.plugins.commonmark.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.commonmark.inline.html_inline.HtmlInlineTagPairingConfig
import markit.plugins.commonmark.inline.html_inline.{HTMLInlineNode, HTMLTagType}
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func commonMark(): Markit {
    return Markit(CommonMarkBundle())
}

private func commonMarkWithoutPairing(): Markit {
    return Markit(CommonMarkBundle(
        htmlInlineTagPairingConfig: HtmlInlineTagPairingConfig(enabled: false)
    ))
}

@Test
class HtmlInlineTests {
    @TestCase
    func pairsInlineTagsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Text with <span>中文 HTML</span> content\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Text with <span>中文 HTML</span> content</p>")
                let paragraph = expectParagraph(result.root, 4)
                AstTestKit.expectSpan(paragraph, 0, 42, 0, 38)
                expectSpannedText(AstTestKit.child(paragraph, 0, "TextNode"), "Text with ", 0, 10, 0, 10)
                let html = expectSpannedHtmlInline(
                    AstTestKit.child(paragraph, 1, "HTMLInlineNode"),
                    "span",
                    HTMLTagType.Container,
                    "<span>中文 HTML</span>",
                    10,
                    34,
                    10,
                    30,
                    1
                )
                expectSpannedText(AstTestKit.child(html, 0, "TextNode"), "中文 HTML", 16, 27, 16, 23)
                expectSpannedText(AstTestKit.child(paragraph, 2, "TextNode"), " content", 34, 42, 30, 38)
                expectSoftBreak(AstTestKit.child(paragraph, 3, "SoftBreakNode"), 42, 43, 38, 39)
            }
        )
    }

    @TestCase
    func canDisableInlineTagPairingAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithoutPairing,
            "Text with <span>inline HTML</span> content\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Text with <span>inline HTML</span> content</p>")
                let paragraph = expectParagraph(result.root, 6)
                AstTestKit.expectSpan(paragraph, 0, 42, 0, 42)
                expectSpannedText(AstTestKit.child(paragraph, 0, "TextNode"), "Text with ", 0, 10, 0, 10)
                expectSpannedHtmlInline(
                    AstTestKit.child(paragraph, 1, "HTMLInlineNode"),
                    "span",
                    HTMLTagType.OpeningTag,
                    "<span>",
                    10,
                    16,
                    10,
                    16,
                    0
                )
                expectSpannedText(AstTestKit.child(paragraph, 2, "TextNode"), "inline HTML", 16, 27, 16, 27)
                expectSpannedHtmlInline(
                    AstTestKit.child(paragraph, 3, "HTMLInlineNode"),
                    "span",
                    HTMLTagType.ClosingTag,
                    "</span>",
                    27,
                    34,
                    27,
                    34,
                    0
                )
                expectSpannedText(AstTestKit.child(paragraph, 4, "TextNode"), " content", 34, 42, 34, 42)
                expectSoftBreak(AstTestKit.child(paragraph, 5, "SoftBreakNode"), 42, 43, 42, 43)
            }
        )
    }

    @TestCase
    func rendersSelfClosingTagsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Line one<br/>Line two and very<wbr/>long\n",
            "<p>Line one<br/>Line two and very<wbr/>long</p>"
        )
    }

    @TestCase
    func protectsCodeTagContentAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Use <code>**bold**</code> for code\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Use <code>**bold**</code> for code</p>")
                AstTestKit.expectNoNode(result.root, "BoldNode")
                let paragraph = expectParagraph(result.root, 4)
                AstTestKit.expectSpan(paragraph, 0, 34, 0, 34)
                expectSpannedText(AstTestKit.child(paragraph, 0, "TextNode"), "Use ", 0, 4, 0, 4)
                let code = expectSpannedHtmlInline(
                    AstTestKit.child(paragraph, 1, "HTMLInlineNode"),
                    "code",
                    HTMLTagType.Container,
                    "<code>**bold**</code>",
                    4,
                    25,
                    4,
                    25,
                    1
                )
                @Expect(code.isContentProtected, true)
                expectSpannedText(AstTestKit.child(code, 0, "TextNode"), "**bold**", 10, 18, 10, 18)
                expectSpannedText(AstTestKit.child(paragraph, 2, "TextNode"), " for code", 25, 34, 25, 34)
                expectSoftBreak(AstTestKit.child(paragraph, 3, "SoftBreakNode"), 34, 35, 34, 35)
            }
        )
    }

    @TestCase
    func convertsMarkdownHrefToHtmlHrefAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Check <a href=\"guide.md\" class=\"btn\">the guide</a>\n",
            "<p>Check <a href=\"guide.html\" class=\"btn\">the guide</a></p>"
        )
    }

    @TestCase
    func leavesExternalAndNonMarkdownHrefUnchangedAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Visit <a href=\"https://example.com\">site</a> and <a href=\"file.pdf\">pdf</a>\n",
            "<p>Visit <a href=\"https://example.com\">site</a> and <a href=\"file.pdf\">pdf</a></p>"
        )
    }

    @TestCase
    func pairsLegacySafeInlineContainersAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "This is <em>emphasized</em>, <strong>strong</strong>, <kbd>Ctrl+C</kbd>, and <mark>highlighted</mark>",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<p>This is <em>emphasized</em>, <strong>strong</strong>, <kbd>Ctrl+C</kbd>, and <mark>highlighted</mark></p>"
                )
                let paragraph = expectParagraph(result.root, 8)
                expectText(paragraph.children[0], "This is ")
                expectHtmlInline(paragraph.children[1], "em", HTMLTagType.Container, "<em>emphasized</em>", "emphasized")
                expectText(paragraph.children[2], ", ")
                expectHtmlInline(paragraph.children[3], "strong", HTMLTagType.Container, "<strong>strong</strong>", "strong")
                expectText(paragraph.children[4], ", ")
                expectHtmlInline(paragraph.children[5], "kbd", HTMLTagType.Container, "<kbd>Ctrl+C</kbd>", "Ctrl+C")
                expectText(paragraph.children[6], ", and ")
                expectHtmlInline(paragraph.children[7], "mark", HTMLTagType.Container, "<mark>highlighted</mark>", "highlighted")
            }
        )
    }

    @TestCase
    func pairsSubSupSmallAndTimeContainersAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "H<sub>2</sub>O and E=mc<sup>2</sup>; <small>small text</small>; <time datetime=\"2023-01-01\">January 1, 2023</time>",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<p>H<sub>2</sub>O and E=mc<sup>2</sup>; <small>small text</small>; <time datetime=\"2023-01-01\">January 1, 2023</time></p>"
                )
                let paragraph = expectParagraph(result.root, 8)
                expectText(paragraph.children[0], "H")
                expectHtmlInline(paragraph.children[1], "sub", HTMLTagType.Container, "<sub>2</sub>", "2")
                expectText(paragraph.children[2], "O and E=mc")
                expectHtmlInline(paragraph.children[3], "sup", HTMLTagType.Container, "<sup>2</sup>", "2")
                expectText(paragraph.children[4], "; ")
                expectHtmlInline(paragraph.children[5], "small", HTMLTagType.Container, "<small>small text</small>", "small text")
                expectText(paragraph.children[6], "; ")
                let time = expectHtmlInline(
                    paragraph.children[7],
                    "time",
                    HTMLTagType.Container,
                    "<time datetime=\"2023-01-01\">January 1, 2023</time>",
                    "January 1, 2023"
                )
                expectAttribute(time, "datetime", "2023-01-01")
            }
        )
    }

    @TestCase
    func convertsMarkdownHrefInSubdirectoryWithMultipleAttributesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Click <a href=\"docs/readme.md\" class=\"btn\" target=\"_blank\">documentation</a>",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<p>Click <a href=\"docs/readme.html\" class=\"btn\" target=\"_blank\">documentation</a></p>"
                )
                let paragraph = expectParagraph(result.root, 2)
                expectText(paragraph.children[0], "Click ")
                let link = expectHtmlInline(
                    paragraph.children[1],
                    "a",
                    HTMLTagType.Container,
                    "<a href=\"docs/readme.md\" class=\"btn\" target=\"_blank\">documentation</a>",
                    "documentation"
                )
                expectAttribute(link, "href", "docs/readme.md")
                expectAttribute(link, "class", "btn")
                expectAttribute(link, "target", "_blank")
            }
        )
    }

    @TestCase
    func rendersWbrAndImplicitImageAsSelfClosingAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Very<wbr/>long <img src=\"logo.png\"> word",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Very<wbr/>long <img src=\"logo.png\"> word</p>")
                let paragraph = expectParagraph(result.root, 5)
                expectText(paragraph.children[0], "Very")
                expectHtmlInline(paragraph.children[1], "wbr", HTMLTagType.SelfClosing, "<wbr/>", "")
                expectText(paragraph.children[2], "long ")
                let image = expectHtmlInline(paragraph.children[3], "img", HTMLTagType.SelfClosing, "<img src=\"logo.png\">", "")
                expectAttribute(image, "src", "logo.png")
                expectText(paragraph.children[4], " word")
            }
        )
    }

    private func expectParagraph(root: Node, childCount: Int64): ParagraphNode {
        AstTestKit.expectRoot(root, 1)
        let node = AstTestKit.child(root, 0, "ParagraphNode")
        if (let paragraph: ParagraphNode <- node) {
            @Expect(paragraph.children.size, childCount)
            return paragraph
        }
        throw IllegalArgumentException("Expected ParagraphNode, actual ${node.name}")
    }

    private func expectHtmlInline(
        node: Node,
        tagName: String,
        tagType: HTMLTagType,
        raw: String,
        childText: String
    ): HTMLInlineNode {
        if (let html: HTMLInlineNode <- node) {
            @Expect(html.tagName, tagName)
            @Expect(html.tagType.toString(), tagType.toString())
            @Expect(html.rawContent(), raw)
            if (childText.isEmpty()) {
                @Expect(html.children.size, 0)
            } else {
                @Expect(html.children.size, 1)
                expectText(html.children[0], childText)
            }
            return html
        }
        throw IllegalArgumentException("Expected HTMLInlineNode, actual ${node.name}")
    }

    private func expectSpannedHtmlInline(
        node: Node,
        tagName: String,
        tagType: HTMLTagType,
        raw: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64,
        childCount: Int64
    ): HTMLInlineNode {
        if (let html: HTMLInlineNode <- node) {
            @Expect(html.tagName, tagName)
            @Expect(html.tagType.toString(), tagType.toString())
            @Expect(html.rawContent(), raw)
            @Expect(html.children.size, childCount)
            AstTestKit.expectSpan(html, startByte, endByte, startRune, endRune)
            return html
        }
        throw IllegalArgumentException("Expected HTMLInlineNode, actual ${node.name}")
    }

    private func expectAttribute(node: HTMLInlineNode, name: String, value: String): Unit {
        if (let Some(actual) <- node.attributes.get(name)) {
            @Expect(actual, value)
            return
        }
        throw IllegalArgumentException("Missing HTML inline attribute ${name}")
    }

    private func expectText(node: Node, content: String): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, content)
            return
        }
        if (node.name == "TextNode") {
            @Expect(node.literal, content)
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
        if (node.name == "TextNode") {
            @Expect(node.literal, content)
            AstTestKit.expectSpan(node, startByte, endByte, startRune, endRune)
            AstTestKit.expectLeaf(node)
            return
        }
        throw IllegalArgumentException("Expected TextNode, actual ${node.name}")
    }

    private func expectSoftBreak(
        node: Node,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        AstTestKit.expectSpan(node, startByte, endByte, startRune, endRune)
        AstTestKit.expectLeaf(node)
    }
}
