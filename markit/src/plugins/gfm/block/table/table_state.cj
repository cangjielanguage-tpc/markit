package markit.plugins.gfm.block.table

import std.collection.ArrayList
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class TableState <: BlockState {
    public let headerLine: SourceLine
    public let alignmentLine: SourceLine
    public let alignments: ArrayList<TableAlignment>
    public let bodyLines = ArrayList<SourceLine>()
    public var sourceSpan: SourceSpan

    public init(
        headerLine: SourceLine,
        alignmentLine: SourceLine,
        alignments: ArrayList<TableAlignment>
    ) {
        this.headerLine = headerLine
        this.alignmentLine = alignmentLine
        this.alignments = alignments
        this.sourceSpan = headerLine.span.merge(alignmentLine.span)
    }

    public func addBodyLine(line: SourceLine): Unit {
        bodyLines.add(line)
        sourceSpan = sourceSpan.merge(line.span)
    }
}
