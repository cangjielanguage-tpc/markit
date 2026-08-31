package markit.plugins.gfm.inline.strikethrough

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class StrikethroughParser <: InlineParser {
    public prop name: String {
        get() {
            return "StrikethroughParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "StrikethroughPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 850
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'~']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 5 || input[startByte] != b'~' || input[startByte + 1] != b'~') {
            return None
        }

        var contentEnd: Int64 = -1
        var cursor: Int64 = startByte + 2
        while (cursor < endByte - 1) {
            if (!InlineUtils.isEscaped(input, cursor, startByte) && input[cursor] == b'~' && input[cursor + 1] == b'~') {
                contentEnd = cursor
                break
            }
            cursor += InlineUtils.nextRuneByteSize(input, cursor)
        }

        if (contentEnd <= startByte + 2) {
            return None
        }

        let consumedBytes = contentEnd + 2 - startByte
        let rawRunes = InlineUtils.countRunes(input, startByte, startByte + consumedBytes)
        let contentStart = startByte + 2
        let contentRuneCount = InlineUtils.countRunes(input, contentStart, contentEnd)
        let node = session.attachNode(StrikethroughNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
            InlineUtils.processEscapes(input, contentStart, contentEnd)
        ))
        session.appendInlineChildrenRange(
            node,
            input,
            contentStart,
            contentEnd,
            InlineUtils.spanWithRunes(baseSpan, 2, contentEnd - startByte, 2, 2 + contentRuneCount)
        )
        return Some(InlineParseResult(node, consumedBytes, rawRunes))
    }
}
