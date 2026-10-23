package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.core.editing.*
import markit.core.source.*
import markit.core.session.{EditableSourceLifecycle, PersistentCachePayload, PersistentQuotaCache, SourceVersionRetention}

private class RetentionTestCachePayload <: PersistentCachePayload {
    public func cloneCachePayload(): PersistentCachePayload { return RetentionTestCachePayload() }
}

private class RetentionReleaseSwitch {
    public var reject: Bool = true
}

// A focused witness for LineIndex.size: it must not request/copy a long last
// line just to decide whether the source ends in a line ending.
private class LineCountWitness <: EditableSourceVersion {
    private let source: EditableSourceVersion
    public var lineReads: Int64 = 0
    public init(source: EditableSourceVersion) { this.source = source }
    public prop identity: SourceVersionIdentity { get() { return source.identity } }
    public prop byteLength: Int64 { get() { return source.byteLength } }
    public prop runeLength: Int64 { get() { return source.runeLength } }
    public prop utf16Length: Int64 { get() { return source.utf16Length } }
    public prop lineCount: Int64 { get() { return source.lineCount } }
    public func sliceBytes(start: Int64, end: Int64): String { return source.sliceBytes(start, end) }
    public func coordinateAtByte(offset: Int64): ?SourceCoordinate { return source.coordinateAtByte(offset) }
    public func byteAtCoordinate(offset: Int64, coordinate: EditingCoordinate): ?Int64 {
        return source.byteAtCoordinate(offset, coordinate)
    }
    public func byteAtLineColumn(line: Int64, column: Int64): ?Int64 { return source.byteAtLineColumn(line, column) }
    public func lineAt(index: Int64): ?EditingSourceLine { lineReads += 1; return source.lineAt(index) }
}

@Test
@Tag[SourceRetention]
class Task05SourceRetentionTests {
    private func append(store: EditableRopeStore): Unit {
        store.applyEdits(store.current.identity.version,
            [EditingTextEdit(EditingRange(store.current.byteLength, store.current.byteLength), "x")])
    }

    @TestCase
    func rawBirthEpochProtectsColdAnchorsBeyondCurrentSnapshotVersion() {
        let store = EditableRopeStore("birth", text: "abcdef")
        let lifecycle = EditableSourceLifecycle(store)
        let rawBirth = lifecycle.retention.retain(0)
        let oldRoot = store.snapshot
        let cold = SourceAnchor(oldRoot.identity, 4)
        for (step in 0..128) {
            append(store)
            lifecycle.retention.setCurrent(step + 1)
            @Expect(lifecycle.pruneHistory(), 0)
        }
        @Expect(store.oldestAvailableVersion, 0)
        @Expect(store.retainedHistoryCount, 128)
        @Expect(store.resolve(cold, 128).getOrThrow(), 4)
        @Expect(oldRoot.sliceBytes(0, oldRoot.byteLength), "abcdef")
        rawBirth.release()
        rawBirth.release()
        @Expect(lifecycle.pruneHistory(), 128)
        @Expect(store.retainedHistoryCount, 0)
        @Expect(store.historyCapacity <= 64, true)
        @Expect(store.oldestAvailableVersion, 128)
        @Expect(store.resolve(cold, 128).isNone(), true)
        @Expect(store.resolve(SourceAnchor(store.current.identity, 4), 128).getOrThrow(), 4)
        // The independently held root still reads correctly; freeing the delta
        // path only removes the unleased cross-version mapping promise.
        @Expect(oldRoot.sliceBytes(0, oldRoot.byteLength), "abcdef")
    }

    @TestCase
    func transactionSnapshotAndCacheLeasesReleaseOnlyTheirOwnEpochs() {
        let store = EditableRopeStore("owners", text: "a")
        let lifecycle = EditableSourceLifecycle(store)
        let snapshot = lifecycle.retention.retain(0)
        append(store)
        lifecycle.retention.setCurrent(1)
        let transaction = lifecycle.retention.retain(1)
        let cache = PersistentQuotaCache(lifecycle.retention, 4)
        @Expect(cache.put("derived", RetentionTestCachePayload(), 1, 1), true)
        append(store)
        lifecycle.retention.setCurrent(2)
        @Expect(store.retainedVersionCount, 3)
        snapshot.release()
        @Expect(lifecycle.pruneHistory(), 1)
        @Expect(store.oldestAvailableVersion, 1)
        transaction.release()
        @Expect(lifecycle.pruneHistory(), 0)
        @Expect(lifecycle.retention.retainCount(1), 1)
        cache.remove("derived")
        @Expect(lifecycle.pruneHistory(), 1)
        @Expect(store.oldestAvailableVersion, 2)
        @Expect(store.retainedVersionCount, 1)
        lifecycle.retention.clearCurrent()
        @Expect(store.retainedVersionCount, 0)
    }

    @TestCase
    func prunedEpochCannotBeRepinnedOrLeakCacheCounts() {
        let store = EditableRopeStore("pruned", text: "a")
        let lifecycle = EditableSourceLifecycle(store)
        append(store)
        lifecycle.retention.setCurrent(1)
        lifecycle.pruneHistory()
        var rejected = false
        try { lifecycle.retention.retain(0) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(lifecycle.retention.retainCount(0), 0)
        let cache = PersistentQuotaCache(lifecycle.retention, 4)
        @Expect(cache.put("current", RetentionTestCachePayload(), 1, 1), true)
        rejected = false
        try { cache.put("old", RetentionTestCachePayload(), 1, 0) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(cache.entryCount, 1)
        @Expect(cache.get("current").isSome(), true)
        @Expect(lifecycle.retention.retainCount(0), 0)
    }

    @TestCase
    func failedReleaseHookKeepsLeaseActiveAndCountRetryable() {
        let releaseSwitch = RetentionReleaseSwitch()
        let retention = SourceVersionRetention("hook", onRelease: { _: SourceVersionIdentity =>
            if (releaseSwitch.reject) { throw IllegalArgumentException("injected release failure") }
        })
        let lease = retention.retain(0)
        var rejected = false
        try { lease.release() } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(lease.released, false)
        @Expect(retention.retainCount(0), 1)
        releaseSwitch.reject = false
        lease.release()
        @Expect(lease.released, true)
        @Expect(retention.retainCount(0), 0)
    }

    @TestCase
    func persistentLineIndexRestoresPastFutureAndIndependentBranches() {
        let index = LineIndex()
        index.enablePersistent()
        let empty = index.snapshot()
        for (i in 0..2048) { index.add(SourceLine("line", SourceSpan(i * 2, i * 2 + 1, i * 2, i * 2 + 1))) }
        let past = index.snapshot()
        for (i in 2048..4096) { index.add(SourceLine("future", SourceSpan(i * 2, i * 2 + 1, i * 2, i * 2 + 1))) }
        let future = index.snapshot()
        @Expect(index.lineAt(4095).text, "future")
        index.restore(past)
        @Expect(index.size, 2048)
        index.add(SourceLine("branch", SourceSpan(4096, 4097, 4096, 4097)))
        let branch = index.snapshot()
        index.restore(future)
        @Expect(index.size, 4096)
        @Expect(index.lineAt(2048).text, "future")
        @Expect(index.findByByteOffset(8190).getOrThrow().text, "future")
        index.restore(branch)
        @Expect(index.size, 2049)
        @Expect(index.lineAt(2048).text, "branch")
        @Expect(index.lines().size, 2049)
        index.restore(empty)
        @Expect(index.size, 0)
        @Expect(index.findByByteOffset(0).isNone(), true)
        index.restore(past)
        @Expect(index.lineAt(2047).span.startByte, 4094)
    }

    @TestCase
    func flatLineSnapshotsKeepPrefixesAcrossBranchesAndPromotion() {
        let index = LineIndex()
        index.add(SourceLine("first", SourceSpan(0, 1, 0, 1)))
        let prefix = index.snapshot()
        index.add(SourceLine("second", SourceSpan(2, 3, 2, 3)))
        let future = index.snapshot()
        index.restore(prefix)
        @Expect(index.size, 1)
        @Expect(index.lines().size, 1)
        @Expect(index.findByByteOffset(2).isNone(), true)
        index.add(SourceLine("branch", SourceSpan(4, 5, 4, 5)))
        let branch = index.snapshot()
        index.restore(future)
        @Expect(index.lineAt(1).text, "second")
        index.enablePersistent()
        let persistent = index.snapshot()
        index.add(SourceLine("third", SourceSpan(6, 7, 6, 7)))
        index.restore(branch)
        @Expect(index.lineAt(1).text, "branch")
        index.restore(persistent)
        @Expect(index.size, 2)
        @Expect(index.lineAt(1).text, "second")
    }

    @TestCase
    func sourceBufferViewsRopeBytesAndRebindsWithoutAppendCopy() {
        let store = EditableRopeStore("view", text: "A\u{00E9}\r\nB")
        let oldRoot = store.snapshot
        let buffer = SourceBuffer(editableSource: Some(store.current))
        @Expect(buffer.byteSize, 6)
        @Expect(buffer.stringSegmentCount(), 0)
        @Expect(buffer.byteSegmentCount(), 0)
        @Expect(buffer.byteAt(1), 195)
        @Expect(buffer.byteAt(2), 169)
        @Expect(buffer.slice(1, 3), "\u{00E9}")
        buffer.releaseRetainedSource()
        @Expect(buffer.slice(0, 1), "A")
        store.applyEdits(0, [EditingTextEdit(EditingRange(0, 1), "XYZ")])
        buffer.bindEditableSource(store.current)
        @Expect(buffer.byteSize, 8)
        @Expect(buffer.slice(0, 5), "XYZ\u{00E9}")
        @Expect(oldRoot.sliceBytes(0, 1), "A")
        var rejected = false
        try { buffer.append("bad") } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try { buffer.bindEditableSource(oldRoot) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(buffer.materialize(), "XYZ\u{00E9}\r\nB")
    }

    @TestCase
    func lineSourceViewRebindsWidthAndCrLfWithoutStaleCheckpointPrefixes() {
        let source = EditableRopeStore("line-view", text: "A\u{00E9}\r\nB\n")
        let oldRoot = source.snapshot
        let index = LineIndex()
        index.bindEditableSource(source.current)
        @Expect(index.isEditableView, true)
        @Expect(index.size, 2)
        @Expect(index.lineAt(0).text, "A\u{00E9}")
        @Expect(index.lineAt(0).span.endByte, 3)
        @Expect(index.lineAt(1).span.startByte, 5)
        @Expect(index.lineAt(1).span.startRune, 4)
        @Expect(index.lineAt(1).terminated, true)
        @Expect(index.findByByteOffset(2).getOrThrow().text, "A\u{00E9}")
        @Expect(index.findByByteOffset(4).isNone(), true)
        let before = index.snapshot()
        source.applyEdits(0, [EditingTextEdit(EditingRange(0, 1), "wide"), EditingTextEdit(EditingRange(3, 4), "")])
        index.bindEditableSource(source.current)
        @Expect(index.size, 2)
        @Expect(index.lineAt(0).text, "wide\u{00E9}")
        @Expect(index.lineAt(1).span.startByte, 7)
        @Expect(index.lineAt(1).span.startRune, 6)
        let after = index.snapshot()
        index.restore(before)
        @Expect(index.lineAt(0).text, "A\u{00E9}")
        @Expect(index.lineAt(1).span.startByte, 5)
        index.bindEditableSource(source.current)
        @Expect(index.lineAt(0).text, "wide\u{00E9}")
        index.restore(after)
        @Expect(index.lines().size, 2)
        @Expect(oldRoot.sliceBytes(0, oldRoot.byteLength), "A\u{00E9}\r\nB\n")
        var rejected = false
        try { index.add(SourceLine("bad", SourceSpan.empty())) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        let empty = LineIndex()
        empty.bindEditableSource(EditableRopeVersion("empty-lines", ""))
        @Expect(empty.size, 0)
        let endings = LineIndex()
        endings.bindEditableSource(EditableRopeVersion("endings", "\r\n\n"))
        @Expect(endings.size, 2)
        @Expect(endings.lineAt(0).text, "")
        @Expect(endings.lineAt(1).text, "")
        @Expect(endings.lineAt(1).terminated, true)
        let longLast = LineCountWitness(EditableRopeVersion("long-last",
            "prefix\n" + String.fromUtf8(Array<Byte>(65536, repeat: 97))))
        let lazy = LineIndex()
        lazy.bindEditableSource(longLast)
        for (_ in 0..5) {
            @Expect(lazy.size, 2)
            let saved = lazy.snapshot()
            @Expect(saved.size, 2)
            lazy.restore(saved)
        }
        @Expect(longLast.lineReads, 0)
        @Expect(lazy.lineAt(0).text, "prefix")
        @Expect(longLast.lineReads, 1)
    }
}
