package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexFraction]
class KatexFractionSqrtTests {
    @TestCase
    func migratedKatexParserBatchFractionsInfixAndSqrtShouldParse() {
        // Sources:
        // - describe("A frac parser") / it("should also parse cfrac, dfrac, tfrac, and genfrac")
        // - describe("An over/brace/brack parser") / it("should not fail")
        // - describe("A genfrac builder") / it("should not fail")
        // - describe("A infix builder") / it("should not fail")
        // - describe("A sqrt parser") / it("should parse square roots")
        assertParsesAll([
            "\\frac{x}{y}",
            "\\dfrac{x}{y}",
            "\\tfrac{x}{y}",
            "\\cfrac{x}{y}",
            "\\genfrac ( ] {0.06em}{0}{a}{b+c}",
            "\\genfrac ( ] {0.8pt}{}{a}{b+c}",
            "\\genfrac {} {} {0.8pt}{}{a}{b+c}",
            "\\genfrac [ {} {0.8pt}{}{a}{b+c}",
            "1 \\over x",
            "1+2i \\over 3+4i",
            "a+b \\brace c+d",
            "a+b \\brack c+d",
            "a \\over b",
            "a \\atop b",
            "a \\choose b",
            "a \\brace b",
            "a \\brack b",
            "\\sqrt{x}",
            "\\sqrt{x^2 + y^2}",
            "\\sqrt[3]{x}",
            "\\sqrt[\\small 3]{x}",
            "\\sqrt[\\color{red} 3]{x}",
            "\\sqrt[\\textstyle 3]{x}",
            "\\sqrt[\\tt 3]{x}"
        ])
    }
}
