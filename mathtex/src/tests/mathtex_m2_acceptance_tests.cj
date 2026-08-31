package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*
import mathtex.{MathRenderOptions, MathRenderer, MathTex}

@Test
@Tag[MathTex, MathTexM2, MathTexHtml, MathTexTypst, MathTexIntegration]
class MathtexM2AcceptanceTests {
    @TestCase
    func m2CommonKaTeXSubsetShouldRenderAccessibleStaticHtml() {
        let renderer = MathRenderer()
        let formulas = [
            "E = mc^2",
            "x_i^2 + y_{n+1}",
            "\\frac{a}{b} + \\sqrt{x^2 + y^2}",
            "\\sum\\limits_{i=1}^n x_i + \\int\\nolimits_0^1 f(x) dx",
            "\\left(\\frac{x}{y}\\right) + \\left\\lVert v \\right\\rVert",
            "\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}",
            "\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}",
            "\\begin{aligned}a&=b+c\\\\d&=e+f\\end{aligned}",
            "\\newcommand\\sq[1]{#1^2}\\sq{x}+\\sq{y}",
            "\\overline{x} + \\underline{y} + \\boxed{z}"
        ]

        for (tex in formulas) {
            let result = renderer.renderHtmlAndMathMl(tex, options: MathRenderOptions(displayMode: tex.contains("\\begin")))
            @Expect(result.supported, true)
            @Expect(result.output.contains("class=\"katex mathtex"), true)
            @Expect(result.output.contains("<span class=\"katex-mathml\">"), true)
            @Expect(result.output.contains("<span class=\"katex-html\" aria-hidden=\"true\">"), true)
            @Expect(result.output.contains("data-tex=\""), true)
            @Expect(result.output.contains("<annotation encoding=\"application/x-tex\">"), true)
        }
    }

    @TestCase
    func m2CommonKaTeXSubsetShouldRenderTypstForMarkit() {
        let renderer = MathRenderer()
        let formulas = [
            "E = mc^2",
            "\\frac{1}{n}\\sum_{i=1}^n x_i",
            "\\sqrt{x^2 + y^2}",
            "\\sum\\limits_{i=1}^n x_i",
            "\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}",
            "\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}",
            "\\begin{aligned}a&=b+c\\\\d&=e+f\\end{aligned}"
        ]

        for (tex in formulas) {
            let result = renderer.renderTypst(tex, options: MathRenderOptions(displayMode: tex.contains("\\begin")))
            @Expect(result.supported, true)
            @Expect(result.output.isEmpty(), false)
        }
    }

    @TestCase
    func m2ParserShouldSupportChunkedInputForMarkitPipelines() {
        let session = MathTex().createSession()
        let first = session.feed("\\frac{a}")
        @Expect(first.isFinal, false)
        @Expect(first.bytesAccepted, 8)

        let snapshot = session.snapshot()
        @Expect(snapshot.source, "\\frac{a}")

        session.feed("{b} + ")
        session.feedBytes("x_i".toArray())
        let finalOutput = session.finalize()
        @Expect(finalOutput.finalUpdate.isFinal, true)
        @Expect(finalOutput.expression.source, "\\frac{a}{b} + x_i")

        let rendered = MathRenderer().renderHtmlAndMathMl(finalOutput.expression.source)
        @Expect(rendered.supported, true)
        @Expect(rendered.output.contains("class=\"mfrac katex-frac\""), true)
        @Expect(rendered.output.contains("class=\"msupsub katex-msupsub\""), true)
    }
}
