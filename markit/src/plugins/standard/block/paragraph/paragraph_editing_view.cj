package markit.plugins.standard.block.paragraph

import std.collection.ArrayList
import markit.core.block.BlockEditingContext
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.Node
import markit.core.session.ParagraphTermination
import markit.core.source.SourceLine
import markit.plugins.standard.editing.StandardParagraphInlineView

private class ParagraphNewlineView <: InlineTextView {
    public ParagraphNewlineView(private let sourceIdentity: SourceVersionIdentity,
        private let begin: Int64, private let finish: Int64) {}
    public prop source: SourceVersionIdentity { get() { return sourceIdentity } }
    public prop mappingIdentity: String { get() { return "standard.paragraph.newline" } }
    public prop byteLength: Int64 { get() { return 1 } }
    public func readByte(index: Int64): Byte {
        if (index != 0) { throw IllegalArgumentException("Newline byte out of bounds") }; return b'\n'
    }
    public func sliceBytes(start: Int64, end: Int64): String {
        if (start < 0 || end < start || end > 1) { throw IllegalArgumentException("Newline window out of bounds") }
        return if (start == end) { "" } else { "\n" }
    }
    public func runeOffsetAtByte(index: Int64): Int64 {
        if (index < 0 || index > 1) { throw IllegalArgumentException("Newline boundary out of bounds") }; return index
    }
    public func mapByte(index: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (index < 0 || index > 1) { return None }
        return Some(SourceAnchor(source, if (index == 0) { begin } else { finish }, affinity: affinity))
    }
}
private class ParagraphMappedRawState <: IncrementalStatePayload {
    public ParagraphMappedRawState(public let normalized: Bool) {}
    public func clonePayload(): IncrementalStatePayload { return this }
    public func fingerprint(): String { return normalized.toString() }
}
public func withMappedParagraphRaw(context: BlockEditingContext, action: () -> ArrayList<Node>): ArrayList<Node> {
    let previous = context.readState("standard.paragraph.mapping") ?? ParagraphMappedRawState(false)
    context.writeState("standard.paragraph.mapping", ParagraphMappedRawState(true))
    try { return action() } finally { context.writeState("standard.paragraph.mapping", previous) }
}

public func paragraphEditingView(context: BlockEditingContext, lines: ArrayList<SourceLine>,
    termination: ParagraphTermination, id: Int64): StandardParagraphInlineView {
    let parts = ArrayList<InlineTextView>(); var escapes: Int64 = 0
    for (i in 0..lines.size) {
        let line = lines[i]
        parts.add(RopeInlineTextView(context.source, line.span.startByte, line.span.endByte))
        for (at in 0..line.text.size) { if (line.text[at] == b'\\') { escapes += 1 } }
        if (i + 1 < lines.size || ParagraphChildrenBuilder.shouldAppendTerminalSoftBreak(line, termination)) {
            let coordinate = context.source.coordinateAtByte(line.span.endByte).getOrThrow()
            let finish = context.source.byteAtLineColumn(coordinate.line + 1, 0) ?? line.span.endByte
            parts.add(ParagraphNewlineView(context.source.identity, line.span.endByte, finish))
        }
    }
    let state = context.readState("standard.paragraph.mapping")
    let normalized = if (let Some(value) <- state) { (value as ParagraphMappedRawState).getOrThrow().normalized } else { false }
    return StandardParagraphInlineView(MappedInlineTextView(parts.toArray(), context.source.identity, "paragraph:${id}"), escapes,
        normalizedRaw: normalized)
}

public func paragraphEscapeCount(view: InlineTextView, start: Int64, end: Int64): Int64 {
    var count: Int64 = 0
    for (i in start..end) { if (view.readByte(i) == b'\\') { count += 1 } }
    return count
}
