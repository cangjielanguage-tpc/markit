package markit.tests.unit.property

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle, StandardMarkdownBundle}
import markit.core.nodes.Node
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func standard(): Markit {
    return Markit(StandardMarkdownBundle())
}

private func commonMark(): Markit {
    return Markit(CommonMarkBundle())
}

private func gfm(): Markit {
    return Markit(GFMBundle())
}

@Test
class UniversalPropertyTests {
    @TestCase
    func emptyMinimalAndWhitespaceInputsStayStableAcrossModes() {
        let inputs = [
            "",
            " ",
            "\n",
            "\t",
            "\r\n",
            "a",
            " \n ",
            "\n\n\n",
            "   \t  \n  "
        ]

        for (input in inputs) {
            assertAllModesMatch(standard, input)
            assertDirectDeterministic(standard, input)
        }
    }

    @TestCase
    func unicodeInputsStayStableAcrossModesAndOffsets() {
        let inputs = [
            "# 标题 with Chinese",
            "**粗体** text",
            "🚀 Emoji in markdown",
            "Ñoño español",
            "Русский текст",
            "العربية",
            "日本語のテキスト",
            "Mixed: 中文 + English + 🎉",
            "Zero-width: \u{200B}invisible\u{200B}",
            "Combining: e\u{0301}acute"
        ]

        for (input in inputs) {
            assertAllModesMatch(standard, input)
            ParseModeTestKit.assertAcrossModes(
                standard,
                input,
                { result: ParseModeResult =>
                    validateOffsetsWithinInput(result.root, input)
                }
            )
        }
    }

    @TestCase
    func malformedSyntaxDoesNotDestabilizeParsingAcrossModes() {
        let inputs = [
            "*incomplete bold",
            "[incomplete link",
            "`incomplete code",
            "# heading without space",
            "```\nunclosed code block",
            "- list item\n  incomplete nesting",
            "> incomplete\n> > quote",
            "![incomplete image",
            "**nested *italic* bold",
            "\\",
            "***",
            "___"
        ]

        for (input in inputs) {
            assertAllModesMatch(gfm, input)
            ParseModeTestKit.assertAcrossModes(
                gfm,
                input,
                { result: ParseModeResult =>
                    validateOffsetsWithinInput(result.root, input)
                }
            )
        }
    }

    @TestCase
    func escapedMarkdownSyntaxDoesNotCreateForbiddenNodesAcrossModes() {
        let cases = [
            ("\\*not bold\\*", "ItalicNode"),
            ("\\**not bold**", "BoldNode"),
            ("\\_not italic\\_", "ItalicNode"),
            ("\\__not bold__", "BoldNode"),
            ("\\[not a link\\]", "LinkNode"),
            ("\\[text\\](url)", "LinkNode"),
            ("\\`not code\\`", "InlineCodeNode"),
            ("\\# not a heading", "Heading1Node"),
            ("\\*\\*not bold\\*\\*", "BoldNode")
        ]

        for ((input, forbiddenNodeName) in cases) {
            ParseModeTestKit.assertAcrossModes(
                standard,
                input,
                { result: ParseModeResult =>
                    AstTestKit.expectNoNode(result.root, forbiddenNodeName)
                }
            )
        }
    }

    @TestCase
    func mixedLineEndingsAndControlCharactersStayDeterministic() {
        let inputs = [
            "Line 1\nLine 2\r\nLine 3\rLine 4",
            "# Heading\r\n\r\nParagraph\n\nAnother",
            "- Item 1\r\n- Item 2\n- Item 3\r",
            "> Quote\r\n> \r\n> Continued",
            "Text with \u{0001} control char",
            "Bell character: \u{0007}",
            "Null character: \u{0000}",
            "Delete character: \u{007F}",
            "Tab: \u{0009} and vertical tab: \u{000B}",
            "Form feed: \u{000C}"
        ]

        for (input in inputs) {
            assertDirectDeterministic(standard, input)
            assertDirectDeterministic(gfm, input)
            assertDirectDeterministic(commonMark, input)
        }
    }

    @TestCase
    func numericWhitespaceAndModerateNestingInputsStayStable() {
        let inputs = [
            "999999999. Large list number",
            "0. Zero list number",
            "1. Normal list number",
            "2147483647. Max int list number",
            "#    ",
            "-    ",
            ">    ",
            "```\n   \n```",
            "`   `",
            "[   ](url)",
            "![   ](url)",
            nestedQuoteInput(10)
        ]

        for (input in inputs) {
            assertAllModesMatch(gfm, input)
        }
    }

    @TestCase
    func basicMarkdownIsDeterministicAcrossBundles() {
        let inputs = [
            "# Heading",
            "**bold text**",
            "*italic text*",
            "`inline code`",
            "Simple paragraph",
            "\\*not bold\\*",
            "\\[not a link\\]",
            "\\`not code\\`",
            "\\# not a heading"
        ]

        for (input in inputs) {
            assertDirectDeterministic(standard, input)
            assertDirectDeterministic(gfm, input)
            assertDirectDeterministic(commonMark, input)
        }
    }

    private func assertAllModesMatch(markitFactory: () -> Markit, markdown: String): Unit {
        let results = ParseModeTestKit.collect(markitFactory, markdown)
        if (results.isEmpty()) {
            return
        }

        let expected = results[0]
        for (result in results) {
            assertSameRenderResult(expected, result, markdown)
        }
    }

    private func assertDirectDeterministic(markitFactory: () -> Markit, markdown: String): Unit {
        let first = markitFactory().parse(markdown)
        let second = markitFactory().parse(markdown)

        if (first.toHtml() != second.toHtml()) {
            throw IllegalArgumentException("HTML changed across direct parses for `${markdown}`")
        }
        if (first.toMarkdown() != second.toMarkdown()) {
            throw IllegalArgumentException("Markdown changed across direct parses for `${markdown}`")
        }
        if (first.toTypst() != second.toTypst()) {
            throw IllegalArgumentException("Typst changed across direct parses for `${markdown}`")
        }
        if (first.toJson() != second.toJson()) {
            throw IllegalArgumentException("JSON changed across direct parses for `${markdown}`")
        }
        if (first.toString() != second.toString()) {
            throw IllegalArgumentException("tree changed across direct parses for `${markdown}`")
        }
    }

    private func assertSameRenderResult(expected: ParseModeResult, actual: ParseModeResult, markdown: String): Unit {
        if (expected.html != actual.html) {
            throw IllegalArgumentException("HTML mismatch in ${actual.mode} for `${markdown}`")
        }
        if (expected.markdown != actual.markdown) {
            throw IllegalArgumentException("Markdown mismatch in ${actual.mode} for `${markdown}`")
        }
        if (expected.typst != actual.typst) {
            throw IllegalArgumentException("Typst mismatch in ${actual.mode} for `${markdown}`")
        }
        if (expected.json != actual.json) {
            throw IllegalArgumentException("JSON mismatch in ${actual.mode} for `${markdown}`")
        }
        if (expected.tree != actual.tree) {
            throw IllegalArgumentException("tree mismatch in ${actual.mode} for `${markdown}`")
        }
    }

    private func validateOffsetsWithinInput(root: Node, markdown: String): Unit {
        let maxRuneOffset = markdown.toRuneArray().size
        validateNodeOffsets(root, maxRuneOffset)
    }

    private func validateNodeOffsets(node: Node, maxRuneOffset: Int64): Unit {
        if (node.startOffset() < 0) {
            throw IllegalArgumentException("${node.name} has negative start offset")
        }
        if (node.endOffset() < node.startOffset()) {
            throw IllegalArgumentException("${node.name} has inverted offsets")
        }
        if (node.endOffset() > maxRuneOffset) {
            throw IllegalArgumentException("${node.name} end offset exceeds input")
        }

        for (child in node.children) {
            validateNodeOffsets(child, maxRuneOffset)
        }
    }

    private func nestedQuoteInput(maxDepth: Int64): String {
        let sb = StringBuilder()
        for (i in 0..maxDepth) {
            for (_ in 0..i) {
                sb.append(">")
            }
            sb.append(" Level ${i}\n")
        }
        return sb.toString()
    }
}
