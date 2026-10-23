package markit.plugins.standard.block.list

import std.collection.ArrayList
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class ListBlockState <: BlockState {
    public let ordered: Bool
    public let baseIndent: Int64
    public let delimiter: Byte
    public let startNumber: Int64
    public var tight: Bool = true
    public var sourceSpan: SourceSpan
    public let items = ArrayList<ListItemData>()
    public let pendingBlankLines = ArrayList<SourceLine>()

    public ListBlockState(marker: ListMarker, sourceSpan: SourceSpan) {
        this.ordered = marker.ordered
        this.baseIndent = marker.indent
        this.delimiter = marker.delimiter
        this.startNumber = marker.number
        this.sourceSpan = sourceSpan
    }

    public func addItem(marker: ListMarker, line: SourceLine): Unit {
        items.add(ListItemData(marker, line))
    }

    public func addContinuationLine(line: SourceLine): Unit {
        if (items.isEmpty()) {
            return
        }
        items[items.size - 1].addContinuationLine(line)
    }

    public func addPendingBlankLine(line: SourceLine): Unit {
        pendingBlankLines.add(line)
    }

    public func clearPendingBlankLines(): Unit {
        pendingBlankLines.clear()
    }
}

public class ListItemData {
    public let number: Int64
    public let marker: Byte
    public let delimiter: Byte
    public let indent: Int64
    public let leadingContent: String
    public let firstLineSpan: SourceSpan
    public let firstLineContentSpan: SourceSpan
    public let firstLineTerminated: Bool
    public var sourceSpan: SourceSpan
    public let continuationLines = ArrayList<SourceLine>()

    public ListItemData(marker: ListMarker, line: SourceLine) {
        this.number = marker.number
        this.marker = marker.marker
        this.delimiter = marker.delimiter
        this.indent = marker.indent
        this.leadingContent = marker.content
        this.firstLineSpan = line.span
        this.firstLineContentSpan = SourceSpan(
            line.span.startByte + marker.contentStartByte,
            line.span.startByte + marker.contentEndByte,
            line.span.startRune + marker.contentStartRune,
            line.span.startRune + marker.contentEndRune
        )
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

public class ListMarker {
    public ListMarker(
        public let ordered: Bool,
        public let marker: Byte,
        public let delimiter: Byte,
        public let number: Int64,
        public let indent: Int64,
        public let content: String,
        public let contentStartByte: Int64,
        public let contentEndByte: Int64,
        public let contentStartRune: Int64,
        public let contentEndRune: Int64
    ) {}
}
