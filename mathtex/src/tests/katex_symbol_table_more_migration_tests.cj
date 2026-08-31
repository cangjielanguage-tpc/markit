package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexSymbols, KatexUnicode]
class KatexSymbolTableMoreMigrationTests {
    @TestCase func migratedKatexLowerGreekAlphaShouldRender() { assertRendersAll(["\\alpha"]) }
    @TestCase func migratedKatexLowerGreekBetaShouldRender() { assertRendersAll(["\\beta"]) }
    @TestCase func migratedKatexLowerGreekGammaShouldRender() { assertRendersAll(["\\gamma"]) }
    @TestCase func migratedKatexLowerGreekDeltaShouldRender() { assertRendersAll(["\\delta"]) }
    @TestCase func migratedKatexLowerGreekEpsilonShouldRender() { assertRendersAll(["\\epsilon"]) }
    @TestCase func migratedKatexLowerGreekVarepsilonShouldRender() { assertRendersAll(["\\varepsilon"]) }
    @TestCase func migratedKatexLowerGreekZetaShouldRender() { assertRendersAll(["\\zeta"]) }
    @TestCase func migratedKatexLowerGreekEtaShouldRender() { assertRendersAll(["\\eta"]) }
    @TestCase func migratedKatexLowerGreekThetaShouldRender() { assertRendersAll(["\\theta"]) }
    @TestCase func migratedKatexLowerGreekVarthetaShouldRender() { assertRendersAll(["\\vartheta"]) }
    @TestCase func migratedKatexLowerGreekIotaShouldRender() { assertRendersAll(["\\iota"]) }
    @TestCase func migratedKatexLowerGreekKappaShouldRender() { assertRendersAll(["\\kappa"]) }
    @TestCase func migratedKatexLowerGreekLambdaShouldRender() { assertRendersAll(["\\lambda"]) }
    @TestCase func migratedKatexLowerGreekMuShouldRender() { assertRendersAll(["\\mu"]) }
    @TestCase func migratedKatexLowerGreekNuShouldRender() { assertRendersAll(["\\nu"]) }
    @TestCase func migratedKatexLowerGreekXiShouldRender() { assertRendersAll(["\\xi"]) }
    @TestCase func migratedKatexLowerGreekRhoShouldRender() { assertRendersAll(["\\rho"]) }
    @TestCase func migratedKatexLowerGreekVarrhoShouldRender() { assertRendersAll(["\\varrho"]) }
    @TestCase func migratedKatexLowerGreekSigmaShouldRender() { assertRendersAll(["\\sigma"]) }
    @TestCase func migratedKatexLowerGreekVarsigmaShouldRender() { assertRendersAll(["\\varsigma"]) }
    @TestCase func migratedKatexLowerGreekTauShouldRender() { assertRendersAll(["\\tau"]) }
    @TestCase func migratedKatexLowerGreekUpsilonShouldRender() { assertRendersAll(["\\upsilon"]) }
    @TestCase func migratedKatexLowerGreekPhiShouldRender() { assertRendersAll(["\\phi"]) }
    @TestCase func migratedKatexLowerGreekVarphiShouldRender() { assertRendersAll(["\\varphi"]) }
    @TestCase func migratedKatexLowerGreekChiShouldRender() { assertRendersAll(["\\chi"]) }
    @TestCase func migratedKatexLowerGreekPiShouldRender() { assertRendersAll(["\\pi"]) }
    @TestCase func migratedKatexLowerGreekPsiShouldRender() { assertRendersAll(["\\psi"]) }
    @TestCase func migratedKatexLowerGreekOmegaShouldRender() { assertRendersAll(["\\omega"]) }

    @TestCase func migratedKatexUpperGreekGammaShouldRender() { assertRendersAll(["\\Gamma"]) }
    @TestCase func migratedKatexUpperGreekDeltaShouldRender() { assertRendersAll(["\\Delta"]) }
    @TestCase func migratedKatexUpperGreekThetaShouldRender() { assertRendersAll(["\\Theta"]) }
    @TestCase func migratedKatexUpperGreekLambdaShouldRender() { assertRendersAll(["\\Lambda"]) }
    @TestCase func migratedKatexUpperGreekXiShouldRender() { assertRendersAll(["\\Xi"]) }
    @TestCase func migratedKatexUpperGreekPiShouldRender() { assertRendersAll(["\\Pi"]) }
    @TestCase func migratedKatexUpperGreekSigmaShouldRender() { assertRendersAll(["\\Sigma"]) }
    @TestCase func migratedKatexUpperGreekUpsilonShouldRender() { assertRendersAll(["\\Upsilon"]) }
    @TestCase func migratedKatexUpperGreekPhiShouldRender() { assertRendersAll(["\\Phi"]) }
    @TestCase func migratedKatexUpperGreekPsiShouldRender() { assertRendersAll(["\\Psi"]) }
    @TestCase func migratedKatexUpperGreekOmegaShouldRender() { assertRendersAll(["\\Omega"]) }

    @TestCase func migratedKatexBigOperatorSumShouldRender() { assertRendersAll(["\\sum_{i=1}^n x_i"]) }
    @TestCase func migratedKatexBigOperatorProdShouldRender() { assertRendersAll(["\\prod_{i=1}^n x_i"]) }
    @TestCase func migratedKatexBigOperatorCoprodShouldRender() { assertRendersAll(["\\coprod_{i=1}^n x_i"]) }
    @TestCase func migratedKatexBigOperatorIntShouldRender() { assertRendersAll(["\\int_a^b f(x)dx"]) }
    @TestCase func migratedKatexBigOperatorIintShouldRender() { assertRendersAll(["\\iint_D f(x,y)dxdy"]) }
    @TestCase func migratedKatexBigOperatorIiintShouldRender() { assertRendersAll(["\\iiint_D f(x,y,z)dxdydz"]) }
    @TestCase func migratedKatexBigOperatorOintShouldRender() { assertRendersAll(["\\oint_C f(z)dz"]) }
    @TestCase func migratedKatexBigOperatorOiintShouldRender() { assertRendersAll(["\\oiint_S f(x,y,z)dS"]) }
    @TestCase func migratedKatexBigOperatorOiiintShouldRender() { assertRendersAll(["\\oiiint_V f(x,y,z)dV"]) }

    @TestCase func migratedKatexBinaryCdotShouldRender() { assertRendersAll(["a\\cdot b"]) }
    @TestCase func migratedKatexBinaryCdotpShouldRender() { assertRendersAll(["a\\cdotp b"]) }
    @TestCase func migratedKatexBinaryTimesShouldRender() { assertRendersAll(["a\\times b"]) }
    @TestCase func migratedKatexBinaryPmShouldRender() { assertRendersAll(["a\\pm b"]) }
    @TestCase func migratedKatexBinaryMpShouldRender() { assertRendersAll(["a\\mp b"]) }
    @TestCase func migratedKatexBinaryDivShouldRender() { assertRendersAll(["a\\div b"]) }
    @TestCase func migratedKatexBinaryOplusShouldRender() { assertRendersAll(["a\\oplus b"]) }
    @TestCase func migratedKatexBinaryOtimesShouldRender() { assertRendersAll(["a\\otimes b"]) }
    @TestCase func migratedKatexBinaryCupShouldRender() { assertRendersAll(["A\\cup B"]) }
    @TestCase func migratedKatexBinaryCapShouldRender() { assertRendersAll(["A\\cap B"]) }

    @TestCase func migratedKatexRelationLeqShouldRender() { assertRendersAll(["a\\leq b"]) }
    @TestCase func migratedKatexRelationGeqShouldRender() { assertRendersAll(["a\\geq b"]) }
    @TestCase func migratedKatexRelationNeqShouldRender() { assertRendersAll(["a\\neq b"]) }
    @TestCase func migratedKatexRelationNleqShouldRender() { assertRendersAll(["a\\nleq b"]) }
    @TestCase func migratedKatexRelationNgeqShouldRender() { assertRendersAll(["a\\ngeq b"]) }
    @TestCase func migratedKatexRelationCongShouldRender() { assertRendersAll(["a\\cong b"]) }
    @TestCase func migratedKatexRelationEquivShouldRender() { assertRendersAll(["a\\equiv b"]) }
    @TestCase func migratedKatexRelationApproxShouldRender() { assertRendersAll(["a\\approx b"]) }
    @TestCase func migratedKatexRelationSimShouldRender() { assertRendersAll(["a\\sim b"]) }
    @TestCase func migratedKatexRelationProptoShouldRender() { assertRendersAll(["a\\propto b"]) }
    @TestCase func migratedKatexRelationInShouldRender() { assertRendersAll(["a\\in B"]) }
    @TestCase func migratedKatexRelationNotinShouldRender() { assertRendersAll(["a\\notin B"]) }
    @TestCase func migratedKatexRelationSubsetShouldRender() { assertRendersAll(["A\\subset B"]) }
    @TestCase func migratedKatexRelationSubseteqShouldRender() { assertRendersAll(["A\\subseteq B"]) }
    @TestCase func migratedKatexRelationSupsetShouldRender() { assertRendersAll(["A\\supset B"]) }
    @TestCase func migratedKatexRelationSupseteqShouldRender() { assertRendersAll(["A\\supseteq B"]) }

    @TestCase func migratedKatexArrowToShouldRender() { assertRendersAll(["A\\to B"]) }
    @TestCase func migratedKatexArrowRightarrowShouldRender() { assertRendersAll(["A\\rightarrow B"]) }
    @TestCase func migratedKatexArrowLeftarrowShouldRender() { assertRendersAll(["A\\leftarrow B"]) }
    @TestCase func migratedKatexArrowDoubleRightShouldRender() { assertRendersAll(["A\\Rightarrow B"]) }
    @TestCase func migratedKatexArrowDoubleLeftShouldRender() { assertRendersAll(["A\\Leftarrow B"]) }
    @TestCase func migratedKatexArrowLeftrightShouldRender() { assertRendersAll(["A\\leftrightarrow B"]) }
    @TestCase func migratedKatexArrowDoubleLeftrightShouldRender() { assertRendersAll(["A\\Leftrightarrow B"]) }
    @TestCase func migratedKatexArrowIffShouldRender() { assertRendersAll(["A\\iff B"]) }
    @TestCase func migratedKatexArrowImpliesShouldRender() { assertRendersAll(["A\\implies B"]) }
    @TestCase func migratedKatexArrowImpliedbyShouldRender() { assertRendersAll(["A\\impliedby B"]) }
}
