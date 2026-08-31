package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexEnvironment, KatexHtml, KatexMathMl]
class KatexEnvironmentStructureTests {
    @TestCase
    func migratedKatexMatrixEnvironmentShouldHaveRowsAndCells() {
        // Source: test/katex-spec.ts / describe("A begin/end parser") matrix row and cell handling.
        assertFirstNodeEnvironmentShape("\\begin{matrix}a&b\\\\c&d\\end{matrix}", "matrix", 2, 2)
        assertMathMlContains("\\begin{matrix}a&b\\\\c&d\\end{matrix}", "<mtable><mtr><mtd><mrow><mi>a</mi></mrow></mtd><mtd><mrow><mi>b</mi></mrow></mtd></mtr>")
        assertHtmlContains("\\begin{matrix}a&b\\\\c&d\\end{matrix}", "class=\"mtable katex-environment katex-env-matrix\"")
        assertHtmlContains("\\begin{matrix}a&b\\\\c&d\\end{matrix}", "class=\"col-align-c\"")
        assertHtmlContains("\\begin{matrix}a&b\\\\c&d\\end{matrix}", "class=\"arraycolsep\" style=\"width:0.5em;\"")
        assertHtmlContains("\\begin{matrix}a&b\\\\c&d\\end{matrix}", "class=\"vlist\" style=\"height:1.45em;\"")
    }

    @TestCase
    func migratedKatexCasesEnvironmentShouldHaveRowsAndCells() {
        // Source: test/katex-spec.ts / describe("A cases environment").
        assertFirstNodeEnvironmentShape("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "cases", 2, 2)
        assertMathMlContains("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "<mtable><mtr><mtd><mrow><mi>a</mi></mrow></mtd><mtd><mrow><mtext>if </mtext><mi>b</mi></mrow></mtd></mtr>")
        assertHtmlContains("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "class=\"katex-delim katex-delim-left mopen delimcenter\"><span class=\"delimsizing size4\">{</span>")
        assertHtmlContains("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "class=\"mtable katex-environment katex-env-cases\"")
        assertHtmlContains("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "class=\"col-align-l\"")
        assertHtmlContains("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "class=\"vlist\" style=\"height:1.69em;\"")
        assertHtmlContains("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "style=\"top:-3.69em;\"")
        assertHtmlContains("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "style=\"top:-2.25em;\"")
        assertHtmlContains("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "class=\"pstrut\" style=\"height:3.008em;\"")
    }

    @TestCase
    func migratedKatexAlignedEnvironmentShouldHaveRowsAndCells() {
        // Source: test/katex-spec.ts / describe("An aligned environment").
        assertFirstNodeEnvironmentShape("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "aligned", 2, 2)
        assertMathMlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "<mtable><mtr><mtd><mrow><mi>a</mi></mrow></mtd><mtd><mrow><mo>=</mo><mi>b</mi></mrow></mtd></mtr>")
        assertHtmlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "class=\"mtable katex-environment katex-env-aligned\"")
        assertHtmlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "class=\"col-align-r\"")
        assertHtmlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "class=\"col-align-l\"")
        assertHtmlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "class=\"vlist\" style=\"height:1.6em;\"")
        assertHtmlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "style=\"top:-3.76em;\"")
        assertHtmlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "style=\"top:-2.26em;\"")
        assertHtmlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "class=\"vlist\" style=\"height:1.1em;\"")
        assertHtmlContains("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "class=\"mord\"></span><span class=\"mspace\" style=\"margin-right:0.2778em;\"></span><span class=\"katex-symbol mrel\">=</span>")
    }

    @TestCase
    func migratedKatexMatrixStarShouldSkipOptionalAlignmentPreamble() {
        // Source: test/katex-spec.ts / matrix* optional alignment build cases.
        assertFirstNodeEnvironmentShape("\\begin{matrix*}[r] a & -1 \\\\ -1 & d \\end{matrix*}", "matrix*", 2, 2)
        assertFirstNodeEnvironmentPreamble("\\begin{matrix*}[r] a & -1 \\\\ -1 & d \\end{matrix*}", ["r"], [])
        assertHtmlContains("\\begin{matrix*}[r] a & -1 \\\\ -1 & d \\end{matrix*}", "class=\"mtable katex-environment katex-env-matrixstar\"")
        assertHtmlContains("\\begin{matrix*}[r] a & -1 \\\\ -1 & d \\end{matrix*}", "class=\"col-align-r\"")
    }

    @TestCase
    func migratedKatexSmallmatrixAndSubarrayShouldUseCompactEnvironmentMetrics() {
        // Source: KaTeX array-like builders for smallmatrix/subarray compact sizing.
        assertHtmlContains("\\begin{smallmatrix}a&b\\\\c&d\\end{smallmatrix}", "class=\"mtable katex-environment katex-env-smallmatrix\"")
        assertHtmlContains("\\begin{smallmatrix}a&b\\\\c&d\\end{smallmatrix}", "class=\"arraycolsep\" style=\"width:0.2778em;\"")
        assertHtmlContains("\\begin{smallmatrix}a&b\\\\c&d\\end{smallmatrix}", "class=\"vlist\" style=\"height:0.98em;\"")
        assertHtmlContains("\\begin{subarray}{c}i=1\\\\j=2\\end{subarray}", "class=\"mtable katex-environment katex-env-subarray\"")
        assertHtmlContains("\\begin{subarray}{c}i=1\\\\j=2\\end{subarray}", "class=\"pstrut\" style=\"height:2.4em;\"")
        assertMathMlContains("\\begin{smallmatrix}a&b\\\\c&d\\end{smallmatrix}", "<mtable>")
    }

    @TestCase
    func migratedKatexSmallmatrixShouldUseTighterColumnSeparation() {
        // Source: KaTeX smallmatrix compact environment layout.
        assertHtmlContains("\\begin{smallmatrix}a&b\\\\c&d\\end{smallmatrix}", "class=\"arraycolsep\" style=\"width:0.2778em;\"")
        assertHtmlContains("\\begin{smallmatrix}a&b\\\\c&d\\end{smallmatrix}", "class=\"vlist\" style=\"height:0.98em;\"")
    }

    @TestCase
    func migratedKatexSubarrayShouldStripAlignmentPreambleAndUseCompactPstrut() {
        // Source: KaTeX subarray parser strips the alignment preamble before row parsing.
        assertFirstNodeEnvironmentShape("\\begin{subarray}{c}i=1\\\\j=2\\end{subarray}", "subarray", 2, 1)
        assertFirstNodeEnvironmentPreamble("\\begin{subarray}{c}i=1\\\\j=2\\end{subarray}", ["c"], [])
        assertHtmlContains("\\begin{subarray}{c}i=1\\\\j=2\\end{subarray}", "class=\"pstrut\" style=\"height:2.4em;\"")
    }

    @TestCase
    func migratedKatexArrayPreambleShouldKeepAlignmentAndVerticalSeparators() {
        // Source: test/katex-spec.ts / describe("An array environment") preamble cases.
        let tex = "\\begin{array}{|l||c:r::}a&b&c\\\\d&e&f\\end{array}"
        assertFirstNodeEnvironmentShape(tex, "array", 2, 3)
        assertFirstNodeEnvironmentPreamble(tex, ["l", "c", "r"], [1, 2, 1, 2])
        assertHtmlContains(tex, "class=\"col-align-l\"")
        assertHtmlContains(tex, "class=\"col-align-c\"")
        assertHtmlContains(tex, "class=\"col-align-r\"")
        assertHtmlContains(tex, "class=\"vertical-separator\" style=\"height:1.45em;border-right-width:0.04em;\"")
        assertMathMlContains(tex, "<mtable columnalign=\"left center right\">")
    }

    @TestCase
    func migratedKatexMultirowCasesShouldScaleVlistHeight() {
        // Source: KaTeX cases-like environments scale vlist height with additional rows.
        assertHtmlContains("\\begin{cases}a&b\\\\c&d\\\\e&f\\end{cases}", "class=\"vlist\" style=\"height:3.13em;\"")
    }
}
