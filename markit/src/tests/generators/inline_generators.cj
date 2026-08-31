package markit.tests.generators

import std.random.Random

public class InlineGenerators {
    private let config: GeneratorConfig
    private let random: Random
    private let words = ["bold", "italic", "code", "link", "中文", "stream"]

    public init(config: GeneratorConfig, random: Random) {
        this.config = config
        this.random = random
    }

    public func generateBold(): TestCase {
        let text = generateText(1, 3)
        let delimiter = if (random.nextBool()) { "**" } else { "__" }
        return TestCase(
            "${delimiter}${text}${delimiter}\n",
            "<p><strong>${text}</strong></p>",
            description: "bold"
        )
    }

    public func generateItalic(): TestCase {
        let text = generateText(1, 3)
        let delimiter = if (random.nextBool()) { "*" } else { "_" }
        return TestCase(
            "${delimiter}${text}${delimiter}\n",
            "<p><em>${text}</em></p>",
            description: "italic"
        )
    }

    public func generateInlineCode(): TestCase {
        let text = "value_${random.nextInt64(100)}"
        return TestCase("`${text}`\n", "<p><code>${text}</code></p>", description: "inline-code")
    }

    public func generateLink(): TestCase {
        let text = generateText(1, 2)
        return TestCase(
            "[${text}](https://example.com/${text.replace(" ", "-")})\n",
            "<p><a href=\"https://example.com/${text.replace(" ", "-")}\">${text}</a></p>",
            description: "link"
        )
    }

    public func generateImage(): TestCase {
        let alt = generateText(1, 2)
        return TestCase(
            "![${alt}](images/generated.png \"title\")\n",
            "<p><img src=\"images/generated.png\" alt=\"${alt}\" title=\"title\" /></p>",
            description: "image"
        )
    }

    public func generateRandom(): TestCase {
        let choice = random.nextInt64(5)
        return match (choice) {
            case 0 => generateBold()
            case 1 => generateItalic()
            case 2 => generateInlineCode()
            case 3 => generateLink()
            case _ => generateImage()
        }
    }

    private func generateText(minWords: Int64, maxWords: Int64): String {
        let limit = if (config.maxLength < 8) { 8 } else { config.maxLength }
        let requested = minWords + random.nextInt64(maxWords - minWords + 1)
        let count = if (requested * 8 > limit) { minWords } else { requested }
        let out = StringBuilder()
        for (i in 0..count) {
            if (i > 0) {
                out.append(" ")
            }
            out.append(words[random.nextInt64(words.size)])
        }
        return out.toString()
    }
}
