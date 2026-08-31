package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexEnvironment, KatexDelimiter, KatexHtml, KatexMathMl]
class KatexDoubleVerticalDelimiterStructureTests {
    @TestCase
    func migratedKatexVmatrixShouldUseStretchyDoubleVerticalDelimiters() {
        // Source: test/katex-spec.ts / matrix environment build cases.
        let tex = "\\begin{Vmatrix}a&b\\\\c&d\\end{Vmatrix}"
        assertHtmlContains(tex, "class=\"katex-delim katex-delim-left mopen delimcenter\"><span class=\"delimsizing mult\">")
        assertHtmlContains(tex, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"0.556em\" height=\"2.4em\" viewBox=\"0 0 556 2400\">")
        assertHtmlContains(tex, "class=\"katex-delim katex-delim-right mclose delimcenter\"><span class=\"delimsizing mult\">")
        assertMathMlContains(tex, "<mrow><mo fence=\"true\">∥</mo><mtable>")
        assertMathMlContains(tex, "</mtable><mo fence=\"true\">∥</mo></mrow>")
    }

    @TestCase
    func migratedKatexVmatrixStarShouldUseStretchyDoubleVerticalDelimiters() {
        // Source: test/katex-spec.ts / matrix* optional alignment build cases.
        let tex = "\\begin{Vmatrix*}[r] a & -1 \\\\ -1 & d \\end{Vmatrix*}"
        assertHtmlContains(tex, "katex-env-wrap-Vmatrixstar")
        assertHtmlContains(tex, "class=\"katex-delim katex-delim-left mopen delimcenter\"><span class=\"delimsizing mult\">")
        assertMathMlContains(tex, "<mo fence=\"true\">∥</mo><mtable columnalign=\"right\">")
    }

    @TestCase
    func migratedKatexLeftRightVertCommandsShouldRenderAsDoubleVerticalUnicode() {
        // Source: test/katex-spec.ts / left/right delimiter command cases.
        let tex = "\\left\\lVert x \\right\\rVert"
        assertHtmlContains(tex, "class=\"katex-delim katex-delim-left mopen\">∥</span>")
        assertHtmlContains(tex, "class=\"katex-delim katex-delim-right mclose\">∥</span>")
        assertMathMlContains(tex, "<mo fence=\"true\">∥</mo><mrow><mi>x</mi></mrow><mo fence=\"true\">∥</mo>")
    }
}
