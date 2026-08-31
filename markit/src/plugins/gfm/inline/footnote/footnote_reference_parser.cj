package markit.plugins.gfm.inline.footnote

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class FootnoteReferenceParser <: InlineParser {
    public prop name: String {
        get() {
            return "FootnoteReferenceParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 250
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'[']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 4 || input[startByte] != b'[' || input[startByte + 1] != b'^') {
            return None
        }

        var cursor: Int64 = startByte + 2
        while (cursor < endByte && input[cursor] != b']') {
            if (input[cursor] == b'\n' || input[cursor] == b'\r') {
                return None
            }
            cursor += InlineUtils.nextRuneByteSize(input, cursor)
        }
        if (cursor >= endByte || input[cursor] != b']' || cursor == startByte + 2) {
            return None
        }

        let raw = input[startByte..cursor + 1]
        let id = input[startByte + 2..cursor]
        let rawRunes = InlineUtils.countRunes(input, startByte, cursor + 1)
        let registry = session.symbolTables.get(FootnotePlugin.stateKey)
        let number = registry.addReference(id, baseSpan.startRune)
        let node = session.attachNode(FootnoteReferenceNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, raw.size, 0, rawRunes),
            id,
            number,
            raw
        ))
        return Some(InlineParseResult(node, raw.size, rawRunes))
    }
}
