package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexUnicode, KatexSymbols]
class KatexUnicodeSymbolExtendedTests {
    @TestCase
    func migratedKatexUnicodeNegatedRelationsShouldParse() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should parse negated relations")
        assertParsesAll(["∉∤∦≁≆≠≨≩≮≯≰≱⊀⊁⊈⊉⊊⊋⊬⊭⊮⊯⋠⋡⋦⋧⋨⋩⋬⋭⪇⪈⪉⪊⪵⪶⪹⪺⫋⫌"])
    }

    @TestCase
    func migratedKatexUnicodeRelationsShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build relations")
        assertRendersAll(["∈∋∝∼∽≂≃≅≈≊≍≎≏≐≑≒≓≖≗≜≡≤≥≦≧≪≫≬≳≷≺≻≼≽≾≿∴∵∣≔≕⩴⋘⋙⟂⊨∌"])
    }

    @TestCase
    func migratedKatexUnicodeUnsupportedRelationsShouldStillParse() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should parse relations")
        assertParsesAll(["⊶⊷"])
    }

    @TestCase
    func migratedKatexUnicodeBigOperatorsShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build big operators")
        assertRendersAll(["∏∐∑∫∬∭∮⋀⋁⋂⋃⨀⨁⨂⨄⨆"])
    }

    @TestCase
    func migratedKatexUnicodeMoreRelationsShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build more relations")
        assertRendersAll(["⊂⊃⊆⊇⊏⊐⊑⊒⊢⊣⊩⊪⊸⋈⋍⋐⋑⋔⋛⋞⋟⌢⌣⩾⪆⪌⪕⪖⪯⪰⪷⪸⫅⫆≘≙≚≛≝≞≟≲⩽⪅≶⋚⪋"])
    }

    @TestCase
    func migratedKatexUnicodeSymbolsShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should parse symbols")
        assertRendersAll([
            "£¥ℂℍℑℎℓℕ℘ℙℚℜℝℤℲℵðℶℷℸ⅁∀∁∂∃∇∞∠∡∢♠♡♢♣♭♮♯✓°¬‼⋮·©",
            "\\text{£¥ℂℍℎ©®}"
        ])
    }

    @TestCase
    func migratedKatexUnicodeGreekCapitalLettersShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build Greek capital letters")
        assertRendersAll(["ΑΒΕΖΗΙΚΜΝΟΡΤΧϝ"])
    }

    @TestCase
    func migratedKatexUnicodeArrowsShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build arrows")
        assertRendersAll(["←↑→↓↔↕↖↗↘↙↚↛↞↠↢↣↦↩↪↫↬↭↮↰↱↶↷↼↽↾↾↿⇀⇁⇂⇃⇄⇆⇇⇈⇉"])
    }

    @TestCase
    func migratedKatexUnicodeMoreArrowsShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build more arrows")
        assertRendersAll(["⇊⇋⇌⇍⇎⇏⇐⇑⇒⇓⇔⇕⇚⇛⇝⟵⟶⟷⟸⟹⟺⟼"])
    }

    @TestCase
    func migratedKatexUnicodeBinaryOperatorsShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build binary operators")
        assertRendersAll(["±×÷∓∔∧∨∩∪≀⊎⊓⊔⊕⊖⊗⊘⊙⊚⊛⊝◯⊞⊟⊠⊡⊺⊻⊼⋇⋉⋊⋋⋌⋎⋏⋒⋓⩞⋅∘∖∙"])
    }

    @TestCase
    func migratedKatexUnicodeCommonOrdsShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build common ords")
        assertRendersAll(["§¶£¥∇∞⋅∠∡∢♠♡♢♣♭♮♯✓…⋮⋯⋱! ‼ ⦵"])
    }

    @TestCase
    func migratedKatexUnicodeDelimitersShouldRender() {
        // Source: test/katex-spec.ts / describe("Unicode") / it("should build delimiters")
        assertRendersAll([
            "\\left⌊\\frac{a}{b}\\right⌋",
            "\\left⌈\\frac{a}{b}\\right⌈",
            "\\left⟮\\frac{a}{b}\\right⟯",
            "\\left⟨\\frac{a}{b}\\right⟩",
            "\\left⎰\\frac{a}{b}\\right⎱",
            "┌x┐ └x┘",
            "⌜x⌝ ⌞x⌟",
            "⟦x⟧",
            "\\llbracket \\rrbracket",
            "\\lBrace \\rBrace"
        ])
    }

    @TestCase
    func migratedKatexUnicodeAccentTextShouldParse() {
        // Source: test/katex-spec.ts / describe("Unicode accents")
        assertParsesAll([
            "ÀÁÂÃÄÅÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåèéêëìíîïñòóôõöùúûüýÿ",
            "\\text{ÀÁÂÃÄÅÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåèéêëìíîïñòóôõöùúûüýÿ}",
            "ấā́ắ\\text{ấā́ắ}",
            "íȷ́"
        ])
    }
}
