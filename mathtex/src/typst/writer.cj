package mathtex.typst

import mathtex.ast.{
    MathColorNode,
    MathCommandNode,
    MathDelimitedNode,
    MathEnvironmentNode,
    MathErrorNode,
    MathExpression,
    MathFractionNode,
    MathGroupNode,
    MathLimitsNode,
    MathNode,
    MathSequenceNode,
    MathSizingNode,
    MathSqrtNode,
    MathSupSubNode,
    MathSymbolNode,
    MathTextNode
}

public class MathTypstWriter {
    public init() {}

    public func writeInline(expression: MathExpression): String {
        let body = writeMath(expression.root).trimAscii()
        if (body.isEmpty()) {
            return ""
        }
        return "$" + body + "$"
    }

    public func writeBlock(expression: MathExpression): String {
        let body = writeMath(expression.root).trimAscii()
        if (body.isEmpty()) {
            return ""
        }
        return "$\n" + body + "\n$"
    }

    public func writeMath(expression: MathExpression): String {
        return writeMath(expression.root)
    }

    public func writeMath(node: MathNode): String {
        if (let error: MathErrorNode <- node) {
            return escapeText(error.literal)
        }
        if (let sequence: MathSequenceNode <- node) {
            return writeSequence(sequence.children)
        }
        if (let group: MathGroupNode <- node) {
            if (group.children.size == 0) {
                return ""
            }
            return "(" + writeSequence(group.children) + ")"
        }
        if (let symbol: MathSymbolNode <- node) {
            return writeSymbol(symbol)
        }
        if (let text: MathTextNode <- node) {
            return "\"" + escapeText(text.text) + "\""
        }
        if (let delimited: MathDelimitedNode <- node) {
            return writeDelimiter(delimited.left) + writeArgument(delimited.body) + writeDelimiter(delimited.right)
        }
        if (let environment: MathEnvironmentNode <- node) {
            return writeEnvironment(environment)
        }
        if (let frac: MathFractionNode <- node) {
            return "frac(" + writeArgument(frac.numerator) + ", " + writeArgument(frac.denominator) + ")"
        }
        if (let sqrt: MathSqrtNode <- node) {
            if (let Some(index) <- sqrt.index) {
                return "root(" + writeArgument(index) + ", " + writeArgument(sqrt.radicand) + ")"
            }
            return "sqrt(" + writeArgument(sqrt.radicand) + ")"
        }
        if (let script: MathSupSubNode <- node) {
            return writeScripts(script)
        }
        if (let limits: MathLimitsNode <- node) {
            return writeMath(limits.base)
        }
        if (let color: MathColorNode <- node) {
            return "color(\"" + escapeText(color.color) + "\", " + writeArgument(color.body) + ")"
        }
        if (let sizing: MathSizingNode <- node) {
            return writeArgument(sizing.body)
        }
        if (let command: MathCommandNode <- node) {
            return writeCommand(command)
        }
        return writeSequence(node.children)
    }

    private func writeDelimiter(node: MathNode): String {
        if (let symbol: MathSymbolNode <- node) {
            if (symbol.value == ".") {
                return ""
            }
            return writeSymbol(symbol)
        }
        return node.literal
    }

    private func writeEnvironment(environment: MathEnvironmentNode): String {
        if (isMatrixEnvironment(environment.name)) {
            let delimiter = matrixDelimiter(environment.name)
            let rows = writeEnvironmentRows(environment, ", ", "; ")
            if (!delimiter.isEmpty()) {
                return "mat(delim: \"" + delimiter + "\", " + rows + ")"
            }
            return "mat(" + rows + ")"
        }
        if (environment.name == "cases" || environment.name == "rcases") {
            return "cases(" + writeEnvironmentRows(environment, ", ", "; ") + ")"
        }
        if (isAlignedEnvironment(environment.name)) {
            return "align(" + writeEnvironmentRows(environment, " & ", "; ") + ")"
        }
        return writeEnvironmentRows(environment, " ", "; ")
    }

    private func writeEnvironmentRows(environment: MathEnvironmentNode, cellSeparator: String, rowSeparator: String): String {
        let out = StringBuilder()
        var firstRow = true
        for (row in environment.rows) {
            if (!firstRow) {
                out.append(rowSeparator)
            }
            firstRow = false
            var firstCell = true
            for (cell in row) {
                if (!firstCell) {
                    out.append(cellSeparator)
                }
                firstCell = false
                out.append(writeArgument(cell))
            }
        }
        return out.toString()
    }

    private func isMatrixEnvironment(name: String): Bool {
        return name == "matrix" || name == "matrix*" || name == "pmatrix" || name == "pmatrix*" ||
            name == "bmatrix" || name == "bmatrix*" || name == "Bmatrix" || name == "Bmatrix*" ||
            name == "vmatrix" || name == "vmatrix*" || name == "Vmatrix" || name == "Vmatrix*" ||
            name == "smallmatrix" || name == "array" || name == "subarray"
    }

    private func isAlignedEnvironment(name: String): Bool {
        return name == "aligned" || name == "alignedat" || name == "gathered" || name == "split" ||
            name == "align" || name == "align*" || name == "alignat" || name == "alignat*" ||
            name == "gather" || name == "gather*" || name == "equation"
    }

    private func matrixDelimiter(name: String): String {
        match (name) {
            case "pmatrix" => return "("
            case "pmatrix*" => return "("
            case "bmatrix" => return "["
            case "bmatrix*" => return "["
            case "Bmatrix" => return "{"
            case "Bmatrix*" => return "{"
            case "vmatrix" => return "|"
            case "vmatrix*" => return "|"
            case "Vmatrix" => return "∥"
            case "Vmatrix*" => return "∥"
            case _ => return ""
        }
    }

    private func writeSequence(children: Array<MathNode>): String {
        let out = StringBuilder()
        var previous = ""
        for (child in children) {
            let current = writeMath(child)
            if (current.isEmpty()) {
                continue
            }
            if (!previous.isEmpty() && needsSeparator(previous, current)) {
                out.append(" ")
            }
            out.append(current)
            previous = current
        }
        return out.toString()
    }

    private func writeArgument(node: MathNode): String {
        if (let group: MathGroupNode <- node) {
            return writeSequence(group.children)
        }
        if (let sequence: MathSequenceNode <- node) {
            return writeSequence(sequence.children)
        }
        return writeMath(node)
    }

    private func writeScripts(script: MathSupSubNode): String {
        let out = StringBuilder()
        let base = writeMath(script.base)
        if (base.isEmpty()) {
            out.append("{}")
        } else {
            out.append(base)
        }
        if (let Some(sub) <- script.sub) {
            out.append("_")
            out.append(writeScriptOperand(sub))
        }
        if (let Some(sup) <- script.sup) {
            out.append("^")
            out.append(writeScriptOperand(sup))
        }
        return out.toString()
    }

    private func writeScriptOperand(node: MathNode): String {
        let body = writeArgument(node)
        if (body.size <= 1 || isBareTypstAtom(body)) {
            return body
        }
        return "(" + body + ")"
    }

    private func writeCommand(command: MathCommandNode): String {
        match (command.name) {
            case "spacing" => return " "
            case "overline" => return "overline(" + writeFirstArgument(command) + ")"
            case "underline" => return "underline(" + writeFirstArgument(command) + ")"
            case "bigl" => return writeFirstArgument(command)
            case "Biggr" => return writeFirstArgument(command)
            case "llap" => return writeFirstArgument(command)
            case "rlap" => return writeFirstArgument(command)
            case "clap" => return writeFirstArgument(command)
            case "mathllap" => return writeFirstArgument(command)
            case "mathrlap" => return writeFirstArgument(command)
            case "mathclap" => return writeFirstArgument(command)
            case _ => return writeSequence(command.children)
        }
    }

    private func writeFirstArgument(command: MathCommandNode): String {
        if (command.children.size == 0) {
            return ""
        }
        return writeArgument(command.children[0])
    }

    private func writeSymbol(symbol: MathSymbolNode): String {
        if (symbol.literal.startsWith("\\")) {
            let command = symbol.literal[1..symbol.literal.size]
            let mapped = mapCommand(command)
            if (!mapped.isEmpty()) {
                return mapped
            }
        }
        let mappedValue = mapSymbolValue(symbol.value)
        if (!mappedValue.isEmpty()) {
            return mappedValue
        }
        return symbol.value
    }

    private func mapCommand(command: String): String {
        match (command) {
            case "alpha" => return "alpha"
            case "beta" => return "beta"
            case "gamma" => return "gamma"
            case "delta" => return "delta"
            case "epsilon" => return "epsilon"
            case "varepsilon" => return "epsilon.alt"
            case "theta" => return "theta"
            case "lambda" => return "lambda"
            case "mu" => return "mu"
            case "sigma" => return "sigma"
            case "phi" => return "phi"
            case "varphi" => return "phi.alt"
            case "omega" => return "omega"
            case "pi" => return "pi"
            case "psi" => return "psi"
            case "infty" => return "infinity"
            case "partial" => return "diff"
            case "nabla" => return "nabla"
            case "forall" => return "forall"
            case "exists" => return "exists"
            case "emptyset" => return "emptyset"
            case "sum" => return "sum"
            case "prod" => return "product"
            case "int" => return "integral"
            case "lim" => return "lim"
            case "limsup" => return "lim sup"
            case "liminf" => return "lim inf"
            case "sin" => return "sin"
            case "cos" => return "cos"
            case "tan" => return "tan"
            case "log" => return "log"
            case "ln" => return "ln"
            case "cdot" => return "dot"
            case "times" => return "times"
            case "pm" => return "+-"
            case "mp" => return "-+"
            case "div" => return "/"
            case "leq" => return "<="
            case "le" => return "<="
            case "geq" => return ">="
            case "ge" => return ">="
            case "neq" => return "!="
            case "ne" => return "!="
            case "cong" => return "tilde.equiv"
            case "equiv" => return "equiv"
            case "approx" => return "approx"
            case "sim" => return "tilde"
            case "propto" => return "prop"
            case "in" => return "in"
            case "notin" => return "in.not"
            case "subset" => return "subset"
            case "subseteq" => return "subset.eq"
            case "supset" => return "supset"
            case "supseteq" => return "supset.eq"
            case "to" => return "->"
            case "rightarrow" => return "->"
            case "leftarrow" => return "<-"
            case "Rightarrow" => return "=>"
            case "Leftarrow" => return "<="
            case "leftrightarrow" => return "<->"
            case "Leftrightarrow" => return "<=>"
            case "iff" => return "<=>"
            case "implies" => return "=>"
            case "impliedby" => return "<="
            case "langle" => return "<"
            case "rangle" => return ">"
            case "vdots" => return "dots.v"
            case _ => return ""
        }
    }

    private func mapSymbolValue(value: String): String {
        match (value) {
            case "α" => return "alpha"
            case "β" => return "beta"
            case "γ" => return "gamma"
            case "δ" => return "delta"
            case "ϵ" => return "epsilon"
            case "ε" => return "epsilon.alt"
            case "θ" => return "theta"
            case "λ" => return "lambda"
            case "μ" => return "mu"
            case "σ" => return "sigma"
            case "ϕ" => return "phi"
            case "φ" => return "phi.alt"
            case "ω" => return "omega"
            case "π" => return "pi"
            case "ψ" => return "psi"
            case "∞" => return "infinity"
            case "∂" => return "diff"
            case "∇" => return "nabla"
            case "∀" => return "forall"
            case "∃" => return "exists"
            case "∅" => return "emptyset"
            case "∑" => return "sum"
            case "∏" => return "product"
            case "∫" => return "integral"
            case "⋅" => return "dot"
            case "×" => return "times"
            case "±" => return "+-"
            case "∓" => return "-+"
            case "÷" => return "/"
            case "≤" => return "<="
            case "≥" => return ">="
            case "≠" => return "!="
            case "≅" => return "tilde.equiv"
            case "≡" => return "equiv"
            case "≈" => return "approx"
            case "∼" => return "tilde"
            case "∝" => return "prop"
            case "∈" => return "in"
            case "∉" => return "in.not"
            case "⊂" => return "subset"
            case "⊆" => return "subset.eq"
            case "⊃" => return "supset"
            case "⊇" => return "supset.eq"
            case "→" => return "->"
            case "←" => return "<-"
            case "⇒" => return "=>"
            case "⇐" => return "<="
            case "↔" => return "<->"
            case "⇔" => return "<=>"
            case "⟨" => return "<"
            case "⟩" => return ">"
            case "∥" => return "∥"
            case "⋮" => return "dots.v"
            case "~" => return " "
            case _ => return ""
        }
    }

    private func needsSeparator(previous: String, current: String): Bool {
        if (previous.endsWith(" ") || current.startsWith(" ")) {
            return false
        }
        if (current == ")" || current == "," || current == ";" || current == "]") {
            return false
        }
        if (previous == "(" || previous == "[" || previous == "{" || previous == "") {
            return false
        }
        if (current.startsWith("_") || current.startsWith("^")) {
            return false
        }
        if (previous.endsWith("_") || previous.endsWith("^")) {
            return false
        }
        if (isAllDigits(previous) && isAllDigits(current)) {
            return false
        }
        return true
    }

    private func isBareTypstAtom(value: String): Bool {
        if (value.isEmpty()) {
            return false
        }
        for (ch in value) {
            if (!((ch >= b'0' && ch <= b'9') || (ch >= b'a' && ch <= b'z') || (ch >= b'A' && ch <= b'Z') || ch == b'.')) {
                return false
            }
        }
        return true
    }

    private func isAllDigits(value: String): Bool {
        if (value.isEmpty()) {
            return false
        }
        for (ch in value) {
            if (ch < b'0' || ch > b'9') {
                return false
            }
        }
        return true
    }

    private func escapeText(value: String): String {
        return value.replace("\\", "\\\\").replace("\"", "\\\"")
    }
}
