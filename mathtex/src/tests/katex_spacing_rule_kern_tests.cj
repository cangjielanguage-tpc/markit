package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexSpacing, KatexRule]
class KatexSpacingRuleKernTests {
    @TestCase
    func migratedKatexParserBatchRulesKernsRaiseAndLapShouldParse() {
        // Sources:
        // - describe("An lap parser")
        // - describe("A rule parser")
        // - describe("A kern parser")
        // - describe("A non-braced kern parser")
        // - describe("A raise parser")
        assertParsesAll([
            "\\rlap{\\,/}{=}",
            "\\mathrlap{\\,/}{=}",
            "{=}\\llap{/\\,}",
            "{=}\\mathllap{/\\,}",
            "\\sum_{\\clap{ABCDEFG}}",
            "\\sum_{\\mathclap{ABCDEFG}}",
            "\\rule{1em}{2em}",
            "\\rule[0.5em]{1em}{2em}",
            "\\rule{-1em}{2em}",
            "\\kern1em x",
            "x \\kern1em y",
            "x \\kern 1em y",
            "x \\mkern1mu y",
            "x \\hspace{1em} y",
            "x \\hskip1em y",
            "\\raisebox{1em}{x}",
            "\\vcenter{x}",
            "\\hskip1em\\relax^2"
        ])
    }
}
