package markit.tests.unit.property

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.gfm.inline.footnote.{FootnoteDefinitionNode, FootnoteReferenceNode}
import markit.plugins.standard.block.fenced_code_block.{FencedCodeBlockConfig, FencedCodeBlockNode}
import markit.plugins.standard.inline.image.ImageNode
import markit.plugins.standard.inline.link.LinkNode
import markit.bundles.StandardMarkdownBundle
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func standardOffset(): Markit {
    return Markit(StandardMarkdownBundle())
}

private func groupedFenceOffset(): Markit {
    return Markit(StandardMarkdownBundle(
        fencedCodeBlockConfig: FencedCodeBlockConfig(enableGroup: true)
    ))
}

private func gfmOffset(): Markit {
    return Markit(GFMBundle())
}

@Test
class UniversalOffsetPropertyTests {
    @TestCase
    func linkAndImageOffsetsStayExactForChineseLabelsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standardOffset,
            "[中](a.md) ![图](b.png)\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p><a href=\"a.html\">中</a> <img src=\"b.png\" alt=\"图\" /></p>")
                AstTestKit.expectSpan(result.root, 0, 25, 0, 21)
                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 0, 25, 0, 21)

                if (let link: LinkNode <- AstTestKit.child(paragraph, 0, "LinkNode")) {
                    @Expect(link.content, "中")
                    @Expect(link.url, "a.md")
                    @Expect(link.title, "")
                    AstTestKit.expectSpan(link, 0, 11, 0, 9)
                    AstTestKit.expectSpan(AstTestKit.child(link, 0, "TextNode"), 1, 4, 1, 2)
                }
                AstTestKit.expectSpan(AstTestKit.child(paragraph, 1, "TextNode"), 11, 12, 9, 10)
                if (let image: ImageNode <- AstTestKit.child(paragraph, 2, "ImageNode")) {
                    @Expect(image.alt, "图")
                    @Expect(image.src, "b.png")
                    @Expect(image.title, "")
                    AstTestKit.expectSpan(image, 12, 25, 10, 21)
                }
                AstTestKit.expectSpan(AstTestKit.child(paragraph, 3, "SoftBreakNode"), 25, 26, 21, 22)
            }
        )
    }

    @TestCase
    func groupedFenceOffsetsStayExactForUnicodeFileContentAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            groupedFenceOffset,
            "```ts\n///// main.ts\nconst 值 = 1;\n///// test.ts [cj]\n测试()\n```\n",
            { result: ParseModeResult =>
                let fenced = AstTestKit.child(result.root, 0, "FencedCodeBlockNode")
                if (let code: FencedCodeBlockNode <- fenced) {
                    @Expect(code.language, "ts")
                    @Expect(code.fileGroups.size, 2)
                    @Expect(code.fileGroups[0].filename, "main.ts")
                    @Expect(code.fileGroups[0].language, "ts")
                    @Expect(code.fileGroups[0].content, "const 值 = 1;")
                    @Expect(code.fileGroups[1].filename, "test.ts")
                    @Expect(code.fileGroups[1].language, "cj")
                    @Expect(code.fileGroups[1].content, "测试()")
                    AstTestKit.expectSpan(code, 0, 66, 0, 60)
                }
            }
        )
    }

    @TestCase
    func footnoteReferenceAndDefinitionOffsetsStayExactAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfmOffset,
            "文本[^注]\n\n[^注]: 第一行\n    第二行\n",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<p>文本<a id=\"fnref:注\" href=\"#fn:注\" class=\"footnote-ref\">1</a></p><div id=\"fn:注\" class=\"footnote-definition\">第一行\n第二行</div>"
                )
                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                if (let reference: FootnoteReferenceNode <- AstTestKit.child(paragraph, 1, "FootnoteReferenceNode")) {
                    @Expect(reference.footnoteId, "注")
                    @Expect(reference.footnoteNumber, 1)
                    AstTestKit.expectSpan(reference, 6, 12, 2, 6)
                }
                if (let definition: FootnoteDefinitionNode <- AstTestKit.child(result.root, 1, "FootnoteDefinitionNode")) {
                    @Expect(definition.footnoteId, "注")
                    @Expect(definition.footnoteNumber, 1)
                    @Expect(definition.content, "第一行\n第二行")
                    AstTestKit.expectSpan(definition, 14, 45, 8, 25)
                }
            }
        )
    }
}
