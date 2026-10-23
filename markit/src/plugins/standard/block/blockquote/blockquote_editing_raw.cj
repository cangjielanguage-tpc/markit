package markit.plugins.standard.block.blockquote

import std.collection.ArrayList
import markit.core.block.{BlockEditingContext, BlockPayloadUpdate}
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.{TypedSyntaxPayload, NodeCodec}
import markit.core.source.{EditableRopeVersion, SourceSpan}
import markit.plugins.standard.editing.standardProjectMappedRaw

// Nested quote raw spelling is its parent's normalized view: ancestor markers
// are absent and line endings are LF. The top-level spelling remains physical.
private class QuoteRawNewline <: InlineTextView {
    public QuoteRawNewline(private let identity: SourceVersionIdentity,
        private let first: Int64, private let last: Int64) {}
    public prop source: SourceVersionIdentity { get() { return identity } }
    public prop mappingIdentity: String { get() { return "quote.raw.newline" } }
    public prop byteLength: Int64 { get() { return 1 } }
    public func readByte(index: Int64): Byte {
        if (index != 0) { throw IllegalArgumentException("Invalid quote newline byte") }; return b'\n'
    }
    public func sliceBytes(start: Int64, end: Int64): String {
        if (start < 0 || end < start || end > 1) { throw IllegalArgumentException("Invalid quote newline window") }
        return if (start == end) { "" } else { "\n" }
    }
    public func runeOffsetAtByte(index: Int64): Int64 {
        if (index < 0 || index > 1) { throw IllegalArgumentException("Invalid quote newline boundary") }; return index
    }
    public func mapByte(index: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (index < 0 || index > 1) { return None }
        return Some(SourceAnchor(source, if (index == 0) { first } else { last }, affinity: affinity))
    }
}

public func blockquoteParentDepth(context: BlockEditingContext, start: Int64): Int64 {
    let source = (context.source as EditableRopeVersion).getOrThrow()
    let line = source.coordinateAtByte(start).getOrThrow().line
    var cursor = source.byteAtLineColumn(line, 0).getOrThrow()
    var depth: Int64 = 0
    while (cursor < start) {
        let width = blockquoteSourceContentStart(source, cursor, start)
        if (width.isNone() || width.getOrThrow() == 0) { break }
        cursor += width.getOrThrow(); depth += 1
    }
    return depth
}

public func blockquoteRawView(context: BlockEditingContext, start: Int64, end: Int64,
    parentDepth: Int64, id: Int64): MappedInlineTextView {
    if (parentDepth == 0) {
        return MappedInlineTextView([RopeInlineTextView(context.source, start, end)],
            context.source.identity, "quote.raw:${id}")
    }
    let source = (context.source as EditableRopeVersion).getOrThrow()
    let parts = ArrayList<InlineTextView>()
    var line = source.coordinateAtByte(start).getOrThrow().line
    while (line < source.lineCount) {
        let physical = source.byteAtLineColumn(line, 0).getOrThrow()
        if (physical >= end) { break }
        let next = if (line + 1 < source.lineCount) { source.byteAtLineColumn(line + 1, 0).getOrThrow() } else { source.byteLength }
        var finish = next
        if (finish > physical && source.readByte(finish - 1) == b'\n') { finish -= 1 }
        if (finish > physical && source.readByte(finish - 1) == b'\r') { finish -= 1 }
        var first = physical
        for (_ in 0..parentDepth) { first += blockquoteSourceContentStart(source, first, finish) ?? 0 }
        if (first < start) { first = start }
        if (finish > end) { finish = end }
        if (first <= finish) { parts.add(RopeInlineTextView(source, first, finish)) }
        if (next <= end && next > finish) { parts.add(QuoteRawNewline(source.identity, finish, next)) }
        line += 1
    }
    return MappedInlineTextView(parts.toArray(), source.identity, "quote.raw:${id}")
}

// Payload updates follow the ancestor path only. Persistent mapped parts retain
// their old immutable source; the actual inserted bytes receive the new epoch.
public func blockquoteAncestorRawUpdates(context: BlockEditingContext, parentId: Int64,
    editStart: Int64, editEnd: Int64, rebuild!: Bool = false): Array<BlockPayloadUpdate> {
    let tree = context.previous.getOrThrow()
    var cursor = tree.view(parentId)
    let updates = ArrayList<BlockPayloadUpdate>()
    let codec = NodeCodec(); registerBlockquoteEditingCodecs(codec)
    while (let Some(view) <- cursor) {
        if (let typed: TypedSyntaxPayload <- view.syntax.payload) {
            if (let quotedNode: EditingBlockquoteNode <- typed.materializeShallow()) {
                let start = context.resolve(view.syntax.startAnchor).getOrThrow()
                let end = context.resolve(view.syntax.endAnchor).getOrThrow()
                let span = SourceSpan(start, end, context.source.coordinateAtByte(start).getOrThrow().runeOffset,
                    context.source.coordinateAtByte(end).getOrThrow().runeOffset)
                var raw: ?MappedInlineTextView = None
                if (!rebuild) {
                    let a = standardProjectMappedRaw(quotedNode.rawView,
                        SourceAnchor(context.source.identity, editStart, affinity: AnchorAffinity.Before), context)
                    let b = standardProjectMappedRaw(quotedNode.rawView,
                        SourceAnchor(context.source.identity, editEnd, affinity: AnchorAffinity.After), context)
                    if (a.isSome() && b.isSome() && a.getOrThrow() <= b.getOrThrow()) {
                        raw = Some(quotedNode.rawView.spliceBytes(a.getOrThrow(), b.getOrThrow(),
                            [RopeInlineTextView(context.source, editStart, editEnd)], context.source.identity, quotedNode.rawView.mappingIdentity))
                    }
                }
                let mapped = if (let Some(ready) <- raw) { ready }
                    else { blockquoteRawView(context, start, end, quotedNode.parentQuoteDepth, quotedNode.id) }
                let current = EditingBlockquoteNode(quotedNode.id, span, quotedNode.blockRecovery.getOrThrow(), quotedNode.editingProvider,
                    mapped, quotedNode.parentQuoteDepth)
                quotedNode.copyBaseTo(current); current.sourceSpan = span
                updates.add(BlockPayloadUpdate(TypedSyntaxPayload(codec, current), quotedNode.id))
            }
        }
        cursor = view.parent()
    }
    return updates.toArray()
}
