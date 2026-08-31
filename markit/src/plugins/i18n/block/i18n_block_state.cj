package markit.plugins.i18n.block

import std.collection.ArrayList
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class I18nBlockState <: BlockState {
    public let languageId: String
    public let universal: Bool
    public let indentLevel: Int64
    public let openingLine: SourceLine
    public let contentLines = ArrayList<SourceLine>()
    public var closingLine: ?SourceLine = None
    public var sourceSpan: SourceSpan
    public var closed: Bool = false

    public init(
        languageId: String,
        universal: Bool,
        indentLevel: Int64,
        openingLine: SourceLine
    ) {
        this.languageId = languageId
        this.universal = universal
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
