package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexHtml, KatexMathMl, KatexSqrt]
class KatexSqrtStructureTests {
    @TestCase
    func migratedKatexSimpleSqrtShouldUseMainSqrtSvgMetrics() {
        // Source: src/functions/sqrt.ts and src/svgGeometry.ts sqrtMain builder output.
        assertHtmlContains("\\sqrt{x}", "class=\"mord sqrt katex-sqrt\"")
        assertHtmlContains("\\sqrt{x}", "class=\"vlist\" style=\"height:0.8003em;\"")
        assertHtmlContains("\\sqrt{x}", "class=\"svg-align\" style=\"top:-3em;\"")
        assertHtmlContains("\\sqrt{x}", "class=\"pstrut\" style=\"height:3em;\"")
        assertHtmlContains("\\sqrt{x}", "class=\"mord\" style=\"padding-left:0.833em;\"")
        assertHtmlContains("\\sqrt{x}", "class=\"hide-tail\" style=\"min-width:0.853em;height:1.08em;display:inline-block;\"")
        assertHtmlContains("\\sqrt{x}", "viewBox=\"0 0 400000 1080\"")
        assertMathMlContains("\\sqrt{x}", "<msqrt><mrow><mi>x</mi></mrow></msqrt>")
    }

    @TestCase
    func migratedKatexSqrtWithScriptsShouldUseLargerSqrtSvgMetrics() {
        // Source: KaTeX renderToString("\\sqrt{x^2 + y^2}") sqrtSize1 metrics.
        assertHtmlContains("\\sqrt{x^2 + y^2}", "class=\"vlist\" style=\"height:0.9578em;\"")
        assertHtmlContains("\\sqrt{x^2 + y^2}", "class=\"svg-align\" style=\"top:-3.2em;\"")
        assertHtmlContains("\\sqrt{x^2 + y^2}", "class=\"pstrut\" style=\"height:3.2em;\"")
        assertHtmlContains("\\sqrt{x^2 + y^2}", "class=\"mord\" style=\"padding-left:1em;\"")
        assertHtmlContains("\\sqrt{x^2 + y^2}", "class=\"hide-tail\" style=\"min-width:1.02em;height:1.28em;display:inline-block;\"")
        assertHtmlContains("\\sqrt{x^2 + y^2}", "viewBox=\"0 0 400000 1296\"")
        assertHtmlContains("\\sqrt{x^2 + y^2}", "class=\"vlist\" style=\"height:0.2822em;\"")
        assertHtmlContains("\\sqrt{x^2 + y^2}", "class=\"vlist\" style=\"height:0.7401em;\"")
        assertHtmlContains("\\sqrt{x^2 + y^2}", "style=\"top:-2.989em;margin-right:0.05em;\"")
    }

    @TestCase
    func migratedKatexIndexedSqrtShouldExposeRootHtmlAndMathMlMroot() {
        // Source: src/functions/sqrt.ts optional root handling.
        assertHtmlContains("\\sqrt[3]{2}", "class=\"root katex-sqrt-root\"")
        assertHtmlContains("\\sqrt[3]{2}", "class=\"vlist\" style=\"height:0.7869em;\"")
        assertHtmlContains("\\sqrt[3]{2}", "style=\"top:-2.9647em;\"")
        assertHtmlContains("\\sqrt[3]{2}", "class=\"sizing reset-size6 size1 mtight\"")
        assertMathMlContains("\\sqrt[3]{2}", "<mroot><mrow><mn>2</mn></mrow><mrow><mn>3</mn></mrow></mroot>")
    }
}
