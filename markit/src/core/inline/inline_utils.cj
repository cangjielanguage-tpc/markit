package markit.core.inline

import markit.core.source.SourceSpan

public class InlineUtils {
    public static func countRunes(text: String): Int64 {
        var count: Int64 = 0
        var index: Int64 = 0
        while (index < text.size) {
            let byte = text[index]
            if (byte < 0x80) {
                index += 1
            } else if ((byte & 0xE0) == 0xC0 && index + 1 < text.size) {
                index += 2
            } else if ((byte & 0xF0) == 0xE0 && index + 2 < text.size) {
                index += 3
            } else if ((byte & 0xF8) == 0xF0 && index + 3 < text.size) {
                index += 4
            } else {
                break
            }
            count += 1
        }
        return count
    }

    public static func countRunes(text: String, startByte: Int64, endByte: Int64): Int64 {
        var count: Int64 = 0
        var index = startByte
        while (index < endByte) {
            let width = nextRuneByteSize(text, index)
            if (width == 0) {
                break
            }
            index += width
            count += 1
        }
        return count
    }

    public static func nextRuneByteSize(text: String, startByte: Int64): Int64 {
        if (startByte < 0 || startByte >= text.size) {
            return 0
        }
        let byte = text[startByte]
        if (byte < 0x80) {
            return 1
        }
        if ((byte & 0xE0) == 0xC0 && startByte + 1 < text.size) {
            return 2
        }
        if ((byte & 0xF0) == 0xE0 && startByte + 2 < text.size) {
            return 3
        }
        if ((byte & 0xF8) == 0xF0 && startByte + 3 < text.size) {
            return 4
        }
        return 0
    }

    public static func spanWithRunes(
        base: SourceSpan,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): SourceSpan {
        return SourceSpan(
            base.startByte + startByte,
            base.startByte + endByte,
            base.startRune + startRune,
            base.startRune + endRune
        )
    }

    public static func isEscaped(input: String, byteIndex: Int64): Bool {
        return isEscaped(input, byteIndex, 0)
    }

    public static func isEscaped(input: String, byteIndex: Int64, boundaryByte: Int64): Bool {
        if (byteIndex == 0) {
            return false
        }

        var slashCount: Int64 = 0
        var cursor = byteIndex - 1
        while (cursor >= boundaryByte && input[cursor] == b'\\') {
            slashCount += 1
            if (cursor == boundaryByte) {
                break
            }
            cursor -= 1
        }
        return slashCount % 2 == 1
    }

    public static func processEscapes(text: String): String {
        if (!text.contains("\\")) {
            return text
        }
        let sb = StringBuilder()
        var index: Int64 = 0
        while (index < text.size) {
            if (text[index] == b'\\' && index + 1 < text.size && isEscapable(text[index + 1])) {
                sb.append(String.fromUtf8([text[index + 1]]))
                index += 2
                continue
            }

            let width = nextRuneByteSize(text, index)
            if (width == 0) {
                break
            }
            sb.append(text[index..index + width])
            index += width
        }
        return sb.toString()
    }

    public static func processEscapes(text: String, startByte: Int64, endByte: Int64): String {
        var hasEscape = false
        var scan = startByte
        while (scan < endByte) {
            if (text[scan] == b'\\') {
                hasEscape = true
                break
            }
            scan += 1
        }
        if (!hasEscape) {
            return text[startByte..endByte]
        }

        let sb = StringBuilder()
        var index: Int64 = startByte
        while (index < endByte) {
            if (text[index] == b'\\' && index + 1 < endByte && isEscapable(text[index + 1])) {
                sb.append(String.fromUtf8([text[index + 1]]))
                index += 2
                continue
            }

            let width = nextRuneByteSize(text, index)
            if (width == 0) {
                break
            }
            sb.append(text[index..index + width])
            index += width
        }
        return sb.toString()
    }

    public static func isWhitespace(byte: Byte): Bool {
        return byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r'
    }

    public static func isAsciiAlphaNumeric(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') ||
            (byte >= b'A' && byte <= b'Z') ||
            (byte >= b'0' && byte <= b'9')
    }

    public static func repeat(text: String, count: Int64): String {
        let sb = StringBuilder()
        for (_ in 0..count) {
            sb.append(text)
        }
        return sb.toString()
    }

    private static func isEscapable(byte: Byte): Bool {
        return byte == b'\\' ||
            byte == b'`' ||
            byte == b'*' ||
            byte == b'_' ||
            byte == b'{' ||
            byte == b'}' ||
            byte == b'[' ||
            byte == b']' ||
            byte == b'(' ||
            byte == b')' ||
            byte == b'#' ||
            byte == b'+' ||
            byte == b'-' ||
            byte == b'.' ||
            byte == b'!' ||
            byte == b'<' ||
            byte == b'>' ||
            byte == b'|'
    }

}
