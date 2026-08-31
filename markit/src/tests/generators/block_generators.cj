package markit.tests.generators

import std.random.Random

public class BlockGenerators {
    private let config: GeneratorConfig
    private let random: Random
    private let words = [
        "alpha",
        "beta",
        "markdown",
        "中文",
        "stream",
        "parser",
        "emoji"
    ]

    public init(config: GeneratorConfig, random: Random) {
        this.config = config
        this.random = random
    }

    public func generateHeading(): TestCase {
        let level = random.nextInt64(6) + 1
        let text = generateText(2, 4)
        let input = "${repeat("#", level)} ${text}\n"
        return TestCase(
            input,
            "<h${level} id=\"${slug(text)}\">${text}</h${level}>",
            description: "heading-${level}"
        )
    }

    public func generateParagraph(): TestCase {
        let text = generateText(4, 8)
        return TestCase("${text}\n", "<p>${text}</p>", description: "paragraph")
    }

    public func generateCodeBlock(): TestCase {
        let languages = ["cj", "text", "markdown", ""]
        let language = languages[random.nextInt64(languages.size)]
        let code = "let value = ${random.nextInt64(100)}"
        let info = if (language.isEmpty()) { "" } else { language }
        let input = "```" + info + "\n" + code + "\n```\n"
        let classAttr = if (language.isEmpty()) { "" } else { " class=\"language-${language}\"" }
        return TestCase(
            input,
            "<pre><code${classAttr}>${code}</code></pre>",
            description: "fenced-code"
        )
    }

    public func generateList(): TestCase {
        let first = generateText(1, 2)
        let second = generateText(1, 2)
        let input = "- ${first}\n- ${second}\n"
        return TestCase(
            input,
            "<ul><li>${first}</li><li>${second}</li></ul>",
            description: "unordered-list"
        )
    }

    public func generateBlockquote(): TestCase {
        let text = generateText(2, 4)
        return TestCase("> ${text}\n", "<blockquote><p>${text}</p></blockquote>", description: "blockquote")
    }

    public func generateDivider(): TestCase {
        return TestCase("---\n", "<hr />", description: "divider")
    }

    public func generateRandom(): TestCase {
        let choice = random.nextInt64(6)
        return match (choice) {
            case 0 => generateHeading()
            case 1 => generateParagraph()
            case 2 => generateCodeBlock()
            case 3 => generateList()
            case 4 => generateBlockquote()
            case _ => generateDivider()
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

    private func repeat(value: String, count: Int64): String {
        let out = StringBuilder(count)
        for (_ in 0..count) {
            out.append(value)
        }
        return out.toString()
    }

    private func slug(text: String): String {
        return text.replace(" ", "-")
    }
}
