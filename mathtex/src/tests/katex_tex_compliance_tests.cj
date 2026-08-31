package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexTexCompliance]
class KatexTexComplianceTests {
    @TestCase
    func migratedKatexTexCompliantParserShouldAcceptTeXArguments() {
        // Source: test/katex-spec.ts / describe("A TeX-compliant parser")
        assertParsesAll([
            "\\frac 2 3",
            "\\frac {\\frac x y} z",
            "\\frac x {\\frac y z}",
            "\\frac {\\sqrt x} y",
            "\\frac x {\\sqrt y}",
            "\\frac {\\mathllap x} y",
            "\\frac x {\\mathllap y}",
            "\\mathllap {\\frac x y}",
            "\\mathllap {\\mathllap x}",
            "\\sqrt {\\mathllap x}",
            "x^{\\sqrt x}",
            "x^{\\mathllap x}",
            "x_{\\sqrt x}",
            "x_{\\mathllap x}",
            "x^\\imath",
            "x_\\imath",
            "x''''",
            "x_2''",
            "x''_2",
            "\\sqrt2^3",
            "\\frac23^4",
            "\\sqrt \\frac x y",
            "\\sqrt \\text x",
            "x^\\frac x y",
            "x_\\text x",
            "\\frac {\\left( x \\right)} y",
            "\\frac x {\\left( y \\right)}",
            "\\mathllap {\\left( x \\right)}",
            "\\sqrt {\\left( x \\right)}",
            "x^{\\left( x \\right)}"
        ])
    }

    @TestCase
    func migratedKatexOptionalArgumentsShouldParseWhenWellFormed() {
        // Source: test/katex-spec.ts / describe("An optional argument parser")
        assertParsesAll([
            "\\frac[1]{2}{3}",
            "\\rule[0.2em]{1em}{1em}",
            "\\sqrt[3]{2}",
            "\\sqrt{2}",
            "\\rule{1em}{2em}",
            "\\Large\\sqrt[3]{x}"
        ])
    }

    @TestCase
    func migratedKatexParserShouldRenderCoreBuildCases() {
        // Sources: genfrac builder, infix builder, optional argument parser.
        assertRendersAll([
            "\\frac{x}{y}",
            "\\dfrac{x}{y}",
            "\\tfrac{x}{y}",
            "\\cfrac{x}{y}",
            "\\genfrac ( ] {0.06em}{0}{a}{b+c}",
            "a \\over b",
            "a \\atop b",
            "a \\choose b",
            "a \\brace b",
            "a \\brack b",
            "\\sqrt[3]{2}",
            "\\rule[0.2em]{1em}{1em}"
        ])
    }
}
