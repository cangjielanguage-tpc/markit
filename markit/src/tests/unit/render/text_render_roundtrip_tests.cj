package markit.tests.unit.render

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.gfm.block.table.TableConfig
import markit.tests.utils.ParseModeTestKit

private func standard(): Markit {
    return Markit()
}

private func gfm(): Markit {
    return Markit(GFMBundle())
}

private func gfmThreeLine(): Markit {
    return Markit(GFMBundle(tableConfig: TableConfig(enableThreeLineTable: true)))
}

@Test
class TextRenderRoundTripTests {
    @TestCase
    func standardMarkdownPrimitiveRenderersMatchLegacyAcrossModes() {
        let cases = [
            ("Hello world.", "Hello world.\n\n"),
            ("# Title", "# Title\n\n"),
            ("- one\n- two", "- one\n- two\n\n"),
            ("> A quote.", "> A quote.\n\n"),
            ("```\ncode\n```", "```\ncode\n```\n\n"),
            ("---", "---\n\n")
        ]

        for ((markdown, expectedMarkdown) in cases) {
            ParseModeTestKit.assertMarkdownAcrossModes(standard, markdown, expectedMarkdown)
        }
    }

    @TestCase
    func standardTypstPrimitiveRenderersMatchLegacyAcrossModes() {
        let cases = [
            ("Hello world.", "Hello world.\n\n"),
            ("# Title", "= Title <title>\n\n"),
            ("- one\n- two", "- one\n- two\n\n"),
            ("```js\nlet x = 1\n```", "``````js\nlet x = 1\n``````\n\n")
        ]

        for ((markdown, expectedTypst) in cases) {
            ParseModeTestKit.assertTypstAcrossModes(standard, markdown, expectedTypst)
        }
    }

    @TestCase
    func gfmMarkdownPrimitiveRenderersMatchLegacyAcrossModes() {
        ParseModeTestKit.assertMarkdownAcrossModes(
            gfm,
            "| A | B |\n| --- | --- |\n| 1 | 2 |",
            "| A | B |\n| --- | --- |\n| 1 | 2 |\n\n"
        )

        ParseModeTestKit.assertMarkdownAcrossModes(
            gfm,
            "$$\nE = mc^2\n$$",
            "$$\nE = mc^2\n$$\n\n"
        )

        ParseModeTestKit.assertMarkdownAcrossModes(
            gfmThreeLine,
            "---\n| A | B |\n| --- | --- |\n| 1 | 2 |\n---",
            "---\n| A | B |\n| --- | --- |\n| 1 | 2 |\n---\n\n"
        )
    }

    @TestCase
    func standardMarkdownRoundTripStabilizesAcrossModes() {
        let inputs = [
            "Same text.",
            "# One",
            "```js\nx=1\n```",
            "- Item\n  - Nested\n- Done",
            "> Quote\n> with second line"
        ]

        for (markdown in inputs) {
            for (result in ParseModeTestKit.collect(standard, markdown)) {
                let first = result.markdown
                let second = standard().parse(first).toMarkdown()
                let third = standard().parse(second).toMarkdown()
                @Expect(second, third)
            }
        }
    }

    @TestCase
    func gfmMarkdownRoundTripStabilizesAcrossModes() {
        let inputs = [
            "| A | B |\n| --- | --- |\n| 1 | 2 |",
            "- [x] done\n- [ ] todo",
            "$$\nE = mc^2\n$$",
            "~~gone~~ and $x+y$",
            "Contact user@example.com"
        ]

        for (markdown in inputs) {
            for (result in ParseModeTestKit.collect(gfm, markdown)) {
                let first = result.markdown
                let second = gfm().parse(first).toMarkdown()
                let third = gfm().parse(second).toMarkdown()
                @Expect(second, third)
            }
        }
    }
}
