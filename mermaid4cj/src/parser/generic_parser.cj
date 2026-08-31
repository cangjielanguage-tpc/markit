package mermaid4cj.parser

import std.collection.{ArrayList, HashMap}
import mermaid4cj.core.{DiagramKind, GenericDiagram, GenericEdge, GenericNode, GenericParseResult, GenericRow, GenericTask}

public class GenericDiagramParser {
    public init() {}

    public func parse(source: String, kind: DiagramKind): GenericParseResult {
        match (kind) {
            case DiagramKind.Mindmap => return parseMindmap(source)
            case DiagramKind.Class => return parseClassDiagram(source)
            case DiagramKind.Er => return parseErDiagram(source)
            case DiagramKind.Pie => return parsePie(source)
            case DiagramKind.Gantt => return parseGantt(source)
            case _ =>
                return GenericParseResult(GenericDiagram(source, kind), diagnostics: ["Unsupported generic Mermaid diagram kind"])
        }
    }

    private func parseMindmap(source: String): GenericParseResult {
        let nodes = ArrayList<GenericNode>()
        let edges = ArrayList<GenericEdge>()
        let stack = ArrayList<Int64>()
        var sawHeader = false
        var idSeq: Int64 = 0
        for (raw in source.lines()) {
            let lineNoComment = stripComment(raw)
            let trimmed = lineNoComment.trimAscii()
            if (trimmed.isEmpty()) {
                continue
            }
            if (!sawHeader) {
                if (trimmed.toAsciiLower().startsWith("mindmap")) {
                    sawHeader = true
                    continue
                }
                return GenericParseResult(GenericDiagram(source, DiagramKind.Mindmap), diagnostics: ["Missing mindmap header"])
            }
            let level = indentLevel(lineNoComment)
            let label = cleanMindmapLabel(trimmed)
            let id = "mindmap-${idSeq}"
            idSeq++
            nodes.add(GenericNode(id, label, level: level))
            while (!stack.isEmpty() && nodes[stack[stack.size - 1]].level >= level) {
                stack.remove(at: stack.size - 1)
            }
            if (!stack.isEmpty()) {
                edges.add(GenericEdge(nodes[stack[stack.size - 1]].id, id))
            }
            stack.add(nodes.size - 1)
        }
        return GenericParseResult(GenericDiagram(source, DiagramKind.Mindmap, nodes: nodes, edges: edges))
    }

    private func parseClassDiagram(source: String): GenericParseResult {
        let nodes = ArrayList<GenericNode>()
        let edges = ArrayList<GenericEdge>()
        let seen = HashMap<String, Bool>()
        var sawHeader = false
        for (raw in source.lines()) {
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            if (!sawHeader) {
                if (line.toAsciiLower().startsWith("classdiagram")) {
                    sawHeader = true
                    continue
                }
                return GenericParseResult(GenericDiagram(source, DiagramKind.Class), diagnostics: ["Missing classDiagram header"])
            }
            if (line.startsWith("class ")) {
                let id = line["class ".size..line.size].split(" ", removeEmpty: true)[0].trimAscii()
                addNode(nodes, seen, id, id, 0)
            } else {
                parseRelationLine(line, classRelationTokens(), nodes, edges, seen)
            }
        }
        return GenericParseResult(GenericDiagram(source, DiagramKind.Class, nodes: nodes, edges: edges))
    }

    private func parseErDiagram(source: String): GenericParseResult {
        let nodes = ArrayList<GenericNode>()
        let edges = ArrayList<GenericEdge>()
        let seen = HashMap<String, Bool>()
        var sawHeader = false
        for (raw in source.lines()) {
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            if (!sawHeader) {
                if (line.toAsciiLower().startsWith("erdiagram")) {
                    sawHeader = true
                    continue
                }
                return GenericParseResult(GenericDiagram(source, DiagramKind.Er), diagnostics: ["Missing erDiagram header"])
            }
            parseRelationLine(line, erRelationTokens(), nodes, edges, seen)
        }
        return GenericParseResult(GenericDiagram(source, DiagramKind.Er, nodes: nodes, edges: edges))
    }

    private func parsePie(source: String): GenericParseResult {
        let rows = ArrayList<GenericRow>()
        var sawHeader = false
        var title: ?String = None
        for (raw in source.lines()) {
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            if (!sawHeader) {
                let lower = line.toAsciiLower()
                if (lower.startsWith("pie")) {
                    sawHeader = true
                    if (lower.startsWith("pie title ")) {
                        title = Some(line["pie title ".size..line.size].trimAscii())
                    }
                    continue
                }
                return GenericParseResult(GenericDiagram(source, DiagramKind.Pie), diagnostics: ["Missing pie header"])
            }
            if (line.toAsciiLower().startsWith("title ")) {
                title = Some(line["title ".size..line.size].trimAscii())
                continue
            }
            if (let Some(pos) <- line.indexOf(":")) {
                let label = unquote(line[0..pos].trimAscii())
                let value = parsePositiveFloat(line[(pos + 1)..line.size].trimAscii())
                if (!label.isEmpty() && value > 0.0) {
                    rows.add(GenericRow(label, value))
                }
            }
        }
        return GenericParseResult(GenericDiagram(source, DiagramKind.Pie, title: title, rows: rows))
    }

    private func parseGantt(source: String): GenericParseResult {
        let tasks = ArrayList<GenericTask>()
        var sawHeader = false
        var title: ?String = None
        var section = ""
        var cursor: Int64 = 0
        let taskEnds = HashMap<String, Int64>()
        var taskSeq: Int64 = 0
        for (raw in source.lines()) {
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            if (!sawHeader) {
                if (line.toAsciiLower().startsWith("gantt")) {
                    sawHeader = true
                    continue
                }
                return GenericParseResult(GenericDiagram(source, DiagramKind.Gantt), diagnostics: ["Missing gantt header"])
            }
            let lower = line.toAsciiLower()
            if (lower.startsWith("title ")) {
                title = Some(line["title ".size..line.size].trimAscii())
                continue
            }
            if (lower.startsWith("section ")) {
                section = line["section ".size..line.size].trimAscii()
                continue
            }
            if (lower.startsWith("dateformat ") || lower.startsWith("axisformat ") || lower.startsWith("tickinterval ") || lower.startsWith("weekday ") || lower.startsWith("excludes ") || lower.startsWith("todaymarker ")) {
                continue
            }
            if (let Some(colon) <- line.indexOf(":")) {
                let label = line[0..colon].trimAscii()
                let fields = splitCsv(line[(colon + 1)..line.size])
                if (label.isEmpty() || fields.size == 0) {
                    continue
                }
                let task = buildGanttTask(label, section, fields, cursor, taskSeq, taskEnds)
                tasks.add(task)
                if (!task.id.isEmpty()) {
                    taskEnds[task.id] = task.end
                }
                cursor = max(cursor, task.end)
                taskSeq++
            }
        }
        return GenericParseResult(GenericDiagram(source, DiagramKind.Gantt, title: title, tasks: tasks))
    }

    private func parseRelationLine(line: String, tokens: Array<String>, nodes: ArrayList<GenericNode>, edges: ArrayList<GenericEdge>, seen: HashMap<String, Bool>): Unit {
        for (token in tokens) {
            if (let Some(pos) <- line.indexOf(token)) {
                let left = cleanEntity(line[0..pos])
                let rest = line[(pos + token.size)..line.size]
                let labelSplit = rest.indexOf(":")
                let rightPart = if (let Some(colon) <- labelSplit) { rest[0..colon] } else { rest }
                let label = if (let Some(colon) <- labelSplit) { rest[(colon + 1)..rest.size].trimAscii() } else { "" }
                let right = cleanEntity(rightPart)
                if (!left.isEmpty() && !right.isEmpty()) {
                    addNode(nodes, seen, left, left, 0)
                    addNode(nodes, seen, right, right, 0)
                    edges.add(GenericEdge(left, right, label: label, relation: token))
                }
                return
            }
        }
    }

    private func addNode(nodes: ArrayList<GenericNode>, seen: HashMap<String, Bool>, id: String, label: String, level: Int64): Unit {
        if (id.isEmpty() || (seen.get(id) ?? false)) {
            return
        }
        seen[id] = true
        nodes.add(GenericNode(id, label, level: level))
    }

    private func classRelationTokens(): Array<String> {
        return ["<|--", "--|>", "<|..", "..|>", "*--", "o--", "-->", "..>", "--", ".."]
    }

    private func erRelationTokens(): Array<String> {
        return ["||--||", "||--o{", "||--|{", "}o--||", "}|--||", "}o--o{", "}o--|{", "}|--o{", "}|--|{", "|o--o{", "|o--|{", "o|--||", "o|--o{", "o|--|{"]
    }

    private func cleanEntity(text: String): String {
        let parts = text.trimAscii().split(" ", removeEmpty: true)
        if (parts.size == 0) {
            return ""
        }
        return unquote(parts[0])
    }

    private func cleanMindmapLabel(text: String): String {
        var out = text
        if (out.startsWith("root")) {
            out = out["root".size..out.size].trimAscii()
        }
        if (out.startsWith("((") && out.endsWith("))")) {
            return out[2..(out.size - 2)].trimAscii()
        }
        if ((out.startsWith("(") && out.endsWith(")")) || (out.startsWith("[") && out.endsWith("]")) || (out.startsWith("{") && out.endsWith("}"))) {
            return out[1..(out.size - 1)].trimAscii()
        }
        return unquote(out)
    }

    private func indentLevel(line: String): Int64 {
        var level: Int64 = 0
        var spaces: Int64 = 0
        var i: Int64 = 0
        while (i < line.size) {
            if (line[i] == b'\t') {
                level++
            } else if (line[i] == b' ') {
                spaces++
            } else {
                break
            }
            i++
        }
        return level + spaces / 2
    }

    private func parsePositiveFloat(value: String): Float64 {
        var whole = 0.0
        var frac = 0.0
        var scale = 1.0
        var afterDot = false
        for (i in 0..value.size) {
            let ch = value[i]
            if (ch == b'.') {
                afterDot = true
            } else if (ch >= b'0' && ch <= b'9') {
                let digit = Float64(ch - b'0')
                if (afterDot) {
                    scale *= 10.0
                    frac += digit / scale
                } else {
                    whole = whole * 10.0 + digit
                }
            }
        }
        return whole + frac
    }

    private func buildGanttTask(label: String, section: String, fields: Array<String>, cursor: Int64, taskSeq: Int64, taskEnds: HashMap<String, Int64>): GenericTask {
        var status = ""
        var id = ""
        var start = cursor
        var duration: Int64 = 1
        var sawStart = false
        let statuses = ["done", "active", "crit", "milestone"]
        for (raw in fields) {
            let field = raw.trimAscii()
            if (field.isEmpty()) {
                continue
            }
            let lower = field.toAsciiLower()
            if (containsWord(statuses, lower)) {
                status = if (status.isEmpty()) { lower } else { "${status} ${lower}" }
            } else if (lower.startsWith("after ")) {
                let dep = field["after ".size..field.size].trimAscii().split(" ", removeEmpty: true)[0]
                start = taskEnds.get(dep) ?? cursor
                sawStart = true
            } else if (looksLikeDate(field)) {
                let day = parseDateSerial(field)
                if (!sawStart) {
                    start = day
                    sawStart = true
                } else {
                    duration = max(1, day - start)
                }
            } else if (looksLikeDuration(lower)) {
                duration = parseDurationDays(lower)
            } else if (id.isEmpty()) {
                id = field
            }
        }
        if (id.isEmpty()) {
            id = "task-${taskSeq}"
        }
        return GenericTask(label, section: section, status: status, id: id, start: start, end: start + max(1, duration))
    }

    private func splitCsv(text: String): Array<String> {
        let out = ArrayList<String>()
        for (part in text.split(",", removeEmpty: true)) {
            out.add(part.trimAscii())
        }
        return out.toArray()
    }

    private func containsWord(words: Array<String>, value: String): Bool {
        for (word in words) {
            if (word == value) {
                return true
            }
        }
        return false
    }

    private func looksLikeDate(text: String): Bool {
        return text.size >= 10 && text[4] == b'-' && text[7] == b'-'
    }

    private func parseDateSerial(text: String): Int64 {
        if (!looksLikeDate(text)) {
            return 0
        }
        let year = parseAsciiInt(text[0..4])
        let month = parseAsciiInt(text[5..7])
        let day = parseAsciiInt(text[8..10])
        return year * 372 + month * 31 + day
    }

    private func looksLikeDuration(text: String): Bool {
        return text.endsWith("d") || text.endsWith("w") || text.endsWith("h")
    }

    private func parseDurationDays(text: String): Int64 {
        var unit = 1
        if (text.endsWith("w")) {
            unit = 7
        }
        let value = parseAsciiInt(text[0..max(0, text.size - 1)])
        return max(1, value * unit)
    }

    private func parseAsciiInt(text: String): Int64 {
        var value: Int64 = 0
        for (i in 0..text.size) {
            let ch = text[i]
            if (ch >= b'0' && ch <= b'9') {
                value = value * 10 + Int64(ch - b'0')
            }
        }
        return value
    }

    private func stripComment(line: String): String {
        if (let Some(pos) <- line.indexOf("%%")) {
            return line[0..pos]
        }
        return line
    }

    private func unquote(text: String): String {
        if (text.size >= 2 && ((text[0] == b'"' && text[text.size - 1] == b'"') || (text[0] == b'\'' && text[text.size - 1] == b'\''))) {
            return text[1..(text.size - 1)]
        }
        return text
    }
}
