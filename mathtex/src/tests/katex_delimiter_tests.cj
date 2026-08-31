package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexDelimiter]
class KatexDelimiterTests {
    @TestCase
    func migratedKatexParserBatchLeftRightDelimitersShouldParse() {
        // Sources:
        // - describe("A left/right parser") / not fail, empty delimiter, middle handling, nested middles
        // - describe("left/right builder")
        // - describe("A delimiter sizing parser")
        assertParsesAll([
            "\\left( x \\right)",
            "\\left[ x \\right]",
            "\\left\\{ x \\right\\}",
            "\\left\\langle x \\right\\rangle",
            "\\left. x \\right)",
            "\\left( x \\right.",
            "\\left( x \\middle| y \\right)",
            "\\left( x \\middle| y \\middle| z \\right)",
            "\\left( \\left[ x \\middle| y \\right] \\middle| z \\right)",
            "\\bigl |",
            "\\bigr |",
            "\\Bigl |",
            "\\Bigr |",
            "\\biggl |",
            "\\biggr |",
            "\\Biggl |",
            "\\Biggr \\langle",
            "\\bigm |",
            "\\Bigm |",
            "\\biggm |",
            "\\Biggm |"
        ])
    }
}
