package markit.plugins.gfm.inline.inline_math

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class InlineMathParser <: InlineParser {
    public prop name: String {
        get() {
            return "InlineMathParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "InlineMathPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 650
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'$']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 2 || input[startByte] != b'$') {
            return None
        }

        var end: Int64 = -1
        var cursor: Int64 = startByte + 1
        while (cursor < endByte) {
            if (input[cursor] == b'\n' || input[cursor] == b'\r') {
                return None
            }
            if (!InlineUtils.isEscaped(input, cursor, startByte) && input[cursor] == b'$') {
                end = cursor
                break
            }
            cursor += InlineUtils.nextRuneByteSize(input, cursor)
        }

        if (end < 0) {
            return None
        }

        let raw = input[startByte..end + 1]
        let content = input[startByte + 1..end]
        let rawRunes = InlineUtils.countRunes(input, startByte, end + 1)
        let node = session.attachNode(InlineMathNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, raw.size, 0, rawRunes),
            content,
            raw
        ))
        return Some(InlineParseResult(node, raw.size, rawRunes))
    }
}
