package markit.plugins.standard.inline.italic

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class ItalicParser <: InlineParser {
    public prop name: String {
        get() {
            return "ItalicParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ItalicPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 1000
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'*', b'_']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 3) {
            return None
        }
        let delimiterByte = input[startByte]
        if (!(delimiterByte == b'*' || delimiterByte == b'_')) {
            return None
        }
        if (endByte - startByte > 1 && input[startByte + 1] == delimiterByte) {
            return None
        }
        if (InlineUtils.isWhitespace(input[startByte + 1])) {
            return None
        }

        var contentEnd: Int64 = -1
        var cursor: Int64 = startByte + 1
        while (cursor < endByte) {
            if (!InlineUtils.isEscaped(input, cursor, startByte) &&
                input[cursor] == delimiterByte &&
                isValidClosing(input, cursor, delimiterByte, startByte, endByte)) {
                contentEnd = cursor
                break
            }
            cursor += 1
        }

        if (contentEnd <= startByte + 1) {
            return None
        }

        let consumedBytes = contentEnd + 1 - startByte
        let rawRunes = InlineUtils.countRunes(input, startByte, startByte + consumedBytes)
        let contentStart = startByte + 1
        let contentRuneCount = InlineUtils.countRunes(input, contentStart, contentEnd)
        let node = session.attachNode(ItalicNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
            InlineUtils.processEscapes(input, contentStart, contentEnd),
            input[startByte..startByte + 1]
        ))
        session.appendInlineChildrenRange(
            node,
            input,
            contentStart,
            contentEnd,
            InlineUtils.spanWithRunes(baseSpan, 1, contentEnd - startByte, 1, 1 + contentRuneCount)
        )

        return Some(InlineParseResult(node, consumedBytes, rawRunes))
    }

    private func isValidClosing(input: String, pos: Int64, delimiterByte: Byte, startByte: Int64, endByte: Int64): Bool {
        if (pos == startByte || InlineUtils.isWhitespace(input[pos - 1])) {
            return false
        }
        if (delimiterByte == b'_' && pos + 1 < endByte && InlineUtils.isAsciiAlphaNumeric(input[pos + 1])) {
            return false
        }
        return true
    }
}
