package mermaid4cj.core

public interface MermaidTextMeasurer {
    func measureText(text: String): Float64
    func countLines(text: String): Int64
}

public class DefaultMermaidTextMeasurer <: MermaidTextMeasurer {
    public init() {}

    public func measureText(text: String): Float64 {
        var width = 0.0
        for (r in text.runes()) {
            width += measureRune(r)
        }
        return width
    }

    public func countLines(text: String): Int64 {
        var lines: Int64 = 1
        var i: Int64 = 0
        while (i < text.size) {
            if (text[i] == b'\n') {
                lines++
            } else if (text[i] == b'\r') {
                lines++
                if (i + 1 < text.size && text[i + 1] == b'\n') {
                    i++
                }
            }
            i++
        }
        return lines
    }

    private func measureRune(r: Rune): Float64 {
        if (r == r' ' || r == r'\t') {
            return 4.0
        }
        if ((r >= r'\u{2E80}' && r <= r'\u{A4CF}') || (r >= r'\u{AC00}' && r <= r'\u{D7AF}') || (r >= r'\u{F900}' && r <= r'\u{FAFF}') || (r >= r'\u{FE10}' && r <= r'\u{FE6F}') || (r >= r'\u{FF00}' && r <= r'\u{FFEF}')) {
            return 16.0
        }
        return 8.0
    }
}
