package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexComment]
class KatexCommentParserTests {
    @TestCase
    func migratedKatexCommentAtEndOfLineShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["a^2 + b^2 = c^2 % Pythagoras' Theorem\n"])
    }

    @TestCase
    func migratedKatexCommentAtStartOfLineShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["% comment\n"])
    }

    @TestCase
    func migratedKatexMultipleCommentLinesShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["% comment 1\n% comment 2\n"])
    }

    @TestCase
    func migratedKatexCommentBetweenSubscriptAndSuperscriptShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["x_3 %comment\n^2"])
    }

    @TestCase
    func migratedKatexCommentBeforeSuperscriptGroupShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["x^ %comment\n{2}"])
    }

    @TestCase
    func migratedKatexCommentBeforeSuperscriptFractionShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["x^ %comment\n\\frac{1}{2}"])
    }

    @TestCase
    func migratedKatexCommentBeforeExpressionShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["%comment\n{2}"])
    }

    @TestCase
    func migratedKatexCommentsBeforeHlineShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["\\begin{matrix}a&b\\\\ %hline\n\\hline %hline\n\\hline c&d\\end{matrix}"])
    }

    @TestCase
    func migratedKatexCommentAfterCommandSequenceShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["\\def\\foo{1\n2}\nx %\\foo\n"])
    }

    @TestCase
    func migratedKatexTextCommentShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["\\text{hello% comment 1\nworld}"])
    }

    @TestCase
    func migratedKatexOutputCommentShouldParse() {
        // Source: test/katex-spec.ts / describe("A comment parser")
        assertParsesAll(["5 % comment\n"])
    }
}
