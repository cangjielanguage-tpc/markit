package markit_kit.utils

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

private func statistics(source: String, target!: String = "zh"): ReadingStatistics {
    let parser = Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: target)))
    return ReadingStatistics.fromDocument(parser.parse(source).root())
}

@Test
class ReadingStatisticsTests {
    @TestCase
    func countsOnlyTargetLanguageProse() {
        let source = "中文说明。\n\n:::en\nEnglish explanation.\n:::\n"
        let zh = statistics(source)
        let en = statistics(source, target: "en")
        @Expect(zh.cjkCharacters, 4)
        @Expect(zh.words, 0)
        @Expect(en.cjkCharacters, 0)
        @Expect(en.words, 2)
    }

    @TestCase
    func excludesCodeMathHtmlAndImageMetadata() {
        let source = "正文。\n\n```antlr4\npackageHeader: Identifier;\n```\n\n" +
            "```mermaid\ngraph TD; A --> B;\n```\n\n$$\nlong formula\n$$\n\n" +
            "<div>unreadable raw HTML content</div>\n\n![image description](image.svg)\n"
        let result = statistics(source)
        @Expect(result.cjkCharacters, 2)
        @Expect(result.words, 0)
    }

    @TestCase
    func countsVisibleLabelsAndInlineIdentifiersWithoutUrlsOrMarkup() {
        let result = statistics("# 标题\n\n[文档](https://example.com/long/path) **hello** `Int64`\n")
        @Expect(result.cjkCharacters, 4)
        @Expect(result.words, 2)
    }

    @TestCase
    func preservesWordBoundariesAcrossBlocksAndInlineFormatting() {
        let result = statistics("un**defined**\n\nhello\nworld\n")
        @Expect(result.words, 3)
    }

    @TestCase
    func countsOnlyVisibleTableCellTranslations() {
        let source = "| :zh{术语}: :en{Term}: |\n| --- |\n| `Int64` |\n"
        @Expect(statistics(source).cjkCharacters, 2)
        @Expect(statistics(source).words, 1)
        @Expect(statistics(source, target: "en").words, 2)
    }

    @TestCase
    func combinesCharacterAndWordRatesWithSecondRounding() {
        @Expect(ReadingStatistics(400, 200).estimatedSeconds, 120)
        @Expect(ReadingStatistics(0, 1).estimatedSeconds, 1)
        @Expect(ReadingStatistics(0, 0).estimatedSeconds, 0)
    }
}
