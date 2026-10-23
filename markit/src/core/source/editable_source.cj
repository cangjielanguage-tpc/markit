package markit.core.source

import std.collection.{ArrayList, HashMap}
import markit.core.editing.*

public class EditableRopeVersion <: EditableSourceVersion {
    private let sourceIdentity: SourceVersionIdentity
    public prop identity: SourceVersionIdentity { get() { return sourceIdentity } }
    public prop byteLength: Int64 { get() { return root.bytes } }
    public prop runeLength: Int64 { get() { return root.runes } }
    public prop utf16Length: Int64 { get() { return root.utf16 } }
    public prop lineCount: Int64 { get() { return root.breaks + 1 } }
    public prop treeHeight: Int64 { get() { return root.height } }
    public static let leafByteLimit: Int64 = 1024

    public init(documentId: String, text: String, version!: Int64 = 0) {
        sourceIdentity = SourceVersionIdentity(documentId, version)
        root = ropeFromText(text)
    }

    internal EditableRopeVersion(identity: SourceVersionIdentity, internal let root: RopeNode) {
        sourceIdentity = identity
    }

    public func sliceBytes(start: Int64, end: Int64): String {
        if (end < start || !ropeBoundary(root, start) || !ropeBoundary(root, end)) {
            throw IllegalArgumentException("Invalid UTF-8 source slice")
        }
        let output = StringBuilder(); ropeSlice(root, start, end, output); return output.toString()
    }

    // Raw byte access also permits a UTF-8 continuation byte; parser cursors
    // decide scalar boundaries, while sliceBytes continues to validate them.
    public func readByte(byteOffset: Int64): Byte {
        if (byteOffset < 0 || byteOffset >= byteLength) { throw IllegalArgumentException("Invalid source byte offset") }
        return ropeByte(root, byteOffset)
    }

    public func coordinateAtByte(byteOffset: Int64): ?SourceCoordinate {
        if (!ropeBoundary(root, byteOffset)) { return None }
        let prefix = ropePrefix(root, byteOffset)
        let midpoint = byteOffset > 0 && byteOffset < byteLength &&
            ropeByte(root, byteOffset - 1) == 13 && ropeByte(root, byteOffset) == 10
        return Some(SourceCoordinate(byteOffset, prefix.runes, prefix.utf16,
            if (midpoint) { -1 } else { prefix.breaks }, if (midpoint) { -1 } else { prefix.tail16 }))
    }

    public func byteAtCoordinate(offset: Int64, coordinate: EditingCoordinate): ?Int64 {
        match (coordinate) {
            case EditingCoordinate.Utf8Byte => return if (ropeBoundary(root, offset)) { Some(offset) } else { None }
            case EditingCoordinate.UnicodeRune => return ropeOffset(root, offset, false)
            case EditingCoordinate.Utf16 => return ropeOffset(root, offset, true)
        }
    }

    private func lineStart(index: Int64): Int64 {
        return if (index == 0) { 0 } else { ropeBreakEnd(root, index) }
    }

    public func byteAtLineColumn(line: Int64, utf16Column: Int64): ?Int64 {
        if (line < 0 || line >= lineCount || utf16Column < 0) { return None }
        let start = lineStart(line)
        let units = ropePrefix(root, start).utf16
        if (let Some(offset) <- ropeOffset(root, units + utf16Column, true)) {
            if (let Some(position) <- coordinateAtByte(offset)) {
                if (position.line == line && position.utf16Column == utf16Column) { return Some(offset) }
            }
        }
        return None
    }

    public func lineAt(index: Int64): ?EditingSourceLine {
        if (index < 0 || index >= lineCount) { return None }
        let start = lineStart(index)
        let end = if (index + 1 < lineCount) { lineStart(index + 1) } else { byteLength }
        var contentEnd = end
        if (end > start && ropeByte(root, end - 1) == 10) {
            contentEnd -= 1
            if (contentEnd > start && ropeByte(root, contentEnd - 1) == 13) { contentEnd -= 1 }
        } else if (end > start && ropeByte(root, end - 1) == 13) { contentEnd -= 1 }
        return Some(EditingSourceLine(index, start, sliceBytes(start, contentEnd), sliceBytes(contentEnd, end)))
    }
}

internal class RopeEditDelta {
    RopeEditDelta(let start: Int64, let end: Int64, let inserted: Int64) {}
}

internal class RopeEditBatch {
    RopeEditBatch(let beforeLength: Int64, let afterLength: Int64, let edits: Array<RopeEditDelta>) {}
}

internal struct RopeAnchorKey <: Hashable & Equatable<RopeAnchorKey> {
    let version: Int64
    let offset: Int64
    let after: Bool
    RopeAnchorKey(anchor: SourceAnchor) {
        version = anchor.source.version; offset = anchor.byteOffset; after = anchor.affinity == AnchorAffinity.After
    }
    public func hashCode(): Int64 { return version ^ (offset << 1) ^ if (after) { 1 } else { 0 } }
    public operator func ==(other: RopeAnchorKey): Bool {
        return version == other.version && offset == other.offset && after == other.after
    }
}

internal class RopeAnchorProjection {
    RopeAnchorProjection(var version: Int64, var offset: Int64) {}
}

// Acknowledgement publishes the source immediately. Parsing owns no rollback hook.
// History retains small deltas, never historical rope roots; callers own snapshots.
// Callers that prune history must lease every live anchor birth epoch first.
public class EditableRopeStore <: EditableSourceStore {
    private var accepted: EditableRopeVersion
    private var history = HashMap<Int64, RopeEditBatch>()
    private var availableFrom: Int64
    private let retainedEpochs = HashMap<Int64, Int64>()
    private let projections = HashMap<RopeAnchorKey, RopeAnchorProjection>()
    private let projectionSlots = Array<?RopeAnchorKey>(2048, repeat: Option<RopeAnchorKey>.None)
    private var nextProjectionSlot: Int64 = 0
    private var replayedBatches: Int64 = 0
    public prop current: EditableSourceVersion { get() { return accepted } }
    public prop snapshot: EditableRopeVersion { get() { return accepted } }
    // Small concrete-store diagnostics for the targeted hot-path checks.
    public prop cachedAnchorCount: Int64 { get() { return projections.size } }
    public prop anchorReplayCount: Int64 { get() { return replayedBatches } }
    public prop oldestAvailableVersion: Int64 { get() { return availableFrom } }
    public prop retainedHistoryCount: Int64 { get() { return history.size } }
    public prop historyCapacity: Int64 { get() { return history.capacity } }
    public prop retainedVersionCount: Int64 { get() { return retainedEpochs.size } }

    public EditableRopeStore(documentId: String, text!: String = "", version!: Int64 = 0) {
        accepted = EditableRopeVersion(documentId, text, version: version); availableFrom = version
    }

    // An epoch lease pins the complete delta path from that epoch to current.
    // It does not duplicate a rope root: a snapshot holder already owns its root.
    public func retainVersion(version: Int64): EditableSourceLease {
        if (version < availableFrom || version > accepted.identity.version) {
            throw IllegalArgumentException("Source epoch is unavailable")
        }
        retainedEpochs[version] = (retainedEpochs.get(version) ?? 0) + 1
        return EditableSourceLease(this, version)
    }

    internal func releaseVersion(version: Int64): Unit {
        let count = retainedEpochs.get(version) ?? 0
        if (count <= 0) { throw IllegalArgumentException("Unbalanced source epoch lease") }
        if (count == 1) { retainedEpochs.remove(version) } else { retainedEpochs[version] = count - 1 }
    }

    // Only a released prefix is removed. No raw-node traversal/rebasing or
    // ArrayList prefix shift is needed; total removal work is amortized by edits.
    public func pruneHistory(): Int64 {
        let before = availableFrom
        while (availableFrom < accepted.identity.version && !retainedEpochs.contains(availableFrom)) {
            history.remove(availableFrom)
            availableFrom += 1
        }
        if (availableFrom != before) {
            // stdlib HashMap.remove drops values but keeps its backing arrays.
            // Compact only after losing at least three quarters of capacity;
            // this work is amortized by the released history, never every edit.
            if (history.capacity > 64 && history.size < history.capacity / 4) {
                let compact = HashMap<Int64, RopeEditBatch>(history.size)
                for ((version, batch) in history) { compact[version] = batch }
                history = compact
            }
            // The cache is fixed-size; discard projections whose birth was freed.
            for (slot in 0..projectionSlots.size) {
                if (let Some(key) <- projectionSlots[slot]) {
                    if (key.version < availableFrom) {
                        projections.remove(key)
                        projectionSlots[slot] = Option<RopeAnchorKey>.None
                    }
                }
            }
        }
        return availableFrom - before
    }

    public func applyEdits(expectedVersion: Int64, edits: Array<EditingTextEdit>): EditableSourceVersion {
        if (expectedVersion != accepted.identity.version) { throw IllegalArgumentException("Stale source version") }
        if (edits.isEmpty()) { return accepted }
        let converted = ArrayList<RopeEditDelta>()
        var previousEnd: Int64 = 0
        for (edit in edits) {
            let start = accepted.byteAtCoordinate(edit.range.start, edit.range.coordinate).getOrThrow()
            let end = accepted.byteAtCoordinate(edit.range.end, edit.range.coordinate).getOrThrow()
            if (start < previousEnd) { throw IllegalArgumentException("Edits must be ascending and non-overlapping") }
            converted.add(RopeEditDelta(start, end, edit.text.size)); previousEnd = end
        }
        // Validate the complete batch before publishing any root or version.
        var root = accepted.root
        var i = edits.size
        while (i > 0) {
            i -= 1
            let delta = converted[i]
            let (head, suffix) = ropeSplit(root, delta.end)
            let (prefix, _) = ropeSplit(head, delta.start)
            root = ropeJoin(ropeJoin(prefix, ropeFromText(edits[i].text)), suffix)
        }
        let next = EditableRopeVersion(SourceVersionIdentity(accepted.identity.documentId, expectedVersion + 1), root)
        history[expectedVersion] = RopeEditBatch(accepted.byteLength, next.byteLength, converted.toArray())
        accepted = next
        return next
    }

    public func resolve(anchor: SourceAnchor, targetVersion: Int64): ?Int64 {
        if (anchor.source.documentId != accepted.identity.documentId || anchor.source.version < availableFrom ||
            targetVersion < availableFrom || anchor.source.version > accepted.identity.version || targetVersion > accepted.identity.version) { return None }
        let length = if (anchor.source.version == accepted.identity.version) { accepted.byteLength }
            else { history.get(anchor.source.version).getOrThrow().beforeLength }
        if (anchor.byteOffset > length) { return None }
        // This store is document-scoped; identity was checked before this key.
        let key = RopeAnchorKey(anchor)
        var offset = anchor.byteOffset; var version = anchor.source.version
        if (let Some(cached) <- projections.get(key)) {
            // Never reverse a clamped projection: deleted positions lost information.
            if (cached.version <= targetVersion) { offset = cached.offset; version = cached.version }
        }
        while (version < targetVersion) {
            offset = translate(offset, anchor.affinity, history.get(version).getOrThrow().edits)
            version += 1; replayedBatches += 1
        }
        while (version > targetVersion) {
            version -= 1
            let inverse = ArrayList<RopeEditDelta>(); var shift: Int64 = 0
            for (edit in history.get(version).getOrThrow().edits) {
                inverse.add(RopeEditDelta(edit.start + shift, edit.start + shift + edit.inserted, edit.end - edit.start))
                shift += edit.inserted - (edit.end - edit.start)
            }
            offset = translate(offset, anchor.affinity, inverse.toArray())
            replayedBatches += 1
        }
        // Only forward projections belong in the incremental cache. A historical
        // query cannot replace a newer state or become a lossy intermediate base.
        if (targetVersion >= anchor.source.version) {
            if (let Some(cached) <- projections.get(key)) {
                if (targetVersion > cached.version) { cached.version = targetVersion; cached.offset = offset }
            } else {
                if (let Some(evicted) <- projectionSlots[nextProjectionSlot]) { projections.remove(evicted) }
                projectionSlots[nextProjectionSlot] = Some(key)
                nextProjectionSlot = (nextProjectionSlot + 1) % projectionSlots.size
                projections[key] = RopeAnchorProjection(targetVersion, offset)
            }
        }
        return Some(offset)
    }

    private func translate(offset: Int64, affinity: AnchorAffinity, edits: Array<RopeEditDelta>): Int64 {
        var shift: Int64 = 0
        for (edit in edits) {
            if (offset < edit.start) { break }
            if (edit.start == edit.end && offset == edit.start) {
                if (affinity == AnchorAffinity.Before) { return offset + shift }
                shift += edit.inserted; continue
            }
            if (offset < edit.end) { return edit.start + shift + if (affinity == AnchorAffinity.After) { edit.inserted } else { 0 } }
            shift += edit.inserted - (edit.end - edit.start)
        }
        return offset + shift
    }
}

public class EditableSourceLease {
    private var store: ?EditableRopeStore
    internal EditableSourceLease(store: EditableRopeStore, public let version: Int64) { this.store = Some(store) }
    public prop released: Bool { get() { return store.isNone() } }
    public func release(): Unit {
        if (let Some(owner) <- store) { owner.releaseVersion(version); store = None }
    }
}
