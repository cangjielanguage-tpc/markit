package markit.core.session

import std.collection.{ArrayList, HashMap}
import markit.core.editing.SourceVersionIdentity

public interface PersistentCachePayload {
    func cloneCachePayload(): PersistentCachePayload
}

// Source storage owns the actual source objects. This document-scoped tracker
// calls its release hook exactly when the last current/snapshot/cache lease ends.
// The source implementation can reclaim its version registry at that point.
public class SourceVersionRetention {
    public let documentId: String
    private let counts = HashMap<Int64, Int64>()
    private let onRetain: (SourceVersionIdentity) -> Unit
    private let onRelease: (SourceVersionIdentity) -> Unit
    private var currentVersion: ?Int64 = None

    public init(documentId: String,
        onRetain!: (SourceVersionIdentity) -> Unit = { _: SourceVersionIdentity => },
        onRelease!: (SourceVersionIdentity) -> Unit = { _: SourceVersionIdentity => }) {
        if (documentId.isEmpty()) { throw IllegalArgumentException("Empty retention document") }
        this.documentId = documentId
        this.onRetain = onRetain
        this.onRelease = onRelease
    }

    public func retain(version: Int64): SourceVersionLease {
        if (version < 0) { throw IllegalArgumentException("Negative retained source version") }
        acquire(version)
        return SourceVersionLease(this, version)
    }

    public func setCurrent(version: Int64): Unit {
        if (version < 0) { throw IllegalArgumentException("Negative current source version") }
        if (let Some(previous) <- currentVersion) {
            if (previous == version) { return }
        }
        acquire(version)
        let previous = currentVersion
        try {
            if (let Some(old) <- previous) { release(old) }
        } catch (error: Exception) {
            release(version)
            throw error
        }
        currentVersion = Some(version)
    }

    public func clearCurrent(): Unit {
        let previous = currentVersion
        if (let Some(old) <- previous) { release(old) }
        currentVersion = None
    }

    public func retainCount(version: Int64): Int64 { return counts.get(version) ?? 0 }
    public func retainedVersionCount(): Int64 { return counts.size }

    private func acquire(version: Int64): Unit {
        let count = counts.get(version) ?? 0
        // Hooks validate/pin before any public count changes. A failed pin can
        // be retried without leaking a count or an apparently active lease.
        if (count == 0) { onRetain(SourceVersionIdentity(documentId, version)) }
        counts[version] = count + 1
    }

    internal func release(version: Int64): Unit {
        let count = counts.get(version) ?? 0
        if (count <= 0) { throw IllegalArgumentException("Unbalanced source version lease") }
        if (count == 1) {
            onRelease(SourceVersionIdentity(documentId, version))
            counts.remove(version)
        } else { counts[version] = count - 1 }
    }
}

public class SourceVersionLease {
    public let version: Int64
    private var retention: ?SourceVersionRetention
    internal init(retention: SourceVersionRetention, version: Int64) {
        this.retention = Some(retention)
        this.version = version
    }
    public prop released: Bool { get() { return retention.isNone() } }
    public func release(): Unit {
        if (let Some(owner) <- retention) { owner.release(version); retention = None }
    }
}

private class PersistentCacheEntry {
    public let payload: PersistentCachePayload
    public let cost: Int64
    public let source: SourceVersionLease
    public var stamp: Int64
    public var pinCount: Int64 = 0
    public init(payload: PersistentCachePayload, cost: Int64, source: SourceVersionLease, stamp: Int64) {
        this.payload = payload
        this.cost = cost
        this.source = source
        this.stamp = stamp
    }
}

// LRU is intentionally confined to optional derived cache entries. Eviction
// never removes raw syntax or a source version still leased by a live snapshot.
public class PersistentQuotaCache {
    private let entries = HashMap<String, PersistentCacheEntry>()
    private let retention: SourceVersionRetention
    private var quota: Int64
    private var used: Int64 = 0
    private var clock: Int64 = 0

    public init(retention: SourceVersionRetention, quota: Int64) {
        if (quota < 0) { throw IllegalArgumentException("Negative cache quota") }
        this.retention = retention
        this.quota = quota
    }

    public prop totalCost: Int64 { get() { return used } }
    public prop maximumCost: Int64 { get() { return quota } }
    public prop entryCount: Int64 { get() { return entries.size } }
    public prop overQuota: Bool { get() { return used > quota } }

    public func get(key: String): ?PersistentCachePayload {
        if (let Some(entry) <- entries.get(key)) {
            let result = entry.payload.cloneCachePayload()
            entry.stamp = tick()
            return Some(result)
        }
        return None
    }

    public func put(key: String, payload: PersistentCachePayload, cost: Int64, sourceVersion: Int64): Bool {
        if (key.isEmpty() || cost < 0 || sourceVersion < 0) { throw IllegalArgumentException("Invalid cache entry") }
        if (cost > quota) { return false }
        let old = entries.get(key)
        if (let Some(entry) <- old) { if (entry.pinCount > 0) { return false } }
        // Clone before changing the cache: a provider failure leaves it intact.
        let frozen = payload.cloneCachePayload()
        let oldCost = if (let Some(entry) <- old) { entry.cost } else { 0 }
        let victims = ArrayList<String>()
        var available: Int64 = quota - used + oldCost
        while (available < cost) {
            if (let Some(victim) <- oldestUnpinned(key, victims)) {
                victims.add(victim)
                available += entries.get(victim).getOrThrow().cost
            } else { return false }
        }
        // Retain first so replacing the sole cache lease of one source version
        // cannot release/reclaim that version in between the two entries.
        let lease = retention.retain(sourceVersion)
        for (victim in victims) { remove(victim) }
        remove(key)
        entries[key] = PersistentCacheEntry(frozen, cost, lease, tick())
        used += cost
        return true
    }

    public func pin(key: String): Bool {
        if (let Some(entry) <- entries.get(key)) { entry.pinCount += 1; return true }
        return false
    }

    public func unpin(key: String): Unit {
        if (let Some(entry) <- entries.get(key)) {
            if (entry.pinCount <= 0) { throw IllegalArgumentException("Unbalanced cache pin") }
            entry.pinCount -= 1
        } else { throw IllegalArgumentException("Missing pinned cache entry") }
        trim()
    }

    public func remove(key: String): Bool {
        if (let Some(entry) <- entries.get(key)) {
            if (entry.pinCount > 0) { return false }
            entries.remove(key)
            used -= entry.cost
            entry.source.release()
            return true
        }
        return false
    }

    public func setQuota(cost: Int64): Unit {
        if (cost < 0) { throw IllegalArgumentException("Negative cache quota") }
        quota = cost
        trim()
    }

    public func clear(): Unit {
        let keys = ArrayList<String>()
        for ((key, entry) in entries) { if (entry.pinCount == 0) { keys.add(key) } }
        for (key in keys) { remove(key) }
    }

    private func tick(): Int64 { clock += 1; return clock }
    private func trim(): Unit {
        while (used > quota) {
            if (let Some(key) <- oldestUnpinned("", ArrayList<String>())) { remove(key) } else { return }
        }
    }

    private func oldestUnpinned(excluding: String, selected: ArrayList<String>): ?String {
        var key: ?String = None
        var stamp: Int64 = 9223372036854775807
        for ((candidate, entry) in entries) {
            if (candidate != excluding && entry.pinCount == 0 && !selected.contains(candidate) && entry.stamp < stamp) {
                key = Some(candidate)
                stamp = entry.stamp
            }
        }
        return key
    }
}
