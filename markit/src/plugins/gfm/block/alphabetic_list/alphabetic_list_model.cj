package markit.plugins.gfm.block.alphabetic_list

import std.collection.ArrayList
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class AlphabeticListBlockState <: BlockState {
    public let baseIndent: Int64
    public let startLetter: Byte
    public let isUpperCase: Bool
    public let delimiter: Byte
    public var expectedLetter: Byte
    public var tight: Bool = true
    public var sourceSpan: SourceSpan
    public let items = ArrayList<AlphabeticListItemData>()

    public init(marker: AlphabeticListMarker, sourceSpan: SourceSpan) {
        this.baseIndent = marker.indent
        this.startLetter = marker.letter
        this.isUpperCase = marker.isUpperCase
        this.delimiter = marker.delimiter
        this.expectedLetter = marker.letter
        this.sourceSpan = sourceSpan
    }

    public func addItem(marker: AlphabeticListMarker, line: SourceLine): Unit {
        items.add(AlphabeticListItemData(marker, line))
        expectedLetter = nextLetter(marker.letter)
    }

    public func addContinuationLine(line: SourceLine): Unit {
        if (items.isEmpty()) {
            return
        }
        items[items.size - 1].addContinuationLine(line)
    }

    private func nextLetter(letter: Byte): Byte {
        if (isUpperCase) {
            return if (letter == b'Z') { b'A' } else { letter + 1 }
        }
        return if (letter == b'z') { b'a' } else { letter + 1 }
    }
}

public class AlphabeticListItemData {
    public let letter: Byte
    public let delimiter: Byte
    public let indent: Int64
    public let leadingContent: String
    public let firstLineSpan: SourceSpan
    public let firstLineTerminated: Bool
    public var sourceSpan: SourceSpan
    public let continuationLines = ArrayList<SourceLine>()

    public init(marker: AlphabeticListMarker, line: SourceLine) {
        this.letter = marker.letter
        this.delimiter = marker.delimiter
        this.indent = marker.indent
        this.leadingContent = marker.content
        this.firstLineSpan = line.span
        this.firstLineTerminated = line.terminated
        this.sourceSpan = line.span
    }

    public func addContinuationLine(line: SourceLine): Unit {
        continuationLines.add(line)
        sourceSpan = sourceSpan.merge(line.span)
    }

    public func endsWithTerminator(): Bool {
        if (!continuationLines.isEmpty()) {
            return continuationLines[continuationLines.size - 1].terminated
        }
        return firstLineTerminated
    }
}

public class AlphabeticListMarker {
    public let letter: Byte
    public let isUpperCase: Bool
    public let delimiter: Byte
    public let indent: Int64
    public let content: String

    public init(
        letter: Byte,
        isUpperCase: Bool,
        delimiter: Byte,
        indent: Int64,
        content: String
    ) {
        this.letter = letter
        this.isUpperCase = isUpperCase
        this.delimiter = delimiter
        this.indent = indent
        this.content = content
    }
}
