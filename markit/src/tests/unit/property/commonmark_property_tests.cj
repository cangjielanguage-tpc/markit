package markit.tests.unit.property

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.core.nodes.Node
import markit.plugins.commonmark.block.html_block.{HtmlBlockConfig, HTMLBlockNode}
import markit.plugins.commonmark.inline.commonmark_autolink.CommonMarkAutolinkNode
import markit.plugins.commonmark.inline.entity_reference.EntityReferenceNode
import markit.plugins.commonmark.inline.html_inline.{HtmlInlineTagPairingConfig, HTMLInlineNode}
import markit.plugins.standard.block.heading.HeadingNode
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func commonMark(): Markit {
    return Markit(CommonMarkBundle())
}

private func commonMarkWithHtmlMarkdown(): Markit {
    return Markit(CommonMarkBundle(
        htmlBlockConfig: HtmlBlockConfig(enableInlineMarkdownParsing: true)
    ))
}

private func commonMarkWithoutInlinePairing(): Markit {
    return Markit(CommonMarkBundle(
        htmlInlineTagPairingConfig: HtmlInlineTagPairingConfig(enabled: false)
    ))
}

@Test
class CommonMarkPropertyTests {
    @TestCase
    func setextHeadingsPreserveLevelsContentAndSlugAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Heading 1\n=========\n\n中文二级\n---------\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<h1 id=\"heading-1\">Heading 1</h1><h2 id=\"中文二级\">中文二级</h2>")
                AstTestKit.expectRoot(result.root, 2)
                expectHeading(AstTestKit.child(result.root, 0, "Heading1Node"), 1, "Heading 1", "heading-1")
                expectHeading(AstTestKit.child(result.root, 1, "Heading2Node"), 2, "中文二级", "中文二级")
            }
        )
    }

    @TestCase
    func dividerWithoutParagraphAndInvalidSetextStayDistinctAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "---\n\nNo heading\n-- x\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<hr /><p>No heading\n-- x</p>")
                AstTestKit.expectRoot(result.root, 2)
                AstTestKit.child(result.root, 0, "DividerNode")
                AstTestKit.child(result.root, 1, "ParagraphNode")
                AstTestKit.expectNoNode(result.root, "Heading1Node")
                AstTestKit.expectNoNode(result.root, "Heading2Node")
            }
        )
    }

    @TestCase
    func namedDecimalAndHexEntitiesPreserveTypeValueAndReferenceAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "&lt; &#8212; &#x2014; &copy; 中文\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>&lt; &#8212; &#x2014; &copy; 中文</p>")
                expectEntities(
                    result.root,
                    ["Named", "Decimal", "Hexadecimal", "Named"],
                    ["lt", "#8212", "#x2014", "copy"],
                    ["&lt;", "&#8212;", "&#x2014;", "&copy;"]
                )
            }
        )
    }

    @TestCase
    func invalidEntitiesRemainEscapedTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Invalid: &invalid; &123; &#; &#abc; &nbsp &amp\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Invalid: &amp;invalid; &amp;123; &amp;#; &amp;#abc; &amp;nbsp &amp;amp</p>")
                AstTestKit.expectNoNode(result.root, "EntityReferenceNode")
            }
        )
    }

    @TestCase
    func commonMarkAutolinksPreserveUrlEmailAndDisplayTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Visit <http://example.com> or email <user+tag@example.com>\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Visit <a href=\"http://example.com\">http://example.com</a> or email <a href=\"mailto:user+tag@example.com\">user+tag@example.com</a></p>")
                expectAutolinks(
                    result.root,
                    ["Url", "Email"],
                    ["http://example.com", "mailto:user+tag@example.com"],
                    ["http://example.com", "user+tag@example.com"]
                )
            }
        )
    }

    @TestCase
    func invalidAutolinkAndUnsafeAngleTextRemainParagraphTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "This is <not a link> and <bad space://url>\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>This is &lt;not a link&gt; and &lt;bad space://url&gt;</p>")
                AstTestKit.expectNoNode(result.root, "CommonMarkAutolink")
                AstTestKit.expectNoNode(result.root, "HTMLInlineNode")
            }
        )
    }

    @TestCase
    func htmlInlinePairingCanBeEnabledOrDisabledWithoutChangingHtmlAcrossModes() {
        let markdown = "Text with <span data-x=\"1\">中文 HTML</span> content\n"
        let expectedHtml = "<p>Text with <span data-x=\"1\">中文 HTML</span> content</p>"

        ParseModeTestKit.assertAcrossModes(
            commonMark,
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html, expectedHtml)
                expectHtmlInlineTags(result.root, ["Container"], ["span"])
            }
        )

        ParseModeTestKit.assertAcrossModes(
            commonMarkWithoutInlinePairing,
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html, expectedHtml)
                expectHtmlInlineTags(result.root, ["OpeningTag", "ClosingTag"], ["span", "span"])
            }
        )
    }

    @TestCase
    func htmlBlockTypesPreserveRawContentAndProtectionRulesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkWithHtmlMarkdown,
            "<pre>\nThis is **bold** text.\n</pre>\n\n<div>\nThis is **bold** text.\n</div>\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<pre>\nThis is **bold** text.\n</pre>\n<div><p>This is <strong>bold</strong> text.</p></div>")
                AstTestKit.expectNodeCount(result.root, "HTMLBlockNode", 2)
                AstTestKit.expectNodeCount(result.root, "BoldNode", 1)
                expectHtmlBlock(AstTestKit.child(result.root, 0, "HTMLBlockNode"), "SafeBlockTag", "pre", true)
                expectHtmlBlock(AstTestKit.child(result.root, 1, "HTMLBlockNode"), "SafeBlockTag", "div", false)
            }
        )
    }

    private func expectHeading(node: Node, level: Int64, content: String, slug: String): Unit {
        if (let heading: HeadingNode <- node) {
            @Expect(heading.level, level)
            @Expect(heading.content, content)
            @Expect(heading.slug, slug)
        }
    }

    private func expectEntities(root: Node, types: Array<String>, values: Array<String>, references: Array<String>): Unit {
        @Expect(types.size, values.size)
        @Expect(types.size, references.size)
        AstTestKit.expectNodeCount(root, "EntityReferenceNode", types.size)

        let paragraph = AstTestKit.child(root, 0, "ParagraphNode")
        var index: Int64 = 0
        for (child in paragraph.children) {
            if (let entity: EntityReferenceNode <- child) {
                @Expect(entity.entityTypeName(), types[index])
                @Expect(entity.entityValue, values[index])
                @Expect(entity.entityReference, references[index])
                index += 1
            }
        }
        @Expect(index, types.size)
    }

    private func expectAutolinks(root: Node, types: Array<String>, urls: Array<String>, displayTexts: Array<String>): Unit {
        @Expect(types.size, urls.size)
        @Expect(types.size, displayTexts.size)
        AstTestKit.expectNodeCount(root, "CommonMarkAutolink", types.size)

        let paragraph = AstTestKit.child(root, 0, "ParagraphNode")
        var index: Int64 = 0
        for (child in paragraph.children) {
            if (let link: CommonMarkAutolinkNode <- child) {
                @Expect(link.autolinkTypeName(), types[index])
                @Expect(link.url, urls[index])
                @Expect(link.displayText, displayTexts[index])
                index += 1
            }
        }
        @Expect(index, types.size)
    }

    private func expectHtmlInlineTags(root: Node, tagTypes: Array<String>, tagNames: Array<String>): Unit {
        @Expect(tagTypes.size, tagNames.size)
        AstTestKit.expectNodeCount(root, "HTMLInlineNode", tagTypes.size)

        let paragraph = AstTestKit.child(root, 0, "ParagraphNode")
        var index: Int64 = 0
        for (child in paragraph.children) {
            if (let html: HTMLInlineNode <- child) {
                @Expect(html.tagType.toString(), tagTypes[index])
                @Expect(html.tagName, tagNames[index])
                index += 1
            }
        }
        @Expect(index, tagTypes.size)
    }

    private func expectHtmlBlock(node: Node, blockType: String, tagName: String, protected: Bool): Unit {
        if (let block: HTMLBlockNode <- node) {
            @Expect(block.blockType.toString(), blockType)
            @Expect(block.tagName, tagName)
            @Expect(block.isContentProtected, protected)
        }
    }
}
