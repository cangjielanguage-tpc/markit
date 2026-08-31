package markit.tests.unit.plugins.gfm.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.gfm.inline.autolink.AutolinkNode
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}
import markit.tests.utils.AstTestKit

private func gfm(): Markit {
    return Markit(GFMBundle())
}

@Test
class AutolinkTests {
    @TestCase
    func rendersBareUrlsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "Visit https://example.com/path?q=test#section\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Visit <a href=\"https://example.com/path?q=test#section\">https://example.com/path?q=test#section</a></p>")
                expectAutolink(
                    result.root,
                    "Url",
                    "https://example.com/path?q=test#section",
                    "https://example.com/path?q=test#section",
                    "Visit ",
                    "",
                    6,
                    45,
                    45
                )
            }
        )
    }

    @TestCase
    func rendersFtpUrlsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "Download ftp://files.example.com/file.zip\n",
            "<p>Download <a href=\"ftp://files.example.com/file.zip\">ftp://files.example.com/file.zip</a></p>"
        )
    }

    @TestCase
    func rendersBareEmailsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "Contact user+tag@example.com now\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Contact <a href=\"mailto:user+tag@example.com\">user+tag@example.com</a> now</p>")
                expectAutolink(
                    result.root,
                    "Email",
                    "mailto:user+tag@example.com",
                    "user+tag@example.com",
                    "Contact ",
                    " now",
                    8,
                    28,
                    32
                )
            }
        )
    }

    @TestCase
    func excludesTrailingPunctuationAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "Visit https://example.com. Email user@example.com!\n",
            "<p>Visit <a href=\"https://example.com\">https://example.com</a>. Email <a href=\"mailto:user@example.com\">user@example.com</a>!</p>"
        )
    }

    @TestCase
    func supportsMultipleBareLinksAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "Visit https://example.com and http://test.org\n",
            "<p>Visit <a href=\"https://example.com\">https://example.com</a> and <a href=\"http://test.org\">http://test.org</a></p>"
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
        let paragraph = AstTestKit.child(root, 0, "ParagraphNode")
        AstTestKit.expectSpan(paragraph, 0, paragraphEnd, 0, paragraphEnd)
        AstTestKit.expectNodeCount(root, "AutolinkNode", 1)
        @Expect(paragraph.children.size, if (afterText.isEmpty()) { 3 } else { 4 })

        expectText(AstTestKit.child(paragraph, 0, "TextNode"), beforeText, 0, linkStart)
        if (let link: AutolinkNode <- AstTestKit.child(paragraph, 1, "AutolinkNode")) {
            @Expect(link.autolinkTypeName(), autolinkType)
            @Expect(link.url, url)
            @Expect(link.displayText, displayText)
            AstTestKit.expectSpan(link, linkStart, linkEnd, linkStart, linkEnd)
            AstTestKit.expectLeaf(link)
        }
        if (!afterText.isEmpty()) {
            expectText(AstTestKit.child(paragraph, 2, "TextNode"), afterText, linkEnd, paragraphEnd)
            let softBreak = AstTestKit.child(paragraph, 3, "SoftBreakNode")
            AstTestKit.expectSpan(softBreak, paragraphEnd, paragraphEnd + 1, paragraphEnd, paragraphEnd + 1)
            AstTestKit.expectLeaf(softBreak)
        } else {
            let softBreak = AstTestKit.child(paragraph, 2, "SoftBreakNode")
            AstTestKit.expectSpan(softBreak, paragraphEnd, paragraphEnd + 1, paragraphEnd, paragraphEnd + 1)
            AstTestKit.expectLeaf(softBreak)
        }
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
