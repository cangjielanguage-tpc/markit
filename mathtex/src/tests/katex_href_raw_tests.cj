package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexHref]
class KatexHrefRawTests {
    @TestCase
    func migratedKatexParserBatchHrefUrlAndRawTextShouldParse() {
        // Sources:
        // - describe("operatorname support")
        // - describe("href and url commands") / parse input, empty/single-character URLs, balanced braces
        // - describe("A raw text parser")
        assertParsesAll([
            "\\operatorname{sech} x",
            "\\operatorname*{argmax}_x f(x)",
            "\\href{https://katex.org}{KaTeX}",
            "\\href{}{empty}",
            "\\href{x}{x}",
            "\\href{https://example.com/a b}{x}",
            "\\href{https://example.com/#$%&~_^}{x}",
            "\\href{https://example.com/{a}}{x}",
            "\\url{https://katex.org}",
            "\\url{x}",
            "\\url{}"
        ])
    }
}
