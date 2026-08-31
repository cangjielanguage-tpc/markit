package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexFont, KatexStyle]
class KatexFontStyleTests {
    @TestCase
    func migratedKatexParserBatchFontsAndStylesShouldParse() {
        // Sources:
        // - describe("A style change parser") / should not fail
        // - describe("A font parser") / parse font commands, nested font commands, textcolor
        // - describe("An HTML font tree-builder") / render font commands
        assertParsesAll([
            "\\displaystyle x",
            "\\textstyle x",
            "\\scriptstyle x",
            "\\scriptscriptstyle x",
            "{\\displaystyle x} y",
            "\\text{hello $x + y$}",
            "\\mathrm{ABC123}",
            "\\mathbb{R}",
            "\\mathit{ABC}",
            "\\mathnormal{ABC}",
            "\\mathcal{ABC}",
            "\\mathfrak{ABC}",
            "\\mathsf{ABC123}",
            "\\mathtt{ABC123}",
            "\\mathbf{ABC123}",
            "\\boldsymbol{x+y}",
            "\\pmb{x+y}",
            "\\mathrm{\\mathbb{R}}",
            "\\mathsf{\\textcolor{#fA6}{ABC}}",
            "\\textbf{R }",
            "\\textit{R}",
            "\\textup{R}",
            "\\textmd{R}",
            "\\textsf{R}",
            "\\texttt{R}",
            "\\text{R\\textit{S}T}",
            "\\textsf{\\textit{R}G\\textbf{B}}",
            "\\emph{abc}",
            "\\text{\\emph{abc}}"
        ])
    }
}
