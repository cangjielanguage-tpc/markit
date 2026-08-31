package markit.tests.unit.generators

import std.random.Random
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.tests.generators.{
    BlockGenerators,
    GeneratorConfig,
    InlineGenerators,
    MarkdownGenerator,
    TestCase
}
import markit.tests.utils.ParseModeTestKit

@Test
class GeneratorInfrastructureTests {
    @TestCase
    func generatorConfigDefaultsAndCustomValuesAreStable() {
        let defaults = GeneratorConfig()
        @Expect(defaults.maxDepth, 3)
        @Expect(defaults.maxLength, 100)
        @Expect(defaults.includeEdgeCases, true)
        @Expect(defaults.includeSpecialChars, true)
        @Expect(defaults.seed, UInt64(0))

        let custom = GeneratorConfig(5, 200, false, true, UInt64(42))
        @Expect(custom.maxDepth, 5)
        @Expect(custom.maxLength, 200)
        @Expect(custom.includeEdgeCases, false)
        @Expect(custom.includeSpecialChars, true)
        @Expect(custom.seed, UInt64(42))
    }

    @TestCase
    func generatedTestCaseStoresExactInputExpectedHtmlAndDescription() {
        let testCase = TestCase("# Hello\n", "<h1 id=\"hello\">Hello</h1>", description: "heading")
        @Expect(testCase.input, "# Hello\n")
        @Expect(testCase.expectedHtml, "<h1 id=\"hello\">Hello</h1>")
        @Expect(testCase.description, "heading")
    }

    @TestCase
    func blockGeneratorsProduceMarkdownThatMatchesParserAcrossModes() {
        let config = GeneratorConfig(3, 80, true, true, UInt64(7))
        let random = Random(config.seed)
        let generator = BlockGenerators(config, random)

        assertGeneratedHtml(generator.generateHeading())
        assertGeneratedHtml(generator.generateParagraph())
        assertGeneratedHtml(generator.generateCodeBlock())
        assertGeneratedHtml(generator.generateList())
        assertGeneratedHtml(generator.generateBlockquote())
        assertGeneratedHtml(generator.generateDivider())
    }

    @TestCase
    func inlineGeneratorsProduceMarkdownThatMatchesParserAcrossModes() {
        let config = GeneratorConfig(3, 80, true, true, UInt64(11))
        let random = Random(config.seed)
        let generator = InlineGenerators(config, random)

        assertGeneratedHtml(generator.generateBold())
        assertGeneratedHtml(generator.generateItalic())
        assertGeneratedHtml(generator.generateInlineCode())
        assertGeneratedHtml(generator.generateLink())
        assertGeneratedHtml(generator.generateImage())
    }

    @TestCase
    func markdownGeneratorIsRepeatableForSameSeedAndModeStable() {
        let config = GeneratorConfig(6, 80, true, true, UInt64(99))
        let firstGenerator = MarkdownGenerator(config: config)
        let secondGenerator = MarkdownGenerator(config: config)

        let first = firstGenerator.generateDocument(firstGenerator.random())
        let second = secondGenerator.generateDocument(secondGenerator.random())

        @Expect(first.input, second.input)
        @Expect(first.expectedHtml, second.expectedHtml)
        @Expect(first.description, second.description)
        assertGeneratedHtml(first)
    }

    private func assertGeneratedHtml(testCase: TestCase): Unit {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(StandardMarkdownBundle(fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false))) },
            testCase.input,
            testCase.expectedHtml
        )
    }
}
