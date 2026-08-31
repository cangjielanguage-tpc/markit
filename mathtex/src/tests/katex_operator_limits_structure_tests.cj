package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexHtml, KatexMathMl, KatexOperator, KatexLimits]
class KatexOperatorLimitsStructureTests {
    @TestCase
    func migratedKatexInlineSumShouldUseSmallOperatorSideScripts() {
        // Source: KaTeX renderToString("\\sum_{i=1}^n x_i", displayMode: false).
        let tex = "\\sum_{i=1}^n x_i"
        assertHtmlContains(tex, "class=\"mop\"><span class=\"mop op-symbol small-op\" style=\"position:relative;top:0em;\">∑</span><span class=\"msupsub katex-msupsub\">")
        assertHtmlContains(tex, "class=\"mspace\" style=\"margin-right:0.1667em;\"></span><span class=\"mord katex-scripts\">")
        assertMathMlContains(tex, "<msubsup><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></msubsup>")
    }

    @TestCase
    func migratedKatexDisplaySumShouldUseLargeOperatorLimits() {
        // Source: KaTeX renderToString("\\sum_{i=1}^n x_i", displayMode: true).
        let tex = "\\sum_{i=1}^n x_i"
        assertHtmlContains(tex, "class=\"mop op-limits\"", displayMode: true)
        assertHtmlContains(tex, "class=\"mop op-symbol large-op\">∑</span>", displayMode: true)
        assertHtmlContains(tex, "style=\"top:-1.8723em;margin-left:0em;\"", displayMode: true)
        assertHtmlContains(tex, "style=\"top:-4.3em;margin-left:0em;\"", displayMode: true)
        assertMathMlContains(tex, "<munderover><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></munderover>", displayMode: true)
    }

    @TestCase
    func migratedKatexInlineDisplaystyleSumShouldUseLargeOperatorLimits() {
        // Source: KaTeX renderToString("\\displaystyle{\\sum_{i=1}^n x_i}", displayMode: false).
        let tex = "\\displaystyle{\\sum_{i=1}^n x_i}"
        assertHtmlContains(tex, "class=\"mop op-limits\"")
        assertHtmlContains(tex, "class=\"mop op-symbol large-op\">∑</span>")
        assertMathMlContains(tex, "<munderover><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></munderover>")
    }

    @TestCase
    func migratedKatexDisplayTextstyleSumShouldUseSmallOperatorSideScripts() {
        // Source: KaTeX renderToString("\\textstyle{\\sum_{i=1}^n x_i}", displayMode: true).
        let tex = "\\textstyle{\\sum_{i=1}^n x_i}"
        assertHtmlContains(tex, "class=\"mop\"><span class=\"mop op-symbol small-op\" style=\"position:relative;top:0em;\">∑</span><span class=\"msupsub katex-msupsub\">", displayMode: true)
        assertMathMlContains(tex, "<msubsup><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></msubsup>", displayMode: true)
    }

    @TestCase
    func migratedKatexExplicitLimitsShouldForceLimitsLayout() {
        // Source: KaTeX renderToString("\\sum\\limits_{i=1}^n x_i", displayMode: false).
        let tex = "\\sum\\limits_{i=1}^n x_i"
        assertHtmlContains(tex, "class=\"mop op-limits\"")
        assertHtmlContains(tex, "class=\"mop op-symbol small-op\">∑</span>")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:1.3514em;\"")
        assertHtmlContains(tex, "style=\"top:-2.1223em;margin-left:0em;\"")
        assertHtmlContains(tex, "style=\"top:-3.95em;margin-left:0em;\"")
        assertMathMlContains(tex, "<munderover><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></munderover>")
        assertTypstEquals(tex, "$sum_(i = 1)^n x_i$")
    }

    @TestCase
    func migratedKatexExplicitNolimitsShouldForceSideScriptsInDisplay() {
        // Source: KaTeX renderToString("\\sum\\nolimits_{i=1}^n x_i", displayMode: true).
        let tex = "\\sum\\nolimits_{i=1}^n x_i"
        assertHtmlContains(tex, "class=\"mop\"><span class=\"mop op-symbol small-op\" style=\"position:relative;top:0em;\">∑</span><span class=\"msupsub katex-msupsub\">", displayMode: true)
        assertMathMlContains(tex, "<msubsup><mo>∑</mo><mrow><mi>i</mi><mo>=</mo><mn>1</mn></mrow><mi>n</mi></msubsup>", displayMode: true)
        assertTypstEquals(tex, "$\nsum_(i = 1)^n x_i\n$", displayMode: true)
    }

    @TestCase
    func migratedKatexIntegralLimitsShouldUseLimitsWhenForced() {
        // Source: KaTeX renderToString("\\int\\limits_0^1 x", displayMode: false).
        let tex = "\\int\\limits_0^1 x"
        assertHtmlContains(tex, "class=\"mop op-limits\"")
        assertHtmlContains(tex, "class=\"mop op-symbol small-op\">∫</span>")
        assertMathMlContains(tex, "<munderover><mo>∫</mo><mn>0</mn><mn>1</mn></munderover>")
    }

    @TestCase
    func migratedKatexDisplayIntegralShouldKeepSideScriptsByDefault() {
        // Source: KaTeX v0.16.47 src/functions/op.ts and src/functions/supsub.ts.
        // Integrals do not use limits unless forced, but symbol operators use large-op in display style.
        let tex = "\\int_0^1 x"
        assertHtmlContains(tex, "class=\"mop\"><span class=\"mop op-symbol large-op\" style=\"margin-right:0.4445em;position:relative;top:-0.0011em;\">∫</span><span class=\"msupsub katex-msupsub\">", displayMode: true)
        assertHtmlContains(tex, "style=\"top:-1.7881em;margin-left:-0.4445em;margin-right:0.05em;\"", displayMode: true)
        assertHtmlContains(tex, "style=\"top:-3.8129em;margin-right:0.05em;\"", displayMode: true)
        assertMathMlContains(tex, "<msubsup><mo>∫</mo><mn>0</mn><mn>1</mn></msubsup>", displayMode: true)
    }

    @TestCase
    func migratedKatexLogWithSubscriptShouldUseTextOperatorScripts() {
        // Source: KaTeX renderToString("\\sin(x) + \\log_2 n \\le \\infty").
        let tex = "\\sin(x) + \\log_2 n \\le \\infty"
        assertHtmlContains(tex, "class=\"mop\"><span class=\"mop\">lo<span style=\"margin-right:0.0139em;\">g</span></span><span class=\"msupsub katex-msupsub\">")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:0.207em;\"")
        assertHtmlContains(tex, "style=\"top:-2.4559em;margin-right:0.05em;\"")
        assertHtmlContains(tex, "class=\"mspace\" style=\"margin-right:0.1667em;\"></span><span class=\"katex-symbol mord mathnormal\">n</span>")
        assertMathMlContains(tex, "<msub><mo>log</mo><mn>2</mn></msub><mi>n</mi><mo>≤</mo>")
    }

    @TestCase
    func migratedKatexOperatornameShouldRenderUprightText() {
        // Source: src/functions/operatorname.ts HTML builder.
        assertHtmlContains("\\operatorname{rank}(A)", "class=\"mop\"><span class=\"mord mathrm\">rank</span></span>")
    }
}
