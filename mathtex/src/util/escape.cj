package mathtex.util

public class HtmlEscaper {
    public static func escapeText(text: String): String {
        if (text.isEmpty()) {
            return ""
        }
        let out = StringBuilder(text.size)
        var segmentStart: Int64 = 0
        for (i in 0..text.size) {
            let replacement = textReplacement(text[i])
            if (replacement.isEmpty()) {
                continue
            }
            out.append(text[segmentStart..i])
            out.append(replacement)
            segmentStart = i + 1
        }
        out.append(text[segmentStart..text.size])
        return out.toString()
    }

    public static func escapeAttribute(text: String): String {
        if (text.isEmpty()) {
            return ""
        }
        let out = StringBuilder(text.size)
        var segmentStart: Int64 = 0
        for (i in 0..text.size) {
            let replacement = attributeReplacement(text[i])
            if (replacement.isEmpty()) {
                continue
            }
            out.append(text[segmentStart..i])
            out.append(replacement)
            segmentStart = i + 1
        }
        out.append(text[segmentStart..text.size])
        return out.toString()
    }

    private static func textReplacement(ch: Byte): String {
        if (ch == b'&') {
            return "&amp;"
        }
        if (ch == b'<') {
            return "&lt;"
        }
        if (ch == b'>') {
            return "&gt;"
        }
        return ""
    }

    private static func attributeReplacement(ch: Byte): String {
        if (ch == b'&') {
            return "&amp;"
        }
        if (ch == b'<') {
            return "&lt;"
        }
        if (ch == b'>') {
            return "&gt;"
        }
        if (ch == b'"') {
            return "&quot;"
        }
        if (ch == b'\'') {
            return "&#39;"
        }
        return ""
    }
}
