package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexDelimiter, KatexHtml, KatexMathMl]
class KatexDelimiterStructureTests {
    @TestCase
    func migratedKatexLeftRightShouldExposeDelimiterDom() {
        // Source: test/katex-spec.ts / describe("A leftright parser").
        // Source: KaTeX renderToString("\\left(\\frac{x}{y}\\right)") delimiter builder output.
        assertHtmlContains("\\left(\\frac{x}{y}\\right)", "class=\"katex-delimited minner\"")
        assertHtmlContains("\\left(\\frac{x}{y}\\right)", "class=\"katex-delim katex-delim-left mopen delimcenter\" style=\"top:0em;\"><span class=\"delimsizing size2\">(</span></span>")
        assertHtmlContains("\\left(\\frac{x}{y}\\right)", "class=\"katex-delim-body\"")
        assertHtmlContains("\\left(\\frac{x}{y}\\right)", "class=\"katex-delim katex-delim-right mclose delimcenter\" style=\"top:0em;\"><span class=\"delimsizing size2\">)</span></span>")
        assertMathMlContains("\\left(\\frac{x}{y}\\right)", "<mrow><mo fence=\"true\">(</mo><mrow><mfrac>")
    }

    @TestCase
    func migratedKatexInvisibleDelimiterShouldNotRenderVisibleFence() {
        // Source: test/katex-spec.ts / left/right delimiter cases with dot delimiters.
        assertHtmlContains("\\left. x \\right)", "class=\"katex-delim katex-delim-left mopen\"></span>")
        assertMathMlContains("\\left. x \\right)", "<mrow><mrow><mi>x</mi></mrow><mo fence=\"true\">)</mo></mrow>")
    }

    @TestCase
    func migratedKatexFloorDelimitersShouldParseInsideLeftRight() {
        // Source: KaTeX delimiter table for \lfloor and \rfloor.
        let tex = "\\left\\langle x,y \\right\\rangle + \\left\\lfloor n \\right\\rfloor"
        assertHtmlContains(tex, "class=\"katex-delim katex-delim-left mopen\">⌊</span>")
        assertHtmlContains(tex, "class=\"katex-delim katex-delim-right mclose\">⌋</span>")
        assertMathMlContains(tex, "<mo fence=\"true\">⌊</mo>")
        assertMathMlContains(tex, "<mo fence=\"true\">⌋</mo>")
    }

    @TestCase
    func migratedKatexMatrixLikeEnvironmentsShouldExposeDelimiterWrappers() {
        // Source: test/katex-spec.ts / matrix environment builders.
        assertHtmlContains("\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}", "class=\"katex-environment-wrap katex-env-wrap-pmatrix\"")
        assertHtmlContains("\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}", "class=\"katex-delim katex-delim-left mopen delimcenter\"><span class=\"delimsizing size3\">(</span></span>")
        assertHtmlContains("\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}", "class=\"katex-delim katex-delim-right mclose delimcenter\"><span class=\"delimsizing size3\">)</span></span>")
        assertHtmlContains("\\begin{bmatrix}a&b\\\\c&d\\end{bmatrix}", "class=\"katex-delim katex-delim-left mopen delimcenter\"><span class=\"delimsizing size3\">[</span></span>")
        assertHtmlContains("\\begin{bmatrix}a&b\\\\c&d\\end{bmatrix}", "class=\"katex-delim katex-delim-right mclose delimcenter\"><span class=\"delimsizing size3\">]</span></span>")
    }

    @TestCase
    func migratedKatexThreeRowBmatrixShouldUseStretchySquareBrackets() {
        // Source: KaTeX v0.16.47 src/environments/array.ts + src/delimiter.ts.
        let tex = "\\begin{bmatrix}1&0&0\\\\0&\\cos\\theta&-\\sin\\theta\\\\0&\\sin\\theta&\\cos\\theta\\end{bmatrix}"
        assertHtmlContains(tex, "class=\"katex-delim katex-delim-left mopen delimcenter\"><span class=\"delimsizing mult\">")
        assertHtmlContains(tex, "width=\"0.667em\" height=\"3.6em\" viewBox=\"0 0 667 3600\"")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:2.05em;\"")
        assertHtmlContains(tex, "style=\"top:-4.21em;\"")
        assertHtmlContains(tex, "style=\"top:-3.01em;\"")
        assertHtmlContains(tex, "style=\"top:-1.81em;\"")
    }

    @TestCase
    func migratedKatexCasesShouldExposeOneSidedDelimiterWrapper() {
        // Source: test/katex-spec.ts / cases and rcases environment builders.
        assertHtmlContains("\\begin{cases}a&b\\\\c&d\\end{cases}", "class=\"katex-environment-wrap katex-env-wrap-cases\"")
        assertHtmlContains("\\begin{cases}a&b\\\\c&d\\end{cases}", "class=\"katex-delim katex-delim-left mopen delimcenter\"><span class=\"delimsizing size4\">{</span></span>")
        assertHtmlContains("\\begin{rcases}a&b\\\\c&d\\end{rcases}", "class=\"katex-environment-wrap katex-env-wrap-rcases\"")
        assertHtmlContains("\\begin{rcases}a&b\\\\c&d\\end{rcases}", "class=\"katex-delim katex-delim-right mclose delimcenter\"><span class=\"delimsizing size4\">}</span></span>")
    }
}
