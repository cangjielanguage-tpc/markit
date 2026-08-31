package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexUnicode]
class KatexUnicodeTests {
    @TestCase
    func migratedUnicodeSpecBatchShouldParse() {
        // Sources: test/unicode-spec.ts parse/build coverage for text, Greek, CJK, Cyrillic, Devanagari, Georgian, Armenian, emoji.
        assertParsesAll([
            "\\text{ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ}",
            "\\text{·}",
            "·",
            "\\text{À like accents}",
            "ÀÁÂÃÄÅ",
            "\\text{ΑΒΓΔ}",
            "\\alpha\\beta\\gamma\\delta",
            "\\Gamma\\Delta\\Theta\\Lambda",
            "\\text{Привет}",
            "Привет",
            "\\text{中文数学}",
            "中文数学",
            "\\text{देवनागरी}",
            "देवनागरी",
            "\\text{ქართული}",
            "ქართული",
            "\\text{Հայերեն}",
            "Հայերեն",
            "\\text{āăąćĉċčďđē}",
            "āăąćĉċčďđē",
            "\\text{😀}",
            "😀 + 🚀"
        ])
    }
}
