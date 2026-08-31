package markit.plugins.standard.block.fenced_code_block

import std.collection.ArrayList
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class FencedCodeBlockState <: BlockState {
    public let marker: Byte
    public let fenceLength: Int64
    public let indentWidth: Int64
    public let language: String
    public let highlightLines: String
    public let i18nLines: String
    public let openingLine: SourceLine
    public let lines = ArrayList<SourceLine>()
    public var sourceSpan: SourceSpan
    public var closed: Bool = false
    public var closingLine: ?SourceLine = None

    public init(
        marker: Byte,
        fenceLength: Int64,
        indentWidth: Int64,
        language: String,
        highlightLines: String,
        i18nLines: String,
        openingLine: SourceLine
    ) {
        this.marker = marker
        this.fenceLength = fenceLength
        this.indentWidth = indentWidth
        this.language = language
        this.highlightLines = highlightLines
        this.i18nLines = i18nLines
        this.openingLine = openingLine
        this.sourceSpan = openingLine.span
    }

    public func addContentLine(line: SourceLine): Unit {
        lines.add(line)
        this.sourceSpan = this.sourceSpan.merge(line.span)
    }

    public func close(line: SourceLine): Unit {
        closed = true
        closingLine = Some(line)
        this.sourceSpan = this.sourceSpan.merge(line.span)
    }
}
