package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*
import mathtex.MathRenderer

@Test
@Tag[KatexMigration, KatexHtml, KatexMathMl]
class KatexMathMlHtmlMigrationTests {
    @TestCase
    func migratedKatexMathMlBuilderCoreCasesShouldRender() {
        // Source: test/mathml-spec.ts / describe("A MathML builder")
        assertRendersAll([
            "1+2",
            "1234",
            "x'",
            "\\phantom{x}",
            "\\sum_{n=1}^{10} n",
            "\\int_0^1 x dx",
            "\\limsup_{x \\rightarrow \\infty}",
            "\\raisebox{1em}{x}",
            "\\left(\\frac{x}{y}\\right)",
            "\\colorbox{red}{x}",
            "\\href{https://katex.org}{KaTeX}",
            "\\mathchoice{D}{T}{S}{SS}",
            "\\boldsymbol{x}",
            "\\hat{x}",
            "\\tag{1}"
        ])
    }

    @TestCase
    func migratedKatexHtmlRootKeepsKatexAndMathtexClasses() {
        // Source: internal interface renderToString/root markup expectations, adapted to mathtex root class.
        let html = MathRenderer().renderHtmlAndMathMl("x^2").output
        @Expect(html.contains("class=\"katex mathtex\""), true)
        @Expect(html.contains("class=\"katex-mathml\""), true)
        @Expect(html.contains("class=\"katex-html\""), true)
    }
}
