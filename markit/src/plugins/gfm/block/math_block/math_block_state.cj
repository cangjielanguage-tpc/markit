package markit.plugins.gfm.block.math_block

import std.collection.ArrayList
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class MathBlockState <: BlockState {
    public let indentLevel: Int64
    public let openingLine: SourceLine
    public let contentLines = ArrayList<SourceLine>()
    public var closingLine: ?SourceLine = None
    public var sourceSpan: SourceSpan
    public var closed: Bool = false

    public init(indentLevel: Int64, openingLine: SourceLine) {
        this.indentLevel = indentLevel
        this.openingLine = openingLine
        this.sourceSpan = openingLine.span
    }

    public func addContentLine(line: SourceLine): Unit {
        contentLines.add(line)
        sourceSpan = sourceSpan.merge(line.span)
    }

    public func close(line: SourceLine): Unit {
        closingLine = Some(line)
        sourceSpan = sourceSpan.merge(line.span)
        closed = true
    }
}
