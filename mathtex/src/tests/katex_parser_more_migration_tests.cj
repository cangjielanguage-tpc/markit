package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexStructure]
class KatexParserMoreMigrationTests {
    @TestCase
    func migratedKatexSupSubUnicodeScriptCharactersShouldParse() {
        // Source: test/katex-spec.ts / A subscript and superscript parser / Unicode (sub|super)script characters.
        assertRendersAll(["A² + B²⁺³ + ¹²C + E₂³ + F₂₊₃"])
        assertMathMlContains("A²", "<msup><mi>A</mi><mn>2</mn></msup>")
        assertMathMlContains("E₂³", "<msubsup><mi>E</mi><mn>2</mn><mn>3</mn></msubsup>")
    }

    @TestCase
    func migratedKatexSupSubUnicodeNucleuslessSuperscriptShouldParse() {
        // Source: test/katex-spec.ts / Unicode (sub|super)script characters / ^{12}C.
        assertRendersAll(["¹²C"])
    }

    @TestCase
    func migratedKatexSupSubUnicodeSubscriptRunShouldParse() {
        // Source: test/katex-spec.ts / Unicode (sub|super)script characters / F_{2+3}.
        assertRendersAll(["F₂₊₃"])
    }

    @TestCase
    func migratedKatexSupSubUnicodeSuperscriptRunShouldParse() {
        // Source: test/katex-spec.ts / Unicode (sub|super)script characters / B^{2+3}.
        assertRendersAll(["B²⁺³"])
    }

    @TestCase
    func migratedKatexLimitControlsAfterOperatorShouldParse() {
        // Source: test/katex-spec.ts / A parser with limit controls / directly follows an op node.
        assertRendersAll(["\\int\\limits_2^2 3", "\\sum\\nolimits_3^4 4"])
    }

    @TestCase
    func migratedKatexLimitControlsRightmostBeforeScriptsShouldParse() {
        // Source: test/katex-spec.ts / A parser with limit controls / multiple limit controls before scripts.
        assertRendersAll(["\\int\\nolimits\\limits_2^2", "\\int\\limits\\limits\\limits_2^2"])
    }

    @TestCase
    func migratedKatexBegingroupShouldParseAsSemisimpleGroup() {
        // Source: test/katex-spec.ts / A \begingroup...\endgroup parser / should not fail.
        assertRendersAll(["\\begingroup xy \\endgroup"])
    }

    @TestCase
    func migratedKatexBegingroupShouldNotAffectSpacing() {
        // Source: test/katex-spec.ts / A \begingroup...\endgroup parser / should not affect spacing in math mode.
        assertRendersAll(["\\begingroup x+ \\endgroup y"])
    }

    @TestCase
    func migratedKatexImplicitGroupSizingLargeShouldParse() {
        // Source: test/katex-spec.ts / An implicit group parser / \Large x.
        assertRendersAll(["\\Large x"])
    }

    @TestCase
    func migratedKatexImplicitGroupSizingInsideGroupShouldParse() {
        // Source: test/katex-spec.ts / An implicit group parser / sizing inside groups.
        assertRendersAll(["abc {abc \\Large xyz} abc"])
    }

    @TestCase
    func migratedKatexOptionalSqrtSizingIndexShouldParse() {
        // Source: test/katex-spec.ts / implicit group parser within optional groups / \sqrt[\small 3]{x}.
        assertRendersAll(["\\sqrt[\\small 3]{x}"])
    }

    @TestCase
    func migratedKatexOptionalSqrtColorIndexShouldParse() {
        // Source: test/katex-spec.ts / implicit group parser within optional groups / \sqrt[\color{red} 3]{x}.
        assertRendersAll(["\\sqrt[\\color{red} 3]{x}"])
    }

    @TestCase
    func migratedKatexOptionalSqrtStyleIndexShouldParse() {
        // Source: test/katex-spec.ts / implicit group parser within optional groups / \sqrt[\textstyle 3]{x}.
        assertRendersAll(["\\sqrt[\\textstyle 3]{x}"])
    }

    @TestCase
    func migratedKatexOptionalSqrtOldFontIndexShouldParse() {
        // Source: test/katex-spec.ts / implicit group parser within optional groups / \sqrt[\tt 3]{x}.
        assertRendersAll(["\\sqrt[\\tt 3]{x}"])
    }

    @TestCase
    func migratedKatexFracVariantsAsFracsShouldRender() {
        // Source: test/katex-spec.ts / A frac parser / cfrac, dfrac, tfrac, and genfrac as fracs.
        assertRendersAll([
            "\\dfrac{x}{y}",
            "\\tfrac{x}{y}",
            "\\cfrac{x}{y}",
            "\\genfrac ( ] {0.06em}{0}{a}{b+c}",
            "\\genfrac ( ] {0.8pt}{}{a}{b+c}"
        ])
    }

    @TestCase
    func migratedKatexGenfracEmptyDelimitersShouldRender() {
        // Source: test/katex-spec.ts / A genfrac builder / empty delimiter cases.
        assertRendersAll(["\\genfrac {} {} {0.8pt}{}{a}{b+c}"])
    }

    @TestCase
    func migratedKatexTfracInSubscriptShouldRenderLikeTextstyleFrac() {
        // Source: test/katex-spec.ts / A genfrac builder / \tfrac in subscript.
        assertRendersAll(["x_{\\tfrac{1}{2}}"])
    }

    @TestCase
    func migratedKatexDfracInSubscriptShouldRenderLikeDisplaystyleFrac() {
        // Source: test/katex-spec.ts / A genfrac builder / \dfrac in subscript.
        assertRendersAll(["x_{\\dfrac{a}{b}}", "x_{y_{\\dfrac{a}{b}}}"])
    }

    @TestCase
    func migratedKatexInfixAtopShouldParse() {
        // Source: test/katex-spec.ts / A frac parser / should parse atop.
        assertRendersAll(["x \\atop y"])
    }

    @TestCase
    func migratedKatexInfixBuilderVariantsShouldRender() {
        // Source: test/katex-spec.ts / A infix builder / should not fail.
        assertRendersAll(["a \\over b", "a \\atop b", "a \\choose b", "a \\brace b", "a \\brack b"])
    }
}
