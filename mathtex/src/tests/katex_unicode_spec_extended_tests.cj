package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexUnicode]
class KatexUnicodeSpecExtendedTests {
    @TestCase
    func migratedUnicodeSpecLatinOneInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{ÀÁÂÃÄÅÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåèéêëìíîïñòóôõöùúûüýÿÆÇÐØÞßæçðøþ}"])
    }

    @TestCase
    func migratedUnicodeSpecMiddleDotInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{eV·nm}"])
    }

    @TestCase
    func migratedUnicodeSpecMiddleDotInMathShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["x·y"])
    }

    @TestCase
    func migratedUnicodeSpecLatinOneOutsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["ÀÁÂÃÄÅÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåèéêëìíîïñòóôõöùúûüýÿÇÐÞçðþ"])
    }

    @TestCase
    func migratedUnicodeSpecLowerGreekShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["αβγδεϵζηθϑικλμνξοπϖρϱςστυφϕχψω"])
    }

    @TestCase
    func migratedUnicodeSpecUpperGreekShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["ΓΔΘΛΞΠΣΥΦΨΩ"])
    }

    @TestCase
    func migratedUnicodeSpecCyrillicInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{БГДЖЗЙЛФЦШЫЮЯ}"])
    }

    @TestCase
    func migratedUnicodeSpecCyrillicOutsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["БГДЖЗЙЛФЦШЫЮЯ"])
    }

    @TestCase
    func migratedUnicodeSpecCjkJapaneseInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{私はバナナです}"])
    }

    @TestCase
    func migratedUnicodeSpecCjkKoreanInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{여보세요}"])
    }

    @TestCase
    func migratedUnicodeSpecCjkJapaneseOutsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["私はバナナです"])
    }

    @TestCase
    func migratedUnicodeSpecCjkKoreanOutsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["여보세요"])
    }

    @TestCase
    func migratedUnicodeSpecDevanagariInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{नमस्ते}"])
    }

    @TestCase
    func migratedUnicodeSpecDevanagariOutsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["नमस्ते"])
    }

    @TestCase
    func migratedUnicodeSpecGeorgianInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{გამარჯობა}"])
    }

    @TestCase
    func migratedUnicodeSpecGeorgianOutsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["გამარჯობა"])
    }

    @TestCase
    func migratedUnicodeSpecArmenianOutsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["ԱԲԳաբգ"])
    }

    @TestCase
    func migratedUnicodeSpecArmenianInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{ԱԲԳաբգ}"])
    }

    @TestCase
    func migratedUnicodeSpecExtendedLatinInsideTextShouldRender() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertRendersAll(["\\text{ěščřžůřťďňőİı}"])
    }

    @TestCase
    func migratedUnicodeSpecEmojiOutsideStrictShouldParse() {
        // Source: test/unicode-spec.ts / describe("unicode")
        assertParsesAll(["✌", "\\text{✌}"])
    }
}
