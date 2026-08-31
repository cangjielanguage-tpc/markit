package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexBox, KatexSpacing]
class KatexBoxLayoutExtendedTests {
    @TestCase
    func migratedKatexLapParserAdditionalCasesShouldParse() {
        // Source: test/katex-spec.ts / describe("An lap parser")
        assertParsesAll([
            "\\mathrlap{\\frac{a}{b}}{=}",
            "{=}\\mathllap{\\frac{a}{b}}",
            "\\sum_{\\mathclap{\\frac{a}{b}}}",
            "\\mathrlap{\\,/}",
            "\\mathllap{/\\,}",
            "\\mathclap{ABCDEFG}"
        ])
    }

    @TestCase
    func migratedKatexRuleParserAdditionalCasesShouldRender() {
        // Source: test/katex-spec.ts / describe("A rule parser")
        assertRendersAll([
            "\\rule{1em}{2em}",
            "\\rule{1ex}{2em}",
            "\\rule{   01.24ex}{2.450   em   }",
            "\\rule{-1em}{- 0.2em}",
            "\\text{a\\rule{1em}{2em}b}"
        ])
    }

    @TestCase
    func migratedKatexKernParserAdditionalCasesShouldParse() {
        // Sources: describe("A kern parser"), describe("A non-braced kern parser")
        assertParsesAll([
            "\\kern{1em}",
            "\\kern{1ex}",
            "\\mkern{1mu}",
            "a\\kern{1em}b",
            "\\kern{-1em}",
            "\\kern{+1em}",
            "\\kern1em",
            "\\kern 1 ex",
            "\\mkern 1mu",
            "a\\mkern1mub",
            "a\\mkern-1mub",
            "a\\mkern-1mu b",
            "\\kern-1em",
            "\\kern+1em",
            "a\\mkern\t-\r1  \n mu\nb"
        ])
    }

    @TestCase
    func migratedKatexSmashParserAndBuilderShouldRender() {
        // Sources: describe("A smash parser"), describe("A smash builder")
        assertRendersAll([
            "\\smash{x}",
            "\\smash{x^2}",
            "\\smash{x}^2",
            "\\smash x",
            "\\smash[b]{x}",
            "\\smash[b]{x^2}",
            "\\smash[b]{x}^2",
            "\\smash[b] x",
            "\\smash[]{x}",
            "\\smash[]{x^2}",
            "\\smash[]{x}^2",
            "\\smash[] x"
        ])
    }
}
