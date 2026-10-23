package markit.plugins.standard.inline.reference_link

import markit.core.block.BlockEditingContext
import markit.core.editing.AnchorAffinity
import markit.core.inline.*
import markit.plugins.standard.editing.{StandardLiteralFacet, StandardParagraphInlineView}

public func referenceLabelView(parent: InlineTextView, begin: Int64, end: Int64, identity: String,
    normalizedRaw!: Bool = false): InlineTextView {
    let window = InlineTextWindow(parent, begin, end)
    var escapes: Int64 = 0
    for (at in 0..window.byteLength) { if (window.readByte(at) == b'\\') { escapes += 1 } }
    // The literal provider still validates every emitted unit's real physical
    // mapping; this window cannot manufacture anchors for an unmapped source.
    return StandardParagraphInlineView(MappedInlineTextView([window], parent.source, identity), escapes,
        normalizedRaw: normalizedRaw)
}

public class ReferenceLabelProjection <: InlineNestedProjection {
    public ReferenceLabelProjection(private let identity: String) {}
    public func project(_: InlineTextView, _: InlineTextView, _: InlineEditChange): ?InlineNestedProjectionResult {
        // LinkNode.content is a public immutable String derived from its label.
        // A label edit must retry that actual reference candidate as well.
        return None
    }
    public func rebase(child: InlineTextView, current: InlineTextView,
        block: BlockEditingContext): ?InlineNestedProjectionResult {
        let literal = StandardLiteralFacet()
        let a = child.mapByte(0, AnchorAffinity.After)
        let b = child.mapByte(child.byteLength, AnchorAffinity.Before)
        if (a.isNone() || b.isNone()) { return None }
        let begin = literal.projectRaw(current, a.getOrThrow(), block)
        let end = literal.projectRaw(current, b.getOrThrow(), block)
        if (begin.isNone() || end.isNone()) { return None }
        let start = begin.getOrThrow(); let finish = end.getOrThrow()
        if (start < 1 || finish >= current.byteLength || finish - start != child.byteLength ||
            current.readByte(start - 1) != b'[' || current.readByte(finish) != b']') { return None }
        let previous = child as StandardParagraphInlineView
        if (previous.isNone()) { return None }
        return Some(InlineNestedProjectionResult(referenceLabelView(current, start, finish, identity,
            normalizedRaw: previous.getOrThrow().normalizedRaw),
            InlineEditChange(0, 0, 0), ReferenceLabelProjection(identity)))
    }
}
