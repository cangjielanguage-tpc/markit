package mathtex.parser

import std.collection.ArrayList
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
    MathSourceSpan,
    MathSqrtNode,
    MathSupSubNode,
    MathSymbolNode,
    MathTextNode
}

class TexParser {
    private let source: String
    private let displayMode: Bool
    private let allowMiddle: Bool
    private let macroNames = ArrayList<String>()
    private let macroBodies = ArrayList<String>()
    private let macroParamCounts = ArrayList<Int64>()
    private var cursor: Int64 = 0

    init(source: String, displayMode: Bool, allowMiddle!: Bool = false) {
        this.source = source
        this.displayMode = displayMode
        this.allowMiddle = allowMiddle
    }

    func parse(): MathExpression {
        let root = parseSequence(stopAtBrace: false)
        return MathExpression(root, source, displayMode: displayMode)
    }

    private func parseSequence(stopAtBrace!: Bool): MathNode {
        let start = cursor
        let nodes = ArrayList<MathNode>()
        while (cursor < source.size) {
            if (stopAtBrace && source[cursor] == b'}') {
                break
            }
            skipIgnoredInput()
            if (cursor >= source.size) {
                break
            }
            let atom = parseAtom()
            nodes.add(parseScripts(atom))
        }

        let span = span(start, cursor)
        if (nodes.size == 1) {
            return MathSequenceNode(span, nodes.toArray())
        }
        return MathSequenceNode(span, nodes.toArray())
    }

    private func parseAtom(): MathNode {
        if (cursor >= source.size) {
            return MathErrorNode("Unexpected end of input", span(cursor, cursor), "")
        }

        let start = cursor
        let ch = source[cursor]
        if (ch == b'^' || ch == b'_') {
            return parseNucleuslessScript()
        }
        let unicodeScriptKind = currentUnicodeScriptKind()
        if (!unicodeScriptKind.isEmpty()) {
            return parseNucleuslessUnicodeScript(unicodeScriptKind)
        }
        if (ch == b'&') {
            cursor += 1
            return MathErrorNode("Unexpected alignment tab", span(start, cursor), "&")
        }
        if (ch == b'{') {
            return parseGroup()
        }
        if (ch == b'}') {
            cursor += 1
            return MathErrorNode("Unexpected closing brace", span(start, cursor), "}")
        }
        if (ch == b'\\') {
            return parseCommand()
        }
        if (startsWithAsciiAt("<:", cursor)) {
            cursor += 2
            return MathSymbolNode("<:", span(start, cursor), literal: "<:", family: "rel")
        }
        if (startsWithAsciiAt("...", cursor)) {
            cursor += 3
            return MathSymbolNode("…", span(start, cursor), literal: "...", family: "inner")
        }
        cursor += nextRuneByteSize(ch)
        let value = source[start..cursor]
        return MathSymbolNode(value, span(start, cursor), family: classifySymbol(value))
    }

    private func parseScripts(base: MathNode): MathNode {
        var current = base
        var sup: ?MathNode = None
        var sub: ?MathNode = None
        var end = base.sourceSpan.endByte

        skipIgnoredInput()
        var keepReadingLimitControls = true
        while (keepReadingLimitControls) {
            keepReadingLimitControls = false
            if (startsWithCommandAt("\\limits", cursor)) {
            let start = cursor
            cursor += 7
            if (!canApplyLimits(current)) {
                return MathErrorNode("Limit controls must follow a math operator", span(base.sourceSpan.startByte, cursor), source[base.sourceSpan.startByte..cursor])
            }
            current = MathLimitsNode(current, "limits", span(base.sourceSpan.startByte, cursor), source[start..cursor])
            end = cursor
            skipIgnoredInput()
                keepReadingLimitControls = true
            } else if (startsWithCommandAt("\\nolimits", cursor)) {
            let start = cursor
            cursor += 9
            if (!canApplyLimits(current)) {
                return MathErrorNode("Limit controls must follow a math operator", span(base.sourceSpan.startByte, cursor), source[base.sourceSpan.startByte..cursor])
            }
            current = MathLimitsNode(current, "nolimits", span(base.sourceSpan.startByte, cursor), source[start..cursor])
            end = cursor
            skipIgnoredInput()
                keepReadingLimitControls = true
            }
        }
        while (cursor < source.size && (source[cursor] == b'^' || source[cursor] == b'_')) {
            let marker = source[cursor]
            cursor += 1
            skipIgnoredInput()
            skipRelaxCommands()
            let script = parseAtom()
            end = script.sourceSpan.endByte
            if (marker == b'^') {
                if (sup.isSome()) {
                    return MathErrorNode("Double superscript", span(base.sourceSpan.startByte, end), source[base.sourceSpan.startByte..end])
                }
                sup = Some(script)
            } else {
                if (sub.isSome()) {
                    return MathErrorNode("Double subscript", span(base.sourceSpan.startByte, end), source[base.sourceSpan.startByte..end])
                }
                sub = Some(script)
            }
            skipIgnoredInput()
        }
        var unicodeKind = currentUnicodeScriptKind()
        while (!unicodeKind.isEmpty()) {
            let script = parseUnicodeScriptRun(unicodeKind)
            end = script.sourceSpan.endByte
            if (unicodeKind == "sup") {
                if (sup.isSome()) {
                    return MathErrorNode("Double superscript", span(base.sourceSpan.startByte, end), source[base.sourceSpan.startByte..end])
                }
                sup = Some(script)
            } else {
                if (sub.isSome()) {
                    return MathErrorNode("Double subscript", span(base.sourceSpan.startByte, end), source[base.sourceSpan.startByte..end])
                }
                sub = Some(script)
            }
            skipIgnoredInput()
            unicodeKind = currentUnicodeScriptKind()
        }

        if (sup.isNone() && sub.isNone()) {
            return current
        }
        current = MathSupSubNode(current, span(base.sourceSpan.startByte, end), sup: sup, sub: sub)
        return current
    }

    private func parseNucleuslessScript(): MathNode {
        let start = cursor
        let base = MathGroupNode(span(start, start), [])
        return parseScripts(base)
    }

    private func parseNucleuslessUnicodeScript(kind: String): MathNode {
        let start = cursor
        let base = MathGroupNode(span(start, start), [])
        let script = parseUnicodeScriptRun(kind)
        if (kind == "sup") {
            return MathSupSubNode(base, span(start, script.sourceSpan.endByte), sup: Some(script))
        }
        return MathSupSubNode(base, span(start, script.sourceSpan.endByte), sub: Some(script))
    }

    private func parseGroup(): MathNode {
        let start = cursor
        cursor += 1
        let inner = parseSequence(stopAtBrace: true)
        if (cursor < source.size && source[cursor] == b'}') {
            cursor += 1
            return MathGroupNode(span(start, cursor), inner.children)
        }
        return MathErrorNode("Unclosed group", span(start, cursor), source[start..cursor])
    }

    private func parseCommand(): MathNode {
        let start = cursor
        cursor += 1
        let nameStart = cursor
        while (cursor < source.size && isAsciiLetter(source[cursor])) {
            cursor += 1
        }
        if (nameStart == cursor && cursor < source.size) {
            cursor += nextRuneByteSize(source[cursor])
        }
        let command = source[nameStart..cursor]
        let literal = source[start..cursor]

        match (command) {
            case "frac" => return parseFraction(start, literal)
            case "dfrac" => return parseFraction(start, literal)
            case "tfrac" => return parseFraction(start, literal)
            case "cfrac" => return parseFraction(start, literal)
            case "genfrac" => return parseGenFrac(start, literal)
            case "sqrt" => return parseSqrt(start)
            case "begin" => return parseEnvironment(start, literal)
            case "begingroup" => return parseBeginGroup(start, literal)
            case "end" => return MathErrorNode("Unexpected \\end", span(start, cursor), literal)
            case "endgroup" => return MathErrorNode("Unexpected \\endgroup", span(start, cursor), literal)
            case "left" => return parseLeftRight(start, literal)
            case "right" => return MathErrorNode("Unexpected \\right", span(start, cursor), literal)
            case "middle" => return if (allowMiddle) {
                MathCommandNode("middle", span(start, cursor), literal)
            } else {
                MathErrorNode("Unexpected \\middle", span(start, cursor), literal)
            }
            case "over" => return MathCommandNode("over", span(start, cursor), literal)
            case "atop" => return MathCommandNode("atop", span(start, cursor), literal)
            case "brace" => return MathCommandNode("brace", span(start, cursor), literal)
            case "brack" => return MathCommandNode("brack", span(start, cursor), literal)
            case "choose" => return MathCommandNode("choose", span(start, cursor), literal)
            case "text" => return parseTextCommand(start)
            case "operatorname" => return parseOptionalStarTextLikeCommand(start, literal, "operatorname")
            case "mathop" => return parseOneArgCommand(start, literal, "mathop")
            case "mathrel" => return parseOneArgCommand(start, literal, "mathrel")
            case "mathord" => return parseOneArgCommand(start, literal, "mathord")
            case "mathbin" => return parseOneArgCommand(start, literal, "mathbin")
            case "mathopen" => return parseOneArgCommand(start, literal, "mathopen")
            case "mathclose" => return parseOneArgCommand(start, literal, "mathclose")
            case "mathpunct" => return parseOneArgCommand(start, literal, "mathpunct")
            case "mathrm" => return parseOneArgCommand(start, literal, "mathrm")
            case "mathbb" => return parseOneArgCommand(start, literal, "mathbb")
            case "mathit" => return parseOneArgCommand(start, literal, "mathit")
            case "mathnormal" => return parseOneArgCommand(start, literal, "mathnormal")
            case "mathcal" => return parseOneArgCommand(start, literal, "mathcal")
            case "mathfrak" => return parseOneArgCommand(start, literal, "mathfrak")
            case "mathsf" => return parseOneArgCommand(start, literal, "mathsf")
            case "mathtt" => return parseOneArgCommand(start, literal, "mathtt")
            case "mathbf" => return parseOneArgCommand(start, literal, "mathbf")
            case "rm" => return parseOneArgCommand(start, literal, "mathrm")
            case "it" => return parseOneArgCommand(start, literal, "mathit")
            case "bf" => return parseOneArgCommand(start, literal, "mathbf")
            case "sf" => return parseOneArgCommand(start, literal, "mathsf")
            case "tt" => return parseOneArgCommand(start, literal, "mathtt")
            case "cal" => return parseOneArgCommand(start, literal, "mathcal")
            case "boldsymbol" => return parseOneArgCommand(start, literal, "boldsymbol")
            case "pmb" => return parseOneArgCommand(start, literal, "pmb")
            case "textbf" => return parseTextLikeCommand(start, literal, "textbf")
            case "textit" => return parseTextLikeCommand(start, literal, "textit")
            case "textup" => return parseTextLikeCommand(start, literal, "textup")
            case "textmd" => return parseTextLikeCommand(start, literal, "textmd")
            case "textsf" => return parseTextLikeCommand(start, literal, "textsf")
            case "texttt" => return parseTextLikeCommand(start, literal, "texttt")
            case "emph" => return parseTextLikeCommand(start, literal, "emph")
            case "hbox" => return parseTextLikeCommand(start, literal, "hbox")
            case "fbox" => return parseTextLikeCommand(start, literal, "fbox")
            case "angl" => return parseTextLikeCommand(start, literal, "angl")
            case "angln" => return MathCommandNode("angl", span(start, cursor), literal, children: [MathSymbolNode("n", span(start, cursor), family: "ord")])
            case "blue" => return parseNamedColor(start, literal, "blue")
            case "red" => return parseNamedColor(start, literal, "red")
            case "green" => return parseNamedColor(start, literal, "green")
            case "purple" => return parseNamedColor(start, literal, "purple")
            case "redA" => return parseNamedColor(start, literal, "#e84d39")
            case "textcolor" => return parseTextColor(start, literal)
            case "color" => return parseTextColor(start, literal)
            case "Huge" => return parseSizing(start, literal, "Huge")
            case "small" => return parseSizing(start, literal, "small")
            case "Large" => return parseSizing(start, literal, "Large")
            case "large" => return parseSizing(start, literal, "large")
            case "LARGE" => return parseSizing(start, literal, "LARGE")
            case "huge" => return parseSizing(start, literal, "huge")
            case "tiny" => return parseSizing(start, literal, "tiny")
            case "scriptsize" => return parseSizing(start, literal, "scriptsize")
            case "footnotesize" => return parseSizing(start, literal, "footnotesize")
            case "normalsize" => return parseSizing(start, literal, "normalsize")
            case "displaystyle" => return parseSizing(start, literal, "display")
            case "textstyle" => return parseSizing(start, literal, "text")
            case "scriptstyle" => return parseSizing(start, literal, "script")
            case "scriptscriptstyle" => return parseSizing(start, literal, "scriptscript")
            case "overline" => return parseOneArgCommand(start, literal, "overline")
            case "underline" => return parseOneArgCommand(start, literal, "underline")
            case "underbar" => return parseOneArgCommand(start, literal, "underbar")
            case "widehat" => return parseOneArgCommand(start, literal, "widehat")
            case "widecheck" => return parseOneArgCommand(start, literal, "widecheck")
            case "widetilde" => return parseOneArgCommand(start, literal, "widetilde")
            case "overrightarrow" => return parseOneArgCommand(start, literal, "overrightarrow")
            case "overleftarrow" => return parseOneArgCommand(start, literal, "overleftarrow")
            case "overleftrightarrow" => return parseOneArgCommand(start, literal, "overleftrightarrow")
            case "Overrightarrow" => return parseOneArgCommand(start, literal, "Overrightarrow")
            case "underrightarrow" => return parseOneArgCommand(start, literal, "underrightarrow")
            case "underleftarrow" => return parseOneArgCommand(start, literal, "underleftarrow")
            case "underleftrightarrow" => return parseOneArgCommand(start, literal, "underleftrightarrow")
            case "overbrace" => return parseOneArgCommand(start, literal, "overbrace")
            case "underbrace" => return parseOneArgCommand(start, literal, "underbrace")
            case "overbracket" => return parseOneArgCommand(start, literal, "overbracket")
            case "underbracket" => return parseOneArgCommand(start, literal, "underbracket")
            case "overgroup" => return parseOneArgCommand(start, literal, "overgroup")
            case "undergroup" => return parseOneArgCommand(start, literal, "undergroup")
            case "overlinesegment" => return parseOneArgCommand(start, literal, "overlinesegment")
            case "underlinesegment" => return parseOneArgCommand(start, literal, "underlinesegment")
            case "overleftharpoon" => return parseOneArgCommand(start, literal, "overleftharpoon")
            case "overrightharpoon" => return parseOneArgCommand(start, literal, "overrightharpoon")
            case "utilde" => return parseOneArgCommand(start, literal, "utilde")
            case "hat" => return parseOneArgCommand(start, literal, "hat")
            case "bar" => return parseOneArgCommand(start, literal, "bar")
            case "vec" => return parseOneArgCommand(start, literal, "vec")
            case "tilde" => return parseOneArgCommand(start, literal, "tilde")
            case "dot" => return parseOneArgCommand(start, literal, "dot")
            case "ddot" => return parseOneArgCommand(start, literal, "ddot")
            case "acute" => return parseOneArgCommand(start, literal, "acute")
            case "grave" => return parseOneArgCommand(start, literal, "grave")
            case "breve" => return parseOneArgCommand(start, literal, "breve")
            case "check" => return parseOneArgCommand(start, literal, "check")
            case "phantom" => return parseOneArgCommand(start, literal, "phantom")
            case "hphantom" => return parseOneArgCommand(start, literal, "hphantom")
            case "vphantom" => return parseOneArgCommand(start, literal, "vphantom")
            case "smash" => return parseOneArgCommand(start, literal, "smash")
            case "cancel" => return parseOneArgCommand(start, literal, "cancel")
            case "bcancel" => return parseOneArgCommand(start, literal, "bcancel")
            case "xcancel" => return parseOneArgCommand(start, literal, "xcancel")
            case "sout" => return parseOneArgCommand(start, literal, "sout")
            case "boxed" => return parseOneArgCommand(start, literal, "boxed")
            case "xleftarrow" => return parseOptionalAndOneArgCommand(start, literal, "xleftarrow")
            case "xrightarrow" => return parseOptionalAndOneArgCommand(start, literal, "xrightarrow")
            case "xLeftarrow" => return parseOptionalAndOneArgCommand(start, literal, "xLeftarrow")
            case "xRightarrow" => return parseOptionalAndOneArgCommand(start, literal, "xRightarrow")
            case "xleftrightarrow" => return parseOptionalAndOneArgCommand(start, literal, "xleftrightarrow")
            case "xLeftrightarrow" => return parseOptionalAndOneArgCommand(start, literal, "xLeftrightarrow")
            case "xhookleftarrow" => return parseOptionalAndOneArgCommand(start, literal, "xhookleftarrow")
            case "xhookrightarrow" => return parseOptionalAndOneArgCommand(start, literal, "xhookrightarrow")
            case "xmapsto" => return parseOptionalAndOneArgCommand(start, literal, "xmapsto")
            case "xrightharpoondown" => return parseOptionalAndOneArgCommand(start, literal, "xrightharpoondown")
            case "xrightharpoonup" => return parseOptionalAndOneArgCommand(start, literal, "xrightharpoonup")
            case "xleftharpoondown" => return parseOptionalAndOneArgCommand(start, literal, "xleftharpoondown")
            case "xleftharpoonup" => return parseOptionalAndOneArgCommand(start, literal, "xleftharpoonup")
            case "xrightleftharpoons" => return parseOptionalAndOneArgCommand(start, literal, "xrightleftharpoons")
            case "xleftrightharpoons" => return parseOptionalAndOneArgCommand(start, literal, "xleftrightharpoons")
            case "xlongequal" => return parseOptionalAndOneArgCommand(start, literal, "xlongequal")
            case "xtwoheadrightarrow" => return parseOptionalAndOneArgCommand(start, literal, "xtwoheadrightarrow")
            case "xtwoheadleftarrow" => return parseOptionalAndOneArgCommand(start, literal, "xtwoheadleftarrow")
            case "xtofrom" => return parseOptionalAndOneArgCommand(start, literal, "xtofrom")
            case "xrightleftarrows" => return parseOptionalAndOneArgCommand(start, literal, "xrightleftarrows")
            case "xrightequilibrium" => return parseOptionalAndOneArgCommand(start, literal, "xrightequilibrium")
            case "xleftequilibrium" => return parseOptionalAndOneArgCommand(start, literal, "xleftequilibrium")
            case "phase" => return parseOneArgCommand(start, literal, "phase")
            case "colorbox" => return parseColorBox(start, literal, "colorbox")
            case "fcolorbox" => return parseFColorBox(start, literal)
            case "href" => return parseTwoRawAndMathCommand(start, literal, "href")
            case "url" => return parseRawCommand(start, literal, "url")
            case "mathchoice" => return parseFourArgCommand(start, literal, "mathchoice")
            case "tag" => return parseOptionalStarOneArgCommand(start, literal, "tag")
            case "includegraphics" => return parseIncludeGraphics(start, literal)
            case "raisebox" => return parseRaiseBox(start, literal)
            case "vcenter" => return parseOneArgCommand(start, literal, "vcenter")
            case "rule" => return parseRule(start, literal)
            case "kern" => return parseKern(start, literal)
            case "mkern" => return parseKern(start, literal)
            case "hspace" => return parseKern(start, literal)
            case "hskip" => return parseHSkip(start, literal)
            case "llap" => return parseOneArgCommand(start, literal, "llap")
            case "rlap" => return parseOneArgCommand(start, literal, "rlap")
            case "clap" => return parseOneArgCommand(start, literal, "clap")
            case "mathllap" => return parseOneArgCommand(start, literal, "mathllap")
            case "mathrlap" => return parseOneArgCommand(start, literal, "mathrlap")
            case "mathclap" => return parseOneArgCommand(start, literal, "mathclap")
            case "bigl" => return parseOneArgCommand(start, literal, "bigl")
            case "bigr" => return parseOneArgCommand(start, literal, "bigr")
            case "bigm" => return parseOneArgCommand(start, literal, "bigm")
            case "big" => return parseOneArgCommand(start, literal, "big")
            case "Bigl" => return parseOneArgCommand(start, literal, "Bigl")
            case "Bigr" => return parseOneArgCommand(start, literal, "Bigr")
            case "Bigm" => return parseOneArgCommand(start, literal, "Bigm")
            case "Big" => return parseOneArgCommand(start, literal, "Big")
            case "biggl" => return parseOneArgCommand(start, literal, "biggl")
            case "biggr" => return parseOneArgCommand(start, literal, "biggr")
            case "biggm" => return parseOneArgCommand(start, literal, "biggm")
            case "bigg" => return parseOneArgCommand(start, literal, "bigg")
            case "Biggl" => return parseOneArgCommand(start, literal, "Biggl")
            case "Biggr" => return parseOneArgCommand(start, literal, "Biggr")
            case "Biggm" => return parseOneArgCommand(start, literal, "Biggm")
            case "Bigg" => return parseOneArgCommand(start, literal, "Bigg")
            case "\\" => return MathCommandNode("newline", span(start, cursor), literal)
            case "newline" => return MathCommandNode("newline", span(start, cursor), literal)
            case "cr" => return MathCommandNode("newline", span(start, cursor), literal)
            case "hline" => return MathCommandNode("hline", span(start, cursor), literal)
            case "hdashline" => return MathCommandNode("hdashline", span(start, cursor), literal)
            case "mathstrut" => return MathCommandNode("mathstrut", span(start, cursor), literal)
            case "limits" => return MathErrorNode("Limit controls must follow a math operator", span(start, cursor), literal)
            case "nolimits" => return MathErrorNode("Limit controls must follow a math operator", span(start, cursor), literal)
            case "relax" => return MathGroupNode(span(start, cursor), [])
            case "def" => return parseDefinition(start, literal, "def")
            case "gdef" => return parseDefinition(start, literal, "gdef")
            case "edef" => return parseDefinition(start, literal, "edef")
            case "xdef" => return parseDefinition(start, literal, "xdef")
            case "newcommand" => return parseNewCommand(start, literal, "newcommand")
            case "renewcommand" => return parseNewCommand(start, literal, "renewcommand")
            case "providecommand" => return parseNewCommand(start, literal, "providecommand")
            case ";" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "," => return MathCommandNode("spacing", span(start, cursor), literal)
            case "!" => return MathCommandNode("spacing", span(start, cursor), literal)
            case ":" => return MathCommandNode("spacing", span(start, cursor), literal)
            case ">" => return MathCommandNode("spacing", span(start, cursor), literal)
            case " " => return MathCommandNode("spacing", span(start, cursor), literal)
            case "thinspace" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "medspace" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "quad" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "qquad" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "enspace" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "thickspace" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "negthinspace" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "negmedspace" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "negthickspace" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "space" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "nobreakspace" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "~" => return MathCommandNode("spacing", span(start, cursor), literal)
            case "{" => return MathSymbolNode("{", span(start, cursor), literal: literal, family: "open")
            case "}" => return MathSymbolNode("}", span(start, cursor), literal: literal, family: "close")
            case "$" => return MathSymbolNode("$", span(start, cursor), literal: literal, family: "ord")
            case "%" => return MathSymbolNode("%", span(start, cursor), literal: literal, family: "ord")
            case "&" => return MathSymbolNode("&", span(start, cursor), literal: literal, family: "ord")
            case "#" => return MathSymbolNode("#", span(start, cursor), literal: literal, family: "ord")
            case "textellipsis" => return MathTextNode("…", span(start, cursor), literal: literal)
            case "dots" => return MathSymbolNode("…", span(start, cursor), literal: literal, family: "inner")
            case "ldots" => return MathSymbolNode("…", span(start, cursor), literal: literal, family: "inner")
            case "cdots" => return MathSymbolNode("⋯", span(start, cursor), literal: literal, family: "inner")
            case "vdots" => return MathSymbolNode("⋮", span(start, cursor), literal: literal, family: "ord")
            case "KaTeX" => return MathTextNode("KaTeX", span(start, cursor), literal: literal)
            case "i" => return MathSymbolNode("ı", span(start, cursor), literal: literal, family: "ord")
            case "j" => return MathSymbolNode("ȷ", span(start, cursor), literal: literal, family: "ord")
            case "ae" => return MathTextNode("æ", span(start, cursor), literal: literal)
            case "AE" => return MathTextNode("Æ", span(start, cursor), literal: literal)
            case "oe" => return MathTextNode("œ", span(start, cursor), literal: literal)
            case "OE" => return MathTextNode("Œ", span(start, cursor), literal: literal)
            case "o" => return MathTextNode("ø", span(start, cursor), literal: literal)
            case "O" => return MathTextNode("Ø", span(start, cursor), literal: literal)
            case "ss" => return MathTextNode("ß", span(start, cursor), literal: literal)
            case "aa" => return MathTextNode("å", span(start, cursor), literal: literal)
            case "AA" => return MathTextNode("Å", span(start, cursor), literal: literal)
            case "imath" => return MathSymbolNode("ı", span(start, cursor), literal: literal, family: "ord")
            case "jmath" => return MathSymbolNode("ȷ", span(start, cursor), literal: literal, family: "ord")
            case "alpha" => return MathSymbolNode("α", span(start, cursor), literal: literal, family: "ord")
            case "beta" => return MathSymbolNode("β", span(start, cursor), literal: literal, family: "ord")
            case "gamma" => return MathSymbolNode("γ", span(start, cursor), literal: literal, family: "ord")
            case "delta" => return MathSymbolNode("δ", span(start, cursor), literal: literal, family: "ord")
            case "epsilon" => return MathSymbolNode("ϵ", span(start, cursor), literal: literal, family: "ord")
            case "varepsilon" => return MathSymbolNode("ε", span(start, cursor), literal: literal, family: "ord")
            case "zeta" => return MathSymbolNode("ζ", span(start, cursor), literal: literal, family: "ord")
            case "eta" => return MathSymbolNode("η", span(start, cursor), literal: literal, family: "ord")
            case "theta" => return MathSymbolNode("θ", span(start, cursor), literal: literal, family: "ord")
            case "vartheta" => return MathSymbolNode("ϑ", span(start, cursor), literal: literal, family: "ord")
            case "iota" => return MathSymbolNode("ι", span(start, cursor), literal: literal, family: "ord")
            case "kappa" => return MathSymbolNode("κ", span(start, cursor), literal: literal, family: "ord")
            case "lambda" => return MathSymbolNode("λ", span(start, cursor), literal: literal, family: "ord")
            case "mu" => return MathSymbolNode("μ", span(start, cursor), literal: literal, family: "ord")
            case "nu" => return MathSymbolNode("ν", span(start, cursor), literal: literal, family: "ord")
            case "xi" => return MathSymbolNode("ξ", span(start, cursor), literal: literal, family: "ord")
            case "rho" => return MathSymbolNode("ρ", span(start, cursor), literal: literal, family: "ord")
            case "varrho" => return MathSymbolNode("ϱ", span(start, cursor), literal: literal, family: "ord")
            case "sigma" => return MathSymbolNode("σ", span(start, cursor), literal: literal, family: "ord")
            case "varsigma" => return MathSymbolNode("ς", span(start, cursor), literal: literal, family: "ord")
            case "tau" => return MathSymbolNode("τ", span(start, cursor), literal: literal, family: "ord")
            case "upsilon" => return MathSymbolNode("υ", span(start, cursor), literal: literal, family: "ord")
            case "phi" => return MathSymbolNode("ϕ", span(start, cursor), literal: literal, family: "ord")
            case "varphi" => return MathSymbolNode("φ", span(start, cursor), literal: literal, family: "ord")
            case "chi" => return MathSymbolNode("χ", span(start, cursor), literal: literal, family: "ord")
            case "pi" => return MathSymbolNode("π", span(start, cursor), literal: literal, family: "ord")
            case "psi" => return MathSymbolNode("ψ", span(start, cursor), literal: literal, family: "ord")
            case "omega" => return MathSymbolNode("ω", span(start, cursor), literal: literal, family: "ord")
            case "Gamma" => return MathSymbolNode("Γ", span(start, cursor), literal: literal, family: "ord")
            case "Delta" => return MathSymbolNode("Δ", span(start, cursor), literal: literal, family: "ord")
            case "Theta" => return MathSymbolNode("Θ", span(start, cursor), literal: literal, family: "ord")
            case "Lambda" => return MathSymbolNode("Λ", span(start, cursor), literal: literal, family: "ord")
            case "Xi" => return MathSymbolNode("Ξ", span(start, cursor), literal: literal, family: "ord")
            case "Pi" => return MathSymbolNode("Π", span(start, cursor), literal: literal, family: "ord")
            case "Sigma" => return MathSymbolNode("Σ", span(start, cursor), literal: literal, family: "ord")
            case "Upsilon" => return MathSymbolNode("Υ", span(start, cursor), literal: literal, family: "ord")
            case "Phi" => return MathSymbolNode("Φ", span(start, cursor), literal: literal, family: "ord")
            case "Psi" => return MathSymbolNode("Ψ", span(start, cursor), literal: literal, family: "ord")
            case "Omega" => return MathSymbolNode("Ω", span(start, cursor), literal: literal, family: "ord")
            case "sum" => return MathSymbolNode("∑", span(start, cursor), literal: literal, family: "op")
            case "prod" => return MathSymbolNode("∏", span(start, cursor), literal: literal, family: "op")
            case "coprod" => return MathSymbolNode("∐", span(start, cursor), literal: literal, family: "op")
            case "int" => return MathSymbolNode("∫", span(start, cursor), literal: literal, family: "op")
            case "iint" => return MathSymbolNode("∫∫", span(start, cursor), literal: literal, family: "op")
            case "iiint" => return MathSymbolNode("∫∫∫", span(start, cursor), literal: literal, family: "op")
            case "oint" => return MathSymbolNode("∮", span(start, cursor), literal: literal, family: "op")
            case "oiint" => return MathSymbolNode("∮∮", span(start, cursor), literal: literal, family: "op")
            case "oiiint" => return MathSymbolNode("∮∮∮", span(start, cursor), literal: literal, family: "op")
            case "lim" => return MathSymbolNode("lim", span(start, cursor), literal: literal, family: "op")
            case "limsup" => return MathSymbolNode("lim sup", span(start, cursor), literal: literal, family: "op")
            case "liminf" => return MathSymbolNode("lim inf", span(start, cursor), literal: literal, family: "op")
            case "sin" => return MathSymbolNode("sin", span(start, cursor), literal: literal, family: "op")
            case "cos" => return MathSymbolNode("cos", span(start, cursor), literal: literal, family: "op")
            case "tan" => return MathSymbolNode("tan", span(start, cursor), literal: literal, family: "op")
            case "log" => return MathSymbolNode("log", span(start, cursor), literal: literal, family: "op")
            case "ln" => return MathSymbolNode("ln", span(start, cursor), literal: literal, family: "op")
            case "max" => return MathSymbolNode("max", span(start, cursor), literal: literal, family: "op")
            case "min" => return MathSymbolNode("min", span(start, cursor), literal: literal, family: "op")
            case "cdot" => return MathSymbolNode("⋅", span(start, cursor), literal: literal, family: "bin")
            case "cdotp" => return MathSymbolNode("·", span(start, cursor), literal: literal, family: "bin")
            case "times" => return MathSymbolNode("×", span(start, cursor), literal: literal, family: "bin")
            case "pm" => return MathSymbolNode("±", span(start, cursor), literal: literal, family: "bin")
            case "mp" => return MathSymbolNode("∓", span(start, cursor), literal: literal, family: "bin")
            case "div" => return MathSymbolNode("÷", span(start, cursor), literal: literal, family: "bin")
            case "oplus" => return MathSymbolNode("⊕", span(start, cursor), literal: literal, family: "bin")
            case "otimes" => return MathSymbolNode("⊗", span(start, cursor), literal: literal, family: "bin")
            case "cup" => return MathSymbolNode("∪", span(start, cursor), literal: literal, family: "bin")
            case "cap" => return MathSymbolNode("∩", span(start, cursor), literal: literal, family: "bin")
            case "leq" => return MathSymbolNode("≤", span(start, cursor), literal: literal, family: "rel")
            case "le" => return MathSymbolNode("≤", span(start, cursor), literal: literal, family: "rel")
            case "lt" => return MathSymbolNode("<", span(start, cursor), literal: literal, family: "rel")
            case "leqq" => return MathSymbolNode("≦", span(start, cursor), literal: literal, family: "rel")
            case "leqslant" => return MathSymbolNode("⩽", span(start, cursor), literal: literal, family: "rel")
            case "lesssim" => return MathSymbolNode("≲", span(start, cursor), literal: literal, family: "rel")
            case "lessapprox" => return MathSymbolNode("⪅", span(start, cursor), literal: literal, family: "rel")
            case "lnsim" => return MathSymbolNode("⋦", span(start, cursor), literal: literal, family: "rel")
            case "lnapprox" => return MathSymbolNode("⪉", span(start, cursor), literal: literal, family: "rel")
            case "precnsim" => return MathSymbolNode("⋨", span(start, cursor), literal: literal, family: "rel")
            case "precnapprox" => return MathSymbolNode("⪹", span(start, cursor), literal: literal, family: "rel")
            case "nsim" => return MathSymbolNode("≁", span(start, cursor), literal: literal, family: "rel")
            case "geq" => return MathSymbolNode("≥", span(start, cursor), literal: literal, family: "rel")
            case "ge" => return MathSymbolNode("≥", span(start, cursor), literal: literal, family: "rel")
            case "gt" => return MathSymbolNode(">", span(start, cursor), literal: literal, family: "rel")
            case "geqq" => return MathSymbolNode("≧", span(start, cursor), literal: literal, family: "rel")
            case "geqslant" => return MathSymbolNode("⩾", span(start, cursor), literal: literal, family: "rel")
            case "gtrsim" => return MathSymbolNode("≳", span(start, cursor), literal: literal, family: "rel")
            case "gtrapprox" => return MathSymbolNode("⪆", span(start, cursor), literal: literal, family: "rel")
            case "gnsim" => return MathSymbolNode("⋧", span(start, cursor), literal: literal, family: "rel")
            case "gnapprox" => return MathSymbolNode("⪊", span(start, cursor), literal: literal, family: "rel")
            case "succnsim" => return MathSymbolNode("⋩", span(start, cursor), literal: literal, family: "rel")
            case "succnapprox" => return MathSymbolNode("⪺", span(start, cursor), literal: literal, family: "rel")
            case "neq" => return MathSymbolNode("≠", span(start, cursor), literal: literal, family: "rel")
            case "ne" => return MathSymbolNode("≠", span(start, cursor), literal: literal, family: "rel")
            case "nleq" => return MathSymbolNode("≰", span(start, cursor), literal: literal, family: "rel")
            case "ngeq" => return MathSymbolNode("≱", span(start, cursor), literal: literal, family: "rel")
            case "cong" => return MathSymbolNode("≅", span(start, cursor), literal: literal, family: "rel")
            case "equiv" => return MathSymbolNode("≡", span(start, cursor), literal: literal, family: "rel")
            case "approx" => return MathSymbolNode("≈", span(start, cursor), literal: literal, family: "rel")
            case "approxeq" => return MathSymbolNode("≊", span(start, cursor), literal: literal, family: "rel")
            case "sim" => return MathSymbolNode("∼", span(start, cursor), literal: literal, family: "rel")
            case "simeq" => return MathSymbolNode("≃", span(start, cursor), literal: literal, family: "rel")
            case "backsim" => return MathSymbolNode("∽", span(start, cursor), literal: literal, family: "rel")
            case "backsimeq" => return MathSymbolNode("⋍", span(start, cursor), literal: literal, family: "rel")
            case "precsim" => return MathSymbolNode("≾", span(start, cursor), literal: literal, family: "rel")
            case "precapprox" => return MathSymbolNode("⪷", span(start, cursor), literal: literal, family: "rel")
            case "thicksim" => return MathSymbolNode("∼", span(start, cursor), literal: literal, family: "rel")
            case "thickapprox" => return MathSymbolNode("≈", span(start, cursor), literal: literal, family: "rel")
            case "succsim" => return MathSymbolNode("≿", span(start, cursor), literal: literal, family: "rel")
            case "succapprox" => return MathSymbolNode("⪸", span(start, cursor), literal: literal, family: "rel")
            case "eqsim" => return MathSymbolNode("≂", span(start, cursor), literal: literal, family: "rel")
            case "triangleq" => return MathSymbolNode("≜", span(start, cursor), literal: literal, family: "rel")
            case "propto" => return MathSymbolNode("∝", span(start, cursor), literal: literal, family: "rel")
            case "in" => return MathSymbolNode("∈", span(start, cursor), literal: literal, family: "rel")
            case "notin" => return MathSymbolNode("∉", span(start, cursor), literal: literal, family: "rel")
            case "subset" => return MathSymbolNode("⊂", span(start, cursor), literal: literal, family: "rel")
            case "subseteq" => return MathSymbolNode("⊆", span(start, cursor), literal: literal, family: "rel")
            case "subseteqq" => return MathSymbolNode("⫅", span(start, cursor), literal: literal, family: "rel")
            case "subsetneq" => return MathSymbolNode("⊊", span(start, cursor), literal: literal, family: "rel")
            case "subsetneqq" => return MathSymbolNode("⫋", span(start, cursor), literal: literal, family: "rel")
            case "nsubseteq" => return MathSymbolNode("⊈", span(start, cursor), literal: literal, family: "rel")
            case "supset" => return MathSymbolNode("⊃", span(start, cursor), literal: literal, family: "rel")
            case "supseteq" => return MathSymbolNode("⊇", span(start, cursor), literal: literal, family: "rel")
            case "supseteqq" => return MathSymbolNode("⫆", span(start, cursor), literal: literal, family: "rel")
            case "supsetneq" => return MathSymbolNode("⊋", span(start, cursor), literal: literal, family: "rel")
            case "supsetneqq" => return MathSymbolNode("⫌", span(start, cursor), literal: literal, family: "rel")
            case "nsupseteq" => return MathSymbolNode("⊉", span(start, cursor), literal: literal, family: "rel")
            case "sqsubset" => return MathSymbolNode("⊏", span(start, cursor), literal: literal, family: "rel")
            case "sqsubseteq" => return MathSymbolNode("⊑", span(start, cursor), literal: literal, family: "rel")
            case "sqsupset" => return MathSymbolNode("⊐", span(start, cursor), literal: literal, family: "rel")
            case "sqsupseteq" => return MathSymbolNode("⊒", span(start, cursor), literal: literal, family: "rel")
            case "to" => return MathSymbolNode("→", span(start, cursor), literal: literal, family: "rel")
            case "rightarrow" => return MathSymbolNode("→", span(start, cursor), literal: literal, family: "rel")
            case "leftarrow" => return MathSymbolNode("←", span(start, cursor), literal: literal, family: "rel")
            case "longleftarrow" => return MathSymbolNode("⟵", span(start, cursor), literal: literal, family: "rel")
            case "longrightarrow" => return MathSymbolNode("⟶", span(start, cursor), literal: literal, family: "rel")
            case "longleftrightarrow" => return MathSymbolNode("⟷", span(start, cursor), literal: literal, family: "rel")
            case "nleftarrow" => return MathSymbolNode("↚", span(start, cursor), literal: literal, family: "rel")
            case "nrightarrow" => return MathSymbolNode("↛", span(start, cursor), literal: literal, family: "rel")
            case "nleftrightarrow" => return MathSymbolNode("↮", span(start, cursor), literal: literal, family: "rel")
            case "uparrow" => return MathSymbolNode("↑", span(start, cursor), literal: literal, family: "rel")
            case "downarrow" => return MathSymbolNode("↓", span(start, cursor), literal: literal, family: "rel")
            case "updownarrow" => return MathSymbolNode("↕", span(start, cursor), literal: literal, family: "rel")
            case "nearrow" => return MathSymbolNode("↗", span(start, cursor), literal: literal, family: "rel")
            case "searrow" => return MathSymbolNode("↘", span(start, cursor), literal: literal, family: "rel")
            case "swarrow" => return MathSymbolNode("↙", span(start, cursor), literal: literal, family: "rel")
            case "nwarrow" => return MathSymbolNode("↖", span(start, cursor), literal: literal, family: "rel")
            case "dashleftarrow" => return MathSymbolNode("⇠", span(start, cursor), literal: literal, family: "rel")
            case "dashrightarrow" => return MathSymbolNode("⇢", span(start, cursor), literal: literal, family: "rel")
            case "leftleftarrows" => return MathSymbolNode("⇇", span(start, cursor), literal: literal, family: "rel")
            case "rightrightarrows" => return MathSymbolNode("⇉", span(start, cursor), literal: literal, family: "rel")
            case "leftrightarrows" => return MathSymbolNode("⇆", span(start, cursor), literal: literal, family: "rel")
            case "rightleftarrows" => return MathSymbolNode("⇄", span(start, cursor), literal: literal, family: "rel")
            case "leftarrowtail" => return MathSymbolNode("↢", span(start, cursor), literal: literal, family: "rel")
            case "rightarrowtail" => return MathSymbolNode("↣", span(start, cursor), literal: literal, family: "rel")
            case "looparrowleft" => return MathSymbolNode("↫", span(start, cursor), literal: literal, family: "rel")
            case "looparrowright" => return MathSymbolNode("↬", span(start, cursor), literal: literal, family: "rel")
            case "curvearrowleft" => return MathSymbolNode("↶", span(start, cursor), literal: literal, family: "rel")
            case "curvearrowright" => return MathSymbolNode("↷", span(start, cursor), literal: literal, family: "rel")
            case "circlearrowleft" => return MathSymbolNode("↺", span(start, cursor), literal: literal, family: "rel")
            case "circlearrowright" => return MathSymbolNode("↻", span(start, cursor), literal: literal, family: "rel")
            case "upuparrows" => return MathSymbolNode("⇈", span(start, cursor), literal: literal, family: "rel")
            case "downdownarrows" => return MathSymbolNode("⇊", span(start, cursor), literal: literal, family: "rel")
            case "rightsquigarrow" => return MathSymbolNode("⇝", span(start, cursor), literal: literal, family: "rel")
            case "leftrightsquigarrow" => return MathSymbolNode("↭", span(start, cursor), literal: literal, family: "rel")
            case "mapsto" => return MathSymbolNode("↦", span(start, cursor), literal: literal, family: "rel")
            case "longmapsto" => return MathSymbolNode("⟼", span(start, cursor), literal: literal, family: "rel")
            case "hookleftarrow" => return MathSymbolNode("↩", span(start, cursor), literal: literal, family: "rel")
            case "hookrightarrow" => return MathSymbolNode("↪", span(start, cursor), literal: literal, family: "rel")
            case "twoheadleftarrow" => return MathSymbolNode("↞", span(start, cursor), literal: literal, family: "rel")
            case "twoheadrightarrow" => return MathSymbolNode("↠", span(start, cursor), literal: literal, family: "rel")
            case "Rightarrow" => return MathSymbolNode("⇒", span(start, cursor), literal: literal, family: "rel")
            case "Leftarrow" => return MathSymbolNode("⇐", span(start, cursor), literal: literal, family: "rel")
            case "Longleftarrow" => return MathSymbolNode("⟸", span(start, cursor), literal: literal, family: "rel")
            case "Longrightarrow" => return MathSymbolNode("⟹", span(start, cursor), literal: literal, family: "rel")
            case "Longleftrightarrow" => return MathSymbolNode("⟺", span(start, cursor), literal: literal, family: "rel")
            case "nLeftarrow" => return MathSymbolNode("⇍", span(start, cursor), literal: literal, family: "rel")
            case "nRightarrow" => return MathSymbolNode("⇏", span(start, cursor), literal: literal, family: "rel")
            case "nLeftrightarrow" => return MathSymbolNode("⇎", span(start, cursor), literal: literal, family: "rel")
            case "Uparrow" => return MathSymbolNode("⇑", span(start, cursor), literal: literal, family: "rel")
            case "Downarrow" => return MathSymbolNode("⇓", span(start, cursor), literal: literal, family: "rel")
            case "Updownarrow" => return MathSymbolNode("⇕", span(start, cursor), literal: literal, family: "rel")
            case "Lleftarrow" => return MathSymbolNode("⇚", span(start, cursor), literal: literal, family: "rel")
            case "Rrightarrow" => return MathSymbolNode("⇛", span(start, cursor), literal: literal, family: "rel")
            case "leftrightarrow" => return MathSymbolNode("↔", span(start, cursor), literal: literal, family: "rel")
            case "Leftrightarrow" => return MathSymbolNode("⇔", span(start, cursor), literal: literal, family: "rel")
            case "iff" => return MathSymbolNode("⟺", span(start, cursor), literal: literal, family: "rel")
            case "implies" => return MathSymbolNode("⟹", span(start, cursor), literal: literal, family: "rel")
            case "impliedby" => return MathSymbolNode("⟸", span(start, cursor), literal: literal, family: "rel")
            case "vdash" => return MathSymbolNode("⊢", span(start, cursor), literal: literal, family: "rel")
            case "dashv" => return MathSymbolNode("⊣", span(start, cursor), literal: literal, family: "rel")
            case "vDash" => return MathSymbolNode("⊨", span(start, cursor), literal: literal, family: "rel")
            case "Vdash" => return MathSymbolNode("⊩", span(start, cursor), literal: literal, family: "rel")
            case "Vvdash" => return MathSymbolNode("⊪", span(start, cursor), literal: literal, family: "rel")
            case "nvdash" => return MathSymbolNode("⊬", span(start, cursor), literal: literal, family: "rel")
            case "nvDash" => return MathSymbolNode("⊭", span(start, cursor), literal: literal, family: "rel")
            case "nVdash" => return MathSymbolNode("⊮", span(start, cursor), literal: literal, family: "rel")
            case "nVDash" => return MathSymbolNode("⊯", span(start, cursor), literal: literal, family: "rel")
            case "models" => return MathSymbolNode("⊨", span(start, cursor), literal: literal, family: "rel")
            case "therefore" => return MathSymbolNode("∴", span(start, cursor), literal: literal, family: "rel")
            case "because" => return MathSymbolNode("∵", span(start, cursor), literal: literal, family: "rel")
            case "land" => return MathSymbolNode("∧", span(start, cursor), literal: literal, family: "bin")
            case "wedge" => return MathSymbolNode("∧", span(start, cursor), literal: literal, family: "bin")
            case "lor" => return MathSymbolNode("∨", span(start, cursor), literal: literal, family: "bin")
            case "vee" => return MathSymbolNode("∨", span(start, cursor), literal: literal, family: "bin")
            case "sqcap" => return MathSymbolNode("⊓", span(start, cursor), literal: literal, family: "bin")
            case "sqcup" => return MathSymbolNode("⊔", span(start, cursor), literal: literal, family: "bin")
            case "doublebarwedge" => return MathSymbolNode("⩞", span(start, cursor), literal: literal, family: "bin")
            case "divideontimes" => return MathSymbolNode("⋇", span(start, cursor), literal: literal, family: "bin")
            case "ltimes" => return MathSymbolNode("⋉", span(start, cursor), literal: literal, family: "bin")
            case "rtimes" => return MathSymbolNode("⋊", span(start, cursor), literal: literal, family: "bin")
            case "leftthreetimes" => return MathSymbolNode("⋋", span(start, cursor), literal: literal, family: "bin")
            case "rightthreetimes" => return MathSymbolNode("⋌", span(start, cursor), literal: literal, family: "bin")
            case "curlywedge" => return MathSymbolNode("⋏", span(start, cursor), literal: literal, family: "bin")
            case "curlyvee" => return MathSymbolNode("⋎", span(start, cursor), literal: literal, family: "bin")
            case "intercal" => return MathSymbolNode("⊺", span(start, cursor), literal: literal, family: "bin")
            case "doublecap" => return MathSymbolNode("⋒", span(start, cursor), literal: literal, family: "bin")
            case "doublecup" => return MathSymbolNode("⋓", span(start, cursor), literal: literal, family: "bin")
            case "boxtimes" => return MathSymbolNode("⊠", span(start, cursor), literal: literal, family: "bin")
            case "barwedge" => return MathSymbolNode("⊼", span(start, cursor), literal: literal, family: "bin")
            case "veebar" => return MathSymbolNode("⊻", span(start, cursor), literal: literal, family: "bin")
            case "bigvee" => return MathSymbolNode("⋁", span(start, cursor), literal: literal, family: "op")
            case "bigwedge" => return MathSymbolNode("⋀", span(start, cursor), literal: literal, family: "op")
            case "bigcap" => return MathSymbolNode("⋂", span(start, cursor), literal: literal, family: "op")
            case "bigcup" => return MathSymbolNode("⋃", span(start, cursor), literal: literal, family: "op")
            case "bigoplus" => return MathSymbolNode("⨁", span(start, cursor), literal: literal, family: "op")
            case "bigotimes" => return MathSymbolNode("⨂", span(start, cursor), literal: literal, family: "op")
            case "bigsqcup" => return MathSymbolNode("⨆", span(start, cursor), literal: literal, family: "op")
            case "smallint" => return MathSymbolNode("∫", span(start, cursor), literal: literal, family: "op")
            case "intop" => return MathSymbolNode("∫", span(start, cursor), literal: literal, family: "op")
            case "neg" => return MathSymbolNode("¬", span(start, cursor), literal: literal, family: "ord")
            case "lnot" => return MathSymbolNode("¬", span(start, cursor), literal: literal, family: "ord")
            case "top" => return MathSymbolNode("⊤", span(start, cursor), literal: literal, family: "ord")
            case "bot" => return MathSymbolNode("⊥", span(start, cursor), literal: literal, family: "ord")
            case "nexists" => return MathSymbolNode("∄", span(start, cursor), literal: literal, family: "ord")
            case "infty" => return MathSymbolNode("∞", span(start, cursor), literal: literal, family: "ord")
            case "partial" => return MathSymbolNode("∂", span(start, cursor), literal: literal, family: "ord")
            case "nabla" => return MathSymbolNode("∇", span(start, cursor), literal: literal, family: "ord")
            case "forall" => return MathSymbolNode("∀", span(start, cursor), literal: literal, family: "ord")
            case "exists" => return MathSymbolNode("∃", span(start, cursor), literal: literal, family: "ord")
            case "emptyset" => return MathSymbolNode("∅", span(start, cursor), literal: literal, family: "ord")
            case "not" => return parseNot(start, literal)
            case "langle" => return MathSymbolNode("⟨", span(start, cursor), literal: literal, family: "open")
            case "rangle" => return MathSymbolNode("⟩", span(start, cursor), literal: literal, family: "close")
            case "lparen" => return MathSymbolNode("(", span(start, cursor), literal: literal, family: "open")
            case "rparen" => return MathSymbolNode(")", span(start, cursor), literal: literal, family: "close")
            case "lfloor" => return MathSymbolNode("⌊", span(start, cursor), literal: literal, family: "open")
            case "rfloor" => return MathSymbolNode("⌋", span(start, cursor), literal: literal, family: "close")
            case "lceil" => return MathSymbolNode("⌈", span(start, cursor), literal: literal, family: "open")
            case "rceil" => return MathSymbolNode("⌉", span(start, cursor), literal: literal, family: "close")
            case "llbracket" => return MathSymbolNode("⟦", span(start, cursor), literal: literal, family: "open")
            case "rrbracket" => return MathSymbolNode("⟧", span(start, cursor), literal: literal, family: "close")
            case "lBrace" => return MathSymbolNode("⦃", span(start, cursor), literal: literal, family: "open")
            case "rBrace" => return MathSymbolNode("⦄", span(start, cursor), literal: literal, family: "close")
            case "lbrace" => return MathSymbolNode("{", span(start, cursor), literal: literal, family: "open")
            case "rbrace" => return MathSymbolNode("}", span(start, cursor), literal: literal, family: "close")
            case "lvert" => return MathSymbolNode("|", span(start, cursor), literal: literal, family: "open")
            case "rvert" => return MathSymbolNode("|", span(start, cursor), literal: literal, family: "close")
            case "vert" => return MathSymbolNode("|", span(start, cursor), literal: literal, family: "ord")
            case "lVert" => return MathSymbolNode("∥", span(start, cursor), literal: literal, family: "open")
            case "rVert" => return MathSymbolNode("∥", span(start, cursor), literal: literal, family: "close")
            case "Vert" => return MathSymbolNode("∥", span(start, cursor), literal: literal, family: "ord")
            case "|" => return MathSymbolNode("∥", span(start, cursor), literal: literal, family: "ord")
            case "mid" => return MathSymbolNode("|", span(start, cursor), literal: literal, family: "rel")
            case "lang" => return MathSymbolNode("⟨", span(start, cursor), literal: literal, family: "open")
            case "rang" => return MathSymbolNode("⟩", span(start, cursor), literal: literal, family: "close")
            case "N" => return MathSymbolNode("N", span(start, cursor), literal: literal, family: "ord")
            case "R" => return MathSymbolNode("R", span(start, cursor), literal: literal, family: "ord")
            case "Z" => return MathSymbolNode("Z", span(start, cursor), literal: literal, family: "ord")
            case "alef" => return MathSymbolNode("ℵ", span(start, cursor), literal: literal, family: "ord")
            case "alefsym" => return MathSymbolNode("ℵ", span(start, cursor), literal: literal, family: "ord")
            case "empty" => return MathSymbolNode("∅", span(start, cursor), literal: literal, family: "ord")
            case "infin" => return MathSymbolNode("∞", span(start, cursor), literal: literal, family: "ord")
            case "Alpha" => return MathSymbolNode("Α", span(start, cursor), literal: literal, family: "ord")
            case "Beta" => return MathSymbolNode("Β", span(start, cursor), literal: literal, family: "ord")
            case "Chi" => return MathSymbolNode("Χ", span(start, cursor), literal: literal, family: "ord")
            case "Epsilon" => return MathSymbolNode("Ε", span(start, cursor), literal: literal, family: "ord")
            case "Eta" => return MathSymbolNode("Η", span(start, cursor), literal: literal, family: "ord")
            case "Iota" => return MathSymbolNode("Ι", span(start, cursor), literal: literal, family: "ord")
            case "Kappa" => return MathSymbolNode("Κ", span(start, cursor), literal: literal, family: "ord")
            case "Mu" => return MathSymbolNode("Μ", span(start, cursor), literal: literal, family: "ord")
            case "Nu" => return MathSymbolNode("Ν", span(start, cursor), literal: literal, family: "ord")
            case "Omicron" => return MathSymbolNode("Ο", span(start, cursor), literal: literal, family: "ord")
            case "Rho" => return MathSymbolNode("Ρ", span(start, cursor), literal: literal, family: "ord")
            case "Tau" => return MathSymbolNode("Τ", span(start, cursor), literal: literal, family: "ord")
            case "Zeta" => return MathSymbolNode("Ζ", span(start, cursor), literal: literal, family: "ord")
            case "darr" => return MathSymbolNode("↓", span(start, cursor), literal: literal, family: "rel")
            case "uarr" => return MathSymbolNode("↑", span(start, cursor), literal: literal, family: "rel")
            case "larr" => return MathSymbolNode("←", span(start, cursor), literal: literal, family: "rel")
            case "rarr" => return MathSymbolNode("→", span(start, cursor), literal: literal, family: "rel")
            case "harr" => return MathSymbolNode("↔", span(start, cursor), literal: literal, family: "rel")
            case "lrarr" => return MathSymbolNode("↔", span(start, cursor), literal: literal, family: "rel")
            case "dArr" => return MathSymbolNode("⇓", span(start, cursor), literal: literal, family: "rel")
            case "Darr" => return MathSymbolNode("⇓", span(start, cursor), literal: literal, family: "rel")
            case "uArr" => return MathSymbolNode("⇑", span(start, cursor), literal: literal, family: "rel")
            case "Uarr" => return MathSymbolNode("⇑", span(start, cursor), literal: literal, family: "rel")
            case "lArr" => return MathSymbolNode("⇐", span(start, cursor), literal: literal, family: "rel")
            case "Larr" => return MathSymbolNode("⇐", span(start, cursor), literal: literal, family: "rel")
            case "rArr" => return MathSymbolNode("⇒", span(start, cursor), literal: literal, family: "rel")
            case "Rarr" => return MathSymbolNode("⇒", span(start, cursor), literal: literal, family: "rel")
            case "hArr" => return MathSymbolNode("⇔", span(start, cursor), literal: literal, family: "rel")
            case "Harr" => return MathSymbolNode("⇔", span(start, cursor), literal: literal, family: "rel")
            case "lrArr" => return MathSymbolNode("⇔", span(start, cursor), literal: literal, family: "rel")
            case "Lrarr" => return MathSymbolNode("⇔", span(start, cursor), literal: literal, family: "rel")
            case "clubs" => return MathSymbolNode("♣", span(start, cursor), literal: literal, family: "ord")
            case "diamonds" => return MathSymbolNode("♢", span(start, cursor), literal: literal, family: "ord")
            case "hearts" => return MathSymbolNode("♡", span(start, cursor), literal: literal, family: "ord")
            case "spades" => return MathSymbolNode("♠", span(start, cursor), literal: literal, family: "ord")
            case "cnums" => return MathSymbolNode("C", span(start, cursor), literal: literal, family: "ord")
            case "Complex" => return MathSymbolNode("C", span(start, cursor), literal: literal, family: "ord")
            case "natnums" => return MathSymbolNode("N", span(start, cursor), literal: literal, family: "ord")
            case "real" => return MathSymbolNode("R", span(start, cursor), literal: literal, family: "ord")
            case "reals" => return MathSymbolNode("R", span(start, cursor), literal: literal, family: "ord")
            case "Reals" => return MathSymbolNode("R", span(start, cursor), literal: literal, family: "ord")
            case "plusmn" => return MathSymbolNode("±", span(start, cursor), literal: literal, family: "bin")
            case "exist" => return MathSymbolNode("∃", span(start, cursor), literal: literal, family: "ord")
            case "isin" => return MathSymbolNode("∈", span(start, cursor), literal: literal, family: "rel")
            case "sub" => return MathSymbolNode("⊂", span(start, cursor), literal: literal, family: "rel")
            case "sube" => return MathSymbolNode("⊆", span(start, cursor), literal: literal, family: "rel")
            case "supe" => return MathSymbolNode("⊇", span(start, cursor), literal: literal, family: "rel")
            case "sdot" => return MathSymbolNode("⋅", span(start, cursor), literal: literal, family: "bin")
            case "sect" => return MathSymbolNode("§", span(start, cursor), literal: literal, family: "ord")
            case "yen" => return MathSymbolNode("¥", span(start, cursor), literal: literal, family: "ord")
            case "checkmark" => return MathSymbolNode("✓", span(start, cursor), literal: literal, family: "ord")
            case "circledR" => return MathSymbolNode("®", span(start, cursor), literal: literal, family: "ord")
            case "copyright" => return MathSymbolNode("©", span(start, cursor), literal: literal, family: "ord")
            case "maltese" => return MathSymbolNode("✠", span(start, cursor), literal: literal, family: "ord")
            case "minuso" => return MathSymbolNode("⦵", span(start, cursor), literal: literal, family: "bin")
            case "circ" => return MathSymbolNode("∘", span(start, cursor), literal: literal, family: "bin")
            case "thetasym" => return MathSymbolNode("ϑ", span(start, cursor), literal: literal, family: "ord")
            case "weierp" => return MathSymbolNode("℘", span(start, cursor), literal: literal, family: "ord")
            case "Dagger" => return MathSymbolNode("‡", span(start, cursor), literal: literal, family: "bin")
            case "image" => return MathSymbolNode("ℑ", span(start, cursor), literal: literal, family: "ord")
            case "varPi" => return MathSymbolNode("Π", span(start, cursor), literal: literal, family: "ord")
            case "overset" => return parseTwoArgCommand(start, literal, "overset")
            case "underset" => return parseTwoArgCommand(start, literal, "underset")
            case "injlim" => return MathSymbolNode("inj lim", span(start, cursor), literal: literal, family: "op")
            case "projlim" => return MathSymbolNode("proj lim", span(start, cursor), literal: literal, family: "op")
            case "varlimsup" => return MathSymbolNode("lim sup", span(start, cursor), literal: literal, family: "op")
            case "varliminf" => return MathSymbolNode("lim inf", span(start, cursor), literal: literal, family: "op")
            case "varinjlim" => return MathSymbolNode("lim", span(start, cursor), literal: literal, family: "op")
            case "varprojlim" => return MathSymbolNode("lim", span(start, cursor), literal: literal, family: "op")
            case "plim" => return MathSymbolNode("plim", span(start, cursor), literal: literal, family: "op")
            case "argmin" => return MathSymbolNode("arg min", span(start, cursor), literal: literal, family: "op")
            case "argmax" => return MathSymbolNode("arg max", span(start, cursor), literal: literal, family: "op")
            case "substack" => return parseOneArgCommand(start, literal, "substack")
            case "mathinner" => return parseRequiredGroup("Missing body for \\mathinner")
            case _ =>
                if (let Some(expanded) <- expandMacro(literal, start)) {
                    return expanded
                }
                return MathErrorNode("Unsupported command: \\${command}", span(start, cursor), literal)
        }
    }

    private func parseFraction(start: Int64, literal: String): MathNode {
        let numerator = parseRequiredArgument("Missing numerator for ${literal}")
        let denominator = parseRequiredArgument("Missing denominator for ${literal}")
        return MathFractionNode(numerator, denominator, span(start, denominator.sourceSpan.endByte))
    }

    private func parseSqrt(start: Int64): MathNode {
        let index = parseOptionalSqrtIndex()
        let radicand = parseRequiredArgument("Missing radicand for \\sqrt")
        return MathSqrtNode(radicand, span(start, radicand.sourceSpan.endByte), index: index)
    }

    private func parseEnvironment(start: Int64, literal: String): MathNode {
        let name = parseRequiredRawGroup()
        if (name.isEmpty()) {
            return MathErrorNode("Missing environment name", span(start, cursor), source[start..cursor])
        }
        if (!isKnownEnvironment(name)) {
            return MathErrorNode("No such environment: ${name}", span(start, cursor), source[start..cursor])
        }
        let bodyStart = cursor
        let endNeedle = "\\end{" + name + "}"
        let endAt = findEnvironmentEnd(name, bodyStart)
        if (endAt < 0) {
            return MathErrorNode("Missing \\end{${name}}", span(start, cursor), source[start..cursor])
        }
        let body = source[bodyStart..endAt]
        let rows = parseEnvironmentRows(name, body)
        let preamble = extractEnvironmentPreamble(name, body)
        let columnAlignments = parseEnvironmentColumnAlignments(name, preamble)
        let columnSeparatorCounts = parseEnvironmentColumnSeparatorCounts(name, preamble)
        cursor = endAt + endNeedle.size
        return MathEnvironmentNode(
            name,
            rows,
            span(start, cursor),
            literal,
            columnAlignments: columnAlignments,
            columnSeparatorCounts: columnSeparatorCounts
        )
    }

    private func parseBeginGroup(start: Int64, literal: String): MathNode {
        let endAt = findAscii("\\endgroup", cursor)
        if (endAt < 0) {
            return MathErrorNode("Missing \\endgroup", span(start, cursor), source[start..cursor])
        }
        let body = source[cursor..endAt]
        let inner = parseWithCurrentMacros(body, allowMiddle: allowMiddle)
        cursor = endAt + 9
        return MathGroupNode(span(start, cursor), inner.children)
    }

    private func isKnownEnvironment(name: String): Bool {
        match (name) {
            case "matrix" | "matrix*" | "pmatrix" | "pmatrix*" | "bmatrix" | "bmatrix*" | "Bmatrix" | "Bmatrix*" => return true
            case "vmatrix" | "vmatrix*" | "Vmatrix" | "Vmatrix*" | "array" | "subarray" | "smallmatrix" => return true
            case "cases" | "rcases" | "aligned" | "aligned*" | "gathered" | "gathered*" | "gather" | "gather*" => return true
            case "alignedat" | "alignedat*" | "align" | "align*" | "alignat" | "alignat*" | "equation" | "equation*" => return true
            case "split" | "CD" => return true
            case _ => return false
        }
    }

    private func parseEnvironmentRows(name: String, body: String): Array<Array<MathNode>> {
        let content = stripEnvironmentPreamble(name, body)
        let rows = ArrayList<Array<MathNode>>()
        var cells = ArrayList<MathNode>()
        var cellStart: Int64 = 0
        var i: Int64 = 0
        var braceDepth: Int64 = 0
        var environmentDepth: Int64 = 0

        while (i < content.size) {
            if (startsWithAsciiIn(content, "\\begin{", i)) {
                environmentDepth += 1
                i += 7
                continue
            }
            if (startsWithAsciiIn(content, "\\end{", i) && environmentDepth > 0) {
                environmentDepth -= 1
                i += 5
                continue
            }
            if (content[i] == b'{') {
                braceDepth += 1
                i += 1
                continue
            }
            if (content[i] == b'}') {
                if (braceDepth > 0) {
                    braceDepth -= 1
                }
                i += 1
                continue
            }
            if (braceDepth == 0 && environmentDepth == 0 && content[i] == b'&') {
                cells.add(parseEnvironmentCell(content[cellStart..i]))
                i += 1
                cellStart = i
                continue
            }
            if (braceDepth == 0 && environmentDepth == 0 && startsWithAsciiIn(content, "\\\\", i)) {
                cells.add(parseEnvironmentCell(content[cellStart..i]))
                rows.add(cells.toArray())
                cells = ArrayList<MathNode>()
                i += 2
                cellStart = skipOptionalRowSpacing(content, i)
                i = cellStart
                continue
            }
            if (braceDepth == 0 && environmentDepth == 0 && startsWithAsciiIn(content, "\\cr", i)) {
                cells.add(parseEnvironmentCell(content[cellStart..i]))
                rows.add(cells.toArray())
                cells = ArrayList<MathNode>()
                i += 3
                cellStart = skipOptionalRowSpacing(content, i)
                i = cellStart
                continue
            }
            i += nextRuneByteSize(content[i])
        }

        if (cellStart <= content.size) {
            cells.add(parseEnvironmentCell(content[cellStart..content.size]))
        }
        if (cells.size > 0 || rows.size == 0) {
            rows.add(cells.toArray())
        }
        return rows.toArray()
    }

    private func parseEnvironmentCell(cell: String): MathNode {
        return parseWithCurrentMacros(cell.trimAscii(), allowMiddle: false)
    }

    private func stripEnvironmentPreamble(name: String, body: String): String {
        var i: Int64 = 0
        while (i < body.size && isAsciiWhitespace(body[i])) {
            i += 1
        }
        if (isMatrixStarEnvironment(name)) {
            i = skipBracketGroupIn(body, i)
        } else if (name == "array" || name == "subarray" || name == "alignedat" || name == "alignedat*" || name == "alignat" || name == "alignat*") {
            i = skipGroupIn(body, i)
        }
        return body[i..body.size]
    }

    private func extractEnvironmentPreamble(name: String, body: String): String {
        var i: Int64 = 0
        while (i < body.size && isAsciiWhitespace(body[i])) {
            i += 1
        }
        if (isMatrixStarEnvironment(name)) {
            return extractBracketPreamble(body, i)
        }
        if (name == "array" || name == "subarray" || name == "alignedat" || name == "alignedat*" || name == "alignat" || name == "alignat*") {
            return extractBracePreamble(body, i)
        }
        return ""
    }

    private func extractBracketPreamble(text: String, offset: Int64): String {
        if (offset >= text.size || text[offset] != b'[') {
            return ""
        }
        let end = findDelimitedEndIn(text, offset, b'[', b']')
        if (end <= offset + 1) {
            return ""
        }
        return text[(offset + 1)..(end - 1)].trimAscii()
    }

    private func extractBracePreamble(text: String, offset: Int64): String {
        if (offset >= text.size || text[offset] != b'{') {
            return ""
        }
        let end = findDelimitedEndIn(text, offset, b'{', b'}')
        if (end <= offset + 1) {
            return ""
        }
        return text[(offset + 1)..(end - 1)].trimAscii()
    }

    private func parseEnvironmentColumnAlignments(name: String, preamble: String): Array<String> {
        let alignments = ArrayList<String>()
        if (preamble.isEmpty()) {
            return alignments.toArray()
        }
        var i: Int64 = 0
        while (i < preamble.size) {
            let ch = preamble[i]
            if (ch == b'l') {
                alignments.add("l")
                i += 1
                continue
            }
            if (ch == b'c') {
                alignments.add("c")
                i += 1
                continue
            }
            if (ch == b'r') {
                alignments.add("r")
                i += 1
                continue
            }
            if ((ch == b'@' || ch == b'!' || ch == b'>' || ch == b'<') && i + 1 < preamble.size && preamble[i + 1] == b'{') {
                i = skipGroupIn(preamble, i + 1)
                continue
            }
            i += nextRuneByteSize(ch)
        }
        if (isMatrixStarEnvironment(name) && alignments.size > 1) {
            return [alignments[0]]
        }
        return alignments.toArray()
    }

    private func parseEnvironmentColumnSeparatorCounts(name: String, preamble: String): Array<Int64> {
        let counts = ArrayList<Int64>()
        if (name != "array" || preamble.isEmpty()) {
            return counts.toArray()
        }
        counts.add(0)
        var columnIndex: Int64 = 0
        var i: Int64 = 0
        while (i < preamble.size) {
            let ch = preamble[i]
            if (ch == b'|' || ch == b':') {
                counts[columnIndex] = counts[columnIndex] + 1
                i += 1
                continue
            }
            if (ch == b'l' || ch == b'c' || ch == b'r') {
                columnIndex += 1
                counts.add(0)
                i += 1
                continue
            }
            if ((ch == b'@' || ch == b'!' || ch == b'>' || ch == b'<') && i + 1 < preamble.size && preamble[i + 1] == b'{') {
                i = skipGroupIn(preamble, i + 1)
                continue
            }
            i += nextRuneByteSize(ch)
        }
        return counts.toArray()
    }

    private func isMatrixStarEnvironment(name: String): Bool {
        return name == "matrix*" || name == "pmatrix*" || name == "bmatrix*" || name == "Bmatrix*" || name == "vmatrix*" || name == "Vmatrix*"
    }

    private func skipOptionalRowSpacing(text: String, offset: Int64): Int64 {
        var i = offset
        while (i < text.size && isAsciiWhitespace(text[i])) {
            i += 1
        }
        if (i >= text.size || text[i] != b'[') {
            return i
        }
        return skipBracketGroupIn(text, i)
    }

    private func skipBracketGroupIn(text: String, offset: Int64): Int64 {
        if (offset >= text.size || text[offset] != b'[') {
            return offset
        }
        return skipDelimitedGroupIn(text, offset, b'[', b']')
    }

    private func skipGroupIn(text: String, offset: Int64): Int64 {
        if (offset >= text.size || text[offset] != b'{') {
            return offset
        }
        return skipDelimitedGroupIn(text, offset, b'{', b'}')
    }

    private func skipDelimitedGroupIn(text: String, offset: Int64, open: Byte, close: Byte): Int64 {
        var i = findDelimitedEndIn(text, offset, open, close)
        while (i < text.size && isAsciiWhitespace(text[i])) {
            i += 1
        }
        return i
    }

    private func findDelimitedEndIn(text: String, offset: Int64, open: Byte, close: Byte): Int64 {
        var i = offset + 1
        var depth: Int64 = 1
        while (i < text.size && depth > 0) {
            if (text[i] == open) {
                depth += 1
            } else if (text[i] == close) {
                depth -= 1
            }
            i += nextRuneByteSize(text[i])
        }
        return i
    }

    private func parseLeftRight(start: Int64, literal: String): MathNode {
        let leftDelim = parseDelimiterArgument("Missing left delimiter")
        let bodyStart = cursor
        let rightAt = findMatchingRight(bodyStart)
        if (rightAt < 0) {
            return MathErrorNode("Missing \\right", span(start, cursor), source[start..cursor])
        }
        let body = source[bodyStart..rightAt]
        let inner = parseWithCurrentMacros(body, allowMiddle: true)
        cursor = rightAt + 6
        let rightDelim = parseDelimiterArgument("Missing right delimiter")
        return MathDelimitedNode(leftDelim, inner, rightDelim, span(start, rightDelim.sourceSpan.endByte), source[start..rightDelim.sourceSpan.endByte])
    }

    private func parseTextCommand(start: Int64): MathNode {
        skipIgnoredInput()
        if (cursor >= source.size) {
            return MathErrorNode("Missing text group for \\text", span(start, cursor), source[start..cursor])
        }
        if (source[cursor] != b'{') {
            let atomStart = cursor
            cursor += nextRuneByteSize(source[cursor])
            return MathTextNode(source[atomStart..cursor], span(start, cursor), literal: source[start..cursor])
        }
        cursor += 1
        let textStart = cursor
        var depth: Int64 = 1
        while (cursor < source.size && depth > 0) {
            if (source[cursor] == b'{') {
                depth += 1
                cursor += 1
                continue
            }
            if (source[cursor] == b'}') {
                depth -= 1
                if (depth == 0) {
                    break
                }
                cursor += 1
                continue
            }
            cursor += nextRuneByteSize(source[cursor])
        }
        let text = source[textStart..cursor]
        if (text.contains("\\sqrt")) {
            return MathErrorNode("Unsupported math-mode function in text", span(start, cursor), source[start..cursor])
        }
        if (cursor < source.size && source[cursor] == b'}') {
            cursor += 1
        }
        return MathTextNode(text, span(start, cursor), literal: source[start..cursor])
    }

    private func parseTextLikeCommand(start: Int64, literal: String, name: String): MathNode {
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathCommandNode(name, span(start, body.sourceSpan.endByte), literal, children: [body])
    }

    private func parseOptionalStarTextLikeCommand(start: Int64, literal: String, name: String): MathNode {
        skipOptionalStar()
        return parseTextLikeCommand(start, literal, name)
    }

    private func parseNamedColor(start: Int64, literal: String, color: String): MathNode {
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathColorNode(color, body, span(start, body.sourceSpan.endByte), literal)
    }

    private func parseTextColor(start: Int64, literal: String): MathNode {
        let color = parseRequiredRawGroup()
        if (color.isEmpty() || !isValidColor(color)) {
            return MathErrorNode("Invalid color", span(start, cursor), source[start..cursor])
        }
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathColorNode(normalizeColor(color), body, span(start, body.sourceSpan.endByte), literal)
    }

    private func parseSizing(start: Int64, literal: String, size: String): MathNode {
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathSizingNode(size, body, span(start, body.sourceSpan.endByte), literal)
    }

    private func parseOneArgCommand(start: Int64, literal: String, name: String): MathNode {
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathCommandNode(name, span(start, body.sourceSpan.endByte), literal, children: [body])
    }

    private func parseOptionalStarOneArgCommand(start: Int64, literal: String, name: String): MathNode {
        skipOptionalStar()
        return parseOneArgCommand(start, literal, name)
    }

    private func parseTwoArgCommand(start: Int64, literal: String, name: String): MathNode {
        let first = parseRequiredArgument("Missing first body for ${literal}")
        let second = parseRequiredArgument("Missing second body for ${literal}")
        return MathCommandNode(name, span(start, second.sourceSpan.endByte), literal, children: [first, second])
    }

    private func parseOptionalAndOneArgCommand(start: Int64, literal: String, name: String): MathNode {
        let below = parseOptionalRawBracket()
        let body = parseRequiredArgument("Missing body for ${literal}")
        if (let Some(rawBelow) <- below) {
            return MathCommandNode(name, span(start, body.sourceSpan.endByte), literal, children: [
                body,
                TexParser(rawBelow, displayMode).parse().root
            ])
        }
        return MathCommandNode(name, span(start, body.sourceSpan.endByte), literal, children: [body])
    }

    private func parseColorBox(start: Int64, literal: String, name: String): MathNode {
        let color = parseRequiredRawGroup()
        if (color.isEmpty() || !isValidColor(color)) {
            return MathErrorNode("Invalid color", span(start, cursor), source[start..cursor])
        }
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathCommandNode(name, span(start, body.sourceSpan.endByte), literal, children: [MathTextNode(normalizeColor(color), span(start, cursor)), body])
    }

    private func parseFColorBox(start: Int64, literal: String): MathNode {
        let border = parseRequiredRawGroup()
        let background = parseRequiredRawGroup()
        if (border.isEmpty() || background.isEmpty() || !isValidColor(border) || !isValidColor(background)) {
            return MathErrorNode("Invalid color", span(start, cursor), source[start..cursor])
        }
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathCommandNode("fcolorbox", span(start, body.sourceSpan.endByte), literal, children: [
            MathTextNode(normalizeColor(border), span(start, cursor)),
            MathTextNode(normalizeColor(background), span(start, cursor)),
            body
        ])
    }

    private func parseTwoRawAndMathCommand(start: Int64, literal: String, name: String): MathNode {
        let raw = parseRequiredRawGroup()
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathCommandNode(name, span(start, body.sourceSpan.endByte), literal, children: [
            MathTextNode(raw, span(start, cursor)),
            body
        ])
    }

    private func parseRawCommand(start: Int64, literal: String, name: String): MathNode {
        let raw = parseRequiredRawGroup()
        return MathCommandNode(name, span(start, cursor), literal, children: [MathTextNode(raw, span(start, cursor))])
    }

    private func parseFourArgCommand(start: Int64, literal: String, name: String): MathNode {
        let first = parseRequiredArgument("Missing first body for ${literal}")
        let second = parseRequiredArgument("Missing second body for ${literal}")
        let third = parseRequiredArgument("Missing third body for ${literal}")
        let fourth = parseRequiredArgument("Missing fourth body for ${literal}")
        return MathCommandNode(name, span(start, fourth.sourceSpan.endByte), literal, children: [first, second, third, fourth])
    }

    private func parseIncludeGraphics(start: Int64, literal: String): MathNode {
        skipOptionalBracketGroup()
        let path = parseRequiredRawGroup()
        if (path.isEmpty()) {
            return MathErrorNode("Missing path for ${literal}", span(start, cursor), source[start..cursor])
        }
        return MathCommandNode("includegraphics", span(start, cursor), literal, children: [MathTextNode(path, span(start, cursor))])
    }

    private func parseDefinition(start: Int64, literal: String, name: String): MathNode {
        skipIgnoredInput()
        let commandName = parseDefinitionName()
        if (commandName.isEmpty()) {
            return MathErrorNode("Missing macro name for ${literal}", span(start, cursor), source[start..cursor])
        }
        let parameterText = parseOptionalMacroParameterText()
        let body = parseRequiredRawGroupIgnoringComments()
        let parameterCount = parseSimpleMacroParameterCount(parameterText)
        if (parameterCount < 0) {
            return MathErrorNode("Invalid macro parameter text", span(start, cursor), source[start..cursor])
        }
        defineMacro(commandName, body, parameterCount)
        return MathGroupNode(span(start, cursor), [])
    }

    private func parseNewCommand(start: Int64, literal: String, name: String): MathNode {
        skipOptionalStar()
        skipIgnoredInput()
        let commandName = parseNewCommandName()
        if (commandName.isEmpty()) {
            return MathErrorNode("Missing macro name for ${literal}", span(start, cursor), source[start..cursor])
        }
        let exists = macroExists(commandName) || TexCommandRegistry.supports(commandName)
        if (name == "newcommand" && exists) {
            return MathErrorNode("Macro already exists", span(start, cursor), source[start..cursor])
        }
        if (name == "renewcommand" && !exists) {
            return MathErrorNode("Macro does not exist", span(start, cursor), source[start..cursor])
        }

        let parameterCountText = parseOptionalRawBracket()
        var parameterCount: Int64 = 0
        if (let Some(text) <- parameterCountText) {
            parameterCount = parseNewCommandParameterCount(text)
            if (parameterCount < 0) {
                return MathErrorNode("Invalid number of macro arguments", span(start, cursor), source[start..cursor])
            }
        }
        let body = parseRequiredRawGroupIgnoringComments()
        if (name == "providecommand" && exists) {
            return MathGroupNode(span(start, cursor), [])
        }
        defineMacro(commandName, body, parameterCount)
        return MathGroupNode(span(start, cursor), [])
    }

    private func parseRaiseBox(start: Int64, literal: String): MathNode {
        let amount = parseRequiredRawGroup()
        if (amount.isEmpty()) {
            return MathErrorNode("Missing amount for ${literal}", span(start, cursor), source[start..cursor])
        }
        let body = parseRequiredArgument("Missing body for ${literal}")
        return MathCommandNode("raisebox", span(start, body.sourceSpan.endByte), literal, children: [
            MathTextNode(amount, span(start, cursor)),
            body
        ])
    }

    private func parseRule(start: Int64, literal: String): MathNode {
        skipOptionalBracketGroup()
        let width = parseRequiredRawGroup()
        let height = parseRequiredRawGroup()
        if (width.isEmpty() || height.isEmpty()) {
            return MathErrorNode("Missing size for ${literal}", span(start, cursor), source[start..cursor])
        }
        return MathCommandNode("rule", span(start, cursor), literal, children: [
            MathTextNode(width, span(start, cursor)),
            MathTextNode(height, span(start, cursor))
        ])
    }

    private func parseKern(start: Int64, literal: String): MathNode {
        skipIgnoredInput()
        if (cursor < source.size && source[cursor] == b'{') {
            let raw = parseRequiredRawGroup()
            if (raw.isEmpty()) {
                return MathErrorNode("Missing size for ${literal}", span(start, cursor), source[start..cursor])
            }
            return MathCommandNode("kern", span(start, cursor), source[start..cursor], children: [MathTextNode(raw, span(start, cursor))])
        }
        let sizeStart = cursor
        while (cursor < source.size && !isAsciiWhitespace(source[cursor]) && source[cursor] != b'\\' && source[cursor] != b'^' && source[cursor] != b'_' && source[cursor] != b'}') {
            cursor += nextRuneByteSize(source[cursor])
        }
        if (sizeStart == cursor) {
            return MathErrorNode("Missing size for ${literal}", span(start, cursor), source[start..cursor])
        }
        return MathCommandNode("kern", span(start, cursor), source[start..cursor])
    }

    private func parseGenFrac(start: Int64, literal: String): MathNode {
        let left = parseRequiredArgument("Missing left delimiter for ${literal}")
        let right = parseRequiredArgument("Missing right delimiter for ${literal}")
        let thickness = parseRequiredArgument("Missing thickness for ${literal}")
        let style = parseRequiredArgument("Missing style for ${literal}")
        let numerator = parseRequiredArgument("Missing numerator for ${literal}")
        let denominator = parseRequiredArgument("Missing denominator for ${literal}")
        if (hasError(left) || hasError(right) || hasError(thickness) || hasError(style)) {
            return MathErrorNode("Invalid \\genfrac", span(start, cursor), source[start..cursor])
        }
        return MathFractionNode(numerator, denominator, span(start, denominator.sourceSpan.endByte))
    }

    private func parseHSkip(start: Int64, literal: String): MathNode {
        while (cursor < source.size && !isAsciiWhitespace(source[cursor]) && source[cursor] != b'\\' && source[cursor] != b'^' && source[cursor] != b'_') {
            cursor += nextRuneByteSize(source[cursor])
        }
        return MathCommandNode("spacing", span(start, cursor), source[start..cursor])
    }

    private func parseRequiredGroup(message: String): MathNode {
        skipIgnoredInput()
        if (cursor < source.size && source[cursor] == b'{') {
            return parseGroup()
        }
        return MathErrorNode(message, span(cursor, cursor), "")
    }

    private func parseRequiredArgument(message: String): MathNode {
        skipIgnoredInput()
        if (cursor >= source.size) {
            return MathErrorNode(message, span(cursor, cursor), "")
        }
        if (source[cursor] == b'{') {
            return parseGroup()
        }
        return parseAtom()
    }

    private func parseDelimiterArgument(message: String): MathNode {
        skipIgnoredInput()
        if (cursor >= source.size) {
            return MathErrorNode(message, span(cursor, cursor), "")
        }
        if (source[cursor] == b'.') {
            let start = cursor
            cursor += 1
            return MathSymbolNode(".", span(start, cursor), family: "close")
        }
        return parseAtom()
    }

    private func parseRequiredRawGroup(): String {
        skipIgnoredInput()
        if (cursor >= source.size || source[cursor] != b'{') {
            return ""
        }
        cursor += 1
        let start = cursor
        var depth: Int64 = 1
        while (cursor < source.size && depth > 0) {
            if (source[cursor] == b'{') {
                depth += 1
                cursor += 1
                continue
            }
            if (source[cursor] == b'}') {
                depth -= 1
                if (depth == 0) {
                    break
                }
                cursor += 1
                continue
            }
            cursor += nextRuneByteSize(source[cursor])
        }
        let value = source[start..cursor]
        if (cursor < source.size && source[cursor] == b'}') {
            cursor += 1
        }
        return value
    }

    private func parseRequiredRawGroupIgnoringComments(): String {
        skipIgnoredInput()
        if (cursor >= source.size || source[cursor] != b'{') {
            return ""
        }
        cursor += 1
        let start = cursor
        var depth: Int64 = 1
        while (cursor < source.size && depth > 0) {
            if (source[cursor] == b'%') {
                while (cursor < source.size && source[cursor] != b'\n') {
                    cursor += 1
                }
                if (cursor < source.size && source[cursor] == b'\n') {
                    cursor += 1
                }
                continue
            }
            if (source[cursor] == b'{') {
                depth += 1
                cursor += 1
                continue
            }
            if (source[cursor] == b'}') {
                depth -= 1
                if (depth == 0) {
                    break
                }
                cursor += 1
                continue
            }
            cursor += nextRuneByteSize(source[cursor])
        }
        let value = source[start..cursor]
        if (cursor < source.size && source[cursor] == b'}') {
            cursor += 1
        }
        return value
    }

    private func skipOptionalBracketGroup(): Unit {
        skipIgnoredInput()
        if (cursor >= source.size || source[cursor] != b'[') {
            return
        }
        cursor += 1
        var depth: Int64 = 1
        while (cursor < source.size && depth > 0) {
            if (source[cursor] == b'[') {
                depth += 1
                cursor += 1
                continue
            }
            if (source[cursor] == b']') {
                depth -= 1
                cursor += 1
                continue
            }
            cursor += nextRuneByteSize(source[cursor])
        }
    }

    private func parseOptionalSqrtIndex(): ?MathNode {
        let raw = parseOptionalRawBracket()
        if (let Some(text) <- raw) {
            return Some(TexParser(text, displayMode).parse().root)
        }
        return None
    }

    private func parseDefinitionName(): String {
        if (cursor >= source.size || source[cursor] != b'\\') {
            return ""
        }
        let start = cursor
        cursor += 1
        let nameStart = cursor
        while (cursor < source.size && isAsciiLetter(source[cursor])) {
            cursor += 1
        }
        if (nameStart == cursor && cursor < source.size) {
            cursor += nextRuneByteSize(source[cursor])
        }
        return source[start..cursor]
    }

    private func parseNewCommandName(): String {
        skipIgnoredInput()
        if (cursor < source.size && source[cursor] == b'{') {
            cursor += 1
            skipIgnoredInput()
            let name = parseDefinitionName()
            skipIgnoredInput()
            if (cursor < source.size && source[cursor] == b'}') {
                cursor += 1
                return name
            }
            return ""
        }
        return parseDefinitionName()
    }

    private func parseOptionalRawBracket(): ?String {
        skipIgnoredInput()
        if (cursor >= source.size || source[cursor] != b'[') {
            return None
        }
        cursor += 1
        let start = cursor
        var depth: Int64 = 1
        while (cursor < source.size && depth > 0) {
            if (source[cursor] == b'[') {
                depth += 1
                cursor += 1
                continue
            }
            if (source[cursor] == b']') {
                depth -= 1
                if (depth == 0) {
                    break
                }
                cursor += 1
                continue
            }
            cursor += nextRuneByteSize(source[cursor])
        }
        let value = source[start..cursor]
        if (cursor < source.size && source[cursor] == b']') {
            cursor += 1
        }
        return Some(value)
    }

    private func parseNewCommandParameterCount(text: String): Int64 {
        if (text.isEmpty()) {
            return -1
        }
        var value: Int64 = 0
        for (ch in text) {
            let digit = digitValue(ch)
            if (digit < 0) {
                return -1
            }
            value = value * 10 + digit
        }
        if (value < 0) {
            return -1
        }
        if (value > 9) {
            return 1
        }
        return value
    }

    private func parseOptionalMacroParameterText(): String {
        let start = cursor
        while (cursor < source.size) {
            skipIgnoredInput()
            if (cursor >= source.size || source[cursor] == b'{') {
                return source[start..cursor]
            }
            cursor += nextRuneByteSize(source[cursor])
        }
        return source[start..cursor]
    }

    private func skipOptionalStar(): Unit {
        skipIgnoredInput()
        if (cursor < source.size && source[cursor] == b'*') {
            cursor += 1
        }
    }

    private func defineMacro(name: String, body: String, parameterCount: Int64): Unit {
        macroNames.add(name)
        macroBodies.add(body)
        macroParamCounts.add(parameterCount)
    }

    private func macroExists(name: String): Bool {
        for (macroName in macroNames) {
            if (macroName == name) {
                return true
            }
        }
        return false
    }

    private func expandMacro(name: String, start: Int64): ?MathNode {
        var body = ""
        var parameterCount: Int64 = 0
        var found = false
        for (i in 0..macroNames.size) {
            if (macroNames[i] == name) {
                body = macroBodies[i]
                parameterCount = macroParamCounts[i]
                found = true
            }
        }
        if (!found) {
            return None
        }
        let args = ArrayList<String>()
        for (_ in 0..parameterCount) {
            if (let Some(argument) <- parseMacroArgumentRaw()) {
                args.add(argument)
            } else {
                return Some(MathErrorNode("Missing macro argument", span(start, cursor), source[start..cursor]))
            }
        }
        let expandedText = substituteMacroBody(body, args.toArray())
        return Some(parseWithCurrentMacros(expandedText, allowMiddle: allowMiddle))
    }

    private func parseSimpleMacroParameterCount(parameterText: String): Int64 {
        if (parameterText.isEmpty()) {
            return 0
        }
        var expected: Int64 = 1
        var i: Int64 = 0
        while (i < parameterText.size) {
            if (isAsciiWhitespace(parameterText[i])) {
                i += 1
                continue
            }
            if (parameterText[i] != b'#' || i + 1 >= parameterText.size) {
                return -1
            }
            let value = digitValue(parameterText[i + 1])
            if (value != expected || value < 1 || value > 9) {
                return -1
            }
            expected += 1
            i += 2
        }
        return expected - 1
    }

    private func parseMacroArgumentRaw(): ?String {
        skipIgnoredInput()
        if (cursor >= source.size) {
            return None
        }
        if (source[cursor] == b'{') {
            cursor += 1
            let start = cursor
            var depth: Int64 = 1
            while (cursor < source.size && depth > 0) {
                if (source[cursor] == b'{') {
                    depth += 1
                    cursor += 1
                    continue
                }
                if (source[cursor] == b'}') {
                    depth -= 1
                    if (depth == 0) {
                        break
                    }
                    cursor += 1
                    continue
                }
                cursor += nextRuneByteSize(source[cursor])
            }
            let value = source[start..cursor]
            if (cursor < source.size && source[cursor] == b'}') {
                cursor += 1
            }
            return Some(value)
        }
        let start = cursor
        if (source[cursor] == b'\\') {
            cursor += 1
            let nameStart = cursor
            while (cursor < source.size && isAsciiLetter(source[cursor])) {
                cursor += 1
            }
            if (nameStart == cursor && cursor < source.size) {
                cursor += nextRuneByteSize(source[cursor])
            }
            return Some(source[start..cursor])
        }
        cursor += nextRuneByteSize(source[cursor])
        return Some(source[start..cursor])
    }

    private func substituteMacroBody(body: String, args: Array<String>): String {
        let out = StringBuilder(body.size + 16)
        var i: Int64 = 0
        while (i < body.size) {
            if (body[i] == b'#' && i + 1 < body.size) {
                let value = digitValue(body[i + 1])
                if (value >= 1 && value <= args.size) {
                    out.append(args[value - 1])
                    i += 2
                    continue
                }
            }
            out.append(body[i..i + nextRuneByteSize(body[i])])
            i += nextRuneByteSize(body[i])
        }
        return out.toString()
    }

    private func parseWithCurrentMacros(text: String, allowMiddle!: Bool): MathNode {
        let parser = TexParser(text, displayMode, allowMiddle: allowMiddle)
        for (i in 0..macroNames.size) {
            parser.defineMacro(macroNames[i], macroBodies[i], macroParamCounts[i])
        }
        return parser.parse().root
    }

    private func findAscii(needle: String, startAt: Int64): Int64 {
        if (needle.isEmpty() || startAt >= source.size) {
            return -1
        }
        var i = startAt
        while (i + needle.size <= source.size) {
            if (startsWithAsciiAt(needle, i)) {
                return i
            }
            i += 1
        }
        return -1
    }

    private func findEnvironmentEnd(name: String, startAt: Int64): Int64 {
        let beginNeedle = "\\begin{" + name + "}"
        let endNeedle = "\\end{" + name + "}"
        var depth: Int64 = 1
        var i = startAt
        while (i < source.size) {
            if (i + beginNeedle.size <= source.size && startsWithAsciiAt(beginNeedle, i)) {
                depth += 1
                i += beginNeedle.size
                continue
            }
            if (i + endNeedle.size <= source.size && startsWithAsciiAt(endNeedle, i)) {
                depth -= 1
                if (depth == 0) {
                    return i
                }
                i += endNeedle.size
                continue
            }
            i += 1
        }
        return -1
    }

    private func findMatchingRight(startAt: Int64): Int64 {
        var depth: Int64 = 1
        var i = startAt
        while (i < source.size) {
            if (i + 5 <= source.size && startsWithAsciiAt("\\left", i)) {
                depth += 1
                i += 5
                continue
            }
            if (i + 6 <= source.size && startsWithAsciiAt("\\right", i)) {
                depth -= 1
                if (depth == 0) {
                    return i
                }
                i += 6
                continue
            }
            i += 1
        }
        return -1
    }

    private func parseNot(start: Int64, literal: String): MathNode {
        skipIgnoredInput()
        if (cursor >= source.size) {
            return MathSymbolNode("¬", span(start, cursor), literal: literal, family: "rel")
        }
        let target = parseAtom()
        if (let symbol: MathSymbolNode <- target) {
            return MathSymbolNode("̸${symbol.value}", span(start, target.sourceSpan.endByte), literal: source[start..target.sourceSpan.endByte], family: "rel")
        }
        return MathSymbolNode("̸", span(start, target.sourceSpan.endByte), literal: source[start..target.sourceSpan.endByte], family: "rel")
    }

    private func canApplyLimits(node: MathNode): Bool {
        if (let symbol: MathSymbolNode <- node) {
            return symbol.family == "op"
        }
        if (let limits: MathLimitsNode <- node) {
            return canApplyLimits(limits.base)
        }
        if (let command: MathCommandNode <- node) {
            return command.name == "operatorname" || command.name == "mathop"
        }
        return false
    }

    private func currentUnicodeScriptKind(): String {
        if (cursor >= source.size) {
            return ""
        }
        let end = cursor + nextRuneByteSize(source[cursor])
        let value = source[cursor..end]
        if (!unicodeSupValue(value).isEmpty()) {
            return "sup"
        }
        if (!unicodeSubValue(value).isEmpty()) {
            return "sub"
        }
        return ""
    }

    private func parseUnicodeScriptRun(kind: String): MathNode {
        let start = cursor
        let nodes = ArrayList<MathNode>()
        while (cursor < source.size) {
            let end = cursor + nextRuneByteSize(source[cursor])
            let value = source[cursor..end]
            let normalized = if (kind == "sup") { unicodeSupValue(value) } else { unicodeSubValue(value) }
            if (normalized.isEmpty()) {
                break
            }
            nodes.add(MathSymbolNode(normalized, span(cursor, end), literal: value, family: classifySymbol(normalized)))
            cursor = end
        }
        if (nodes.size == 1) {
            return nodes[0]
        }
        return MathGroupNode(span(start, cursor), nodes.toArray())
    }

    private func unicodeSupValue(value: String): String {
        match (value) {
            case "⁰" => return "0"
            case "¹" => return "1"
            case "²" => return "2"
            case "³" => return "3"
            case "⁴" => return "4"
            case "⁵" => return "5"
            case "⁶" => return "6"
            case "⁷" => return "7"
            case "⁸" => return "8"
            case "⁹" => return "9"
            case "⁺" => return "+"
            case "⁻" => return "-"
            case "⁼" => return "="
            case "⁽" => return "("
            case "⁾" => return ")"
            case "ⁿ" => return "n"
            case _ => return ""
        }
    }

    private func unicodeSubValue(value: String): String {
        match (value) {
            case "₀" => return "0"
            case "₁" => return "1"
            case "₂" => return "2"
            case "₃" => return "3"
            case "₄" => return "4"
            case "₅" => return "5"
            case "₆" => return "6"
            case "₇" => return "7"
            case "₈" => return "8"
            case "₉" => return "9"
            case "₊" => return "+"
            case "₋" => return "-"
            case "₌" => return "="
            case "₍" => return "("
            case "₎" => return ")"
            case _ => return ""
        }
    }

    private func classifySymbol(value: String): String {
        if (value == "+" || value == "-" || value == "*") {
            return "bin"
        }
        if (value == "=" || value == "<" || value == ">") {
            return "rel"
        }
        if (value == "," || value == ";") {
            return "punct"
        }
        if (value == "(" || value == "[") {
            return "open"
        }
        if (value == ")" || value == "]" || value == "?" || value == "!") {
            return "close"
        }
        return "ord"
    }

    private func hasError(node: MathNode): Bool {
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

    private func normalizeColor(color: String): String {
        if (color[0] == b'#') {
            return color
        }
        if (isNamedColor(color)) {
            return color
        }
        return "#${color}"
    }

    private func isValidColor(color: String): Bool {
        if (isNamedColor(color)) {
            return true
        }
        let hex = if (color[0] == b'#') { color[1..color.size] } else { color }
        if (!(hex.size == 3 || hex.size == 4 || hex.size == 6 || hex.size == 8)) {
            return false
        }
        for (ch in hex) {
            if (!((ch >= b'0' && ch <= b'9') || (ch >= b'a' && ch <= b'f') || (ch >= b'A' && ch <= b'F'))) {
                return false
            }
        }
        return true
    }

    private func isNamedColor(color: String): Bool {
        if (color.isEmpty()) {
            return false
        }
        for (ch in color) {
            if (!((ch >= b'a' && ch <= b'z') || (ch >= b'A' && ch <= b'Z'))) {
                return false
            }
        }
        return true
    }

    private func span(start: Int64, end: Int64): MathSourceSpan {
        return MathSourceSpan(
            startByte: start,
            endByte: end,
            startRune: countRunes(source[0..start]),
            endRune: countRunes(source[0..end])
        )
    }

    private func countRunes(text: String): Int64 {
        var count: Int64 = 0
        var i: Int64 = 0
        while (i < text.size) {
            count += 1
            i += nextRuneByteSize(text[i])
        }
        return count
    }

    private func nextRuneByteSize(first: Byte): Int64 {
        if ((first & 0b10000000) == 0) {
            return 1
        }
        if ((first & 0b11100000) == 0b11000000) {
            return 2
        }
        if ((first & 0b11110000) == 0b11100000) {
            return 3
        }
        return 4
    }

    private func isAsciiLetter(ch: Byte): Bool {
        return (ch >= b'a' && ch <= b'z') || (ch >= b'A' && ch <= b'Z')
    }

    private func isAsciiWhitespace(ch: Byte): Bool {
        return ch == b' ' || ch == b'\t' || ch == b'\n' || ch == b'\r'
    }

    private func digitValue(ch: Byte): Int64 {
        match (ch) {
            case b'0' => return 0
            case b'1' => return 1
            case b'2' => return 2
            case b'3' => return 3
            case b'4' => return 4
            case b'5' => return 5
            case b'6' => return 6
            case b'7' => return 7
            case b'8' => return 8
            case b'9' => return 9
            case _ => return -1
        }
    }

    private func skipAsciiWhitespace(): Unit {
        while (cursor < source.size && isAsciiWhitespace(source[cursor])) {
            cursor += 1
        }
    }

    private func skipIgnoredInput(): Unit {
        var keepSkipping = true
        while (keepSkipping) {
            keepSkipping = false
            skipAsciiWhitespace()
            if (cursor < source.size && source[cursor] == b'%') {
                while (cursor < source.size && source[cursor] != b'\n') {
                    cursor += 1
                }
                if (cursor < source.size && source[cursor] == b'\n') {
                    cursor += 1
                }
                keepSkipping = true
            }
        }
    }

    private func skipRelaxCommands(): Unit {
        var keepSkipping = true
        while (keepSkipping) {
            keepSkipping = false
            skipIgnoredInput()
            if (startsWithAsciiAt("\\relax", cursor)) {
                cursor += 6
                keepSkipping = true
            }
        }
    }

    private func startsWithAsciiAt(needle: String, offset: Int64): Bool {
        if (offset + needle.size > source.size) {
            return false
        }
        for (i in 0..needle.size) {
            if (source[offset + i] != needle[i]) {
                return false
            }
        }
        return true
    }

    private func startsWithCommandAt(command: String, offset: Int64): Bool {
        if (!startsWithAsciiAt(command, offset)) {
            return false
        }
        let end = offset + command.size
        if (end >= source.size) {
            return true
        }
        return !isAsciiLetter(source[end])
    }

    private func startsWithAsciiIn(text: String, needle: String, offset: Int64): Bool {
        if (offset + needle.size > text.size) {
            return false
        }
        for (i in 0..needle.size) {
            if (text[offset + i] != needle[i]) {
                return false
            }
        }
        return true
    }
}
