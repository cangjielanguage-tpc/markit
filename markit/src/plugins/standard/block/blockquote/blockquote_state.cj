package markit.plugins.standard.block.blockquote

import std.collection.ArrayList
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class BlockquoteState <: BlockState {
    public var sourceSpan: SourceSpan
    public let lines = ArrayList<SourceLine>()

    public init(sourceSpan: SourceSpan) {
        this.sourceSpan = sourceSpan
    }

    public func addLine(text: String, line: SourceLine): Unit {
        lines.add(SourceLine(text, line.span, terminated: line.terminated))
        sourceSpan = sourceSpan.merge(line.span)
    }
}
