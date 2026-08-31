package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexMacro]
class KatexMacroLikeExtendedTests {
    @TestCase
    func migratedKatexOversetAndUndersetShouldRender() {
        // Source: test/katex-spec.ts / describe("A macro expander") / overset and underset build cases.
        assertRendersAll([
            "\\overset{f}{\\rightarrow} Y",
            "\\underset{f}{\\rightarrow} Y"
        ])
    }

    @TestCase
    func migratedKatexIffImpliesImpliedbyShouldRender() {
        // Source: test/katex-spec.ts / describe("A macro expander") / iff, implies, impliedby.
        assertRendersAll([
            "X \\iff Y",
            "X \\implies Y",
            "X \\impliedby Y"
        ])
    }

    @TestCase
    func migratedKatexLogLikeMacroAliasesShouldParse() {
        // Source: test/katex-spec.ts / AMS log-like macro expansion tests.
        assertParsesAll([
            "\\limsup",
            "\\liminf",
            "\\injlim",
            "\\projlim",
            "\\varlimsup",
            "\\varliminf",
            "\\varinjlim",
            "\\varprojlim",
            "\\plim",
            "\\argmin",
            "\\argmax"
        ])
    }

    @TestCase
    func migratedKatexDefinitionCommandsShouldParseDefinitions() {
        // Source: test/katex-spec.ts / macro definition parser coverage, parse-only subset.
        assertParsesAll([
            "\\gdef\\foo{1}",
            "\\def\\foo{1}",
            "\\edef\\foo{1}",
            "\\xdef\\foo{1}",
            "\\gdef\\foo#1{hi #1}",
            "\\gdef\\foo#1#2{(#1,#2)}",
            "\\gdef\\foo#1#2#3#4#5#6#7#8#9{}",
            "\\def\\arraystretch{1.5}\\begin{matrix}a&b\\\\c&d\\end{matrix}"
        ])
    }

    @TestCase
    func migratedKatexGdefNoArgumentMacroShouldRenderExpandedBody() {
        // Source: test/katex-spec.ts / describe("A macro expander") / "\\gdef defines macros"
        assertRendersAll(["\\gdef\\foo{x^2}\\foo+\\foo"])
    }

    @TestCase
    func migratedKatexDefNoArgumentMacroShouldRenderExpandedBody() {
        // Source: test/katex-spec.ts / describe("A macro expander") / "\\def works locally", no-argument subset.
        assertRendersAll(["\\def\\x{1}\\x\\def\\x{2}\\x"])
    }

    @TestCase
    func migratedKatexDefinitionCommentsShouldNotCloseMacroBody() {
        // Source: test/katex-spec.ts / describe("A comment parser") / macro definition comment handling.
        assertRendersAll(["\\def\\foo{1 %}\n2}\n\\foo"])
    }

    @TestCase
    func migratedKatexGdefArgumentMacrosShouldRenderExpandedBody() {
        // Source: test/katex-spec.ts / describe("A macro expander") / "\\gdef defines macros" argument cases.
        assertRendersAll([
            "\\gdef\\foo#1{hi #1}\\foo{Alice}+\\foo{Bob}",
            "\\gdef\\foo#1#2{(#1,#2)}\\foo 1 2+\\foo 3 4"
        ])
        assertTypstEquals("\\gdef\\sq#1{#1^2}\\sq{x}+\\sq y", "$x^2 + y^2$")
    }

    @TestCase
    func migratedKatexNestedArgumentMacrosShouldRenderExpandedBody() {
        // Source: test/katex-spec.ts / describe("A macro expander") / nested macro argument expansion.
        assertTypstEquals("\\gdef\\baz#1{#1#1}\\gdef\\foo#1{\\baz{#1}}\\foo{x}", "$x x$")
    }

    @TestCase
    func migratedKatexArgumentMacrosShouldFlowIntoNestedParsers() {
        // Source: test/katex-spec.ts / macro expansion inside grouped parser contexts.
        assertHtmlContains("\\gdef\\sq#1{#1^2}\\left(\\sq{x}\\right)", "class=\"katex-delim-body\"")
        assertMathMlContains("\\gdef\\sq#1{#1^2}\\left(\\sq{x}\\right)", "<msup><mi>x</mi><mn>2</mn></msup>")
        assertMathMlContains("\\gdef\\sq#1{#1^2}\\begin{matrix}\\sq{x}&\\sq{y}\\end{matrix}", "<msup><mi>x</mi><mn>2</mn></msup>")
        assertMathMlContains("\\gdef\\sq#1{#1^2}\\begin{matrix}\\sq{x}&\\sq{y}\\end{matrix}", "<msup><mi>y</mi><mn>2</mn></msup>")
    }

    @TestCase
    func migratedKatexOperatornameStarShouldRender() {
        // Source: test/katex-spec.ts / describe("operatorname support")
        assertRendersAll(["\\operatorname*{x*Π∑\\Pi\\sum\\frac a b}"])
    }

    @TestCase
    func migratedKatexTagStarShouldRenderLikeTag() {
        // Source: test/katex-spec.ts / describe("\\tag support")
        assertRendersAll(["\\tag*{hi} x+y^2"])
    }

    @TestCase
    func migratedKatexMathchoiceDisplayCaseShouldRender() {
        // Source: test/katex-spec.ts / describe("The \\mathchoice function")
        assertRendersAll(["\\displaystyle\\mathchoice{\\sum_{k = 0}^{\\infty} x^k}{T}{S}{SS}"])
    }

    @TestCase
    func migratedKatexMathchoiceTextCaseShouldRender() {
        // Source: test/katex-spec.ts / describe("The \\mathchoice function")
        assertRendersAll(["\\mathchoice{D}{\\sum_{k = 0}^{\\infty} x^k}{S}{SS}"])
    }

    @TestCase
    func migratedKatexMathchoiceScriptCaseShouldRender() {
        // Source: test/katex-spec.ts / describe("The \\mathchoice function")
        assertRendersAll(["x_{\\mathchoice{D}{T}{\\sum_{k = 0}^{\\infty} x^k}{SS}}"])
    }

    @TestCase
    func migratedKatexMathchoiceScriptScriptCaseShouldRender() {
        // Source: test/katex-spec.ts / describe("The \\mathchoice function")
        assertRendersAll(["x_{y_{\\mathchoice{D}{T}{S}{\\sum_{k = 0}^{\\infty} x^k}}}"])
    }

    @TestCase
    func migratedKatexNewlineWithoutOptionalArgumentShouldRender() {
        // Source: test/katex-spec.ts / describe("Newlines via \\\\ and \\newline")
        assertRendersAll(["hello \\\\ world", "hello \\newline world"])
    }

    @TestCase
    func migratedKatexNewlineDoesNotScanOptionalSizeShouldRender() {
        // Source: test/katex-spec.ts / describe("Newlines via \\\\ and \\newline")
        assertRendersAll(["hello \\newline[w]orld"])
    }

    @TestCase
    func migratedKatexEmphNestedCasesShouldRender() {
        // Source: test/katex-spec.ts / describe("\\emph")
        assertRendersAll([
            "\\emph{foo \\emph{bar}}",
            "\\text{\\emph{foo \\emph{bar}}}",
            "\\textup{\\emph{foo \\emph{bar}}}",
            "\\textit{\\emph{foo \\emph{bar}}}"
        ])
    }
}
