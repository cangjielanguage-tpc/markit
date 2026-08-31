package mermaid4cj.parser

import std.collection.ArrayList
import mermaid4cj.core.{MindmapDiagram, MindmapNode, MindmapNodeShape, MindmapParseResult}

public class MindmapParser {
    public init() {}

    public func parse(source: String): MindmapParseResult {
        let nodes = ArrayList<MindmapNode>()
        let stack = ArrayList<Int64>()
        let diagnostics = ArrayList<String>()
        var sawHeader = false
        var seq: Int64 = 0
        var lineNo: Int64 = 0
        var baseLevel: ?Int64 = None
        for (raw in source.lines()) {
            lineNo++
            let noComment = stripComment(raw)
            let trimmed = noComment.trimAscii()
            if (trimmed.isEmpty()) {
                continue
            }
            if (!sawHeader) {
                if (trimmed.toAsciiLower().startsWith("mindmap")) {
                    sawHeader = true
                    continue
                }
                diagnostics.add("Line ${lineNo}: expected mindmap header")
                break
            }
            if (trimmed.startsWith("::icon(")) {
                if (nodes.isEmpty()) {
                    diagnostics.add("Line ${lineNo}: mindmap icon has no preceding node")
                } else {
                    let prev = nodes[nodes.size - 1]
                    nodes[nodes.size - 1] = MindmapNode(prev.id, prev.label, prev.level, prev.parentIndex, shape: prev.shape, icon: readParenValue(trimmed), className: prev.className)
                }
                continue
            }
            if (trimmed.startsWith(":::")) {
                if (nodes.isEmpty()) {
                    diagnostics.add("Line ${lineNo}: mindmap class has no preceding node")
                } else {
                    let prev = nodes[nodes.size - 1]
                    nodes[nodes.size - 1] = MindmapNode(prev.id, prev.label, prev.level, prev.parentIndex, shape: prev.shape, icon: prev.icon, className: trimmed[3..trimmed.size].trimAscii())
                }
                continue
            }
            if (trimmed.toAsciiLower().startsWith("mindmap")) {
                diagnostics.add("Line ${lineNo}: unexpected MINDMAP token in mindmap node")
                continue
            }
            let rawLevel = indentLevel(noComment)
            let level = match (baseLevel) {
                case Some(value) => rawLevel - value
                case None =>
                    baseLevel = Some(rawLevel)
                    0
            }
            if (level < 0) {
                diagnostics.add("Line ${lineNo}: mindmap indentation is above root level")
                continue
            }
            while (!stack.isEmpty() && nodes[stack[stack.size - 1]].level >= level) {
                stack.remove(at: stack.size - 1)
            }
            let parent = if (stack.isEmpty()) { -1 } else { stack[stack.size - 1] }
            if (parent < 0 && !nodes.isEmpty()) {
                diagnostics.add("Line ${lineNo}: there can be only one mindmap root")
                continue
            }
            let parsed = parseNode(trimmed)
            nodes.add(MindmapNode("mindmap-${seq}", parsed.label, level, parent, shape: parsed.shape))
            stack.add(nodes.size - 1)
            seq++
        }
        if (!sawHeader && diagnostics.isEmpty()) {
            diagnostics.add("Missing mindmap header")
        }
        if (nodes.isEmpty() && diagnostics.isEmpty()) {
            diagnostics.add("Mindmap must contain at least one node")
        }
        return MindmapParseResult(MindmapDiagram(source, nodes: nodes), diagnostics: diagnostics.toArray())
    }

    private func parseNode(text: String): ParsedMindmapNode {
        var value = text.trimAscii()
        if (value.startsWith("root")) {
            value = value["root".size..value.size].trimAscii()
        }
        if (value.contains("[\"`") && value.endsWith("`\"]")) {
            if (let Some(start) <- value.indexOf("[\"`")) {
                return ParsedMindmapNode(value[(start + 3)..(value.size - 3)], MindmapNodeShape.Square)
            }
        }
        if (value.startsWith("((") && value.endsWith("))")) {
            return ParsedMindmapNode(value[2..(value.size - 2)].trimAscii(), MindmapNodeShape.Circle)
        }
        if (value.contains("((") && value.endsWith("))")) {
            let start = value.indexOf("((").getOrThrow()
            return ParsedMindmapNode(value[(start + 2)..(value.size - 2)].trimAscii(), MindmapNodeShape.Circle)
        }
        if (value.contains("[") && value.endsWith("]")) {
            let start = value.indexOf("[").getOrThrow()
            return ParsedMindmapNode(unquote(value[(start + 1)..(value.size - 1)].trimAscii()), MindmapNodeShape.Square)
        }
        if (value.contains("{{") && value.endsWith("}}")) {
            let start = value.indexOf("{{").getOrThrow()
            return ParsedMindmapNode(value[(start + 2)..(value.size - 2)].trimAscii(), MindmapNodeShape.Hexagon)
        }
        if (value.contains("))") && value.endsWith("((")) {
            let start = value.indexOf("))").getOrThrow()
            return ParsedMindmapNode(value[(start + 2)..(value.size - 2)].trimAscii(), MindmapNodeShape.Bang)
        }
        if (value.contains(")") && value.endsWith("(")) {
            let start = value.indexOf(")").getOrThrow()
            return ParsedMindmapNode(value[(start + 1)..(value.size - 1)].trimAscii(), MindmapNodeShape.Cloud)
        }
        if (value.contains("(") && value.endsWith(")")) {
            let start = value.indexOf("(").getOrThrow()
            return ParsedMindmapNode(value[(start + 1)..(value.size - 1)].trimAscii(), MindmapNodeShape.Rounded)
        }
        return ParsedMindmapNode(unquote(value), MindmapNodeShape.Default)
    }

    private func indentLevel(line: String): Int64 {
        var spaces: Int64 = 0
        var tabs: Int64 = 0
        for (i in 0..line.size) {
            if (line[i] == b' ') {
                spaces++
            } else if (line[i] == b'\t') {
                tabs++
            } else {
                break
            }
        }
        return tabs * 4 + spaces
    }

    private func readParenValue(text: String): String {
        if (text.endsWith(")") && text.contains("(")) {
            let start = text.indexOf("(").getOrThrow()
            return text[(start + 1)..(text.size - 1)].trimAscii()
        }
        return ""
    }

    private func stripComment(line: String): String {
        if (let Some(pos) <- line.indexOf("%%")) {
            return line[0..pos]
        }
        return line
    }

    private func unquote(text: String): String {
        let trimmed = text.trimAscii()
        if (trimmed.size >= 2 && ((trimmed[0] == b'"' && trimmed[trimmed.size - 1] == b'"') || (trimmed[0] == b'\'' && trimmed[trimmed.size - 1] == b'\''))) {
            return trimmed[1..(trimmed.size - 1)]
        }
        return trimmed
    }
}

class ParsedMindmapNode {
    let label: String
    let shape: MindmapNodeShape

    init(label: String, shape: MindmapNodeShape) {
        this.label = label
        this.shape = shape
    }
}
