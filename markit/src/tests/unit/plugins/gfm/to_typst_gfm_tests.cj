package markit.tests.unit.plugins.gfm

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle())
}

@Test
class ToTypstGFMTests {
    @TestCase
    func taskListMatchesLegacyTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            gfm,
            "- [x] done\n- [ ] todo\n",
            expectedTaskListTypst()
        )
    }

    @TestCase
    func footnoteReferenceInlinesDefinitionInTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            gfm,
            "[^1]: footnote **body**\n\nText[^1]\n",
            "Text#footnote[footnote *body*]\n\n"
        )
    }

    @TestCase
    func forwardFootnoteReferenceInlinesDefinitionInTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            gfm,
            "Text[^1]\n\n[^1]: footnote body\n",
            "Text#footnote[footnote body]\n\n"
        )
    }

    @TestCase
    func strikeAutolinkAndMathMatchLegacyTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            gfm,
            "~~gone~~ <https://example.com>\n\n$E = mc^2$\n\n$$\n\\int_0^1 x^2 \\, dx = \\frac{1}{3}\n$$\n",
            "#strike[gone] #link(\"https://example.com\")[https://example.com]\n\n$E = m c^2$\n\n$\nintegral_0^1 x^2 d x = frac(1, 3)\n$\n\n"
        )
    }

    @TestCase
    func mathCommandsMatchLegacyTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            gfm,
            "$\\forall x \\in A, \\sin x \\approx \\cos y, T1 \\equiv T2, A \\subseteq B$\n",
            "$forall x in A, sin x approx cos y, T 1 equiv T 2, A subset.eq B$\n\n"
        )
    }

    private func expectedTaskListTypst(): String {
        return String.join([
            "#grid(",
            "  columns: (1.2em, 1fr),",
            "  align: (left, horizon),",
            "  column-gutter: 0.65em,",
            "  row-gutter: 0.38em,",
            "  [#box(width: 0.95em, height: 0.95em, baseline: -0.05em, inset: 0pt, radius: 2.5pt, fill: rgb(\"#2563eb\"))[#align(center + horizon)[#text(fill: white, weight: \"bold\", size: 0.72em)[✓]]]], [#set par(first-line-indent: 0em, leading: 1em, spacing: 0.18em)",
            "done],",
            "  [#box(width: 0.95em, height: 0.95em, baseline: -0.05em, inset: 0pt, radius: 2.5pt, stroke: 0.75pt + rgb(\"#94a3b8\"))[]], [#set par(first-line-indent: 0em, leading: 1em, spacing: 0.18em)",
            "todo]",
            ")",
            "",
            ""
        ], delimiter: "\n")
    }
}
