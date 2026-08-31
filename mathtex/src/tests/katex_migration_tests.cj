package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*
import mathtex.{MathRenderer, MathTex}
import mathtex.ast.{
    MathColorNode,
    MathCommandNode,
    MathErrorNode,
    MathFractionNode,
    MathGroupNode,
    MathNode,
    MathSequenceNode,
    MathSizingNode,
    MathSqrtNode,
    MathSupSubNode,
    MathSymbolNode,
    MathTextNode
}

// Migrated from KaTeX v0.16.47 test/katex-spec.ts.
@Test
@Tag[KatexMigration, KatexParser]
class KatexMigrationTests {
    @TestCase
    func parserShouldNotFailOnEmptyString() {
        // Source: describe("A parser") / it("should not fail on an empty string")
        let root = parseRoot("")

        @Expect(root.children.size, 0)
    }

    @TestCase
    func parserShouldIgnoreWhitespace() {
        // Source: describe("A parser") / it("should ignore whitespace")
        let direct = mathMlBodyWithoutTexAnnotation("xy")
        let spaced = mathMlBodyWithoutTexAnnotation("    x    y    ")

        @Expect(spaced, direct)
    }

    @TestCase
    func parserShouldIgnoreWhitespaceInAtom() {
        // Source: describe("A parser") / it("should ignore whitespace in atom")
        let direct = mathMlBodyWithoutTexAnnotation("x^y")
        let spaced = mathMlBodyWithoutTexAnnotation("    x   ^ y    ")

        @Expect(spaced, direct)
    }

    @TestCase
    func ordParserShouldNotFail() {
        // Source: describe("An ord parser") / it("should not fail")
        @Expect(hasError(parseRoot("1234|/@.\"`abcdefgzABCDEFGZ")), false)
    }

    @TestCase
    func ordParserShouldBuildAListOfOrds() {
        // Source: describe("An ord parser") / it("should build a list of ords")
        assertAllSymbolsHaveFamily("1234|/@.\"`abcdefgzABCDEFGZ", "ord")
    }

    @TestCase
    func ordParserShouldParseTheRightNumberOfOrds() {
        // Source: describe("An ord parser") / it("should parse the right number of ords")
        let expression = "1234|/@.\"`abcdefgzABCDEFGZ"
        @Expect(parseRoot(expression).children.size, expression.size)
    }

    @TestCase
    func binParserShouldNotFail() {
        // Source: describe("A bin parser") / it("should not fail")
        @Expect(hasError(parseRoot("+-*\\cdot\\pm\\div")), false)
    }

    @TestCase
    func binParserShouldBuildAListOfBins() {
        // Source: describe("A bin parser") / it("should build a list of bins")
        assertAllSymbolsHaveFamily("+-*\\cdot\\pm\\div", "bin")
    }

    @TestCase
    func relParserShouldNotFail() {
        // Source: describe("A rel parser") / it("should not fail")
        @Expect(hasError(parseRoot("=<>\\leq\\geq\\neq\\nleq\\ngeq\\cong")), false)
        @Expect(hasError(parseRoot("\\not=\\not<\\not>\\not\\leq\\not\\geq\\not\\in")), false)
    }

    @TestCase
    func relParserShouldBuildAListOfRels() {
        // Source: describe("A rel parser") / it("should build a list of rels")
        assertAllSymbolsHaveFamily("=<>\\leq\\geq\\neq\\nleq\\ngeq\\cong", "rel")
    }

    @TestCase
    func punctParserShouldNotFail() {
        // Source: describe("A punct parser") / it("should not fail")
        @Expect(hasError(parseRoot(",;")), false)
    }

    @TestCase
    func punctParserShouldBuildAListOfPuncts() {
        // Source: describe("A punct parser") / it("should build a list of puncts")
        assertAllSymbolsHaveFamily(",;", "punct")
    }

    @TestCase
    func openParserShouldNotFail() {
        // Source: describe("An open parser") / it("should not fail")
        @Expect(hasError(parseRoot("([")), false)
    }

    @TestCase
    func openParserShouldBuildAListOfOpens() {
        // Source: describe("An open parser") / it("should build a list of opens")
        assertAllSymbolsHaveFamily("([", "open")
    }

    @TestCase
    func closeParserShouldNotFail() {
        // Source: describe("A close parser") / it("should not fail")
        @Expect(hasError(parseRoot(")]?!")), false)
    }

    @TestCase
    func closeParserShouldBuildAListOfCloses() {
        // Source: describe("A close parser") / it("should build a list of closes")
        assertAllSymbolsHaveFamily(")]?!", "close")
    }

    @TestCase
    func mathinnerParserShouldNotFail() {
        // Source: describe("A mathinner parser") / it("should not fail")
        @Expect(hasError(parseRoot("\\mathinner{\\langle{\\psi}\\rangle}")), false)
        @Expect(hasError(parseRoot("\\frac 1 {\\mathinner{\\langle{\\psi}\\rangle}}")), false)
    }

    @TestCase
    func mathinnerParserShouldReturnOneGroup() {
        // Source: describe("A mathinner parser") / it("should return one group, not a fragment")
        @Expect(parseRoot("\\mathinner{\\langle{\\psi}\\rangle}").children.size, 1)
    }

    @TestCase
    func katexParserShouldNotFail() {
        // Source: describe("A \\KaTeX parser") / it("should not fail")
        let node = firstNode("\\KaTeX")
        if (let text: MathTextNode <- node) {
            @Expect(text.text, "KaTeX")
            return
        }
        throw IllegalArgumentException("Expected MathTextNode")
    }

    @TestCase
    func supsubShouldNotFailOnSuperscripts() {
        // Source: describe("A subscript and superscript parser") / it("should not fail on superscripts")
        @Expect(hasError(parseRoot("x^2")), false)
    }

    @TestCase
    func supsubShouldNotFailOnSubscripts() {
        // Source: describe("A subscript and superscript parser") / it("should not fail on subscripts")
        @Expect(hasError(parseRoot("x_3")), false)
    }

    @TestCase
    func supsubShouldNotFailOnBothSubscriptsAndSuperscripts() {
        // Source: describe("A subscript and superscript parser") / it("should not fail on both subscripts and superscripts")
        @Expect(hasError(parseRoot("x^2_3")), false)
        @Expect(hasError(parseRoot("x_2^3")), false)
    }

    @TestCase
    func supsubShouldNotFailWhenThereIsNoNucleus() {
        // Source: describe("A subscript and superscript parser") / it("should not fail when there is no nucleus")
        @Expect(hasError(parseRoot("^3")), false)
        @Expect(hasError(parseRoot("^3+")), false)
        @Expect(hasError(parseRoot("_2")), false)
        @Expect(hasError(parseRoot("^3_2")), false)
        @Expect(hasError(parseRoot("_2^3")), false)
    }

    @TestCase
    func supsubShouldProduceSupsubForSuperscript() {
        // Source: describe("A subscript and superscript parser") / it("should produce supsubs for superscript")
        let node = firstNode("x^2")

        if (let script: MathSupSubNode <- node) {
            @Expect(script.base.kind, "Symbol")
            @Expect(script.sup.isSome(), true)
            @Expect(script.sub.isNone(), true)
            return
        }
        throw IllegalArgumentException("Expected MathSupSubNode")
    }

    @TestCase
    func supsubShouldProduceSupsubForSubscript() {
        // Source: describe("A subscript and superscript parser") / it("should produce supsubs for subscript")
        let node = firstNode("x_3")

        if (let script: MathSupSubNode <- node) {
            @Expect(script.base.kind, "Symbol")
            @Expect(script.sub.isSome(), true)
            @Expect(script.sup.isNone(), true)
            return
        }
        throw IllegalArgumentException("Expected MathSupSubNode")
    }

    @TestCase
    func supsubShouldProduceSupsubForCaretUnderscore() {
        // Source: describe("A subscript and superscript parser") / it("should produce supsubs for ^_")
        let node = firstNode("x^2_3")

        if (let script: MathSupSubNode <- node) {
            @Expect(script.base.kind, "Symbol")
            @Expect(script.sup.isSome(), true)
            @Expect(script.sub.isSome(), true)
            return
        }
        throw IllegalArgumentException("Expected MathSupSubNode")
    }

    @TestCase
    func supsubShouldProduceSupsubForUnderscoreCaret() {
        // Source: describe("A subscript and superscript parser") / it("should produce supsubs for _^")
        let node = firstNode("x_3^2")

        if (let script: MathSupSubNode <- node) {
            @Expect(script.base.kind, "Symbol")
            @Expect(script.sup.isSome(), true)
            @Expect(script.sub.isSome(), true)
            return
        }
        throw IllegalArgumentException("Expected MathSupSubNode")
    }

    @TestCase
    func supsubShouldProduceTheSameThingRegardlessOfOrder() {
        // Source: describe("A subscript and superscript parser") / it("should produce the same thing regardless of order")
        let caretThenUnderscore = mathMlBodyWithoutTexAnnotation("x^2_3")
        let underscoreThenCaret = mathMlBodyWithoutTexAnnotation("x_3^2")

        @Expect(caretThenUnderscore, underscoreThenCaret)
    }

    @TestCase
    func supsubShouldNotParseDoubleSubscriptsOrSuperscripts() {
        // Source: describe("A subscript and superscript parser") / it("should not parse double subscripts or superscripts")
        @Expect(hasError(parseRoot("x^x^x")), true)
        @Expect(hasError(parseRoot("x_x_x")), true)
        @Expect(hasError(parseRoot("x_x^x_x")), true)
        @Expect(hasError(parseRoot("x_x^x^x")), true)
        @Expect(hasError(parseRoot("x^x_x_x")), true)
        @Expect(hasError(parseRoot("x^x_x^x")), true)
    }

    @TestCase
    func supsubShouldWorkCorrectlyWithGroups() {
        // Source: describe("A subscript and superscript parser") / it("should work correctly with {}s")
        @Expect(hasError(parseRoot("x^{2+3}")), false)
        @Expect(hasError(parseRoot("x_{3-2}")), false)
        @Expect(hasError(parseRoot("x^{2+3}_3")), false)
        @Expect(hasError(parseRoot("x^2_{3-2}")), false)
        @Expect(hasError(parseRoot("x^{2+3}_{3-2}")), false)
        @Expect(hasError(parseRoot("x_{3-2}^{2+3}")), false)
        @Expect(hasError(parseRoot("x_3^{2+3}")), false)
        @Expect(hasError(parseRoot("x_{3-2}^2")), false)
    }

    @TestCase
    func supsubShouldWorkWithNestedSuperSubscripts() {
        // Source: describe("A subscript and superscript parser") / it("should work with nested super/subscripts")
        @Expect(hasError(parseRoot("x^{x^x}")), false)
        @Expect(hasError(parseRoot("x^{x_x}")), false)
        @Expect(hasError(parseRoot("x_{x^x}")), false)
        @Expect(hasError(parseRoot("x_{x_x}")), false)
    }

    @TestCase
    func supsubShouldSkipRelaxInSuperSubscripts() {
        // Source: describe("A subscript and superscript parser") / it("should skip \\relax in super/subscripts")
        let directSup = mathMlBodyWithoutTexAnnotation("x^2")
        let relaxSup = mathMlBodyWithoutTexAnnotation("x^\\relax 2")
        let directSub = mathMlBodyWithoutTexAnnotation("x_2")
        let relaxSub = mathMlBodyWithoutTexAnnotation("x_\\relax 2")

        @Expect(relaxSup, directSup)
        @Expect(relaxSub, directSub)
    }

    @TestCase
    func supsubShouldNotFailIfRelaxIsInAnAtom() {
        // Source: describe("A subscript and superscript parser") / it("should not fail if \\relax is in an atom")
        @Expect(hasError(parseRoot("\\hskip1em\\relax^2")), false)
    }

    @TestCase
    func groupParserShouldNotFail() {
        // Source: describe("A group parser") / it("should not fail")
        @Expect(hasError(parseRoot("{xy}")), false)
    }

    @TestCase
    func groupParserShouldProduceASingleOrd() {
        // Source: describe("A group parser") / it("should produce a single ord")
        let root = parseRoot("{xy}")
        @Expect(root.children.size, 1)
        if (let group: MathGroupNode <- root.children[0]) {
            @Expect(group.children.size, 2)
            return
        }
        throw IllegalArgumentException("Expected MathGroupNode")
    }

    @TestCase
    func fracShouldProduceAFrac() {
        // Source: describe("A frac parser") / it("should produce a frac")
        assertFirstNodeIsFraction("\\frac{x}{y}", true)
    }

    @TestCase
    func fracShouldAcceptUngroupedArguments() {
        // Source: describe("A mathinner parser") / it("should not fail") uses TeX-style "\\frac 1 {...}" argument parsing
        assertFirstNodeIsFraction("\\frac 1 2", false)
    }

    @TestCase
    func functionParserShouldParseNoArgumentFunctions() {
        // Source: describe("A function parser") / it("should parse no argument functions")
        @Expect(hasError(parseRoot("\\div")), false)
    }

    @TestCase
    func functionParserShouldParseOneArgumentFunctions() {
        // Source: describe("A function parser") / it("should parse 1 argument functions")
        @Expect(hasError(parseRoot("\\blue x")), false)
    }

    @TestCase
    func functionParserShouldParseTwoArgumentFunctions() {
        // Source: describe("A function parser") / it("should parse 2 argument functions")
        @Expect(hasError(parseRoot("\\frac 1 2")), false)
    }

    @TestCase
    func functionParserShouldNotParseOneArgumentFunctionsWithNoArguments() {
        // Source: describe("A function parser") / it("should not parse 1 argument functions with no arguments")
        @Expect(hasError(parseRoot("\\blue")), true)
    }

    @TestCase
    func functionParserShouldNotParseTwoArgumentFunctionsWithZeroOrOneArguments() {
        // Source: describe("A function parser") / it("should not parse 2 argument functions with 0 or 1 arguments")
        @Expect(hasError(parseRoot("\\frac")), true)
        @Expect(hasError(parseRoot("\\frac 1")), true)
    }

    @TestCase
    func functionParserShouldNotParseFunctionWithTextRightAfterIt() {
        // Source: describe("A function parser") / it("should not parse a function with text right after it")
        @Expect(hasError(parseRoot("\\redx")), true)
    }

    @TestCase
    func functionParserShouldParseFunctionWithNumberRightAfterIt() {
        // Source: describe("A function parser") / it("should parse a function with a number right after it")
        @Expect(hasError(parseRoot("\\frac12")), false)
    }

    @TestCase
    func functionParserShouldParseSomeFunctionsWithTextRightAfterIt() {
        // Source: describe("A function parser") / it("should parse some functions with text right after it")
        @Expect(hasError(parseRoot("\\;x")), false)
    }

    @TestCase
    func dfracShouldProduceAFrac() {
        // Source: describe("A dfrac parser") / it("should produce a frac")
        assertFirstNodeIsFraction("\\dfrac{x}{y}", true)
    }

    @TestCase
    func tfracShouldProduceAFrac() {
        // Source: describe("A tfrac parser") / it("should produce a frac")
        assertFirstNodeIsFraction("\\tfrac{x}{y}", true)
    }

    @TestCase
    func cfracShouldProduceAFrac() {
        // Source: describe("A cfrac parser") / it("should produce a frac")
        assertFirstNodeIsFraction("\\cfrac{x}{y}", true)
    }

    @TestCase
    func fracParserShouldNotFail() {
        // Source: describe("A frac parser") / it("should not fail")
        @Expect(hasError(parseRoot("\\frac{x}{y}")), false)
    }

    @TestCase
    func fracParserShouldAlsoParseVariantsAndGenfrac() {
        // Source: describe("A frac parser") / it("should also parse cfrac, dfrac, tfrac, and genfrac")
        @Expect(hasError(parseRoot("\\cfrac{x}{y}")), false)
        @Expect(hasError(parseRoot("\\dfrac{x}{y}")), false)
        @Expect(hasError(parseRoot("\\tfrac{x}{y}")), false)
        @Expect(hasError(parseRoot("\\genfrac ( ] {0.06em}{0}{a}{b+c}")), false)
        @Expect(hasError(parseRoot("\\genfrac ( ] {0.8pt}{}{a}{b+c}")), false)
    }

    @TestCase
    func fracParserShouldFailIfGenfracHasLessThanSixArguments() {
        // Source: describe("A frac parser") / it("should fail if genfrac is given less than 6 arguments")
        @Expect(hasError(parseRoot("\\genfrac ( ] {0.06em}{0}{a}")), true)
    }

    @TestCase
    func sizingParserShouldNotFail() {
        // Source: describe("A sizing parser") / it("should not fail")
        @Expect(hasError(parseRoot("\\Huge{x}\\small{x}")), false)
    }

    @TestCase
    func sizingParserShouldProduceASizingNode() {
        // Source: describe("A sizing parser") / it("should produce a sizing node")
        let node = firstNode("\\Huge{x}\\small{x}")
        if (let sizing: MathSizingNode <- node) {
            @Expect(sizing.size, "Huge")
            @Expect(sizing.body.kind, "Group")
            return
        }
        throw IllegalArgumentException("Expected MathSizingNode")
    }

    @TestCase
    func textParserShouldNotFail() {
        // Source: describe("A text parser") / it("should not fail")
        @Expect(hasError(parseRoot("\\text{a b}")), false)
    }

    @TestCase
    func textParserShouldProduceAText() {
        // Source: describe("A text parser") / it("should produce a text")
        let node = firstNode("\\text{a b}")
        if (let text: MathTextNode <- node) {
            @Expect(text.text, "a b")
            return
        }
        throw IllegalArgumentException("Expected MathTextNode")
    }

    @TestCase
    func textParserShouldParseTextWithNoBracesAroundIt() {
        // Source: describe("A text parser") / it("should parse text with no braces around it")
        @Expect(hasError(parseRoot("\\text x")), false)
    }

    @TestCase
    func textParserShouldAcceptMathModeTokensAfterArgument() {
        // Source: describe("A text parser") / it("should accept math mode tokens after its argument")
        @Expect(hasError(parseRoot("\\text{sin}^2")), false)
    }

    @TestCase
    func textParserShouldIgnoreSpaceBeforeTextGroup() {
        // Source: describe("A text parser") / it("should ignore a space before the text group")
        let node = firstNode("\\text {moo}")
        if (let text: MathTextNode <- node) {
            @Expect(text.text, "moo")
            return
        }
        throw IllegalArgumentException("Expected MathTextNode")
    }

    @TestCase
    func textParserShouldParseSpacingFunctions() {
        // Source: describe("A text parser") / it("should parse spacing functions")
        @Expect(hasError(parseRoot("a b\\, \\; \\! \\: \\> ~ \\thinspace \\medspace \\quad \\ ")), false)
        @Expect(hasError(parseRoot("\\enspace \\thickspace \\qquad \\space \\nobreakspace")), false)
    }

    @TestCase
    func textParserShouldHandleVdots() {
        // Source: describe("A text parser") / it("should handle ⋮ and \\vdots")
        @Expect(hasError(parseRoot("\\text{a \\vdots b ⋮ d}")), false)
    }

    @TestCase
    func colorParserShouldNotFail() {
        // Source: describe("A color parser") / it("should not fail")
        @Expect(hasError(parseRoot("\\blue{x}")), false)
    }

    @TestCase
    func colorParserShouldBuildAColorNode() {
        // Source: describe("A color parser") / it("should build a color node")
        let node = firstNode("\\blue{x}")
        if (let color: MathColorNode <- node) {
            @Expect(color.color, "blue")
            @Expect(color.body.kind, "Group")
            return
        }
        throw IllegalArgumentException("Expected MathColorNode")
    }

    @TestCase
    func colorParserShouldParseACustomColor() {
        // Source: describe("A color parser") / it("should parse a custom color")
        @Expect(hasError(parseRoot("\\textcolor{#fA6}{x}")), false)
        @Expect(hasError(parseRoot("\\textcolor{#fA6fA6}{x}")), false)
        @Expect(hasError(parseRoot("\\textcolor{fA6fA6}{x}")), false)
    }

    @TestCase
    func colorParserShouldCorrectlyExtractTheCustomColor() {
        // Source: describe("A color parser") / it("should correctly extract the custom color")
        assertFirstNodeColor("\\textcolor{#fA6}{x}", "#fA6")
        assertFirstNodeColor("\\textcolor{#fA6fA6}{x}", "#fA6fA6")
        assertFirstNodeColor("\\textcolor{fA6fA6}{x}", "#fA6fA6")
    }

    @TestCase
    func colorParserShouldNotParseABadCustomColor() {
        // Source: describe("A color parser") / it("should not parse a bad custom color")
        @Expect(hasError(parseRoot("\\textcolor{bad-color}{x}")), true)
        @Expect(hasError(parseRoot("\\textcolor{#fA6f1}{x}")), true)
        @Expect(hasError(parseRoot("\\textcolor{#gA6}{x}")), true)
    }

    @TestCase
    func colorParserShouldParseNewColorsFromBrandingGuide() {
        // Source: describe("A color parser") / it("should parse new colors from the branding guide")
        @Expect(hasError(parseRoot("\\redA{x}")), false)
    }

    @TestCase
    func alphaHexColorParserShouldCorrectlyExtractAlphaHexColors() {
        // Source: describe("Alpha hex color parser") / it("should correctly extract alpha hex colors")
        assertFirstNodeColor("\\textcolor{#ff000080}{x}", "#ff000080")
        assertFirstNodeColor("\\textcolor{#1234ABCD}{z}", "#1234ABCD")
        assertFirstNodeColor("\\textcolor{#abc8}{w}", "#abc8")
    }

    @TestCase
    func alphaHexColorParserShouldNotParseInvalidAlphaHexColors() {
        // Source: describe("Alpha hex color parser") / it("should not parse invalid alpha hex colors")
        @Expect(hasError(parseRoot("\\textcolor{#ff00008g}{x}")), true)
        @Expect(hasError(parseRoot("\\textcolor{#ff00008}{x}")), true)
        @Expect(hasError(parseRoot("\\textcolor{#ff000080f}{x}")), true)
    }

    @TestCase
    func tieParserShouldParseTiesInMathMode() {
        // Source: describe("A tie parser") / it("should parse ties in math mode")
        @Expect(hasError(parseRoot("a~b")), false)
    }

    @TestCase
    func tieParserShouldParseTiesInTextMode() {
        // Source: describe("A tie parser") / it("should parse ties in text mode")
        @Expect(hasError(parseRoot("\\text{a~ b}")), false)
    }

    @TestCase
    func delimiterSizingParserShouldParseNormalDelimiters() {
        // Source: describe("A delimiter sizing parser") / it("should parse normal delimiters")
        @Expect(hasError(parseRoot("\\bigl |")), false)
        @Expect(hasError(parseRoot("\\Biggr \\langle")), false)
    }

    @TestCase
    func delimiterSizingParserShouldProduceADelimsizing() {
        // Source: describe("A delimiter sizing parser") / it("should produce a delimsizing")
        let node = firstNode("\\bigl |")
        if (let command: MathCommandNode <- node) {
            @Expect(command.name, "bigl")
            return
        }
        throw IllegalArgumentException("Expected MathCommandNode")
    }

    @TestCase
    func overlineParserShouldNotFail() {
        // Source: describe("An overline parser") / it("should not fail")
        @Expect(hasError(parseRoot("\\overline{x}")), false)
    }

    @TestCase
    func overlineParserShouldProduceAnOverline() {
        // Source: describe("An overline parser") / it("should produce an overline")
        let node = firstNode("\\overline{x}")
        if (let command: MathCommandNode <- node) {
            @Expect(command.name, "overline")
            return
        }
        throw IllegalArgumentException("Expected MathCommandNode")
    }

    @TestCase
    func lapParserShouldNotFailOnATextArgument() {
        // Source: describe("An lap parser") / it("should not fail on a text argument")
        @Expect(hasError(parseRoot("\\rlap{\\,/}{=}")), false)
        @Expect(hasError(parseRoot("\\mathrlap{\\,/}{=}")), false)
        @Expect(hasError(parseRoot("{=}\\llap{/\\,}")), false)
        @Expect(hasError(parseRoot("{=}\\mathllap{/\\,}")), false)
        @Expect(hasError(parseRoot("\\sum_{\\clap{ABCDEFG}}")), false)
        @Expect(hasError(parseRoot("\\sum_{\\mathclap{ABCDEFG}}")), false)
    }

    @TestCase
    func sqrtShouldProduceSqrts() {
        // Source: describe("A sqrt parser") / it("should produce sqrts")
        let node = firstNode("\\sqrt{x}")

        if (let sqrt: MathSqrtNode <- node) {
            @Expect(sqrt.radicand.kind, "Group")
            return
        }
        throw IllegalArgumentException("Expected MathSqrtNode")
    }
}

func mathMlBodyWithoutTexAnnotation(tex: String): String {
    let output = MathRenderer().renderMathMl(tex).output
    let marker = "<annotation encoding=\"application/x-tex\">"
    let start = output.indexOf(marker)
    if (let Some(startIndex) <- start) {
        return output[0..startIndex]
    }
    return output
}
