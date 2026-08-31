package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexSymbols]
class KatexSymbolsExtendedTests {
    @TestCase
    func migratedKatexSymbolTableSynonymsShouldRender() {
        // Source: test/katex-spec.ts / describe("The symbol table integrity")
        assertRendersAll([
            "<",
            ">",
            "\\lt",
            "\\gt",
            "\\left<\\frac{1}{x}\\right>",
            "\\left\\lt\\frac{1}{x}\\right\\gt"
        ])
    }

    @TestCase
    func migratedKatexAmsTextAndMathSymbolsShouldRender() {
        // Source: test/katex-spec.ts / describe("Symbols") / AMS symbols
        assertRendersAll([
            "\\yen\\checkmark\\circledR\\maltese",
            "\\text{\\yen\\checkmark\\circledR\\maltese}"
        ])
    }

    @TestCase
    func migratedKatexTextIAndJShouldRender() {
        // Source: test/katex-spec.ts / describe("Symbols") / it("should parse \\text{\\i\\j}")
        assertRendersAll(["\\text{\\i\\j}"])
    }

    @TestCase
    func migratedKatexSpacingFunctionsInMathAndTextShouldRender() {
        // Source: test/katex-spec.ts / describe("Symbols") / spacing in math or text mode
        assertRendersAll(["A\\;B\\,C\\nobreakspace \\text{A\\;B\\,C\\nobreakspace}"])
    }

    @TestCase
    func migratedKatexMinusoShouldRender() {
        // Source: test/katex-spec.ts / describe("Symbols") / it("should build \\minuso")
        assertRendersAll(["\\minuso"])
    }

    @TestCase
    func migratedKatexLigatureCommandsShouldRender() {
        // Source: test/katex-spec.ts / describe("Symbols") / ligature commands
        assertRendersAll(["\\text{\\ae\\AE\\oe\\OE\\o\\O\\ss}"])
    }

    @TestCase
    func migratedKatexTexvcSymbolsRemainCovered() {
        // Source: test/katex-spec.ts / describe("A texvc builder")
        assertRendersAll([
            "\\lang\\N\\darr\\R\\dArr\\Z\\Darr\\alef\\rang",
            "\\alefsym\\uarr\\Alpha\\uArr\\Beta\\Uarr\\Chi",
            "\\clubs\\diamonds\\hearts\\spades\\cnums\\Complex",
            "\\Dagger\\empty\\harr\\Epsilon\\hArr\\Eta\\Harr\\exist",
            "\\image\\larr\\infin\\lArr\\Iota\\Larr\\isin\\Kappa",
            "\\Mu\\lrarr\\natnums\\lrArr\\Nu\\Lrarr\\Omicron",
            "\\real\\rarr\\plusmn\\rArr\\reals\\Rarr\\Reals\\Rho",
            "\\text{\\sect}\\sdot\\sub\\sube\\supe",
            "\\Tau\\thetasym\\weierp\\Zeta"
        ])
    }
}
