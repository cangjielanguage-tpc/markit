package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.core.inline.*
import markit.core.editing.*
import markit.core.source.{EditableRopeStore, EditableRopeVersion, SourceSpan}
import markit.core.nodes.{PersistentTextPayload, TextNode}

private class GuardInlineWindow <: InlineTextView {
    public var byteReads: Int64 = 0
    public var slices: Int64 = 0
    public var largestSlice: Int64 = 0
    public GuardInlineWindow(private let view: InlineTextView) {}
    public prop source: SourceVersionIdentity { get() { return view.source } }
    public prop mappingIdentity: String { get() { return view.mappingIdentity } }
    public prop byteLength: Int64 { get() { return view.byteLength } }
    public func readByte(index: Int64): Byte { byteReads += 1; return view.readByte(index) }
    public func sliceBytes(start: Int64, end: Int64): String {
        if (end - start > 32) { throw IllegalArgumentException("Whole inline text export forbidden by test") }
        slices += 1
        if (end - start > largestSlice) { largestSlice = end - start }
        return view.sliceBytes(start, end)
    }
    public func runeOffsetAtByte(index: Int64): Int64 { return view.runeOffsetAtByte(index) }
    public func mapByte(index: Int64, affinity: AnchorAffinity): ?SourceAnchor { return view.mapByte(index, affinity) }
}

private class WrongAnchorInlineView <: InlineTextView {
    public WrongAnchorInlineView(private let view: InlineTextView, private let rawSource: SourceVersionIdentity) {}
    public prop source: SourceVersionIdentity { get() { return view.source } }
    public prop mappingIdentity: String { get() { return "wrong-anchor-witness" } }
    public prop byteLength: Int64 { get() { return view.byteLength } }
    public func readByte(index: Int64): Byte { return view.readByte(index) }
    public func sliceBytes(start: Int64, end: Int64): String { return view.sliceBytes(start, end) }
    public func runeOffsetAtByte(index: Int64): Int64 { return view.runeOffsetAtByte(index) }
    public func mapByte(index: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        return Some(SourceAnchor(rawSource, index, affinity: affinity))
    }
}

@Test
@Tag[InlineEditing, InlineTextViews]
class Task06InlineViewTests {
    @TestCase
    func ropeWindowsReadRawUnicodeBytesAndKeepTheirImmutableVersion() {
        let store = EditableRopeStore("rope-window", text: "x\u{4E2D}\u{1F600}\r\ny")
        let old = store.snapshot
        let view = RopeInlineTextView(old, 1, 10)
        @Expect(view.byteLength, 9)
        @Expect(view.readByte(0), 228)
        @Expect(view.readByte(1), 184)
        @Expect(view.readByte(3), 240)
        @Expect(view.runeOffsetAtByte(3), 1)
        @Expect(view.runeOffsetAtByte(7), 2)
        @Expect(view.runeOffsetAtByte(8), 3)
        @Expect(view.runeOffsetAtByte(9), 4)
        @Expect(view.sliceBytes(0, 7), "\u{4E2D}\u{1F600}")
        @Expect(view.mapByte(3, AnchorAffinity.After).getOrThrow().byteOffset, 4)
        var rejected = false
        try { view.runeOffsetAtByte(1) } catch (_: Exception) { rejected = true }
        @Expect(rejected, true)
        store.applyEdits(0, [EditingTextEdit(EditingRange(1, 4), "Z")])
        @Expect(view.source.version, 0)
        @Expect(view.sliceBytes(0, 3), "\u{4E2D}")
        @Expect(store.current.sliceBytes(0, 2), "xZ")
        let window = InlineTextWindow(InlineTextWindow(view, 0, 7), 3, 7)
        @Expect(window.sliceBytes(0, 4), "\u{1F600}")
        @Expect(window.runeOffsetAtByte(4), 1)
        @Expect(window.mapByte(0, AnchorAffinity.Before).getOrThrow().byteOffset, 4)
        @Expect(view.mapByte(10, AnchorAffinity.After).isNone(), true)
    }

    @TestCase
    func largeMappedByteSpliceReadsOnlyAnExplicitSmallWindowAndPreservesOldBirths() {
        let text = String.fromUtf8(Array<Byte>(2 * 1024 * 1024, repeat: 97))
        let store = EditableRopeStore("large-view", text: text)
        let original = store.snapshot
        let guard = GuardInlineWindow(RopeInlineTextView(original, 0, original.byteLength))
        let before = MappedInlineTextView([guard], original.identity, "layout-v0")
        let middle: Int64 = 1024 * 1024
        @Expect(before.readByte(middle), 97)
        @Expect(guard.byteReads, 1)
        @Expect(guard.slices, 0)
        store.applyEdits(0, [EditingTextEdit(EditingRange(middle, middle + 1), "XY")])
        let inserted = RopeInlineTextView(store.current, middle, middle + 2)
        let after = before.spliceBytes(middle, middle + 1, [inserted], store.current.identity, "layout-v1")
        @Expect(after.byteLength, before.byteLength + 1)
        @Expect(after.partCount, 3)
        @Expect(guard.slices, 0)
        @Expect(after.sliceBytes(middle - 2, middle + 4), "aaXYaa")
        @Expect(after.sliceBytes(middle - 2, middle + 4), store.current.sliceBytes(middle - 2, middle + 4))
        @Expect(guard.largestSlice <= 2, true)
        let left = after.mapByte(middle - 1, AnchorAffinity.After).getOrThrow()
        @Expect(left.source.version, 0)
        let beforeJoin = after.mapByte(middle + 2, AnchorAffinity.Before).getOrThrow()
        let afterJoin = after.mapByte(middle + 2, AnchorAffinity.After).getOrThrow()
        @Expect(beforeJoin.source.version, 1)
        @Expect(afterJoin.source.version, 0)
        @Expect(store.resolve(afterJoin, 1).getOrThrow(), middle + 2)
        @Expect(before.sliceBytes(middle - 1, middle + 2), "aaa")
        @Expect(before.byteLength, text.size)
    }

    @TestCase
    func weightedSegmentsPreserveUnicodeCrLfAndRejectPartialScalars() {
        let source = EditableRopeVersion("segments", "\u{4E2D}\u{1F600}\r\nX")
        let chinese = RopeInlineTextView(source, 0, 3)
        let emoji = RopeInlineTextView(source, 3, 7)
        let parts: Array<InlineTextView> = [chinese, emoji, RopeInlineTextView(source, 7, 8), RopeInlineTextView(source, 8, 10)]
        let view = MappedInlineTextView(parts, source.identity, "segmented")
        parts[1] = chinese
        @Expect(refEq((view.partAt(1) as Object).getOrThrow(), emoji), true)
        @Expect(view.byteLength, 10)
        @Expect(view.readByte(7), 13)
        @Expect(view.readByte(8), 10)
        @Expect(view.runeOffsetAtByte(3), 1)
        @Expect(view.runeOffsetAtByte(7), 2)
        @Expect(view.runeOffsetAtByte(8), 3)
        @Expect(view.runeOffsetAtByte(9), 4)
        @Expect(view.runeOffsetAtByte(10), 5)
        @Expect(view.sliceBytes(0, 10), "\u{4E2D}\u{1F600}\r\nX")
        var rejected = false
        try { view.spliceBytes(4, 7, [], source.identity, "invalid") } catch (_: Exception) { rejected = true }
        @Expect(rejected, true)
        @Expect(view.partCount, 4)
        @Expect(view.mapByte(3, AnchorAffinity.Before).getOrThrow().byteOffset, 3)
        @Expect(view.mapByte(3, AnchorAffinity.After).getOrThrow().byteOffset, 3)
        let empty = MappedInlineTextView([], source.identity, "empty")
        @Expect(empty.byteLength, 0)
        @Expect(empty.runeOffsetAtByte(0), 0)
        @Expect(empty.sliceBytes(0, 0), "")
        @Expect(empty.mapByte(0, AnchorAffinity.After).isNone(), true)
    }

    @TestCase
    func syntheticPartsKeepUnknownMappingAndAffinityChoosesTheCorrectBoundary() {
        let source = EditableRopeVersion("mapped-gap", "a---b")
        let synthetic = EditableRopeVersion("temporary-synthetic-bytes", "xy")
        let inserted = UnmappedInlineTextView(source.identity, RopeInlineTextView(synthetic, 0, 2), "synthetic")
        let view = MappedInlineTextView(
            [RopeInlineTextView(source, 0, 1), inserted, RopeInlineTextView(source, 4, 5)], source.identity, "omitted-markers")
        @Expect(view.sliceBytes(0, 4), "axyb")
        @Expect(view.mapByte(1, AnchorAffinity.Before).getOrThrow().byteOffset, 1)
        @Expect(view.mapByte(1, AnchorAffinity.After).isNone(), true)
        @Expect(view.mapByte(2, AnchorAffinity.Before).isNone(), true)
        @Expect(view.mapByte(2, AnchorAffinity.After).isNone(), true)
        @Expect(view.mapByte(3, AnchorAffinity.Before).isNone(), true)
        @Expect(view.mapByte(3, AnchorAffinity.After).getOrThrow().byteOffset, 4)
    }

    @TestCase
    func partSplicesShareUnchangedPartsAndKeepOldSequencesReadable() {
        let source = EditableRopeVersion("parts", "ab")
        let a = RopeInlineTextView(source, 0, 1)
        let b = RopeInlineTextView(source, 1, 2)
        let parts = Array<InlineTextView>(1024, { _: Int64 => a })
        let old = MappedInlineTextView(parts, source.identity, "initial")
        var changed = old.replacePart(512, b, source.identity, "replace")
        @Expect(refEq((changed.partAt(0) as Object).getOrThrow(), (old.partAt(0) as Object).getOrThrow()), true)
        @Expect(refEq((changed.partAt(1023) as Object).getOrThrow(), (old.partAt(1023) as Object).getOrThrow()), true)
        @Expect(changed.sliceBytes(510, 515), "aabaa")
        var reference = String.fromUtf8(Array<Byte>(1024, repeat: 97))
        reference = reference[0..512] + "b" + reference[513..reference.size]
        for (step in 0..40) {
            let at = (step * 71) % changed.partCount
            changed = changed.splicingParts(at, 1, [b, a], source.identity, "layout:${step}")
            reference = reference[0..at] + "ba" + reference[at + 1..reference.size]
            @Expect(changed.sliceBytes(at, at + 2), "ba")
        }
        @Expect(changed.byteLength, 1064)
        @Expect(changed.sliceBytes(0, changed.byteLength), reference)
        @Expect(old.byteLength, 1024)
        @Expect(old.sliceBytes(510, 515), "aaaaa")
    }

    @TestCase
    func foreignFuturePartsAndReturnedAnchorsRejectWithoutChangingOldRoots() {
        let source = EditableRopeVersion("identity", "ab")
        let a = RopeInlineTextView(source, 0, 1)
        let old = MappedInlineTextView([a], source.identity, "old")
        let foreignView = RopeInlineTextView(EditableRopeVersion("foreign", "x"), 0, 1)
        let future = RopeInlineTextView(EditableRopeVersion("identity", "x", version: 2), 0, 1)
        for (bad in [foreignView, future]) {
            var rejected = false
            try { MappedInlineTextView([bad], source.identity, "bad") } catch (_: IllegalArgumentException) { rejected = true }
            @Expect(rejected, true)
            rejected = false
            try { old.replacePart(0, bad, source.identity, "bad-splice") } catch (_: IllegalArgumentException) { rejected = true }
            @Expect(rejected, true)
        }
        for (badSource in [SourceVersionIdentity("foreign", 0), SourceVersionIdentity("identity", 2)]) {
            let dishonest = MappedInlineTextView([WrongAnchorInlineView(a, badSource)], source.identity, "bad-anchor")
            var rejected = false
            try { dishonest.mapByte(0, AnchorAffinity.After) } catch (_: IllegalArgumentException) { rejected = true }
            @Expect(rejected, true)
        }
        @Expect(old.sliceBytes(0, 1), "a")
        let retained = old.replacePart(0, a, SourceVersionIdentity("identity", 1), "new-target-old-birth")
        @Expect(retained.source.version, 1)
        @Expect(retained.mapByte(0, AnchorAffinity.After).getOrThrow().source.version, 0)
    }

    @TestCase
    func boundedLogicalTextSplicePreservesOneExplicitLegacyTextNode() {
        let text = String.fromUtf8(Array<Byte>(256 * 1024, repeat: 97))
        let original = TextNode(77, SourceSpan(0, text.size, 0, text.size), text)
        original.setString("unit", "one")
        let payload = PersistentTextPayload.fromNode(original)
        let at: Int64 = 128 * 1024
        let window = PersistentInlineLiteralWindow(payload, at, at + 1)
        @Expect(window.segments().size, 1)
        @Expect(window.sliceBytes(), "a")
        let changed = window.splice("\u{4E2D}")
        @Expect(changed.byteLength, payload.byteLength + 2)
        @Expect(PersistentInlineLiteralWindow(changed, at - 1, at + 4).sliceBytes(), "a\u{4E2D}a")
        @Expect(PersistentInlineLiteralWindow(payload, at - 1, at + 2).sliceBytes(), "aaa")
        let explicitLegacy = PersistentInlineLiteralWindow(changed, at, at + 3)
            .toLegacyNode(77, SourceSpan(0, changed.byteLength, 0, text.size))
        @Expect(explicitLegacy.name, "TextNode")
        @Expect(explicitLegacy.id, 77)
        @Expect(explicitLegacy.children.size, 0)
        @Expect(explicitLegacy.string("unit"), Some("one"))
        @Expect(explicitLegacy.content, text[0..at] + "\u{4E2D}" + text[at + 1..text.size])
        @Expect(explicitLegacy.literal, explicitLegacy.content)
        @Expect(original.content, text)
    }
}
