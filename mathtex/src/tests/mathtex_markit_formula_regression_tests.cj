package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[MathTex, MathTexMarkit, MathTexTypst]
class MathtexMarkitFormulaRegressionTests {
    @TestCase
    func markitInlineFormulaTypstShouldCoverCommonMarkdownMath() {
        assertTypstEquals("E = mc^2", "$E = m c^2$")
        assertTypstEquals("\\frac{1}{n}\\sum_{i=1}^n x_i", "$frac(1, n) sum_(i = 1)^n x_i$")
        assertTypstEquals("\\sqrt{x^2 + y^2}", "$sqrt(x^2 + y^2)$")
        assertTypstEquals("p \\implies q", "$p => q$")
    }

    @TestCase
    func markitBlockFormulaTypstShouldUseTypstMathBlock() {
        assertTypstEquals("\\int_0^1 x dx", "$\nintegral_0^1 x d x\n$", displayMode: true)
        assertTypstEquals("\\lim_{x \\to \\infty} f(x)", "$\nlim_(x -> infinity) f (x)\n$", displayMode: true)
    }

    @TestCase
    func markitHtmlShouldStayCopyableWithMathMlAndKaTeXSvgHtml() {
        assertHtmlContains("\\frac{a}{b}", "class=\"katex mathtex\"")
        assertHtmlContains("\\frac{a}{b}", "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"")
        assertHtmlContains("\\frac{a}{b}", "class=\"katex-html\" aria-hidden=\"true\"")
    }

    @TestCase
    func markitTypeSystemFormulasShouldRenderTurnstilesAndMapsto() {
        let substitution = "\\sigma = [X \\mapsto TA](~)"
        let subtype = "\\Delta \\vdash (A1 ..., An) <: \\sigma (T_{1},..., T_{n})"
        assertRendersAll([substitution, subtype])
        assertHtmlContains(substitution, "↦")
        assertMathMlContains(substitution, "<mo>↦</mo>")
        assertHtmlContains(subtype, "⊢")
        assertMathMlContains(subtype, "<mo>⊢</mo>")
        assertHtmlContains(subtype, "&lt;")
        assertHtmlContains(subtype, "…")
        assertHtmlContains(subtype, "&lt;:")
        assertMathMlContains(subtype, "<mo>&lt;:</mo>")
        assertTypstEquals(substitution, "$sigma = [X ↦ T A] ( )$")
        assertTypstEquals(subtype, "$Δ ⊢ (A 1 …, A n) <: sigma (T_1, …, T_n)$")
    }

    @TestCase
    func markitLogicAndSemanticRelationSymbolsShouldRender() {
        let formulas = [
            "A \\dashv B",
            "\\Gamma \\vDash A",
            "\\Gamma \\models A",
            "\\Gamma \\nvdash A",
            "\\Gamma \\nvDash A",
            "\\Gamma \\nVdash A",
            "A \\land B \\lor \\neg C",
            "\\top \\implies \\bot",
            "A \\hookrightarrow B \\twoheadrightarrow C",
            "A \\longmapsto B",
            "A \\therefore B \\because C",
            "A \\longrightarrow B \\Longrightarrow C",
            "A \\nrightarrow B \\nRightarrow C",
            "A \\nearrow B \\swarrow C",
            "A \\uparrow B \\Downarrow C",
            "A \\rightleftarrows B \\leftrightarrows C",
            "A \\rightarrowtail B \\leftarrowtail C",
            "A \\looparrowright B \\curvearrowleft C",
            "A \\rightsquigarrow B \\leftrightsquigarrow C",
            "A \\leqslant B \\geqslant C",
            "A \\lesssim B \\gtrapprox C",
            "A \\subsetneq B \\nsubseteq C",
            "A \\sqsubseteq B \\sqsupseteq C",
            "A \\sqcap B \\sqcup C",
            "\\bigcup_i A_i \\cap \\bigcap_j B_j",
            "\\bigvee_i P_i \\land \\bigwedge_j Q_j",
            "\\exists x \\lor \\nexists y"
        ]
        assertRendersAll(formulas)
        assertHtmlContains("A \\dashv B", "⊣")
        assertHtmlContains("\\Gamma \\vDash A", "⊨")
        assertHtmlContains("\\Gamma \\nvdash A", "⊬")
        assertHtmlContains("A \\land B \\lor \\neg C", "∧")
        assertHtmlContains("A \\land B \\lor \\neg C", "∨")
        assertHtmlContains("A \\land B \\lor \\neg C", "¬")
        assertHtmlContains("\\top \\implies \\bot", "⊤")
        assertHtmlContains("\\top \\implies \\bot", "⊥")
        assertHtmlContains("A \\hookrightarrow B \\twoheadrightarrow C", "↪")
        assertHtmlContains("A \\longmapsto B", "⟼")
        assertHtmlContains("A \\longrightarrow B \\Longrightarrow C", "⟶")
        assertHtmlContains("A \\nrightarrow B \\nRightarrow C", "↛")
        assertHtmlContains("A \\nearrow B \\swarrow C", "↗")
        assertHtmlContains("A \\uparrow B \\Downarrow C", "↑")
        assertHtmlContains("A \\rightleftarrows B \\leftrightarrows C", "⇄")
        assertHtmlContains("A \\rightarrowtail B \\leftarrowtail C", "↣")
        assertHtmlContains("A \\looparrowright B \\curvearrowleft C", "↬")
        assertHtmlContains("A \\rightsquigarrow B \\leftrightsquigarrow C", "⇝")
        assertHtmlContains("A \\leqslant B \\geqslant C", "⩽")
        assertHtmlContains("A \\lesssim B \\gtrapprox C", "≲")
        assertHtmlContains("A \\subsetneq B \\nsubseteq C", "⊊")
        assertHtmlContains("A \\sqsubseteq B \\sqsupseteq C", "⊑")
        assertHtmlContains("A \\sqcap B \\sqcup C", "⊓")
        assertHtmlContains("\\bigcup_i A_i \\cap \\bigcap_j B_j", "⋃")
        assertHtmlContains("\\bigvee_i P_i \\land \\bigwedge_j Q_j", "⋁")
        assertHtmlContains("\\exists x \\lor \\nexists y", "∄")
    }
}
