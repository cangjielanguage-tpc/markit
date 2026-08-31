package markit.core.source

import std.collection.ArrayList

public class LineIndex {
    private let indexedLines = ArrayList<SourceLine>()

    public prop size: Int64 {
        get() {
            return indexedLines.size
        }
    }

    public func add(line: SourceLine): Unit {
        indexedLines.add(line)
    }

    public func lineAt(index: Int64): SourceLine {
        return indexedLines[index]
    }

    public func lines(): ArrayList<SourceLine> {
        let copy = ArrayList<SourceLine>()
        for (line in indexedLines) {
            copy.add(line)
        }
        return copy
    }

    public func findByByteOffset(byteOffset: Int64): ?SourceLine {
        for (line in indexedLines) {
            if (byteOffset >= line.span.startByte && byteOffset <= line.span.endByte) {
                return Some(line)
            }
        }
        return None
    }
}
