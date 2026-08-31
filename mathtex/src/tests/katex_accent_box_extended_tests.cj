package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexAccent, KatexBox]
class KatexAccentBoxExtendedTests {
    @TestCase
    func migratedKatexAccentParserShouldParseMoreAccents() {
        // Source: test/katex-spec.ts / describe("An accent parser") / it("should not fail")
        assertParsesAll([
            "\\vec{x}",
            "\\vec{x^2}",
            "\\vec{x}^2",
            "\\vec x",
            "\\underbar{X}",
            "\\widehat{x}",
            "\\widecheck{x}",
            "\\overrightarrow{x}"
        ])
    }

    @TestCase
    func migratedKatexAccentBuilderShouldRenderMoreAccents() {
        // Source: test/katex-spec.ts / describe("An accent builder")
        assertRendersAll([
            "\\vec{x}",
            "\\vec{x}^2",
            "\\vec{x}_2",
            "\\vec{x}_2^2"
        ])
    }

    @TestCase
    func migratedKatexStretchyShiftyAccentBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and shifty accent builder")
        assertRendersAll([
            "\\widehat{AB}",
            "\\widecheck{AB}",
            "\\widehat{AB}^2",
            "\\widehat{AB}_2",
            "\\widehat{AB}_2^2"
        ])
    }

    @TestCase
    func migratedKatexStretchyNonShiftyAccentBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy and non-shifty accent builder")
        assertRendersAll([
            "\\overrightarrow{AB}",
            "\\overrightarrow{AB}^2",
            "\\overrightarrow{AB}_2",
            "\\overrightarrow{AB}_2^2"
        ])
    }

    @TestCase
    func migratedKatexStretchyMathMlBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("A stretchy MathML builder")
        assertRendersAll(["\\widetilde{ABCD}"])
    }

    @TestCase
    func migratedKatexUnderAccentParserShouldParse() {
        // Source: test/katex-spec.ts / describe("An under-accent parser")
        assertParsesAll([
            "\\underrightarrow{x}",
            "\\underrightarrow{x^2}",
            "\\underrightarrow{x}^2",
            "\\underrightarrow x"
        ])
    }

    @TestCase
    func migratedKatexUnderAccentBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("An under-accent builder")
        assertRendersAll([
            "\\underrightarrow{x}",
            "\\underrightarrow{x}^2",
            "\\underrightarrow{x}_2",
            "\\underrightarrow{x}_2^2"
        ])
    }

    @TestCase
    func migratedKatexExtensibleArrowParserShouldParse() {
        // Source: test/katex-spec.ts / describe("An extensible arrow parser")
        assertParsesAll([
            "\\xrightarrow{x}",
            "\\xrightarrow{x^2}",
            "\\xrightarrow{x}^2",
            "\\xrightarrow x",
            "\\xrightarrow[under]{over}"
        ])
    }

    @TestCase
    func migratedKatexExtensibleArrowBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("An extensible arrow builder")
        assertRendersAll([
            "\\xrightarrow{x}",
            "\\xrightarrow{x}^2",
            "\\xrightarrow{x}_2",
            "\\xrightarrow{x}_2^2",
            "\\xrightarrow[under]{over}"
        ])
    }

    @TestCase
    func migratedKatexHorizontalBraceParserShouldParse() {
        // Source: test/katex-spec.ts / describe("A horizontal brace parser")
        assertParsesAll([
            "\\overbrace{x}",
            "\\overbrace{x^2}",
            "\\overbrace{x}^2",
            "\\overbrace x",
            "\\underbrace{x}_2",
            "\\underbrace{x}_2^2"
        ])
    }

    @TestCase
    func migratedKatexHorizontalBraceBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("A horizontal brace builder")
        assertRendersAll([
            "\\overbrace{x}",
            "\\overbrace{x}^2",
            "\\underbrace{x}_2",
            "\\underbrace{x}_2^2"
        ])
    }

    @TestCase
    func migratedKatexHorizontalBracketParserShouldParse() {
        // Source: test/katex-spec.ts / describe("A horizontal bracket parser")
        assertParsesAll([
            "\\overbracket{x}",
            "\\underbracket{x}_2",
            "\\overbracket x",
            "\\underbracket x",
            "\\overbracket x^2"
        ])
    }

    @TestCase
    func migratedKatexHorizontalBracketBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("A horizontal bracket builder")
        assertRendersAll([
            "\\overbracket{x}",
            "\\underbracket{x}_2"
        ])
    }

    @TestCase
    func migratedKatexBoxedParserShouldParse() {
        // Source: test/katex-spec.ts / describe("A boxed parser")
        assertParsesAll([
            "\\boxed{x}",
            "\\boxed{x^2}",
            "\\boxed{x}^2",
            "\\boxed x"
        ])
    }

    @TestCase
    func migratedKatexBoxedBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("A boxed builder")
        assertRendersAll([
            "\\boxed{x}",
            "\\boxed{x}^2",
            "\\boxed{x}_2",
            "\\boxed{x}_2^2"
        ])
    }

    @TestCase
    func migratedKatexColorboxParserShouldParseTextCases() {
        // Source: test/katex-spec.ts / describe("A colorbox parser")
        assertParsesAll([
            "\\colorbox{red}{a b}",
            "\\colorbox{red}{x}^2",
            "\\colorbox{red} x",
            "\\colorbox{#197}{a b}",
            "\\colorbox{#1a9b7c}{a b}"
        ])
    }

    @TestCase
    func migratedKatexColorboxBuilderShouldRenderTextCases() {
        // Source: test/katex-spec.ts / describe("A colorbox builder")
        assertRendersAll([
            "\\colorbox{red}{a b}",
            "\\colorbox{red}{a b}^2",
            "\\colorbox{red} x"
        ])
    }

    @TestCase
    func migratedKatexFcolorboxParserShouldParseTextCases() {
        // Source: test/katex-spec.ts / describe("An fcolorbox parser")
        assertParsesAll([
            "\\fcolorbox{blue}{yellow}{a b}",
            "\\fcolorbox{blue}{yellow}{x}^2",
            "\\fcolorbox{blue}{yellow} x",
            "\\fcolorbox{blue}{#197}{a b}",
            "\\fcolorbox{blue}{#1a9b7c}{a b}"
        ])
    }

    @TestCase
    func migratedKatexFcolorboxBuilderShouldRenderTextCases() {
        // Source: test/katex-spec.ts / describe("A fcolorbox builder")
        assertRendersAll([
            "\\fcolorbox{blue}{yellow}{a b}",
            "\\fcolorbox{blue}{yellow}{a b}^2",
            "\\fcolorbox{blue}{yellow} x"
        ])
    }

    @TestCase
    func migratedKatexStrikeThroughParserShouldParse() {
        // Source: test/katex-spec.ts / describe("A strike-through parser")
        assertParsesAll([
            "\\cancel{x}",
            "\\cancel{x^2}",
            "\\cancel{x}^2",
            "\\cancel x",
            "\\text{\\sout{abc}}"
        ])
    }

    @TestCase
    func migratedKatexStrikeThroughBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("A strike-through builder")
        assertRendersAll([
            "\\cancel{x}",
            "\\cancel{x}^2",
            "\\cancel{x}_2",
            "\\cancel{x}_2^2",
            "\\sout{x}",
            "\\sout{x}^2",
            "\\sout{x}_2",
            "\\sout{x}_2^2",
            "\\text{\\sout{abc}}"
        ])
    }

    @TestCase
    func migratedKatexActuarialAngleBuilderShouldRender() {
        // Source: test/katex-spec.ts / describe("A actuarial angle builder")
        assertRendersAll([
            "a_{\\angl{n}}",
            "a_{\\angl{n}i}",
            "a_{\\angl n}",
            "a_\\angln"
        ])
    }

    @TestCase
    func migratedKatexPhaseShouldRenderInMathMode() {
        // Source: test/katex-spec.ts / describe("\\phase")
        assertRendersAll(["\\phase{-78.2^\\circ}"])
    }

    @TestCase
    func migratedKatexPhantomParserAdditionalCasesShouldParse() {
        // Source: test/katex-spec.ts / describe("A phantom parser")
        assertParsesAll([
            "\\phantom{x}",
            "\\phantom{x^2}",
            "\\phantom{x}^2",
            "\\phantom x",
            "\\hphantom{x}",
            "\\hphantom{x^2}",
            "\\hphantom{x}^2",
            "\\hphantom x"
        ])
    }

    @TestCase
    func migratedKatexPhantomBuilderAdditionalCasesShouldRender() {
        // Source: test/katex-spec.ts / describe("A phantom builder")
        assertRendersAll([
            "\\phantom{x}",
            "\\phantom{x^2}",
            "\\phantom{x}^2",
            "\\phantom x",
            "\\mathstrut",
            "\\hphantom{x}",
            "\\hphantom{x^2}",
            "\\hphantom{x}^2",
            "\\hphantom x"
        ])
    }
}
