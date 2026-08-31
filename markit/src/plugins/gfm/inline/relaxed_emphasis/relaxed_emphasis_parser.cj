package markit.plugins.gfm.inline.relaxed_emphasis

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.plugins.standard.inline.bold.BoldNode
import markit.plugins.standard.inline.italic.ItalicNode

public class RelaxedEmphasisParser <: InlineParser {
    public prop name: String {
        get() {
            return "RelaxedEmphasisParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "RelaxedEmphasisPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 880
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'_']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 3 || input[startByte] != b'_') {
            return None
        }

        let isBold = endByte - startByte > 1 && input[startByte + 1] == b'_'
        let delimiterLength: Int64 = if (isBold) { 2 } else { 1 }
        if (endByte - startByte <= delimiterLength || InlineUtils.isWhitespace(input[startByte + delimiterLength])) {
            return None
        }

        var contentEnd: Int64 = -1
        var cursor = startByte + delimiterLength
        while (cursor < endByte) {
            if (!InlineUtils.isEscaped(input, cursor, startByte) && input[cursor] == b'_') {
                if (isBold) {
                    if (cursor + 1 < endByte && input[cursor + 1] == b'_' && isValidClosing(input, cursor, 2, startByte, endByte)) {
                        contentEnd = cursor
                        break
                    }
                    cursor += 1
                    continue
                }
                if (isValidClosing(input, cursor, 1, startByte, endByte)) {
                    contentEnd = cursor
                    break
                }
            }
            let width = InlineUtils.nextRuneByteSize(input, cursor)
            cursor += if (width == 0) { 1 } else { width }
        }

        if (contentEnd <= startByte + delimiterLength) {
            return None
        }

        let consumedBytes = contentEnd + delimiterLength - startByte
        let rawRunes = InlineUtils.countRunes(input, startByte, startByte + consumedBytes)
        let content = input[startByte + delimiterLength..contentEnd]
        let contentRuneCount = InlineUtils.countRunes(content)
        let node: Node = if (isBold) {
            session.attachNode(BoldNode(
                session.allocateNodeId(),
                InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
                InlineUtils.processEscapes(content),
                "__"
            ))
        } else {
            session.attachNode(ItalicNode(
                session.allocateNodeId(),
                InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
                InlineUtils.processEscapes(content),
                "_"
            ))
        }
        session.appendInlineChildren(
            node,
            content,
            InlineUtils.spanWithRunes(
                baseSpan,
                delimiterLength,
                contentEnd - startByte,
                delimiterLength,
                delimiterLength + contentRuneCount
            )
        )

        return Some(InlineParseResult(node, consumedBytes, rawRunes))
    }

    private func isValidClosing(input: String, position: Int64, delimiterLength: Int64, startByte: Int64, endByte: Int64): Bool {
        if (position <= startByte || InlineUtils.isWhitespace(input[position - 1])) {
            return false
        }
        let after = position + delimiterLength
        if (after >= endByte) {
            return true
        }
        return !InlineUtils.isAsciiAlphaNumeric(input[after])
    }
}
