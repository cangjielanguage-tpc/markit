package markit.plugins.commonmark.block.html_block

import std.collection.{ArrayList, HashMap}
import markit.core.block.BlockState
import markit.core.source.{SourceLine, SourceSpan}

public class HTMLBlockState <: BlockState {
    public let blockType: HTMLBlockType
    public let tagName: String
    public let isSelfClosing: Bool
    public let isContentProtected: Bool
    public let attributes: HashMap<String, String>
    public let endMarker: String
    public let lines = ArrayList<SourceLine>()
    public var closed: Bool
    public var nestingDepth: Int64
    public var sourceSpan: SourceSpan

    public init(
        firstLine: SourceLine,
        blockType: HTMLBlockType,
        tagName: String,
        isSelfClosing: Bool,
        isContentProtected: Bool,
        attributes: HashMap<String, String>,
        endMarker: String,
        closed: Bool,
        nestingDepth!: Int64 = 0
    ) {
        this.blockType = blockType
        this.tagName = tagName
        this.isSelfClosing = isSelfClosing
        this.isContentProtected = isContentProtected
        this.attributes = attributes
        this.endMarker = endMarker
        this.closed = closed
        this.nestingDepth = nestingDepth
        this.sourceSpan = firstLine.span
        lines.add(firstLine)
    }

    public func add(line: SourceLine): Unit {
        lines.add(line)
        sourceSpan = sourceSpan.merge(line.span)
    }
}
