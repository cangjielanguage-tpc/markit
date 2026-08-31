package markit.plugins.gfm.block.task_list

import std.collection.ArrayList
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class TaskListBlockState <: BlockState {
    public let baseIndent: Int64
    public var tight: Bool = true
    public var sourceSpan: SourceSpan
    public let items = ArrayList<TaskListItemData>()

    public init(marker: TaskListMarker, sourceSpan: SourceSpan) {
        this.baseIndent = marker.indent
        this.sourceSpan = sourceSpan
    }

    public func addItem(marker: TaskListMarker, line: SourceLine): Unit {
        items.add(TaskListItemData(marker, line))
    }

    public func addContinuationLine(line: SourceLine): Unit {
        if (items.isEmpty()) {
            return
        }
        items[items.size - 1].addContinuationLine(line)
    }
}

public class TaskListItemData {
    public let marker: Byte
    public let checked: Bool
    public let indent: Int64
    public let leadingContent: String
    public let firstLineSpan: SourceSpan
    public let firstLineTerminated: Bool
    public var sourceSpan: SourceSpan
    public let continuationLines = ArrayList<SourceLine>()

    public init(marker: TaskListMarker, line: SourceLine) {
        this.marker = marker.marker
        this.checked = marker.checked
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

public class TaskListMarker {
    public let marker: Byte
    public let checked: Bool
    public let indent: Int64
    public let content: String

    public init(
        marker: Byte,
        checked: Bool,
        indent: Int64,
        content: String
    ) {
        this.marker = marker
        this.checked = checked
        this.indent = indent
        this.content = content
    }
}
