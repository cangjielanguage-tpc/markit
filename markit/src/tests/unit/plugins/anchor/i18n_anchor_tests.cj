package markit.tests.unit.plugins.anchor

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class I18nAnchorTests {
    @TestCase
    func transparentLanguageBlockParagraphsExposeOriginalSourceAnchorsAcrossModes() {
        let markdown = "默认文本😀\n\n:::en\nEnglish paragraph long enough\n:::\n\n:::zh\n中文正文\n:::\n\n:::\nShared paragraph😀\n:::\n\n尾部:en{Tail}:\n"
        for (language in ["zh", "en"]) {
            ParseModeTestKit.assertAcrossModes(
                { => Markit(GFMBundle(blockAutoAnchor: true)).use(I18nPlugin(
                    config: I18nConfig(defaultLanguage: "zh", targetLanguage: language)
                )) },
                markdown,
                { result: ParseModeResult =>
                    let translated = if (language == "en") { "English paragraph long enough" } else { "中文正文" }
                    for (expected in [translated, "Shared paragraph😀"]) {
                        let start = markdown.indexOf(expected).getOrThrow()
                        let end = start + expected.size
                        @Expect(result.html.contains(
                            "<p data-source-start-byte=\"${start}\" data-source-end-byte=\"${end}\">${expected}</p>"
                        ), true)
                    }
                    // The default-only prefix is absent in English. Source-only
                    // translated paragraphs must not consume either counter.
                    let lastIndex = if (language == "en") { 1 } else { 2 }
                    @Expect(result.html.contains("id=\"0-block-${lastIndex}\""), true)
                    @Expect(result.html.contains("id=\"0-block-${lastIndex + 1}\""), false)
                }
            )
        }
    }
}
