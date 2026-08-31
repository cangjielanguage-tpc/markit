package markit.tests.unit.plugins.gfm.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.gfm.inline.footnote.{FootnoteDefinitionNode, FootnoteReferenceNode}
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle())
}

@Test
class FootnoteTests {
    @TestCase
    func parsesFootnoteDefinitionAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^1]: This is a footnote\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<div id=\"fn:1\" class=\"footnote-definition\">This is a footnote</div>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectSpan(result.root, 0, 24, 0, 24)
                let definition = AstTestKit.child(result.root, 0, "FootnoteDefinitionNode")
                expectDefinition(definition, "1", "This is a footnote", 0, 0, 24, 0, 24)
                expectText(AstTestKit.child(definition, 0, "TextNode"), "This is a footnote", 6, 24, 6, 24)
            }
        )
    }

    @TestCase
    func parsesFootnoteReferenceAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^1]: Footnote content\n\nText with [^1] reference.\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<div id=\"fn:1\" class=\"footnote-definition\">Footnote content</div><p>Text with <a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\">1</a> reference.</p>")
                AstTestKit.expectRoot(result.root, 2)
                AstTestKit.expectSpan(result.root, 0, 49, 0, 49)

                let definition = AstTestKit.child(result.root, 0, "FootnoteDefinitionNode")
                expectDefinition(definition, "1", "Footnote content", 0, 0, 23, 0, 23)
                expectText(AstTestKit.child(definition, 0, "TextNode"), "Footnote content", 6, 22, 6, 22)

                let paragraph = AstTestKit.child(result.root, 1, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 24, 49, 24, 49)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "Text with ", 24, 34, 24, 34)
                expectReference(AstTestKit.child(paragraph, 1, "FootnoteReferenceNode"), "1", 1, 34, 38, 34, 38)
                expectText(AstTestKit.child(paragraph, 2, "TextNode"), " reference.", 38, 49, 38, 49)
                expectSoftBreak(AstTestKit.child(paragraph, 3, "SoftBreakNode"), 49, 50, 49, 50)
            }
        )
    }

    @TestCase
    func supportsForwardAndRepeatedReferencesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "First [^note] and second [^note].\n\n[^note]: Shared footnote\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>First <a id=\"fnref:note\" href=\"#fn:note\" class=\"footnote-ref\">1</a> and second <a id=\"fnref:note\" href=\"#fn:note\" class=\"footnote-ref\">1</a>.</p><div id=\"fn:note\" class=\"footnote-definition\">Shared footnote</div>")
            }
        )
    }

    @TestCase
    func supportsMultilineDefinitionAndInlineMarkdownAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^复杂-id_123]: First **bold** line\n    Second *italic* line\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<div id=\"fn:复杂-id_123\" class=\"footnote-definition\">First <strong>bold</strong> line\nSecond <em>italic</em> line</div>")
                if (let definition: FootnoteDefinitionNode <- result.root.children[0]) {
                    @Expect(definition.footnoteId, "复杂-id_123")
                    @Expect(definition.content, "First **bold** line\nSecond *italic* line")
                }
            }
        )
    }

    @TestCase
    func invalidFootnoteSyntaxFallsBackToParagraphAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "[^]: Empty ID\n[^note\n1]\n",
            "<p>[^]: Empty ID\n[^note\n1]</p>"
        )
    }

    @TestCase
    func preservesSequentialFootnoteNumbersAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^note1]: First footnote\n[^note2]: Second footnote\n[^note3]: Third footnote\n\nText [^note1] and [^note2] and [^note3].\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div id=\"fn:note1\" class=\"footnote-definition\">First footnote</div><div id=\"fn:note2\" class=\"footnote-definition\">Second footnote</div><div id=\"fn:note3\" class=\"footnote-definition\">Third footnote</div><p>Text <a id=\"fnref:note1\" href=\"#fn:note1\" class=\"footnote-ref\">1</a> and <a id=\"fnref:note2\" href=\"#fn:note2\" class=\"footnote-ref\">2</a> and <a id=\"fnref:note3\" href=\"#fn:note3\" class=\"footnote-ref\">3</a>.</p>"
                )
                expectFootnoteReference(result.root, "note1", 1)
                expectFootnoteReference(result.root, "note2", 2)
                expectFootnoteReference(result.root, "note3", 3)
            }
        )
    }

    @TestCase
    func keepsFootnoteIdsCaseSensitiveAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^Note]: Capitalized\n[^note]: Lowercase\n\nText [^Note] and [^note].\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div id=\"fn:Note\" class=\"footnote-definition\">Capitalized</div><div id=\"fn:note\" class=\"footnote-definition\">Lowercase</div><p>Text <a id=\"fnref:Note\" href=\"#fn:Note\" class=\"footnote-ref\">1</a> and <a id=\"fnref:note\" href=\"#fn:note\" class=\"footnote-ref\">2</a>.</p>"
                )
                expectFootnoteReference(result.root, "Note", 1)
                expectFootnoteReference(result.root, "note", 2)
            }
        )
    }

    @TestCase
    func ignoresDuplicateFootnoteDefinitionsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^1]: First definition\n[^1]: Second definition\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<div id=\"fn:1\" class=\"footnote-definition\">First definition</div>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectSpan(result.root, 0, 22, 0, 22)
                let definition = AstTestKit.child(result.root, 0, "FootnoteDefinitionNode")
                expectDefinition(definition, "1", "First definition", 0, 0, 22, 0, 22)
                expectText(AstTestKit.child(definition, 0, "TextNode"), "First definition", 6, 22, 6, 22)
            }
        )
    }

    @TestCase
    func keepsUndefinedFootnoteReferenceAsReferenceNodeAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "Text with [^undefined] reference.\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<p>Text with <a id=\"fnref:undefined\" href=\"#fn:undefined\" class=\"footnote-ref\">1</a> reference.</p>"
                )
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectSpan(result.root, 0, 33, 0, 33)
                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 0, 33, 0, 33)
                expectText(AstTestKit.child(paragraph, 0, "TextNode"), "Text with ", 0, 10, 0, 10)
                expectReference(AstTestKit.child(paragraph, 1, "FootnoteReferenceNode"), "undefined", 1, 10, 22, 10, 22)
                expectText(AstTestKit.child(paragraph, 2, "TextNode"), " reference.", 22, 33, 22, 33)
                expectSoftBreak(AstTestKit.child(paragraph, 3, "SoftBreakNode"), 33, 34, 33, 34)
            }
        )
    }

    @TestCase
    func supportsBlankLinesInsideFootnoteDefinitionsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^1]: First paragraph\n\n    Second paragraph\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div id=\"fn:1\" class=\"footnote-definition\">First paragraph\n\nSecond paragraph</div>"
                )
                if (let definition: FootnoteDefinitionNode <- result.root.children[0]) {
                    @Expect(definition.content, "First paragraph\n\nSecond paragraph")
                }
            }
        )
    }

    @TestCase
    func parsesInlineFootnoteReferenceWhenDefinitionColonIsMissingAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^1] Missing colon\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<p><a id=\"fnref:1\" href=\"#fn:1\" class=\"footnote-ref\">1</a> Missing colon</p>"
                )
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectSpan(result.root, 0, 18, 0, 18)
                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 0, 18, 0, 18)
                expectReference(AstTestKit.child(paragraph, 0, "FootnoteReferenceNode"), "1", 1, 0, 4, 0, 4)
                expectText(AstTestKit.child(paragraph, 1, "TextNode"), " Missing colon", 4, 18, 4, 18)
                expectSoftBreak(AstTestKit.child(paragraph, 2, "SoftBreakNode"), 18, 19, 18, 19)
            }
        )
    }

    @TestCase
    func supportsComplexAndUnicodeFootnoteIdsAndContentAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "[^复杂-id_123]: 中文脚注 with émojis 🚀\n\nUse [^复杂-id_123].\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div id=\"fn:复杂-id_123\" class=\"footnote-definition\">中文脚注 with émojis 🚀</div><p>Use <a id=\"fnref:复杂-id_123\" href=\"#fn:复杂-id_123\" class=\"footnote-ref\">1</a>.</p>"
                )
                if (let definition: FootnoteDefinitionNode <- result.root.children[0]) {
                    @Expect(definition.footnoteId, "复杂-id_123")
                    @Expect(definition.content, "中文脚注 with émojis 🚀")
                }
                expectFootnoteReference(result.root, "复杂-id_123", 1)
            }
        )
    }

    private func expectDefinition(
        node: Node,
        footnoteId: String,
        content: String,
        footnoteNumber: Int64,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let definition: FootnoteDefinitionNode <- node) {
            @Expect(definition.footnoteId, footnoteId)
            @Expect(definition.content, content)
            @Expect(definition.footnoteNumber, footnoteNumber)
            AstTestKit.expectSpan(definition, startByte, endByte, startRune, endRune)
            @Expect(definition.children.size, 1)
        }
    }

    private func expectReference(
        node: Node,
        footnoteId: String,
        footnoteNumber: Int64,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let reference: FootnoteReferenceNode <- node) {
            @Expect(reference.footnoteId, footnoteId)
            @Expect(reference.footnoteNumber, footnoteNumber)
            AstTestKit.expectSpan(reference, startByte, endByte, startRune, endRune)
            AstTestKit.expectLeaf(reference)
        }
    }

    private func expectText(
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
        }
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

    private func expectFootnoteReference(root: Node, footnoteId: String, footnoteNumber: Int64): Unit {
        if (expectFootnoteReferenceIn(root, footnoteId, footnoteNumber)) {
            return
        }
        throw IllegalArgumentException("Expected FootnoteReferenceNode")
    }

    private func expectFootnoteReferenceIn(node: Node, footnoteId: String, footnoteNumber: Int64): Bool {
        if (let reference: FootnoteReferenceNode <- node) {
            if (reference.footnoteId == footnoteId) {
                @Expect(reference.footnoteNumber, footnoteNumber)
                return true
            }
        }
        for (child in node.children) {
            if (expectFootnoteReferenceIn(child, footnoteId, footnoteNumber)) {
                return true
            }
        }
        return false
    }
}
