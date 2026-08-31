package mermaid4cj.parser

import std.collection.{ArrayList, HashMap, HashSet}
import mermaid4cj.core.{FlowDirection, FlowEdge, FlowEdgeMarker, FlowEdgeStyle, FlowNode, FlowNodeRef, FlowNodeShape, FlowNodeStyle, FlowParseResult, FlowSubgraph, FlowchartDiagram, TextRange}

class ParsedEdgeSyntax {
    let leftEnd: Int64
    let targetStart: Int64
    let label: ?TextRange
    let style: FlowEdgeStyle
    let length: Int64
    let markerStart: FlowEdgeMarker
    let markerEnd: FlowEdgeMarker

    init(leftEnd: Int64, targetStart: Int64, label: ?TextRange, style: FlowEdgeStyle, length: Int64, markerStart: FlowEdgeMarker, markerEnd: FlowEdgeMarker) {
        this.leftEnd = leftEnd
        this.targetStart = targetStart
        this.label = label
        this.style = style
        this.length = length
        this.markerStart = markerStart
        this.markerEnd = markerEnd
    }
}

class EdgeEndToken {
    let start: Int64
    let end: Int64
    let marker: FlowEdgeMarker

    init(start: Int64, end: Int64, marker: FlowEdgeMarker) {
        this.start = start
        this.end = end
        this.marker = marker
    }
}

public class FlowchartParser {
    public init() {}

    public func parse(source: String): FlowParseResult {
        let nodes = ArrayList<FlowNode>()
        let edges = ArrayList<FlowEdge>()
        let classStyles = HashMap<String, FlowNodeStyle>()
        let nodeClasses = HashMap<String, String>()
        let nodeStyles = HashMap<String, FlowNodeStyle>()
        let usedEdgeIds = HashSet<String>()
        let subgraphs = ArrayList<TextRange>()
        let subgraphDefs = ArrayList<FlowSubgraph>()
        let nodeParents = HashMap<String, String>()
        let subgraphStack = ArrayList<String>()
        var direction = FlowDirection.TD
        var sawHeader = false
        var lineNo: Int64 = 0
        let diagnostics = ArrayList<String>()

        var lineStart: Int64 = 0
        while (lineStart <= source.size) {
            if (lineStart == source.size) {
                break
            }
            var lineEnd = findLineEnd(source, lineStart)
            lineEnd = extendNodeDataLineEnd(source, lineStart, lineEnd)
            let rawLine = source[lineStart..lineEnd]
            lineNo++
            let range = trimAsciiRange(source, TextRange(lineStart, stripCommentEnd(source, lineStart, lineEnd)))
            if (range.isEmpty()) {
                lineStart = nextLineStart(source, lineEnd)
                continue
            }

            var statementStart = range.start
            while (statementStart <= range.end) {
                let statementEnd = findStatementEnd(source, statementStart, range.end)
                let statementRange = trimAsciiRange(source, TextRange(statementStart, statementEnd))
                if (!statementRange.isEmpty()) {
                    let statement = source[statementRange.start..statementRange.end]
                    validateNodeDataShapes(source, statementRange, diagnostics)
                    if (!diagnostics.isEmpty()) {
                        break
                    }
                    if (!sawHeader) {
                        let parsedDirection = parseHeader(statement)
                        if (let Some(dir) <- parsedDirection) {
                            direction = dir
                            sawHeader = true
                        } else {
                            diagnostics.add("Line ${lineNo}: expected graph or flowchart header")
                            break
                        }
                    } else if (statement.startsWith("subgraph ")) {
                        let subgraph = parseSubgraph(source, statementRange, subgraphStack, subgraphDefs.size)
                        subgraphs.add(subgraph.title)
                        subgraphDefs.add(subgraph)
                        subgraphStack.add(subgraph.id)
                    } else if (statement.startsWith("direction ") && !subgraphStack.isEmpty()) {
                        setCurrentSubgraphDirection(source, statementRange, subgraphStack, subgraphDefs)
                    } else if (statement == "end") {
                        if (!subgraphStack.isEmpty()) {
                            subgraphStack.remove(at: subgraphStack.size - 1)
                        }
                    } else if (parseClassDef(source, statementRange, classStyles)) {
                        ()
                    } else if (parseClass(source, statementRange, nodeClasses)) {
                        ()
                    } else if (parseStyle(source, statementRange, nodeStyles, nodes)) {
                        ()
                    } else if (parseLinkStyle(source, statementRange)) {
                        ()
                    } else if (!parseEdge(source, statementRange, nodes, edges, nodeClasses, nodeParents, currentSubgraph(subgraphStack), usedEdgeIds)) {
                        if (containsEdgeSyntax(statement)) {
                            diagnostics.add("Line ${lineNo}: invalid or incomplete flowchart edge")
                            break
                        }
                        parseNode(source, statementRange, nodes, nodeParents, currentSubgraph(subgraphStack))
                    }
                }
                if (statementEnd >= range.end || !diagnostics.isEmpty()) {
                    break
                }
                statementStart = statementEnd + 1
            }
            if (!diagnostics.isEmpty()) {
                break
            }
            lineStart = nextLineStart(source, lineEnd)
        }

        if (!sawHeader && diagnostics.isEmpty()) {
            diagnostics.add("Missing graph or flowchart header")
        }

        return FlowParseResult(
            FlowchartDiagram(
                source,
                direction,
                nodes,
                edges,
                classStyles: classStyles,
                nodeClasses: nodeClasses,
                nodeStyles: nodeStyles,
                subgraphs: subgraphs,
                subgraphDefs: subgraphDefs,
                nodeParents: nodeParents
            ),
            diagnostics: diagnostics.toArray()
        )
    }

    private func parseHeader(line: String): ?FlowDirection {
        let parts = line.split(" ", removeEmpty: true)
        if (parts.size == 0) {
            return None
        }
        let head = parts[0].toAsciiLower()
        if (head != "graph" && head != "flowchart" && head != "flowchart-v2" && head != "flowchart-elk") {
            return None
        }
        if (parts.size == 1) {
            return Some(FlowDirection.TD)
        }
        return Some(parseDirection(parts[1]))
    }

    private func parseDirection(value: String): FlowDirection {
        match (value.toAsciiUpper()) {
            case "LR" => return FlowDirection.LR
            case "RL" => return FlowDirection.RL
            case "BT" => return FlowDirection.BT
            case "TB" => return FlowDirection.TB
            case ">" => return FlowDirection.LR
            case "<" => return FlowDirection.RL
            case "^" => return FlowDirection.BT
            case "V" => return FlowDirection.TB
            case _ => return FlowDirection.TD
        }
    }

    private func parseEdge(
        source: String,
        range: TextRange,
        nodes: ArrayList<FlowNode>,
        edges: ArrayList<FlowEdge>,
        nodeClasses: HashMap<String, String>,
        nodeParents: HashMap<String, String>,
        currentParent: ?String,
        usedEdgeIds: HashSet<String>
    ): Bool {
        if (let Some(parsed) <- parseMermaidEdgeSyntax(source, range)) {
            var leftRange = trimAsciiRange(source, TextRange(range.start, parsed.leftEnd))
            var edgeId: ?String = None
            if (let Some(idSplit) <- findEdgeIdSplit(source, leftRange.start, leftRange.end)) {
                edgeId = Some(source[idSplit.start..idSplit.end])
                leftRange = trimAsciiRange(source, TextRange(leftRange.start, idSplit.start))
            }
            let sourceRefs = ArrayList<FlowNodeRef>()
            let sourceRanges = splitTargetList(source, leftRange)
            for (sourceRange in sourceRanges) {
                let sourceRef = parseNodeRef(source, sourceRange, nodes)
                assignNodeParent(nodeParents, sourceRef.id, currentParent)
                if (let Some(className) <- sourceRef.className) {
                    nodeClasses[sourceRef.id] = className
                }
                sourceRefs.add(sourceRef)
            }
            let rightRange = trimAsciiRange(source, TextRange(parsed.targetStart, range.end))
            if (rightRange.isEmpty()) {
                return false
            }
            let (targetRange, edgeLabel) = splitEdgeLabel(source, rightRange)
            if (targetRange.isEmpty()) {
                return false
            }
            if (let Some(nextEdgeStart) <- firstEdgeMarkerOffset(source[targetRange.start..targetRange.end])) {
                let firstTargetRange = trimAsciiRange(source, TextRange(targetRange.start, targetRange.start + nextEdgeStart))
                let firstTargetRefs = ArrayList<FlowNodeRef>()
                for (singleTargetRange in splitTargetList(source, firstTargetRange)) {
                    let targetRef = parseNodeRef(source, singleTargetRange, nodes)
                    assignNodeParent(nodeParents, targetRef.id, currentParent)
                    if (let Some(className) <- targetRef.className) {
                        nodeClasses[targetRef.id] = className
                    }
                    firstTargetRefs.add(targetRef)
                }
                for (sourceIndex in 0..sourceRefs.size) {
                    let sourceRef = sourceRefs[sourceIndex]
                    for (targetIndex in 0..firstTargetRefs.size) {
                        let targetRef = firstTargetRefs[targetIndex]
                        edges.add(FlowEdge(
                            sourceRef.id,
                            targetRef.id,
                            id: explicitEdgeIdFor(edgeId, usedEdgeIds, sourceIndex, targetIndex, sourceRefs.size),
                            label: edgeLabel ?? parsed.label,
                            style: parsed.style,
                            length: parsed.length,
                            directed: hasEndMarker(parsed.markerEnd),
                            markerStart: parsed.markerStart,
                            markerEnd: parsed.markerEnd
                        ))
                    }
                }
                return parseEdge(source, TextRange(firstTargetRange.start, targetRange.end), nodes, edges, nodeClasses, nodeParents, currentParent, usedEdgeIds)
            }
            let targetRanges = splitTargetList(source, targetRange)
            let targetRefs = ArrayList<FlowNodeRef>()
            for (singleTargetRange in targetRanges) {
                let targetRef = parseNodeRef(source, singleTargetRange, nodes)
                assignNodeParent(nodeParents, targetRef.id, currentParent)
                if (let Some(className) <- targetRef.className) {
                    nodeClasses[targetRef.id] = className
                }
                targetRefs.add(targetRef)
            }
            for (sourceIndex in 0..sourceRefs.size) {
                let sourceRef = sourceRefs[sourceIndex]
                for (targetIndex in 0..targetRefs.size) {
                    let targetRef = targetRefs[targetIndex]
                    edges.add(FlowEdge(
                        sourceRef.id,
                        targetRef.id,
                        id: explicitEdgeIdFor(edgeId, usedEdgeIds, sourceIndex, targetIndex, sourceRefs.size),
                        label: edgeLabel ?? parsed.label,
                        style: parsed.style,
                        length: parsed.length,
                        directed: hasEndMarker(parsed.markerEnd),
                        markerStart: parsed.markerStart,
                        markerEnd: parsed.markerEnd
                    ))
                }
            }
            return true
        }
        return false
    }

    private func explicitEdgeIdFor(edgeId: ?String, usedEdgeIds: HashSet<String>, sourceIndex: Int64, targetIndex: Int64, sourceCount: Int64): ?String {
        if (let Some(id) <- edgeId) {
            let selectedSourceIndex = if (sourceCount > 1) { sourceCount - 1 } else { 0 }
            if (sourceIndex == selectedSourceIndex && targetIndex == 0 && !usedEdgeIds.contains(id)) {
                usedEdgeIds.add(id)
                return Some(id)
            }
        }
        return None
    }

    private func firstEdgeMarkerOffset(text: String): ?Int64 {
        var best: ?Int64 = None
        for (marker in ["<-->", "<==>", "<-.->", "x--", "x==", "x-.", "o--", "o==", "o-.", "-->", "---", "==>", "===", "-.->", "-.-", "--x", "--o", "==x", "==o", ".-x", ".-o"]) {
            if (let Some(pos) <- text.indexOf(marker)) {
                if (best.isNone() || pos < best.getOrThrow()) {
                    best = Some(pos)
                }
            }
        }
        return best
    }

    private func splitTargetList(source: String, range: TextRange): Array<TextRange> {
        let result = ArrayList<TextRange>()
        var start = range.start
        var i = range.start
        var squareDepth: Int64 = 0
        var parenDepth: Int64 = 0
        var braceDepth: Int64 = 0
        var activeQuote: ?Byte = None
        while (i < range.end) {
            let ch = source[i]
            if (let Some(q) <- activeQuote) {
                if (ch == q) {
                    activeQuote = None
                }
                i++
                continue
            }
            if (ch == b'"' || ch == b'\'') {
                activeQuote = Some(ch)
                i++
                continue
            }
            if (ch == b'[') {
                squareDepth++
            } else if (ch == b']') {
                squareDepth = max(0, squareDepth - 1)
            } else if (ch == b'(') {
                parenDepth++
            } else if (ch == b')') {
                parenDepth = max(0, parenDepth - 1)
            } else if (ch == b'{') {
                braceDepth++
            } else if (ch == b'}') {
                braceDepth = max(0, braceDepth - 1)
            }
            if (ch == b'&' && squareDepth == 0 && parenDepth == 0 && braceDepth == 0) {
                let item = trimAsciiRange(source, TextRange(start, i))
                if (!item.isEmpty()) {
                    result.add(item)
                }
                start = i + 1
            }
            i++
        }
        let last = trimAsciiRange(source, TextRange(start, range.end))
        if (!last.isEmpty()) {
            result.add(last)
        }
        return result.toArray()
    }

    private func containsEdgeSyntax(statement: String): Bool {
        for (marker in ["<-->", "<==>", "<-.->", "-->", "---", "==>", "===", "-.->", "-.-", "--x", "--o", "==x", "==o", ".-x", ".-o"]) {
            if (statement.contains(marker)) {
                return true
            }
        }
        return false
    }

    private func splitEdgeLabel(source: String, range: TextRange): (TextRange, ?TextRange) {
        if (source[range.start] == b'|') {
            var i = range.start + 1
            while (i < range.end) {
                if (source[i] == b'|') {
                    return (
                        trimAsciiRange(source, TextRange(i + 1, range.end)),
                        Some(parseInlineLabelValue(source, trimAsciiRange(source, TextRange(range.start + 1, i))))
                    )
                }
                i++
            }
        }
        return (range, None)
    }

    private func parseInlineLabelValue(source: String, range: TextRange): TextRange {
        return unquoteRange(source, range)
    }

    private func parseMermaidEdgeSyntax(source: String, range: TextRange): ?ParsedEdgeSyntax {
        var best: ?ParsedEdgeSyntax = None
        for (startToken in ["<--", "<==", "<-.", "x--", "x==", "x-.", "o--", "o==", "o-.", "--", "==", "-."]) {
            var searchStart = range.start
            while (searchStart < range.end) {
                let haystack = source[searchStart..range.end]
                let found = haystack.indexOf(startToken)
                if (found.isNone()) {
                    break
                }
                let startAt = searchStart + found.getOrThrow()
                let labelStart = startAt + startToken.size
                if (startAt == range.start) {
                    searchStart = labelStart
                    continue
                }
                if (let Some(edgeEnd) <- findEdgeEndToken(source, labelStart, range.end, edgeStyleFromStart(startToken))) {
                    let label = parseInlineLabelValue(source, trimAsciiRange(source, TextRange(labelStart, edgeEnd.start)))
                    let textLabel: ?TextRange = if (label.isEmpty()) { None<TextRange> } else { Some(label) }
                    let endToken = source[edgeEnd.start..edgeEnd.end]
                    let fullToken = if (textLabel.isSome()) { endToken } else { startToken + endToken }
                    let parsed = ParsedEdgeSyntax(
                        startAt,
                        edgeEnd.end,
                        textLabel,
                        edgeStyleFromStart(startToken),
                        edgeLengthFromLinkToken(fullToken),
                        markerFromStart(startToken),
                        edgeEnd.marker
                    )
                    if (best.isNone() || parsed.leftEnd < best.getOrThrow().leftEnd) {
                        best = Some(parsed)
                    }
                    break
                }
                searchStart = labelStart
            }
        }
        return best
    }

    private func edgeLengthFromLinkToken(token: String): Int64 {
        let text = token.trimAscii()
        if (text.isEmpty()) {
            return 1
        }
        var lineStart: Int64 = 0
        let lineEnd = text.size - 1
        if (text[0] == b'<' || text[0] == b'x' || text[0] == b'o') {
            lineStart = 1
        }
        var dots: Int64 = 0
        for (i in lineStart..lineEnd) {
            if (text[i] == b'.') {
                dots++
            }
        }
        if (dots > 0) {
            return max(1, dots)
        }
        return max(1, lineEnd - lineStart - 1)
    }

    private func findEdgeEndToken(source: String, start: Int64, end: Int64, style: FlowEdgeStyle): ?EdgeEndToken {
        var i = start
        while (i < end) {
            if (isSolid(style)) {
                if (i == start) {
                    if (source[i] == b'>') {
                        return Some(EdgeEndToken(i, i + 1, FlowEdgeMarker.Point))
                    } else if (source[i] == b'o') {
                        return Some(EdgeEndToken(i, i + 1, FlowEdgeMarker.Circle))
                    } else if (source[i] == b'x') {
                        return Some(EdgeEndToken(i, i + 1, FlowEdgeMarker.Cross))
                    }
                }
                if (source[i] == b'-') {
                    let runEnd = consumeSame(source, i, end, b'-')
                    if (runEnd < end) {
                        if (source[runEnd] == b'>') {
                            return Some(EdgeEndToken(i, runEnd + 1, FlowEdgeMarker.Point))
                        } else if (source[runEnd] == b'o') {
                            return Some(EdgeEndToken(i, runEnd + 1, FlowEdgeMarker.Circle))
                        } else if (source[runEnd] == b'x') {
                            return Some(EdgeEndToken(i, runEnd + 1, FlowEdgeMarker.Cross))
                        }
                    }
                    if (runEnd - i >= 1) {
                        return Some(EdgeEndToken(i, runEnd, FlowEdgeMarker.None))
                    }
                }
            } else if (isThick(style)) {
                if (i == start) {
                    if (source[i] == b'>') {
                        return Some(EdgeEndToken(i, i + 1, FlowEdgeMarker.Point))
                    } else if (source[i] == b'o') {
                        return Some(EdgeEndToken(i, i + 1, FlowEdgeMarker.Circle))
                    } else if (source[i] == b'x') {
                        return Some(EdgeEndToken(i, i + 1, FlowEdgeMarker.Cross))
                    }
                }
                if (source[i] == b'=') {
                    let runEnd = consumeSame(source, i, end, b'=')
                    if (runEnd < end) {
                        if (source[runEnd] == b'>') {
                            return Some(EdgeEndToken(i, runEnd + 1, FlowEdgeMarker.Point))
                        } else if (source[runEnd] == b'o') {
                            return Some(EdgeEndToken(i, runEnd + 1, FlowEdgeMarker.Circle))
                        } else if (source[runEnd] == b'x') {
                            return Some(EdgeEndToken(i, runEnd + 1, FlowEdgeMarker.Cross))
                        }
                    }
                    if (runEnd - i >= 1) {
                        return Some(EdgeEndToken(i, runEnd, FlowEdgeMarker.None))
                    }
                }
            } else {
                if (i == start && source[i] == b'-') {
                    let dashEnd = consumeSame(source, i, end, b'-')
                    if (dashEnd < end) {
                        if (source[dashEnd] == b'>') {
                            return Some(EdgeEndToken(i, dashEnd + 1, FlowEdgeMarker.Point))
                        } else if (source[dashEnd] == b'o') {
                            return Some(EdgeEndToken(i, dashEnd + 1, FlowEdgeMarker.Circle))
                        } else if (source[dashEnd] == b'x') {
                            return Some(EdgeEndToken(i, dashEnd + 1, FlowEdgeMarker.Cross))
                        }
                    }
                    return Some(EdgeEndToken(i, dashEnd, FlowEdgeMarker.None))
                }
                if (source[i] == b'.') {
                    let dotEnd = consumeSame(source, i, end, b'.')
                    if (dotEnd < end && source[dotEnd] == b'-') {
                        let dashEnd = consumeSame(source, dotEnd, end, b'-')
                        if (dashEnd < end) {
                            if (source[dashEnd] == b'>') {
                                return Some(EdgeEndToken(i, dashEnd + 1, FlowEdgeMarker.Point))
                            } else if (source[dashEnd] == b'o') {
                                return Some(EdgeEndToken(i, dashEnd + 1, FlowEdgeMarker.Circle))
                            } else if (source[dashEnd] == b'x') {
                                return Some(EdgeEndToken(i, dashEnd + 1, FlowEdgeMarker.Cross))
                            }
                        }
                        return Some(EdgeEndToken(i, dashEnd, FlowEdgeMarker.None))
                    }
                }
            }
            i++
        }
        return None
    }

    private func consumeSame(source: String, start: Int64, end: Int64, ch: Byte): Int64 {
        var i = start
        while (i < end && source[i] == ch) {
            i++
        }
        return i
    }

    private func edgeStyleFromStart(token: String): FlowEdgeStyle {
        if (token.contains("=")) {
            return FlowEdgeStyle.Thick
        }
        if (token.contains(".")) {
            return FlowEdgeStyle.Dotted
        }
        return FlowEdgeStyle.Solid
    }

    private func markerFromStart(token: String): FlowEdgeMarker {
        if (token.startsWith("<")) {
            return FlowEdgeMarker.Point
        }
        if (token.startsWith("o")) {
            return FlowEdgeMarker.Circle
        }
        if (token.startsWith("x")) {
            return FlowEdgeMarker.Cross
        }
        return FlowEdgeMarker.None
    }

    private func hasEndMarker(marker: FlowEdgeMarker): Bool {
        match (marker) {
            case FlowEdgeMarker.None => return false
            case _ => return true
        }
    }

    private func isSolid(style: FlowEdgeStyle): Bool {
        match (style) {
            case FlowEdgeStyle.Solid => return true
            case _ => return false
        }
    }

    private func isThick(style: FlowEdgeStyle): Bool {
        match (style) {
            case FlowEdgeStyle.Thick => return true
            case _ => return false
        }
    }

    private func findEdgeIdSplit(source: String, start: Int64, end: Int64): ?TextRange {
        var i = end - 1
        while (i >= start) {
            if (source[i] == b'@') {
                var idStart = i - 1
                while (idStart >= start && !isAsciiBlank(source[idStart])) {
                    if (idStart == 0) {
                        break
                    }
                    idStart--
                }
                if (idStart < i && isAsciiBlank(source[idStart])) {
                    idStart++
                }
                let id = trimAsciiRange(source, TextRange(idStart, i))
                if (!id.isEmpty()) {
                    return Some(id)
                }
                return None
            }
            if (isAsciiBlank(source[i])) {
                break
            }
            if (i == 0) {
                break
            }
            i--
        }
        return None
    }

    private func parseNode(source: String, range: TextRange, nodes: ArrayList<FlowNode>, nodeParents: HashMap<String, String>, currentParent: ?String): Unit {
        for (nodeRange in splitTargetList(source, range)) {
            let nodeRef = parseNodeRef(source, nodeRange, nodes)
            if (nodeRef.id.isEmpty()) {
                continue
            }
            assignNodeParent(nodeParents, nodeRef.id, currentParent)
        }
    }

    private func parseSubgraph(source: String, range: TextRange, subgraphStack: ArrayList<String>, generatedIndex: Int64): FlowSubgraph {
        let body = trimAsciiRange(source, TextRange(range.start + "subgraph ".size, range.end))
        if (body.isEmpty()) {
            return FlowSubgraph("", body, parentId: currentSubgraph(subgraphStack))
        }
        if (isQuotedRange(source, body)) {
            return FlowSubgraph("subGraph${generatedIndex}", unquoteRange(source, body), parentId: currentSubgraph(subgraphStack))
        }
        let bracket = source[body.start..body.end].indexOf("[")
        if (let Some(pos) <- bracket) {
            let idRange = trimAsciiRange(source, TextRange(body.start, body.start + pos))
            let titleRange = parseSubgraphTitle(source, TextRange(body.start + pos, body.end), idRange)
            return FlowSubgraph(source[idRange.start..idRange.end], titleRange, parentId: currentSubgraph(subgraphStack))
        }
        let split = splitFirstAsciiBlank(source, body)
        let idRange = split[0]
        if (split[1].isEmpty()) {
            return FlowSubgraph(source[idRange.start..idRange.end], idRange, parentId: currentSubgraph(subgraphStack))
        }
        return FlowSubgraph("subGraph${generatedIndex}", body, parentId: currentSubgraph(subgraphStack))
    }

    private func setCurrentSubgraphDirection(source: String, range: TextRange, subgraphStack: ArrayList<String>, subgraphDefs: ArrayList<FlowSubgraph>): Unit {
        let dirRange = trimAsciiRange(source, TextRange(range.start + "direction ".size, range.end))
        if (dirRange.isEmpty()) {
            return
        }
        let id = subgraphStack[subgraphStack.size - 1]
        let dir = parseDirection(source[dirRange.start..dirRange.end])
        var index = subgraphDefs.size - 1
        while (index >= 0) {
            if (subgraphDefs[index].id == id) {
                let current = subgraphDefs[index]
                subgraphDefs[index] = FlowSubgraph(current.id, current.title, parentId: current.parentId, dir: Some(dir), explicitDir: true)
                return
            }
            index--
        }
    }

    private func parseSubgraphTitle(source: String, range: TextRange, fallback: TextRange): TextRange {
        if (range.isEmpty() || source[range.start] != b'[') {
            return fallback
        }
        var i = range.start + 1
        while (i < range.end) {
            if (source[i] == b']') {
                let title = trimAsciiRange(source, TextRange(range.start + 1, i))
                if (!title.isEmpty()) {
                    return unquoteRange(source, title)
                }
                return fallback
            }
            i++
        }
        return fallback
    }

    private func currentSubgraph(subgraphStack: ArrayList<String>): ?String {
        if (subgraphStack.isEmpty()) {
            return None
        }
        return Some(subgraphStack[subgraphStack.size - 1])
    }

    private func assignNodeParent(nodeParents: HashMap<String, String>, id: String, parent: ?String): Unit {
        if (id.isEmpty() || nodeParents.contains(id)) {
            return
        }
        if (let Some(parentId) <- parent) {
            nodeParents[id] = parentId
        }
    }

    private func parseNodeRef(source: String, range: TextRange, nodes: ArrayList<FlowNode>): FlowNodeRef {
        let trimmed = trimAsciiRange(source, range)
        if (trimmed.isEmpty()) {
            return FlowNodeRef("", TextRange(0, 0))
        }
        let (bodyRange, className) = splitInlineClass(source, trimmed)
        if (let Some(dataRef) <- parseNodeDataRef(source, bodyRange, className, nodes)) {
            return dataRef
        }
        let text = source[bodyRange.start..bodyRange.end]
        let firstShape = findFirstShapeStart(text)
        if (let Some(shapeStart) <- firstShape) {
            let idRange = trimAsciiRange(source, TextRange(bodyRange.start, bodyRange.start + shapeStart))
            let id = source[idRange.start..idRange.end]
            let shape = parseShape(text, shapeStart)
            let label = parseShapeLabel(source, bodyRange, shapeStart)
            let finalLabel = if (label.isEmpty()) { idRange } else { label }
            addOrUpdateNode(nodes, id, finalLabel, shape, className)
            return FlowNodeRef(id, finalLabel, shape: shape, className: className)
        }
        let id = source[bodyRange.start..bodyRange.end]
        addOrUpdateNode(nodes, id, bodyRange, FlowNodeShape.Rectangle, className)
        return FlowNodeRef(id, bodyRange, className: className)
    }

    private func parseNodeDataRef(source: String, range: TextRange, className: ?String, nodes: ArrayList<FlowNode>): ?FlowNodeRef {
        let text = source[range.start..range.end]
        if (let Some(pos) <- text.indexOf("@{")) {
            let baseRange = trimAsciiRange(source, TextRange(range.start, range.start + pos))
            if (baseRange.isEmpty()) {
                return None
            }
            let dataStart = range.start + pos + 2
            let dataEnd = findNodeDataEnd(source, dataStart, range.end)
            if (dataEnd.isNone()) {
                return None
            }
            let (id, defaultLabel, defaultShape) = parseNodeDataBase(source, baseRange)
            if (id.isEmpty()) {
                return None
            }
            let dataRange = TextRange(dataStart, dataEnd.getOrThrow())
            let shape = parseNodeDataShape(source, dataRange) ?? defaultShape
            let label = parseNodeDataLabel(source, dataRange) ?? defaultLabel
            let labelText = parseNodeDataLabelText(source, dataRange)
            addOrUpdateNode(nodes, id, label, shape, className, labelText: labelText)
            return Some(FlowNodeRef(id, label, labelText: labelText, shape: shape, className: className))
        }
        return None
    }

    private func parseNodeDataBase(source: String, range: TextRange): (String, TextRange, FlowNodeShape) {
        let text = source[range.start..range.end]
        if (let Some(shapeStart) <- findFirstShapeStart(text)) {
            let idRange = trimAsciiRange(source, TextRange(range.start, range.start + shapeStart))
            let id = source[idRange.start..idRange.end]
            let shape = parseShape(text, shapeStart)
            let label = parseShapeLabel(source, range, shapeStart)
            let finalLabel = if (label.isEmpty()) { idRange } else { label }
            return (id, finalLabel, shape)
        }
        let id = source[range.start..range.end]
        return (id, range, FlowNodeShape.Rectangle)
    }

    private func findNodeDataEnd(source: String, start: Int64, end: Int64): ?Int64 {
        var i = start
        var activeQuote: ?Byte = None
        while (i < end) {
            let ch = source[i]
            if (let Some(q) <- activeQuote) {
                if (ch == b'\\' && i + 1 < end) {
                    i += 2
                    continue
                }
                if (ch == q) {
                    activeQuote = None
                }
            } else if (ch == b'"' || ch == b'\'') {
                activeQuote = Some(ch)
            } else if (ch == b'}') {
                return Some(i)
            }
            i++
        }
        return None
    }

    private func parseNodeDataShape(source: String, range: TextRange): ?FlowNodeShape {
        if (let Some(valueRange) <- findNodeDataValueRange(source, range, "shape")) {
            let value = source[valueRange.start..valueRange.end].trimAscii().toAsciiLower()
            return Some(shapeFromNodeDataName(value))
        }
        return None
    }

    private func parseNodeDataLabel(source: String, range: TextRange): ?TextRange {
        if (let Some(valueRange) <- findNodeDataValueRange(source, range, "label")) {
            if (!valueRange.isEmpty()) {
                return Some(parseNodeDataLabelValue(source, valueRange))
            }
        }
        return None
    }

    private func parseNodeDataLabelValue(source: String, range: TextRange): TextRange {
        let trimmed = trimAsciiRange(source, range)
        if (trimmed.isEmpty()) {
            return trimmed
        }
        if (source[trimmed.start] == b'|') {
            return trimAsciiRange(source, TextRange(trimmed.start + 1, trimmed.end))
        }
        return unquoteRange(source, trimmed)
    }

    private func parseNodeDataLabelText(source: String, range: TextRange): ?String {
        if (let Some(valueRange) <- findNodeDataValueRange(source, range, "label")) {
            let trimmed = trimAsciiRange(source, valueRange)
            if (trimmed.isEmpty()) {
                return None
            }
            if (source[trimmed.start] == b'|') {
                return Some(normalizeBlockNodeDataLabel(source, TextRange(trimmed.start + 1, trimmed.end)))
            }
            if (isQuotedRange(source, trimmed)) {
                let body = TextRange(trimmed.start + 1, trimmed.end - 1)
                if (rangeContainsLineBreak(source, body)) {
                    return Some(normalizeQuotedNodeDataLabel(source, body))
                }
            }
        }
        return None
    }

    private func normalizeQuotedNodeDataLabel(source: String, range: TextRange): String {
        let out = StringBuilder(range.size)
        var lineStart = range.start
        var first = true
        while (lineStart <= range.end) {
            let lineEnd = findLineEndWithin(source, lineStart, range.end)
            let line = trimAsciiRange(source, TextRange(lineStart, lineEnd))
            if (!first) {
                out.append("\n")
            }
            out.append(source[line.start..line.end])
            first = false
            if (lineEnd >= range.end) {
                break
            }
            lineStart = nextLineStart(source, lineEnd)
        }
        return out.toString()
    }

    private func normalizeBlockNodeDataLabel(source: String, range: TextRange): String {
        var contentStart = range.start
        while (contentStart < range.end && (source[contentStart] == b'\r' || source[contentStart] == b'\n')) {
            contentStart = nextLineStart(source, contentStart)
        }
        let minIndent = minBlockIndent(source, TextRange(contentStart, range.end))
        let out = StringBuilder(range.size)
        var lineStart = contentStart
        while (lineStart < range.end) {
            let lineEnd = findLineEndWithin(source, lineStart, range.end)
            var textStart = lineStart
            var dropped: Int64 = 0
            while (textStart < lineEnd && dropped < minIndent && (source[textStart] == b' ' || source[textStart] == b'\t')) {
                textStart++
                dropped++
            }
            out.append(source[textStart..lineEnd])
            out.append("\n")
            if (lineEnd >= range.end) {
                break
            }
            lineStart = nextLineStart(source, lineEnd)
        }
        return out.toString()
    }

    private func minBlockIndent(source: String, range: TextRange): Int64 {
        var minIndent: ?Int64 = None
        var lineStart = range.start
        while (lineStart < range.end) {
            let lineEnd = findLineEndWithin(source, lineStart, range.end)
            var i = lineStart
            var indent: Int64 = 0
            while (i < lineEnd && (source[i] == b' ' || source[i] == b'\t')) {
                indent++
                i++
            }
            if (i < lineEnd) {
                if (minIndent.isNone() || indent < minIndent.getOrThrow()) {
                    minIndent = Some(indent)
                }
            }
            if (lineEnd >= range.end) {
                break
            }
            lineStart = nextLineStart(source, lineEnd)
        }
        return minIndent ?? 0
    }

    private func findLineEndWithin(source: String, start: Int64, end: Int64): Int64 {
        var i = start
        while (i < end) {
            if (source[i] == b'\n' || source[i] == b'\r') {
                return i
            }
            i++
        }
        return end
    }

    private func rangeContainsLineBreak(source: String, range: TextRange): Bool {
        var i = range.start
        while (i < range.end) {
            if (source[i] == b'\n' || source[i] == b'\r') {
                return true
            }
            i++
        }
        return false
    }

    private func findNodeDataValueRange(source: String, range: TextRange, expectedKey: String): ?TextRange {
        var i = range.start
        while (i < range.end) {
            while (i < range.end && (isAsciiBlank(source[i]) || source[i] == b',')) {
                i++
            }
            let keyStart = i
            while (i < range.end && source[i] != b':') {
                if (source[i] == b',' || source[i] == b'\n' || source[i] == b'\r') {
                    break
                }
                i++
            }
            if (i >= range.end || source[i] != b':') {
                i++
                continue
            }
            let keyRange = trimAsciiRange(source, TextRange(keyStart, i))
            let valueStart = i + 1
            let valueEnd = findNodeDataValueEnd(source, valueStart, range.end)
            if (source[keyRange.start..keyRange.end] == expectedKey) {
                return Some(trimAsciiRange(source, TextRange(valueStart, valueEnd)))
            }
            i = valueEnd
            if (i < range.end && source[i] == b',') {
                i++
            }
        }
        return None
    }

    private func findNodeDataValueEnd(source: String, start: Int64, end: Int64): Int64 {
        var i = start
        var activeQuote: ?Byte = None
        while (i < end) {
            let ch = source[i]
            if (let Some(q) <- activeQuote) {
                if (ch == b'\\' && i + 1 < end) {
                    i += 2
                    continue
                }
                if (ch == q) {
                    activeQuote = None
                }
            } else if (ch == b'"' || ch == b'\'') {
                activeQuote = Some(ch)
            } else if (ch == b',') {
                return i
            } else if ((ch == b'\n' || ch == b'\r') && nextLineStartsNodeDataKey(source, i + 1, end)) {
                return i
            }
            i++
        }
        return end
    }

    private func nextLineStartsNodeDataKey(source: String, start: Int64, end: Int64): Bool {
        var i = start
        while (i < end && isAsciiBlank(source[i])) {
            i++
        }
        if (i >= end || !isNodeDataKeyChar(source[i])) {
            return false
        }
        while (i < end && isNodeDataKeyChar(source[i])) {
            i++
        }
        while (i < end && (source[i] == b' ' || source[i] == b'\t')) {
            i++
        }
        return i < end && source[i] == b':'
    }

    private func isNodeDataKeyChar(ch: Byte): Bool {
        return (ch >= b'a' && ch <= b'z') || (ch >= b'A' && ch <= b'Z') || ch == b'_' || ch == b'-'
    }

    private func shapeFromNodeDataName(value: String): FlowNodeShape {
        match (value) {
            case "rounded" | "event" => return FlowNodeShape.Rounded
            case "circle" => return FlowNodeShape.Circle
            case "diamond" | "decision" | "diam" => return FlowNodeShape.Diamond
            case "cyl" | "cylinder" | "database" | "db" => return FlowNodeShape.Cylinder
            case "datastore" | "data-store" => return FlowNodeShape.Datastore
            case "stadium" | "pill" | "terminal" => return FlowNodeShape.Stadium
            case "subroutine" | "fr-rect" | "framed-rectangle" | "subproc" => return FlowNodeShape.Subroutine
            case "hex" | "hexagon" | "prepare" => return FlowNodeShape.Hexagon
            case "lean-r" | "lean-right" | "in-out" => return FlowNodeShape.LeanRight
            case "lean-l" | "lean-left" | "out-in" => return FlowNodeShape.LeanLeft
            case "trap-b" | "trapezoid-bottom" | "trapezoid" | "priority" => return FlowNodeShape.Trapezoid
            case "trap-t" | "trapezoid-top" | "inv-trapezoid" | "manual" => return FlowNodeShape.InvTrapezoid
            case "dbl-circ" | "double-circle" => return FlowNodeShape.DoubleCircle
            case "text" => return FlowNodeShape.Text
            case "notched-rectangle" | "card" | "notch-rect" => return FlowNodeShape.Card
            case "shaded-process" | "lined-process" | "lined-rectangle" | "lin-proc" | "lin-rect" => return FlowNodeShape.ShadedProcess
            case "sm-circ" | "small-circle" | "start" => return FlowNodeShape.SmallCircle
            case "fr-circ" | "framed-circle" | "stop" => return FlowNodeShape.FramedCircle
            case "f-circ" | "junction" | "filled-circle" => return FlowNodeShape.FilledCircle
            case "fork" | "join" => return FlowNodeShape.Fork
            case "document" | "doc" => return FlowNodeShape.Document
            case "procs" | "processes" | "st-rect" | "stacked-rectangle" => return FlowNodeShape.MultiProcess
            case "div-rect" | "div-proc" | "divided-rectangle" | "divided-process" => return FlowNodeShape.DividedProcess
            case "tri" | "sm-tri" | "extract" | "small-triangle" | "triangle" => return FlowNodeShape.Triangle
            case "sl-rect" | "manual-input" | "sloped-rectangle" => return FlowNodeShape.SlopedRectangle
            case "cross-circ" | "summary" | "crossed-circle" => return FlowNodeShape.CrossedCircle
            case "tag-rect" | "tag-proc" | "tagged-rectangle" | "tagged-process" => return FlowNodeShape.TaggedProcess
            case "tag-doc" | "tagged-document" => return FlowNodeShape.TaggedDocument
            case "flag" | "paper-tape" => return FlowNodeShape.Flag
            case "hourglass" | "collate" => return FlowNodeShape.Hourglass
            case "notch-pent" | "loop-limit" | "notched-pentagon" => return FlowNodeShape.NotchedPentagon
            case "flip-tri" | "manual-file" | "flipped-triangle" => return FlowNodeShape.FlippedTriangle
            case "delay" | "half-rounded-rectangle" => return FlowNodeShape.Delay
            case "curv-trap" | "display" | "curved-trapezoid" => return FlowNodeShape.CurvedTrapezoid
            case "win-pane" | "internal-storage" | "window-pane" => return FlowNodeShape.WindowPane
            case "lin-cyl" | "disk" | "lined-cylinder" => return FlowNodeShape.LinedCylinder
            case "h-cyl" | "das" | "horizontal-cylinder" => return FlowNodeShape.HorizontalCylinder
            case "docs" | "documents" | "st-doc" | "stacked-document" => return FlowNodeShape.MultiDocument
            case "lin-doc" | "lined-document" => return FlowNodeShape.LinedDocument
            case "bang" => return FlowNodeShape.Bang
            case "cloud" => return FlowNodeShape.Cloud
            case "bolt" | "com-link" | "lightning-bolt" => return FlowNodeShape.LightningBolt
            case "bow-rect" | "stored-data" | "bow-tie-rectangle" => return FlowNodeShape.BowTieRectangle
            case "brace" | "comment" | "brace-l" => return FlowNodeShape.CurlyBraceLeft
            case "brace-r" => return FlowNodeShape.CurlyBraceRight
            case "braces" => return FlowNodeShape.CurlyBraces
            case _ => return FlowNodeShape.Rectangle
        }
    }

    private func validateNodeDataShapes(source: String, range: TextRange, diagnostics: ArrayList<String>): Unit {
        var searchStart = range.start
        while (searchStart < range.end) {
            let text = source[searchStart..range.end]
            let found = text.indexOf("@{")
            if (found.isNone()) {
                return
            }
            let dataStart = searchStart + found.getOrThrow() + 2
            let dataEnd = findNodeDataEnd(source, dataStart, range.end)
            if (dataEnd.isNone()) {
                return
            }
            let dataRange = TextRange(dataStart, dataEnd.getOrThrow())
            if (let Some(shapeRange) <- findNodeDataValueRange(source, dataRange, "shape")) {
                let shapeName = source[shapeRange.start..shapeRange.end].trimAscii()
                if (shapeName != shapeName.toAsciiLower() || shapeName.contains("_")) {
                    diagnostics.add("No such shape: ${shapeName}. Shape names should be lowercase.")
                    return
                }
                if (!isKnownMermaidNodeDataShape(shapeName)) {
                    diagnostics.add("No such shape: ${shapeName}.")
                    return
                }
            }
            searchStart = dataEnd.getOrThrow() + 1
        }
    }

    private func isKnownMermaidNodeDataShape(value: String): Bool {
        match (value) {
            case "rect" | "process" | "proc" | "rectangle" =>
                return true
            case "rounded" | "event" =>
                return true
            case "circle" =>
                return true
            case "stadium" | "pill" | "terminal" =>
                return true
            case "fr-rect" | "framed-rectangle" | "subproc" | "subroutine" =>
                return true
            case "cyl" | "db" | "cylinder" | "database" =>
                return true
            case "datastore" | "data-store" =>
                return true
            case "diam" | "decision" | "diamond" =>
                return true
            case "hex" | "hexagon" | "prepare" =>
                return true
            case "lean-r" | "lean-right" | "in-out" =>
                return true
            case "lean-l" | "lean-left" | "out-in" =>
                return true
            case "trap-b" | "trapezoid-bottom" | "priority" | "trapezoid" =>
                return true
            case "trap-t" | "trapezoid-top" | "manual" | "inv-trapezoid" =>
                return true
            case "dbl-circ" | "double-circle" =>
                return true
            case "text" =>
                return true
            case "notched-rectangle" | "card" | "notch-rect" =>
                return true
            case "shaded-process" | "lined-process" | "lined-rectangle" | "lin-proc" | "lin-rect" =>
                return true
            case "sm-circ" | "small-circle" | "start" =>
                return true
            case "fr-circ" | "framed-circle" | "stop" =>
                return true
            case "fork" | "join" =>
                return true
            case "brace" | "comment" | "brace-l" =>
                return true
            case "brace-r" | "braces" =>
                return true
            case "bolt" | "com-link" | "lightning-bolt" =>
                return true
            case "document" | "doc" =>
                return true
            case "delay" | "half-rounded-rectangle" =>
                return true
            case "h-cyl" | "das" | "horizontal-cylinder" =>
                return true
            case "lin-cyl" | "disk" | "lined-cylinder" =>
                return true
            case "curv-trap" | "display" | "curved-trapezoid" =>
                return true
            case "div-rect" | "div-proc" | "divided-rectangle" | "divided-process" =>
                return true
            case "tri" | "sm-tri" | "extract" | "small-triangle" | "triangle" =>
                return true
            case "win-pane" | "internal-storage" | "window-pane" =>
                return true
            case "f-circ" | "junction" | "filled-circle" =>
                return true
            case "lin-doc" | "lined-document" =>
                return true
            case "notch-pent" | "loop-limit" | "notched-pentagon" =>
                return true
            case "flip-tri" | "manual-file" | "flipped-triangle" =>
                return true
            case "sl-rect" | "manual-input" | "sloped-rectangle" =>
                return true
            case "docs" | "documents" | "st-doc" | "stacked-document" =>
                return true
            case "procs" | "processes" | "st-rect" | "stacked-rectangle" =>
                return true
            case "flag" | "paper-tape" =>
                return true
            case "bow-rect" | "stored-data" | "bow-tie-rectangle" =>
                return true
            case "cross-circ" | "summary" | "crossed-circle" =>
                return true
            case "tag-doc" | "tagged-document" =>
                return true
            case "tag-rect" | "tag-proc" | "tagged-rectangle" | "tagged-process" =>
                return true
            case "cloud" | "hourglass" | "bang" =>
                return true
            case _ =>
                return false
        }
    }

    private func findFirstShapeStart(text: String): ?Int64 {
        var best: ?Int64 = None
        for (token in ["(((", "{{", "[(", "[[", "([", "(-", "((", "[/", "[\\", ">", "{", "[", "("]) {
            if (let Some(pos) <- text.indexOf(token)) {
                if (best.isNone() || pos < best.getOrThrow()) {
                    best = Some(pos)
                }
            }
        }
        return best
    }

    private func parseShape(text: String, start: Int64): FlowNodeShape {
        if (text[start..text.size].startsWith("(((")) {
            return FlowNodeShape.DoubleCircle
        }
        if (text[start..text.size].startsWith("{{")) {
            return FlowNodeShape.Hexagon
        }
        if (text[start..text.size].startsWith("[(")) {
            return FlowNodeShape.Cylinder
        }
        if (text[start..text.size].startsWith("[[")) {
            return FlowNodeShape.Subroutine
        }
        if (text[start..text.size].startsWith("((")) {
            return FlowNodeShape.Circle
        }
        if (text[start..text.size].startsWith("([")) {
            return FlowNodeShape.Stadium
        }
        if (text[start..text.size].startsWith("(-")) {
            return FlowNodeShape.Ellipse
        }
        if (text[start..text.size].startsWith("[/")) {
            if (text.indexOf("\\]", start + 2).isSome()) {
                return FlowNodeShape.Trapezoid
            }
            return FlowNodeShape.LeanRight
        }
        if (text[start..text.size].startsWith("[\\")) {
            if (text.indexOf("/]", start + 2).isSome()) {
                return FlowNodeShape.InvTrapezoid
            }
            return FlowNodeShape.LeanLeft
        }
        if (text[start] == b'(') {
            return FlowNodeShape.Rounded
        }
        if (text[start] == b'{') {
            return FlowNodeShape.Diamond
        }
        if (text[start] == b'>') {
            return FlowNodeShape.Odd
        }
        return FlowNodeShape.Rectangle
    }

    private func parseShapeLabel(source: String, nodeRange: TextRange, start: Int64): TextRange {
        let text = source[nodeRange.start..nodeRange.end]
        let opener = if (text[start..text.size].startsWith("[(")) {
            "[("
        } else if (text[start..text.size].startsWith("(((")) {
            "((("
        } else if (text[start..text.size].startsWith("{{")) {
            "{{"
        } else if (text[start..text.size].startsWith("[[")) {
            "[["
        } else if (text[start..text.size].startsWith("((")) {
            "(("
        } else if (text[start..text.size].startsWith("([")) {
            "(["
        } else if (text[start..text.size].startsWith("(-")) {
            "(-"
        } else if (text[start..text.size].startsWith("[/")) {
            "[/"
        } else if (text[start..text.size].startsWith("[\\")) {
            "[\\"
        } else if (text[start] == b'>') {
            ">"
        } else if (text[start] == b'(') {
            "("
        } else if (text[start] == b'{') {
            "{"
        } else {
            "["
        }
        let closer = if (opener == "[(") {
            ")]"
        } else if (opener == "(((") {
            ")))"
        } else if (opener == "{{") {
            "}}"
        } else if (opener == "[[") {
            "]]"
        } else if (opener == "((") {
            "))"
        } else if (opener == "([" ) {
            "])"
        } else if (opener == "(-") {
            "-)"
        } else if (opener == "[/") {
            if (text.indexOf("\\]", start + opener.size).isSome()) { "\\]" } else { "/]" }
        } else if (opener == "[\\") {
            if (text.indexOf("/]", start + opener.size).isSome()) { "/]" } else { "\\]" }
        } else if (opener == ">") {
            "]"
        } else if (opener == "(") {
            ")"
        } else if (opener == "{") {
            "}"
        } else {
            "]"
        }
        let labelStart = nodeRange.start + start + opener.size
        if (let Some(end) <- text.indexOf(closer, start + opener.size)) {
            return unquoteRange(source, trimAsciiRange(source, TextRange(labelStart, nodeRange.start + end)))
        }
        return unquoteRange(source, trimAsciiRange(source, TextRange(labelStart, nodeRange.end)))
    }

    private func addOrUpdateNode(nodes: ArrayList<FlowNode>, id: String, label: TextRange, shape: FlowNodeShape, className: ?String, labelText!: ?String = None): Unit {
        if (id.isEmpty()) {
            return
        }
        for (i in 0..nodes.size) {
            if (nodes[i].id == id) {
                if (nodes[i].label.isEmpty() && !label.isEmpty()) {
                    nodes[i] = FlowNode(id, label, labelText: labelText, shape: shape, className: className)
                }
                return
            }
        }
        nodes.add(FlowNode(id, label, labelText: labelText, shape: shape, className: className))
    }

    private func splitInlineClass(source: String, range: TextRange): (TextRange, ?String) {
        let text = source[range.start..range.end]
        if (let Some(pos) <- text.indexOf(":::")) {
            let body = trimAsciiRange(source, TextRange(range.start, range.start + pos))
            let classRange = trimAsciiRange(source, TextRange(range.start + pos + 3, range.end))
            if (!classRange.isEmpty()) {
                return (body, Some(source[classRange.start..classRange.end]))
            }
            return (body, None)
        }
        return (range, None)
    }

    private func parseClassDef(source: String, range: TextRange, classStyles: HashMap<String, FlowNodeStyle>): Bool {
        let statement = source[range.start..range.end]
        if (!statement.startsWith("classDef ")) {
            return false
        }
        let rest = trimAsciiRange(source, TextRange(range.start + "classDef ".size, range.end))
        let split = splitFirstAsciiBlank(source, rest)
        let nameRange = split[0]
        let styleRange = split[1]
        if (nameRange.isEmpty() || styleRange.isEmpty()) {
            return true
        }
        let style = parseStyleProperties(source[styleRange.start..styleRange.end])
        for (name in source[nameRange.start..nameRange.end].split(",", removeEmpty: true)) {
            let clean = name.trimAscii()
            if (!clean.isEmpty()) {
                classStyles[clean] = style
            }
        }
        return true
    }

    private func parseClass(source: String, range: TextRange, nodeClasses: HashMap<String, String>): Bool {
        let statement = source[range.start..range.end]
        if (!statement.startsWith("class ")) {
            return false
        }
        let rest = trimAsciiRange(source, TextRange(range.start + "class ".size, range.end))
        let split = splitFirstAsciiBlank(source, rest)
        let idsRange = split[0]
        let classRange = split[1]
        if (idsRange.isEmpty() || classRange.isEmpty()) {
            return true
        }
        let className = source[classRange.start..classRange.end]
        for (id in source[idsRange.start..idsRange.end].split(",", removeEmpty: true)) {
            let clean = id.trimAscii()
            if (!clean.isEmpty()) {
                nodeClasses[clean] = className
            }
        }
        return true
    }

    private func parseStyle(source: String, range: TextRange, nodeStyles: HashMap<String, FlowNodeStyle>, nodes: ArrayList<FlowNode>): Bool {
        let statement = source[range.start..range.end]
        if (!statement.startsWith("style ")) {
            return false
        }
        let rest = trimAsciiRange(source, TextRange(range.start + "style ".size, range.end))
        let split = splitFirstAsciiBlank(source, rest)
        let idRange = split[0]
        let styleRange = split[1]
        if (idRange.isEmpty() || styleRange.isEmpty()) {
            return true
        }
        let id = source[idRange.start..idRange.end]
        nodeStyles[id] = parseStyleProperties(source[styleRange.start..styleRange.end])
        addOrUpdateNode(nodes, id, idRange, FlowNodeShape.Rectangle, None<String>)
        return true
    }

    private func parseLinkStyle(source: String, range: TextRange): Bool {
        let statement = source[range.start..range.end]
        return statement.startsWith("linkStyle ")
    }

    private func normalizeStyleKey(key: String): String {
        match (key) {
            case "background" | "fill" => return "fill"
            case "border" | "stroke" => return "stroke"
            case _ => return key
        }
    }

    private func borderStrokeValue(value: String): String {
        let parts = value.split(" ", removeEmpty: true)
        if (parts.size > 0) {
            return parts[parts.size - 1]
        }
        return value
    }

    private func styleValueForKey(key: String, value: String): String {
        if (key == "stroke") {
            return borderStrokeValue(value)
        }
        return value
    }

    private func splitFirstAsciiBlank(source: String, range: TextRange): Array<TextRange> {
        var i = range.start
        while (i < range.end) {
            if (isAsciiBlank(source[i])) {
                return [
                    trimAsciiRange(source, TextRange(range.start, i)),
                    trimAsciiRange(source, TextRange(i + 1, range.end))
                ]
            }
            i++
        }
        return [range, TextRange(range.end, range.end)]
    }

    private func parseStyleProperties(style: String): FlowNodeStyle {
        var fill: ?String = None
        var stroke: ?String = None
        var color: ?String = None
        for (part in style.split(",", removeEmpty: true)) {
            let trimmed = part.trimAscii()
            let separator = trimmed.indexOf(":")
            if (separator.isNone()) {
                continue
            }
            let index = separator.getOrThrow()
            let key = normalizeStyleKey(trimmed[0..index].trimAscii())
            let value = trimmed[(index + 1)..trimmed.size].trimAscii()
            if (key == "fill") {
                fill = Some(styleValueForKey(key, value))
            } else if (key == "stroke") {
                stroke = Some(styleValueForKey(key, value))
            } else if (key == "color") {
                color = Some(styleValueForKey(key, value))
            }
        }
        return FlowNodeStyle(fill: fill, stroke: stroke, color: color)
    }

    private func findLineEnd(source: String, start: Int64): Int64 {
        var i = start
        while (i < source.size) {
            if (source[i] == b'\n' || source[i] == b'\r') {
                return i
            }
            i++
        }
        return source.size
    }

    private func extendNodeDataLineEnd(source: String, lineStart: Int64, lineEnd: Int64): Int64 {
        var i = lineStart
        var activeQuote: ?Byte = None
        var nodeDataDepth: Int64 = 0
        var sawNodeDataOnLine = false
        while (i < source.size) {
            let ch = source[i]
            if (let Some(q) <- activeQuote) {
                if (ch == b'\\' && i + 1 < source.size) {
                    i += 2
                    continue
                }
                if (ch == q) {
                    activeQuote = None
                }
            } else if (ch == b'"' || ch == b'\'') {
                activeQuote = Some(ch)
            } else if (ch == b'@' && i + 1 < source.size && source[i + 1] == b'{') {
                nodeDataDepth++
                if (i < lineEnd) {
                    sawNodeDataOnLine = true
                }
                i += 2
                continue
            } else if (ch == b'}' && nodeDataDepth > 0) {
                nodeDataDepth--
                if (nodeDataDepth == 0 && sawNodeDataOnLine && i >= lineEnd) {
                    return findLineEnd(source, i)
                }
            }
            if (i >= lineEnd && nodeDataDepth == 0) {
                return lineEnd
            }
            if (i >= lineEnd && !sawNodeDataOnLine) {
                return lineEnd
            }
            i++
        }
        return lineEnd
    }

    private func nextLineStart(source: String, lineEnd: Int64): Int64 {
        var i = lineEnd
        if (i < source.size && source[i] == b'\r') {
            i++
        }
        if (i < source.size && source[i] == b'\n') {
            i++
        }
        return i
    }

    private func findStatementEnd(source: String, start: Int64, end: Int64): Int64 {
        var i = start
        while (i < end) {
            if (source[i] == b';') {
                return i
            }
            i++
        }
        return end
    }

    private func stripCommentEnd(source: String, start: Int64, end: Int64): Int64 {
        var i = start
        while (i + 1 < end) {
            if (source[i] == b'%' && source[i + 1] == b'%') {
                return i
            }
            i++
        }
        return end
    }

    private func trimAsciiRange(source: String, range: TextRange): TextRange {
        var start = range.start
        var end = range.end
        while (start < end && isAsciiBlank(source[start])) {
            start++
        }
        while (end > start && isAsciiBlank(source[end - 1])) {
            end--
        }
        return TextRange(start, end)
    }

    private func isAsciiBlank(ch: Byte): Bool {
        return ch == b' ' || ch == b'\t' || ch == b'\n' || ch == b'\r'
    }

    private func unquoteRange(source: String, range: TextRange): TextRange {
        var value = range
        if (range.size >= 2 && ((source[range.start] == b'"' && source[range.end - 1] == b'"') || (source[range.start] == b'\'' && source[range.end - 1] == b'\''))) {
            value = TextRange(range.start + 1, range.end - 1)
        }
        if (value.size >= 2 && source[value.start] == b'`' && source[value.end - 1] == b'`') {
            return TextRange(value.start + 1, value.end - 1)
        }
        return value
    }

    private func isQuotedRange(source: String, range: TextRange): Bool {
        return range.size >= 2 && ((source[range.start] == b'"' && source[range.end - 1] == b'"') || (source[range.start] == b'\'' && source[range.end - 1] == b'\''))
    }
}
