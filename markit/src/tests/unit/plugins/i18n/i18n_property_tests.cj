package markit.tests.unit.plugins.i18n

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.tests.utils.ParseModeTestKit

@Test
class I18nPropertyTests {
    @TestCase
    func targetLanguageNeverRendersKnownOtherLanguageTokens() {
        let markitFactory = { =>
            Markit(GFMBundle()).use(I18nPlugin(
                config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
            ))
        }

        ParseModeTestKit.assertHtmlAcrossModes(
            markitFactory,
            ":zh{中文}: :en{English}:",
            "<p>English</p>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            markitFactory,
            "A :zh{甲}: B :en{Beta}: C",
            "<p>Beta</p>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            markitFactory,
            ":zh{中文 `code`}: :en{English **bold**}:",
            "<p>English <strong>bold</strong></p>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            markitFactory,
            ":::zh\n中文块\n:::\n:::en\nEnglish block\n:::",
            "<p>English block</p>"
        )
    }

    @TestCase
    func byteStreamingMatchesDirectForUnicodeSamples() {
        let samples = [
            ":zh{中文}: :en{English 中文}:",
            ":::en\n# 标题 Title\n:::\n",
            "before :{通用}: after :en{目标}:"
        ]

        for (markdown in samples) {
            let direct = Markit(GFMBundle()).use(I18nPlugin(
                config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
            )).parse(markdown).html()
            let session = Markit(GFMBundle()).use(I18nPlugin(
                config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
            )).createSession()
            for (byte in markdown) {
                session.feedBytes([byte])
            }
            session.finalize()
            @Expect(session.renderer().renderHtml(session.snapshot().root), direct)
        }
    }
}
