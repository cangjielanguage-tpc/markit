package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexAccent, KatexEnclosure]
class KatexAccentEnclosureTests {
    @TestCase
    func migratedKatexParserBatchAccentsAndEnclosuresShouldParse() {
        // Sources:
        // - MathML accents turn into mover
        // - describe("An overline parser")
        // - describe("A colorbox parser")
        // - describe("An fcolorbox parser")
        // - describe("A strike-through parser")
        // - describe("A phantom parser")
        // - describe("A smash parser")
        assertParsesAll([
            "\\hat{x}",
            "\\widehat{xyz}",
            "\\bar{x}",
            "\\vec{x}",
            "\\tilde{x}",
            "\\dot{x}",
            "\\ddot{x}",
            "\\acute{x}",
            "\\grave{x}",
            "\\breve{x}",
            "\\check{x}",
            "\\overline{x}",
            "\\underline{x}",
            "\\boxed{x+y}",
            "\\colorbox{red}{x}",
            "\\colorbox{#fA6}{x}",
            "\\fcolorbox{red}{blue}{x}",
            "\\cancel{x}",
            "\\bcancel{x}",
            "\\xcancel{x}",
            "\\sout{x}",
            "\\phantom{x+y}",
            "\\hphantom{x+y}",
            "\\vphantom{x+y}",
            "\\smash{x+y}",
            "\\smash{\\frac{x}{y}}"
        ])
    }
}
