package markit.tests.unit.plugins.commonmark.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.commonmark.inline.entity_reference.EntityReferenceNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func commonMark(): Markit {
    return Markit(CommonMarkBundle())
}

@Test
class EntityReferenceTests {
    @TestCase
    func rendersNamedEntityReferencesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Text with &nbsp; space and &copy; 中文\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Text with &nbsp; space and &copy; 中文</p>")
                expectEntityReferences(
                    result.root,
                    ["Named", "Named"],
                    ["nbsp", "copy"],
                    ["&nbsp;", "&copy;"],
                    [10, 27],
                    [16, 33],
                    40,
                    36
                )
            }
        )
    }

    @TestCase
    func rendersDecimalAndHexReferencesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Em dash: &#8212; and &#x2014;\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Em dash: &#8212; and &#x2014;</p>")
                expectEntityReferences(
                    result.root,
                    ["Decimal", "Hexadecimal"],
                    ["#8212", "#x2014"],
                    ["&#8212;", "&#x2014;"],
                    [9, 21],
                    [16, 29],
                    29,
                    29
                )
            }
        )
    }

    @TestCase
    func supportsCommonNamedEntitiesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "&lt; &gt; &amp; &quot; &apos;\n",
            "<p>&lt; &gt; &amp; &quot; &apos;</p>"
        )
    }

    @TestCase
    func invalidEntitiesStayEscapedTextAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Invalid: &invalid; &123; &#; &#abc; &nbsp &amp\n",
            "<p>Invalid: &amp;invalid; &amp;123; &amp;#; &amp;#abc; &amp;nbsp &amp;amp</p>"
        )
    }

    @TestCase
    func typstDecodesBasicNamedEntitiesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "&lt; &gt; &amp;\n",
            { result: ParseModeResult =>
                @Expect(result.typst, "\\< \\> &\n\n")
            }
        )
    }

    private func expectEntityReferences(
        root: Node,
        types: Array<String>,
        values: Array<String>,
        references: Array<String>,
        startOffsets: Array<Int64>,
        endOffsets: Array<Int64>,
        endByte: Int64,
        endRune: Int64
    ): Unit {
        @Expect(types.size, values.size)
        @Expect(types.size, references.size)
        @Expect(types.size, startOffsets.size)
        @Expect(types.size, endOffsets.size)
        AstTestKit.expectRoot(root, 1)
        AstTestKit.expectSpan(root, 0, endByte, 0, endRune)
        AstTestKit.expectNodeCount(root, "EntityReferenceNode", types.size)

        let paragraph = AstTestKit.child(root, 0, "ParagraphNode")
        AstTestKit.expectSpan(paragraph, 0, endByte, 0, endRune)
        let hasTrailingText = endOffsets[types.size - 1] < endByte
        let expectedChildCount = types.size * 2 + if (hasTrailingText) { 2 } else { 1 }
        @Expect(paragraph.children.size, expectedChildCount)
        for (i in 0..types.size) {
            let childIndex = i * 2 + 1
            if (let entity: EntityReferenceNode <- AstTestKit.child(paragraph, childIndex, "EntityReferenceNode")) {
                @Expect(entity.entityTypeName(), types[i])
                @Expect(entity.entityValue, values[i])
                @Expect(entity.entityReference, references[i])
                AstTestKit.expectSpan(entity, startOffsets[i], endOffsets[i], startOffsets[i], endOffsets[i])
                AstTestKit.expectLeaf(entity)
            }
        }
        let softBreakIndex = expectedChildCount - 1
        let softBreak = AstTestKit.child(paragraph, softBreakIndex, "SoftBreakNode")
        AstTestKit.expectSpan(softBreak, endByte, endByte + 1, endRune, endRune + 1)
        AstTestKit.expectLeaf(softBreak)
        expectTextLeaves(paragraph, hasTrailingText)
    }

    private func expectTextLeaves(paragraph: Node, hasTrailingText: Bool): Unit {
        let indexes = if (hasTrailingText) { [0, 2, 4] } else { [0, 2] }
        for (i in indexes) {
            if (let text: TextNode <- AstTestKit.child(paragraph, i, "TextNode")) {
                AstTestKit.expectLeaf(text)
            }
        }
    }
}
