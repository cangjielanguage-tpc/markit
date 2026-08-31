package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexText, KatexColor, KatexSizing]
class KatexTextColorSizingTests {
    @TestCase
    func migratedKatexParserBatchTextColorAndSizingShouldParse() {
        // Sources:
        // - describe("An implicit group parser")
        // - describe("A sizing parser")
        // - describe("A text parser")
        // - describe("A color parser")
        // - describe("Alpha hex color parser")
        assertParsesAll([
            "\\Large x",
            "abc {abc \\Large xyz} abc",
            "\\Large abc",
            "a \\Large abc",
            "a { b \\Large c } d",
            "\\Huge{x}\\small{x}",
            "\\tiny{x}",
            "\\scriptsize{x}",
            "\\footnotesize{x}",
            "\\normalsize{x}",
            "\\large{x}",
            "\\Large{x}",
            "\\LARGE{x}",
            "\\huge{x}",
            "\\Huge{x}",
            "\\text{a b}",
            "\\text x",
            "\\text{a {b} \\blue{c} \\textcolor{#fff}{x} \\llap{x}}",
            "\\text{  a \\  }",
            "\\text {moo}",
            "\\text{sin}^2",
            "\\text{a \\vdots b ⋮ d}",
            "\\blue{x}",
            "\\red{x}",
            "\\redA{x}",
            "\\textcolor{#fA6}{x}",
            "\\textcolor{#fA6fA6}{x}",
            "\\textcolor{fA6fA6}{x}",
            "\\textcolor{#ff000080}{x}",
            "\\textcolor{#1234ABCD}{z}",
            "\\textcolor{#abc8}{w}",
            "\\color{red}xy",
            "\\color{#fA6}xy"
        ])
    }
}
