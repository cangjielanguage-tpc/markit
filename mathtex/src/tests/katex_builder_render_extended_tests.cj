package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexHtml, KatexBuilder]
class KatexBuilderRenderExtendedTests {
    @TestCase
    func migratedKatexMarkupGeneratorSigmaShouldRender() {
        // Source: test/katex-spec.ts / describe("A markup generator")
        assertRendersAll(["\\sigma^2"])
    }

    @TestCase
    func migratedKatexMarkupGeneratorSingleLetterShouldRenderMathMlAndHtml() {
        // Source: test/katex-spec.ts / describe("A markup generator")
        assertRendersAll(["a"])
    }

    @TestCase
    func migratedKatexBinBuilderNormalPlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll(["x + y"])
    }

    @TestCase
    func migratedKatexBinBuilderLeadingPlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll(["+ x"])
    }

    @TestCase
    func migratedKatexBinBuilderRepeatedPlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll(["x + + 2"])
    }

    @TestCase
    func migratedKatexBinBuilderOpenThenPlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll(["( + 2"])
    }

    @TestCase
    func migratedKatexBinBuilderRelThenPlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll(["= + 2"])
    }

    @TestCase
    func migratedKatexBinBuilderOpThenPlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll(["\\sin + 2"])
    }

    @TestCase
    func migratedKatexBinBuilderPunctThenPlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll([", + 2"])
    }

    @TestCase
    func migratedKatexBinBuilderColorBeforePlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll(["\\blue{x}+y"])
    }

    @TestCase
    func migratedKatexBinBuilderColorContainingPlusShouldRender() {
        // Source: test/katex-spec.ts / describe("A bin builder")
        assertRendersAll(["\\blue{x+}+y"])
    }

    @TestCase
    func migratedKatexPhantomSmashBuilderHphantomShouldRenderMord() {
        // Source: test/katex-spec.ts / describe("A \\phantom builder and \\smash builder")
        assertRendersAll(["\\hphantom{a}"])
    }

    @TestCase
    func migratedKatexPhantomSmashBuilderHphantomRelationShouldRenderMord() {
        // Source: test/katex-spec.ts / describe("A \\phantom builder and \\smash builder")
        assertRendersAll(["a\\hphantom{=}b"])
    }

    @TestCase
    func migratedKatexPhantomSmashBuilderHphantomBinShouldRenderMord() {
        // Source: test/katex-spec.ts / describe("A \\phantom builder and \\smash builder")
        assertRendersAll(["a\\hphantom{+}b"])
    }

    @TestCase
    func migratedKatexPhantomSmashBuilderSmashOrdShouldRenderMord() {
        // Source: test/katex-spec.ts / describe("A \\phantom builder and \\smash builder")
        assertRendersAll(["\\smash{a}"])
    }

    @TestCase
    func migratedKatexPhantomSmashBuilderSmashRelShouldRenderMord() {
        // Source: test/katex-spec.ts / describe("A \\phantom builder and \\smash builder")
        assertRendersAll(["\\smash{=}"])
    }

    @TestCase
    func migratedKatexPhantomSmashBuilderSmashBinBetweenAtomsShouldRenderMord() {
        // Source: test/katex-spec.ts / describe("A \\phantom builder and \\smash builder")
        assertRendersAll(["a\\smash{+}b"])
    }

    @TestCase
    func migratedKatexAccentBuilderVecShouldRender() {
        // Source: test/katex-spec.ts / describe("An accent builder")
        assertRendersAll(["\\vec{x}"])
    }

    @TestCase
    func migratedKatexAccentBuilderVecSupShouldRender() {
        // Source: test/katex-spec.ts / describe("An accent builder")
        assertRendersAll(["\\vec{x}^2"])
    }

    @TestCase
    func migratedKatexAccentBuilderVecSubShouldRender() {
        // Source: test/katex-spec.ts / describe("An accent builder")
        assertRendersAll(["\\vec{x}_2"])
    }

    @TestCase
    func migratedKatexAccentBuilderVecSubSupShouldRender() {
        // Source: test/katex-spec.ts / describe("An accent builder")
        assertRendersAll(["\\vec{x}_2^2"])
    }

    @TestCase
    func migratedKatexStretchyAccentWidehatShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and shifty accent builder")
        assertRendersAll(["\\widehat{AB}"])
    }

    @TestCase
    func migratedKatexStretchyAccentWidecheckShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and shifty accent builder")
        assertRendersAll(["\\widecheck{AB}"])
    }

    @TestCase
    func migratedKatexStretchyAccentWidehatSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and shifty accent builder")
        assertRendersAll(["\\widehat{AB}^2"])
    }

    @TestCase
    func migratedKatexStretchyAccentWidehatSubShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and shifty accent builder")
        assertRendersAll(["\\widehat{AB}_2"])
    }

    @TestCase
    func migratedKatexStretchyAccentWidehatSubSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and shifty accent builder")
        assertRendersAll(["\\widehat{AB}_2^2"])
    }

    @TestCase
    func migratedKatexOverrightarrowShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and non-shifty accent builder")
        assertRendersAll(["\\overrightarrow{AB}"])
    }

    @TestCase
    func migratedKatexOverrightarrowSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and non-shifty accent builder")
        assertRendersAll(["\\overrightarrow{AB}^2"])
    }

    @TestCase
    func migratedKatexOverrightarrowSubShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and non-shifty accent builder")
        assertRendersAll(["\\overrightarrow{AB}_2"])
    }

    @TestCase
    func migratedKatexOverrightarrowSubSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and non-shifty accent builder")
        assertRendersAll(["\\overrightarrow{AB}_2^2"])
    }

    @TestCase
    func migratedKatexStretchyMathMlWidetildeShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy MathML builder")
        assertRendersAll(["\\widetilde{ABCD}"])
    }

    @TestCase
    func migratedKatexUnderAccentUnderrightarrowShouldRender() {
        // Source: test/katex-spec.ts / describe("An under-accent builder")
        assertRendersAll(["\\underrightarrow{x}"])
    }

    @TestCase
    func migratedKatexUnderAccentUnderrightarrowSupShouldRender() {
        // Source: test/katex-spec.ts / describe("An under-accent builder")
        assertRendersAll(["\\underrightarrow{x}^2"])
    }

    @TestCase
    func migratedKatexUnderAccentUnderrightarrowSubShouldRender() {
        // Source: test/katex-spec.ts / describe("An under-accent builder")
        assertRendersAll(["\\underrightarrow{x}_2"])
    }

    @TestCase
    func migratedKatexUnderAccentUnderrightarrowSubSupShouldRender() {
        // Source: test/katex-spec.ts / describe("An under-accent builder")
        assertRendersAll(["\\underrightarrow{x}_2^2"])
    }

    @TestCase
    func migratedKatexXrightarrowShouldRender() {
        // Source: test/katex-spec.ts / describe("An extensible arrow builder")
        assertRendersAll(["\\xrightarrow{x}"])
    }

    @TestCase
    func migratedKatexXrightarrowSupShouldRender() {
        // Source: test/katex-spec.ts / describe("An extensible arrow builder")
        assertRendersAll(["\\xrightarrow{x}^2"])
    }

    @TestCase
    func migratedKatexXrightarrowSubShouldRender() {
        // Source: test/katex-spec.ts / describe("An extensible arrow builder")
        assertRendersAll(["\\xrightarrow{x}_2"])
    }

    @TestCase
    func migratedKatexXrightarrowSubSupShouldRender() {
        // Source: test/katex-spec.ts / describe("An extensible arrow builder")
        assertRendersAll(["\\xrightarrow{x}_2^2"])
    }

    @TestCase
    func migratedKatexXrightarrowOptionalShouldRender() {
        // Source: test/katex-spec.ts / describe("An extensible arrow builder")
        assertRendersAll(["\\xrightarrow[under]{over}"])
    }

    @TestCase
    func migratedKatexOverbraceShouldRender() {
        // Source: test/katex-spec.ts / describe("A horizontal brace builder")
        assertRendersAll(["\\overbrace{x}"])
    }

    @TestCase
    func migratedKatexOverbraceSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A horizontal brace builder")
        assertRendersAll(["\\overbrace{x}^2"])
    }

    @TestCase
    func migratedKatexUnderbraceSubShouldRender() {
        // Source: test/katex-spec.ts / describe("A horizontal brace builder")
        assertRendersAll(["\\underbrace{x}_2"])
    }

    @TestCase
    func migratedKatexUnderbraceSubSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A horizontal brace builder")
        assertRendersAll(["\\underbrace{x}_2^2"])
    }

    @TestCase
    func migratedKatexOverbracketShouldRender() {
        // Source: test/katex-spec.ts / describe("A horizontal bracket builder")
        assertRendersAll(["\\overbracket{x}"])
    }

    @TestCase
    func migratedKatexUnderbracketShouldRender() {
        // Source: test/katex-spec.ts / describe("A horizontal bracket builder")
        assertRendersAll(["\\underbracket{x}_2"])
    }

    @TestCase
    func migratedKatexBoxedShouldRender() {
        // Source: test/katex-spec.ts / describe("A boxed builder")
        assertRendersAll(["\\boxed{x}"])
    }

    @TestCase
    func migratedKatexBoxedSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A boxed builder")
        assertRendersAll(["\\boxed{x}^2"])
    }

    @TestCase
    func migratedKatexBoxedSubShouldRender() {
        // Source: test/katex-spec.ts / describe("A boxed builder")
        assertRendersAll(["\\boxed{x}_2"])
    }

    @TestCase
    func migratedKatexBoxedSubSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A boxed builder")
        assertRendersAll(["\\boxed{x}_2^2"])
    }

    @TestCase
    func migratedKatexColorboxShouldRender() {
        // Source: test/katex-spec.ts / describe("A colorbox builder")
        assertRendersAll(["\\colorbox{red}{a b}"])
    }

    @TestCase
    func migratedKatexColorboxSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A colorbox builder")
        assertRendersAll(["\\colorbox{red}{a b}^2"])
    }

    @TestCase
    func migratedKatexFcolorboxShouldRender() {
        // Source: test/katex-spec.ts / describe("A fcolorbox builder")
        assertRendersAll(["\\fcolorbox{blue}{yellow}{a b}"])
    }

    @TestCase
    func migratedKatexFcolorboxSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A fcolorbox builder")
        assertRendersAll(["\\fcolorbox{blue}{yellow}{a b}^2"])
    }

    @TestCase
    func migratedKatexCancelShouldRender() {
        // Source: test/katex-spec.ts / describe("A strike-through builder")
        assertRendersAll(["\\cancel{x}"])
    }

    @TestCase
    func migratedKatexCancelSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A strike-through builder")
        assertRendersAll(["\\cancel{x}^2"])
    }

    @TestCase
    func migratedKatexCancelSubShouldRender() {
        // Source: test/katex-spec.ts / describe("A strike-through builder")
        assertRendersAll(["\\cancel{x}_2"])
    }

    @TestCase
    func migratedKatexCancelSubSupShouldRender() {
        // Source: test/katex-spec.ts / describe("A strike-through builder")
        assertRendersAll(["\\cancel{x}_2^2"])
    }

    @TestCase
    func migratedKatexSoutTextShouldRender() {
        // Source: test/katex-spec.ts / describe("A strike-through builder")
        assertRendersAll(["\\text{\\sout{abc}}"])
    }

    @TestCase
    func migratedKatexActuarialAngleShouldRender() {
        // Source: test/katex-spec.ts / describe("A actuarial angle builder")
        assertRendersAll(["a_{\\angl{n}}"])
    }

    @TestCase
    func migratedKatexActuarialAngleWithTrailingAtomShouldRender() {
        // Source: test/katex-spec.ts / describe("A actuarial angle builder")
        assertRendersAll(["a_{\\angl{n}i}"])
    }

    @TestCase
    func migratedKatexActuarialAngleUnbracedShouldRender() {
        // Source: test/katex-spec.ts / describe("A actuarial angle builder")
        assertRendersAll(["a_{\\angl n}"])
    }

    @TestCase
    func migratedKatexActuarialAngleAliasShouldRender() {
        // Source: test/katex-spec.ts / describe("A actuarial angle builder")
        assertRendersAll(["a_\\angln"])
    }

    @TestCase
    func migratedKatexPhaseShouldRender() {
        // Source: test/katex-spec.ts / describe("\\phase")
        assertRendersAll(["\\phase{-78.2^\\circ}"])
    }
}
