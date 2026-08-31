package markit.tests.unit.plugins.commonmark.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.commonmark.inline.commonmark_autolink.CommonMarkAutolinkNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func commonMark(): Markit {
    return Markit(CommonMarkBundle())
}

@Test
class CommonMarkAutolinkTests {
    @TestCase
    func rendersHttpUrlAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Visit <http://example.com> for more info\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Visit <a href=\"http://example.com\">http://example.com</a> for more info</p>")
                expectAutolink(
                    result.root,
                    "Url",
                    "http://example.com",
                    "http://example.com",
                    "Visit ",
                    " for more info",
                    6,
                    26,
                    40
                )
            }
        )
    }

    @TestCase
    func rendersEmailAutolinkAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "Contact <user+tag@example.com> today\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Contact <a href=\"mailto:user+tag@example.com\">user+tag@example.com</a> today</p>")
                expectAutolink(
                    result.root,
                    "Email",
                    "mailto:user+tag@example.com",
                    "user+tag@example.com",
                    "Contact ",
                    " today",
                    8,
                    30,
                    36
                )
            }
        )
    }

    @TestCase
    func supportsCustomSchemeAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Open <git+ssh://user@server.com/repo.git>\n",
            "<p>Open <a href=\"git+ssh://user@server.com/repo.git\">git+ssh://user@server.com/repo.git</a></p>"
        )
    }

    @TestCase
    func supportsMultipleAutolinksAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "Visit <http://example.com> or email <user@example.com>\n",
            "<p>Visit <a href=\"http://example.com\">http://example.com</a> or email <a href=\"mailto:user@example.com\">user@example.com</a></p>"
        )
    }

    @TestCase
    func invalidAutolinkFallsBackToTextAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            commonMark,
            "This is <not a link> here\n",
            "<p>This is &lt;not a link&gt; here</p>"
        )
    }

    private func expectAutolink(
        root: Node,
        autolinkType: String,
        url: String,
        displayText: String,
        beforeText: String,
        afterText: String,
        linkStart: Int64,
        linkEnd: Int64,
        paragraphEnd: Int64
    ): Unit {
        AstTestKit.expectRoot(root, 1)
        AstTestKit.expectSpan(root, 0, paragraphEnd, 0, paragraphEnd)
        AstTestKit.expectNodeCount(root, "CommonMarkAutolink", 1)
        let paragraph = AstTestKit.child(root, 0, "ParagraphNode")
        AstTestKit.expectSpan(paragraph, 0, paragraphEnd, 0, paragraphEnd)
        @Expect(paragraph.children.size, 4)
        expectText(AstTestKit.child(paragraph, 0, "TextNode"), beforeText, 0, linkStart)
        if (let link: CommonMarkAutolinkNode <- AstTestKit.child(paragraph, 1, "CommonMarkAutolink")) {
            @Expect(link.autolinkTypeName(), autolinkType)
            @Expect(link.url, url)
            @Expect(link.displayText, displayText)
            AstTestKit.expectSpan(link, linkStart, linkEnd, linkStart, linkEnd)
            AstTestKit.expectLeaf(link)
        }
        expectText(AstTestKit.child(paragraph, 2, "TextNode"), afterText, linkEnd, paragraphEnd)
        let softBreak = AstTestKit.child(paragraph, 3, "SoftBreakNode")
        AstTestKit.expectSpan(softBreak, paragraphEnd, paragraphEnd + 1, paragraphEnd, paragraphEnd + 1)
        AstTestKit.expectLeaf(softBreak)
    }

    private func expectText(node: Node, content: String, start: Int64, end: Int64): Unit {
        if (let text: TextNode <- node) {
            @Expect(text.content, content)
            AstTestKit.expectSpan(text, start, end, start, end)
            AstTestKit.expectLeaf(text)
            return
        }
        throw IllegalArgumentException("Expected TextNode, actual ${node.name}")
    }
}
