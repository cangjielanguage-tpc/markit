package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexEnvironment]
class KatexEnvironmentExtendedTests {
    @TestCase
    func migratedKatexBeginEndParserAdditionalCasesShouldParse() {
        // Source: test/katex-spec.ts / describe("A begin/end parser")
        assertParsesAll([
            "\\begin{aligned}\\end{aligned}",
            "\\begin{matrix}\\end{matrix}",
            "\\begin{matrix}\\hline a&b\\\\ \\hline c&d\\end{matrix}",
            "\\begin{matrix}\\hline a&b\\cr \\hline c&d\\end{matrix}",
            "\\begin{matrix}\\hdashline a&b\\\\ \\hdashline c&d\\end{matrix}",
            "\\begin{matrix}0&1\\over2&3\\\\4&5&6\\end{matrix}",
            "\\begin{array}{rl}\\begin{pmatrix}1&2\\\\3&4\\end{pmatrix}&0\\\\0&\\begin{pmatrix}1&2\\\\3&4\\end{pmatrix}\\end{array}",
            "\\begin{matrix}a&b\\cr c&d\\end{matrix}",
            "\\begin{matrix}a&b\\\\c&d\\end{matrix}",
            "\\begin{matrix}a&b\\cr[c]&d\\end{matrix}",
            "\\begin{matrix}a&b\\\\ [c]&d\\end{matrix}",
            "a\\\\ [b]",
            "\\def\\arraystretch{1.5}\\begin{matrix}a&b\\\\c&d\\end{matrix}"
        ])
    }

    @TestCase
    func migratedKatexMatrixStarEnvironmentsShouldRender() {
        // Source: test/katex-spec.ts / matrix* optional alignment build cases.
        assertRendersAll([
            "\\begin{matrix*}[r] a & -1 \\\\ -1 & d \\end{matrix*}",
            "\\begin{pmatrix*}[r] a & -1 \\\\ -1 & d \\end{pmatrix*}",
            "\\begin{bmatrix*}[r] a & -1 \\\\ -1 & d \\end{bmatrix*}",
            "\\begin{Bmatrix*}[r] a & -1 \\\\ -1 & d \\end{Bmatrix*}",
            "\\begin{vmatrix*}[r] a & -1 \\\\ -1 & d \\end{vmatrix*}",
            "\\begin{Vmatrix*}[r] a & -1 \\\\ -1 & d \\end{Vmatrix*}",
            "\\begin{matrix*} a & -1 \\\\ -1 & d \\end{matrix*}"
        ])
    }

    @TestCase
    func migratedKatexArrayAndSubarrayEnvironmentCasesShouldParse() {
        // Sources: describe("An array environment"), describe("A subarray environment")
        assertParsesAll([
            "\\begin{array}r1\\\\20\\end{array}",
            "\\begin{array}{|l||c:r::}\\end{array}",
            "\\begin{subarray}{c}a \\\\ b\\end{subarray}"
        ])
    }

    @TestCase
    func migratedKatexDisplayAmsEnvironmentsShouldRender() {
        // Source: test/katex-spec.ts / describe("AMS environments") display-mode build cases.
        assertRendersAll([
            "\\begin{gather}a+b\\\\c+d\\end{gather}",
            "\\begin{gather*}a+b\\\\c+d\\end{gather*}",
            "\\begin{align}a&=b+c\\\\d+e&=f\\end{align}",
            "\\begin{align*}a&=b+c\\\\d+e&=f\\end{align*}",
            "\\begin{alignat}{2}10&x+ &3&y = 2\\\\3&x+&13&y = 4\\end{alignat}",
            "\\begin{alignat*}{2}10&x+ &3&y = 2\\\\3&x+&13&y = 4\\end{alignat*}",
            "\\begin{equation}a=b+c\\end{equation}",
            "\\begin{equation}\\begin{split}a &=b+c\\\\&=e+f\\end{split}\\end{equation}",
            "\\begin{split}a &=b+c\\\\&=e+f\\end{split}",
            "\\begin{CD}A @<a<< B @>>b> C @>>> D\\\\@. @| @AcAA @VVdV \\\\@. E @= F @>>> G\\end{CD}"
        ])
    }

    @TestCase
    func migratedKatexSubstackAndSmallCasesShouldRender() {
        // Sources: substack, smallmatrix, cases, rcases, aligned environment.
        assertRendersAll([
            "\\sum_{\\substack{ 0<i<m \\\\ 0<j<n }}  P(i,j)",
            "\\sum_{\\substack{ 0<i<\\varPi \\\\ 0<j<\\pi }}  P(i,j)",
            "\\sum_{\\substack{}}  P(i,j)",
            "\\begin{smallmatrix} a & b \\\\ c & d \\end{smallmatrix}",
            "f(a,b)=\\begin{cases}a+1&\\text{if }b\\text{ is odd}\\\\a&\\text{if }b=0\\\\a-1&\\text{otherwise}\\end{cases}",
            "\\begin{rcases} a &\\text{if } b \\\\ c &\\text{if } d \\end{rcases}⇒…",
            "\\begin{aligned}a&=b&c&=d\\\\e&=f\\end{aligned}",
            "\\begin{aligned}[a]&[b]\\\\ [c]&[d]\\end{aligned}"
        ])
    }
}
