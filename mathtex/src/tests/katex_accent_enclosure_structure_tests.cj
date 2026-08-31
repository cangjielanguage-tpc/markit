package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexHtml, KatexMathMl, KatexAccent, KatexEnclosure]
class KatexAccentEnclosureStructureTests {
    @TestCase
    func migratedKatexOverlineShouldExposeKaTeXLikeHtmlAndMathMl() {
        // Sources: src/functions/overline.ts and test/mathml-spec.ts accent snapshots.
        assertHtmlContains("\\overline{x}", "class=\"mord overline katex-over-accent katex-cmd-overline\"")
        assertHtmlContains("\\overline{x}", "class=\"overline-line katex-accent-line\"")
        assertMathMlContains("\\overline{x}", "<mover accent=\"true\">")
        assertMathMlContains("\\overline{x}", "<mo stretchy=\"true\">¯</mo>")
    }

    @TestCase
    func migratedKatexUnderlineShouldExposeKaTeXLikeHtmlAndMathMl() {
        // Source: src/functions/underline.ts.
        assertHtmlContains("\\underline{x}", "class=\"mord underline katex-under-accent katex-cmd-underline\"")
        assertHtmlContains("\\underline{x}", "class=\"underline-line katex-accent-line\"")
        assertMathMlContains("\\underline{x}", "<munder accentunder=\"true\">")
        assertMathMlContains("\\underline{x}", "<mo stretchy=\"true\">_</mo>")
    }

    @TestCase
    func migratedKatexSimpleAccentsShouldExposeAccentBodyAndMathMlMover() {
        // Source: src/functions/accent.ts.
        assertHtmlContains("\\hat{x}", "class=\"mord accent katex-accent katex-cmd-hat\"")
        assertHtmlContains("\\hat{x}", "class=\"accent-body katex-accent-body\"")
        assertHtmlContains("\\hat{x}", "class=\"vlist\" style=\"height:0.6944em;\"")
        assertHtmlContains("\\hat{x}", "class=\"accent-body katex-accent-body\" style=\"left:-0.1944em;\"")
        assertMathMlContains("\\hat{x}", "<mover accent=\"true\">")
        assertMathMlContains("\\hat{x}", "<mo stretchy=\"false\">^</mo>")
    }

    @TestCase
    func migratedKatexCombinedAccentsShouldKeepKaTeXLikeVlistBaselines() {
        // Source: src/functions/overline.ts, underline.ts, and accent.ts combined builder structure.
        let tex = "\\overline{x} + \\underline{y} + \\hat{z}"
        assertHtmlContains(tex, "class=\"mord overline katex-over-accent katex-cmd-overline\"")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:0.6306em;\"")
        assertHtmlContains(tex, "class=\"mord underline katex-under-accent katex-cmd-underline\"")
        assertHtmlContains(tex, "class=\"vlist-t vlist-t2\"")
        assertHtmlContains(tex, "class=\"vlist-s\">&#8203;</span>")
        assertHtmlContains(tex, "class=\"mord accent katex-accent katex-cmd-hat\"")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:0.6944em;\"")
    }

    @TestCase
    func migratedKatexStretchyAccentsShouldExposeStretchyMathMl() {
        // Source: src/stretchy.ts MathML path.
        assertHtmlContains("\\widetilde{ABCD}", "class=\"mord accent katex-over-accent katex-cmd-widetilde\"")
        assertHtmlContains("\\widetilde{ABCD}", "class=\"svg-align\"")
        assertHtmlContains("\\widetilde{ABCD}", "preserveAspectRatio=\"none\"")
        assertMathMlContains("\\widetilde{ABCD}", "<mo stretchy=\"true\">~</mo>")
    }

    @TestCase
    func migratedKatexWideAccentsShouldUseStretchySvgNotPlainRules() {
        // Source: src/stretchy.ts widehat, widetilde, and overrightarrow builders.
        let tex = "\\widehat{AB} + \\widetilde{xyz} + \\overrightarrow{PQ}"
        assertHtmlContains(tex, "class=\"mord accent katex-over-accent katex-cmd-widehat\"")
        assertHtmlContains(tex, "height=\"0.3em\" viewBox=\"0 0 2364 300\"")
        assertHtmlContains(tex, "class=\"mord accent katex-over-accent katex-cmd-widetilde\"")
        assertHtmlContains(tex, "height=\"0.286em\" viewBox=\"0 0 1033 286\"")
        assertHtmlContains(tex, "class=\"mord accent katex-over-accent katex-cmd-overrightarrow\"")
        assertHtmlContains(tex, "class=\"hide-tail\" style=\"height:0.522em;min-width:0.888em;\"")
    }

    @TestCase
    func migratedKatexBraceAccentsShouldUseStretchyBraceSvg() {
        // Source: src/stretchy.ts overbrace/underbrace builders.
        let tex = "\\overbrace{x+x+x}^{n} + \\underbrace{1+1+1}_{n}"
        assertHtmlContains(tex, "class=\"minner mover\"")
        assertHtmlContains(tex, "class=\"mord accent katex-over-accent katex-cmd-overbrace\"")
        assertHtmlContains(tex, "class=\"stretchy\" style=\"height:0.548em;min-width:1.6em;\"")
        assertHtmlContains(tex, "class=\"brace-left\" style=\"height:0.548em;\"")
        assertHtmlContains(tex, "class=\"brace-center\" style=\"height:0.548em;\"")
        assertHtmlContains(tex, "class=\"brace-right\" style=\"height:0.548em;\"")
        assertHtmlContains(tex, "width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMinYMin slice\"")
        assertHtmlContains(tex, "width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMidYMin slice\"")
        assertHtmlContains(tex, "width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMaxYMin slice\"")
        assertHtmlContains(tex, "class=\"minner munder\"")
        assertHtmlContains(tex, "class=\"mord accent katex-under-accent katex-cmd-underbrace\"")
        assertMathMlContains(tex, "<mo stretchy=\"true\">⏞</mo>")
        assertMathMlContains(tex, "<mo stretchy=\"true\">⏟</mo>")
    }

    @TestCase
    func migratedKatexBoxedAndCancelShouldExposeEnclosureHtmlAndMathMl() {
        // Sources: src/functions/enclose.ts and test/katex-spec.ts boxed/cancel builders.
        assertHtmlContains("\\boxed{x}", "class=\"mord katex-enclose katex-boxed\"")
        assertHtmlContains("\\boxed{x}", "class=\"boxpad\"")
        assertMathMlContains("\\boxed{x}", "<menclose notation=\"box\">")
        assertHtmlContains("\\cancel{x}", "class=\"mord katex-enclose katex-cancel cancel-lap\"")
        assertHtmlContains("\\cancel{x}", "class=\"stretchy cancel katex-cancel-line\"")
        assertMathMlContains("\\cancel{x}", "<menclose notation=\"updiagonalstrike\">")
        assertMathMlContains("\\xcancel{x}", "<menclose notation=\"updiagonalstrike downdiagonalstrike\">")
    }

    @TestCase
    func migratedKatexColorboxesShouldUseKaTeXBoxPaddingStructure() {
        // Source: src/functions/color.ts colorbox/fcolorbox HTML builders.
        let tex = "\\colorbox{yellow}{x} + \\fcolorbox{blue}{yellow}{y}"
        assertHtmlContains(tex, "class=\"stretchy colorbox katex-colorbox\" style=\"height:1.0306em;background-color:yellow;\"")
        assertHtmlContains(tex, "class=\"boxpad\"><span class=\"mord\"><span class=\"katex-symbol mord\">x</span>")
        assertHtmlContains(tex, "class=\"stretchy fcolorbox katex-fcolorbox\" style=\"height:1.305em;border-style:solid;border-width:0.04em;background-color:yellow;border-color:blue;\"")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:0.7706em;\"")
    }
}
