package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexEnvironment]
class KatexEnvironmentMoreMigrationTests {
    @TestCase
    func migratedKatexArraySingleAlignmentShouldParse() {
        // Source: test/katex-spec.ts / describe("An array environment")
        assertParsesAll(["\\begin{array}r1\\\\20\\end{array}"])
    }

    @TestCase
    func migratedKatexArrayVerticalSeparatorsShouldParse() {
        // Source: test/katex-spec.ts / describe("An array environment")
        assertParsesAll(["\\begin{array}{|l||c:r::}\\end{array}"])
    }

    @TestCase
    func migratedKatexSubarraySingleAlignmentShouldParse() {
        // Source: test/katex-spec.ts / describe("A subarray environment")
        assertParsesAll(["\\begin{subarray}{c}a \\\\ b\\end{subarray}"])
    }

    @TestCase
    func migratedKatexSubstackShouldRender() {
        // Source: test/katex-spec.ts / describe("A substack function")
        assertRendersAll(["\\sum_{\\substack{ 0<i<m \\\\ 0<j<n }}  P(i,j)"])
    }

    @TestCase
    func migratedKatexSubstackWithSpacesShouldRender() {
        // Source: test/katex-spec.ts / describe("A substack function")
        assertRendersAll(["\\sum_{\\substack{ 0<i<m \\\\ 0<j<n }}  P(i,j)"])
    }

    @TestCase
    func migratedKatexSubstackWithMacrosShouldRender() {
        // Source: test/katex-spec.ts / describe("A substack function")
        assertRendersAll(["\\sum_{\\substack{ 0<i<\\varPi \\\\ 0<j<\\pi }}  P(i,j)"])
    }

    @TestCase
    func migratedKatexSubstackEmptyShouldRender() {
        // Source: test/katex-spec.ts / describe("A substack function")
        assertRendersAll(["\\sum_{\\substack{}}  P(i,j)"])
    }

    @TestCase
    func migratedKatexSmallmatrixShouldRender() {
        // Source: test/katex-spec.ts / describe("A smallmatrix environment")
        assertRendersAll(["\\begin{smallmatrix} a & b \\\\ c & d \\end{smallmatrix}"])
    }

    @TestCase
    func migratedKatexCasesShouldParse() {
        // Source: test/katex-spec.ts / describe("A cases environment")
        assertParsesAll(["f(a,b)=\\begin{cases}a+1&\\text{if }b\\text{ is odd}\\\\a&\\text{if }b=0\\\\a-1&\\text{otherwise}\\end{cases}"])
    }

    @TestCase
    func migratedKatexRcasesShouldRender() {
        // Source: test/katex-spec.ts / describe("An rcases environment")
        assertRendersAll(["\\begin{rcases} a &\\text{if } b \\\\ c &\\text{if } d \\end{rcases}⇒…"])
    }

    @TestCase
    func migratedKatexAlignedInputShouldParse() {
        // Source: test/katex-spec.ts / describe("An aligned environment")
        assertParsesAll(["\\begin{aligned}a&=b&c&=d\\\\e&=f\\end{aligned}"])
    }

    @TestCase
    func migratedKatexAlignedCellsInBracketsShouldParse() {
        // Source: test/katex-spec.ts / describe("An aligned environment")
        assertParsesAll(["\\begin{aligned}[a]&[b]\\\\ [c]&[d]\\end{aligned}"])
    }

    @TestCase
    func migratedKatexAlignedFinalEmptyFirstCellShouldParse() {
        // Source: test/katex-spec.ts / describe("An aligned environment")
        assertParsesAll(["\\begin{aligned}a&b\\\\&c\\end{aligned}"])
    }

    @TestCase
    func migratedKatexGatheredShouldRender() {
        // Source: test/katex-spec.ts / describe("AMS environments")
        assertRendersAll(["\\begin{gathered}a=b\\\\c=d\\end{gathered}"])
    }

    @TestCase
    func migratedKatexAlignedatShouldRender() {
        // Source: test/katex-spec.ts / describe("AMS environments")
        assertRendersAll(["\\begin{alignedat}{2}a&=b&c&=d\\\\e&=f&g&=h\\end{alignedat}"])
    }

    @TestCase
    func migratedKatexEquationShouldRender() {
        // Source: test/katex-spec.ts / describe("AMS environments")
        assertRendersAll(["\\begin{equation}a=b\\end{equation}"])
    }

    @TestCase
    func migratedKatexSplitShouldRender() {
        // Source: test/katex-spec.ts / describe("AMS environments")
        assertRendersAll(["\\begin{split}a&=b\\\\c&=d\\end{split}"])
    }

    @TestCase
    func migratedKatexCdEnvironmentShouldRender() {
        // Source: test/katex-spec.ts / describe("The CD environment")
        assertRendersAll(["\\begin{CD}A @<a<< B @>>b> C @>>> D\\\\@. @| @AcAA @VVdV \\\\@. E @= F @>>> G\\end{CD}"])
    }
}
