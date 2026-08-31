package mathtex.html

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
import mathtex.mathml.MathMlWriter
import mathtex.util.HtmlEscaper

private struct XArrowLayout {
    let strut: String
    let vlistHeight: String
    let depth: String
    let upperTop: String
    let arrowTop: String
    let lowerTop: String

    init(strut: String, vlistHeight: String, depth: String, upperTop: String, arrowTop: String, lowerTop: String) {
        this.strut = strut
        this.vlistHeight = vlistHeight
        this.depth = depth
        this.upperTop = upperTop
        this.arrowTop = arrowTop
        this.lowerTop = lowerTop
    }
}

public class HtmlMathWriter {
    private var fontDepth: Int64 = 0
    private var crampedDepth: Int64 = 0
    private var displayMode: Bool = false
    private var currentStyle: String = "text"

    public init() {}

    public func writeHtmlAndMathMl(expression: MathExpression, classPrefix: String, errorColor: String): String {
        this.displayMode = expression.displayMode
        this.currentStyle = if (expression.displayMode) { "display" } else { "text" }
        let prefix = HtmlEscaper.escapeAttribute(classPrefix)
        let displayClass = if (expression.displayMode) { " ${prefix}-display" } else { "" }
        let out = StringBuilder(expression.source.size + 256)
        out.append("<span class=\"${prefix} mathtex${displayClass}\" data-tex=\"")
        out.append(HtmlEscaper.escapeAttribute(expression.source))
        out.append("\">")
        out.append("<span class=\"${prefix}-mathml\">")
        out.append(MathMlWriter().write(expression))
        out.append("</span>")
        out.append("<span class=\"${prefix}-html\" aria-hidden=\"true\">")
        writeRootHtml(expression.root, out, prefix, errorColor)
        out.append("</span></span>")
        return out.toString()
    }

    public func writeHtml(expression: MathExpression, classPrefix: String, errorColor: String): String {
        this.displayMode = expression.displayMode
        this.currentStyle = if (expression.displayMode) { "display" } else { "text" }
        let prefix = HtmlEscaper.escapeAttribute(classPrefix)
        let displayClass = if (expression.displayMode) { " ${prefix}-display" } else { "" }
        let out = StringBuilder(expression.source.size + 128)
        out.append("<span class=\"${prefix} mathtex${displayClass}\" data-tex=\"")
        out.append(HtmlEscaper.escapeAttribute(expression.source))
        out.append("\">")
        writeRootHtml(expression.root, out, prefix, errorColor)
        out.append("</span>")
        return out.toString()
    }

    private func writeRootHtml(node: MathNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        if (let sequence: MathSequenceNode <- node) {
            writeSequenceWithBases(sequence.children, out, prefix, errorColor)
            return
        }
        if (let group: MathGroupNode <- node) {
            writeSequenceWithBases(group.children, out, prefix, errorColor)
            return
        }
        writeBaseOpen(baseStrutForNode(node), out)
        writeNode(node, out, prefix, errorColor)
        out.append("</span>")
    }

    private func writeNode(node: MathNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        if (let error: MathErrorNode <- node) {
            out.append("<span class=\"${prefix}-error\" title=\"")
            out.append(HtmlEscaper.escapeAttribute(error.message))
            out.append("\" style=\"color:")
            out.append(HtmlEscaper.escapeAttribute(errorColor))
            out.append("\">")
            out.append(HtmlEscaper.escapeText(error.literal))
            out.append("</span>")
            return
        }
        if (let sequence: MathSequenceNode <- node) {
            writeSequenceChildren(sequence.children, out, prefix, errorColor)
            return
        }
        if (let group: MathGroupNode <- node) {
            writeSequenceChildren(group.children, out, prefix, errorColor)
            return
        }
        if (let symbol: MathSymbolNode <- node) {
            let useMathNormal = fontDepth == 0 && shouldUseMathNormal(symbol)
            out.append("<span class=\"${prefix}-symbol ")
            out.append(katexAtomClass(symbol.family))
            if (useMathNormal) {
                out.append(" mathnormal")
            }
            if (isTightStyle()) {
                out.append(" mtight")
            }
            out.append("\"")
            let italicCorrection = mathnormalItalicCorrection(symbol.value)
            if (useMathNormal && !italicCorrection.isEmpty()) {
                out.append(" style=\"margin-right:")
                out.append(italicCorrection)
                out.append(";\"")
            }
            out.append(">")
            out.append(HtmlEscaper.escapeText(symbol.value))
            out.append("</span>")
            return
        }
        if (let text: MathTextNode <- node) {
            out.append("<span class=\"${prefix}-text mtext\">")
            out.append(HtmlEscaper.escapeText(text.text))
            out.append("</span>")
            return
        }
        if (let delimited: MathDelimitedNode <- node) {
            writeDelimited(delimited.left, delimited.body, delimited.right, out, prefix, errorColor)
            return
        }
        if (let environment: MathEnvironmentNode <- node) {
            writeEnvironment(environment, out, prefix, errorColor)
            return
        }
        if (let color: MathColorNode <- node) {
            out.append("<span class=\"${prefix}-color\" style=\"color:")
            out.append(HtmlEscaper.escapeAttribute(color.color))
            out.append("\">")
            writeNode(color.body, out, prefix, errorColor)
            out.append("</span>")
            return
        }
        if (let sizing: MathSizingNode <- node) {
            out.append("<span class=\"${prefix}-size ${prefix}-size-")
            out.append(HtmlEscaper.escapeAttribute(sizing.size))
            out.append(styleSizingClass(sizing.size))
            out.append("\">")
            let previousStyle = currentStyle
            if (isMathStyle(sizing.size)) {
                currentStyle = sizing.size
            }
            writeNode(sizing.body, out, prefix, errorColor)
            currentStyle = previousStyle
            out.append("</span>")
            return
        }
        if (let command: MathCommandNode <- node) {
            writeCommand(command, out, prefix, errorColor)
            return
        }
        if (let frac: MathFractionNode <- node) {
            writeFraction(frac, out, prefix, errorColor)
            return
        }
        if (let sqrt: MathSqrtNode <- node) {
            writeSqrt(sqrt, out, prefix, errorColor)
            return
        }
        if (let script: MathSupSubNode <- node) {
            if (isHorizontalBraceScript(script)) {
                writeHorizontalBraceScript(script, out, prefix, errorColor)
                return
            }
            writeScripts(script, out, prefix, errorColor)
            return
        }
        if (let limits: MathLimitsNode <- node) {
            writeNode(limits.base, out, prefix, errorColor)
            return
        }
        for (child in node.children) {
            writeNode(child, out, prefix, errorColor)
        }
    }

    private func writeFraction(frac: MathFractionNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        let displayFraction = currentStyle == "display"
        let scriptFraction = isTightStyle()
        let vlistHeight = if (displayFraction) { "1.1076em" } else if (scriptFraction) { "0.6915em" } else { "0.6954em" }
        let denominatorTop = if (displayFraction) { "-2.314em" } else if (scriptFraction) { "-2.656em" } else { "-2.655em" }
        let lineTop = if (scriptFraction) { "-3.2255em" } else { "-3.23em" }
        let numeratorTop = if (displayFraction) { "-3.677em" } else if (scriptFraction) { "-3.384em" } else { "-3.394em" }
        let depth = if (displayFraction) { "0.686em" } else if (scriptFraction) { "0.344em" } else { "0.345em" }
        let scriptSizing = if (scriptFraction) { "sizing reset-size3 size1 mtight" } else { "sizing reset-size6 size3 mtight" }
        let lineClass = if (scriptFraction) { "frac-line ${prefix}-frac-line mtight" } else { "frac-line ${prefix}-frac-line" }
        let lineWidth = if (scriptFraction) { "0.049em" } else { "0.04em" }
        out.append("<span class=\"mord ${prefix}-frac-wrap\"><span class=\"mopen nulldelimiter\"></span><span class=\"mfrac ${prefix}-frac\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(vlistHeight)
        out.append(";\">")
        out.append("<span style=\"top:")
        out.append(denominatorTop)
        out.append(";\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"")
        if (displayFraction) {
            out.append("mord")
        } else {
            out.append(scriptSizing)
            out.append(" ${prefix}-frac-den")
        }
        out.append("\"><span class=\"mord")
        if (scriptFraction) { out.append(" mtight") }
        out.append("\">")
        let previousStyle = currentStyle
        if (!displayFraction) { currentStyle = "script" }
        writeNode(frac.denominator, out, prefix, errorColor)
        currentStyle = previousStyle
        out.append("</span></span></span>")
        out.append("<span style=\"top:")
        out.append(lineTop)
        out.append(";\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"")
        out.append(lineClass)
        out.append("\" style=\"border-bottom-width:")
        out.append(lineWidth)
        out.append(";\"></span></span>")
        out.append("<span style=\"top:")
        out.append(numeratorTop)
        out.append(";\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"")
        if (displayFraction) {
            out.append("mord")
        } else {
            out.append(scriptSizing)
            out.append(" ${prefix}-frac-num")
        }
        out.append("\"><span class=\"mord")
        if (scriptFraction) { out.append(" mtight") }
        out.append("\">")
        if (!displayFraction) { currentStyle = "script" }
        writeNode(frac.numerator, out, prefix, errorColor)
        currentStyle = previousStyle
        out.append("</span></span></span>")
        out.append("</span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(depth)
        out.append(";\"><span></span></span></span></span></span><span class=\"mclose nulldelimiter\"></span></span>")
    }

    private func writeSqrt(sqrt: MathSqrtNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        let tall = needsTallSqrt(sqrt.radicand)
        let vlistHeight = if (tall) { "0.9578em" } else { "0.8003em" }
        let alignTop = if (tall) { "-3.2em" } else { "-3em" }
        let pstrutHeight = if (tall) { "3.2em" } else { "3em" }
        let paddingLeft = if (tall) { "1em" } else { "0.833em" }
        let radicalTop = if (tall) { "-2.9178em" } else { "-2.7603em" }
        let minWidth = if (tall) { "1.02em" } else { "0.853em" }
        let svgHeight = if (tall) { "1.28em" } else { "1.08em" }
        let depth = if (tall) { "0.2822em" } else { "0.2397em" }
        out.append("<span class=\"mord sqrt ${prefix}-sqrt\">")
        if (let Some(index) <- sqrt.index) {
            out.append("<span class=\"root ${prefix}-sqrt-root\"><span class=\"vlist-t\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.7869em;\"><span style=\"top:-2.9647em;\"><span class=\"pstrut\" style=\"height:2.5em;\"></span><span class=\"sizing reset-size6 size1 mtight\"><span class=\"mord mtight\">")
            writeNode(index, out, prefix, errorColor)
            out.append("</span></span></span></span></span></span></span>")
        }
        out.append("<span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(vlistHeight)
        out.append(";\">")
        out.append("<span class=\"svg-align\" style=\"top:")
        out.append(alignTop)
        out.append(";\"><span class=\"pstrut\" style=\"height:")
        out.append(pstrutHeight)
        out.append(";\"></span><span class=\"mord\" style=\"padding-left:")
        out.append(paddingLeft)
        out.append(";\">")
        crampedDepth += 1
        writeNode(sqrt.radicand, out, prefix, errorColor)
        crampedDepth -= 1
        out.append("</span></span>")
        out.append("<span style=\"top:")
        out.append(radicalTop)
        out.append(";\"><span class=\"pstrut\" style=\"height:")
        out.append(pstrutHeight)
        out.append(";\"></span><span class=\"hide-tail\" style=\"min-width:")
        out.append(minWidth)
        out.append(";height:")
        out.append(svgHeight)
        out.append(";display:inline-block;\">")
        appendSqrtSvg(out, tall)
        out.append("</span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(depth)
        out.append(";\"><span></span></span></span></span></span>")
    }

    private func writeScripts(script: MathSupSubNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        if (isOperatorScript(script)) {
            writeOperatorScripts(script, out, prefix, errorColor)
            return
        }
        out.append("<span class=\"mord ${prefix}-scripts\"><span class=\"${prefix}-base\">")
        writeNode(script.base, out, prefix, errorColor)
        let supOnlyCramped = crampedDepth > 0 && script.sup.isSome() && script.sub.isNone()
        let vlistHeight = if (supOnlyCramped) { "0.7401em" } else if (script.sup.isNone() && script.sub.isSome()) { "0.3117em" } else { "0.8141em" }
        let vlistClass = if (script.sup.isNone() && script.sub.isSome()) { "vlist-t vlist-t2" } else { "vlist-t" }
        out.append("</span><span class=\"msupsub ${prefix}-msupsub\"><span class=\"")
        out.append(vlistClass)
        out.append("\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(vlistHeight)
        out.append(";\">")
        if (let Some(sub) <- script.sub) {
            let subTop = if (script.sup.isSome()) { "-2.4413em" } else { "-2.55em" }
            out.append("<span style=\"top:")
            out.append(subTop)
            out.append(";margin-left:0em;margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight ${prefix}-script ${prefix}-sub\">")
            let previousStyle = currentStyle
            currentStyle = "script"
            writeNode(sub, out, prefix, errorColor)
            currentStyle = previousStyle
            out.append("</span></span>")
        }
        if (let Some(sup) <- script.sup) {
            let supTop = if (supOnlyCramped) { "-2.989em" } else { "-3.063em" }
            out.append("<span style=\"top:")
            out.append(supTop)
            out.append(";margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight ${prefix}-script ${prefix}-sup\">")
            let previousStyle = currentStyle
            currentStyle = "script"
            writeNode(sup, out, prefix, errorColor)
            currentStyle = previousStyle
            out.append("</span></span>")
        }
        out.append("</span>")
        if (script.sup.isNone() && script.sub.isSome()) {
            out.append("<span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.15em;\"><span></span></span>")
        }
        out.append("</span></span></span></span>")
    }

    private func writeHorizontalBraceScript(script: MathSupSubNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        if (let command: MathCommandNode <- script.base) {
            if ((command.name == "overbrace" || command.name == "overbracket") && script.sup.isSome()) {
                out.append("<span class=\"minner mover\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:1.7327em;\"><span style=\"top:-3.2313em;\"><span class=\"pstrut\" style=\"height:3.2313em;\"></span>")
                writeStretchyOverAccent(command, out, prefix, errorColor)
                out.append("</span><span style=\"top:-4.6627em;\"><span class=\"pstrut\" style=\"height:3.2313em;\"></span><span class=\"sizing reset-size6 size3 mtight\"><span class=\"mord mtight\">")
                writeNode(script.sup.getOrThrow(), out, prefix, errorColor)
                out.append("</span></span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.0833em;\"><span></span></span></span></span></span>")
                return
            }
            if ((command.name == "underbrace" || command.name == "underbracket") && script.sub.isSome()) {
                out.append("<span class=\"minner munder\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.6444em;\"><span style=\"top:-1.7673em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"sizing reset-size6 size3 mtight\"><span class=\"mord mtight\">")
                writeNode(script.sub.getOrThrow(), out, prefix, errorColor)
                out.append("</span></span></span><span style=\"top:-3em;\"><span class=\"pstrut\" style=\"height:3em;\"></span>")
                writeStretchyUnderAccent(command, out, prefix, errorColor)
                out.append("</span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:1.2327em;\"><span></span></span></span></span></span>")
                return
            }
        }
        writeScripts(script, out, prefix, errorColor)
    }

    private func writeOperatorScripts(script: MathSupSubNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        if (shouldUseOperatorLimits(script) && script.sub.isSome() && script.sup.isSome()) {
            let displayLayout = currentStyle == "display"
            let vlistHeight = if (displayLayout) { "1.6514em" } else { "1.3514em" }
            let depth = if (displayLayout) { "1.2777em" } else { "0.9777em" }
            let pstrutHeight = if (displayLayout) { "3.05em" } else { "3em" }
            let subTop = if (displayLayout) { "-1.8723em" } else { "-2.1223em" }
            let opTop = if (displayLayout) { "-3.05em" } else { "-3em" }
            let supTop = if (displayLayout) { "-4.3em" } else { "-3.95em" }
            let opClass = if (displayLayout) { "large-op" } else { "small-op" }
            out.append("<span class=\"mop op-limits\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
            out.append(vlistHeight)
            out.append(";\">")
            out.append("<span style=\"top:")
            out.append(subTop)
            out.append(";margin-left:0em;\"><span class=\"pstrut\" style=\"height:")
            out.append(pstrutHeight)
            out.append(";\"></span><span class=\"sizing reset-size6 size3 mtight\">")
            writeNode(script.sub.getOrThrow(), out, prefix, errorColor)
            out.append("</span></span>")
            out.append("<span style=\"top:")
            out.append(opTop)
            out.append(";\"><span class=\"pstrut\" style=\"height:")
            out.append(pstrutHeight)
            out.append(";\"></span><span><span class=\"mop op-symbol ")
            out.append(opClass)
            out.append("\">")
            writeOperatorBaseText(script.base, out)
            out.append("</span></span></span>")
            out.append("<span style=\"top:")
            out.append(supTop)
            out.append(";margin-left:0em;\"><span class=\"pstrut\" style=\"height:")
            out.append(pstrutHeight)
            out.append(";\"></span><span class=\"sizing reset-size6 size3 mtight\">")
            writeNode(script.sup.getOrThrow(), out, prefix, errorColor)
            out.append("</span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
            out.append(depth)
            out.append(";\"><span></span></span></span></span></span>")
            return
        }
        if (isTextOperatorScript(script)) {
            writeTextOperatorScripts(script, out, prefix, errorColor)
            return
        }
        if (currentStyle == "display" && isIntegralOperator(script.base)) {
            writeDisplayIntegralSideScripts(script, out, prefix, errorColor)
            return
        }

        out.append("<span class=\"mop\"><span class=\"mop op-symbol small-op\" style=\"position:relative;top:0em;\">")
        writeOperatorBaseText(script.base, out)
        out.append("</span><span class=\"msupsub ${prefix}-msupsub\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.8043em;\">")
        if (let Some(sub) <- script.sub) {
            out.append("<span style=\"top:-2.4003em;margin-left:0em;margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight\">")
            writeNode(sub, out, prefix, errorColor)
            out.append("</span></span>")
        }
        if (let Some(sup) <- script.sup) {
            out.append("<span style=\"top:-3.2029em;margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight\">")
            writeNode(sup, out, prefix, errorColor)
            out.append("</span></span>")
        }
        out.append("</span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.2997em;\"><span></span></span></span></span></span></span>")
    }

    private func writeDisplayIntegralSideScripts(script: MathSupSubNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        out.append("<span class=\"mop\"><span class=\"mop op-symbol large-op\" style=\"margin-right:0.4445em;position:relative;top:-0.0011em;\">")
        writeOperatorBaseText(script.base, out)
        out.append("</span><span class=\"msupsub ${prefix}-msupsub\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:1.564em;\">")
        if (let Some(sub) <- script.sub) {
            out.append("<span style=\"top:-1.7881em;margin-left:-0.4445em;margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight\">")
            writeNode(sub, out, prefix, errorColor)
            out.append("</span></span>")
        }
        if (let Some(sup) <- script.sup) {
            out.append("<span style=\"top:-3.8129em;margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight\">")
            writeNode(sup, out, prefix, errorColor)
            out.append("</span></span>")
        }
        out.append("</span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.9119em;\"><span></span></span></span></span></span></span>")
    }

    private func writeTextOperatorScripts(script: MathSupSubNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        out.append("<span class=\"mop\"><span class=\"mop\">")
        writeTextOperatorBase(script.base, out)
        out.append("</span><span class=\"msupsub ${prefix}-msupsub\">")
        if (script.sup.isNone() && script.sub.isSome()) {
            out.append("<span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.207em;\">")
            out.append("<span style=\"top:-2.4559em;margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight\">")
            writeNode(script.sub.getOrThrow(), out, prefix, errorColor)
            out.append("</span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.2441em;\"><span></span></span></span></span>")
        } else {
            out.append("<span class=\"vlist-t\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.8141em;\">")
            if (let Some(sub) <- script.sub) {
                out.append("<span style=\"top:-2.4413em;margin-left:0em;margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight\">")
                writeNode(sub, out, prefix, errorColor)
                out.append("</span></span>")
            }
            if (let Some(sup) <- script.sup) {
                out.append("<span style=\"top:-3.2029em;margin-right:0.05em;\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight\">")
                writeNode(sup, out, prefix, errorColor)
                out.append("</span></span>")
            }
            out.append("</span></span></span>")
        }
        out.append("</span></span>")
    }

    private func writeOperatorBaseText(node: MathNode, out: StringBuilder): Unit {
        if (let limits: MathLimitsNode <- node) {
            writeOperatorBaseText(limits.base, out)
            return
        }
        if (let symbol: MathSymbolNode <- node) {
            out.append(HtmlEscaper.escapeText(symbol.value))
            return
        }
        out.append(HtmlEscaper.escapeText(node.literal))
    }

    private func writeTextOperatorBase(node: MathNode, out: StringBuilder): Unit {
        if (let limits: MathLimitsNode <- node) {
            writeTextOperatorBase(limits.base, out)
            return
        }
        if (let symbol: MathSymbolNode <- node) {
            if (symbol.value == "log") {
                out.append("lo<span style=\"margin-right:0.0139em;\">g</span>")
                return
            }
            out.append(HtmlEscaper.escapeText(symbol.value))
            return
        }
        out.append(HtmlEscaper.escapeText(node.literal))
    }

    private func writeDelimited(left: MathNode, body: MathNode, right: MathNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        let tall = needsTallSqrt(body)
        let delimitedClass = if (tall) { "${prefix}-delimited minner" } else { "${prefix}-delimited" }
        out.append("<span class=\"")
        out.append(delimitedClass)
        out.append("\">")
        writeLeftRightDelimiter(left, "left", tall, out, prefix)
        out.append("<span class=\"${prefix}-delim-body\">")
        writeNode(body, out, prefix, errorColor)
        out.append("</span>")
        writeLeftRightDelimiter(right, "right", tall, out, prefix)
        out.append("</span>")
    }

    private func writeLeftRightDelimiter(node: MathNode, side: String, tall: Bool, out: StringBuilder, prefix: String): Unit {
        let atomClass = if (side == "left") { "mopen" } else { "mclose" }
        out.append("<span class=\"${prefix}-delim ${prefix}-delim-${side} ${atomClass}")
        if (tall) {
            out.append(" delimcenter\" style=\"top:0em;\">")
        } else {
            out.append("\">")
        }
        let delimiter = delimiterText(node)
        if (delimiter != ".") {
            if (tall) {
                out.append("<span class=\"delimsizing size2\">")
                out.append(HtmlEscaper.escapeText(delimiter))
                out.append("</span>")
            } else {
                out.append(HtmlEscaper.escapeText(delimiter))
            }
        }
        out.append("</span>")
    }

    private func writeEnvironment(environment: MathEnvironmentNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        let left = environmentLeftDelimiter(environment.name)
        let right = environmentRightDelimiter(environment.name)
        let hasDelimiter = !left.isEmpty() || !right.isEmpty()
        if (hasDelimiter) {
            out.append("<span class=\"${prefix}-environment-wrap ${prefix}-env-wrap-")
            out.append(HtmlEscaper.escapeAttribute(normalizeEnvironmentClass(environment.name)))
            out.append("\"><span class=\"minner\">")
            if (!left.isEmpty()) {
                writeEnvironmentDelimiter(environment.name, left, "left", environment.rows.size, out, prefix)
            }
        }
        out.append("<span class=\"mord\"><span class=\"mtable ${prefix}-environment ${prefix}-env-")
        out.append(HtmlEscaper.escapeAttribute(normalizeEnvironmentClass(environment.name)))
        out.append("\">")
        let columnCount = maxColumnCount(environment)
        let aligned = isAlignedEnvironment(environment.name)
        for (col in 0..columnCount) {
            writeArrayVerticalSeparators(environment, col, out)
            if (col > 0 && !aligned) {
                let sep = environmentColumnSep(environment.name)
                out.append("<span class=\"arraycolsep\" style=\"width:")
                out.append(sep)
                out.append(";\"></span><span class=\"arraycolsep\" style=\"width:")
                out.append(sep)
                out.append(";\"></span>")
            }
            out.append("<span class=\"")
            out.append(environmentColumnClass(environment, col))
            out.append("\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
            out.append(environmentVlistHeight(environment.name, environment.rows.size))
            out.append("em;\">")
            for (rowIndex in 0..environment.rows.size) {
                out.append("<span class=\"${prefix}-env-row\" style=\"top:")
                out.append(environmentRowTop(environment.name, rowIndex))
                out.append("em;\"><span class=\"pstrut\" style=\"height:")
                out.append(environmentPstrutHeight(environment.name))
                out.append("em;\"></span><span class=\"mord ${prefix}-env-cell\">")
                if (col < environment.rows[rowIndex].size) {
                    if (aligned && col % 2 == 1) {
                        writeAlignedCell(environment.rows[rowIndex][col], out, prefix, errorColor)
                    } else {
                        writeNode(environment.rows[rowIndex][col], out, prefix, errorColor)
                    }
                }
                out.append("</span></span>")
            }
            out.append("</span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
            out.append(environmentDepth(environment.name))
            out.append("em;\"><span></span></span></span></span></span>")
        }
        writeArrayVerticalSeparators(environment, columnCount, out)
        out.append("</span></span>")
        if (hasDelimiter) {
            if (!right.isEmpty()) {
                writeEnvironmentDelimiter(environment.name, right, "right", environment.rows.size, out, prefix)
            }
            out.append("</span></span>")
        }
    }

    private func writeEnvironmentDelimiter(name: String, delimiter: String, side: String, rows: Int64, out: StringBuilder, prefix: String): Unit {
        let atomClass = if (side == "left") { "mopen" } else { "mclose" }
        out.append("<span class=\"${prefix}-delim ${prefix}-delim-${side} ${atomClass} delimcenter\">")
        if (isDoubleVerticalMatrixEnvironment(name)) {
            appendDoubleVerticalDelimiterSvg(out)
        } else if (isSquareBracketMatrixEnvironment(name) && rows >= 3) {
            appendSquareBracketDelimiterSvg(side, rows, out)
        } else {
            out.append("<span class=\"delimsizing ")
            out.append(environmentDelimiterSize(name))
            out.append("\">")
            out.append(HtmlEscaper.escapeText(delimiter))
            out.append("</span>")
        }
        out.append("</span>")
    }

    private func appendSquareBracketDelimiterSvg(side: String, rows: Int64, out: StringBuilder): Unit {
        let totalHeight = if (rows <= 3) { "3.6em" } else { (1.2 * Float64(rows)).toString() + "em" }
        let viewHeight = if (rows <= 3) { "3600" } else { (1200 * rows).toString() }
        let vlistHeight = if (rows <= 3) { "2.05em" } else { environmentVlistHeight("bmatrix", rows) + "em" }
        let depth = if (rows <= 3) { "1.55em" } else { environmentDepth("bmatrix") + "em" }
        let top = if (rows <= 3) { "-4.05em" } else { (-2.0 - 1.2 * Float64(rows) / 2.0).toString() + "em" }
        out.append("<span class=\"delimsizing mult\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(vlistHeight)
        out.append(";\"><span style=\"top:")
        out.append(top)
        out.append(";\"><span class=\"pstrut\" style=\"height:5.6em;\"></span><span style=\"width:0.667em;height:")
        out.append(totalHeight)
        out.append(";\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"0.667em\" height=\"")
        out.append(totalHeight)
        out.append("\" viewBox=\"0 0 667 ")
        out.append(viewHeight)
        out.append("\"><path d=\"")
        if (side == "left") {
            out.append("M403 1759 V84 H666 V0 H319 V1759 v0 v1759 v84 h347 v-84 H403z M403 1759 V0 H319 V1759 v0 v1759 v84 h84z")
        } else {
            out.append("M347 1759 V0 H0 V84 H263 V1759 v0 v1759 H0 v84 H347z M347 1759 V0 H263 V1759 v0 v1759 h84z")
        }
        out.append("\"/></svg></span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(depth)
        out.append(";\"><span></span></span></span></span></span>")
    }

    private func appendDoubleVerticalDelimiterSvg(out: StringBuilder): Unit {
        out.append("<span class=\"delimsizing mult\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:1.45em;\"><span style=\"top:-3.45em;\"><span class=\"pstrut\" style=\"height:4.4em;\"></span><span style=\"width:0.556em;height:2.4em;\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"0.556em\" height=\"2.4em\" viewBox=\"0 0 556 2400\"><path d=\"M145 15 v585 v1200 v585 c2.667,10,9.667,15,21,15c10,0,16.667,-5,20,-15 v-585 v-1200 v-585 c-2.667,-10,-9.667,-15,-21,-15c-10,0,-16.667,5,-20,15z M188 15 H145 v585 v1200 v585 h43zM367 15 v585 v1200 v585 c2.667,10,9.667,15,21,15c10,0,16.667,-5,20,-15 v-585 v-1200 v-585 c-2.667,-10,-9.667,-15,-21,-15c-10,0,-16.667,5,-20,15z M410 15 H367 v585 v1200 v585 h43z\"/></svg></span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.95em;\"><span></span></span></span></span></span>")
    }

    private func writeDelimiterNode(node: MathNode, out: StringBuilder): Unit {
        let delimiter = delimiterText(node)
        if (delimiter != ".") {
            out.append(HtmlEscaper.escapeText(delimiter))
        }
    }

    private func delimiterText(node: MathNode): String {
        if (let symbol: MathSymbolNode <- node) {
            return symbol.value
        }
        return node.literal
    }

    private func writeCommand(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        if (command.name == "operatorname" && command.children.size > 0) {
            out.append("<span class=\"mop\"><span class=\"mord mathrm\">")
            writeOperatorNameText(command.children[0], out)
            out.append("</span></span>")
            return
        }
        if (isFontCommand(command.name)) {
            out.append("<span class=\"${prefix}-font ${prefix}-font-")
            out.append(HtmlEscaper.escapeAttribute(command.name))
            out.append(" ")
            out.append(HtmlEscaper.escapeAttribute(command.name))
            out.append("\">")
            fontDepth += 1
            writeChildren(command, out, prefix, errorColor)
            fontDepth -= 1
            out.append("</span>")
            return
        }
        if (command.name == "spacing") {
            let width = spacingCommandWidth(command.literal)
            if (width.isEmpty()) {
                out.append("<span class=\"${prefix}-space\"> </span>")
            } else {
                writeMspace(width, out)
            }
            return
        }
        if (command.name == "newline") {
            out.append("<span class=\"${prefix}-newline\"></span>")
            return
        }
        if (isXArrowCommand(command.name) && command.children.size > 0) {
            writeXArrow(command, out, prefix, errorColor)
            return
        }
        if (isOverAccentCommand(command.name) && command.children.size > 0) {
            writeOverAccent(command, out, prefix, errorColor)
            return
        }
        if (isUnderAccentCommand(command.name) && command.children.size > 0) {
            writeUnderAccent(command, out, prefix, errorColor)
            return
        }
        if (isSimpleAccentCommand(command.name) && command.children.size > 0) {
            writeSimpleAccent(command, out, prefix, errorColor)
            return
        }
        if (command.name == "boxed" && command.children.size > 0) {
            out.append("<span class=\"mord ${prefix}-enclose ${prefix}-boxed\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.7706em;\"><span style=\"top:-3.305em;\"><span class=\"pstrut\" style=\"height:3.305em;\"></span><span class=\"boxpad\"><span class=\"mord\">")
            writeNode(command.children[0], out, prefix, errorColor)
            out.append("</span></span></span><span style=\"top:-2.7706em;\"><span class=\"pstrut\" style=\"height:3.305em;\"></span><span class=\"stretchy fbox\" style=\"height:1.305em;border-style:solid;border-width:0.04em;\"></span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.5344em;\"><span></span></span></span></span></span>")
            return
        }
        if (isCancelCommand(command.name) && command.children.size > 0) {
            writeCancel(command, out, prefix, errorColor)
            return
        }
        if (command.name == "sout" && command.children.size > 0) {
            out.append("<span class=\"mord ${prefix}-enclose ${prefix}-sout\"><span class=\"${prefix}-sout-line\"></span><span class=\"${prefix}-enclose-body\">")
            writeNode(command.children[0], out, prefix, errorColor)
            out.append("</span></span>")
            return
        }
        if (command.name == "colorbox" && command.children.size >= 2) {
            writeColorBox(command, out, prefix, errorColor)
            return
        }
        if (command.name == "fcolorbox" && command.children.size >= 3) {
            writeFColorBox(command, out, prefix, errorColor)
            return
        }
        out.append("<span class=\"${prefix}-command ${prefix}-cmd-")
        out.append(HtmlEscaper.escapeAttribute(normalizeEnvironmentClass(command.name)))
        out.append("\">")
        writeChildren(command, out, prefix, errorColor)
        out.append("</span>")
    }

    private func writeOverAccent(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        let className = normalizeEnvironmentClass(command.name)
        if (isStretchyOverAccent(command.name)) {
            writeStretchyOverAccent(command, out, prefix, errorColor)
            return
        }
        out.append("<span class=\"mord ")
        out.append(HtmlEscaper.escapeAttribute(className))
        out.append(" ${prefix}-over-accent ${prefix}-cmd-")
        out.append(HtmlEscaper.escapeAttribute(className))
        out.append("\"><span class=\"vlist-t\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.6306em;\">")
        out.append("<span style=\"top:-3em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"${prefix}-accent-base mord\">")
        writeNode(command.children[0], out, prefix, errorColor)
        out.append("</span></span>")
        out.append("<span style=\"top:-3.5506em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"")
        out.append(HtmlEscaper.escapeAttribute(className))
        out.append("-line ${prefix}-accent-line\" style=\"border-bottom-width:0.04em;\"></span></span></span></span></span></span>")
    }

    private func writeUnderAccent(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        let className = normalizeEnvironmentClass(command.name)
        if (command.name == "underbrace" || isArrowStretchy(command.name) || isHorizontalPairAccent(command.name) || command.name == "utilde") {
            writeStretchyUnderAccent(command, out, prefix, errorColor)
            return
        }
        out.append("<span class=\"mord ")
        out.append(HtmlEscaper.escapeAttribute(className))
        out.append(" ${prefix}-under-accent ${prefix}-cmd-")
        out.append(HtmlEscaper.escapeAttribute(className))
        out.append("\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.4306em;\">")
        out.append("<span style=\"top:-2.6456em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"")
        out.append(HtmlEscaper.escapeAttribute(className))
        out.append("-line ${prefix}-accent-line\" style=\"border-bottom-width:0.04em;\"></span></span>")
        out.append("<span style=\"top:-3em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"${prefix}-accent-base mord\">")
        writeNode(command.children[0], out, prefix, errorColor)
        out.append("</span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.3944em;\"><span></span></span></span></span></span>")
    }

    private func writeSimpleAccent(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        out.append("<span class=\"mord accent ${prefix}-accent ${prefix}-cmd-")
        out.append(HtmlEscaper.escapeAttribute(normalizeEnvironmentClass(command.name)))
        out.append("\"><span class=\"vlist-t\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.6944em;\">")
        out.append("<span style=\"top:-3em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"${prefix}-accent-base mord\">")
        writeNode(command.children[0], out, prefix, errorColor)
        out.append("</span></span>")
        out.append("<span style=\"top:-3em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"accent-body ${prefix}-accent-body\" style=\"left:-0.1944em;\"><span class=\"mord\">")
        out.append(HtmlEscaper.escapeText(simpleAccentGlyph(command.name)))
        out.append("</span></span></span></span></span></span></span>")
    }

    private func writeCancel(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        out.append("<span class=\"mord ${prefix}-enclose ${prefix}-")
        out.append(HtmlEscaper.escapeAttribute(command.name))
        out.append(" cancel-lap\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.6306em;\"><span style=\"top:-3em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"mord cancel-pad ${prefix}-enclose-body\">")
        writeNode(command.children[0], out, prefix, errorColor)
        out.append("</span></span><span class=\"svg-align\" style=\"top:-2.8em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"stretchy ")
        out.append(HtmlEscaper.escapeAttribute(command.name))
        out.append(" ${prefix}-cancel-line\" aria-hidden=\"true\" style=\"height:0.8306em;\">")
        appendCancelSvg(command.name, out)
        out.append("</span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.2em;\"><span></span></span></span></span></span>")
    }

    private func writeColorBox(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        out.append("<span class=\"mord\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.7306em;\"><span style=\"top:-2.7306em;\"><span class=\"pstrut\" style=\"height:3.0306em;\"></span><span class=\"stretchy colorbox ${prefix}-colorbox\" style=\"height:1.0306em;background-color:")
        writeTextNodeValue(command.children[0], out)
        out.append(";\"></span></span><span style=\"top:-3.0306em;\"><span class=\"pstrut\" style=\"height:3.0306em;\"></span><span class=\"boxpad\"><span class=\"mord\">")
        writeTextModeNode(command.children[1], out, prefix, errorColor)
        out.append("</span></span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.3em;\"><span></span></span></span></span></span>")
    }

    private func writeFColorBox(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        out.append("<span class=\"mord\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.7706em;\"><span style=\"top:-2.7706em;\"><span class=\"pstrut\" style=\"height:3.305em;\"></span><span class=\"stretchy fcolorbox ${prefix}-fcolorbox\" style=\"height:1.305em;border-style:solid;border-width:0.04em;background-color:")
        writeTextNodeValue(command.children[1], out)
        out.append(";border-color:")
        writeTextNodeValue(command.children[0], out)
        out.append(";\"></span></span><span style=\"top:-3.305em;\"><span class=\"pstrut\" style=\"height:3.305em;\"></span><span class=\"boxpad\"><span class=\"mord\">")
        writeTextModeNode(command.children[2], out, prefix, errorColor)
        out.append("</span></span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.5344em;\"><span></span></span></span></span></span>")
    }

    private func writeTextModeNode(node: MathNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        if (let symbol: MathSymbolNode <- node) {
            out.append("<span class=\"${prefix}-symbol ")
            out.append(katexAtomClass(symbol.family))
            out.append("\">")
            out.append(HtmlEscaper.escapeText(symbol.value))
            out.append("</span>")
            return
        }
        if (let text: MathTextNode <- node) {
            out.append("<span class=\"${prefix}-text mtext\">")
            out.append(HtmlEscaper.escapeText(text.text))
            out.append("</span>")
            return
        }
        if (let sequence: MathSequenceNode <- node) {
            for (child in sequence.children) {
                writeTextModeNode(child, out, prefix, errorColor)
            }
            return
        }
        if (let group: MathGroupNode <- node) {
            for (child in group.children) {
                writeTextModeNode(child, out, prefix, errorColor)
            }
            return
        }
        writeNode(node, out, prefix, errorColor)
    }

    private func writeXArrow(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        let hasBelow = command.children.size > 1
        let layout = xArrowLayout(command.name, hasBelow)
        out.append("<span class=\"base\"><span class=\"strut\" style=\"")
        out.append(layout.strut)
        out.append("\"></span><span class=\"mrel x-arrow ${prefix}-x-arrow ${prefix}-cmd-")
        out.append(HtmlEscaper.escapeAttribute(command.name))
        out.append("\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(layout.vlistHeight)
        out.append(";\"><span style=\"top:")
        out.append(layout.upperTop)
        out.append(";\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight x-arrow-pad\"><span class=\"mord mtight\">")
        let previousStyle = currentStyle
        currentStyle = "script"
        writeNode(command.children[0], out, prefix, errorColor)
        currentStyle = previousStyle
        out.append("</span></span></span><span class=\"svg-align\" style=\"top:")
        out.append(layout.arrowTop)
        out.append(";\"><span class=\"pstrut\" style=\"height:2.7em;\"></span>")
        appendStretchySvg(command.name, out, true)
        out.append("</span>")
        if (hasBelow) {
            out.append("<span style=\"top:")
            out.append(layout.lowerTop)
            out.append(";\"><span class=\"pstrut\" style=\"height:2.7em;\"></span><span class=\"sizing reset-size6 size3 mtight x-arrow-pad\"><span class=\"mord mtight\">")
            currentStyle = "script"
            writeNode(command.children[1], out, prefix, errorColor)
            currentStyle = previousStyle
            out.append("</span></span></span>")
        }
        out.append("</span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:")
        out.append(layout.depth)
        out.append(";\"><span></span></span></span></span></span></span>")
    }

    private func xArrowLayout(name: String, hasBelow: Bool): XArrowLayout {
        if (name == "xrightleftarrows") {
            return if (hasBelow) {
                XArrowLayout("height:1.9105em;vertical-align:-0.7976em;", "1.1129em", "0.7976em", "-3.7125em", "-2.7005em", "-2.1034em")
            } else {
                XArrowLayout("height:1.4981em;vertical-align:-0.2005em;", "1.2976em", "0.2005em", "-3.7125em", "-2.7005em", "")
            }
        }
        if (name == "xrightleftharpoons" || name == "xleftrightharpoons" ||
            name == "xrightequilibrium" || name == "xleftequilibrium") {
            return if (hasBelow) {
                XArrowLayout("height:1.7255em;vertical-align:-0.7051em;", "1.0204em", "0.7051em", "-3.435em", "-2.608em", "-2.0109em")
            } else {
                XArrowLayout("height:1.3131em;vertical-align:-0.108em;", "1.2051em", "0.108em", "-3.435em", "-2.608em", "")
            }
        }
        if (name == "xtofrom") {
            return if (hasBelow) {
                XArrowLayout("height:1.5375em;vertical-align:-0.6111em;", "0.9264em", "0.6111em", "-3.325em", "-2.686em", "-2.0889em")
            } else {
                XArrowLayout("height:1.1251em;vertical-align:-0.014em;", "1.1111em", "0.014em", "-3.325em", "-2.686em", "")
            }
        }
        if (name == "xtwoheadleftarrow" || name == "xtwoheadrightarrow") {
            return if (hasBelow) {
                XArrowLayout("height:1.3435em;vertical-align:-0.5141em;", "0.8294em", "0.5141em", "-3.228em", "-2.783em", "-2.1859em")
            } else {
                XArrowLayout("height:1.0141em;", "1.0141em", "0em", "-3.228em", "-2.783em", "")
            }
        }
        return if (hasBelow) {
            XArrowLayout("height:1.5315em;vertical-align:-0.6081em;", "0.9234em", "0.6081em", "-3.322em", "-2.689em", "-2.0919em")
        } else {
            XArrowLayout("height:1.1191em;vertical-align:-0.011em;", "1.1081em", "0.011em", "-3.322em", "-2.689em", "")
        }
    }

    private func writeStretchyOverAccent(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        let top = if (command.name == "widetilde") { "-3.4306em" } else { "-3.6833em" }
        let height = stretchyHeight(command.name)
        out.append("<span class=\"mord accent ${prefix}-over-accent ${prefix}-cmd-")
        out.append(HtmlEscaper.escapeAttribute(normalizeEnvironmentClass(command.name)))
        out.append("\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.9833em;\"><span style=\"top:-3em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"mord\">")
        writeNode(command.children[0], out, prefix, errorColor)
        out.append("</span></span><span class=\"svg-align\" style=\"top:")
        out.append(top)
        out.append(";\"><span class=\"pstrut\" style=\"height:3em;\"></span>")
        if (command.name == "overbrace") {
            out.append("<span class=\"stretchy\" style=\"height:0.548em;min-width:1.6em;\">")
            appendBraceSvg(out, false)
            out.append("</span>")
        } else if (isHorizontalPairAccent(command.name)) {
            appendHorizontalPairAccentSvg(command.name, out)
        } else if (isArrowStretchy(command.name)) {
            appendStretchySvg(command.name, out, false)
        } else {
            out.append("<span style=\"height:")
            out.append(height)
            out.append(";\">")
            appendWideAccentSvg(command.name, out)
            out.append("</span>")
        }
        out.append("</span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.1944em;\"><span></span></span></span></span></span>")
    }

    private func writeStretchyUnderAccent(command: MathCommandNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        out.append("<span class=\"mord accent ${prefix}-under-accent ${prefix}-cmd-")
        out.append(HtmlEscaper.escapeAttribute(normalizeEnvironmentClass(command.name)))
        out.append("\"><span class=\"vlist-t vlist-t2\"><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.6444em;\"><span class=\"svg-align\" style=\"top:-2.2687em;\"><span class=\"pstrut\" style=\"height:3em;\"></span>")
        if (command.name == "underbrace") {
            out.append("<span class=\"stretchy\" style=\"height:0.548em;min-width:1.6em;\">")
            appendBraceSvg(out, true)
            out.append("</span>")
        } else if (isHorizontalPairAccent(command.name)) {
            appendHorizontalPairAccentSvg(command.name, out)
        } else if (command.name == "utilde") {
            out.append("<span style=\"height:0.286em;\">")
            appendWideAccentSvg("widetilde", out)
            out.append("</span>")
        } else {
            appendStretchySvg(command.name, out, false)
        }
        out.append("</span><span style=\"top:-3em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"mord\">")
        writeNode(command.children[0], out, prefix, errorColor)
        out.append("</span></span></span><span class=\"vlist-s\">&#8203;</span></span><span class=\"vlist-r\"><span class=\"vlist\" style=\"height:0.1944em;\"><span></span></span></span></span></span>")
    }

    private func appendWideAccentSvg(name: String, out: StringBuilder): Unit {
        if (name == "widetilde") {
            out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" height=\"0.286em\" viewBox=\"0 0 1033 286\" preserveAspectRatio=\"none\"><path d=\"M344 55.266c-142 0-300.638 81.316-311.5 86.418-8.01 3.762-22.5 10.91-23.5 5.562L1 120c-1-2-1-3-1-4 0-5 3-9 8-10l18.4-9C160.9 31.9 283 0 358 0c148 0 188 122 331 122s314-97 326-97c4 0 8 2 10 7l7 21.114c1 2.14 1 3.21 1 4.28 0 5.347-3 9.626-7 10.696l-22.3 12.622C852.6 158.372 751 181.476 676 181.476c-149 0-189-126.21-332-126.21z\"/></svg>")
            return
        }
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" height=\"0.3em\" viewBox=\"0 0 2364 300\" preserveAspectRatio=\"none\"><path d=\"M1181 0h2l1171 176c6 0 10 5 10 11l-2 23c-1 6-5 10-11 10h-1L1182 67 15 220h-1c-6 0-10-4-11-10l-2-23c-1-6 4-11 10-11z\"/></svg>")
    }

    private func appendRightArrowSvg(out: StringBuilder): Unit {
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.522em\" viewBox=\"0 0 400000 522\" preserveAspectRatio=\"xMaxYMin slice\"><path d=\"M0 241v40h399891c-47.3 35.3-84 78-110 128-16.7 32-27.7 63.7-33 95 0 1.3-.2 2.7-.5 4-.3 1.3-.5 2.3-.5 3 0 7.3 6.7 11 20 11 8 0 13.2-.8 15.5-2.5 2.3-1.7 4.2-5.5 5.5-11.5 2-13.3 5.7-27 11-41 14.7-44.7 39-84.5 73-119.5s73.7-60.2 119-75.5c6-2 9-5.7 9-11s-3-9-9-11c-45.3-15.3-85-40.5-119-75.5s-58.3-74.8-73-119.5c-4.7-14-8.3-27.3-11-40-1.3-6.7-3.2-10.8-5.5-12.5-2.3-1.7-7.5-2.5-15.5-2.5-14 0-21 3.7-21 11 0 2 2 10.3 6 25 20.7 83.3 67 151.7 139 205zm0 0v40h399900v-40z\"/></svg>")
    }

    private func appendLeftArrowSvg(out: StringBuilder): Unit {
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.522em\" viewBox=\"0 0 400000 522\" preserveAspectRatio=\"xMinYMin slice\"><path d=\"M400000 241H110l3-3c68.7-52.7 113.7-120 135-202 4-14.7 6-23 6-25 0-7.3-7-11-21-11-8 0-13.2.8-15.5 2.5-2.3 1.7-4.2 5.8-5.5 12.5-1.3 4.7-2.7 10.3-4 17-12 48.7-34.8 92-68.5 130S65.3 228.3 18 247c-10 4-16 7.7-18 11 0 8.7 6 14.3 18 17 47.3 18.7 87.8 47 121.5 85S196 441.3 208 490c.7 2 1.3 5 2 9s1.2 6.7 1.5 8c.3 1.3 1 3.3 2 6s2.2 4.5 3.5 5.5c1.3 1 3.3 1.8 6 2.5s6 1 10 1c14 0 21-3.7 21-11 0-2-2-10.3-6-25-20-79.3-65-146.7-135-202 l-3-3h399890zM100 241v40h399900v-40z\"/></svg>")
    }

    private func appendLongEqualSvg(out: StringBuilder): Unit {
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.334em\" viewBox=\"0 0 400000 334\" preserveAspectRatio=\"xMinYMin slice\"><path d=\"M0 50h400000v40H0z M0 244h400000v40H0z M0 50h400000v40H0z M0 244h400000v40H0z\"/></svg>")
    }

    private func appendNamedStretchySvg(pathName: String, height: String, viewBoxHeight: String, align: String, out: StringBuilder): Unit {
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"")
        out.append(height)
        out.append("\" viewBox=\"0 0 400000 ")
        out.append(viewBoxHeight)
        out.append("\" preserveAspectRatio=\"")
        out.append(align)
        out.append(" slice\"><path d=\"")
        appendKatexStretchyPath(pathName, out)
        out.append("\"/></svg>")
    }

    private func appendSingleStretchySvg(name: String, out: StringBuilder): Unit {
        let height = stretchySvgHeight(name)
        let viewBoxHeight = svgViewBoxHeight(name)
        if (name == "overleftarrow" || name == "underleftarrow" || name == "xleftarrow") {
            appendNamedStretchySvg("leftarrow", height, viewBoxHeight, "xMinYMin", out)
        } else if (name == "xLeftarrow") {
            appendNamedStretchySvg("doubleleftarrow", height, viewBoxHeight, "xMinYMin", out)
        } else if (name == "xtwoheadleftarrow") {
            appendNamedStretchySvg("twoheadleftarrow", height, viewBoxHeight, "xMinYMin", out)
        } else if (name == "xleftharpoonup" || name == "overleftharpoon") {
            appendNamedStretchySvg("leftharpoon", height, viewBoxHeight, "xMinYMin", out)
        } else if (name == "xleftharpoondown") {
            appendNamedStretchySvg("leftharpoondown", height, viewBoxHeight, "xMinYMin", out)
        } else if (name == "xRightarrow" || name == "Overrightarrow") {
            appendNamedStretchySvg("doublerightarrow", height, viewBoxHeight, "xMaxYMin", out)
        } else if (name == "xtwoheadrightarrow") {
            appendNamedStretchySvg("twoheadrightarrow", height, viewBoxHeight, "xMaxYMin", out)
        } else if (name == "xrightharpoonup" || name == "overrightharpoon") {
            appendNamedStretchySvg("rightharpoon", height, viewBoxHeight, "xMaxYMin", out)
        } else if (name == "xrightharpoondown") {
            appendNamedStretchySvg("rightharpoondown", height, viewBoxHeight, "xMaxYMin", out)
        } else {
            appendNamedStretchySvg("rightarrow", height, viewBoxHeight, "xMaxYMin", out)
        }
    }

    private func appendKatexStretchyPath(pathName: String, out: StringBuilder): Unit {
        match (pathName) {
            case "doubleleftarrow" => out.append("M262 157l10-10c34-36 62.7-77 86-123 3.3-8 5-13.3 5-16 0-5.3-6.7-8-20-8-7.3 0-12.2.5-14.5 1.5-2.3 1-4.8 4.5-7.5 10.5-49.3 97.3-121.7 169.3-217 216-28 14-57.3 25-88 33-6.7 2-11 3.8-13 5.5-2 1.7-3 4.2-3 7.5s1 5.8 3 7.5c2 1.7 6.3 3.5 13 5.5 68 17.3 128.2 47.8 180.5 91.5 52.3 43.7 93.8 96.2 124.5 157.5 9.3 8 15.3 12.3 18 13h6c12-.7 18-4 18-10 0-2-1.7-7-5-15-23.3-46-52-87-86-123l-10-10h399738v-40H218c328 0 0 0 0 0l-10-8c-26.7-20-65.7-43-117-69 2.7-2 6-3.7 10-5 36.7-16 72.3-37.3 107-64l10-8h399782v-40z m8 0v40h399730v-40zm0 194v40h399730v-40z")
            case "doublerightarrow" => out.append("M399738 392l-10 10c-34 36-62.7 77-86 123-3.3 8-5 13.3-5 16 0 5.3 6.7 8 20 8 7.3 0 12.2-.5 14.5-1.5 2.3-1 4.8-4.5 7.5-10.5 49.3-97.3 121.7-169.3 217-216 28-14 57.3-25 88-33 6.7-2 11-3.8 13-5.5 2-1.7 3-4.2 3-7.5s-1-5.8-3-7.5c-2-1.7-6.3-3.5-13-5.5-68-17.3-128.2-47.8-180.5-91.5-52.3-43.7-93.8-96.2-124.5-157.5-9.3-8-15.3-12.3-18-13h-6c-12 .7-18 4-18 10 0 2 1.7 7 5 15 23.3 46 52 87 86 123l10 10H0v40h399782c-328 0 0 0 0 0l10 8c26.7 20 65.7 43 117 69-2.7 2-6 3.7-10 5-36.7 16-72.3 37.3-107 64l-10 8H0v40zM0 157v40h399730v-40zm0 194v40h399730v-40z")
            case "leftarrow" => out.append("M400000 241H110l3-3c68.7-52.7 113.7-120 135-202 4-14.7 6-23 6-25 0-7.3-7-11-21-11-8 0-13.2.8-15.5 2.5-2.3 1.7-4.2 5.8-5.5 12.5-1.3 4.7-2.7 10.3-4 17-12 48.7-34.8 92-68.5 130S65.3 228.3 18 247c-10 4-16 7.7-18 11 0 8.7 6 14.3 18 17 47.3 18.7 87.8 47 121.5 85S196 441.3 208 490c.7 2 1.3 5 2 9s1.2 6.7 1.5 8c.3 1.3 1 3.3 2 6s2.2 4.5 3.5 5.5c1.3 1 3.3 1.8 6 2.5s6 1 10 1c14 0 21-3.7 21-11 0-2-2-10.3-6-25-20-79.3-65-146.7-135-202 l-3-3h399890zM100 241v40h399900v-40z")
            case "rightarrow" => out.append("M0 241v40h399891c-47.3 35.3-84 78-110 128-16.7 32-27.7 63.7-33 95 0 1.3-.2 2.7-.5 4-.3 1.3-.5 2.3-.5 3 0 7.3 6.7 11 20 11 8 0 13.2-.8 15.5-2.5 2.3-1.7 4.2-5.5 5.5-11.5 2-13.3 5.7-27 11-41 14.7-44.7 39-84.5 73-119.5s73.7-60.2 119-75.5c6-2 9-5.7 9-11s-3-9-9-11c-45.3-15.3-85-40.5-119-75.5s-58.3-74.8-73-119.5c-4.7-14-8.3-27.3-11-40-1.3-6.7-3.2-10.8-5.5-12.5-2.3-1.7-7.5-2.5-15.5-2.5-14 0-21 3.7-21 11 0 2 2 10.3 6 25 20.7 83.3 67 151.7 139 205zm0 0v40h399900v-40z")
            case "lefthook" => out.append("M400000 281H103s-33-11.2-61-33.5S0 197.3 0 164s14.2-61.2 42.5-83.5C70.8 58.2 104 47 142 47c16.7 0 25 6.7 25 20 0 12-8.7 18.7-26 20-40 3.3-68.7 15.7-86 37-10 12-15 25.3-15 40 0 22.7 9.8 40.7 29.5 54 19.7 13.3 43.5 21 71.5 23h399859zM103 281v-40h399897v40z")
            case "righthook" => out.append("M399859 241c-764 0 0 0 0 0 40-3.3 68.7-15.7 86-37 10-12 15-25.3 15-40 0-22.7-9.8-40.7-29.5-54-19.7-13.3-43.5-21-71.5-23-17.3-1.3-26-8-26-20 0-13.3 8.7-20 26-20 38 0 71 11.2 99 33.5 0 0 7 5.6 21 16.7 14 11.2 21 33.5 21 66.8s-14 61.2-42 83.5c-28 22.3-61 33.5-99 33.5L0 241z M0 281v-40h399859v40z")
            case "leftmapsto" => out.append("M40 281V448H0V74h40v167h399960v40z M40 281V448H0V74h40v167h399960v40z")
            case "twoheadleftarrow" => out.append("M0 167c68 40 115.7 95.7 143 167h22c15.3 0 23-.3 23-1 0-1.3-5.3-13.7-16-37-18-35.3-41.3-69-70-101l-7-8h125l9 7c50.7 39.3 85 86 103 140h46c0-4.7-6.3-18.7-19-42-18-35.3-40-67.3-66-96l-9-9h399716v-40H284l9-9c26-28.7 48-60.7 66-96 12.7-23.333 19-37.333 19-42h-46c-18 54-52.3 100.7-103 140l-9 7H95l7-8c28.7-32 52-65.7 70-101 10.7-23.333 16-35.7 16-37 0-.7-7.7-1-23-1h-22C115.7 71.3 68 127 0 167z")
            case "twoheadrightarrow" => out.append("M400000 167c-68-40-115.7-95.7-143-167h-22c-15.3 0-23 .3-23 1 0 1.3 5.3 13.7 16 37 18 35.3 41.3 69 70 101l7 8h-125l-9-7c-50.7-39.3-85-86-103-140h-46c0 4.7 6.3 18.7 19 42 18 35.3 40 67.3 66 96l9 9H0v40h399716l-9 9c-26 28.7-48 60.7-66 96-12.7 23.333-19 37.333-19 42h46c18-54 52.3-100.7 103-140l9-7h125l-7 8c-28.7 32-52 65.7-70 101-10.7 23.333-16 35.7-16 37 0 .7 7.7 1 23 1h22c27.3-71.3 75-127 143-167z")
            case "leftharpoon" => out.append("M0 267c.7 5.3 3 10 7 14h399993v-40H93c3.3-3.3 10.2-9.5 20.5-18.5s17.8-15.8 22.5-20.5c50.7-52 88-110.3 112-175 4-11.3 5-18.3 3-21-1.3-4-7.3-6-18-6-8 0-13 .7-15 2s-4.7 6.7-8 16c-42 98.7-107.3 174.7-196 228-6.7 4.7-10.7 8-12 10-1.3 2-2 5.7-2 11zm100-26v40h399900v-40z")
            case "rightharpoon" => out.append("M0 241v40h399993c4.7-4.7 7-9.3 7-14 0-9.3-3.7-15.3-11-18-92.7-56.7-159-133.7-199-231-3.3-9.3-6-14.7-8-16-2-1.3-7-2-15-2-10.7 0-16.7 2-18 6-2 2.7-1 9.7 3 21 15.3 42 36.7 81.8 64 119.5 27.3 37.7 58 69.2 92 94.5zm0 0v40h399900v-40z")
            case "leftharpoondown" => out.append("M7 241c-4 4-6.333 8.667-7 14 0 5.333.667 9 2 11s5.333 5.333 12 10c90.667 54 156 130 196 228 3.333 10.667 6.333 16.333 9 17 2 .667 5 1 9 1h5c10.667 0 16.667-2 18-6 2-2.667 1-9.667-3-21-32-87.333-82.667-157.667-152-211l-3-3h399907v-40zM93 281H400000v-40L7 241z")
            case "rightharpoondown" => out.append("M399747 511c0 7.3 6.7 11 20 11 8 0 13-.8 15-2.5s4.7-6.8 8-15.5c40-94 99.3-166.3 178-217 13.3-8 20.3-12.3 21-13 5.3-3.3 8.5-5.8 9.5-7.5 1-1.7 1.5-5.2 1.5-10.5s-2.3-10.3-7-15H0v40h399908c-34 25.3-64.7 57-92 95-27.3 38-48.7 77.7-64 119-3.3 8.7-5 14-5 16zM0 241v40h399900v-40z")
            case "leftharpoonplus" => out.append("M0 267c.7 5.3 3 10 7 14h399993v-40H93c3.3-3.3 10.2-9.5 20.5-18.5s17.8-15.8 22.5-20.5c50.7-52 88-110.3 112-175 4-11.3 5-18.3 3-21-1.3-4-7.3-6-18-6-8 0-13 .7-15 2s-4.7 6.7-8 16c-42 98.7-107.3 174.7-196 228-6.7 4.7-10.7 8-12 10-1.3 2-2 5.7-2 11zm100-26v40h399900v-40zM0 435v40h400000v-40zm0 0v40h400000v-40z")
            case "leftharpoondownplus" => out.append("M7 435c-4 4-6.3 8.7-7 14 0 5.3.7 9 2 11s5.3 5.3 12 10c90.7 54 156 130 196 228 3.3 10.7 6.3 16.3 9 17 2 .7 5 1 9 1h5c10.7 0 16.7-2 18-6 2-2.7 1-9.7-3-21-32-87.3-82.7-157.7-152-211l-3-3h399907v-40H7zm93 0v40h399900v-40zM0 241v40h399900v-40zm0 0v40h399900v-40z")
            case "rightharpoonplus" => out.append("M0 241v40h399993c4.7-4.7 7-9.3 7-14 0-9.3-3.7-15.3-11-18-92.7-56.7-159-133.7-199-231-3.3-9.3-6-14.7-8-16-2-1.3-7-2-15-2-10.7 0-16.7 2-18 6-2 2.7-1 9.7 3 21 15.3 42 36.7 81.8 64 119.5 27.3 37.7 58 69.2 92 94.5zm0 0v40h399900v-40z m100 194v40h399900v-40zm0 0v40h399900v-40z")
            case "rightharpoondownplus" => out.append("M399747 705c0 7.3 6.7 11 20 11 8 0 13-.8 15-2.5s4.7-6.8 8-15.5c40-94 99.3-166.3 178-217 13.3-8 20.3-12.3 21-13 5.3-3.3 8.5-5.8 9.5-7.5 1-1.7 1.5-5.2 1.5-10.5s-2.3-10.3-7-15H0v40h399908c-34 25.3-64.7 57-92 95-27.3 38-48.7 77.7-64 119-3.3 8.7-5 14-5 16zM0 435v40h399900v-40zm0-194v40h400000v-40zm0 0v40h400000v-40z")
            case "leftToFrom" => out.append("M0 147h400000v40H0zm0 214c68 40 115.7 95.7 143 167h22c15.3 0 23-.3 23-1 0-1.3-5.3-13.7-16-37-18-35.3-41.3-69-70-101l-7-8h399905v-40H95l7-8c28.7-32 52-65.7 70-101 10.7-23.3 16-35.7 16-37 0-.7-7.7-1-23-1h-22C115.7 265.3 68 321 0 361zm0-174v-40h399900v40zm100 154v40h399900v-40z")
            case "rightToFrom" => out.append("M400000 167c-70.7-42-118-97.7-142-167h-23c-15.3 0-23 .3-23 1 0 1.3 5.3 13.7 16 37 18 35.3 41.3 69 70 101l7 8H0v40h399905l-7 8c-28.7 32-52 65.7-70 101-10.7 23.3-16 35.7-16 37 0 .7 7.7 1 23 1h23c24-69.3 71.3-125 142-167z M100 147v40h399900v-40zM0 341v40h399900v-40z")
            case "baraboveleftarrow" => out.append("M400000 620h-399890l3-3c68.7-52.7 113.7-120 135-202 4-14.7 6-23 6-25 0-7.3-7-11-21-11-8 0-13.2 0.8-15.5 2.5-2.3 1.7-4.2 5.8-5.5 12.5-1.3 4.7-2.7 10.3-4 17-12 48.7-34.8 92-68.5 130s-74.2 66.3-121.5 85c-10 4-16 7.7-18 11 0 8.7 6 14.3 18 17 47.3 18.7 87.8 47 121.5 85s56.5 81.3 68.5 130c0.7 2 1.3 5 2 9s1.2 6.7 1.5 8c0.3 1.3 1 3.3 2 6s2.2 4.5 3.5 5.5c1.3 1 3.3 1.8 6 2.5s6 1 10 1c14 0 21-3.7 21-11 0-2-2-10.3-6-25-20-79.3-65-146.7-135-202l-3-3h399890zM100 620v40h399900v-40z M0 241v40h399900v-40zM0 241v40h399900v-40z")
            case "rightarrowabovebar" => out.append("M0 241v40h399891c-47.3 35.3-84 78-110 128-16.7 32-27.7 63.7-33 95 0 1.3-.2 2.7-.5 4-.3 1.3-.5 2.3-.5 3 0 7.3 6.7 11 20 11 8 0 13.2-.8 15.5-2.5 2.3-1.7 4.2-5.5 5.5-11.5 2-13.3 5.7-27 11-41 14.7-44.7 39-84.5 73-119.5s73.7-60.2 119-75.5c6-2 9-5.7 9-11s-3-9-9-11c-45.3-15.3-85-40.5-119-75.5s-58.3-74.8-73-119.5c-4.7-14-8.3-27.3-11-40-1.3-6.7-3.2-10.8-5.5-12.5-2.3-1.7-7.5-2.5-15.5-2.5-14 0-21 3.7-21 11 0 2 2 10.3 6 25 20.7 83.3 67 151.7 139 205zm96 379h399894v40H0zm0 0h399904v40H0z")
            case "baraboveshortleftharpoon" => out.append("M507 435c-4 4-6.3 8.7-7 14 0 5.3 0.7 9 2 11 1.3 2 5.3 5.3 12 10 90.7 54 156 130 196 228 3.3 10.7 6.3 16.3 9 17 2 0.7 5 1 9 1 0 0 5 0 5 0 10.7 0 16.7-2 18-6 2-2.7 1-9.7-3-21-32-87.3-82.7-157.7-152-211 0 0-3-3-3-3l399351 0 0-40c-398570 0-399437 0-399437 0z M593 435v40H399500v-40z M0 281v-40H399908v40z M0 281v-40H399908v40z")
            case "rightharpoonaboveshortbar" => out.append("M0 241l0 40c399126 0 399993 0 399993 0 4.7-4.7 7-9.3 7-14 0-9.3-3.7-15.3-11-18-92.7-56.7-159-133.7-199-231-3.3-9.3-6-14.7-8-16-2-1.3-7-2-15-2-10.7 0-16.7 2-18 6-2 2.7-1 9.7 3 21 15.3 42 36.7 81.8 64 119.5 27.3 37.7 58 69.2 92 94.5z M0 241v40H399908v-40z M0 475v-40H399500v40z M0 475v-40H399500v40z")
            case "shortbaraboveleftharpoon" => out.append("M7 435c-4 4-6.3 8.7-7 14 0 5.3 0.7 9 2 11 1.3 2 5.3 5.3 12 10 90.7 54 156 130 196 228 3.3 10.7 6.3 16.3 9 17 2 0.7 5 1 9 1 0 0 5 0 5 0 10.7 0 16.7-2 18-6 2-2.7 1-9.7-3-21-32-87.3-82.7-157.7-152-211 0 0-3-3-3-3l399907 0 0-40c-399126 0-399993 0-399993 0z M93 435v40H400000v-40z M500 241v40H400000v-40z M500 241v40H400000v-40z")
            case "shortrightharpoonabovebar" => out.append("M53 241l0 40c398570 0 399437 0 399437 0 4.7-4.7 7-9.3 7-14 0-9.3-3.7-15.3-11-18-92.7-56.7-159-133.7-199-231-3.3-9.3-6-14.7-8-16-2-1.3-7-2-15-2-10.7 0-16.7 2-18 6-2 2.7-1 9.7 3 21 15.3 42 36.7 81.8 64 119.5 27.3 37.7 58 69.2 92 94.5z M500 241v40H399408v-40z M500 435v40H400000v-40z")
            case _ => out.append("M0 241v40h399891c-47.3 35.3-84 78-110 128-16.7 32-27.7 63.7-33 95 0 1.3-.2 2.7-.5 4-.3 1.3-.5 2.3-.5 3 0 7.3 6.7 11 20 11 8 0 13.2-.8 15.5-2.5 2.3-1.7 4.2-5.5 5.5-11.5 2-13.3 5.7-27 11-41 14.7-44.7 39-84.5 73-119.5s73.7-60.2 119-75.5c6-2 9-5.7 9-11s-3-9-9-11c-45.3-15.3-85-40.5-119-75.5s-58.3-74.8-73-119.5c-4.7-14-8.3-27.3-11-40-1.3-6.7-3.2-10.8-5.5-12.5-2.3-1.7-7.5-2.5-15.5-2.5-14 0-21 3.7-21 11 0 2 2 10.3 6 25 20.7 83.3 67 151.7 139 205zm0 0v40h399900v-40z")
        }
    }

    private func appendHorizontalPairAccentSvg(name: String, out: StringBuilder): Unit {
        let height = horizontalPairHeight(name)
        let minWidth = horizontalPairMinWidth(name)
        let viewBoxHeight = horizontalPairViewBoxHeight(name)
        out.append("<span class=\"stretchy\" style=\"height:")
        out.append(height)
        out.append(";min-width:")
        out.append(minWidth)
        out.append(";\"><span class=\"halfarrow-left\" style=\"height:")
        out.append(height)
        out.append(";\">")
        appendHorizontalPairPartSvg(name, true, viewBoxHeight, height, out)
        out.append("</span><span class=\"halfarrow-right\" style=\"height:")
        out.append(height)
        out.append(";\">")
        appendHorizontalPairPartSvg(name, false, viewBoxHeight, height, out)
        out.append("</span></span>")
    }

    private func appendHorizontalPairPartSvg(name: String, left: Bool, viewBoxHeight: String, height: String, out: StringBuilder): Unit {
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"")
        out.append(height)
        out.append("\" viewBox=\"0 0 400000 ")
        out.append(viewBoxHeight)
        out.append("\" preserveAspectRatio=\"")
        out.append(if (left) { "xMinYMin" } else { "xMaxYMin" })
        out.append(" slice\"><path d=\"")
        if (name == "overbracket") {
            out.append(if (left) { "M0 440 h120 V150 H399995 v-120 H0z M0 440 h120 V150 H399995 v-120 H0z" } else { "M399995 440 h-120 V150 H0 v-120 H399995z M399995 440 h-120 V150 H0 v-120 H399995z" })
        } else if (name == "underbracket") {
            out.append(if (left) { "M0 0 h120 V290 H399995 v120 H0z M0 0 h120 V290 H399995 v120 H0z" } else { "M399995 0 h-120 V290 H0 v120 H400000z M399995 0 h-120 V290 H0 v120 H400000z" })
        } else if (name == "overgroup") {
            out.append(if (left) { "M400000 80H435C64 80 168.3 229.4 21 260c-5.9 1.2-18 0-18 0-2 0-3-1-3-3v-38C76 61 257 0 435 0h399565z" } else { "M0 80h399565c371 0 266.7 149.4 414 180 5.9 1.2 18 0 18 0 2 0 3-1 3-3v-38c-76-158-257-219-435-219H0z" })
        } else if (name == "undergroup") {
            out.append(if (left) { "M400000 262H435C64 262 168.3 112.6 21 82c-5.9-1.2-18 0-18 0-2 0-3 1-3 3v38c76 158 257 219 435 219h399565z" } else { "M0 262h399565c371 0 266.7-149.4 414-180 5.9-1.2 18 0 18 0 2 0 3 1 3 3v38c-76 158-257 219-435 219H0z" })
        } else {
            out.append(if (left) { "M40 281 V428 H0 V94 H40 V241 H400000 v40z M40 281 V428 H0 V94 H40 V241 H400000 v40z" } else { "M399960 241 V94 h40 V428 h-40 V281 H0 v-40z M399960 241 V94 h40 V428 h-40 V281 H0 v-40z" })
        }
        out.append("\"/></svg>")
    }

    private func appendStretchySvg(name: String, out: StringBuilder, xArrow: Bool): Unit {
        let minWidth = if (xArrow) { xArrowMinWidth(name) } else { "0.888em" }
        let height = stretchySvgHeight(name)
        if (isTwoPartStretchy(name)) {
            out.append("<span class=\"stretchy\" style=\"height:")
            out.append(height)
            out.append(";min-width:")
            out.append(minWidth)
            out.append(";\"><span class=\"halfarrow-left\" style=\"height:")
            out.append(height)
            out.append(";\">")
            appendLeftStretchyPartSvg(name, out)
            out.append("</span><span class=\"halfarrow-right\" style=\"height:")
            out.append(height)
            out.append(";\">")
            appendRightStretchyPartSvg(name, out)
            out.append("</span></span>")
            return
        }
        if (name == "overleftrightarrow" || name == "underleftrightarrow" || name == "xleftrightarrow" || name == "xLeftrightarrow") {
            out.append("<span class=\"stretchy\" style=\"height:")
            out.append(height)
            out.append(";min-width:")
            out.append(minWidth)
            out.append(";\"><span class=\"halfarrow-left\" style=\"height:")
            out.append(height)
            out.append(";\">")
            appendLeftArrowSvg(out)
            out.append("</span><span class=\"halfarrow-right\" style=\"height:")
            out.append(height)
            out.append(";\">")
            appendRightArrowSvg(out)
            out.append("</span></span>")
            return
        }
        if (name == "xlongequal") {
            out.append("<span class=\"hide-tail\" style=\"height:0.334em;min-width:")
            out.append(minWidth)
            out.append(";\">")
            appendLongEqualSvg(out)
            out.append("</span>")
            return
        }
        out.append("<span class=\"hide-tail\" style=\"height:")
        out.append(height)
        out.append(";min-width:")
        out.append(minWidth)
        out.append(";\">")
        appendSingleStretchySvg(name, out)
        out.append("</span>")
    }

    private func appendBraceSvg(out: StringBuilder, under: Bool): Unit {
        if (under) {
            out.append("<span class=\"brace-left\" style=\"height:0.548em;\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMinYMin slice\"><path d=\"M0 6l6-6h17c12.688 0 19.313.3 20 1 4 4 7.313 8.3 10 13 35.313 51.3 80.813 93.8 136.5 127.5 55.688 33.7 117.188 55.8 184.5 66.5.688 0 2 .3 4 1 18.688 2.7 76 4.3 172 5h399450v120H429l-6-1c-124.688-8-235-61.7-331-161C60.687 138.7 32.312 99.3 7 54L0 41V6z\"/></svg></span>")
            out.append("<span class=\"brace-center\" style=\"height:0.548em;\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMidYMin slice\"><path d=\"M199572 214c100.7 8.3 195.3 44 280 108 55.3 42 101.7 93 139 153l9 14c2.7-4 5.7-8.7 9-14 53.3-86.7 123.7-153 211-199 66.7-36 137.3-56.3 212-62h199568v120H200432c-178.3 11.7-311.7 78.3-403 201-6 8-9.7 12-11 12-.7.7-6.7 1-18 1s-17.3-.3-18-1c-1.3 0-5-4-11-12-44.7-59.3-101.3-106.3-170-141s-145.3-54.3-229-60H0V214z\"/></svg></span>")
            out.append("<span class=\"brace-right\" style=\"height:0.548em;\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMaxYMin slice\"><path d=\"M399994 0l6 6v35l-6 11c-56 104-135.3 181.3-238 232-57.3 28.7-117 45-179 50H-300V214h399897c43.3-7 81-15 113-26 100.7-33 179.7-91 237-174 2.7-5 6-9 10-13 .7-1 7.3-1 20-1h17z\"/></svg></span>")
            return
        }
        out.append("<span class=\"brace-left\" style=\"height:0.548em;\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMinYMin slice\"><path d=\"M6 548l-6-6v-35l6-11c56-104 135.3-181.3 238-232 57.3-28.7 117-45 179-50h399577v120H403c-43.3 7-81 15-113 26-100.7 33-179.7 91-237 174-2.7 5-6 9-10 13-.7 1-7.3 1-20 1H6z\"/></svg></span>")
        out.append("<span class=\"brace-center\" style=\"height:0.548em;\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMidYMin slice\"><path d=\"M200428 334c-100.7-8.3-195.3-44-280-108-55.3-42-101.7-93-139-153l-9-14c-2.7 4-5.7 8.7-9 14-53.3 86.7-123.7 153-211 199-66.7 36-137.3 56.3-212 62H0V214h199568c178.3-11.7 311.7-78.3 403-201 6-8 9.7-12 11-12 .7-.7 6.7-1 18-1s17.3.3 18 1c1.3 0 5 4 11 12 44.7 59.3 101.3 106.3 170 141s145.3 54.3 229 60h199572v120z\"/></svg></span>")
        out.append("<span class=\"brace-right\" style=\"height:0.548em;\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"0.548em\" viewBox=\"0 0 400000 548\" preserveAspectRatio=\"xMaxYMin slice\"><path d=\"M400000 542l-6 6h-17c-12.7 0-19.3-.3-20-1-4-4-7.3-8.3-10-13-35.3-51.3-80.8-93.8-136.5-127.5s-117.2-55.8-184.5-66.5c-.7 0-2-.3-4-1-18.7-2.7-76-4.3-172-5H0V214h399571l6 1c124.7 8 235 61.7 331 161 31.3 33.3 59.7 72.7 85 118l7 13v35z\"/></svg></span>")
    }

    private func appendSqrtSvg(out: StringBuilder, tall: Bool): Unit {
        if (tall) {
            out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"1.28em\" viewBox=\"0 0 400000 1296\" preserveAspectRatio=\"xMinYMin slice\"><path d=\"M263,681c0.7,0,18,39.7,52,119c34,79.3,68.167,158.7,102.5,238c34.3,79.3,51.8,119.3,52.5,120c340,-704.7,510.7,-1060.3,512,-1067l0 -0c4.7,-7.3,11,-11,19,-11H40000v40H1012.3s-271.3,567,-271.3,567c-38.7,80.7,-84,175,-136,283c-52,108,-89.167,185.3,-111.5,232c-22.3,46.7,-33.8,70.3,-34.5,71c-4.7,4.7,-12.3,7,-23,7s-12,-1,-12,-1s-109,-253,-109,-253c-72.7,-168,-109.3,-252,-110,-252c-10.7,8,-22,16.7,-34,26c-22,17.3,-33.3,26,-34,26s-26,-26,-26,-26s76,-59,76,-59s76,-60,76,-60zM1001 80h400000v40h-400000z\"/></svg>")
            return
        }
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"1.08em\" viewBox=\"0 0 400000 1080\" preserveAspectRatio=\"xMinYMin slice\"><path d=\"M95,702c-2.7,0,-7.17,-2.7,-13.5,-8c-5.8,-5.3,-9.5,-10,-9.5,-14c0,-2,0.3,-3.3,1,-4c1.3,-2.7,23.83,-20.7,67.5,-54c44.2,-33.3,65.8,-50.3,66.5,-51c1.3,-1.3,3,-2,5,-2c4.7,0,8.7,3.3,12,10s173,378,173,378c0.7,0,35.3,-71,104,-213c68.7,-142,137.5,-285,206.5,-429c69,-144,104.5,-217.7,106.5,-221l0 -0c5.3,-9.3,12,-14,20,-14H400000v40H845.2724s-225.272,467,-225.272,467s-235,486,-235,486c-2.7,4.7,-9,7,-19,7c-6,0,-10,-1,-12,-3s-194,-422,-194,-422s-65,47,-65,47zM834 80h400000v40h-400000z\"/></svg>")
    }

    private func appendCancelSvg(name: String, out: StringBuilder): Unit {
        if (name == "bcancel") {
            out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" height=\"0.8306em\"><line x1=\"0\" y1=\"0\" x2=\"100%\" y2=\"100%\" stroke-width=\"0.046em\"/></svg>")
            return
        }
        if (name == "xcancel") {
            out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" height=\"0.8306em\"><line x1=\"0\" y1=\"100%\" x2=\"100%\" y2=\"0\" stroke-width=\"0.046em\"/><line x1=\"0\" y1=\"0\" x2=\"100%\" y2=\"100%\" stroke-width=\"0.046em\"/></svg>")
            return
        }
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" height=\"0.8306em\"><line x1=\"0\" y1=\"100%\" x2=\"100%\" y2=\"0\" stroke-width=\"0.046em\"/></svg>")
    }

    private func maxColumnCount(environment: MathEnvironmentNode): Int64 {
        var count: Int64 = 0
        for (row in environment.rows) {
            if (row.size > count) {
                count = row.size
            }
        }
        return count
    }

    private func writeSequenceWithBases(children: Array<MathNode>, out: StringBuilder, prefix: String, errorColor: String): Unit {
        var baseStart: Int64 = 0
        var index: Int64 = 0
        while (index < children.size) {
            if (let symbol: MathSymbolNode <- children[index]) {
                if ((symbol.family == "bin" || symbol.family == "rel") && index + 1 < children.size) {
                    writeBaseOpen(baseStrutForRange(children, baseStart, index + 1), out)
                    writeSequenceChildrenRange(children, baseStart, index + 1, out, prefix, errorColor)
                    out.append("</span>")
                    baseStart = index + 1
                }
            }
            index += 1
        }
        if (baseStart < children.size) {
            writeBaseOpen(baseStrutForRange(children, baseStart, children.size), out)
            writeSequenceChildrenRange(children, baseStart, children.size, out, prefix, errorColor)
            out.append("</span>")
        }
    }

    private func writeBaseOpen(strut: String, out: StringBuilder): Unit {
        out.append("<span class=\"base\"><span class=\"strut\" style=\"")
        out.append(strut)
        out.append("\"></span>")
    }

    private func baseStrutForRange(children: Array<MathNode>, start: Int64, end: Int64): String {
        var hasDisplayFraction = false
        var hasTall = false
        var hasInlineLimits = false
        var lastFamily = ""
        for (index in start..end) {
            if (containsFraction(children[index])) {
                hasTall = true
                if (containsDisplayStyle(children[index])) {
                    hasDisplayFraction = true
                }
            }
            if (containsTallLayout(children[index])) {
                hasTall = true
            }
            if (containsOperatorLimits(children[index])) {
                hasInlineLimits = true
            }
            if (let symbol: MathSymbolNode <- children[index]) {
                lastFamily = symbol.family
            }
        }
        if (hasDisplayFraction || (currentStyle == "display" && hasTall)) {
            return "height:1.7936em;vertical-align:-0.686em;"
        }
        if (hasInlineLimits) {
            return "height:2.3291em;vertical-align:-0.9777em;"
        }
        if (lastFamily == "bin") {
            return "height:0.6667em;vertical-align:-0.0833em;"
        }
        if (lastFamily == "rel") {
            return "height:0.625em;vertical-align:-0.1944em;"
        }
        if (hasTall) {
            return "height:1.0404em;vertical-align:-0.345em;"
        }
        return "height:0.6444em;"
    }

    private func baseStrutForNode(node: MathNode): String {
        if (containsDisplayStyle(node) && containsFraction(node)) {
            return "height:1.7936em;vertical-align:-0.686em;"
        }
        if (containsTallLayout(node)) {
            return "height:1.0404em;vertical-align:-0.345em;"
        }
        return "height:0.6444em;"
    }

    private func writeSequenceChildren(children: Array<MathNode>, out: StringBuilder, prefix: String, errorColor: String): Unit {
        writeSequenceChildrenRange(children, 0, children.size, out, prefix, errorColor)
    }

    private func writeSequenceChildrenRange(children: Array<MathNode>, start: Int64, end: Int64, out: StringBuilder, prefix: String, errorColor: String): Unit {
        for (index in 0..children.size) {
            if (index < start || index >= end) {
                continue
            }
            if (index > start && !isSymbolNode(children[index - 1])) {
                let pairSpacing = atomPairSpacing(children[index - 1], children[index])
                if (!pairSpacing.isEmpty()) {
                    writeMspace(pairSpacing, out)
                }
            }
            if (let symbol: MathSymbolNode <- children[index]) {
                if (isMacroArrowWithExtraSpacing(symbol) && index > start) {
                    writeMspace("0.2778em", out)
                }
                writeNode(symbol, out, prefix, errorColor)
                if (isMacroArrowWithExtraSpacing(symbol) && index + 1 < end) {
                    writeMspace("0.2778em", out)
                }
                if (index + 1 < children.size) {
                    let rightSpacing = atomPairSpacing(children[index], children[index + 1])
                    if (!rightSpacing.isEmpty()) {
                        writeMspace(rightSpacing, out)
                    }
                }
                continue
            }
            writeNode(children[index], out, prefix, errorColor)
        }
    }

    private func containsTallLayout(node: MathNode): Bool {
        if (let _: MathFractionNode <- node) {
            return true
        }
        if (let _: MathSqrtNode <- node) {
            return true
        }
        if (let _: MathEnvironmentNode <- node) {
            return true
        }
        for (child in node.children) {
            if (containsTallLayout(child)) {
                return true
            }
        }
        return false
    }

    private func containsFraction(node: MathNode): Bool {
        if (let _: MathFractionNode <- node) {
            return true
        }
        for (child in node.children) {
            if (containsFraction(child)) {
                return true
            }
        }
        return false
    }

    private func containsOperatorLimits(node: MathNode): Bool {
        if (let script: MathSupSubNode <- node) {
            if (shouldUseOperatorLimits(script)) {
                return true
            }
        }
        for (child in node.children) {
            if (containsOperatorLimits(child)) {
                return true
            }
        }
        return false
    }

    private func containsDisplayStyle(node: MathNode): Bool {
        if (let sizing: MathSizingNode <- node) {
            if (sizing.size == "display") {
                return true
            }
        }
        for (child in node.children) {
            if (containsDisplayStyle(child)) {
                return true
            }
        }
        return false
    }

    private func writeAlignedCell(node: MathNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        if (startsWithRelation(node)) {
            out.append("<span class=\"mord\"></span>")
            writeMspace("0.2778em", out)
        }
        writeNode(node, out, prefix, errorColor)
    }

    private func startsWithRelation(node: MathNode): Bool {
        if (let symbol: MathSymbolNode <- node) {
            return symbol.family == "rel"
        }
        if (let sequence: MathSequenceNode <- node) {
            if (sequence.children.size == 0) {
                return false
            }
            return startsWithRelation(sequence.children[0])
        }
        if (let group: MathGroupNode <- node) {
            if (group.children.size == 0) {
                return false
            }
            return startsWithRelation(group.children[0])
        }
        return false
    }

    private func writeMspace(width: String, out: StringBuilder): Unit {
        out.append("<span class=\"mspace\" style=\"margin-right:")
        out.append(width)
        out.append(";\"></span>")
    }

    private func spacingCommandWidth(literal: String): String {
        match (literal) {
            case "\\," | "\\thinspace" => return "0.1667em"
            case "\\:" | "\\medspace" => return "0.2222em"
            case "\\;" | "\\thickspace" => return "0.2778em"
            case "\\quad" => return "1em"
            case "\\qquad" => return "2em"
            case "\\enspace" => return "0.5em"
            case "\\!" | "\\negthinspace" => return "-0.1667em"
            case "\\negmedspace" => return "-0.2222em"
            case "\\negthickspace" => return "-0.2778em"
            case _ => return ""
        }
    }

    private func atomPairSpacing(left: MathNode, right: MathNode): String {
        let leftFamily = atomFamily(left)
        let rightFamily = atomFamily(right)
        if (leftFamily == "none" || rightFamily == "none") {
            return ""
        }
        if (leftFamily == "op" && shouldSpaceAfterOperator(right)) {
            return "0.1667em"
        }
        if (rightFamily == "bin" && leftFamily != "open" && leftFamily != "bin" && leftFamily != "rel" && leftFamily != "punct") {
            return "0.2222em"
        }
        if (leftFamily == "bin" && rightFamily != "close" && rightFamily != "punct" && rightFamily != "rel") {
            return "0.2222em"
        }
        if (rightFamily == "rel" && leftFamily != "open") {
            return "0.2778em"
        }
        if (leftFamily == "rel" && rightFamily != "close" && rightFamily != "punct") {
            return "0.2778em"
        }
        return ""
    }

    private func atomFamily(node: MathNode): String {
        if (let symbol: MathSymbolNode <- node) {
            return symbol.family
        }
        if (isOperatorWithScripts(node)) {
            return "op"
        }
        if (let _: MathDelimitedNode <- node) {
            return "inner"
        }
        if (let command: MathCommandNode <- node) {
            if (isXArrowCommand(command.name)) {
                return "rel"
            }
        }
        if (let _: MathFractionNode <- node) {
            return "inner"
        }
        if (let _: MathSqrtNode <- node) {
            return "inner"
        }
        if (let _: MathEnvironmentNode <- node) {
            return "inner"
        }
        return "ord"
    }

    private func isSymbolNode(node: MathNode): Bool {
        if (let _: MathSymbolNode <- node) {
            return true
        }
        return false
    }

    private func isMathStyle(size: String): Bool {
        return size == "display" || size == "text" || size == "script" || size == "scriptscript"
    }

    private func isTightStyle(): Bool {
        return currentStyle == "script" || currentStyle == "scriptscript" || crampedDepth > 0
    }

    private func styleSizingClass(size: String): String {
        if (size == "display") {
            return ""
        }
        if (size == "text") {
            return ""
        }
        if (size == "script") {
            return " mtight sizing reset-size6 size3"
        }
        if (size == "scriptscript") {
            return " mtight sizing reset-size6 size1"
        }
        return ""
    }

    private func shouldUseMathNormal(symbol: MathSymbolNode): Bool {
        return symbol.family == "ord" && (isAsciiLettersOnly(symbol.value) || isGreekMathLetter(symbol.value))
    }

    private func isGreekMathLetter(value: String): Bool {
        match (value) {
            case "α" | "β" | "γ" | "δ" | "ϵ" | "ζ" | "η" | "θ" | "ι" | "κ" | "λ" | "μ" |
                "ν" | "ξ" | "ο" | "π" | "ρ" | "σ" | "τ" | "υ" | "ϕ" | "χ" | "ψ" | "ω" |
                "ε" | "ϑ" | "ϖ" | "φ" | "ς" => return true
            case _ => return false
        }
    }

    private func mathnormalItalicCorrection(value: String): String {
        match (value) {
            case "α" => return "0.0037em"
            case "β" => return "0.0528em"
            case "γ" => return "0.0556em"
            case _ => return ""
        }
    }

    private func shouldSpaceAfterOperator(next: MathNode): Bool {
        if (let symbol: MathSymbolNode <- next) {
            return symbol.family == "ord"
        }
        if (let _: MathSupSubNode <- next) {
            return true
        }
        if (let _: MathGroupNode <- next) {
            return true
        }
        return false
    }

    private func isOperatorWithScripts(node: MathNode): Bool {
        if (let script: MathSupSubNode <- node) {
            if (let symbol: MathSymbolNode <- script.base) {
                return symbol.family == "op"
            }
        }
        return false
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

    private func isIntegralOperator(node: MathNode): Bool {
        if (let limits: MathLimitsNode <- node) {
            return isIntegralOperator(limits.base)
        }
        if (let symbol: MathSymbolNode <- node) {
            return symbol.value == "∫" || symbol.value == "∫∫" || symbol.value == "∫∫∫"
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

    private func isTextOperatorScript(script: MathSupSubNode): Bool {
        if (let limits: MathLimitsNode <- script.base) {
            if (let symbol: MathSymbolNode <- limits.base) {
                return symbol.family == "op" && isAsciiLettersOnly(symbol.value)
            }
            return false
        }
        if (let symbol: MathSymbolNode <- script.base) {
            return symbol.family == "op" && isAsciiLettersOnly(symbol.value)
        }
        return false
    }

    private func isDefaultLimitsOperator(value: String): Bool {
        match (value) {
            case "∑" | "∏" | "∐" | "lim" | "lim sup" | "lim inf" => return true
            case _ => return false
        }
    }

    private func isAsciiLettersOnly(value: String): Bool {
        if (value.isEmpty()) {
            return false
        }
        for (ch in value) {
            if (!((ch >= b'a' && ch <= b'z') || (ch >= b'A' && ch <= b'Z'))) {
                return false
            }
        }
        return true
    }

    private func needsTallSqrt(node: MathNode): Bool {
        if (let _: MathSupSubNode <- node) {
            return true
        }
        if (let _: MathFractionNode <- node) {
            return true
        }
        if (let _: MathEnvironmentNode <- node) {
            return true
        }
        if (let _: MathSqrtNode <- node) {
            return true
        }
        for (child in node.children) {
            if (needsTallSqrt(child)) {
                return true
            }
        }
        return false
    }

    private func isAlignedEnvironment(name: String): Bool {
        return name == "aligned" || name == "alignedat" || name == "align" || name == "align*" ||
            name == "alignat" || name == "alignat*" || name == "split"
    }

    private func writeArrayVerticalSeparators(environment: MathEnvironmentNode, boundary: Int64, out: StringBuilder): Unit {
        if (environment.name != "array" || boundary >= environment.columnSeparatorCounts.size) {
            return
        }
        let count = environment.columnSeparatorCounts[boundary]
        for (_ in 0..count) {
            out.append("<span class=\"vertical-separator\" style=\"height:")
            out.append(environmentVlistHeight(environment.name, environment.rows.size))
            out.append("em;border-right-width:0.04em;\"></span>")
        }
    }

    private func environmentColumnClass(environment: MathEnvironmentNode, col: Int64): String {
        let name = environment.name
        if (isCasesEnvironment(name)) {
            return "col-align-l"
        }
        if (environment.columnAlignments.size > 0) {
            let alignment = if (col < environment.columnAlignments.size) {
                environment.columnAlignments[col]
            } else if (isMatrixStarEnvironment(name)) {
                environment.columnAlignments[0]
            } else {
                "c"
            }
            match (alignment) {
                case "l" => return "col-align-l"
                case "r" => return "col-align-r"
                case _ => return "col-align-c"
            }
        }
        if (isAlignedEnvironment(name)) {
            if (col % 2 == 0) {
                return "col-align-r"
            }
            return "col-align-l"
        }
        return "col-align-c"
    }

    private func environmentRowTop(name: String, rowIndex: Int64): String {
        if (isSmallEnvironment(name)) {
            return (-3.18 + Float64(rowIndex) * 0.8).toString()
        }
        if (isCasesEnvironment(name)) {
            if (rowIndex == 0) {
                return "-3.69"
            }
            if (rowIndex == 1) {
                return "-2.25"
            }
            return (-3.69 + Float64(rowIndex) * 1.44).toString()
        }
        if (isAlignedEnvironment(name)) {
            if (rowIndex == 0) {
                return "-3.76"
            }
            if (rowIndex == 1) {
                return "-2.26"
            }
            return (-3.76 + Float64(rowIndex) * 1.5).toString()
        }
        if (isMatrixLikeEnvironment(name)) {
            if (rowIndex == 0) {
                return "-4.21"
            }
            if (rowIndex == 1) {
                return "-3.01"
            }
            if (rowIndex == 2) {
                return "-1.81"
            }
            return (-4.21 + Float64(rowIndex) * 1.2).toString()
        }
        return (-3.61 + Float64(rowIndex) * 1.2).toString()
    }

    private func environmentVlistHeight(name: String, rows: Int64): String {
        if (isSmallEnvironment(name)) {
            if (rows <= 2) {
                return "0.98"
            }
            if (rows == 3) {
                return "1.78"
            }
            let extraRows = if (rows > 2) { rows - 2 } else { 0 }
            return (0.98 + Float64(extraRows) * 0.8).toString()
        }
        if (isCasesEnvironment(name)) {
            if (rows <= 2) {
                return "1.69"
            }
            if (rows == 3) {
                return "3.13"
            }
            let extraRows = if (rows > 2) { rows - 2 } else { 0 }
            return (1.69 + Float64(extraRows) * 1.44).toString()
        }
        if (isAlignedEnvironment(name)) {
            if (rows <= 2) {
                return "1.6"
            }
            if (rows == 3) {
                return "3.1"
            }
            let extraRows = if (rows > 2) { rows - 2 } else { 0 }
            return (1.6 + Float64(extraRows) * 1.5).toString()
        }
        if (isMatrixLikeEnvironment(name)) {
            if (rows <= 2) {
                return "1.45"
            }
            if (rows == 3) {
                return "2.05"
            }
            let extraRows = if (rows > 3) { rows - 3 } else { 0 }
            return (2.05 + Float64(extraRows) * 1.2).toString()
        }
        return "1.45"
    }

    private func environmentDepth(name: String): String {
        if (isSmallEnvironment(name)) {
            return "0.38"
        }
        if (isCasesEnvironment(name)) {
            return "1.19"
        }
        if (isAlignedEnvironment(name)) {
            return "1.1"
        }
        if (isMatrixLikeEnvironment(name)) {
            return "1.55"
        }
        return "0.95"
    }

    private func environmentDelimiterSize(name: String): String {
        if (isCasesEnvironment(name)) {
            return "size4"
        }
        return "size3"
    }

    private func isCasesEnvironment(name: String): Bool {
        return name == "cases" || name == "rcases"
    }

    private func isDoubleVerticalMatrixEnvironment(name: String): Bool {
        return name == "Vmatrix" || name == "Vmatrix*"
    }

    private func isSquareBracketMatrixEnvironment(name: String): Bool {
        return name == "bmatrix" || name == "bmatrix*"
    }

    private func isMatrixStarEnvironment(name: String): Bool {
        return name == "matrix*" || name == "pmatrix*" || name == "bmatrix*" || name == "Bmatrix*" ||
            name == "vmatrix*" || name == "Vmatrix*"
    }

    private func isMatrixLikeEnvironment(name: String): Bool {
        return name == "matrix" || name == "pmatrix" || name == "bmatrix" || name == "Bmatrix" ||
            name == "vmatrix" || name == "Vmatrix" || isMatrixStarEnvironment(name)
    }

    private func environmentPstrutHeight(name: String): String {
        if (isSmallEnvironment(name)) {
            return "2.4"
        }
        if (isCasesEnvironment(name)) {
            return "3.008"
        }
        return "3"
    }

    private func environmentColumnSep(name: String): String {
        if (isSmallEnvironment(name)) {
            return "0.2778em"
        }
        return "0.5em"
    }

    private func isSmallEnvironment(name: String): Bool {
        return name == "smallmatrix" || name == "subarray"
    }

    private func writeChildren(node: MathNode, out: StringBuilder, prefix: String, errorColor: String): Unit {
        for (child in node.children) {
            writeNode(child, out, prefix, errorColor)
        }
    }

    private func writeTextNodeValue(node: MathNode, out: StringBuilder): Unit {
        if (let text: MathTextNode <- node) {
            out.append(HtmlEscaper.escapeAttribute(text.text))
            return
        }
        out.append(HtmlEscaper.escapeAttribute(node.literal))
    }

    private func writeOperatorNameText(node: MathNode, out: StringBuilder): Unit {
        if (let text: MathTextNode <- node) {
            out.append(HtmlEscaper.escapeText(text.text))
            return
        }
        if (let symbol: MathSymbolNode <- node) {
            out.append(HtmlEscaper.escapeText(symbol.value))
            return
        }
        if (let sequence: MathSequenceNode <- node) {
            for (child in sequence.children) {
                writeOperatorNameText(child, out)
            }
            return
        }
        if (let group: MathGroupNode <- node) {
            for (child in group.children) {
                writeOperatorNameText(child, out)
            }
            return
        }
        out.append(HtmlEscaper.escapeText(node.literal))
    }

    private func isFontCommand(name: String): Bool {
        return name == "mathrm" || name == "mathbb" || name == "mathit" || name == "mathnormal" ||
            name == "mathcal" || name == "mathfrak" || name == "mathsf" || name == "mathtt" ||
            name == "mathbf" || name == "boldsymbol" || name == "pmb" ||
            name == "textbf" || name == "textit" || name == "textup" || name == "textmd" ||
            name == "textsf" || name == "texttt" || name == "emph" || name == "hbox"
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

    private func isStretchyOverAccent(name: String): Bool {
        return name == "widehat" || name == "widecheck" || name == "widetilde" || name == "overrightarrow" ||
            name == "overleftarrow" || name == "overleftrightarrow" || name == "Overrightarrow" ||
            name == "overgroup" || name == "overlinesegment" || name == "overleftharpoon" ||
            name == "overrightharpoon" || name == "overbrace" || name == "overbracket"
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

    private func isArrowStretchy(name: String): Bool {
        return name == "overrightarrow" || name == "overleftarrow" || name == "overleftrightarrow" ||
            name == "Overrightarrow" || name == "underrightarrow" || name == "underleftarrow" ||
            name == "underleftrightarrow" || name == "overleftharpoon" || name == "overrightharpoon"
    }

    private func isHorizontalPairAccent(name: String): Bool {
        return name == "overbracket" || name == "underbracket" || name == "overgroup" ||
            name == "undergroup" || name == "overlinesegment" || name == "underlinesegment"
    }

    private func stretchyHeight(name: String): String {
        if (name == "widetilde") {
            return "0.286em"
        }
        if (isArrowStretchy(name)) {
            return stretchySvgHeight(name)
        }
        return "0.3em"
    }

    private func horizontalPairHeight(name: String): String {
        if (name == "overbracket") {
            return "0.44em"
        }
        if (name == "underbracket") {
            return "0.41em"
        }
        if (name == "overgroup" || name == "undergroup") {
            return "0.342em"
        }
        return "0.522em"
    }

    private func horizontalPairViewBoxHeight(name: String): String {
        if (name == "overbracket") {
            return "440"
        }
        if (name == "underbracket") {
            return "410"
        }
        if (name == "overgroup" || name == "undergroup") {
            return "342"
        }
        return "522"
    }

    private func horizontalPairMinWidth(name: String): String {
        if (name == "overbracket" || name == "underbracket") {
            return "1.6em"
        }
        return "0.888em"
    }

    private func xArrowMinWidth(name: String): String {
        if (name == "xleftrightarrow" || name == "xLeftrightarrow") {
            return "1.75em"
        }
        if (name == "xrightleftharpoons" || name == "xleftrightharpoons" || name == "xtofrom" ||
            name == "xrightleftarrows" || name == "xrightequilibrium" || name == "xleftequilibrium") {
            return "1.75em"
        }
        if (name == "xhookleftarrow" || name == "xhookrightarrow") {
            return "1.08em"
        }
        if (name == "xmapsto") {
            return "1.5em"
        }
        if (name == "xlongequal") {
            return "0.888em"
        }
        if (name == "xLeftarrow" || name == "xRightarrow") {
            return "1.526em"
        }
        return "1.469em"
    }

    private func stretchySvgHeight(name: String): String {
        if (name == "xlongequal" || name == "xtwoheadleftarrow" || name == "xtwoheadrightarrow") {
            return "0.334em"
        }
        if (name == "xLeftarrow" || name == "xRightarrow" || name == "xLeftrightarrow" || name == "Overrightarrow") {
            return "0.56em"
        }
        if (name == "xrightleftharpoons" || name == "xleftrightharpoons" ||
            name == "xrightequilibrium" || name == "xleftequilibrium") {
            return "0.716em"
        }
        if (name == "xrightleftarrows") {
            return "0.901em"
        }
        if (name == "xtofrom") {
            return "0.528em"
        }
        return "0.522em"
    }

    private func isTwoPartStretchy(name: String): Bool {
        return name == "xhookleftarrow" || name == "xhookrightarrow" || name == "xmapsto" ||
            name == "xrightleftharpoons" || name == "xleftrightharpoons" || name == "xtofrom" ||
            name == "xrightleftarrows" || name == "xrightequilibrium" || name == "xleftequilibrium"
    }

    private func isStackedXArrow(name: String): Bool {
        return name == "xrightleftharpoons" || name == "xleftrightharpoons" || name == "xtofrom" ||
            name == "xrightleftarrows" || name == "xrightequilibrium" || name == "xleftequilibrium"
    }

    private func appendLeftStretchyPartSvg(name: String, out: StringBuilder): Unit {
        let height = stretchySvgHeight(name)
        appendNamedStretchySvg(leftStretchyPathName(name), height, svgViewBoxHeight(name), "xMinYMin", out)
    }

    private func appendRightStretchyPartSvg(name: String, out: StringBuilder): Unit {
        let height = stretchySvgHeight(name)
        appendNamedStretchySvg(rightStretchyPathName(name), height, svgViewBoxHeight(name), "xMaxYMin", out)
    }

    private func leftStretchyPathName(name: String): String {
        match (name) {
            case "xhookrightarrow" => return "lefthook"
            case "xmapsto" => return "leftmapsto"
            case "xrightleftharpoons" => return "leftharpoondownplus"
            case "xleftrightharpoons" => return "leftharpoonplus"
            case "xtofrom" => return "leftToFrom"
            case "xrightleftarrows" => return "baraboveleftarrow"
            case "xrightequilibrium" => return "baraboveshortleftharpoon"
            case "xleftequilibrium" => return "shortbaraboveleftharpoon"
            case _ => return "leftarrow"
        }
    }

    private func rightStretchyPathName(name: String): String {
        match (name) {
            case "xhookleftarrow" => return "righthook"
            case "xrightleftharpoons" => return "rightharpoonplus"
            case "xleftrightharpoons" => return "rightharpoondownplus"
            case "xtofrom" => return "rightToFrom"
            case "xrightleftarrows" => return "rightarrowabovebar"
            case "xrightequilibrium" => return "rightharpoonaboveshortbar"
            case "xleftequilibrium" => return "shortrightharpoonabovebar"
            case _ => return "rightarrow"
        }
    }

    private func svgViewBoxHeight(name: String): String {
        if (name == "xlongequal" || name == "xtwoheadleftarrow" || name == "xtwoheadrightarrow") {
            return "334"
        }
        if (name == "xLeftarrow" || name == "xRightarrow" || name == "xLeftrightarrow" || name == "Overrightarrow") {
            return "560"
        }
        if (name == "xrightleftharpoons" || name == "xleftrightharpoons" ||
            name == "xrightequilibrium" || name == "xleftequilibrium") {
            return "716"
        }
        if (name == "xrightleftarrows") {
            return "901"
        }
        if (name == "xtofrom") {
            return "528"
        }
        return "522"
    }

    private func isHorizontalBraceScript(script: MathSupSubNode): Bool {
        if (let command: MathCommandNode <- script.base) {
            return ((command.name == "overbrace" || command.name == "overbracket") && script.sup.isSome()) ||
                ((command.name == "underbrace" || command.name == "underbracket") && script.sub.isSome())
        }
        return false
    }

    private func isMacroArrowWithExtraSpacing(symbol: MathSymbolNode): Bool {
        return symbol.literal == "\\implies" || symbol.literal == "\\iff" || symbol.literal == "\\impliedby"
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
            case "utilde" => return "~"
            case "underbrace" => return "⏟"
            case "underbracket" => return "⎵"
            case _ => return "_"
        }
    }

    private func simpleAccentGlyph(name: String): String {
        match (name) {
            case "hat" => return "^"
            case "bar" => return "ˉ"
            case "vec" => return "⃗"
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

    private func katexAtomClass(family: String): String {
        match (family) {
            case "bin" => return "mbin"
            case "rel" => return "mrel"
            case "open" => return "mopen"
            case "close" => return "mclose"
            case "punct" => return "mpunct"
            case "op" => return "mop"
            case _ => return "mord"
        }
    }

    private func normalizeEnvironmentClass(name: String): String {
        return name.replace("*", "star")
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
}
