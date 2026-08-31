package mermaid4cj.parser

import std.collection.{ArrayList, HashMap}
import mermaid4cj.core.{
    ErAttribute,
    ErCardinality,
    ErDiagram,
    ErDirection,
    ErEntity,
    ErParseResult,
    ErRelationship
}

public class ErDiagramParser {
    public init() {}

    public func parse(source: String): ErParseResult {
        let entities = ArrayList<ErEntity>()
        let relationships = ArrayList<ErRelationship>()
        let entityIndex = HashMap<String, Int64>()
        let diagnostics = ArrayList<String>()
        var sawHeader = false
        var title: ?String = None
        var direction = ErDirection.TB
        var inEntityBlock = false
        var blockEntity = ""
        var lineNo: Int64 = 0

        for (raw in source.lines()) {
            lineNo++
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            let lower = line.toAsciiLower()
            if (!sawHeader) {
                if (lower.startsWith("erdiagram")) {
                    sawHeader = true
                    continue
                }
                if (line == "---" || lower.startsWith("title:") || lower.startsWith("title ")) {
                    if (lower.startsWith("title:")) {
                        title = Some(line["title:".size..line.size].trimAscii())
                    } else if (lower.startsWith("title ")) {
                        title = Some(line["title ".size..line.size].trimAscii())
                    }
                    continue
                }
                diagnostics.add("Line ${lineNo}: expected erDiagram header")
                break
            }

            if (inEntityBlock) {
                if (line == "}") {
                    inEntityBlock = false
                    blockEntity = ""
                } else if (let Some(attr) <- parseAttribute(line)) {
                    addAttribute(entities, entityIndex, blockEntity, attr)
                } else {
                    diagnostics.add("Line ${lineNo}: malformed erDiagram attribute")
                }
                continue
            }

            if (lower.startsWith("title:")) {
                title = Some(line["title:".size..line.size].trimAscii())
            } else if (lower.startsWith("title ")) {
                title = Some(line["title ".size..line.size].trimAscii())
            } else if (lower.startsWith("direction ")) {
                direction = parseDirection(line["direction ".size..line.size].trimAscii(), diagnostics, lineNo)
            } else if (line.endsWith("{")) {
                let entitySpec = line[0..(line.size - 1)].trimAscii()
                let parsed = parseEntitySpec(entitySpec)
                if (parsed.id.isEmpty()) {
                    diagnostics.add("Line ${lineNo}: erDiagram entity id is empty")
                } else {
                    ensureEntity(entities, entityIndex, parsed.id, parsed.label)
                    inEntityBlock = true
                    blockEntity = parsed.id
                }
            } else if (let Some(relation) <- parseRelationship(line, entities, entityIndex)) {
                relationships.add(relation)
            } else {
                let parsed = parseEntitySpec(line)
                if (!parsed.id.isEmpty()) {
                    ensureEntity(entities, entityIndex, parsed.id, parsed.label)
                } else {
                    diagnostics.add("Line ${lineNo}: unsupported erDiagram statement")
                }
            }
        }

        if (!sawHeader && diagnostics.isEmpty()) {
            diagnostics.add("Missing erDiagram header")
        }
        if (inEntityBlock) {
            diagnostics.add("Unclosed erDiagram entity block '${blockEntity}'")
        }

        return ErParseResult(
            ErDiagram(source, title: title, direction: direction, entities: entities, relationships: relationships),
            diagnostics: diagnostics.toArray()
        )
    }

    private func parseRelationship(line: String, entities: ArrayList<ErEntity>, entityIndex: HashMap<String, Int64>): ?ErRelationship {
        if (let Some(relation) <- parseSymbolRelationship(line, entities, entityIndex)) {
            return Some(relation)
        }
        return parseAliasRelationship(line, entities, entityIndex)
    }

    private func parseSymbolRelationship(line: String, entities: ArrayList<ErEntity>, entityIndex: HashMap<String, Int64>): ?ErRelationship {
        let connectors = ["--", ".."]
        for (connector in connectors) {
            if (let Some(pos) <- line.indexOf(connector)) {
                let left = line[0..pos].trimAscii()
                let rightAndLabel = line[(pos + connector.size)..line.size].trimAscii()
                if (left.size < 3 || rightAndLabel.size < 3) {
                    return None
                }
                let leftCardToken = left[max(0, left.size - 2)..left.size]
                let sourceText = left[0..max(0, left.size - 2)].trimAscii()
                let rightCardToken = rightAndLabel[0..2]
                let rest = rightAndLabel[2..rightAndLabel.size].trimAscii()
                let parts = splitRelationLabel(rest)
                let sourceSpec = parseEntitySpec(sourceText)
                let targetSpec = parseEntitySpec(parts.left)
                if (sourceSpec.id.isEmpty() || targetSpec.id.isEmpty()) {
                    return None
                }
                ensureEntity(entities, entityIndex, sourceSpec.id, sourceSpec.label)
                ensureEntity(entities, entityIndex, targetSpec.id, targetSpec.label)
                return Some(ErRelationship(
                    sourceSpec.id,
                    targetSpec.id,
                    parts.right,
                    cardForLeft(leftCardToken),
                    cardForRight(rightCardToken),
                    connector == "--",
                    "${leftCardToken}${connector}${rightCardToken}"
                ))
            }
        }
        return None
    }

    private func parseAliasRelationship(line: String, entities: ArrayList<ErEntity>, entityIndex: HashMap<String, Int64>): ?ErRelationship {
        let parts = splitRelationLabel(line)
        if (parts.right.isEmpty()) {
            return None
        }
        let tokens = tokenizeEntityAware(parts.left)
        if (tokens.size < 5) {
            return None
        }
        let sourceSpec = parseEntitySpec(tokens[0])
        let identifyingIndex = findIdentifyingAlias(tokens)
        if (identifyingIndex < 2 || identifyingIndex + 2 >= tokens.size) {
            return None
        }
        let leftCardEnd = if (identifyingIndex > 0 && tokens[identifyingIndex - 1].toAsciiLower() == "optionally") { identifyingIndex - 1 } else { identifyingIndex }
        let leftCardText = joinTokens(tokens, 1, leftCardEnd)
        let rightCardText = joinTokens(tokens, identifyingIndex + 1, tokens.size - 1)
        let targetSpec = parseEntitySpec(tokens[tokens.size - 1])
        if (sourceSpec.id.isEmpty() || targetSpec.id.isEmpty()) {
            return None
        }
        ensureEntity(entities, entityIndex, sourceSpec.id, sourceSpec.label)
        ensureEntity(entities, entityIndex, targetSpec.id, targetSpec.label)
        let identifying = !(identifyingIndex > 0 && tokens[identifyingIndex - 1].toAsciiLower() == "optionally")
        return Some(ErRelationship(
            sourceSpec.id,
            targetSpec.id,
            parts.right,
            cardForAlias(leftCardText),
            cardForAlias(rightCardText),
            identifying,
            parts.left
        ))
    }

    private func parseAttribute(line: String): ?ErAttribute {
        let commentSplit = splitAttributeComment(line)
        let body = commentSplit.left.trimAscii()
        let parts = body.split(" ", removeEmpty: true)
        if (parts.size < 2) {
            return None
        }
        let attrType = parts[0]
        let name = parts[1]
        var key = ""
        if (parts.size > 2) {
            key = body[(attrType.size + 1 + name.size)..body.size].trimAscii()
        }
        return Some(ErAttribute(attrType, name, key: key, comment: commentSplit.right))
    }

    private func splitAttributeComment(line: String): ErSplit {
        if (let Some(start) <- line.indexOf("\"")) {
            if (line.endsWith("\"") && start + 1 < line.size) {
                return ErSplit(line[0..start].trimAscii(), line[(start + 1)..(line.size - 1)])
            }
        }
        return ErSplit(line, "")
    }

    private func splitRelationLabel(text: String): ErSplit {
        if (let Some(colon) <- text.indexOf(":")) {
            return ErSplit(text[0..colon].trimAscii(), unquote(text[(colon + 1)..text.size].trimAscii()))
        }
        return ErSplit(text.trimAscii(), "")
    }

    private func parseEntitySpec(text: String): ErEntitySpec {
        let trimmed = text.trimAscii()
        if (trimmed.isEmpty()) {
            return ErEntitySpec("", "")
        }
        if (let Some(bracket) <- trimmed.indexOf("[")) {
            if (trimmed.endsWith("]")) {
                let id = unquote(trimmed[0..bracket].trimAscii())
                let label = unquote(trimmed[(bracket + 1)..(trimmed.size - 1)].trimAscii())
                return ErEntitySpec(id, label)
            }
        }
        return ErEntitySpec(unquote(trimmed), "")
    }

    private func ensureEntity(entities: ArrayList<ErEntity>, entityIndex: HashMap<String, Int64>, id: String, label: String): Unit {
        if (id.isEmpty()) {
            return
        }
        if (let Some(index) <- entityIndex.get(id)) {
            let current = entities[index]
            if (!label.isEmpty() && current.label == current.id) {
                entities[index] = ErEntity(id, label: label, attributes: current.attributes)
            }
            return
        }
        entityIndex[id] = entities.size
        entities.add(ErEntity(id, label: label))
    }

    private func addAttribute(entities: ArrayList<ErEntity>, entityIndex: HashMap<String, Int64>, id: String, attr: ErAttribute): Unit {
        if (let Some(index) <- entityIndex.get(id)) {
            entities[index].attributes.add(attr)
        }
    }

    private func parseDirection(text: String, diagnostics: ArrayList<String>, lineNo: Int64): ErDirection {
        match (text.toAsciiUpper()) {
            case "TB" => return ErDirection.TB
            case "BT" => return ErDirection.BT
            case "LR" => return ErDirection.LR
            case "RL" => return ErDirection.RL
            case _ =>
                diagnostics.add("Line ${lineNo}: unsupported erDiagram direction")
                return ErDirection.TB
        }
    }

    private func cardForLeft(token: String): ErCardinality {
        match (token) {
            case "|o" => return ErCardinality.ZeroOrOne
            case "||" => return ErCardinality.ExactlyOne
            case "}o" => return ErCardinality.ZeroOrMore
            case "}|" => return ErCardinality.OneOrMore
            case _ => return ErCardinality.ExactlyOne
        }
    }

    private func cardForRight(token: String): ErCardinality {
        match (token) {
            case "o|" => return ErCardinality.ZeroOrOne
            case "||" => return ErCardinality.ExactlyOne
            case "o{" => return ErCardinality.ZeroOrMore
            case "|{" => return ErCardinality.OneOrMore
            case _ => return ErCardinality.ExactlyOne
        }
    }

    private func cardForAlias(text: String): ErCardinality {
        match (text.toAsciiLower()) {
            case "one or zero" | "zero or one" => return ErCardinality.ZeroOrOne
            case "zero or more" | "zero or many" | "many(0)" | "0+" => return ErCardinality.ZeroOrMore
            case "one or more" | "one or many" | "many(1)" | "1+" => return ErCardinality.OneOrMore
            case _ => return ErCardinality.ExactlyOne
        }
    }

    private func findIdentifyingAlias(tokens: ArrayList<String>): Int64 {
        for (i in 0..tokens.size) {
            if (tokens[i].toAsciiLower() == "to") {
                return i
            }
            if (i + 1 < tokens.size && tokens[i].toAsciiLower() == "optionally" && tokens[i + 1].toAsciiLower() == "to") {
                return i + 1
            }
        }
        return -1
    }

    private func tokenizeEntityAware(text: String): ArrayList<String> {
        let out = ArrayList<String>()
        var i: Int64 = 0
        while (i < text.size) {
            while (i < text.size && (text[i] == b' ' || text[i] == b'\t')) {
                i++
            }
            if (i >= text.size) {
                break
            }
            if (text[i] == b'"') {
                var j = i + 1
                while (j < text.size && text[j] != b'"') {
                    j++
                }
                if (j < text.size) {
                    out.add(text[i..(j + 1)])
                    i = j + 1
                } else {
                    out.add(text[i..text.size])
                    i = text.size
                }
            } else {
                var j = i
                while (j < text.size && text[j] != b' ' && text[j] != b'\t') {
                    j++
                }
                out.add(text[i..j])
                i = j
            }
        }
        return out
    }

    private func joinTokens(tokens: ArrayList<String>, start: Int64, end: Int64): String {
        let out = StringBuilder(64)
        for (i in start..end) {
            if (i > start) {
                out.append(" ")
            }
            out.append(tokens[i])
        }
        return out.toString()
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

class ErSplit {
    let left: String
    let right: String

    init(left: String, right: String) {
        this.left = left
        this.right = right
    }
}

class ErEntitySpec {
    let id: String
    let label: String

    init(id: String, label: String) {
        this.id = id
        this.label = label
    }
}
