package markit.utils

import std.collection.ArrayList

public class TextRenderUtils {
    public static func repeat(text: String, count: Int64): String {
        if (count <= 0) {
            return ""
        }

        let sb = StringBuilder()
        for (_ in 0..count) {
            sb.append(text)
        }
        return sb.toString()
    }

    public static func indentSpaces(count: Int64): String {
        return repeat(" ", count)
    }

    public static func trimRight(value: String): String {
        var end = value.size
        while (end > 0) {
            let ch = value[end - 1]
            if (ch == b' ' || ch == b'\t' || ch == b'\n' || ch == b'\r') {
                end -= 1
                continue
            }
            break
        }
        return value[0..end]
    }

    public static func prefixLines(text: String, prefix: String): String {
        let lines = text.split("\n")
        if (lines.isEmpty()) {
            return ""
        }

        let prefixed = ArrayList<String>()
        for (line in lines) {
            prefixed.add(prefix + line)
        }
        return String.join(prefixed.toArray(), delimiter: "\n")
    }

    public static func indentContinuationLines(text: String, continuationIndent: String): String {
        let lines = text.split("\n")
        if (lines.size <= 1) {
            return text
        }

        let parts = ArrayList<String>()
        parts.add(lines[0])
        for (i in 1..lines.size) {
            let line = lines[i]
            parts.add(if (line.isEmpty()) { "" } else { continuationIndent + line })
        }
        return String.join(parts.toArray(), delimiter: "\n")
    }
}
