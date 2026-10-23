package markit.core.inline

import markit.core.editing.{AnchorAffinity, EditableSourceVersion, SourceAnchor, SourceVersionIdentity}
import markit.core.source.{EditableRopeVersion, SourceSpan}
import markit.core.nodes.{PersistentTextPayload, PersistentTextSegment, TextNode}

// All offsets accepted here are view-local UTF-8 bytes. Raw-source edits are
// projected into these coordinates by the owning provider; mapByte preserves
// provenance and does not silently rebase anchors into the target version.
public interface InlineTextView {
    prop source: SourceVersionIdentity
    prop mappingIdentity: String
    prop byteLength: Int64
    func readByte(index: Int64): Byte
    // Explicit output-sized window export, never an implicit parser adapter.
    func sliceBytes(start: Int64, end: Int64): String
    // Invalid UTF-8 scalar boundaries reject rather than rounding a position.
    func runeOffsetAtByte(index: Int64): Int64
    func mapByte(index: Int64, affinity: AnchorAffinity): ?SourceAnchor
}

public class RopeInlineTextView <: InlineTextView {
    private let rope: EditableRopeVersion
    private let begin: Int64
    private let finish: Int64
    private let baseRune: Int64
    private let mappingKey: String
    public RopeInlineTextView(source: EditableSourceVersion, start: Int64, end: Int64,
        mappingIdentity!: String = "raw") {
        if (start < 0 || end < start || end > source.byteLength || mappingIdentity.isEmpty()) {
            throw IllegalArgumentException("Invalid inline source window")
        }
        this.rope = (source as EditableRopeVersion).getOrThrow()
        this.baseRune = source.coordinateAtByte(start).getOrThrow().runeOffset
        source.coordinateAtByte(end).getOrThrow()
        this.begin = start; this.finish = end; this.mappingKey = mappingIdentity
    }
    public prop source: SourceVersionIdentity { get() { return rope.identity } }
    public prop mappingIdentity: String { get() { return mappingKey } }
    public prop byteLength: Int64 { get() { return finish - begin } }
    public func readByte(index: Int64): Byte {
        if (index < 0 || index >= byteLength) { throw IllegalArgumentException("Inline byte index out of bounds") }
        return rope.readByte(begin + index)
    }
    public func sliceBytes(start: Int64, end: Int64): String {
        checkInlineRange(start, end, byteLength)
        return rope.sliceBytes(begin + start, begin + end)
    }
    public func runeOffsetAtByte(index: Int64): Int64 {
        checkInlineRange(index, index, byteLength)
        return rope.coordinateAtByte(begin + index).getOrThrow().runeOffset - baseRune
    }
    public func mapByte(index: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (index < 0 || index > byteLength) { return None }
        return Some(SourceAnchor(source, begin + index, affinity: affinity))
    }
}

// Windowing never obtains a String. Nested windows collapse to the original
// immutable view, so repeated local edits do not build a wrapper-history chain.
public class InlineTextWindow <: InlineTextView {
    private let base: InlineTextView
    private let begin: Int64
    private let finish: Int64
    private let baseRune: Int64
    private let mappingKey: String
    public InlineTextWindow(view: InlineTextView, start: Int64, end: Int64) {
        checkInlineRange(start, end, view.byteLength)
        view.runeOffsetAtByte(start); view.runeOffsetAtByte(end)
        if (let Some(window) <- (view as InlineTextWindow)) {
            this.base = window.base; this.begin = window.begin + start; this.finish = window.begin + end
        } else { this.base = view; this.begin = start; this.finish = end }
        this.baseRune = base.runeOffsetAtByte(begin)
        this.mappingKey = base.mappingIdentity + ":window:${begin}:${finish}"
    }
    public prop source: SourceVersionIdentity { get() { return base.source } }
    public prop mappingIdentity: String { get() { return mappingKey } }
    public prop byteLength: Int64 { get() { return finish - begin } }
    public func readByte(index: Int64): Byte {
        if (index < 0 || index >= byteLength) { throw IllegalArgumentException("Inline byte index out of bounds") }
        return base.readByte(begin + index)
    }
    public func sliceBytes(start: Int64, end: Int64): String {
        checkInlineRange(start, end, byteLength)
        return base.sliceBytes(begin + start, begin + end)
    }
    public func runeOffsetAtByte(index: Int64): Int64 {
        checkInlineRange(index, index, byteLength)
        return base.runeOffsetAtByte(begin + index) - baseRune
    }
    public func mapByte(index: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (index < 0 || index > byteLength) { return None }
        return base.mapByte(begin + index, affinity)
    }
}

// Synthetic text can still be read from an immutable rope/window, but it has
// no provable unique raw-source anchor. A containing view keeps that absence.
public class UnmappedInlineTextView <: InlineTextView {
    public UnmappedInlineTextView(private let sourceIdentity: SourceVersionIdentity,
        private let view: InlineTextView, private let mappingKey: String) {
        if (mappingKey.isEmpty()) { throw IllegalArgumentException("Unmapped inline view requires mapping identity") }
    }
    public prop source: SourceVersionIdentity { get() { return sourceIdentity } }
    public prop mappingIdentity: String { get() { return mappingKey } }
    public prop byteLength: Int64 { get() { return view.byteLength } }
    public func readByte(index: Int64): Byte { return view.readByte(index) }
    public func sliceBytes(start: Int64, end: Int64): String { return view.sliceBytes(start, end) }
    public func runeOffsetAtByte(index: Int64): Int64 { return view.runeOffsetAtByte(index) }
    public func mapByte(_: Int64, _: AnchorAffinity): ?SourceAnchor { return None }
}

private func checkInlineRange(start: Int64, end: Int64, length: Int64): Unit {
    if (start < 0 || end < start || end > length) { throw IllegalArgumentException("Invalid inline text range") }
}

private func validateInlineParts(parts: Array<InlineTextView>, target: SourceVersionIdentity): Unit {
    for (part in parts) {
        if (part.source.documentId != target.documentId || part.source.version > target.version) {
            throw IllegalArgumentException("Foreign or future inline source part")
        }
    }
}

private class InlineViewBranch {
    public let view: ?InlineTextView
    public let left: ?InlineViewBranch
    public let right: ?InlineViewBranch
    public let bytes: Int64
    public let runes: Int64
    public let count: Int64
    public let height: Int64
    public InlineViewBranch(view: InlineTextView) {
        this.view = Some(view); this.left = None; this.right = None
        this.bytes = view.byteLength; this.runes = view.runeOffsetAtByte(bytes)
        this.count = 1; this.height = 1
        if (bytes < 0 || runes < 0) { throw IllegalArgumentException("Invalid inline view summary") }
    }
    public init(left: InlineViewBranch, right: InlineViewBranch) {
        this.view = None; this.left = Some(left); this.right = Some(right)
        this.bytes = left.bytes + right.bytes; this.runes = left.runes + right.runes
        this.count = left.count + right.count
        this.height = 1 + if (left.height > right.height) { left.height } else { right.height }
    }
}

private func inlineViewJoin(left: ?InlineViewBranch, right: ?InlineViewBranch): ?InlineViewBranch {
    if (left.isNone()) { return right }; if (right.isNone()) { return left }
    let l = left.getOrThrow(); let r = right.getOrThrow()
    if (l.height > r.height + 1) {
        return Some(inlineViewBalance(l.left.getOrThrow(), inlineViewJoin(l.right, right).getOrThrow()))
    }
    if (r.height > l.height + 1) {
        return Some(inlineViewBalance(inlineViewJoin(left, r.left).getOrThrow(), r.right.getOrThrow()))
    }
    return Some(InlineViewBranch(l, r))
}

private func inlineViewBalance(left: InlineViewBranch, right: InlineViewBranch): InlineViewBranch {
    if (left.height > right.height + 1) {
        let ll = left.left.getOrThrow(); let lr = left.right.getOrThrow()
        if (ll.height >= lr.height) { return InlineViewBranch(ll, InlineViewBranch(lr, right)) }
        return InlineViewBranch(InlineViewBranch(ll, lr.left.getOrThrow()), InlineViewBranch(lr.right.getOrThrow(), right))
    }
    if (right.height > left.height + 1) {
        let rl = right.left.getOrThrow(); let rr = right.right.getOrThrow()
        if (rr.height >= rl.height) { return InlineViewBranch(InlineViewBranch(left, rl), rr) }
        return InlineViewBranch(InlineViewBranch(left, rl.left.getOrThrow()), InlineViewBranch(rl.right.getOrThrow(), rr))
    }
    return InlineViewBranch(left, right)
}

private func inlineViewBuild(parts: Array<InlineTextView>, start: Int64, end: Int64): ?InlineViewBranch {
    if (start == end) { return None }
    if (end - start == 1) { return Some(InlineViewBranch(parts[start])) }
    let middle = start + (end - start) / 2
    return Some(InlineViewBranch(inlineViewBuild(parts, start, middle).getOrThrow(),
        inlineViewBuild(parts, middle, end).getOrThrow()))
}

private func inlineViewSplitParts(branch: ?InlineViewBranch, at: Int64): (?InlineViewBranch, ?InlineViewBranch) {
    if (branch.isNone()) { return (None, None) }
    let node = branch.getOrThrow()
    if (at == 0) { return (None, branch) }; if (at == node.count) { return (branch, None) }
    let left = node.left.getOrThrow()
    if (at < left.count) {
        let (before, after) = inlineViewSplitParts(node.left, at)
        return (before, inlineViewJoin(after, node.right))
    }
    let (before, after) = inlineViewSplitParts(node.right, at - left.count)
    return (inlineViewJoin(node.left, before), after)
}

private func inlineViewSplitBytes(branch: ?InlineViewBranch, at: Int64): (?InlineViewBranch, ?InlineViewBranch) {
    if (branch.isNone()) { return (None, None) }
    let node = branch.getOrThrow()
    if (at == 0) { return (None, branch) }; if (at == node.bytes) { return (branch, None) }
    if (let Some(view) <- node.view) {
        return (Some(InlineViewBranch(InlineTextWindow(view, 0, at))),
            Some(InlineViewBranch(InlineTextWindow(view, at, view.byteLength))))
    }
    let left = node.left.getOrThrow()
    if (at < left.bytes) {
        let (before, after) = inlineViewSplitBytes(node.left, at)
        return (before, inlineViewJoin(after, node.right))
    }
    let (before, after) = inlineViewSplitBytes(node.right, at - left.bytes)
    return (inlineViewJoin(node.left, before), after)
}

private func inlineViewPart(branch: InlineViewBranch, index: Int64): InlineTextView {
    if (let Some(view) <- branch.view) { return view }
    let left = branch.left.getOrThrow()
    return if (index < left.count) { inlineViewPart(left, index) }
        else { inlineViewPart(branch.right.getOrThrow(), index - left.count) }
}

private func inlineViewByte(branch: InlineViewBranch, index: Int64): Byte {
    if (let Some(view) <- branch.view) { return view.readByte(index) }
    let left = branch.left.getOrThrow()
    return if (index < left.bytes) { inlineViewByte(left, index) }
        else { inlineViewByte(branch.right.getOrThrow(), index - left.bytes) }
}

private func inlineViewRunes(branch: InlineViewBranch, index: Int64): Int64 {
    if (let Some(view) <- branch.view) { return view.runeOffsetAtByte(index) }
    let left = branch.left.getOrThrow()
    return if (index <= left.bytes) { inlineViewRunes(left, index) }
        else { left.runes + inlineViewRunes(branch.right.getOrThrow(), index - left.bytes) }
}

private func inlineViewAnchor(branch: InlineViewBranch, index: Int64, affinity: AnchorAffinity): ?SourceAnchor {
    if (let Some(view) <- branch.view) { return view.mapByte(index, affinity) }
    let left = branch.left.getOrThrow()
    return if (index < left.bytes || (index == left.bytes && affinity == AnchorAffinity.Before)) {
        inlineViewAnchor(left, index, affinity)
    } else { inlineViewAnchor(branch.right.getOrThrow(), index - left.bytes, affinity) }
}

private func inlineViewSlice(branch: ?InlineViewBranch, start: Int64, end: Int64, output: StringBuilder): Unit {
    if (branch.isNone() || start == end) { return }
    let node = branch.getOrThrow()
    if (let Some(view) <- node.view) { output.append(view.sliceBytes(start, end)); return }
    let leftBytes = node.left.getOrThrow().bytes
    if (start < leftBytes) { inlineViewSlice(node.left, start, if (end < leftBytes) { end } else { leftBytes }, output) }
    if (end > leftBytes) { inlineViewSlice(node.right, if (start > leftBytes) { start - leftBytes } else { 0 }, end - leftBytes, output) }
}

// Persistent weighted parts: construction captures references once; changes
// path-copy the affected AVL paths and optional endpoint windows only.
public class MappedInlineTextView <: InlineTextView {
    private let root: ?InlineViewBranch
    public MappedInlineTextView(parts: Array<InlineTextView>, private let sourceIdentity: SourceVersionIdentity,
        private let mappingKey: String) {
        if (mappingKey.isEmpty()) { throw IllegalArgumentException("Mapped inline view requires mapping identity") }
        validateInlineParts(parts, sourceIdentity)
        this.root = inlineViewBuild(parts, 0, parts.size)
    }
    private init(root: ?InlineViewBranch, source: SourceVersionIdentity, mappingIdentity: String) {
        if (mappingIdentity.isEmpty()) { throw IllegalArgumentException("Mapped inline view requires mapping identity") }
        this.sourceIdentity = source; this.mappingKey = mappingIdentity; this.root = root
    }
    public prop source: SourceVersionIdentity { get() { return sourceIdentity } }
    public prop mappingIdentity: String { get() { return mappingKey } }
    public prop byteLength: Int64 { get() { return root.map({ node => node.bytes }) ?? 0 } }
    public prop partCount: Int64 { get() { return root.map({ node => node.count }) ?? 0 } }
    public func partAt(index: Int64): InlineTextView {
        if (index < 0 || index >= partCount) { throw IllegalArgumentException("Inline part index out of bounds") }
        return inlineViewPart(root.getOrThrow(), index)
    }
    public func readByte(index: Int64): Byte {
        if (index < 0 || index >= byteLength) { throw IllegalArgumentException("Inline byte index out of bounds") }
        return inlineViewByte(root.getOrThrow(), index)
    }
    public func sliceBytes(start: Int64, end: Int64): String {
        checkInlineRange(start, end, byteLength)
        runeOffsetAtByte(start); runeOffsetAtByte(end)
        let output = StringBuilder()
        inlineViewSlice(root, start, end, output)
        return output.toString()
    }
    public func runeOffsetAtByte(index: Int64): Int64 {
        checkInlineRange(index, index, byteLength)
        return if (let Some(node) <- root) { inlineViewRunes(node, index) } else { 0 }
    }
    public func mapByte(index: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (index < 0 || index > byteLength) { return None }
        let anchor: ?SourceAnchor = if (let Some(node) <- root) { inlineViewAnchor(node, index, affinity) } else { None }
        if (let Some(raw) <- anchor) {
            if (raw.source.documentId != source.documentId || raw.source.version > source.version) {
                throw IllegalArgumentException("Foreign or future inline source anchor")
            }
        }
        return anchor
    }
    public func splicingParts(start: Int64, deleteCount: Int64, inserted: Array<InlineTextView>,
        target: SourceVersionIdentity, mappingIdentity: String): MappedInlineTextView {
        if (start < 0 || deleteCount < 0 || start > partCount || deleteCount > partCount - start) {
            throw IllegalArgumentException("Invalid inline part splice")
        }
        checkTarget(target)
        validateInlineParts(inserted, target)
        let (before, rest) = inlineViewSplitParts(root, start)
        let (_, after) = inlineViewSplitParts(rest, deleteCount)
        return MappedInlineTextView(inlineViewJoin(inlineViewJoin(before,
            inlineViewBuild(inserted, 0, inserted.size)), after), target, mappingIdentity)
    }
    public func replacePart(index: Int64, replacement: InlineTextView, target: SourceVersionIdentity,
        mappingIdentity: String): MappedInlineTextView {
        return splicingParts(index, 1, [replacement], target, mappingIdentity)
    }
    public func spliceBytes(start: Int64, end: Int64, inserted: Array<InlineTextView>,
        target: SourceVersionIdentity, mappingIdentity: String): MappedInlineTextView {
        checkInlineRange(start, end, byteLength)
        checkTarget(target)
        validateInlineParts(inserted, target)
        runeOffsetAtByte(start); runeOffsetAtByte(end)
        let (before, rest) = inlineViewSplitBytes(root, start)
        let (_, after) = inlineViewSplitBytes(rest, end - start)
        return MappedInlineTextView(inlineViewJoin(inlineViewJoin(before,
            inlineViewBuild(inserted, 0, inserted.size)), after), target, mappingIdentity)
    }
    private func checkTarget(target: SourceVersionIdentity): Unit {
        if (target.documentId != source.documentId || target.version < source.version) {
            throw IllegalArgumentException("Invalid mapped inline target identity")
        }
    }
}

// A selected edit/render window over Task04's bounded logical Text payload.
// Local operations preserve one logical legacy Text; explicit legacy export
// alone materializes that whole logical node.
public class PersistentInlineLiteralWindow {
    public PersistentInlineLiteralWindow(private let payload: PersistentTextPayload,
        public let start: Int64, public let end: Int64) {
        checkInlineRange(start, end, payload.byteLength)
    }
    public func segments(): Array<PersistentTextSegment> { return payload.segments(start, end) }
    public func splice(inserted: String): PersistentTextPayload { return payload.splice(start, end, inserted) }
    public func sliceBytes(): String {
        let output = StringBuilder()
        for (segment in segments()) { output.append(segment.text) }
        return output.toString()
    }
    public func toLegacyNode(id: Int64, span: SourceSpan): TextNode { return payload.materializeNode(id, span) }
}
