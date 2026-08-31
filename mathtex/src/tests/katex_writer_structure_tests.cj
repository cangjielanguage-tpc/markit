package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexHtml, KatexMathMl]
class KatexWriterStructureTests {
    @TestCase
    func migratedKatexRootShouldExposeHtmlAndMathMlSpans() {
        // Source: KaTeX renderToString output contract; mathtex intentionally adds the mathtex root class.
        assertHtmlContains("x^2", "class=\"katex mathtex\"")
        assertHtmlContains("x^2", "data-tex=\"x^2\"")
        assertHtmlContains("x^2", "class=\"katex-mathml\"")
        assertHtmlContains("x^2", "class=\"katex-html\"")
        assertHtmlContains("x^2", "aria-hidden=\"true\"")
    }

    @TestCase
    func migratedKatexDisplayModeShouldExposeDisplayClassAndMathMlDisplay() {
        // Source: KaTeX displayMode markup contract.
        assertHtmlContains("\\frac{a}{b}", "class=\"katex mathtex katex-display\"", displayMode: true)
        assertMathMlContains("\\frac{a}{b}", "<math xmlns=\"http://www.w3.org/1998/Math/MathML\" display=\"block\">", displayMode: true)
    }

    @TestCase
    func migratedKatexMathMlShouldExposeSourceTexAnnotationForCopy() {
        // Source: KaTeX renderToString MathML semantics annotation contract.
        assertMathMlContains("\\frac{a}{b} + \\sqrt{x}", "<semantics><mrow>")
        assertMathMlContains("\\frac{a}{b} + \\sqrt{x}", "<annotation encoding=\"application/x-tex\">\\frac{a}{b} + \\sqrt{x}</annotation>")
        assertHtmlContains("\\frac{a}{b} + \\sqrt{x}", "<annotation encoding=\"application/x-tex\">\\frac{a}{b} + \\sqrt{x}</annotation>")
    }

    @TestCase
    func migratedKatexMathMlShouldUseCoreMathMlElements() {
        // Source: test/mathml-spec.ts MathML builder cases.
        assertMathMlContains("\\frac{a}{b}", "<mfrac><mrow><mi>a</mi></mrow><mrow><mi>b</mi></mrow></mfrac>")
        assertMathMlContains("\\sqrt{x}", "<msqrt><mrow><mi>x</mi></mrow></msqrt>")
        assertMathMlContains("x_i^2", "<msubsup><mi>x</mi><mi>i</mi><mn>2</mn></msubsup>")
        assertMathMlContains("\\text{abc}", "<mtext>abc</mtext>")
    }

    @TestCase
    func migratedKatexHtmlShouldExposeAtomClasses() {
        // Source: KaTeX buildHTML atom class contract.
        assertHtmlContains("x+y=2", "class=\"katex-symbol mord mathnormal\">x</span>")
        assertHtmlContains("x+y=2", "class=\"mspace\" style=\"margin-right:0.2222em;\"></span><span class=\"katex-symbol mbin\">+</span><span class=\"mspace\" style=\"margin-right:0.2222em;\"")
        assertHtmlContains("x+y=2", "class=\"katex-symbol mbin\">+</span>")
        assertHtmlContains("x+y=2", "class=\"mspace\" style=\"margin-right:0.2778em;\"></span><span class=\"katex-symbol mrel\">=</span><span class=\"mspace\" style=\"margin-right:0.2778em;\"")
        assertHtmlContains("x+y=2", "class=\"katex-symbol mrel\">=</span>")
        assertHtmlContains("\\sin(x)", "class=\"katex-symbol mop\">sin</span>")
        assertHtmlContains("(x, y)", "class=\"katex-symbol mopen\">(</span>")
        assertHtmlContains("(x, y)", "class=\"katex-symbol mpunct\">,</span>")
        assertHtmlContains("(x, y)", "class=\"katex-symbol mclose\">)</span>")
    }

    @TestCase
    func migratedKatexGreekRelationShouldUseMathnormalAndRelationSpacing() {
        // Source: KaTeX renderToString("\\alpha + \\beta \\rightarrow \\gamma") HTML and MathML builders.
        let tex = "\\alpha + \\beta \\rightarrow \\gamma"
        assertHtmlContains(tex, "class=\"katex-symbol mord mathnormal\" style=\"margin-right:0.0037em;\">α</span>")
        assertHtmlContains(tex, "class=\"katex-symbol mord mathnormal\" style=\"margin-right:0.0528em;\">β</span>")
        assertHtmlContains(tex, "class=\"mspace\" style=\"margin-right:0.2778em;\"></span><span class=\"katex-symbol mrel\">→</span><span class=\"mspace\" style=\"margin-right:0.2778em;\"></span>")
        assertHtmlContains(tex, "class=\"katex-symbol mord mathnormal\" style=\"margin-right:0.0556em;\">γ</span>")
        assertMathMlContains(tex, "<mi>β</mi><mo>→</mo><mi>γ</mi>")
    }

    @TestCase
    func migratedKatexMacroArrowsShouldUseLongRelationGlyphs() {
        // Source: KaTeX macro expansion for \iff, \implies, and \impliedby.
        let tex = "p \\implies q \\iff r \\impliedby s"
        assertHtmlContains(tex, "class=\"katex-symbol mrel\">⟹</span>")
        assertHtmlContains(tex, "class=\"katex-symbol mrel\">⟺</span>")
        assertHtmlContains(tex, "class=\"katex-symbol mrel\">⟸</span>")
        assertHtmlContains(tex, "class=\"mspace\" style=\"margin-right:0.2778em;\"></span><span class=\"mspace\" style=\"margin-right:0.2778em;\"></span><span class=\"katex-symbol mrel\">⟹</span>")
        assertMathMlContains(tex, "<mo>⟹</mo>")
        assertMathMlContains(tex, "<mo>⟺</mo>")
        assertMathMlContains(tex, "<mo>⟸</mo>")
    }

    @TestCase
    func migratedKatexHtmlShouldExposeFractionSqrtAndScripts() {
        // Source: KaTeX HTML builder frac/sqrt/supsub coverage, matched to mathtex's stable DOM skeleton.
        assertHtmlContains("\\frac{a}{b}", "katex-frac")
        assertHtmlContains("\\frac{a}{b}", "class=\"sizing reset-size6 size3 mtight katex-frac-num\"")
        assertHtmlContains("\\frac{a}{b}", "class=\"sizing reset-size6 size3 mtight katex-frac-den\"")
        assertHtmlContains("\\sqrt{x}", "katex-sqrt")
        assertHtmlContains("\\sqrt{x}", "<svg xmlns=\"http://www.w3.org/2000/svg\"")
        assertHtmlContains("x_i^2", "katex-scripts")
        assertHtmlContains("x_i^2", "katex-sub")
        assertHtmlContains("x_i^2", "katex-sup")
    }
}
