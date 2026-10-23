package markit.plugins.standard.editing

import markit.core.block.BlockEditingContext
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.{NodeCodec, PersistentTextPayload}
import markit.plugins.standard.inline.soft_break.registerSoftBreakEditingCodecs

// The paragraph provider supplies an ordered physical-source mapping and counts
// backslashes once at capture, then updates that count from the actual edit.
// Constructing this immutable carrier never scans or exports the mapped text.
public class StandardParagraphInlineView <: InlineTextView {
    public StandardParagraphInlineView(public let mapped: MappedInlineTextView, public let escapeCount: Int64,
        public let normalizedRaw!: Bool = false) {
        if (escapeCount < 0) { throw IllegalArgumentException("Negative paragraph escape count") }
    }
    public prop source: SourceVersionIdentity { get() { return mapped.source } }
    public prop mappingIdentity: String { get() { return mapped.mappingIdentity } }
    public prop byteLength: Int64 { get() { return mapped.byteLength } }
    public func readByte(at: Int64): Byte { return mapped.readByte(at) }
    public func sliceBytes(start: Int64, end: Int64): String { return mapped.sliceBytes(start, end) }
    public func runeOffsetAtByte(at: Int64): Int64 { return mapped.runeOffsetAtByte(at) }
    public func mapByte(at: Int64, affinity: AnchorAffinity): ?SourceAnchor { return mapped.mapByte(at, affinity) }
}

public interface StandardInlineChildConsumer {
    prop hasEditingChildren: Bool
    func configureEditingChildren(factory: () -> InlineEditingSession): Unit
}

public class StandardInlinePlan {
    private let dispatch = InlineDispatchTable()
    public let literal = StandardLiteralFacet()
    public StandardInlinePlan(parsers: Array<InlineParser>, public let codec: NodeCodec) {
        for (parser in parsers) { dispatch.register(parser) }
        registerSoftBreakEditingCodecs(codec)
        let capturedDispatch = dispatch; let capturedCodec = codec; let capturedLiteral = literal
        let factory = { => InlineEditingSession(capturedDispatch, capturedCodec, capturedLiteral) }
        for (parser in parsers) {
            if (let consumer: StandardInlineChildConsumer <- parser) {
                if (!consumer.hasEditingChildren) { consumer.configureEditingChildren(factory) }
            }
        }
    }
    // Each paragraph retains its own engine and snapshot brand. Unsupported
    // registered parsers fail the core capability gate rather than disappearing.
    public func create(): InlineEditingSession { return InlineEditingSession(dispatch, codec, literal) }
}

private func standardViewResolve(view: InlineTextView, anchor: SourceAnchor,
    context: BlockEditingContext): ?Int64 {
    if (anchor.source.documentId != view.source.documentId) { return None }
    if (anchor.source.version == view.source.version) { return Some(anchor.byteOffset) }
    if (view.source.version == context.sourceVersion) { return context.resolve(anchor) }
    if (let Some(previous) <- context.previous) { return previous.resolveAtVersion(anchor, view.source.version) }
    return None
}

private func standardEscapeStart(view: InlineTextView, start: Int64): Int64 {
    var cursor = start
    while (cursor > 0 && view.readByte(cursor - 1) == b'\\') { cursor -= 1 }
    return cursor
}

// For providers that explicitly own an ordered physical mapping. This helper
// supplies inverse coordinates only; it never grants raw spelling provenance.
public func standardProjectMappedRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64 {
    let target = standardViewResolve(view, anchor, context)
    if (target.isNone()) { return None }
    var low: Int64 = 0; var high = view.byteLength
    while (low < high) {
        let middle = low + (high - low) / 2
        let mapped = view.mapByte(middle, AnchorAffinity.After)
        if (mapped.isNone()) { return None }
        let raw = standardViewResolve(view, mapped.getOrThrow(), context)
        if (raw.isNone()) { return None }
        if (raw.getOrThrow() < target.getOrThrow()) { low = middle + 1 } else { high = middle }
    }
    for (affinity in [AnchorAffinity.After, AnchorAffinity.Before]) {
        if (let Some(mapped) <- view.mapByte(low, affinity)) {
            if (standardViewResolve(view, mapped, context) == target) { return Some(low) }
        }
    }
    return None
}

private func standardEscapeEnd(view: InlineTextView, end: Int64): Int64 {
    var cursor = end
    while (cursor < view.byteLength && view.readByte(cursor) == b'\\') { cursor += 1 }
    // A changed slash run can change the interpretation of its next scalar,
    // including a parser opener/newline. Keep that real dependency in the unit.
    if (cursor < view.byteLength) {
        let byte = view.readByte(cursor)
        cursor += if (byte < 0x80) { 1 } else if ((byte & 0xE0) == 0xC0) { 2 }
            else if ((byte & 0xF0) == 0xE0) { 3 } else { 4 }
    }
    return cursor
}

public class StandardLiteralFacet <: InlineLiteralFacet {
    public prop grammarVersion: String { get() { return "standard.inline-escapes.v1" } }
    public func offsetsFollowLiteral(view: InlineTextView): Bool {
        if (let paragraph: StandardParagraphInlineView <- view) { return paragraph.escapeCount == 0 }
        return false
    }
    public func decode(view: InlineTextView, start: Int64, end: Int64): String {
        return InlineUtils.processEscapes(view.sliceBytes(start, end))
    }
    public func payload(view: InlineTextView, start: Int64, end: Int64,
        block: BlockEditingContext): ?PersistentTextPayload {
        // Only the paragraph provider proves the ordered physical mapping.
        // Ordinary/synthetic InlineTextViews retain the interface's None rule.
        let provider = view as StandardParagraphInlineView
        if (provider.isNone() || view.source.documentId != block.documentId ||
            view.source.version != block.sourceVersion) { return None }
        let spelling = view.sliceBytes(start, end)
        let raw = StringBuilder()
        var cursor: Int64 = 0; var last: Int64 = -1; var rawStart: Int64 = -1
        // Check the selected materialization unit, never unrelated text. An
        // unmapped interior part cannot acquire physical raw merely because
        // its two surrounding parts happen to have source anchors.
        while (cursor < spelling.size) {
            let width = InlineUtils.nextRuneByteSize(spelling, cursor)
            if (width == 0) { return None }
            // Opposite affinities select this scalar's own mapped part,
            // excluding quote/indent gaps between adjacent physical parts.
            let a = view.mapByte(start + cursor, AnchorAffinity.After).flatMap({ anchor => block.resolve(anchor) })
            let b = view.mapByte(start + cursor + width, AnchorAffinity.Before).flatMap({ anchor => block.resolve(anchor) })
            if (a.isNone() || b.isNone() || a.getOrThrow() < last || b.getOrThrow() <= a.getOrThrow()) { return None }
            if (!provider.getOrThrow().normalizedRaw) {
                if (rawStart < 0) { rawStart = a.getOrThrow() }
                else if (a.getOrThrow() != last) {
                    raw.append(block.source.sliceBytes(rawStart, last)); rawStart = a.getOrThrow()
                }
            }
            last = b.getOrThrow()
            cursor += width
        }
        if (rawStart >= 0) { raw.append(block.source.sliceBytes(rawStart, last)) }
        return Some(PersistentTextPayload.withRawSpelling(InlineUtils.processEscapes(spelling),
            if (provider.getOrThrow().normalizedRaw) { spelling } else { raw.toString() }))
    }
    public func projectRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64 {
        if (!(view is StandardParagraphInlineView)) { return None }
        // MappedInlineTextView is persistent/weighted; each anchor lookup is
        // logarithmic in its parts. No scan of paragraph bytes or lines occurs.
        return standardProjectMappedRaw(view, anchor, context)
    }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow {
        let change = context.change
        if (offsetsFollowLiteral(context.previous) && offsetsFollowLiteral(context.current)) {
            return Some(InlineRecoveryWindow(change.startByte, change.oldEndByte, change.newEndByte,
                "paragraph metadata proves no escapes", grammarVersion))
        }
        let start = standardEscapeStart(context.previous, change.startByte)
        let oldEnd = standardEscapeEnd(context.previous, change.oldEndByte)
        let newEnd = standardEscapeEnd(context.current, change.newEndByte)
        let delta = change.newEndByte - change.oldEndByte
        let finish = if (oldEnd > newEnd - delta) { oldEnd } else { newEnd - delta }
        return Some(InlineRecoveryWindow(start, finish, finish + delta,
            "backslash parity and following scalar; nonidentity Text expands in core", grammarVersion))
    }
    public func splice(previous: PersistentTextPayload, context: InlineRecoveryContext): ?InlineLiteralSplice {
        if (!offsetsFollowLiteral(context.previous) || !offsetsFollowLiteral(context.current) ||
            !previous.rawSpellingFollowsText || previous.byteLength != context.previous.byteLength) { return None }
        return Some(InlineLiteralSplice(context.change.startByte, context.change.oldEndByte,
            context.current.sliceBytes(context.change.startByte, context.change.newEndByte)))
    }
}
