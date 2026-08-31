package mermaid4cj.parser

import std.collection.{ArrayList, HashMap}
import mermaid4cj.core.{PieDiagram, PieParseResult, PieSlice}

public class PieParser {
    public init() {}

    public func parse(source: String): PieParseResult {
        let slices = ArrayList<PieSlice>()
        let diagnostics = ArrayList<String>()
        var sawHeader = false
        var title: ?String = None
        var showData = false
        let seen = HashMap<String, Bool>()
        var lineNo: Int64 = 0
        for (raw in source.lines()) {
            lineNo++
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            let lower = line.toAsciiLower()
            if (!sawHeader) {
                if (lower.startsWith("pie")) {
                    sawHeader = true
                    showData = lower.contains("showdata")
                    if (lower.contains(" title ")) {
                        if (let Some(pos) <- lower.indexOf(" title ")) {
                            title = Some(line[(pos + " title ".size)..line.size].trimAscii())
                        }
                    }
                    continue
                }
                diagnostics.add("Line ${lineNo}: expected pie header")
                break
            }
            if (lower.startsWith("title ")) {
                title = Some(line["title ".size..line.size].trimAscii())
            } else if (let Some(colon) <- line.indexOf(":")) {
                let label = unquote(line[0..colon].trimAscii())
                let valueText = line[(colon + 1)..line.size].trimAscii()
                if (let Some(value) <- parseNumber(valueText)) {
                    if (value < 0.0) {
                        diagnostics.add("Line ${lineNo}: pie slice value must be non-negative")
                    } else if (!seen.contains(label)) {
                        slices.add(PieSlice(label, value))
                        seen[label] = true
                    } else {
                        ()
                    }
                } else {
                    diagnostics.add("Line ${lineNo}: invalid pie slice value")
                }
            } else {
                diagnostics.add("Line ${lineNo}: unsupported pie statement")
            }
        }
        if (!sawHeader && diagnostics.isEmpty()) {
            diagnostics.add("Missing pie header")
        }
        return PieParseResult(PieDiagram(source, title: title, showData: showData, slices: slices), diagnostics: diagnostics.toArray())
    }

    private func parseNumber(text: String): ?Float64 {
        if (text.isEmpty()) {
            return None
        }
        var value = 0.0
        var scale = 1.0
        var afterDot = false
        var digits: Int64 = 0
        var decimalDigits: Int64 = 0
        var i: Int64 = 0
        if (text[0] == b'-') {
            return Some(-1.0)
        }
        while (i < text.size) {
            let ch = text[i]
            if (ch == b'.') {
                if (afterDot) {
                    return None
                }
                afterDot = true
            } else if (ch >= b'0' && ch <= b'9') {
                digits++
                if (afterDot) {
                    decimalDigits++
                    scale *= 10.0
                    value += Float64(ch - b'0') / scale
                } else {
                    value = value * 10.0 + Float64(ch - b'0')
                }
            } else {
                return None
            }
            i++
        }
        if (digits == 0) {
            return None
        }
        return Some(value)
    }

    private func stripComment(line: String): String {
        if (let Some(pos) <- line.indexOf("%%")) {
            return line[0..pos]
        }
        return line
    }

    private func unquote(text: String): String {
        if (text.size >= 2 && ((text[0] == b'"' && text[text.size - 1] == b'"') || (text[0] == b'\'' && text[text.size - 1] == b'\''))) {
            return text[1..(text.size - 1)]
        }
        return text
    }
}
