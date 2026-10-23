package markit.plugins.standard.block.paragraph

import markit.core.block.{BlockEditingContext, LeafBlockParser, ContinuationBlockParser}
import markit.core.editing.AnchorAffinity
import markit.core.inline.{InlineTextView, RopeInlineTextView}

// Candidate inventory comes from the actual registered grammar. This proof
// reads physical/view coordinates and one leading byte; it does not copy a
// SourceLine or reinterpret another plugin's delimiters.
public class ParagraphBlockBoundary {
    private let leaves: Array<LeafBlockParser>
    private let continuations: Array<ContinuationBlockParser>
    public ParagraphBlockBoundary(leaves: Array<LeafBlockParser>, continuations: Array<ContinuationBlockParser>) {
        this.leaves = leaves.clone(); this.continuations = continuations.clone()
    }
    public func proves(context: BlockEditingContext, view: InlineTextView, start: Int64): Bool {
        let coordinate = context.source.coordinateAtByte(start).getOrThrow()
        let physicalStart = context.source.byteAtLineColumn(coordinate.line, 0).getOrThrow()
        var low: Int64 = 0; var high = view.byteLength
        while (low < high) {
            let middle = low + (high - low) / 2
            let mapped = view.mapByte(middle, AnchorAffinity.After)
            if (mapped.isNone()) { return false }
            if (context.resolve(mapped.getOrThrow()).getOrThrow() < physicalStart) { low = middle + 1 } else { high = middle }
        }
        let mapped = view.mapByte(low, AnchorAffinity.After)
        if (mapped.isNone() || low == view.byteLength) { return false }
        let first = context.resolve(mapped.getOrThrow()).getOrThrow()
        if (start <= first) { return false } // normalization/line-start grammar may change
        let byte = RopeInlineTextView(context.source, first, first + 1).readByte(0)
        if (byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n') { return false }
        for (parser in leaves) {
            if (parser.acceptsAnyNonBlank) { return false }
            for (candidate in parser.startBytes) { if (candidate == byte) { return false } }
        }
        for (parser in continuations) {
            for (candidate in parser.startBytes) { if (candidate == byte) { return false } }
        }
        return true
    }
}
