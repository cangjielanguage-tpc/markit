package markit.plugins.standard.inline.bold

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class BoldParser <: InlineParser {
    public prop name: String {
        get() {
            return "BoldParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "BoldPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 900
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'*', b'_']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 4) {
            return None
        }
        let delimiterByte = input[startByte]
        if (!((delimiterByte == b'*' && input[startByte + 1] == b'*') || (delimiterByte == b'_' && input[startByte + 1] == b'_'))) {
            return None
        }
        if (endByte - startByte > 2 && InlineUtils.isWhitespace(input[startByte + 2])) {
            return None
        }

        var contentEnd: Int64 = -1
        var cursor: Int64 = startByte + 2
        while (cursor < endByte - 1) {
            if (!InlineUtils.isEscaped(input, cursor, startByte) &&
                input[cursor] == delimiterByte &&
                input[cursor + 1] == delimiterByte &&
                isValidClosing(input, cursor, delimiterByte, startByte, endByte)) {
                contentEnd = cursor
                break
            }
            cursor += 1
        }

        if (contentEnd <= startByte + 2) {
            return None
        }

        let consumedBytes = contentEnd + 2 - startByte
        let rawRunes = InlineUtils.countRunes(input, startByte, startByte + consumedBytes)
        let contentStart = startByte + 2
        let contentRuneCount = InlineUtils.countRunes(input, contentStart, contentEnd)
        let node = session.attachNode(BoldNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
            InlineUtils.processEscapes(input, contentStart, contentEnd),
            input[startByte..startByte + 2]
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

    private func isValidClosing(input: String, pos: Int64, delimiterByte: Byte, startByte: Int64, endByte: Int64): Bool {
        if (pos == startByte || InlineUtils.isWhitespace(input[pos - 1])) {
            return false
        }
        if (delimiterByte == b'_' && pos + 2 < endByte && InlineUtils.isAsciiAlphaNumeric(input[pos + 2])) {
            return false
        }
        return true
    }
}
