package markit.utils

public class EscapeHandler {
    private static let escapable = "\\`*_{}[]()#+-.!|~:$"

    public static func isEscapable(ch: Rune): Bool {
        return escapable.contains(ch.toString())
    }

    public static func processEscapes(text: String): String {
        let out = StringBuilder(text.size)
        var index: Int64 = 0

        while (index < text.size) {
            if (text[index] != b'\\') {
                let width = utf8Width(text[index])
                out.append(text[index..index + width])
                index += width
                continue
            }

            if (index + 1 >= text.size) {
                out.append("\\")
                index += 1
                continue
            }

            let next = text[index + 1]
            if (isEscapableByte(next)) {
                try {
                    out.append(String.fromUtf8([next]))
                } catch (e: Exception) {
                    throw IllegalArgumentException("Invalid escaped byte in EscapeHandler: ${next}")
                }
                index += 2
            } else {
                let width = utf8Width(next)
                out.append("\\")
                out.append(text[index + 1..index + 1 + width])
                index += 1 + width
            }
        }

        return out.toString()
    }

    public static func unescapeText(text: String): String {
        return processEscapes(text)
    }

    public static func escapeSpecialChars(text: String): String {
        let out = StringBuilder(text.size * 2)
        for (r in text.runes()) {
            if (isEscapable(r)) {
                out.append("\\")
            }
            out.append(r.toString())
        }
        return out.toString()
    }

    public static func getEscapeLength(text: String, offset: Int64): Int64 {
        if (offset < 0 || offset >= text.size || text[offset] != b'\\') {
            return 0
        }
        if (offset + 1 >= text.size) {
            return 1
        }
        if (isEscapableByte(text[offset + 1])) {
            return 2
        }
        return 1
    }

    private static func isEscapableByte(byte: Byte): Bool {
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
            byte == b'|' ||
            byte == b'~' ||
            byte == b':' ||
            byte == b'$'
    }

    private static func utf8Width(first: Byte): Int64 {
        if (first < 0x80) {
            return 1
        }
        if ((first & 0xE0) == 0xC0) {
            return 2
        }
        if ((first & 0xF0) == 0xE0) {
            return 3
        }
        if ((first & 0xF8) == 0xF0) {
            return 4
        }
        return 1
    }
}
