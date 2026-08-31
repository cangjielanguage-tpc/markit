package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*
import mathtex.{MathRenderOptions, MathRenderer, MathTex}
import mathtex.ast.{
    MathColorNode,
    MathEnvironmentNode,
    MathErrorNode,
    MathFractionNode,
    MathNode,
    MathSequenceNode,
    MathSymbolNode
}

func parseRoot(tex: String): MathSequenceNode {
    let root = MathTex().parse(tex).expression.root
    if (let sequence: MathSequenceNode <- root) {
        return sequence
    }
    throw IllegalArgumentException("Expected MathSequenceNode")
}

func firstNode(tex: String): MathNode {
    let root = parseRoot(tex)
    if (root.children.size == 0) {
        throw IllegalArgumentException("Expected at least one parsed node")
    }
    return root.children[0]
}

func assertAllSymbolsHaveFamily(tex: String, family: String): Unit {
    let root = parseRoot(tex)
    for (node in root.children) {
        if (let symbol: MathSymbolNode <- node) {
            @Expect(symbol.family, family)
        } else {
            throw IllegalArgumentException("Expected MathSymbolNode")
        }
    }
}

func assertFirstNodeIsFraction(tex: String, grouped: Bool): Unit {
    let node = firstNode(tex)
    if (let frac: MathFractionNode <- node) {
        let expected = if (grouped) { "Group" } else { "Symbol" }
        @Expect(frac.numerator.kind, expected)
        @Expect(frac.denominator.kind, expected)
        return
    }
    throw IllegalArgumentException("Expected MathFractionNode")
}

func assertFirstNodeColor(tex: String, expectedColor: String): Unit {
    let node = firstNode(tex)
    if (let color: MathColorNode <- node) {
        @Expect(color.color, expectedColor)
        return
    }
    throw IllegalArgumentException("Expected MathColorNode")
}

func assertFirstNodeEnvironmentShape(tex: String, expectedName: String, expectedRows: Int64, expectedFirstRowCells: Int64): Unit {
    let node = firstNode(tex)
    if (let environment: MathEnvironmentNode <- node) {
        @Expect(environment.name, expectedName)
        @Expect(environment.rows.size, expectedRows)
        if (environment.rows.size > 0) {
            @Expect(environment.rows[0].size, expectedFirstRowCells)
        }
        return
    }
    throw IllegalArgumentException("Expected MathEnvironmentNode")
}

func assertFirstNodeEnvironmentPreamble(tex: String, expectedAlignments: Array<String>, expectedSeparators: Array<Int64>): Unit {
    let node = firstNode(tex)
    if (let environment: MathEnvironmentNode <- node) {
        @Expect(environment.columnAlignments.size, expectedAlignments.size)
        for (i in 0..expectedAlignments.size) {
            @Expect(environment.columnAlignments[i], expectedAlignments[i])
        }
        @Expect(environment.columnSeparatorCounts.size, expectedSeparators.size)
        for (i in 0..expectedSeparators.size) {
            @Expect(environment.columnSeparatorCounts[i], expectedSeparators[i])
        }
        return
    }
    throw IllegalArgumentException("Expected MathEnvironmentNode")
}

func assertParsesAll(expressions: Array<String>): Unit {
    for (expression in expressions) {
        let root = parseRoot(expression)
        if (hasError(root)) {
            throw IllegalArgumentException("Expected migrated KaTeX expression to parse: ${expression}")
        }
    }
}

func assertRendersAll(expressions: Array<String>): Unit {
    let renderer = MathRenderer()
    for (expression in expressions) {
        let result = renderer.renderHtmlAndMathMl(expression)
        if (!result.supported) {
            throw IllegalArgumentException("Expected migrated KaTeX expression to render: ${expression}")
        }
    }
}

func assertHtmlContains(tex: String, expected: String, displayMode!: Bool = false): Unit {
    let renderer = MathRenderer()
    let result = renderer.renderHtmlAndMathMl(tex, options: MathRenderOptions(displayMode: displayMode))
    if (!result.output.contains(expected)) {
        throw IllegalArgumentException("Expected HTML for `${tex}` to contain `${expected}`, actual `${result.output}`")
    }
}

func assertMathMlContains(tex: String, expected: String, displayMode!: Bool = false): Unit {
    let renderer = MathRenderer()
    let result = renderer.renderMathMl(tex, options: MathRenderOptions(displayMode: displayMode))
    if (!result.output.contains(expected)) {
        throw IllegalArgumentException("Expected MathML for `${tex}` to contain `${expected}`, actual `${result.output}`")
    }
}

func assertTypstEquals(tex: String, expected: String, displayMode!: Bool = false): Unit {
    let renderer = MathRenderer()
    let result = renderer.renderTypst(tex, options: MathRenderOptions(displayMode: displayMode))
    @Expect(result.output, expected)
}

func assertErrorsAll(expressions: Array<String>): Unit {
    for (expression in expressions) {
        let root = parseRoot(expression)
        if (!hasError(root)) {
            throw IllegalArgumentException("Expected migrated KaTeX expression to fail: ${expression}")
        }
    }
}

func hasError(node: MathNode): Bool {
    if (let _: MathErrorNode <- node) {
        return true
    }
    for (child in node.children) {
        if (hasError(child)) {
            return true
        }
    }
    return false
}
