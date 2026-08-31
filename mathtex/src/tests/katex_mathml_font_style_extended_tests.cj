package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexMathMl, KatexFont, KatexStyle]
class KatexMathMlFontStyleExtendedTests {
    @TestCase
    func migratedKatexMathMlLargeOperatorDisplaySumShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\displaystyle\\sum_a^b"])
    }

    @TestCase
    func migratedKatexMathMlIntegralSupsubShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\displaystyle\\int_a^b + \\oiint_a^b + \\oiiint_a^b"])
    }

    @TestCase
    func migratedKatexMathMlRegularOperatorTextstyleShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\textstyle\\sum_a^b"])
    }

    @TestCase
    func migratedKatexMathMlLimsupTextstyleShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\limsup_{x \\rightarrow \\infty}"])
    }

    @TestCase
    func migratedKatexMathMlRaiseboxShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\raisebox{0.25em}{b}"])
    }

    @TestCase
    func migratedKatexMathMlVcenterRelationShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathrel{\\vcenter{\\frac{a}{b}}}"])
    }

    @TestCase
    func migratedKatexMathMlDelimiterSizingShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["(M) \\big(M\\big) \\Big(M\\Big) \\bigg(M\\bigg) \\Bigg(M\\Bigg)"])
    }

    @TestCase
    func migratedKatexMathMlColorboxShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\colorbox{red}{b}"])
    }

    @TestCase
    func migratedKatexMathMlHrefAlphaShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\href{http://example.org}{\\alpha}"])
    }

    @TestCase
    func migratedKatexMathMlHrefInExpressionShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["p \\Vdash \\beta \\href{http://example.org}{+ \\alpha} \\times \\gamma"])
    }

    @TestCase
    func migratedKatexMathMlDisplayMathchoiceShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\displaystyle\\mathchoice{\\sum_{k = 0}^{\\infty} x^k}{T}{S}{SS}"])
    }

    @TestCase
    func migratedKatexMathMlTextMathchoiceShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathchoice{D}{\\sum_{k = 0}^{\\infty} x^k}{S}{SS}"])
    }

    @TestCase
    func migratedKatexMathMlScriptMathchoiceShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["x_{\\mathchoice{D}{T}{\\sum_{k = 0}^{\\infty} x^k}{SS}}"])
    }

    @TestCase
    func migratedKatexMathMlScriptScriptMathchoiceShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["x_{y_{\\mathchoice{D}{T}{S}{\\sum_{k = 0}^{\\infty} x^k}}}"])
    }

    @TestCase
    func migratedKatexMathMlBoldsymbolVariantsShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\boldsymbol{Ax2k\\omega\\Omega\\imath+}"])
    }

    @TestCase
    func migratedKatexMathMlTagShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\tag{hi} x+y^2"])
    }

    @TestCase
    func migratedKatexMathMlNormalSpacesShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\kern1em\\kern1ex"])
    }

    @TestCase
    func migratedKatexMathMlSpecialSpacesShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\,\\thinspace\\:\\>\\medspace\\;\\thickspace\\!\\negthinspace\\negmedspace\\negthickspace\\mkern1mu\\mkern3mu\\mkern4mu\\mkern5mu\\mkern-1mu\\mkern-3mu\\mkern-4mu\\mkern-5mu"])
    }

    @TestCase
    func migratedKatexMathMlLigaturesInTextShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\text{```Hi----'''}--\\texttt{```Hi----'''}\\text{\\tt ```Hi----'''}"])
    }

    @TestCase
    func migratedKatexMathMlTextFontsShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\text{roman\\textit{italic\\textbf{bold italic}}\\textbf{bold}\\textsf{ss\\textit{italic\\textbf{bold italic}}\\textbf{bold}}\\texttt{tt\\textit{italic\\textbf{bold italic}}\\textbf{bold}}}"])
    }

    @TestCase
    func migratedKatexMathMlMathsfDisplaystyleShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{x \\displaystyle y}"])
    }

    @TestCase
    func migratedKatexMathMlMathsfTextstyleShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{x \\textstyle y}"])
    }

    @TestCase
    func migratedKatexMathMlMathsfScriptstyleShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{x \\scriptstyle y}"])
    }

    @TestCase
    func migratedKatexMathMlMathsfScriptscriptstyleShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{x \\scriptscriptstyle y}"])
    }

    @TestCase
    func migratedKatexMathMlMathsfDfracShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{\\dfrac{ABC123}{xyz456}}"])
    }

    @TestCase
    func migratedKatexMathMlMathsfTfracShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{\\tfrac{ABC123}{xyz456}}"])
    }

    @TestCase
    func migratedKatexMathMlMathsfCfracShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{\\cfrac{ABC123}{xyz456}}"])
    }

    @TestCase
    func migratedKatexMathMlMathsfGenfracShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{\\genfrac{}{}{0.8pt}{0}{ABC123}{xyz456}}"])
    }

    @TestCase
    func migratedKatexMathMlResetFontInMatrixShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{\\begin{matrix}x\\end{matrix}}"])
    }

    @TestCase
    func migratedKatexMathMlResetFontInArrayShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{\\begin{array}{c}x\\end{array}}"])
    }

    @TestCase
    func migratedKatexMathMlResetFontInCdShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\mathsf{\\begin{CD}x\\end{CD}}"])
    }

    @TestCase
    func migratedKatexMathMlHboxResetsToTextstyleShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\displaystyle x \\hbox{$x$} x"])
    }

    @TestCase
    func migratedKatexMathMlTextContextShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll(["\\text{\\sf $x$}"])
    }
}
