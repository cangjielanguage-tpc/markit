package markit.utils

import std.collection.{ArrayList, HashMap}

public class HtmlPropertyHelper {
    public static func extractAttribute(html: String, attributeName: String): String {
        if (attributeName.isEmpty()) {
            return ""
        }

        let attributes = extractAllAttributes(html)
        return attributes.get(attributeName) ?? ""
    }

    public static func extractId(html: String): String {
        return extractAttribute(html, "id")
    }

    public static func extractHref(html: String): String {
        return extractAttribute(html, "href")
    }

    public static func extractClass(html: String): String {
        return extractAttribute(html, "class")
    }

    public static func extractSrc(html: String): String {
        return extractAttribute(html, "src")
    }

    public static func extractAllAttributes(html: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        if (let Some(open) <- html.indexOf(b'<')) {
            if (let Some(close) <- html.indexOf(b'>', open + 1)) {
                let tagBody = html[open + 1..close].trimAscii()
                if (tagBody.isEmpty() || tagBody.startsWith("/") || tagBody.startsWith("!")) {
                    return result
                }

                var cursor: Int64 = 0
                while (cursor < tagBody.size && !isAsciiSpace(tagBody[cursor])) {
                    cursor += 1
                }
                if (cursor >= tagBody.size) {
                    return result
                }
                return parseAttributesString(tagBody[cursor..])
            }
        }
        return result
    }

    public static func parseAttributesString(attributes: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        var cursor: Int64 = 0

        while (cursor < attributes.size) {
            cursor = skipSpaces(attributes, cursor)
            if (cursor >= attributes.size) {
                break
            }
            if (attributes[cursor] == b'/') {
                break
            }

            let nameStart = cursor
            while (cursor < attributes.size && !isAsciiSpace(attributes[cursor]) &&
                attributes[cursor] != b'=' && attributes[cursor] != b'/' && attributes[cursor] != b'>') {
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
                if (cursor < attributes.size && attributes[cursor] == quoteByte) {
                    cursor += 1
                }
            } else {
                let valueStart = cursor
                while (cursor < attributes.size && !isAsciiSpace(attributes[cursor]) &&
                    attributes[cursor] != b'/' && attributes[cursor] != b'>') {
                    cursor += 1
                }
                result[name] = attributes[valueStart..cursor]
            }
        }

        return result
    }

    public static func buildAttributesString(
        attributes: HashMap<String, String>,
        includeLeadingSpace!: Bool = false
    ): String {
        if (attributes.isEmpty()) {
            return ""
        }

        let keys = sortedKeys(attributes)
        let out = StringBuilder()
        if (includeLeadingSpace) {
            out.append(" ")
        }
        var first = true
        for (key in keys) {
            if (!first) {
                out.append(" ")
            }
            first = false
            out.append(key)
            out.append("=\"")
            out.append(escapeAttributeValue(attributes[key]))
            out.append("\"")
        }
        return out.toString()
    }

    private static func sortedKeys(attributes: HashMap<String, String>): Array<String> {
        let keys = ArrayList<String>()
        for ((key, _) in attributes) {
            keys.add(key)
        }
        for (i in 0..keys.size) {
            for (j in i + 1..keys.size) {
                if (keys[j] < keys[i]) {
                    let temp = keys[i]
                    keys[i] = keys[j]
                    keys[j] = temp
                }
            }
        }
        return keys.toArray()
    }

    private static func skipSpaces(text: String, start: Int64): Int64 {
        var cursor = start
        while (cursor < text.size && isAsciiSpace(text[cursor])) {
            cursor += 1
        }
        return cursor
    }

    private static func isAsciiSpace(byte: Byte): Bool {
        return byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r'
    }

    private static func escapeAttributeValue(text: String): String {
        return text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&#39;")
    }
}
