package markit.core.source

import std.collection.ArrayList

public class LineScanner {
    private let pendingSegments = ArrayList<String>()
    private var nextLineStartByte: Int64 = 0
    private var nextLineStartRune: Int64 = 0

    public func feed(chunk: String): ArrayList<SourceLine> {
        let lines = ArrayList<SourceLine>()
        var start: Int64 = 0

        while (true) {
            let maybeNewline = chunk.indexOf(b'\n', start)
            if (maybeNewline.isNone()) {
                break
            }

            let newline = maybeNewline.getOrThrow()
            appendSegment(chunk[start..newline])
            let decoded = takePendingLine()
            let sourceLine = emitLine(decoded.text, true, decoded.runeCount)
            advance(decoded.text.size, decoded.runeCount, 1, decoded.terminatorByteSize)
            lines.add(sourceLine)
            start = newline + 1
        }

        if (start < chunk.size) {
            appendSegment(chunk[start..])
        }

        return lines
    }

    public func finalize(): ?SourceLine {
        if (pendingSegments.isEmpty()) {
            return None
        }

        let decoded = takePendingLine(allowTrailingCarriageReturn: true)
        let sourceLine = emitLine(decoded.text, false, decoded.runeCount)
        advance(decoded.text.size, decoded.runeCount, 0, 0)
        return Some(sourceLine)
    }

    private func appendSegment(segment: String): Unit {
        if (!segment.isEmpty()) {
            pendingSegments.add(segment)
        }
    }

    private func takePendingLine(allowTrailingCarriageReturn!: Bool = false): DecodedLine {
        var text: String
        if (pendingSegments.size == 1) {
            text = pendingSegments[0]
        } else {
            var byteSize: Int64 = 0
            for (segment in pendingSegments) {
                byteSize += segment.size
            }

            let builder = StringBuilder(if (byteSize > 0) { byteSize } else { 1 })
            for (segment in pendingSegments) {
                builder.append(segment)
            }
            text = builder.toString()
        }
        pendingSegments.clear()

        var terminatorByteSize: Int64 = 1
        if (!allowTrailingCarriageReturn && text.endsWith("\r")) {
            text = text[0..text.size - 1]
            terminatorByteSize = 2
        }
        return DecodedLine(text, terminatorByteSize, countRunes(text))
    }

    private func emitLine(text: String, terminated: Bool, runeCount: Int64): SourceLine {
        return SourceLine(
            text,
            SourceSpan(
                nextLineStartByte,
                nextLineStartByte + text.size,
                nextLineStartRune,
                nextLineStartRune + runeCount
            ),
            terminated: terminated
        )
    }

    private func advance(textByteSize: Int64, textRuneCount: Int64, terminatorRuneCount: Int64, terminatorByteSize: Int64): Unit {
        nextLineStartByte += textByteSize + terminatorByteSize
        nextLineStartRune += textRuneCount + terminatorRuneCount
    }

    private func countRunes(text: String): Int64 {
        var count: Int64 = 0
        var index: Int64 = 0
        while (index < text.size) {
            let byte = text[index]
            if (byte < 0x80) {
                index += 1
            } else if ((byte & 0xE0) == 0xC0 && index + 1 < text.size) {
                index += 2
            } else if ((byte & 0xF0) == 0xE0 && index + 2 < text.size) {
                index += 3
            } else if ((byte & 0xF8) == 0xF0 && index + 3 < text.size) {
                index += 4
            } else {
                break
            }
            count += 1
        }
        return count
    }
}

private class DecodedLine {
    public let text: String
    public let terminatorByteSize: Int64
    public let runeCount: Int64

    public init(text: String, terminatorByteSize: Int64, runeCount: Int64) {
        this.text = text
        this.terminatorByteSize = terminatorByteSize
        this.runeCount = runeCount
    }
}
