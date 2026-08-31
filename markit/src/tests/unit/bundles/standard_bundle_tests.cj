package markit.tests.unit.bundles

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.list.{UnorderedListItemNode, UnorderedListNode}
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.inline.bold.BoldNode
import markit.plugins.standard.inline.inline_code.InlineCodeNode
import markit.plugins.standard.inline.italic.ItalicNode
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class StandardBundleTests {
    @TestCase
    func exposesBundleMetadata() {
        let bundle = StandardMarkdownBundle()

        @Expect(bundle.name, "StandardMarkdownBundle")
        @Expect(bundle.version, "2.0.0-scaffold")
        @Expect(bundle.includesStandardMarkdown, true)
        @Expect(bundle.plugins.size > 0, true)
    }

    @TestCase
    func registersHeadingFeatureWithExactAstAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit(StandardMarkdownBundle()) },
            "# Heading",
            { result: ParseModeResult =>
                @Expect(result.html, "<h1 id=\"heading\">Heading</h1>")
                expectHeadingDocument(result.root)
            }
        )
    }

    @TestCase
    func registersInlineFeatureWithExactAstAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit(StandardMarkdownBundle()) },
            "**Bold** and *italic* with `code`.",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><strong>Bold</strong> and <em>italic</em> with <code>code</code>.</p>")
                expectInlineDocument(result.root)
            }
        )
    }

    @TestCase
    func registersListFeatureWithExactAstAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit(StandardMarkdownBundle()) },
            "- List item\n- Another item",
            { result: ParseModeResult =>
                @Expect(result.html, "<ul><li>List item</li><li>Another item</li></ul>")
                expectListDocument(result.root)
            }
        )
    }

    @TestCase
    func resolvesLinkAndImageReferencesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(StandardMarkdownBundle()) },
            "[1]: https://google.com\n[img]: image.jpg\n\nVisit [Google][1]. ![Alt text][img]\n",
            "<p>Visit <a href=\"https://google.com\">Google</a>. <img src=\"image.jpg\" alt=\"Alt text\" /></p>"
        )
    }

    @TestCase
    func parsesEmptyDocumentConsistentlyAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit(StandardMarkdownBundle()) },
            "",
            { result: ParseModeResult =>
                @Expect(result.html, "")
                @Expect(result.root.name, "DocumentNode")
                @Expect(result.root.children.size, 0)
            }
        )
    }

    @TestCase
    func parsingIsDeterministicAcrossNewBundleInstances() {
        let markdown = "# Test\n\n**Bold** and *italic* text with `code`.\n"
        let first = Markit(StandardMarkdownBundle()).parse(markdown).toJson()
        let second = Markit(StandardMarkdownBundle()).parse(markdown).toJson()

        @Expect(first, second)
    }

    private func expectHeadingDocument(root: Node): Unit {
        @Expect(root.name, "DocumentNode")
        @Expect(root.children.size, 1)
        if (let heading: HeadingNode <- root.children[0]) {
            @Expect(heading.level, 1)
            @Expect(heading.content, "Heading")
            @Expect(heading.slug, "heading")
            @Expect(heading.children.size, 1)
            expectText(heading.children[0], "Heading")
        } else {
            @Expect(root.children[0].name, "Heading1Node")
        }
    }

    private func expectInlineDocument(root: Node): Unit {
        @Expect(root.name, "DocumentNode")
        @Expect(root.children.size, 1)
        if (let paragraph: ParagraphNode <- root.children[0]) {
            @Expect(paragraph.content, "**Bold** and *italic* with `code`.")
            @Expect(paragraph.children.size, 6)
            expectBold(paragraph.children[0], "Bold", "Bold")
            expectText(paragraph.children[1], " and ")
            expectItalic(paragraph.children[2], "italic", "italic")
            expectText(paragraph.children[3], " with ")
            expectInlineCode(paragraph.children[4], "code")
            expectText(paragraph.children[5], ".")
        } else {
            @Expect(root.children[0].name, "ParagraphNode")
        }
    }

    private func expectListDocument(root: Node): Unit {
        @Expect(root.name, "DocumentNode")
        @Expect(root.children.size, 1)
        if (let list: UnorderedListNode <- root.children[0]) {
            @Expect(list.tight, true)
            @Expect(list.baseIndent, 0)
            @Expect(list.children.size, 2)
            expectListItem(list.children[0], "List item", "List item")
            expectListItem(list.children[1], "Another item", "Another item")
        } else {
            @Expect(root.children[0].name, "UnorderedListNode")
        }
    }

    private func expectListItem(node: Node, content: String, text: String): Unit {
        if (let item: UnorderedListItemNode <- node) {
            @Expect(item.content, content)
            @Expect(item.indentLevel, 0)
            @Expect(String.fromUtf8([item.marker]), "-")
            @Expect(item.children.size, 1)
            expectText(item.children[0], text)
        } else {
            @Expect(node.name, "UnorderedListItemNode")
        }
    }

    private func expectBold(node: Node, content: String, childText: String): Unit {
        if (let bold: BoldNode <- node) {
            @Expect(bold.content, content)
            @Expect(bold.delimiter, "**")
            @Expect(bold.children.size, 1)
            expectText(bold.children[0], childText)
        } else {
            @Expect(node.name, "BoldNode")
        }
    }

    private func expectItalic(node: Node, content: String, childText: String): Unit {
        if (let italic: ItalicNode <- node) {
            @Expect(italic.content, content)
            @Expect(italic.delimiter, "*")
            @Expect(italic.children.size, 1)
            expectText(italic.children[0], childText)
        } else {
            @Expect(node.name, "ItalicNode")
        }
    }

    private func expectInlineCode(node: Node, content: String): Unit {
        if (let code: InlineCodeNode <- node) {
            @Expect(code.content, content)
            @Expect(code.fenceLength, 1)
            @Expect(code.children.size, 0)
        } else {
            @Expect(node.name, "InlineCodeNode")
        }
    }

    private func expectText(node: Node, content: String): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, content)
            @Expect(text.children.size, 0)
        } else {
            @Expect(node.name, "TextNode")
        }
    }
}
