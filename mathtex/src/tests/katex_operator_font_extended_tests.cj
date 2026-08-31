package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexOperator, KatexFont]
class KatexOperatorFontExtendedTests {
    @TestCase
    func migratedKatexOpSymbolBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("An op symbol builder")
        assertRendersAll([
            "\\int_i^n",
            "\\iint_i^n",
            "\\iiint_i^n",
            "\\int\\nolimits_i^n",
            "\\iint\\nolimits_i^n",
            "\\iiint\\nolimits_i^n",
            "\\oint_i^n",
            "\\oiint_i^n",
            "\\oiiint_i^n",
            "\\oint\\nolimits_i^n",
            "\\oiint\\nolimits_i^n",
            "\\oiiint\\nolimits_i^n",
            "\\mathop{\\int}",
            "\\mathop \\int"
        ])
    }

    @TestCase
    func migratedKatexOperatornameSupportShouldRender() {
        // Source: test/katex-spec.ts / describe("operatorname support")
        assertRendersAll([
            "\\operatorname{x*Π∑\\Pi\\sum\\frac a b}",
            "\\operatorname*{x*Π∑\\Pi\\sum\\frac a b}",
            "\\operatorname*{x*Π∑\\Pi\\sum\\frac a b}_y x",
            "\\operatorname*{x*Π∑\\Pi\\sum\\frac a b}\\limits_y x",
            "\\operatorname{sn}\\limits_{b>c}(b+c)"
        ])
    }

    @TestCase
    func migratedKatexFontParserAdditionalCasesShouldParse() {
        // Source: test/katex-spec.ts / describe("A font parser")
        assertParsesAll([
            "\\mathrm x",
            "\\mathbb x",
            "\\mathit x",
            "\\mathnormal x",
            "\\mathrm {x + 1}",
            "\\mathbb {x + 1}",
            "\\mathit {x + 1}",
            "\\mathnormal {x + 1}",
            "\\mathcal{ABC123}",
            "\\mathfrak{abcABC123}",
            "\\mathbb{R \\neq \\mathrm{R}}",
            "\\textcolor{blue}{\\mathbb R}"
        ])
    }

    @TestCase
    func migratedKatexStyleChangeAdditionalCasesShouldParse() {
        // Source: test/katex-spec.ts / describe("A style change parser")
        assertParsesAll([
            "\\displaystyle x",
            "\\textstyle x",
            "\\scriptstyle x",
            "\\scriptscriptstyle x",
            "a b { c d \\displaystyle e f } g h",
            "\\mathsf{x + \\displaystyle y}",
            "\\mathsf{x + \\textstyle y}",
            "\\mathsf{x + \\scriptstyle y}",
            "\\mathsf{x + \\scriptscriptstyle y}",
            "\\mathsf{\\text{x}}",
            "\\mathsf{\\raisebox{2pt}{x}}",
            "\\mathsf{\\fbox{x}}",
            "\\mathsf{\\colorbox{red}{x}}",
            "\\mathsf{\\fcolorbox{blue}{red}{x}}",
            "\\mathsf{\\angl{x}}",
            "\\mathsf{\\hbox{x}}"
        ])
    }
}
