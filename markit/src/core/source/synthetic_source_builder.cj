package markit.core.source

import std.collection.ArrayList

public class SyntheticSourceParseInput {
    public let source: SourceBuffer
    public let lines: ArrayList<SourceLine>

    public init(source: SourceBuffer, lines: ArrayList<SourceLine>) {
        this.source = source
        this.lines = lines
    }
}

public class SyntheticSourceBuilder {
    public static func build(
        inputLines: ArrayList<SourceLine>,
        preserveTrailingNewline!: Bool = false
    ): SyntheticSourceParseInput {
        let source = SourceBuffer()
        let lines = ArrayList<SourceLine>()
        if (inputLines.isEmpty()) {
            return SyntheticSourceParseInput(source, lines)
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
            lines.add(SourceLine(
                line.text,
                SourceSpan(startByte, endByte, startRune, endRune),
                terminated: terminated
            ))
            startByte = endByte + if (terminated) { 1 } else { 0 }
            startRune = endRune + if (terminated) { 1 } else { 0 }
        }

        return SyntheticSourceParseInput(source, lines)
    }

    private static func countRunes(text: String): Int64 {
        var count: Int64 = 0
        for (_ in text.runes()) {
            count += 1
        }
        return count
    }
}
