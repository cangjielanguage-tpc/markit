package markit.plugins.standard.inline.inline_code

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class InlineCodeParser <: InlineParser {
    public prop name: String {
        get() {
            return "InlineCodeParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "InlineCodePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 100
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'`']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (startByte >= endByte || input[startByte] != b'`') {
            return None
        }

        var fenceLength: Int64 = 0
        while (startByte + fenceLength < endByte && input[startByte + fenceLength] == b'`') {
            fenceLength += 1
        }

        var contentEnd: Int64 = -1
        var cursor = startByte + fenceLength
        while (cursor <= endByte - fenceLength) {
            var run: Int64 = 0
            while (cursor + run < endByte && input[cursor + run] == b'`') {
                run += 1
            }
            if (run == fenceLength) {
                contentEnd = cursor
                break
            }
            cursor += if (run > 0) { run } else { 1 }
        }

        if (contentEnd < 0) {
            return None
        }

        let consumedBytes = contentEnd + fenceLength - startByte
        let rawRunes = InlineUtils.countRunes(input, startByte, startByte + consumedBytes)
        let content = normalizeCodeSpan(InlineUtils.processEscapes(input, startByte + fenceLength, contentEnd))
        let node = session.attachNode(InlineCodeNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
            content,
            fenceLength
        ))

        return Some(InlineParseResult(node, consumedBytes, rawRunes))
    }

    private func normalizeCodeSpan(content: String): String {
        if (!content.contains("\n") && !content.contains("\r")) {
            return content
        }

        let sb = StringBuilder()
        var index: Int64 = 0
        var pendingSpace = false
        while (index < content.size) {
            if (content[index] == b'\r') {
                pendingSpace = true
                index += 1
                if (index < content.size && content[index] == b'\n') {
                    index += 1
                }
                continue
            }
            if (content[index] == b'\n') {
                pendingSpace = true
                index += 1
                continue
            }
            if (pendingSpace) {
                sb.append(" ")
                pendingSpace = false
            }
            let width = InlineUtils.nextRuneByteSize(content, index)
            if (width == 0) {
                break
            }
            sb.append(content[index..index + width])
            index += width
        }
        return sb.toString()
    }
}
