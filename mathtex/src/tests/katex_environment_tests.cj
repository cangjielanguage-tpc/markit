package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexEnvironment]
class KatexEnvironmentTests {
    @TestCase
    func migratedKatexParserBatchEnvironmentsShouldParse() {
        // Sources:
        // - describe("A begin/end parser") / simple, arguments, empty, hlines, nesting, row terminators
        // - describe("An array environment")
        // - describe("A subarray environment")
        // - describe("A smallmatrix environment")
        // - describe("A cases environment")
        // - describe("An aligned environment")
        assertParsesAll([
            "\\begin{matrix}a&b\\\\c&d\\end{matrix}",
            "\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}",
            "\\begin{bmatrix}a&b\\\\c&d\\end{bmatrix}",
            "\\begin{Bmatrix}a&b\\\\c&d\\end{Bmatrix}",
            "\\begin{vmatrix}a&b\\\\c&d\\end{vmatrix}",
            "\\begin{Vmatrix}a&b\\\\c&d\\end{Vmatrix}",
            "\\begin{matrix}\\end{matrix}",
            "\\begin{matrix}\\hline a&b\\\\c&d\\end{matrix}",
            "\\begin{matrix}a&b\\cr c&d\\end{matrix}",
            "\\begin{matrix}\na&b\\\\\nc&d\n\\end{matrix}",
            "\\begin{array}{c}a\\\\b\\end{array}",
            "\\begin{array}{cc}a&b\\\\c&d\\end{array}",
            "\\begin{array}{c|c}a&b\\\\c&d\\end{array}",
            "\\begin{subarray}{c}a\\\\b\\end{subarray}",
            "\\begin{smallmatrix}a&b\\\\c&d\\end{smallmatrix}",
            "\\begin{cases}x^2 & x \\geq 0\\\\ -x^2 & x<0\\end{cases}",
            "\\begin{rcases}x^2 & x \\geq 0\\\\ -x^2 & x<0\\end{rcases}",
            "\\begin{aligned}a&=b+c\\\\d&=e+f\\end{aligned}",
            "\\begin{alignedat}{2}a&=b&c&=d\\end{alignedat}",
            "\\begin{gathered}a=b\\\\c=d\\end{gathered}",
            "\\begin{matrix}\\begin{matrix}a\\end{matrix}\\end{matrix}",
            "\\begin{equation}x=y\\end{equation}",
            "\\begin{split}x&=y\\\\z&=w\\end{split}"
        ])
    }
}
