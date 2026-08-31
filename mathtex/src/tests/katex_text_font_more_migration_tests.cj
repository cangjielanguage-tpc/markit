package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexText, KatexFont, KatexColor, KatexSizing]
class KatexTextFontMoreMigrationTests {
    @TestCase func migratedKatexTextNestedExpressionsShouldParse() { assertRendersAll(["\\text{a {b} \\blue{c} \\textcolor{#fff}{x} \\llap{x}}"]) }
    @TestCase func migratedKatexTextSpacesShouldRender() { assertRendersAll(["\\text{  a \\  }"]) }
    @TestCase func migratedKatexTextBackslashNewlineShouldParse() { assertRendersAll(["\\text{\\ \t\r \n \t\r  }"]) }
    @TestCase func migratedKatexTextVdotsShouldRender() { assertRendersAll(["\\text{a \\vdots b ⋮ d}"]) }
    @TestCase func migratedKatexTextSpacingFunctionsShouldRender() { assertRendersAll(["\\text{\\;\\,\\quad\\space\\nobreakspace}"]) }
    @TestCase func migratedKatexTextLigatureAeShouldRender() { assertRendersAll(["\\text{\\ae\\AE}"]) }
    @TestCase func migratedKatexTextLigatureOeShouldRender() { assertRendersAll(["\\text{\\oe\\OE}"]) }
    @TestCase func migratedKatexTextLigatureOslashShouldRender() { assertRendersAll(["\\text{\\o\\O}"]) }
    @TestCase func migratedKatexTextLigatureSsShouldRender() { assertRendersAll(["\\text{\\ss}"]) }
    @TestCase func migratedKatexTextAaShouldRender() { assertRendersAll(["\\text{\\aa\\AA}"]) }

    @TestCase func migratedKatexMathrmShouldRender() { assertRendersAll(["\\mathrm{ABC123}"]) }
    @TestCase func migratedKatexMathitShouldRender() { assertRendersAll(["\\mathit{ABC123}"]) }
    @TestCase func migratedKatexMathnormalShouldRender() { assertRendersAll(["\\mathnormal{ABC123}"]) }
    @TestCase func migratedKatexMathbbShouldRender() { assertRendersAll(["\\mathbb{ABC}"]) }
    @TestCase func migratedKatexMathcalShouldRender() { assertRendersAll(["\\mathcal{ABC}"]) }
    @TestCase func migratedKatexMathfrakShouldRender() { assertRendersAll(["\\mathfrak{ABC}"]) }
    @TestCase func migratedKatexMathsfShouldRender() { assertRendersAll(["\\mathsf{ABC123}"]) }
    @TestCase func migratedKatexMathttShouldRender() { assertRendersAll(["\\mathtt{ABC123}"]) }
    @TestCase func migratedKatexMathbfShouldRender() { assertRendersAll(["\\mathbf{ABC123}"]) }
    @TestCase func migratedKatexBoldsymbolShouldRender() { assertRendersAll(["\\boldsymbol{Ax2k\\omega\\Omega\\imath+}"]) }

    @TestCase func migratedKatexOldFontRmShouldRender() { assertRendersAll(["\\rm ABC"]) }
    @TestCase func migratedKatexOldFontItShouldRender() { assertRendersAll(["\\it ABC"]) }
    @TestCase func migratedKatexOldFontBfShouldRender() { assertRendersAll(["\\bf ABC"]) }
    @TestCase func migratedKatexOldFontSfShouldRender() { assertRendersAll(["\\sf ABC"]) }
    @TestCase func migratedKatexOldFontTtShouldRender() { assertRendersAll(["\\tt ABC"]) }
    @TestCase func migratedKatexOldFontCalShouldRender() { assertRendersAll(["\\cal ABC"]) }

    @TestCase func migratedKatexNamedColorBlueShouldRender() { assertRendersAll(["\\blue{x}"]) }
    @TestCase func migratedKatexNamedColorRedShouldRender() { assertRendersAll(["\\red{x}"]) }
    @TestCase func migratedKatexNamedColorGreenShouldRender() { assertRendersAll(["\\green{x}"]) }
    @TestCase func migratedKatexNamedColorPurpleShouldRender() { assertRendersAll(["\\purple{x}"]) }
    @TestCase func migratedKatexTextcolorShortHexShouldRender() { assertRendersAll(["\\textcolor{#fA6}{x}"]) }
    @TestCase func migratedKatexTextcolorLongHexShouldRender() { assertRendersAll(["\\textcolor{#fA6fA6}{x}"]) }
    @TestCase func migratedKatexTextcolorImplicitHashShouldRender() { assertRendersAll(["\\textcolor{fA6fA6}{x}"]) }
    @TestCase func migratedKatexTextcolorAlphaHexShouldRender() { assertRendersAll(["\\textcolor{#ff000080}{x}"]) }
    @TestCase func migratedKatexOldColorCommandShouldRender() { assertRendersAll(["\\color{#fA6}xy"]) }

    @TestCase func migratedKatexSizingTinyShouldRender() { assertRendersAll(["\\tiny{x}"]) }
    @TestCase func migratedKatexSizingScriptsizeShouldRender() { assertRendersAll(["\\scriptsize{x}"]) }
    @TestCase func migratedKatexSizingFootnotesizeShouldRender() { assertRendersAll(["\\footnotesize{x}"]) }
    @TestCase func migratedKatexSizingSmallShouldRender() { assertRendersAll(["\\small{x}"]) }
    @TestCase func migratedKatexSizingNormalsizeShouldRender() { assertRendersAll(["\\normalsize{x}"]) }
    @TestCase func migratedKatexSizingLargeShouldRender() { assertRendersAll(["\\large{x}"]) }
    @TestCase func migratedKatexSizingHugeShouldRender() { assertRendersAll(["\\Huge{x}"]) }
}
