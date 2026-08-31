package markit.tests.unit.property

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle, StandardMarkdownBundle}
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.tests.generators.{GeneratorConfig, MarkdownGenerator}
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class UniversalRoundTripPropertyTests {
    @TestCase
    func generatedDocumentsMatchExpectedHtmlAcrossAllParseModes() {
        let config = GeneratorConfig(8, 100, true, true, UInt64(2026))
        let generator = MarkdownGenerator(config: config)
        let random = generator.random()

        for (_ in 0..8) {
            let generated = generator.generateDocument(random)
            ParseModeTestKit.assertHtmlAcrossModes(
                { => Markit(StandardMarkdownBundle(fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false))) },
                generated.input,
                generated.expectedHtml
            )
        }
    }

    @TestCase
    func roundTripMarkdownHtmlAndTypstStayStableAcrossBundlesAndModes() {
        let cases = [
            ("standard", "# 标题\n\nUse `代码`\n\n> quote\n"),
            ("commonmark", "Heading\n=======\n\n<div>\n**bold**\n</div>\n"),
            ("gfm", "| A | B |\n| - | - |\n| 中 | ~~del~~ |\n\n[^n]: note\nUse [^n]\n")
        ]

        for ((bundle, markdown) in cases) {
            let factory = match (bundle) {
                case "commonmark" => { => Markit(CommonMarkBundle()) }
                case "gfm" => { => Markit(GFMBundle()) }
                case _ => { => Markit(StandardMarkdownBundle()) }
            }
            ParseModeTestKit.assertAcrossModes(
                factory,
                markdown,
                { result: ParseModeResult =>
                    let reparsed = factory().parse(result.markdown)
                    @Expect(reparsed.toHtml(), result.html)
                    @Expect(factory().parse(markdown).toJson(), result.json)
                    @Expect(factory().parse(markdown).toTypst(), result.typst)
                }
            )
        }
    }

    @TestCase
    func crlfAndByteChunkRoundTripProduceExactSameOutputs() {
        let markdown = "# 标题\r\n\r\n段落 with 中文\r\n\r\n```cj\r\nlet 值 = 1\r\n```\r\n"
        let results = ParseModeTestKit.collect({ => Markit(StandardMarkdownBundle()) }, markdown)
        let expected = results[0]

        for (result in results) {
            @Expect(result.html, expected.html)
            @Expect(result.markdown, expected.markdown)
            @Expect(result.typst, expected.typst)
            @Expect(result.json, expected.json)
            @Expect(result.tree, expected.tree)
        }
    }
}
