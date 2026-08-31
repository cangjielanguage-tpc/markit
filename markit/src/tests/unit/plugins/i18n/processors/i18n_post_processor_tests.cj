package markit.tests.unit.plugins.i18n.processors

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.Node
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.i18n.nodes.I18nInlineNode
import markit.plugins.toc.Toc
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func i18nEn(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
}

private func i18nZh(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "zh")
    ))
}

@Test
class I18nPostProcessorTests {
    @TestCase
    func metadataMarksHiddenLanguageAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            ":zh{你好}: :en{Hello}: :{!}:",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Hello!</p>")
                expectLanguageNodeHidden(result.root, "zh", "你好")
            }
        )
    }

    @TestCase
    func tocExtractsOnlyRenderableHeadingTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            "## :zh{欢迎使用 Markit}: :en{Welcome to Markit}:",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.items.size, 1)
                @Expect(tocNode.items[0].text, "Welcome to Markit")
            }
        )
    }

    @TestCase
    func tocExtractsChineseHeadingWhenTargetIsChineseAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nZh,
            "## :zh{欢迎使用 Markit}: :en{Welcome to Markit}:",
            { result: ParseModeResult =>
                let tocNode = Toc.parse(result.root)
                @Expect(tocNode.items.size, 1)
                @Expect(tocNode.items[0].text, "欢迎使用 Markit ")
            }
        )
    }

    @TestCase
    func configValidationNormalizesAsciiCase() {
        let config = I18nConfig(defaultLanguage: "ZH", targetLanguage: "EN")
        @Expect(config.defaultLanguage, "zh")
        @Expect(config.targetLanguage, "en")
        @Expect(I18nConfig.validateLanguageId("zh-cn"), Some("zh-cn"))
        @Expect(I18nConfig.validateLanguageId("中"), None)
    }

    private func expectLanguageNodeHidden(root: Node, languageId: String, content: String): Unit {
        if (let Some(node) <- findI18nInline(root, languageId, content)) {
            @Expect(node.string("i18n_language"), Some(languageId))
            @Expect(node.string("render"), Some("false"))
            return
        }
        throw IllegalArgumentException("Expected hidden i18n inline node ${languageId}:${content}")
    }

    private func findI18nInline(root: Node, languageId: String, content: String): ?I18nInlineNode {
        if (let inline: I18nInlineNode <- root) {
            if (inline.languageId == languageId && inline.content == content) {
                return Some(inline)
            }
        }
        for (child in root.children) {
            if (let Some(found) <- findI18nInline(child, languageId, content)) {
                return Some(found)
            }
        }
        return None
    }
}
