package markit.tests.unit.plugins.i18n

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func checkTranslatedTextSpan(node: Node, markdown: String, expected: String): Int64 {
    var found: Int64 = 0
    if (let text: TextNode <- node) {
        if (text.content == expected) {
            let start = markdown.indexOf(expected).getOrThrow()
            @Expect(node.sourceSpan.startByte, start)
            @Expect(node.sourceSpan.endByte, start + expected.size)
            // The scanner treats CRLF as one terminator rune while retaining
            // both original bytes. Nested remapping must preserve both axes.
            var startRune: Int64 = 0
            for (_ in markdown[0..start].replace("\r\n", "\n").runes()) {
                startRune += 1
            }
            var runeLength: Int64 = 0
            for (_ in expected.runes()) {
                runeLength += 1
            }
            @Expect(node.sourceSpan.startRune, startRune)
            @Expect(node.sourceSpan.endRune, startRune + runeLength)
            @Expect(node.rawContent(), expected)
            found += 1
        }
    }
    for (child in node.children) {
        found += checkTranslatedTextSpan(child, markdown, expected)
    }
    return found
}

@Test
class I18nSourceSpanTests {
    @TestCase
    func translatedBlockDescendantsReferToOriginalDocumentAcrossModes() {
        let markdown = "中文😀 prefix\n\n  :::en\n  English **bold translated** suffix\n\n  > quote text\n  > > deep quote\n\n  - list item\n  :::\n\n> :::en\n> nested translation\n> :::\n"
        ParseModeTestKit.assertAcrossModes(
            { => Markit(GFMBundle()).use(I18nPlugin(config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en"))) },
            markdown,
            { result: ParseModeResult =>
                for (expected in ["English ", "bold translated", " suffix", "quote text", "deep quote", "list item", "nested translation"]) {
                    @Expect(checkTranslatedTextSpan(result.root, markdown, expected), 1)
                }
            }
        )
    }

    @TestCase
    func translatedCrLfBlocksPreserveOriginalByteCoordinatesAcrossModes() {
        let markdown = "中文😀\r\n\r\n:::en\r\nEnglish😀\r\n\r\n> quoted English\r\n:::\r\n"
        ParseModeTestKit.assertAcrossModes(
            { => Markit(GFMBundle()).use(I18nPlugin(config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en"))) },
            markdown,
            { result: ParseModeResult =>
                @Expect(checkTranslatedTextSpan(result.root, markdown, "English😀"), 1)
                @Expect(checkTranslatedTextSpan(result.root, markdown, "quoted English"), 1)
            }
        )
    }
}
