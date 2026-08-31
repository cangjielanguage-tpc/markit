package markit.tests.unit.plugins.i18n.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.i18n.nodes.{I18nBlockNode, UniversalBlockNode}
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.inline.bold.BoldNode
import markit.plugins.standard.inline.inline_code.InlineCodeNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func i18nEn(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
}

private func i18nZh(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "zh")
    ))
}

@Test
class I18nBlockTests {
    @TestCase
    func rendersTargetLanguageBlockAcrossModes() {
        let markdown = """
:::zh
中文内容
:::
:::en
English **content**
:::
"""
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html, "<p>English <strong>content</strong></p>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectNodeCount(result.root, "I18nBlockNode", 1)
                let block = expectI18nBlock(
                    AstTestKit.child(result.root, 0, "I18nBlockNode"),
                    "en",
                    "English **content**",
                    23,
                    52,
                    15,
                    44,
                    1
                )
                let paragraph = expectParagraph(
                    AstTestKit.child(block, 0, "ParagraphNode"),
                    "English **content**",
                    2
                )
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "English ")
                if (let bold: BoldNode <- AstTestKit.child(paragraph, 1, "BoldNode")) {
                    @Expect(bold.content, "content")
                    @Expect(bold.delimiter, "**")
                    @Expect(bold.children.size, 1)
                    expectText(AstTestKit.child(bold, 0, "TextNode"), "content")
                }
            }
        )
    }

    @TestCase
    func rendersDefaultLanguageBlockAcrossModes() {
        let markdown = """
:::zh
中文 **内容**
:::
:::en
English content
:::
"""
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            markdown,
            "<p>中文 <strong>内容</strong></p>"
        )
    }

    @TestCase
    func universalBlocksRenderForAllTargetsAcrossModes() {
        let markdown = """
:::
通用 `code`
:::
:::en
English
:::
"""
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html, "<p>通用 <code>code</code></p><p>English</p>")
                AstTestKit.expectRoot(result.root, 2)
                AstTestKit.expectNodeCount(result.root, "UniversalBlockNode", 1)
                let universal = expectUniversalBlock(
                    AstTestKit.child(result.root, 0, "UniversalBlockNode"),
                    "通用 `code`",
                    0,
                    21,
                    0,
                    17,
                    1
                )
                let universalParagraph = expectParagraph(
                    AstTestKit.child(universal, 0, "ParagraphNode"),
                    "通用 `code`",
                    2
                )
                expectText(AstTestKit.child(universalParagraph, 0, "TextNode"), "通用 ")
                if (let code: InlineCodeNode <- AstTestKit.child(universalParagraph, 1, "InlineCodeNode")) {
                    @Expect(code.content, "code")
                    AstTestKit.expectLeaf(code)
                }

                let english = expectI18nBlock(
                    AstTestKit.child(result.root, 1, "I18nBlockNode"),
                    "en",
                    "English",
                    22,
                    39,
                    18,
                    35,
                    1
                )
                let englishParagraph = expectParagraph(AstTestKit.child(english, 0, "ParagraphNode"), "English", 1)
                expectText(AstTestKit.child(englishParagraph, 0, "TextNode"), "English")
            }
        )
    }

    @TestCase
    func supportsNestedBlocksAndChineseAcrossModes() {
        let markdown = """
:::en
# Title 中文

- Item 1
- Item 2

> Quote 中文
:::
"""
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html, "<h1 id=\"title-中文\">Title 中文</h1><ul><li>Item 1</li><li><p>Item 2</p></li></ul><blockquote><p>Quote 中文</p></blockquote>")
            }
        )
    }

    @TestCase
    func incompleteBlockFallsBackToParagraphAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            ":::en\nUnclosed",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "I18nBlockNode")
                @Expect(result.html, "")
            }
        )
    }

    @TestCase
    func acceptsIndentedI18nBlocksUpToFourColumnsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nZh,
            " :::zh\n 你好世界\n :::\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>你好世界</p>")
                AstTestKit.expectNodeCount(result.root, "I18nBlockNode", 1)
                let block = expectI18nBlock(
                    AstTestKit.child(result.root, 0, "I18nBlockNode"),
                    "zh",
                    "你好世界",
                    0,
                    25,
                    0,
                    17,
                    1
                )
                let paragraph = expectParagraph(AstTestKit.child(block, 0, "ParagraphNode"), "你好世界", 1)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "你好世界")
            }
        )

        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            "   :::en\n   Hello World\n:::\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Hello World</p>")
                AstTestKit.expectNodeCount(result.root, "I18nBlockNode", 1)
                let block = expectI18nBlock(
                    AstTestKit.child(result.root, 0, "I18nBlockNode"),
                    "en",
                    "Hello World",
                    0,
                    27,
                    0,
                    27,
                    1
                )
                let paragraph = expectParagraph(AstTestKit.child(block, 0, "ParagraphNode"), "Hello World", 1)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "Hello World")
            }
        )

        ParseModeTestKit.assertAcrossModes(
            i18nZh,
            "\t:::zh\n\t中文内容\n\t:::\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>中文内容</p>")
                AstTestKit.expectNodeCount(result.root, "I18nBlockNode", 1)
                let block = expectI18nBlock(
                    AstTestKit.child(result.root, 0, "I18nBlockNode"),
                    "zh",
                    "中文内容",
                    0,
                    25,
                    0,
                    17,
                    1
                )
                let paragraph = expectParagraph(AstTestKit.child(block, 0, "ParagraphNode"), "中文内容", 1)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "中文内容")
            }
        )
    }

    @TestCase
    func rejectsTopLevelI18nBlocksIndentedPastFourColumnsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nZh,
            "     :::zh\n     你好世界\n     :::\n",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "I18nBlockNode")
                @Expect(result.html, "<p>:::zh\n你好世界\n:::</p>")
            }
        )
    }

    @TestCase
    func preservesExtraContentIndentBeyondOpeningIndentAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            "  :::en\n    Indented content\n  :::\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Indented content</p>")
                AstTestKit.expectNodeCount(result.root, "I18nBlockNode", 1)
                let block = expectI18nBlock(
                    AstTestKit.child(result.root, 0, "I18nBlockNode"),
                    "en",
                    "  Indented content",
                    0,
                    34,
                    0,
                    34,
                    1
                )
                let paragraph = expectParagraph(
                    AstTestKit.child(block, 0, "ParagraphNode"),
                    "Indented content",
                    1
                )
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "Indented content")
            }
        )
    }

    @TestCase
    func trimsLanguageIdSupportsEmptyContentAndLessIndentedClosingAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            ":::  en  \nHello\n:::\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Hello</p>")
                let block = expectI18nBlock(
                    AstTestKit.child(result.root, 0, "I18nBlockNode"),
                    "en",
                    "Hello",
                    0,
                    19,
                    0,
                    19,
                    1
                )
                let paragraph = expectParagraph(AstTestKit.child(block, 0, "ParagraphNode"), "Hello", 1)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "Hello")
            }
        )

        ParseModeTestKit.assertAcrossModes(
            i18nZh,
            ":::zh\n:::\n",
            { result: ParseModeResult =>
                @Expect(result.html, "")
                let block = expectI18nBlock(
                    AstTestKit.child(result.root, 0, "I18nBlockNode"),
                    "zh",
                    "",
                    0,
                    9,
                    0,
                    9,
                    0
                )
                AstTestKit.expectLeaf(block)
            }
        )

        ParseModeTestKit.assertAcrossModes(
            i18nZh,
            "  :::zh\n  你好世界\n:::\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>你好世界</p>")
                let block = expectI18nBlock(
                    AstTestKit.child(result.root, 0, "I18nBlockNode"),
                    "zh",
                    "你好世界",
                    0,
                    26,
                    0,
                    18,
                    1
                )
                let paragraph = expectParagraph(AstTestKit.child(block, 0, "ParagraphNode"), "你好世界", 1)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "你好世界")
            }
        )
    }

    private func expectI18nBlock(
        node: Node,
        languageId: String,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64,
        childCount: Int64
    ): I18nBlockNode {
        if (let block: I18nBlockNode <- node) {
            @Expect(block.languageId, languageId)
            @Expect(block.content, content)
            @Expect(block.children.size, childCount)
            AstTestKit.expectSpan(block, startByte, endByte, startRune, endRune)
            return block
        }
        throw IllegalArgumentException("Expected I18nBlockNode, actual ${node.name}")
    }

    private func expectUniversalBlock(
        node: Node,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64,
        childCount: Int64
    ): UniversalBlockNode {
        if (let block: UniversalBlockNode <- node) {
            @Expect(block.content, content)
            @Expect(block.children.size, childCount)
            AstTestKit.expectSpan(block, startByte, endByte, startRune, endRune)
            return block
        }
        throw IllegalArgumentException("Expected UniversalBlockNode, actual ${node.name}")
    }

    private func expectParagraph(node: Node, content: String, childCount: Int64): ParagraphNode {
        if (let paragraph: ParagraphNode <- node) {
            @Expect(paragraph.content, content)
            @Expect(paragraph.children.size, childCount)
            return paragraph
        }
        throw IllegalArgumentException("Expected ParagraphNode, actual ${node.name}")
    }

    private func expectText(node: Node, content: String): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, content)
            AstTestKit.expectLeaf(text)
            return
        }
        throw IllegalArgumentException("Expected TextNode, actual ${node.name}")
    }
}
