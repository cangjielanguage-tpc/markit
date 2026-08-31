package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*
import mathtex.{MathRenderOptions, MathRenderer}

@Test
@Tag[KatexMigration, KatexParser, KatexErrors]
class KatexErrorsMigrationTests {
    @TestCase
    func migratedKatexErrorsRejectCaretAtEndOfGroup() {
        // Source: test/errors-spec.ts / #handleSupSubscript / rejects ^ at end of group
        assertErrorsAll(["{1^}"])
    }

    @TestCase
    func migratedKatexErrorsRejectUnderscoreAtEndOfInput() {
        // Source: test/errors-spec.ts / #handleSupSubscript / rejects _ at end of input
        assertErrorsAll(["1_"])
    }

    @TestCase
    func migratedKatexErrorsRejectDoubleSuperscripts() {
        // Source: test/errors-spec.ts / #parseAtom / rejects double superscripts
        assertErrorsAll(["1^2^3", "1^{2+3}_4^5"])
    }

    @TestCase
    func migratedKatexErrorsRejectDoubleSubscripts() {
        // Source: test/errors-spec.ts / #parseAtom / rejects double subscripts
        assertErrorsAll(["1_2_3", "1_{2+3}^4_5"])
    }

    @TestCase
    func migratedKatexErrorsRejectUndefinedControlSequence() {
        // Source: test/errors-spec.ts / #parseGroup / undefined control sequence
        assertErrorsAll(["\\xyz"])
    }

    @TestCase
    func migratedKatexErrorsRejectExtraClosingBrace() {
        // Source: test/errors-spec.ts / parseInput expecting EOF / extra }
        assertErrorsAll(["{1+2}}"])
    }

    @TestCase
    func migratedKatexErrorsRejectExtraEndCommand() {
        // Source: test/errors-spec.ts / parseInput expecting EOF / extra \end
        assertErrorsAll(["x\\end{matrix}"])
    }

    @TestCase
    func migratedKatexErrorsRejectMissingRight() {
        // Source: test/errors-spec.ts / parseImplicitGroup expecting \right / missing \right
        assertErrorsAll(["\\left(1+2)"])
    }

    @TestCase
    func migratedKatexErrorsRejectIncorrectlyScopedRight() {
        // Source: test/errors-spec.ts / parseImplicitGroup expecting \right / incorrectly scoped \right
        assertErrorsAll(["{\\left(1+2}\\right)"])
    }

    @TestCase
    func migratedKatexErrorsRejectMissingColorGroup() {
        // Source: test/errors-spec.ts / parseSpecialGroup expecting braces / missing { for color
        assertErrorsAll(["\\textcolor#ffffff{text}"])
    }

    @TestCase
    func migratedKatexErrorsRejectMissingRuleSizeGroup() {
        // Source: test/errors-spec.ts / parseSpecialGroup expecting braces / missing { for size
        assertErrorsAll(["\\rule{1em}[2em]"])
    }

    @TestCase
    func migratedKatexErrorsRejectMalformedOptionalSqrt() {
        // Source: test/errors-spec.ts / parseOptionalGroup expecting ] cases
        assertErrorsAll(["\\sqrt[3", "\\sqrt[3{2}"])
    }

    @TestCase
    func migratedKatexErrorsRejectMissingSqrtGroupAtEnd() {
        // Source: test/errors-spec.ts / parseGroup expecting } at end of file
        assertErrorsAll(["\\sqrt{2"])
    }

    @TestCase
    func migratedKatexErrorsRejectUnclosedEnvironment() {
        // Source: test/errors-spec.ts / environments.js / parseArray missing \end
        assertErrorsAll(["\\begin{matrix}1"])
    }

    @TestCase
    func migratedKatexErrorsRejectMismatchedEnvironment() {
        // Source: test/errors-spec.ts / parseImplicitGroup / mismatched environments
        assertErrorsAll(["\\begin{pmatrix}1&2\\\\3&4\\end{bmatrix}+5"])
    }

    @TestCase
    func migratedKatexErrorsRejectUnsupportedTextModeMathFunction() {
        // Source: test/errors-spec.ts / parseFunction / math-mode functions in text mode
        assertErrorsAll(["\\text{\\sqrt2 is irrational}"])
    }

    @TestCase
    func migratedKatexErrorsRejectMissingArgumentsAtEnd() {
        // Source: test/errors-spec.ts / parseArguments / missing argument at end
        assertErrorsAll(["2\\sqrt", "1^{2\\sqrt}"])
    }

    @TestCase
    func migratedKatexErrorsRejectTextcolorBadColors() {
        // Source: test/katex-spec.ts / color parser bad custom colors
        assertErrorsAll([
            "\\textcolor{bad-color}{x}",
            "\\textcolor{#fA6f1}{x}",
            "\\textcolor{#gA6}{x}",
            "\\textcolor{#ff00008g}{x}",
            "\\textcolor{#ff00008}{x}",
            "\\textcolor{#ff000080f}{x}"
        ])
    }

    @TestCase
    func migratedKatexErrorsRejectIncompleteFunctions() {
        // Source: test/katex-spec.ts / TeX-compliant parser missing groups
        assertErrorsAll([
            "\\frac{x}",
            "\\textcolor{#fff}",
            "\\rule{1em}",
            "\\llap",
            "\\bigl",
            "\\text"
        ])
    }

    @TestCase
    func migratedKatexErrorsRejectUnmatchedRightAndMiddle() {
        // Source: test/katex-spec.ts / left/right parser unmatched cases
        assertErrorsAll([
            "\\dfrac{x}{y} \\right)",
            "(\\middle|\\dfrac{x}{y})"
        ])
    }

    @TestCase
    func migratedKatexThrowOnErrorFalseShouldRenderErrorSpan() {
        // Source: KaTeX render options / throwOnError=false.
        let result = MathRenderer().renderHtml("\\definitelyNotKatex", options: MathRenderOptions(throwOnError: false, errorColor: "#b00020"))
        @Expect(result.supported, false)
        @Expect(result.output.contains("class=\"katex-error\""), true)
        @Expect(result.output.contains("style=\"color:#b00020\""), true)
    }

    @TestCase
    func migratedKatexThrowOnErrorTrueShouldRaise() {
        // Source: KaTeX render options / throwOnError=true.
        var thrown = false
        try {
            let _ = MathRenderer().renderHtml("\\definitelyNotKatex", options: MathRenderOptions(throwOnError: true))
        } catch (e: IllegalArgumentException) {
            thrown = true
            @Expect(e.message.contains("Unsupported TeX expression"), true)
        }
        @Expect(thrown, true)
    }
}
