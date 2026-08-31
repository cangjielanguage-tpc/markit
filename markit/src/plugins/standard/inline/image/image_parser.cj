package markit.plugins.standard.inline.image

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class ImageParser <: InlineParser {
    public prop name: String {
        get() {
            return "ImageParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ImagePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 500
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'!']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 6 || input[startByte] != b'!' || input[startByte + 1] != b'[') {
            return None
        }

        let altEnd = findClosingBracket(input, startByte + 2, endByte, startByte)
        if (altEnd < 0 || altEnd + 1 >= endByte || input[altEnd + 1] != b'(') {
            return None
        }

        let destination = parseDestination(input, altEnd + 2, endByte, startByte)
        if (destination.isNone()) {
            return None
        }
        let parsed = destination.getOrThrow()
        let consumedBytes = parsed.closeParen + 1 - startByte
        let rawRunes = InlineUtils.countRunes(input, startByte, startByte + consumedBytes)
        let alt = InlineUtils.processEscapes(input, startByte + 2, altEnd)
        let node = session.attachNode(ImageNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
            alt,
            parsed.url,
            InlineUtils.processEscapes(parsed.title)
        ))

        return Some(InlineParseResult(node, consumedBytes, rawRunes))
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

    private func parseDestination(input: String, start: Int64, endByte: Int64, boundaryByte: Int64): ?ParsedImageDestination {
        var cursor = start
        var inQuotes = false
        var quoteByte: Byte = b'"'
        var titleStart: Int64 = -1
        var titleEnd: Int64 = -1

        while (cursor < endByte) {
            if (InlineUtils.isEscaped(input, cursor, boundaryByte)) {
                cursor += 1
                continue
            }
            let byte = input[cursor]
            if (!inQuotes && (byte == b'"' || byte == b'\'')) {
                inQuotes = true
                quoteByte = byte
                titleStart = cursor + 1
                cursor += 1
                continue
            }
            if (inQuotes && byte == quoteByte) {
                inQuotes = false
                titleEnd = cursor
                cursor += 1
                continue
            }
            if (!inQuotes && byte == b')') {
                let body = input[start..cursor].trimAscii()
                var url = body
                var title = ""
                if (titleStart >= 0 && titleEnd >= titleStart) {
                    url = input[start..titleStart - 1].trimAscii()
                    title = input[titleStart..titleEnd]
                }
                return Some(ParsedImageDestination(url, title, cursor))
            }
            cursor += 1
        }
        return None
    }
}

private class ParsedImageDestination {
    public let url: String
    public let title: String
    public let closeParen: Int64

    public init(url: String, title: String, closeParen: Int64) {
        this.url = url
        this.title = title
        this.closeParen = closeParen
    }
}
