package markit.core.render

import std.io.OutputStream

public interface HtmlWriter {
    func text(value: String): Unit
    func raw(value: String): Unit
}

public class StringHtmlWriter <: HtmlWriter {
    private var buffer: StringBuilder = StringBuilder()

    public func text(value: String): Unit {
        buffer.append(HtmlEscaper.escape(value))
    }

    public func raw(value: String): Unit {
        buffer.append(value)
    }

    public func toString(): String {
        return buffer.toString()
    }
}

public class OutputStreamHtmlWriter <: HtmlWriter {
    private let output: OutputStream

    public init(output: OutputStream) {
        this.output = output
    }

    public func text(value: String): Unit {
        raw(HtmlEscaper.escape(value))
    }

    public func raw(value: String): Unit {
        if (!value.isEmpty()) {
            output.write(value.toArray())
        }
    }

    public func flush(): Unit {
        output.flush()
    }
}

public class HtmlEscaper {
    public static func escape(text: String): String {
        var hasEscapable = false
        var scanIndex: Int64 = 0
        while (scanIndex < text.size) {
            let byte = text[scanIndex]
            if (byte == b'&' || byte == b'<' || byte == b'>' || byte == b'"' || byte == b'\'') {
                hasEscapable = true
                break
            }
            scanIndex += 1
        }
        if (!hasEscapable) {
            return text
        }

        let sb = StringBuilder()
        var segmentStart: Int64 = 0
        var index: Int64 = 0
        while (index < text.size) {
            let byte = text[index]
            var replacement = ""
            if (byte == b'&') {
                replacement = "&amp;"
            } else if (byte == b'<') {
                replacement = "&lt;"
            } else if (byte == b'>') {
                replacement = "&gt;"
            } else if (byte == b'"') {
                replacement = "&quot;"
            } else if (byte == b'\'') {
                replacement = "&#39;"
            }

            if (!replacement.isEmpty()) {
                if (segmentStart < index) {
                    sb.append(text[segmentStart..index])
                }
                sb.append(replacement)
                index += 1
                segmentStart = index
                continue
            }
            index += 1
        }
        if (segmentStart < text.size) {
            sb.append(text[segmentStart..])
        }
        return sb.toString()
    }
}
