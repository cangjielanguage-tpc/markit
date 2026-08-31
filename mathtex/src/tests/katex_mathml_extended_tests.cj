package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexMathMl]
class KatexMathMlExtendedTests {
    @TestCase
    func migratedKatexMathMlGeneratesRightNodeTypes() {
        // Source: test/mathml-spec.ts / it("should generate the right types of nodes")
        assertRendersAll(["\\sin{x}+1\\;\\text{a}"])
    }

    @TestCase
    func migratedKatexMathMlConcatenatesDigitsCasesShouldRender() {
        // Source: test/mathml-spec.ts / it("should concatenate digits into single <mn>")
        assertRendersAll(["\\sin{\\alpha}=0.34=.34^1", "1{,}000{,}000"])
    }

    @TestCase
    func migratedKatexMathMlPrimeOperatorsShouldRender() {
        // Source: test/mathml-spec.ts / it("should make prime operators into <mo> nodes")
        assertRendersAll(["f'"])
    }

    @TestCase
    func migratedKatexMathMlPhantomShouldRender() {
        // Source: test/mathml-spec.ts / it("should generate <mphantom> nodes for \\phantom")
        assertRendersAll(["\\phantom{x}"])
    }

    @TestCase
    func migratedKatexMathMlLargeOperatorsShouldRender() {
        // Sources: MathML large operator/integral/operator cases.
        assertRendersAll([
            "\\displaystyle\\sum_a^b",
            "\\displaystyle\\int_a^b + \\oiint_a^b + \\oiiint_a^b",
            "\\textstyle\\sum_a^b"
        ])
    }

    @TestCase
    func migratedKatexMathMlLimsupCasesShouldRender() {
        // Source: test/mathml-spec.ts / limsup textstyle and displaymode cases.
        assertRendersAll(["\\limsup_{x \\rightarrow \\infty}"])
    }

    @TestCase
    func migratedKatexMathMlRaiseboxAndVcenterCasesShouldRender() {
        // Source: test/mathml-spec.ts / raisebox and vcenter cases.
        assertRendersAll(["\\raisebox{0.25em}{b}", "\\mathrel{\\vcenter{\\frac{a}{b}}}"])
    }

    @TestCase
    func migratedKatexMathMlDelimiterSizingShouldRender() {
        // Source: test/mathml-spec.ts / it("should size delimiters correctly")
        assertRendersAll(["(M) \\big(M\\big) \\Big(M\\Big) \\bigg(M\\bigg) \\Bigg(M\\Bigg)"])
    }

    @TestCase
    func migratedKatexMathMlColorboxShouldRender() {
        // Source: test/mathml-spec.ts / it("should use <menclose> for colorbox")
        assertRendersAll(["\\colorbox{red}{b}"])
    }

    @TestCase
    func migratedKatexMathMlCdEnvironmentShouldRender() {
        // Source: test/mathml-spec.ts / it("should build the CD environment properly")
        assertRendersAll(["\\begin{CD} A @>a>> B\\\\ @VVbV @VVcV\\\\ C @>d>> D \\end{CD}"])
    }

    @TestCase
    func migratedKatexMathMlHrefCasesShouldRender() {
        // Source: test/mathml-spec.ts / href MathML cases.
        assertRendersAll([
            "\\href{http://example.org}{\\alpha}",
            "p \\Vdash \\beta \\href{http://example.org}{+ \\alpha} \\times \\gamma"
        ])
    }

    @TestCase
    func migratedKatexMathMlMathchoiceCasesShouldRender() {
        // Source: test/mathml-spec.ts / it("should render mathchoice as if there was nothing")
        assertRendersAll([
            "\\displaystyle\\mathchoice{\\sum_{k = 0}^{\\infty} x^k}{T}{S}{SS}",
            "\\mathchoice{D}{\\sum_{k = 0}^{\\infty} x^k}{S}{SS}",
            "x_{\\mathchoice{D}{T}{\\sum_{k = 0}^{\\infty} x^k}{SS}}",
            "x_{y_{\\mathchoice{D}{T}{S}{\\sum_{k = 0}^{\\infty} x^k}}}"
        ])
    }

    @TestCase
    func migratedKatexMathMlBoldsymbolShouldRender() {
        // Source: test/mathml-spec.ts / boldsymbol mathvariant case.
        assertRendersAll(["\\boldsymbol{Ax2k\\omega\\Omega\\imath+}"])
    }

    @TestCase
    func migratedKatexMathMlTagShouldRender() {
        // Source: test/mathml-spec.ts / it("tags use <mlabeledtr>")
        assertRendersAll(["\\tag{hi} x+y^2"])
    }

    @TestCase
    func migratedKatexMathMlSpecialSpacesShouldRender() {
        // Source: test/mathml-spec.ts / normal and special spaces.
        assertRendersAll([
            "\\kern1em\\kern1ex",
            "\\,\\thinspace\\:\\>\\medspace\\;\\thickspace\\!\\negthinspace\\negmedspace\\negthickspace\\mkern1mu\\mkern3mu\\mkern4mu\\mkern5mu\\mkern-1mu\\mkern-3mu\\mkern-4mu\\mkern-5mu"
        ])
    }
}
