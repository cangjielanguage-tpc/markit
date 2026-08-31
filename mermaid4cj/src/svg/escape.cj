package mermaid4cj.svg

public class SvgEscaper {
    public static func appendText(out: StringBuilder, text: String): Unit {
        appendTextRange(out, text, 0, text.size)
    }

    public static func appendTextRange(out: StringBuilder, source: String, start: Int64, end: Int64): Unit {
        var segmentStart = start
        for (i in start..end) {
            let replacement = textReplacement(source[i])
            if (replacement.isEmpty()) {
                continue
            }
            out.append(source[segmentStart..i])
            out.append(replacement)
            segmentStart = i + 1
        }
        out.append(source[segmentStart..end])
    }

    public static func appendAttribute(out: StringBuilder, text: String): Unit {
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
    }

    public static func text(text: String): String {
        let out = StringBuilder(text.size)
        appendText(out, text)
        return out.toString()
    }

    public static func attribute(text: String): String {
        let out = StringBuilder(text.size)
        appendAttribute(out, text)
        return out.toString()
    }

    private static func textReplacement(ch: Byte): String {
        if (ch == b'&') { return "&amp;" }
        if (ch == b'<') { return "&lt;" }
        if (ch == b'>') { return "&gt;" }
        return ""
    }

    private static func attributeReplacement(ch: Byte): String {
        if (ch == b'&') { return "&amp;" }
        if (ch == b'<') { return "&lt;" }
        if (ch == b'>') { return "&gt;" }
        if (ch == b'"') { return "&quot;" }
        if (ch == b'\'') { return "&#39;" }
        return ""
    }
}
