package markit.plugins.commonmark

import std.collection.HashMap

public class HtmlAttributeUtils {
    public static func parse(attributes: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        var cursor: Int64 = 0
        while (cursor < attributes.size) {
            cursor = skipSpaces(attributes, cursor)
            if (cursor >= attributes.size) {
                break
            }

            let nameStart = cursor
            while (cursor < attributes.size && isNameByte(attributes[cursor])) {
                cursor += 1
            }
            if (cursor == nameStart) {
                cursor += 1
                continue
            }

            let name = attributes[nameStart..cursor]
            cursor = skipSpaces(attributes, cursor)
            if (cursor >= attributes.size || attributes[cursor] != b'=') {
                result[name] = ""
                continue
            }

            cursor += 1
            cursor = skipSpaces(attributes, cursor)
            if (cursor >= attributes.size) {
                result[name] = ""
                break
            }

            let quoteByte = attributes[cursor]
            if (quoteByte == b'"' || quoteByte == b'\'') {
                cursor += 1
                let valueStart = cursor
                while (cursor < attributes.size && attributes[cursor] != quoteByte) {
                    cursor += 1
                }
                result[name] = attributes[valueStart..cursor]
                if (cursor < attributes.size) {
                    cursor += 1
                }
            } else {
                let valueStart = cursor
                while (cursor < attributes.size && !isSpace(attributes[cursor])) {
                    cursor += 1
                }
                result[name] = attributes[valueStart..cursor]
            }
        }
        return result
    }

    public static func build(attributes: HashMap<String, String>, includeLeadingSpace!: Bool = false): String {
        let sb = StringBuilder()
        for ((key, value) in attributes) {
            if (sb.size > 0) {
                sb.append(" ")
            }
            if (value.isEmpty()) {
                sb.append(key)
            } else {
                sb.append(key)
                sb.append("=\"")
                sb.append(value)
                sb.append("\"")
            }
        }
        let result = sb.toString()
        if (includeLeadingSpace && !result.isEmpty()) {
            return " " + result
        }
        return result
    }

    private static func skipSpaces(text: String, start: Int64): Int64 {
        var cursor = start
        while (cursor < text.size && isSpace(text[cursor])) {
            cursor += 1
        }
        return cursor
    }

    private static func isSpace(byte: Byte): Bool {
        return byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r'
    }

    private static func isNameByte(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') ||
            (byte >= b'A' && byte <= b'Z') ||
            (byte >= b'0' && byte <= b'9') ||
            byte == b'-' ||
            byte == b'_' ||
            byte == b':'
    }
}

public func asciiLower(text: String): String {
    let builder = StringBuilder(if (text.size > 0) { text.size } else { 1 })
    for (rune in text.runes()) {
        builder.append(if (rune.isAsciiUpperCase()) { rune.toAsciiLowerCase() } else { rune })
    }
    return builder.toString()
}
