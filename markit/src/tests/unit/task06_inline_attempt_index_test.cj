package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.editing.*
import markit.core.inline.{InlineAttemptIndex, InlineAttemptRecord}
import markit.core.source.EditableRopeStore

private func attemptEvidence(owner: Int64, start: Int64, end: Int64,
    readStart: Int64, readEnd: Int64, version!: Int64 = 0, parser!: Int64 = 0,
    success!: Bool = true, nested!: Int64 = -1, dependsOnLength!: Bool = false,
    dependencies!: Array<IncrementalReadDependency> = []): InlineAttemptRecord {
    return InlineAttemptRecord(owner, parser, "test-facet:${parser}", "grammar-1", "raw-test",
        SourceVersionIdentity("attempts", version), start, end, readStart, readEnd, success,
        leftContext: "left:${owner}", rightContext: "right:${owner}", nestedOwner: nested,
        dependencies: dependencies, nodeId: if (success) { owner + 1000 } else { -1 }, dependsOnLength: dependsOnLength)
}

@Test
@Tag[InlineEditing, InlineReadDependencies]
class Task06InlineAttemptIndexTests {
    @TestCase
    func failedFarReadAndZeroWidthCloserInsertionWakeOutsideOpenerAndNewCandidates() {
        let missing = IncrementalReadDependency("test-facet:0", "missing-definition", false, 3)
        let failed = attemptEvidence(1, 2, 2, 1, 100, success: false, dependencies: [missing])
        let suffix = attemptEvidence(2, 120, 124, 119, 125)
        let initial = InlineAttemptIndex(SourceVersionIdentity("attempts", 0), "raw-test", records: [failed, suffix])
        let affected = initial.query(100, 100)
        @Expect(affected.size, 1)
        @Expect(affected[0].owner, 1)
        @Expect(affected[0].succeeded, false)
        @Expect(affected[0].nodeId, -1)
        @Expect(initial.readingKey("missing-definition")[0].dependencies[0].found, false)
        let success = attemptEvidence(1, 2, 101, 1, 101, version: 1, dependencies: [missing])
        let newCandidate = attemptEvidence(3, 100, 101, 100, 101, version: 1, parser: 1)
        let next = initial.splice(100, 100, 101, [success, newCandidate], SourceVersionIdentity("attempts", 1))
        @Expect(next.size, 3)
        @Expect(next.byOwner(1).getOrThrow().succeeded, true)
        @Expect(next.byOwner(1).getOrThrow().nodeId, 1001)
        @Expect(next.byOwner(2).getOrThrow().startByte, 121)
        @Expect(next.byOwner(2).getOrThrow().source.version, 0)
        @Expect(next.query(101, 101).size, 2)
        @Expect(initial.byOwner(1).getOrThrow().succeeded, false)
        @Expect(initial.byOwner(2).getOrThrow().startByte, 120)
        @Expect(initial.source.version, 0)
    }

    @TestCase
    func sameStartProvidersAndBothReadBoundariesRemainDistinctAndOrdered() {
        let a = attemptEvidence(20, 10, 12, 9, 14, parser: 2)
        let b = attemptEvidence(10, 10, 10, 9, 14, parser: 1, success: false)
        let c = attemptEvidence(11, 10, 11, 9, 14, parser: 1)
        let initial = InlineAttemptIndex(SourceVersionIdentity("attempts", 0), "raw-test", records: [a, c, b])
        let left = initial.query(9, 9)
        let right = initial.intersecting(14, 14)
        @Expect(left.size, 3)
        @Expect(right.size, 3)
        @Expect(left[0].owner, 10)
        @Expect(left[1].owner, 11)
        @Expect(left[2].owner, 20)
        @Expect(initial.query(8, 8).size, 0)
        @Expect(initial.query(15, 15).size, 0)
        let next = initial.splice(14, 14, 16, [], SourceVersionIdentity("attempts", 1))
        @Expect(next.size, 0)
        @Expect(initial.size, 3)
        @Expect(initial.byOwner(20).getOrThrow().parserIdentity, 2)
    }

    @TestCase
    func lazySuffixShiftKeepsCurrentOwnerSemanticAndNestedLocatorsAndDetachedEvidence() {
        let input = [IncrementalReadDependency("test-facet:0", "present", true, 7),
            IncrementalReadDependency("test-facet:0", "missing", false, 8)]
        let prefix = attemptEvidence(1, 1, 2, 1, 2)
        let suffix = attemptEvidence(2, 20, 22, 19, 23, nested: 50, dependencies: input)
        let lengthWitness = attemptEvidence(3, 40, 41, 40, 41, dependsOnLength: true,
            dependencies: [IncrementalReadDependency("test", "length-only", false, 0)])
        input[0] = IncrementalReadDependency("other", "corruption", false, 100)
        let exported = suffix.dependencies
        exported[1] = IncrementalReadDependency("other", "corruption", true, 100)
        let initial = InlineAttemptIndex(SourceVersionIdentity("attempts", 0), "raw-test", records: [prefix, suffix, lengthWitness])
        @Expect(initial.lengthReaders().size, 1)
        @Expect(initial.lengthReaders()[0].owner, 3)
        let next = initial.splice(10, 11, 14, [], SourceVersionIdentity("attempts", 1))
        let later = next.splice(8, 8, 10, [], SourceVersionIdentity("attempts", 2))
        @Expect(next.lengthReaders().size, 0)
        @Expect(next.byOwner(3).isNone(), true)
        @Expect(next.readingKey("length-only").size, 0)
        @Expect(refEq(later.byOwner(1).getOrThrow(), prefix), true)
        @Expect(later.byOwner(2).getOrThrow().startByte, 25)
        @Expect(later.byOwner(2).getOrThrow().readStart, 24)
        @Expect(later.byOwner(2).getOrThrow().leftContext, "left:2")
        @Expect(later.readingKey("present").size, 1)
        @Expect(later.readingKey("present")[0].startByte, 25)
        @Expect(later.readingKey("present")[0].dependencies[0].found, true)
        @Expect(later.readingKey("present")[0].dependencies[0].version, 7)
        @Expect(later.readingKey("missing")[0].dependencies[1].found, false)
        @Expect(later.readingKey("unread").size, 0)
        @Expect(later.readingKey("corruption").size, 0)
        @Expect(later.nestedAttempts(50)[0].owner, 2)
        @Expect(later.nestedAttempts(50)[0].endByte, 27)
        @Expect(next.byOwner(2).getOrThrow().startByte, 23)
        @Expect(initial.byOwner(2).getOrThrow().startByte, 20)
        @Expect(initial.byOwner(2).getOrThrow().readStart, 19)
        @Expect(initial.readingKey("missing")[0].source.version, 0)
        let semanticRetry = attemptEvidence(2, 25, 27, 24, 28, version: 2, nested: 50, dependsOnLength: true,
            dependencies: [IncrementalReadDependency("test-facet:0", "missing", true, 9)])
        let sameEpoch = later.replacingOwners([2], [semanticRetry])
        @Expect(sameEpoch.source.version, 2)
        @Expect(sameEpoch.byOwner(2).getOrThrow().startByte, 25)
        @Expect(sameEpoch.byOwner(2).getOrThrow().source.version, 2)
        @Expect(sameEpoch.lengthReaders().size, 1)
        @Expect(sameEpoch.lengthReaders()[0].owner, 2)
        @Expect(sameEpoch.readingKey("present").size, 0)
        @Expect(sameEpoch.readingKey("missing")[0].dependencies[0].found, true)
        @Expect(sameEpoch.readingKey("missing")[0].dependencies[0].version, 9)
        @Expect(refEq(sameEpoch.byOwner(1).getOrThrow(), prefix), true)
        @Expect(later.lengthReaders().size, 0)
        @Expect(later.readingKey("missing")[0].dependencies[1].found, false)
        let revoked = sameEpoch.replacingOwners([2], [])
        @Expect(revoked.lengthReaders().size, 0)
        @Expect(revoked.size, 1)
        @Expect(sameEpoch.size, 2)
        @Expect(initial.lengthReaders()[0].startByte, 40)
    }

    @TestCase
    func repeatedLocalBranchesKeepOldSnapshotsAndAllOwnerAndKeyLocators() {
        let records = ArrayList<InlineAttemptRecord>()
        for (i in 0..128) {
            records.add(attemptEvidence(i, i * 10 + 10, i * 10 + 11, i * 10 + 10, i * 10 + 11,
                nested: i % 3, dependencies: [IncrementalReadDependency("test", "key:${i % 3}", i % 2 == 0, i)]))
        }
        let original = InlineAttemptIndex(SourceVersionIdentity("attempts", 0), "raw-test", records: records.toArray())
        var current = original
        for (version in 1..61) {
            current = current.splice(2, 2, 3,
                [attemptEvidence(1000 + version, 2, 2, 2, 2, version: version, success: false)],
                SourceVersionIdentity("attempts", version))
        }
        @Expect(current.size, 129)
        @Expect(original.size, 128)
        @Expect(current.byOwner(1060).getOrThrow().startByte, 2)
        @Expect(current.byOwner(1059).isNone(), true)
        @Expect(current.byOwner(0).getOrThrow().startByte, 70)
        @Expect(current.byOwner(127).getOrThrow().startByte, 1340)
        @Expect(current.readingKey("key:1").size, 43)
        @Expect(current.nestedAttempts(2).size, 42)
        @Expect(original.byOwner(0).getOrThrow().startByte, 10)
        @Expect(original.byOwner(127).getOrThrow().startByte, 1280)
        let exported = current.records()
        @Expect(exported.size, 129)
        @Expect(exported[0].owner, 1060)
        for (i in 1..exported.size) { @Expect(exported[i].startByte >= exported[i - 1].startByte, true) }
    }

    @TestCase
    func rejectedVersionMappingAndDuplicateReplacementsLeaveOriginalIndexesUntouched() {
        let original = InlineAttemptIndex(SourceVersionIdentity("attempts", 0), "raw-test",
            records: [attemptEvidence(1, 10, 11, 9, 12,
                dependencies: [IncrementalReadDependency("test", "key", false, 0)])])
        var refused: Int64 = 0
        try { original.splice(1, 1, 2, [], SourceVersionIdentity("attempts", 0)) }
        catch (_: IllegalArgumentException) { refused += 1 }
        try { original.splice(1, 1, 2, [], SourceVersionIdentity("other", 1)) }
        catch (_: IllegalArgumentException) { refused += 1 }
        try { original.splice(1, 1, 2, [attemptEvidence(1, 2, 2, 2, 2, version: 1)], SourceVersionIdentity("attempts", 1)) }
        catch (_: IllegalArgumentException) { refused += 1 }
        try { original.splice(10, 10, 11, [attemptEvidence(2, 2, 2, 2, 2)], SourceVersionIdentity("attempts", 1)) }
        catch (_: IllegalArgumentException) { refused += 1 }
        let wrongMapping = InlineAttemptRecord(3, 0, "test", "grammar-1", "other-map",
            SourceVersionIdentity("attempts", 1), 2, 2, 2, 2, false)
        try { original.splice(1, 1, 2, [wrongMapping], SourceVersionIdentity("attempts", 1)) }
        catch (_: IllegalArgumentException) { refused += 1 }
        try { original.replacingOwners([1], [attemptEvidence(1, 10, 11, 9, 12, parser: 1)]) }
        catch (_: IllegalArgumentException) { refused += 1 }
        let semanticDuplicate = attemptEvidence(2, 2, 2, 2, 2)
        try { original.replacingOwners([1], [semanticDuplicate, semanticDuplicate]) }
        catch (_: IllegalArgumentException) { refused += 1 }
        let foreignRecord = InlineAttemptRecord(2, 0, "test", "grammar-1", "raw-test",
            SourceVersionIdentity("other", 0), 2, 2, 2, 2, false)
        try { original.replacingOwners([1], [foreignRecord]) }
        catch (_: IllegalArgumentException) { refused += 1 }
        @Expect(refused, 8)
        @Expect(original.size, 1)
        @Expect(original.byOwner(1).getOrThrow().startByte, 10)
        @Expect(original.readingKey("key")[0].dependencies[0].found, false)
        @Expect(original.query(12, 12)[0].owner, 1)
        @Expect(original.source.version, 0)
    }

    @TestCase
    func projectedByteOffsetsAgreeWithRealRopeUnicodeRuneEditsAndCrlfAnchors() {
        let store = EditableRopeStore("attempts", text: "α😀\r\nxyz")
        let first = store.snapshot
        let start = first.byteAtCoordinate(4, EditingCoordinate.UnicodeRune).getOrThrow()
        @Expect(start, 8)
        let original = InlineAttemptIndex(first.identity, "raw-test", records: [
            attemptEvidence(1, start, first.byteLength, start, first.byteLength)])
        let second = store.applyEdits(0, [EditingTextEdit(EditingRange(0, 0), "中")])
        let shifted = original.splice(0, 0, 3, [], second.identity)
        let currentStart = shifted.byOwner(1).getOrThrow().startByte
        @Expect(currentStart, store.resolve(SourceAnchor(first.identity, start), 1).getOrThrow())
        @Expect(currentStart, 11)
        @Expect(second.coordinateAtByte(currentStart).getOrThrow().runeOffset, 5)
        @Expect(second.coordinateAtByte(currentStart).getOrThrow().line, 1)
        let emojiStart = second.byteAtCoordinate(2, EditingCoordinate.UnicodeRune).getOrThrow()
        let emojiEnd = second.byteAtCoordinate(3, EditingCoordinate.UnicodeRune).getOrThrow()
        let third = store.applyEdits(1, [EditingTextEdit(EditingRange(2, 3, coordinate: EditingCoordinate.UnicodeRune), "z")])
        let latest = shifted.splice(emojiStart, emojiEnd, emojiStart + 1, [], third.identity)
        let projected = latest.byOwner(1).getOrThrow()
        @Expect(projected.startByte, 8)
        @Expect(projected.startByte, store.resolve(SourceAnchor(first.identity, start), 2).getOrThrow())
        @Expect(third.coordinateAtByte(projected.startByte).getOrThrow().runeOffset, 5)
        @Expect(third.coordinateAtByte(projected.startByte).getOrThrow().utf16Column, 0)
        @Expect(third.sliceBytes(projected.startByte, projected.endByte), "xyz")
        @Expect(projected.source.version, 0)
        @Expect(original.byOwner(1).getOrThrow().startByte, 8)
        @Expect(shifted.byOwner(1).getOrThrow().startByte, 11)
    }
}
