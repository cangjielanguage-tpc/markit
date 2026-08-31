package markit.tests.generators

import std.random.Random

public class MarkdownGenerator {
    private let config: GeneratorConfig

    public init(config!: GeneratorConfig = GeneratorConfig()) {
        this.config = config
    }

    public func random(): Random {
        if (config.seed == 0) {
            return Random()
        }
        return Random(config.seed)
    }

    public func generateDocument(random: Random): TestCase {
        let blockGen = BlockGenerators(config, random)
        let count = if (config.maxDepth < 1) { 1 } else { config.maxDepth }
        let input = StringBuilder()
        let html = StringBuilder()

        for (i in 0..count) {
            if (i > 0) {
                input.append("\n")
            }
            let testCase = match (i % 5) {
                case 0 => blockGen.generateHeading()
                case 1 => blockGen.generateParagraph()
                case 2 => blockGen.generateCodeBlock()
                case 3 => blockGen.generateBlockquote()
                case _ => blockGen.generateDivider()
            }
            input.append(testCase.input)
            html.append(testCase.expectedHtml)
        }

        return TestCase(input.toString(), html.toString(), description: "document-${count}")
    }

    public func generateBlock(random: Random): TestCase {
        return BlockGenerators(config, random).generateRandom()
    }

    public func generateInline(random: Random): TestCase {
        return InlineGenerators(config, random).generateRandom()
    }
}
