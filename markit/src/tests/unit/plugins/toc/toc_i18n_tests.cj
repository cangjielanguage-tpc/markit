package markit.tests.unit.plugins.toc

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.toc.Toc
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func i18nGfmEn(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
}

private func i18nGfmZh(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "zh")
    ))
}

@Test
class TocI18nTests {
    @TestCase
    func extractsTargetLanguageHeadingTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nGfmEn,
            "## :zh{欢迎使用 Markit}: :en{Welcome to Markit}:\n",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.items.size, 1)
                @Expect(tocNode.items[0].text, "Welcome to Markit")
                @Expect(tocNode.items[0].level, 2)
            }
        )
    }

    @TestCase
    func extractsDefaultLanguageHeadingTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nGfmZh,
            "## :zh{欢迎使用 Markit}: :en{Welcome to Markit}:\n",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.items.size, 1)
                @Expect(tocNode.items[0].text, "欢迎使用 Markit ")
                @Expect(tocNode.items[0].level, 2)
            }
        )
    }
}
