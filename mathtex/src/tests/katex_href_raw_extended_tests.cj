package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexHref, KatexRawText]
class KatexHrefRawExtendedTests {
    @TestCase
    func migratedKatexHrefAndUrlAdditionalCasesShouldRender() {
        // Source: test/katex-spec.ts / describe("href and url commands")
        assertRendersAll([
            "\\href{http://example.com/}{\\sin}",
            "\\url{http://example.com/}",
            "\\href{}{example here}",
            "\\url{}",
            "\\href{http://example.org/~bar/#top?foo=$foo&bar=ba^r_boo%20baz}{\\alpha}",
            "\\url{http://example.org/~bar/#top?foo=$foo&bar=ba^r_boo%20baz}",
            "\\href{http://example.org/{{}t{oo}}}{\\alpha}",
            "\\url{http://example.org/{{}t{oo}}}",
            "\\url{http://example.com/}"
        ])
    }

    @TestCase
    func migratedKatexRawTextParserShouldParseIncludeGraphics() {
        // Source: test/katex-spec.ts / describe("A raw text parser")
        assertParsesAll([
            "\\includegraphics{https://cdn.kastatic.org/images/apple-touch-icon-57x57-precomposed.new.png}",
            "\\includegraphics[height=1em]{https://cdn.kastatic.org/images/apple-touch-icon-57x57-precomposed.new.png}"
        ])
    }
}
