package markit.plugins.standard.inline.reference_link

import markit.core.block.LeafBlockParser
import markit.core.inline.InlineUtils
import markit.core.nodes.Node
import markit.core.session.ParseSession

public class LinkDefinitionParser <: LeafBlockParser {
    public prop name: String {
        get() {
            return "LinkDefinitionParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ReferenceLinkPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 200
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'[']
        }
    }

    public prop acceptsAnyNonBlank: Bool {
        get() {
            return false
        }
    }

    public func tryParse(session: ParseSession, line: String): ?Node {
        let labelEnd = findClosingBracket(line, 0)
        if (labelEnd < 0) {
            return None
        }
        if (labelEnd + 1 >= line.size || line[labelEnd + 1] != b':') {
            return None
        }

        var cursor = labelEnd + 2
        let label = line[1..labelEnd]

        if (label.isEmpty()) {
            return None
        }

        cursor = skipSpaces(line, cursor)
        let (url, urlEnd) = parseUrl(line, cursor)
        cursor = urlEnd
        cursor = skipSpaces(line, cursor)

        var title = ""
        if (cursor < line.size) {
            let titleResult = parseTitle(line, cursor)
            if (titleResult.found) {
                title = titleResult.title
                cursor = titleResult.endPos
                cursor = skipSpaces(line, cursor)
            }
        }

        if (cursor < line.size) {
            return None
        }

        let registry = getRegistry(session)
        if (registry.isNone()) {
            return None
        }
        registry.getOrThrow().addDefinition(label, url, title)

        return Some(session.attachNode(Node(
            "LinkDefinition",
            id: session.allocateNodeId(),
            sourceSpan: session.currentLineSpan()
        )))
    }

    private func getRegistry(session: ParseSession): ?ReferenceLinkRegistry {
        if (let Some(state) <- session.symbolTables.get("ReferenceLinkPlugin.registry")) {
            if (let registry: ReferenceLinkRegistry <- state) {
                return Some(registry)
            }
        }
        return None
    }

    private func findClosingBracket(line: String, start: Int64): Int64 {
        if (start >= line.size || line[start] != b'[') {
            return -1
        }
        var cursor = start + 1
        while (cursor < line.size) {
            if (InlineUtils.isEscaped(line, cursor)) {
                cursor += 1
                continue
            }
            if (line[cursor] == b']') {
                return cursor
            }
            cursor += 1
        }
        return -1
    }

    private func skipSpaces(line: String, start: Int64): Int64 {
        var cursor = start
        while (cursor < line.size && (line[cursor] == b' ' || line[cursor] == b'\t')) {
            cursor += 1
        }
        return cursor
    }

    private func parseUrl(line: String, start: Int64): (String, Int64) {
        if (start >= line.size) {
            return ("", start)
        }
        if (line[start] == b'<') {
            let end = line.indexOf(b'>', start + 1)
            if (end.isSome()) {
                let endPos = end.getOrThrow()
                return (line[start + 1..endPos], endPos + 1)
            }
        }

        var cursor = start
        var parenDepth: Int64 = 0
        while (cursor < line.size) {
            if (InlineUtils.isEscaped(line, cursor)) {
                cursor += 2
                continue
            }
            let byte = line[cursor]
            if (byte == b' ' || byte == b'\t') {
                break
            }
            if (byte == b'(') {
                parenDepth += 1
            } else if (byte == b')') {
                if (parenDepth == 0) {
                    break
                }
                parenDepth -= 1
            }
            cursor += 1
        }
        return (line[start..cursor], cursor)
    }

    private func parseTitle(line: String, start: Int64): ParsedTitle {
        if (start >= line.size) {
            return ParsedTitle(false, "", start)
        }
        let delimiter = line[start]
        if (delimiter != b'"' && delimiter != b'\'' && delimiter != b'(') {
            return ParsedTitle(false, "", start)
        }
        let closeByte = if (delimiter == b'(') { b')' } else { delimiter }
        var cursor = start + 1
        while (cursor < line.size) {
            if (InlineUtils.isEscaped(line, cursor)) {
                cursor += 2
                continue
            }
            if (line[cursor] == closeByte) {
                return ParsedTitle(true, line[start + 1..cursor], cursor + 1)
            }
            cursor += 1
        }
        return ParsedTitle(false, "", start)
    }
}

private class ParsedTitle {
    public let found: Bool
    public let title: String
    public let endPos: Int64

    public init(found: Bool, title: String, endPos: Int64) {
        this.found = found
        this.title = title
        this.endPos = endPos
    }
}
