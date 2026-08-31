package mermaid4cj.parser

import std.collection.{ArrayList, HashMap}
import mermaid4cj.core.{StateDiagram, StateDirection, StateNode, StateNodeKind, StateParseResult, StateTransition}

public class StateDiagramParser {
    public init() {}

    public func parse(source: String): StateParseResult {
        let nodes = ArrayList<StateNode>()
        let transitions = ArrayList<StateTransition>()
        let index = HashMap<String, Int64>()
        let compositeStack = ArrayList<String>()
        let diagnostics = ArrayList<String>()
        var sawHeader = false
        var direction = StateDirection.TB
        var lineNo: Int64 = 0
        for (raw in source.lines()) {
            lineNo++
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            let lower = line.toAsciiLower()
            if (!sawHeader) {
                if (lower.startsWith("statediagram")) {
                    sawHeader = true
                    continue
                }
                diagnostics.add("Line ${lineNo}: expected stateDiagram header")
                break
            }
            if (line == "}") {
                if (compositeStack.isEmpty()) {
                    diagnostics.add("Line ${lineNo}: unexpected stateDiagram closing brace")
                } else {
                    compositeStack.remove(at: compositeStack.size - 1)
                }
            } else if (lower.startsWith("direction ")) {
                direction = parseDirection(line["direction ".size..line.size].trimAscii(), diagnostics, lineNo)
            } else if (lower.startsWith("state ") && line.endsWith("{")) {
                let spec = line["state ".size..(line.size - 1)].trimAscii()
                let parsed = parseStateSpec(spec)
                ensureNode(nodes, index, parsed.id, parsed.label, StateNodeKind.Composite, currentParent(compositeStack))
                compositeStack.add(parsed.id)
            } else if (lower.startsWith("state ")) {
                let parsed = parseStateSpec(line["state ".size..line.size].trimAscii())
                ensureNode(nodes, index, parsed.id, parsed.label, StateNodeKind.State, currentParent(compositeStack))
            } else if (line.contains("-->")) {
                if (let Some(tr) <- parseTransition(line, nodes, index, currentParent(compositeStack))) {
                    transitions.add(tr)
                } else {
                    diagnostics.add("Line ${lineNo}: malformed state transition")
                }
            } else if (lower.startsWith("note ")) {
                diagnostics.add("Line ${lineNo}: stateDiagram notes are not yet supported")
            } else if (lower.startsWith("choice ") || lower.startsWith("fork ") || lower.startsWith("join ")) {
                diagnostics.add("Line ${lineNo}: stateDiagram choice/fork/join are not yet supported")
            } else {
                let parsed = parseStateSpec(line)
                ensureNode(nodes, index, parsed.id, parsed.label, StateNodeKind.State, currentParent(compositeStack))
            }
        }
        if (!sawHeader && diagnostics.isEmpty()) {
            diagnostics.add("Missing stateDiagram header")
        }
        if (!compositeStack.isEmpty()) {
            diagnostics.add("Unclosed stateDiagram composite state '${compositeStack[compositeStack.size - 1]}'")
        }
        return StateParseResult(StateDiagram(source, direction: direction, nodes: nodes, transitions: transitions), diagnostics: diagnostics.toArray())
    }

    private func parseTransition(line: String, nodes: ArrayList<StateNode>, index: HashMap<String, Int64>, parent: ?String): ?StateTransition {
        let pos = line.indexOf("-->").getOrThrow()
        let source = normalizeEndpoint(line[0..pos].trimAscii())
        let right = line[(pos + 3)..line.size].trimAscii()
        var targetText = right
        var label = ""
        if (let Some(colon) <- right.indexOf(":")) {
            targetText = right[0..colon].trimAscii()
            label = right[(colon + 1)..right.size].trimAscii()
        }
        let target = normalizeEndpoint(targetText)
        if (source.isEmpty() || target.isEmpty()) {
            return None
        }
        ensureNode(nodes, index, source, source, if (source == "[*]") { StateNodeKind.Start } else { StateNodeKind.State }, parent)
        ensureNode(nodes, index, target, target, if (target == "[*]") { StateNodeKind.End } else { StateNodeKind.State }, parent)
        return Some(StateTransition(source, target, label: label))
    }

    private func parseStateSpec(text: String): ParsedState {
        let trimmed = text.trimAscii()
        if (let Some(aliasPos) <- trimmed.toAsciiLower().indexOf(" as ")) {
            return ParsedState(trimmed[(aliasPos + 4)..trimmed.size].trimAscii(), unquote(trimmed[0..aliasPos].trimAscii()))
        }
        if (let Some(colon) <- trimmed.indexOf(":")) {
            return ParsedState(trimmed[0..colon].trimAscii(), trimmed[(colon + 1)..trimmed.size].trimAscii())
        }
        return ParsedState(normalizeEndpoint(trimmed), unquote(trimmed))
    }

    private func ensureNode(nodes: ArrayList<StateNode>, index: HashMap<String, Int64>, id: String, label: String, kind: StateNodeKind, parent: ?String): Unit {
        if (id.isEmpty()) {
            return
        }
        if (index.get(id).isSome()) {
            return
        }
        index[id] = nodes.size
        nodes.add(StateNode(id, label: if (id == "[*]") { "" } else { label }, kind: kind, parentId: parent))
    }

    private func parseDirection(text: String, diagnostics: ArrayList<String>, lineNo: Int64): StateDirection {
        match (text.toAsciiUpper()) {
            case "TB" => return StateDirection.TB
            case "BT" => return StateDirection.BT
            case "LR" => return StateDirection.LR
            case "RL" => return StateDirection.RL
            case _ =>
                diagnostics.add("Line ${lineNo}: unsupported stateDiagram direction")
                return StateDirection.TB
        }
    }

    private func currentParent(stack: ArrayList<String>): ?String {
        if (stack.isEmpty()) {
            return None
        }
        return Some(stack[stack.size - 1])
    }

    private func normalizeEndpoint(text: String): String {
        return unquote(text.trimAscii())
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

class ParsedState {
    let id: String
    let label: String

    init(id: String, label: String) {
        this.id = id
        this.label = label
    }
}
