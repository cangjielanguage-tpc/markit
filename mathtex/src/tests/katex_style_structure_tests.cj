package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexHtml, KatexMathMl, KatexFont, KatexColor]
class KatexStyleStructureTests {
    @TestCase
    func migratedKatexHtmlFontCommandsShouldExposeStableClasses() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder").
        assertHtmlContains("\\mathrm{R}", "class=\"katex-font katex-font-mathrm mathrm\"")
        assertHtmlContains("\\mathbf{R}", "class=\"katex-font katex-font-mathbf mathbf\"")
        assertHtmlContains("\\mathbb{R}", "class=\"katex-font katex-font-mathbb mathbb\"")
        assertHtmlContains("\\mathcal{R}", "class=\"katex-font katex-font-mathcal mathcal\"")
        assertHtmlContains("\\mathfrak{R}", "class=\"katex-font katex-font-mathfrak mathfrak\"")
        assertHtmlContains("\\textsf{R}", "class=\"katex-font katex-font-textsf textsf\"")
        assertHtmlContains("\\texttt{R}", "class=\"katex-font katex-font-texttt texttt\"")
    }

    @TestCase
    func migratedKatexMathMlFontCommandsShouldExposeMathVariant() {
        // Source: test/katex-spec.ts / font tree-builder cases, asserted at the MathML accessibility layer.
        assertMathMlContains("\\mathrm{R}", "<mstyle mathvariant=\"normal\"><mrow><mrow><mi>R</mi></mrow></mrow></mstyle>")
        assertMathMlContains("\\mathbf{R}", "<mstyle mathvariant=\"bold\"><mrow><mrow><mi>R</mi></mrow></mrow></mstyle>")
        assertMathMlContains("\\mathbb{R}", "<mstyle mathvariant=\"double-struck\"><mrow><mrow><mi>R</mi></mrow></mrow></mstyle>")
        assertMathMlContains("\\mathfrak{R}", "<mstyle mathvariant=\"fraktur\"><mrow><mrow><mi>R</mi></mrow></mrow></mstyle>")
    }

    @TestCase
    func migratedKatexColorAndSizingShouldExposeHtmlAndMathMlStyleHooks() {
        // Sources: test/katex-spec.ts / color and sizing parser/builder cases.
        assertHtmlContains("\\textcolor{blue}{x}", "class=\"katex-color\" style=\"color:blue\"")
        assertHtmlContains("\\Large{x}", "class=\"katex-size katex-size-Large\"")
        assertMathMlContains("\\textcolor{blue}{x}", "<mstyle mathcolor=\"blue\"><mrow><mi>x</mi></mrow></mstyle>")
        assertMathMlContains("\\Large{x}", "<mstyle mathsize=\"1.44em\"><mrow><mi>x</mi></mrow></mstyle>")
    }

    @TestCase
    func migratedKatexColorBoxesShouldExposeHtmlHooksWithoutBundledCss() {
        // Source: test/katex-spec.ts / colorbox and fcolorbox builder cases.
        assertHtmlContains("\\colorbox{red}{x}", "class=\"stretchy colorbox katex-colorbox\" style=\"height:1.0306em;background-color:red;\"")
        assertHtmlContains("\\fcolorbox{blue}{yellow}{x}", "class=\"stretchy fcolorbox katex-fcolorbox\" style=\"height:1.305em;border-style:solid;border-width:0.04em;background-color:yellow;border-color:blue;\"")
    }
}
