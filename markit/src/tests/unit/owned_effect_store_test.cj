package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.editing.{OwnedEffectPayload, OwnedSemanticEffect, SourceVersionIdentity}
import markit.core.session.{OwnedEffectStore, PersistentCachePayload, PersistentQuotaCache, SourceVersionRetention}

private class MutableOwnedPayload <: OwnedEffectPayload {
    public var value: String
    public init(value: String) { this.value = value }
    public func cloneEffectPayload(): OwnedEffectPayload { return MutableOwnedPayload(value) }
}

private class MutableCachePayload <: PersistentCachePayload {
    public var value: String
    public init(value: String) { this.value = value }
    public func cloneCachePayload(): PersistentCachePayload { return MutableCachePayload(value) }
}

private func ownedEffect(owner: Int64, key: String, value: String, order: Int64): OwnedSemanticEffect {
    return OwnedSemanticEffect(owner, key, MutableOwnedPayload(value), order)
}

private func effectValue(effect: OwnedSemanticEffect): String {
    return (effect.payload as MutableOwnedPayload).getOrThrow().value
}

@Test
@Tag[OwnerEffects]
class OwnedEffectStoreTests {
    @TestCase
    func winnerRetractionPreservesOtherOwnersAndOldSnapshot() {
        let store = OwnedEffectStore()
        let tx = store.beginTransaction()
        tx.add(ownedEffect(2, "key", "second", 20))
        tx.add(ownedEffect(1, "key", "first", 10))
        tx.commit()
        let snapshot = store.snapshot()
        @Expect(effectValue(store.winner("key").getOrThrow()), "first")
        let remove = store.beginTransaction()
        remove.revokeOwner(1)
        remove.commit()
        @Expect(effectValue(store.winner("key").getOrThrow()), "second")
        @Expect(effectValue(snapshot.winner("key").getOrThrow()), "first")
        @Expect(store.effectsForOwner(2).size, 1)
        @Expect(store.effectsForOwner(1).size, 0)
    }

    @TestCase
    func positiveAndMissingReadersInvalidateOnlyOnWinnerChange() {
        let store = OwnedEffectStore()
        let initial = store.beginTransaction()
        initial.add(ownedEffect(1, "key", "first", 1))
        initial.add(ownedEffect(2, "key", "second", 2))
        initial.read("key", 10)
        initial.read("missing", 11)
        initial.commit()
        @Expect(store.takeInvalidatedOwners().size, 0)
        let losing = store.beginTransaction()
        losing.revokeOwner(2)
        losing.commit()
        @Expect(store.takeInvalidatedOwners().size, 0)
        let firstDefinition = store.beginTransaction()
        firstDefinition.add(ownedEffect(3, "missing", "now present", 3))
        firstDefinition.commit()
        let missingReaders = store.takeInvalidatedOwners()
        @Expect(missingReaders.size, 1)
        @Expect(missingReaders[0], 11)
        let winnerRemoval = store.beginTransaction()
        winnerRemoval.revokeOwner(1)
        winnerRemoval.commit()
        let readers = store.takeInvalidatedOwners()
        @Expect(readers.size, 1)
        @Expect(readers[0], 10)
        @Expect(store.readDependencies(11)[0].found, false)
    }

    @TestCase
    func cancelledAndStaleTransactionsPublishNothing() {
        let store = OwnedEffectStore()
        let cancelled = store.beginTransaction()
        cancelled.add(ownedEffect(1, "key", "cancelled", 1))
        cancelled.read("missing", 10)
        cancelled.cancel()
        @Expect(store.winner("key").isNone(), true)
        @Expect(store.readDependencies(10).size, 0)
        @Expect(store.version, 0)
        let stale = store.beginTransaction()
        stale.add(ownedEffect(1, "key", "stale", 1))
        let accepted = store.beginTransaction()
        accepted.add(ownedEffect(2, "other", "accepted", 2))
        accepted.commit()
        var rejected = false
        try { stale.commit() } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(store.winner("key").isNone(), true)
        @Expect(effectValue(store.winner("other").getOrThrow()), "accepted")
        @Expect(store.version, 1)
    }

    @TestCase
    func payloadsAndReplayAreDetachedAndOrdered() {
        let store = OwnedEffectStore()
        let payload = MutableOwnedPayload("original")
        let tx = store.beginTransaction()
        tx.add(OwnedSemanticEffect(1, "late", payload, 20))
        tx.add(ownedEffect(1, "early", "earlier", 10))
        tx.commit()
        payload.value = "mutated"
        let exported = store.effectsForOwner(1)
        @Expect(exported[0].key, "early")
        @Expect(exported[1].key, "late")
        @Expect(effectValue(exported[1]), "original")
        let exportedPayload = (exported[1].payload as MutableOwnedPayload).getOrThrow()
        exportedPayload.value = "changed export"
        @Expect(effectValue(store.winner("late").getOrThrow()), "original")
        let replay = store.beginTransaction()
        replay.replay(1, [ownedEffect(1, "replayed", "restored", 30)])
        replay.commit()
        @Expect(store.winner("late").isNone(), true)
        @Expect(effectValue(store.winner("replayed").getOrThrow()), "restored")
        var rejected = false
        let invalid = store.beginTransaction()
        try { invalid.replay(1, [ownedEffect(2, "wrong", "wrong", 1)]) }
        catch (_: IllegalArgumentException) { rejected = true }
        invalid.cancel()
        @Expect(rejected, true)
        @Expect(effectValue(store.winner("replayed").getOrThrow()), "restored")
    }

    @TestCase
    func revokingReaderRemovesPositiveAndNegativeDependencies() {
        let store = OwnedEffectStore()
        let read = store.beginTransaction()
        read.read("key", 10)
        read.commit()
        let revoke = store.beginTransaction()
        revoke.revokeOwner(10)
        revoke.add(ownedEffect(1, "key", "value", 1))
        revoke.commit()
        @Expect(store.readDependencies(10).size, 0)
        @Expect(store.takeInvalidatedOwners().size, 0)
    }

    @TestCase
    func readBeforeLaterWriteInSameTransactionIsInvalidated() {
        let store = OwnedEffectStore()
        let tx = store.beginTransaction()
        tx.read("key", 10)
        tx.add(ownedEffect(1, "key", "value", 1))
        tx.commit()
        let invalidated = store.takeInvalidatedOwners()
        @Expect(invalidated.size, 1)
        @Expect(invalidated[0], 10)
    }
}

@Test
@Tag[OwnerEffects]
class PersistentQuotaCacheTests {
    @TestCase
    func quotaEvictsLruButRetainsCurrentAndSnapshotSources() {
        let released = ArrayList<Int64>()
        let retention = SourceVersionRetention("doc", onRelease: { source: SourceVersionIdentity => released.add(source.version) })
        retention.setCurrent(0)
        let snapshot = retention.retain(0)
        let cache = PersistentQuotaCache(retention, 4)
        @Expect(cache.put("old", MutableCachePayload("a"), 2, 0), true)
        retention.setCurrent(1)
        @Expect(cache.put("new", MutableCachePayload("b"), 2, 1), true)
        @Expect(cache.put("third", MutableCachePayload("c"), 2, 1), true)
        @Expect(cache.get("old").isNone(), true)
        @Expect(retention.retainCount(0), 1)
        @Expect(released.size, 0)
        snapshot.release()
        snapshot.release()
        @Expect(released.size, 1)
        @Expect(released[0], 0)
        cache.clear()
        @Expect(cache.totalCost, 0)
        @Expect(retention.retainCount(1), 1)
        retention.clearCurrent()
        @Expect(released.size, 2)
        @Expect(retention.retainedVersionCount(), 0)
    }

    @TestCase
    func pinnedQuotaAndOversizedEntriesHaveExplicitOutcomes() {
        let retention = SourceVersionRetention("doc")
        let cache = PersistentQuotaCache(retention, 4)
        @Expect(cache.put("pinned", MutableCachePayload("a"), 4, 0), true)
        @Expect(cache.pin("pinned"), true)
        @Expect(cache.put("blocked", MutableCachePayload("b"), 1, 1), false)
        @Expect(cache.put("large", MutableCachePayload("b"), 5, 1), false)
        @Expect(retention.retainCount(1), 0)
        cache.setQuota(1)
        @Expect(cache.overQuota, true)
        @Expect(cache.entryCount, 1)
        cache.unpin("pinned")
        @Expect(cache.totalCost, 0)
        @Expect(cache.overQuota, false)
        @Expect(retention.retainedVersionCount(), 0)
    }

    @TestCase
    func cacheClonesPayloadAndReplacementDoesNotReleaseLiveSource() {
        let released = ArrayList<Int64>()
        let retention = SourceVersionRetention("doc", onRelease: { source: SourceVersionIdentity => released.add(source.version) })
        let cache = PersistentQuotaCache(retention, 8)
        let payload = MutableCachePayload("original")
        @Expect(cache.put("key", payload, 2, 0), true)
        payload.value = "mutated"
        let exported = (cache.get("key").getOrThrow() as MutableCachePayload).getOrThrow()
        @Expect(exported.value, "original")
        exported.value = "changed export"
        @Expect((cache.get("key").getOrThrow() as MutableCachePayload).getOrThrow().value, "original")
        @Expect(cache.put("key", MutableCachePayload("replacement"), 3, 0), true)
        @Expect(released.size, 0)
        @Expect(cache.totalCost, 3)
        @Expect(retention.retainCount(0), 1)
        cache.remove("key")
        @Expect(released.size, 1)
    }
}
