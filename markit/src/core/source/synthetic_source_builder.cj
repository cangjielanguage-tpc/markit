package markit.core.source

import std.collection.ArrayList

public class SyntheticSourceParseInput {
    public SyntheticSourceParseInput(
        public let source: SourceBuffer,
        public let lines: ArrayList<SourceLine>,
        private let originalSpans!: ArrayList<SourceSpan> = ArrayList<SourceSpan>()
    ) {}

    // Both synthetic consumers transform line prefixes, never suffixes. Keep an
    // individual origin per retained line: a constant offset fails for CRLF,
    // variable quote/indent prefixes, and nested detached parses.
    public func mapSpan(span: SourceSpan): SourceSpan {
        if (originalSpans.isEmpty()) {
            return span
        }
        return SourceSpan(
            mapOffset(span.startByte, false), mapOffset(span.endByte, false),
            mapOffset(span.startRune, true), mapOffset(span.endRune, true)
        )
    }

    private func mapOffset(offset: Int64, runeOffset: Bool): Int64 {
        var low: Int64 = 0
        var high = lines.size - 1
        while (low < high) {
            let mid = low + (high - low) / 2
            let end = if (runeOffset) { lines[mid].span.endRune } else { lines[mid].span.endByte }
            if (offset > end) {
                low = mid + 1
            } else {
                high = mid
            }
        }
        let local = lines[low].span
        let original = originalSpans[low]
        // Removing part of a tab can generate leading spaces. Those spaces
        // map to the original prefix, never before the original source line.
        let mapped = if (runeOffset) {
            original.endRune + offset - local.endRune
        } else {
            original.endByte + offset - local.endByte
        }
        let first = if (runeOffset) { original.startRune } else { original.startByte }
        return if (mapped < first) { first } else { mapped }
    }
}

public class SyntheticSourceBuilder {
    public static func build(
        inputLines: ArrayList<SourceLine>,
        preserveTrailingNewline!: Bool = false
    ): SyntheticSourceParseInput {
        let source = SourceBuffer()
        let lines = ArrayList<SourceLine>()
        let originalSpans = ArrayList<SourceSpan>()
        if (inputLines.isEmpty()) {
            return SyntheticSourceParseInput(source, lines, originalSpans: originalSpans)
        }

        let sb = StringBuilder()
        for (i in 0..inputLines.size) {
            if (i > 0) {
                sb.append("\n")
            }
            sb.append(inputLines[i].text)
        }
        if (preserveTrailingNewline && inputLines[inputLines.size - 1].terminated) {
            sb.append("\n")
        }
        source.append(sb.toString())

        var startByte: Int64 = 0
        var startRune: Int64 = 0
        for (i in 0..inputLines.size) {
            let line = inputLines[i]
            let terminated = i < inputLines.size - 1 || (preserveTrailingNewline && line.terminated)
            let endByte = startByte + line.text.size
            let endRune = startRune + countRunes(line.text)
            originalSpans.add(line.span)
            lines.add(SourceLine(
                line.text,
                SourceSpan(startByte, endByte, startRune, endRune),
                terminated: terminated
            ))
            startByte = endByte + if (terminated) { 1 } else { 0 }
            startRune = endRune + if (terminated) { 1 } else { 0 }
        }

        return SyntheticSourceParseInput(source, lines, originalSpans: originalSpans)
    }

    private static func countRunes(text: String): Int64 {
        var count: Int64 = 0
        for (_ in text.runes()) {
            count += 1
        }
        return count
    }
}
