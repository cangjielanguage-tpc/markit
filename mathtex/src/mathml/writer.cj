package mathtex.mathml

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
import mathtex.util.HtmlEscaper

public class MathMlWriter {
    private var displayMode: Bool = false
    private var currentStyle: String = "text"

    public init() {}

    public func write(expression: MathExpression): String {
        this.displayMode = expression.displayMode
        this.currentStyle = if (expression.displayMode) { "display" } else { "text" }
        let out = StringBuilder(expression.source.size + 128)
        out.append("<math xmlns=\"http://www.w3.org/1998/Math/MathML\"")
        if (expression.displayMode) {
            out.append(" display=\"block\"")
        }
        out.append(">")
        out.append("<semantics>")
        writeNode(expression.root, out)
        out.append("<annotation encoding=\"application/x-tex\">")
        out.append(HtmlEscaper.escapeText(expression.source))
        out.append("</annotation></semantics>")
        out.append("</math>")
        return out.toString()
    }

    private func writeNode(node: MathNode, out: StringBuilder): Unit {
        if (let error: MathErrorNode <- node) {
            out.append("<merror><mtext>")
            out.append(HtmlEscaper.escapeText(error.literal))
            out.append("</mtext></merror>")
            return
        }
        if (let sequence: MathSequenceNode <- node) {
            writeRow(sequence.children, out)
            return
        }
        if (let group: MathGroupNode <- node) {
            writeRow(group.children, out)
            return
        }
        if (let symbol: MathSymbolNode <- node) {
            writeSymbol(symbol, out)
            return
        }
        if (let text: MathTextNode <- node) {
            out.append("<mtext>")
            out.append(HtmlEscaper.escapeText(text.text))
            out.append("</mtext>")
            return
        }
        if (let delimited: MathDelimitedNode <- node) {
            out.append("<mrow>")
            writeFence(delimited.left, out)
            writeNode(delimited.body, out)
            writeFence(delimited.right, out)
            out.append("</mrow>")
            return
        }
        if (let environment: MathEnvironmentNode <- node) {
            let left = environmentLeftDelimiter(environment.name)
            let right = environmentRightDelimiter(environment.name)
            let hasDelimiter = !left.isEmpty() || !right.isEmpty()
            if (hasDelimiter) {
                out.append("<mrow>")
                writeFenceText(left, out)
            }
            out.append("<mtable")
            let columnAlign = environmentColumnAlign(environment)
            if (!columnAlign.isEmpty()) {
                out.append(" columnalign=\"")
                out.append(HtmlEscaper.escapeAttribute(columnAlign))
                out.append("\"")
            }
            out.append(">")
            for (row in environment.rows) {
                out.append("<mtr>")
                for (cell in row) {
                    out.append("<mtd>")
                    writeNode(cell, out)
                    out.append("</mtd>")
                }
                out.append("</mtr>")
            }
            out.append("</mtable>")
            if (hasDelimiter) {
                writeFenceText(right, out)
                out.append("</mrow>")
            }
            return
        }
        if (let color: MathColorNode <- node) {
            out.append("<mstyle mathcolor=\"")
            out.append(HtmlEscaper.escapeAttribute(color.color))
            out.append("\">")
            writeNode(color.body, out)
            out.append("</mstyle>")
            return
        }
        if (let sizing: MathSizingNode <- node) {
            out.append("<mstyle mathsize=\"")
            out.append(HtmlEscaper.escapeAttribute(mathSizeValue(sizing.size)))
            out.append("\">")
            let previousStyle = currentStyle
            if (isMathStyle(sizing.size)) {
                currentStyle = sizing.size
            }
            writeNode(sizing.body, out)
            currentStyle = previousStyle
            out.append("</mstyle>")
            return
        }
        if (let command: MathCommandNode <- node) {
            writeCommand(command, out)
            return
        }
        if (let frac: MathFractionNode <- node) {
            out.append("<mfrac>")
            writeNode(frac.numerator, out)
            writeNode(frac.denominator, out)
            out.append("</mfrac>")
            return
        }
        if (let sqrt: MathSqrtNode <- node) {
            if (let Some(index) <- sqrt.index) {
                out.append("<mroot>")
                writeNode(sqrt.radicand, out)
                writeNode(index, out)
                out.append("</mroot>")
                return
            }
            out.append("<msqrt>")
            writeNode(sqrt.radicand, out)
            out.append("</msqrt>")
            return
        }
        if (let script: MathSupSubNode <- node) {
            if (shouldUseOperatorLimits(script)) {
                if (script.sup.isSome() && script.sub.isSome()) {
                    out.append("<munderover>")
                    writeNode(script.base, out)
                    writeNode(script.sub.getOrThrow(), out)
                    writeNode(script.sup.getOrThrow(), out)
                    out.append("</munderover>")
                    return
                }
                if (let Some(sup) <- script.sup) {
                    out.append("<mover>")
                    writeNode(script.base, out)
                    writeNode(sup, out)
                    out.append("</mover>")
                    return
                }
                if (let Some(sub) <- script.sub) {
                    out.append("<munder>")
                    writeNode(script.base, out)
                    writeNode(sub, out)
                    out.append("</munder>")
                    return
                }
            }
            if (script.sup.isSome() && script.sub.isSome()) {
                out.append("<msubsup>")
                writeNode(script.base, out)
                writeNode(script.sub.getOrThrow(), out)
                writeNode(script.sup.getOrThrow(), out)
                out.append("</msubsup>")
                return
            }
            if (let Some(sup) <- script.sup) {
                out.append("<msup>")
                writeNode(script.base, out)
                writeNode(sup, out)
                out.append("</msup>")
                return
            }
            if (let Some(sub) <- script.sub) {
                out.append("<msub>")
                writeNode(script.base, out)
                writeNode(sub, out)
                out.append("</msub>")
                return
            }
        }
        if (let limits: MathLimitsNode <- node) {
            writeNode(limits.base, out)
            return
        }
        writeRow(node.children, out)
    }

    private func writeFence(node: MathNode, out: StringBuilder): Unit {
        if (let symbol: MathSymbolNode <- node) {
            if (symbol.value == ".") {
                return
            }
            out.append("<mo fence=\"true\">")
            out.append(HtmlEscaper.escapeText(symbol.value))
            out.append("</mo>")
            return
        }
        out.append("<mo fence=\"true\">")
        out.append(HtmlEscaper.escapeText(node.literal))
        out.append("</mo>")
    }

    private func writeFenceText(value: String, out: StringBuilder): Unit {
        if (value.isEmpty()) {
            return
        }
        out.append("<mo fence=\"true\">")
        out.append(HtmlEscaper.escapeText(value))
        out.append("</mo>")
    }

    private func environmentColumnAlign(environment: MathEnvironmentNode): String {
        if (environment.columnAlignments.size == 0) {
            return ""
        }
        let out = StringBuilder()
        var first = true
        for (alignment in environment.columnAlignments) {
            if (!first) {
                out.append(" ")
            }
            first = false
            match (alignment) {
                case "l" => out.append("left")
                case "r" => out.append("right")
                case _ => out.append("center")
            }
        }
        return out.toString()
    }

    private func writeCommand(command: MathCommandNode, out: StringBuilder): Unit {
        let variant = mathVariant(command.name)
        if (!variant.isEmpty()) {
            out.append("<mstyle mathvariant=\"")
            out.append(HtmlEscaper.escapeAttribute(variant))
            out.append("\">")
            writeRow(command.children, out)
            out.append("</mstyle>")
            return
        }
        if (command.name == "spacing") {
            out.append("<mspace width=\"0.2222em\"></mspace>")
            return
        }
        if (command.name == "newline") {
            out.append("<mspace linebreak=\"newline\"></mspace>")
            return
        }
        if (isXArrowCommand(command.name) && command.children.size > 0) {
            writeXArrow(command, out)
            return
        }
        if (isOverAccentCommand(command.name) && command.children.size > 0) {
            out.append("<mover accent=\"true\">")
            writeNode(command.children[0], out)
            out.append("<mo stretchy=\"true\">")
            out.append(HtmlEscaper.escapeText(overAccentGlyph(command.name)))
            out.append("</mo></mover>")
            return
        }
        if (isUnderAccentCommand(command.name) && command.children.size > 0) {
            out.append("<munder accentunder=\"true\">")
            writeNode(command.children[0], out)
            out.append("<mo stretchy=\"true\">")
            out.append(HtmlEscaper.escapeText(underAccentGlyph(command.name)))
            out.append("</mo></munder>")
            return
        }
        if (isSimpleAccentCommand(command.name) && command.children.size > 0) {
            out.append("<mover accent=\"true\">")
            writeNode(command.children[0], out)
            out.append("<mo stretchy=\"false\">")
            out.append(HtmlEscaper.escapeText(simpleAccentGlyph(command.name)))
            out.append("</mo></mover>")
            return
        }
        if (command.name == "boxed" && command.children.size > 0) {
            out.append("<menclose notation=\"box\">")
            writeNode(command.children[0], out)
            out.append("</menclose>")
            return
        }
        if (isCancelCommand(command.name) && command.children.size > 0) {
            out.append("<menclose notation=\"")
            out.append(HtmlEscaper.escapeAttribute(cancelNotation(command.name)))
            out.append("\">")
            writeNode(command.children[0], out)
            out.append("</menclose>")
            return
        }
        if (command.name == "sout" && command.children.size > 0) {
            out.append("<menclose notation=\"horizontalstrike\">")
            writeNode(command.children[0], out)
            out.append("</menclose>")
            return
        }
        if ((command.name == "colorbox" || command.name == "fcolorbox") && command.children.size > 0) {
            out.append("<menclose notation=\"box\">")
            writeNode(command.children[command.children.size - 1], out)
            out.append("</menclose>")
            return
        }
        writeRow(command.children, out)
    }

    private func mathVariant(name: String): String {
        match (name) {
            case "mathrm" => return "normal"
            case "mathnormal" => return "normal"
            case "mathbf" => return "bold"
            case "boldsymbol" => return "bold"
            case "textbf" => return "bold"
            case "mathit" => return "italic"
            case "textit" => return "italic"
            case "emph" => return "italic"
            case "mathbb" => return "double-struck"
            case "mathcal" => return "script"
            case "mathfrak" => return "fraktur"
            case "mathsf" => return "sans-serif"
            case "textsf" => return "sans-serif"
            case "mathtt" => return "monospace"
            case "texttt" => return "monospace"
            case _ => return ""
        }
    }

    private func mathSizeValue(size: String): String {
        match (size) {
            case "tiny" => return "0.5em"
            case "scriptsize" => return "0.7em"
            case "footnotesize" => return "0.8em"
            case "small" => return "0.9em"
            case "normalsize" => return "1em"
            case "large" => return "1.2em"
            case "Large" => return "1.44em"
            case "LARGE" => return "1.73em"
            case "huge" => return "2.07em"
            case "Huge" => return "2.49em"
            case _ => return "1em"
        }
    }

    private func isOverAccentCommand(name: String): Bool {
        return name == "overline" || name == "widehat" || name == "widecheck" || name == "widetilde" ||
            name == "overrightarrow" || name == "overleftarrow" || name == "overleftrightarrow" ||
            name == "Overrightarrow" || name == "overgroup" || name == "overlinesegment" ||
            name == "overleftharpoon" || name == "overrightharpoon" ||
            name == "overbrace" || name == "overbracket"
    }

    private func isUnderAccentCommand(name: String): Bool {
        return name == "underline" || name == "underbar" || name == "underrightarrow" ||
            name == "underleftarrow" || name == "underleftrightarrow" || name == "undergroup" ||
            name == "underlinesegment" || name == "utilde" || name == "underbrace" || name == "underbracket"
    }

    private func isXArrowCommand(name: String): Bool {
        return name == "xleftarrow" || name == "xrightarrow" || name == "xLeftarrow" || name == "xRightarrow" ||
            name == "xleftrightarrow" || name == "xLeftrightarrow" || name == "xhookleftarrow" ||
            name == "xhookrightarrow" || name == "xmapsto" || name == "xrightharpoondown" ||
            name == "xrightharpoonup" || name == "xleftharpoondown" || name == "xleftharpoonup" ||
            name == "xrightleftharpoons" || name == "xleftrightharpoons" || name == "xlongequal" ||
            name == "xtwoheadrightarrow" || name == "xtwoheadleftarrow" || name == "xtofrom" ||
            name == "xrightleftarrows" || name == "xrightequilibrium" || name == "xleftequilibrium"
    }

    private func isSimpleAccentCommand(name: String): Bool {
        return name == "hat" || name == "bar" || name == "vec" || name == "tilde" || name == "dot" ||
            name == "ddot" || name == "acute" || name == "grave" || name == "breve" || name == "check"
    }

    private func isCancelCommand(name: String): Bool {
        return name == "cancel" || name == "bcancel" || name == "xcancel"
    }

    private func overAccentGlyph(name: String): String {
        match (name) {
            case "widehat" => return "^"
            case "widecheck" => return "ˇ"
            case "widetilde" => return "~"
            case "overrightarrow" => return "→"
            case "overleftarrow" => return "←"
            case "overleftrightarrow" => return "↔"
            case "Overrightarrow" => return "⇒"
            case "overgroup" => return "⏠"
            case "overlinesegment" => return "⏐"
            case "overleftharpoon" => return "↼"
            case "overrightharpoon" => return "⇀"
            case "overbrace" => return "⏞"
            case "overbracket" => return "⎴"
            case _ => return "¯"
        }
    }

    private func underAccentGlyph(name: String): String {
        match (name) {
            case "underrightarrow" => return "→"
            case "underleftarrow" => return "←"
            case "underleftrightarrow" => return "↔"
            case "undergroup" => return "⏡"
            case "underlinesegment" => return "⏐"
            case "utilde" => return "~"
            case "underbrace" => return "⏟"
            case "underbracket" => return "⎵"
            case _ => return "_"
        }
    }

    private func xArrowGlyph(name: String): String {
        match (name) {
            case "xleftarrow" => return "←"
            case "xLeftarrow" => return "⇐"
            case "xRightarrow" => return "⇒"
            case "xleftrightarrow" => return "↔"
            case "xLeftrightarrow" => return "⇔"
            case "xhookleftarrow" => return "↩"
            case "xhookrightarrow" => return "↪"
            case "xmapsto" => return "↦"
            case "xrightharpoondown" => return "⇁"
            case "xrightharpoonup" => return "⇀"
            case "xleftharpoondown" => return "↽"
            case "xleftharpoonup" => return "↼"
            case "xrightleftharpoons" => return "⇌"
            case "xleftrightharpoons" => return "⇋"
            case "xlongequal" => return "="
            case "xtwoheadrightarrow" => return "↠"
            case "xtwoheadleftarrow" => return "↞"
            case "xtofrom" => return "⇄"
            case "xrightleftarrows" => return "⇄"
            case "xrightequilibrium" => return "⇌"
            case "xleftequilibrium" => return "⇋"
            case _ => return "→"
        }
    }

    private func simpleAccentGlyph(name: String): String {
        match (name) {
            case "hat" => return "^"
            case "bar" => return "ˉ"
            case "vec" => return "→"
            case "tilde" => return "~"
            case "dot" => return "˙"
            case "ddot" => return "¨"
            case "acute" => return "´"
            case "grave" => return "`"
            case "breve" => return "˘"
            case "check" => return "ˇ"
            case _ => return ""
        }
    }

    private func cancelNotation(name: String): String {
        match (name) {
            case "bcancel" => return "downdiagonalstrike"
            case "xcancel" => return "updiagonalstrike downdiagonalstrike"
            case _ => return "updiagonalstrike"
        }
    }

    private func writeRow(children: Array<MathNode>, out: StringBuilder): Unit {
        out.append("<mrow>")
        for (child in children) {
            writeNode(child, out)
        }
        out.append("</mrow>")
    }

    private func writeXArrow(command: MathCommandNode, out: StringBuilder): Unit {
        if (command.children.size > 1) {
            out.append("<munderover>")
            writeXArrowOperator(command.name, out)
            out.append("<mpadded width=\"+0.6em\" lspace=\"0.3em\">")
            writeNode(command.children[1], out)
            out.append("</mpadded><mpadded width=\"+0.6em\" lspace=\"0.3em\">")
            writeNode(command.children[0], out)
            out.append("</mpadded></munderover>")
            return
        }
        out.append("<mover>")
        writeXArrowOperator(command.name, out)
        out.append("<mpadded width=\"+0.6em\" lspace=\"0.3em\">")
        writeNode(command.children[0], out)
        out.append("</mpadded></mover>")
    }

    private func writeXArrowOperator(name: String, out: StringBuilder): Unit {
        out.append("<mo stretchy=\"true\" minsize=\"")
        out.append(if (name == "xlongequal") { "0.888em" } else { "3.0em" })
        out.append("\">")
        out.append(HtmlEscaper.escapeText(xArrowGlyph(name)))
        out.append("</mo>")
    }

    private func isOperatorScript(script: MathSupSubNode): Bool {
        if (let limits: MathLimitsNode <- script.base) {
            if (let symbol: MathSymbolNode <- limits.base) {
                return symbol.family == "op"
            }
            return false
        }
        if (let symbol: MathSymbolNode <- script.base) {
            return symbol.family == "op"
        }
        return false
    }

    private func isLimitsOperatorScript(script: MathSupSubNode): Bool {
        if (let limits: MathLimitsNode <- script.base) {
            if (let symbol: MathSymbolNode <- limits.base) {
                return symbol.family == "op" && isDefaultLimitsOperator(symbol.value)
            }
            return false
        }
        if (let symbol: MathSymbolNode <- script.base) {
            return symbol.family == "op" && isDefaultLimitsOperator(symbol.value)
        }
        return false
    }

    private func shouldUseOperatorLimits(script: MathSupSubNode): Bool {
        if (let limits: MathLimitsNode <- script.base) {
            if (limits.mode == "limits") {
                return isOperatorScript(script)
            }
            if (limits.mode == "nolimits") {
                return false
            }
        }
        return currentStyle == "display" && isLimitsOperatorScript(script)
    }

    private func isDefaultLimitsOperator(value: String): Bool {
        match (value) {
            case "∑" | "∏" | "∐" | "lim" | "lim sup" | "lim inf" => return true
            case _ => return false
        }
    }

    private func isMathStyle(size: String): Bool {
        return size == "display" || size == "text" || size == "script" || size == "scriptscript"
    }

    private func writeSymbol(symbol: MathSymbolNode, out: StringBuilder): Unit {
        let value = symbol.value
        if (isAsciiNumber(value)) {
            out.append("<mn>")
            out.append(HtmlEscaper.escapeText(value))
            out.append("</mn>")
            return
        }
        if (symbol.family == "bin" || symbol.family == "rel" || symbol.family == "op" ||
            symbol.family == "open" || symbol.family == "close" || symbol.family == "punct") {
            out.append("<mo>")
            out.append(HtmlEscaper.escapeText(value))
            out.append("</mo>")
            return
        }
        if (isIdentifier(value)) {
            out.append("<mi>")
            out.append(HtmlEscaper.escapeText(value))
            out.append("</mi>")
            return
        }
        out.append("<mo>")
        out.append(HtmlEscaper.escapeText(value))
        out.append("</mo>")
    }

    private func environmentLeftDelimiter(name: String): String {
        match (name) {
            case "cases" => return "{"
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

    private func environmentRightDelimiter(name: String): String {
        match (name) {
            case "rcases" => return "}"
            case "pmatrix" => return ")"
            case "pmatrix*" => return ")"
            case "bmatrix" => return "]"
            case "bmatrix*" => return "]"
            case "Bmatrix" => return "}"
            case "Bmatrix*" => return "}"
            case "vmatrix" => return "|"
            case "vmatrix*" => return "|"
            case "Vmatrix" => return "∥"
            case "Vmatrix*" => return "∥"
            case _ => return ""
        }
    }

    private func isAsciiNumber(value: String): Bool {
        if (value.isEmpty()) {
            return false
        }
        for (b in value) {
            if (b < b'0' || b > b'9') {
                return false
            }
        }
        return true
    }

    private func isIdentifier(value: String): Bool {
        if (value.isEmpty()) {
            return false
        }
        let first = value[0]
        return (first >= b'a' && first <= b'z') || (first >= b'A' && first <= b'Z') || value.size > 1
    }
}
