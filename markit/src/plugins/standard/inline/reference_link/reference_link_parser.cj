package markit.plugins.standard.inline.reference_link

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.plugins.standard.inline.link.LinkNode

public class ReferenceLinkParser <: InlineParser {
    public prop name: String {
        get() {
            return "ReferenceLinkParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ReferenceLinkPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 400
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'[']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 3 || input[startByte] != b'[') {
            return None
        }

        let textEnd = findClosingBracket(input, startByte + 1, endByte, startByte)
        if (textEnd < 0) {
            return None
        }

        let text = input[startByte + 1..textEnd]
        let textRuneCount = InlineUtils.countRunes(text)
        var refLabel = ""
        var refRuneCount: Int64 = 0
        var consumedBytes: Int64 = 0
        var consumedRunes: Int64 = 0

        if (textEnd + 1 < endByte && input[textEnd + 1] == b'[') {
            let refEnd = findClosingBracket(input, textEnd + 2, endByte, startByte)
            if (refEnd < 0) {
                return None
            }
            refLabel = input[textEnd + 2..refEnd]
            if (refLabel.isEmpty()) {
                refLabel = text
            }
            refRuneCount = InlineUtils.countRunes(refLabel)
            consumedBytes = refEnd + 1 - startByte
            consumedRunes = textRuneCount + refRuneCount + 4
        } else {
            let registry = getRegistry(session)
            if (registry.isNone() || !registry.getOrThrow().hasDefinition(text)) {
                return None
            }
            refLabel = text
            consumedBytes = textEnd + 1 - startByte
            consumedRunes = textRuneCount + 2
        }

        let registry = getRegistry(session)
        if (registry.isNone()) {
            return None
        }
        let reg = registry.getOrThrow()

        let def = reg.getDefinition(refLabel)
        if (def.isSome()) {
            let definition = def.getOrThrow()
            let node = session.attachNode(LinkNode(
                session.allocateNodeId(),
                InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, consumedRunes),
                InlineUtils.processEscapes(text),
                definition.url,
                InlineUtils.processEscapes(definition.title)
            ))
            session.appendInlineChildren(
                node,
                text,
                InlineUtils.spanWithRunes(baseSpan, 1, textEnd - startByte, 1, 1 + textRuneCount)
            )
            return Some(InlineParseResult(node, consumedBytes, consumedRunes))
        }

        let node = session.attachNode(LinkNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, consumedRunes),
            InlineUtils.processEscapes(text),
            "",
            ""
        ))
        node.setString("refLabel", refLabel)
        session.appendInlineChildren(
            node,
            text,
            InlineUtils.spanWithRunes(baseSpan, 1, textEnd - startByte, 1, 1 + textRuneCount)
        )
        reg.addUnresolvedRef(node)
        return Some(InlineParseResult(node, consumedBytes, consumedRunes))
    }

    private func getRegistry(session: ParseSession): ?ReferenceLinkRegistry {
        if (let Some(state) <- session.symbolTables.get("ReferenceLinkPlugin.registry")) {
            if (let registry: ReferenceLinkRegistry <- state) {
                return Some(registry)
            }
        }
        return None
    }

    private func findClosingBracket(input: String, start: Int64, endByte: Int64, boundaryByte: Int64): Int64 {
        var depth: Int64 = 0
        var cursor = start
        while (cursor < endByte) {
            if (InlineUtils.isEscaped(input, cursor, boundaryByte)) {
                cursor += 1
                continue
            }
            if (input[cursor] == b'[') {
                depth += 1
            } else if (input[cursor] == b']') {
                if (depth == 0) {
                    return cursor
                }
                depth -= 1
            }
            cursor += 1
        }
        return -1
    }
}
