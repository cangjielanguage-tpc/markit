package markit.tests.unit.source

import std.unittest.*
import std.unittest.testmacro.*
import markit.core.editing.*
import markit.core.source.*

@Test
class EditableSourceTests {
    private func edit(start: Int64, end: Int64, text: String): EditingTextEdit {
        return EditingTextEdit(EditingRange(start, end), text)
    }

    @TestCase
    func unicodeCoordinatesAndCrLfMidpoint() {
        let source = EditableRopeVersion("unicode", "中😀\r\nB")
        @Expect(source.byteLength, 10)
        @Expect(source.runeLength, 5)
        @Expect(source.utf16Length, 6)
        @Expect(source.lineCount, 2)
        @Expect(source.coordinateAtByte(1).isNone(), true)
        @Expect(source.byteAtCoordinate(2, EditingCoordinate.Utf16).isNone(), true)
        @Expect(source.byteAtCoordinate(3, EditingCoordinate.Utf16).getOrThrow(), 7)
        let midpoint = source.coordinateAtByte(8).getOrThrow()
        @Expect(midpoint.runeOffset, 3)
        @Expect(midpoint.utf16Offset, 4)
        @Expect(midpoint.line, -1)
        @Expect(midpoint.utf16Column, -1)
        @Expect(source.byteAtLineColumn(0, 3).getOrThrow(), 7)
        @Expect(source.byteAtLineColumn(0, 4).isNone(), true)
        @Expect(source.byteAtLineColumn(1, 0).getOrThrow(), 9)
        @Expect(source.lineAt(0).getOrThrow().content, "中😀")
        @Expect(source.lineAt(0).getOrThrow().lineEnding, "\r\n")
        @Expect(source.lineAt(1).getOrThrow().content, "B")
    }

    @TestCase
    func crossLeafCrLfSplitJoinAndPersistentSnapshots() {
        let prefix = String.fromUtf8(Array<Byte>(1023, repeat: 97))
        let store = EditableRopeStore("crlf", text: prefix + "\r\nB")
        let original = store.snapshot
        @Expect(original.lineCount, 2)
        @Expect(original.lineAt(1).getOrThrow().startByte, 1025)
        let noLF = store.applyEdits(0, [edit(1024, 1025, "")])
        @Expect(noLF.lineCount, 2)
        @Expect(noLF.lineAt(0).getOrThrow().lineEnding, "\r")
        @Expect(noLF.lineAt(1).getOrThrow().startByte, 1024)
        let joined = store.applyEdits(1, [edit(1024, 1024, "\n")])
        @Expect(joined.lineCount, 2)
        @Expect(joined.lineAt(0).getOrThrow().lineEnding, "\r\n")
        let noCR = store.applyEdits(2, [edit(1023, 1024, "")])
        @Expect(noCR.lineAt(0).getOrThrow().lineEnding, "\n")
        @Expect(original.sliceBytes(1023, 1026), "\r\nB")
        @Expect(noLF.sliceBytes(1023, 1025), "\rB")
        @Expect(store.snapshot.treeHeight < 8, true)
        let separated = EditableRopeStore("join", text: prefix + "\rX\nB")
        @Expect(separated.current.lineCount, 3)
        let paired = separated.applyEdits(0, [edit(1024, 1025, "")])
        @Expect(paired.lineCount, 2)
        @Expect(paired.lineAt(0).getOrThrow().lineEnding, "\r\n")
        let split = separated.applyEdits(1, [edit(1024, 1024, "X")])
        @Expect(split.lineCount, 3)
        @Expect(split.lineAt(1).getOrThrow().content, "X")
        @Expect(split.lineAt(1).getOrThrow().lineEnding, "\n")
    }

    @TestCase
    func batchUsesOriginalCoordinatesAndStableInsertionOrder() {
        let store = EditableRopeStore("batch", text: "abcdef")
        let old = store.snapshot
        let changed = store.applyEdits(0, [edit(1, 1, "X"), edit(1, 1, "Y"), edit(1, 3, "R"), edit(3, 3, "Z"), edit(5, 6, "!")])
        @Expect(changed.sliceBytes(0, changed.byteLength), "aXYRZde!")
        @Expect(old.sliceBytes(0, old.byteLength), "abcdef")
        @Expect(store.applyEdits(1, []).identity.version, 1)
        @Expect(store.resolve(SourceAnchor(old.identity, 1, affinity: AnchorAffinity.Before), 1).getOrThrow(), 1)
        @Expect(store.resolve(SourceAnchor(old.identity, 1, affinity: AnchorAffinity.After), 1).getOrThrow(), 4)
        @Expect(store.resolve(SourceAnchor(old.identity, 6), 1).getOrThrow(), 8)
        @Expect(store.resolve(SourceAnchor(changed.identity, 8), 0).getOrThrow(), 6)
        @Expect(store.resolve(SourceAnchor(SourceVersionIdentity("other", 0), 1), 1).isNone(), true)
    }

    @TestCase
    func invalidBatchRejectsAtomically() {
        let store = EditableRopeStore("atomic", text: "中😀\r\nB")
        var rejected = false
        try { store.applyEdits(0, [edit(0, 0, "ok"), edit(1, 3, "bad")]) } catch (_: Exception) { rejected = true }
        @Expect(rejected, true)
        @Expect(store.current.identity.version, 0)
        @Expect(store.current.sliceBytes(0, store.current.byteLength), "中😀\r\nB")
        rejected = false
        try { store.applyEdits(0, [EditingTextEdit(EditingRange(1, 2, coordinate: EditingCoordinate.Utf16), "bad")]) } catch (_: Exception) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try { store.applyEdits(0, [edit(7, 9, ""), edit(7, 7, "bad")]) } catch (_: Exception) { rejected = true }
        @Expect(rejected, true)
        store.applyEdits(0, [edit(7, 8, "")])
        rejected = false
        try { store.applyEdits(0, [edit(0, 0, "bad")]) } catch (_: Exception) { rejected = true }
        @Expect(rejected, true)
        @Expect(store.current.identity.version, 1)
        @Expect(store.current.sliceBytes(0, store.current.byteLength), "中😀\nB")
    }

    @TestCase
    func emptyTrailingNewlinesAndRawRuneEdits() {
        let empty = EditableRopeVersion("empty", "")
        @Expect(empty.lineCount, 1)
        @Expect(empty.lineAt(0).getOrThrow().content, "")
        @Expect(empty.byteAtLineColumn(0, 0).getOrThrow(), 0)
        let store = EditableRopeStore("lines", text: "\r\n\r\n\r\n")
        @Expect(store.current.lineCount, 4)
        @Expect(store.current.lineAt(3).getOrThrow().startByte, 6)
        store.applyEdits(0, [EditingTextEdit(EditingRange(1, 2, coordinate: EditingCoordinate.UnicodeRune), "")])
        @Expect(store.current.sliceBytes(0, store.current.byteLength), "\r\r\n\r\n")
        @Expect(store.current.lineCount, 4)
    }

    @TestCase
    func repeatedLocalEditsMatchFreshTextAndCoordinates() {
        let builder = StringBuilder()
        for (_ in 0..400) { builder.append("中😀a\r\nb\n") }
        var reference = builder.toString()
        let store = EditableRopeStore("reference", text: reference)
        let old = store.snapshot
        for (step in 0..120) {
            let current = store.current
            let rune = (step * 37) % current.runeLength
            let start = current.byteAtCoordinate(rune, EditingCoordinate.UnicodeRune).getOrThrow()
            let end = current.byteAtCoordinate(rune + 1, EditingCoordinate.UnicodeRune).getOrThrow()
            let insertion = if (step % 3 == 0) { "😀\r" } else if (step % 3 == 1) { "\n中" } else { "x" }
            reference = reference[0..start] + insertion + reference[end..reference.size]
            let edited = store.applyEdits(step, [edit(start, end, insertion)])
            let fresh = EditableRopeVersion("fresh", reference)
            @Expect(edited.sliceBytes(0, edited.byteLength), reference)
            @Expect(edited.runeLength, fresh.runeLength)
            @Expect(edited.utf16Length, fresh.utf16Length)
            @Expect(edited.lineCount, fresh.lineCount)
            for (i in 0..edited.lineCount) {
                let a = edited.lineAt(i).getOrThrow(); let b = fresh.lineAt(i).getOrThrow()
                @Expect(a.startByte, b.startByte)
                @Expect(a.content, b.content)
                @Expect(a.lineEnding, b.lineEnding)
            }
            for (r in [0, edited.runeLength / 2, edited.runeLength]) {
                let p = edited.byteAtCoordinate(r, EditingCoordinate.UnicodeRune).getOrThrow()
                let a = edited.coordinateAtByte(p).getOrThrow(); let b = fresh.coordinateAtByte(p).getOrThrow()
                @Expect(a.runeOffset, r); @Expect(a.utf16Offset, b.utf16Offset)
                @Expect(a.line, b.line); @Expect(a.utf16Column, b.utf16Column)
            }
        }
        @Expect(old.sliceBytes(0, old.byteLength), builder.toString())
        @Expect(store.snapshot.treeHeight < 20, true)
    }

    @TestCase
    func repeatedOldAnchorsReplayOnlyNewBatchWithBoundedCache() {
        let store = EditableRopeStore("cached", text: "abcdef")
        let origin = SourceAnchor(store.current.identity, 6)
        for (step in 0..200) {
            store.applyEdits(step, [edit(0, 0, "x")])
            let before = store.anchorReplayCount
            @Expect(store.resolve(origin, step + 1).getOrThrow(), step + 7)
            @Expect(store.anchorReplayCount - before, 1)
            @Expect(store.resolve(origin, step + 1).getOrThrow(), step + 7)
            @Expect(store.anchorReplayCount - before, 1)
        }
        let capacity = EditableRopeStore("capacity", text: String.fromUtf8(Array<Byte>(4096, repeat: 97)))
        for (offset in 0..2200) {
            @Expect(capacity.resolve(SourceAnchor(capacity.current.identity, offset), 0).getOrThrow(), offset)
        }
        @Expect(capacity.cachedAnchorCount, 2048)
        @Expect(capacity.resolve(SourceAnchor(SourceVersionIdentity("wrong", 0), 0), 0).isNone(), true)
        @Expect(capacity.cachedAnchorCount, 2048)
    }

    @TestCase
    func historicalQueriesReplayBirthInsteadOfReversingClampedCache() {
        let store = EditableRopeStore("clamp", text: "abcdef")
        let origin = store.current.identity
        let after = SourceAnchor(origin, 4, affinity: AnchorAffinity.After)
        let before = SourceAnchor(origin, 4, affinity: AnchorAffinity.Before)
        store.applyEdits(0, [edit(2, 5, "R")])
        store.applyEdits(1, [edit(0, 0, "XX")])
        @Expect(store.resolve(after, 2).getOrThrow(), 5)
        @Expect(store.resolve(before, 2).getOrThrow(), 4)
        @Expect(store.resolve(after, 0).getOrThrow(), 4)
        @Expect(store.resolve(after, 1).getOrThrow(), 3)
        let replay = store.anchorReplayCount
        @Expect(store.resolve(after, 2).getOrThrow(), 5)
        @Expect(store.anchorReplayCount, replay)
        store.applyEdits(2, [edit(0, 0, "Y")])
        @Expect(store.resolve(after, 3).getOrThrow(), 6)
        @Expect(store.anchorReplayCount - replay, 1)
        // A first query older than birth must never seed a forward cache.
        let later = SourceAnchor(store.current.identity, 5)
        @Expect(store.resolve(later, 0).getOrThrow(), 5)
        @Expect(store.resolve(later, 3).getOrThrow(), 5)
    }
}
