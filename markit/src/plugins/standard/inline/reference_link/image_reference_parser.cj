package markit.plugins.standard.inline.reference_link

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.plugins.standard.inline.image.ImageNode

public class ImageReferenceParser <: InlineParser {
    public prop name: String {
        get() {
            return "ImageReferenceParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ReferenceLinkPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 600
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'!']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 4 || input[startByte] != b'!' || input[startByte + 1] != b'[') {
            return None
        }

        let altEnd = findClosingBracket(input, startByte + 2, endByte, startByte)
        if (altEnd < 0) {
            return None
        }

        let alt = input[startByte + 2..altEnd]
        let altRuneCount = InlineUtils.countRunes(alt)
        var refLabel = ""
        var refRuneCount: Int64 = 0
        var consumedBytes: Int64 = 0
        var consumedRunes: Int64 = 0

        if (altEnd + 1 < endByte && input[altEnd + 1] == b'[') {
            let refEnd = findClosingBracket(input, altEnd + 2, endByte, startByte)
            if (refEnd < 0) {
                return None
            }
            refLabel = input[altEnd + 2..refEnd]
            if (refLabel.isEmpty()) {
                refLabel = alt
            }
            refRuneCount = InlineUtils.countRunes(refLabel)
            consumedBytes = refEnd + 1 - startByte
            consumedRunes = altRuneCount + refRuneCount + 5
        } else {
            refLabel = alt
            consumedBytes = altEnd + 1 - startByte
            consumedRunes = altRuneCount + 3
            if (refLabel.isEmpty()) {
                return None
            }
        }

        let registry = getRegistry(session)
        if (registry.isNone()) {
            return None
        }
        let reg = registry.getOrThrow()

        let def = reg.getDefinition(refLabel)
        if (def.isSome()) {
            let definition = def.getOrThrow()
            let node = session.attachNode(ImageNode(
                session.allocateNodeId(),
                InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, consumedRunes),
                InlineUtils.processEscapes(alt),
                definition.url,
                InlineUtils.processEscapes(definition.title)
            ))
            return Some(InlineParseResult(node, consumedBytes, consumedRunes))
        }

        let node = session.attachNode(ImageNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, consumedRunes),
            InlineUtils.processEscapes(alt),
            "",
            ""
        ))
        node.setString("refLabel", refLabel)
        reg.addUnresolvedImage(node)
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
