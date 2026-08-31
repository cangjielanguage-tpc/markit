package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[MathTex, MathTexTypst]
class MathtexTypstWriterTests {
    @TestCase
    func typstShouldRenderBasicFractionsRootsAndScriptsExactly() {
        assertTypstEquals("\\frac{a}{b}", "$frac(a, b)$")
        assertTypstEquals("\\sqrt{x}", "$sqrt(x)$")
        assertTypstEquals("x_i + y^2", "$x_i + y^2$")
        assertTypstEquals("x_i^2", "$x_i^2$")
    }

    @TestCase
    func typstShouldRenderCommonSymbolsExactly() {
        assertTypstEquals("\\alpha + \\beta = \\gamma", "$alpha + beta = gamma$")
        assertTypstEquals("x \\leq y \\geq z", "$x <= y >= z$")
        assertTypstEquals("x \\neq y", "$x != y$")
        assertTypstEquals("A \\subseteq B", "$A subset.eq B$")
        assertTypstEquals("x \\to \\infty", "$x -> infinity$")
    }

    @TestCase
    func typstShouldRenderTextAndDisplayModeExactly() {
        assertTypstEquals("\\text{rate} = \\frac{x}{t}", "$\"rate\" = frac(x, t)$")
        assertTypstEquals("\\sum_{n=1}^{10} n", "$sum_(n = 1)^10 n$")
        assertTypstEquals("\\frac{a}{b}", "$\nfrac(a, b)\n$", displayMode: true)
    }

    @TestCase
    func typstShouldRenderStructuredEnvironmentsExactly() {
        assertTypstEquals("\\begin{matrix}a&b\\\\c&d\\end{matrix}", "$mat(a, b; c, d)$")
        assertTypstEquals("\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}", "$cases(a, \"if \" b; c, \"otherwise\")$")
        assertTypstEquals("\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "$align(a & = b; c & = d)$")
    }

    @TestCase
    func typstShouldRenderLeftRightExactly() {
        assertTypstEquals("\\left(\\frac{x}{y}\\right)", "$(frac(x, y))$")
        assertTypstEquals("\\left. x \\right)", "$x)$")
    }
}
