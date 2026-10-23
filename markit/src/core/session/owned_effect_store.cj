package markit.core.session

import std.collection.{ArrayList, HashMap}
import markit.core.editing.{OwnedEffectPayload, OwnedSemanticEffect, OwnedEffectTransaction}

// The token identifies a contribution, rather than its key. A losing candidate
// can change without invalidating readers of the winning candidate.
internal class EffectCandidate {
    public let effect: OwnedSemanticEffect
    public let token: Int64
    public EffectCandidate(effect: OwnedSemanticEffect, token: Int64) {
        this.effect = copyOwnedEffect(effect)
        this.token = token
    }
}

private func copyOwnedEffect(effect: OwnedSemanticEffect): OwnedSemanticEffect {
    return OwnedSemanticEffect(effect.ownerId, effect.key, effect.payload.cloneEffectPayload(), effect.order)
}

public struct OwnedEffectRead {
    public let key: String
    public let readerOwner: Int64
    public let found: Bool
    public let winnerToken: Int64
    public OwnedEffectRead(key: String, readerOwner: Int64, winnerToken: Int64) {
        this.key = key
        this.readerOwner = readerOwner
        this.found = winnerToken >= 0
        this.winnerToken = winnerToken
    }
}

// Persistent key index: an effect snapshot is a root pointer, not a copy of all
// semantic tables. Candidate lists are private and frozen before publication.
internal class EffectSnapshotIndex {
    let key: String
    let values: ArrayList<EffectCandidate>
    let left: ?EffectSnapshotIndex
    let right: ?EffectSnapshotIndex
    let height: Int64
    EffectSnapshotIndex(key: String, values: ArrayList<EffectCandidate>, left: ?EffectSnapshotIndex, right: ?EffectSnapshotIndex) {
        this.key = key; this.values = values; this.left = left; this.right = right
        let a = effectIndexHeight(left); let b = effectIndexHeight(right)
        this.height = 1 + if (a > b) { a } else { b }
    }
}
private func effectIndexHeight(root: ?EffectSnapshotIndex): Int64 {
    if (let Some(node) <- root) { return node.height }; return 0
}
private func effectIndexGet(root: ?EffectSnapshotIndex, key: String): ?ArrayList<EffectCandidate> {
    if (let Some(node) <- root) {
        if (key == node.key) { return Some(node.values) }
        return effectIndexGet(if (key < node.key) { node.left } else { node.right }, key)
    }; return None
}
private func effectIndexBalance(key: String, values: ArrayList<EffectCandidate>, left: ?EffectSnapshotIndex,
    right: ?EffectSnapshotIndex): EffectSnapshotIndex {
    if (effectIndexHeight(left) > effectIndexHeight(right) + 1) {
        let l = left.getOrThrow()
        if (effectIndexHeight(l.left) >= effectIndexHeight(l.right)) {
            return EffectSnapshotIndex(l.key, l.values, l.left, Some(EffectSnapshotIndex(key, values, l.right, right)))
        }
        let m = l.right.getOrThrow()
        return EffectSnapshotIndex(m.key, m.values, Some(EffectSnapshotIndex(l.key, l.values, l.left, m.left)),
            Some(EffectSnapshotIndex(key, values, m.right, right)))
    }
    if (effectIndexHeight(right) > effectIndexHeight(left) + 1) {
        let r = right.getOrThrow()
        if (effectIndexHeight(r.right) >= effectIndexHeight(r.left)) {
            return EffectSnapshotIndex(r.key, r.values, Some(EffectSnapshotIndex(key, values, left, r.left)), r.right)
        }
        let m = r.left.getOrThrow()
        return EffectSnapshotIndex(m.key, m.values, Some(EffectSnapshotIndex(key, values, left, m.left)),
            Some(EffectSnapshotIndex(r.key, r.values, m.right, r.right)))
    }
    return EffectSnapshotIndex(key, values, left, right)
}
private func effectIndexSet(root: ?EffectSnapshotIndex, key: String, values: ArrayList<EffectCandidate>): ?EffectSnapshotIndex {
    if (let Some(node) <- root) {
        if (key < node.key) { return Some(effectIndexBalance(node.key, node.values, effectIndexSet(node.left, key, values), node.right)) }
        if (key > node.key) { return Some(effectIndexBalance(node.key, node.values, node.left, effectIndexSet(node.right, key, values))) }
        return Some(EffectSnapshotIndex(key, values, node.left, node.right))
    }; return Some(EffectSnapshotIndex(key, values, Option<EffectSnapshotIndex>.None, Option<EffectSnapshotIndex>.None))
}
private func effectIndexRemove(root: ?EffectSnapshotIndex, key: String): ?EffectSnapshotIndex {
    if (root.isNone()) { return None }; let node = root.getOrThrow()
    if (key < node.key) { return Some(effectIndexBalance(node.key, node.values, effectIndexRemove(node.left, key), node.right)) }
    if (key > node.key) { return Some(effectIndexBalance(node.key, node.values, node.left, effectIndexRemove(node.right, key))) }
    if (node.left.isNone()) { return node.right }; if (node.right.isNone()) { return node.left }
    var next = node.right.getOrThrow()
    while (next.left.isSome()) { next = next.left.getOrThrow() }
    return Some(effectIndexBalance(next.key, next.values, node.left, effectIndexRemove(node.right, next.key)))
}

public class OwnedEffectSnapshot {
    public let version: Int64
    private let root: ?EffectSnapshotIndex
    internal OwnedEffectSnapshot(version: Int64, root: ?EffectSnapshotIndex) {
        this.version = version; this.root = root
    }
    public func winner(key: String): ?OwnedSemanticEffect {
        if (let Some(candidate) <- winningCandidate(effectIndexGet(root, key) ?? ArrayList<EffectCandidate>())) {
            return Some(copyOwnedEffect(candidate.effect))
        }
        return None
    }
}

public class PreparedOwnedEffects {
    public let snapshot: OwnedEffectSnapshot
    public let expectedVersion: Int64
    internal let owner: OwnedEffectStore
    internal let tokenBase: Int64
    internal let tokenEnd: Int64
    internal let changed: HashMap<String, ArrayList<EffectCandidate>>
    internal let revoked: HashMap<Int64, Bool>
    internal let observed: ArrayList<OwnedEffectRead>
    internal let refreshedReads: HashMap<Int64, Array<String>>
    internal let root: ?EffectSnapshotIndex
    internal var consumed: Bool = false
    private let invalidated: Array<Int64>
    private let invalidatedKeys: HashMap<Int64, Array<String>>
    internal PreparedOwnedEffects(owner: OwnedEffectStore, expectedVersion: Int64, tokenBase: Int64, tokenEnd: Int64,
        changed: HashMap<String, ArrayList<EffectCandidate>>, revoked: HashMap<Int64, Bool>,
        observed: ArrayList<OwnedEffectRead>, root: ?EffectSnapshotIndex, invalidated: Array<Int64>,
        invalidatedKeys: HashMap<Int64, Array<String>>, refreshedReads: HashMap<Int64, Array<String>>) {
        this.owner = owner; this.expectedVersion = expectedVersion; this.tokenBase = tokenBase; this.tokenEnd = tokenEnd
        this.changed = changed; this.revoked = revoked; this.observed = observed; this.root = root
        this.snapshot = OwnedEffectSnapshot(expectedVersion + 1, root)
        this.invalidated = invalidated.clone()
        this.invalidatedKeys = invalidatedKeys
        this.refreshedReads = refreshedReads
    }
    public func invalidatedOwners(): Array<Int64> { return invalidated.clone() }
    public func invalidatedKeysForOwner(owner: Int64): Array<String> { return (invalidatedKeys.get(owner) ?? []).clone() }
}

// Only this store owns live payloads. Public reads, snapshots and replay exports
// clone provider payloads, so a caller cannot mutate the committed contribution.
public class OwnedEffectStore {
    private let candidates = HashMap<String, ArrayList<EffectCandidate>>()
    private let ownerKeys = HashMap<Int64, ArrayList<String>>()
    private let readers = HashMap<String, HashMap<Int64, Int64>>()
    private let readerKeys = HashMap<Int64, HashMap<String, Bool>>()
    private let invalidated = HashMap<Int64, Bool>()
    private var generation: Int64 = 0
    private var nextToken: Int64 = 0
    private var snapshotRoot: ?EffectSnapshotIndex = None

    public prop version: Int64 { get() { return generation } }

    public func beginTransaction(): OwnedEffectsTransaction {
        return OwnedEffectsTransaction(this, generation, nextToken)
    }

    public func snapshot(): OwnedEffectSnapshot { return OwnedEffectSnapshot(generation, snapshotRoot) }

    public func winner(key: String): ?OwnedSemanticEffect {
        if (let Some(candidate) <- winningCandidate(values(key))) {
            return Some(copyOwnedEffect(candidate.effect))
        }
        return None
    }

    public func effectsForOwner(ownerId: Int64): Array<OwnedSemanticEffect> {
        let result = ArrayList<OwnedSemanticEffect>()
        if (let Some(keys) <- ownerKeys.get(ownerId)) {
            for (key in keys) {
                for (candidate in values(key)) {
                    if (candidate.effect.ownerId == ownerId) {
                        var at: Int64 = 0
                        while (at < result.size && result[at].order <= candidate.effect.order) { at += 1 }
                        result.add(copyOwnedEffect(candidate.effect), at: at)
                    }
                }
            }
        }
        return result.toArray()
    }

    public func readDependencies(ownerId: Int64): Array<OwnedEffectRead> {
        let result = ArrayList<OwnedEffectRead>()
        if (let Some(keys) <- readerKeys.get(ownerId)) {
            for ((key, _) in keys) {
                if (let Some(owners) <- readers.get(key)) {
                    if (let Some(token) <- owners.get(ownerId)) { result.add(OwnedEffectRead(key, ownerId, token)) }
                }
            }
        }
        return result.toArray()
    }

    public func takeInvalidatedOwners(): Array<Int64> {
        let result = ArrayList<Int64>()
        for ((owner, _) in invalidated) { result.add(owner) }
        invalidated.clear()
        return result.toArray()
    }

    internal func values(key: String): ArrayList<EffectCandidate> {
        return candidates.get(key) ?? ArrayList<EffectCandidate>()
    }

    internal func keysForOwner(owner: Int64): Array<String> {
        return (ownerKeys.get(owner) ?? ArrayList<String>()).toArray()
    }

    internal func prepare(expected: Int64, tokenBase: Int64, tokenEnd: Int64,
        changed: HashMap<String, ArrayList<EffectCandidate>>, revoked: HashMap<Int64, Bool>,
        observed: ArrayList<OwnedEffectRead>, refreshedReads: HashMap<Int64, Array<String>>): PreparedOwnedEffects {
        if (generation != expected || nextToken != tokenBase) { throw IllegalArgumentException("Stale owned effect preparation") }
        let frozen = HashMap<String, ArrayList<EffectCandidate>>()
        var root = snapshotRoot
        for ((key, values) in changed) {
            let detached = ArrayList<EffectCandidate>()
            for (candidate in values) { detached.add(EffectCandidate(candidate.effect, candidate.token)) }
            frozen[key] = detached
            root = if (detached.isEmpty()) { effectIndexRemove(root, key) } else { effectIndexSet(root, key, detached) }
        }
        let revokedCopy = HashMap<Int64, Bool>()
        for ((owner, value) in revoked) { revokedCopy[owner] = value }
        let observedCopy = ArrayList<OwnedEffectRead>()
        for (read in observed) { observedCopy.add(read) }
        let refreshedCopy = HashMap<Int64, Array<String>>()
        for ((owner, keys) in refreshedReads) { refreshedCopy[owner] = keys.clone() }
        // Provider clone code above can fail or reenter. Validate again before
        // returning a candidate; no live table/token has been changed.
        if (generation != expected || nextToken != tokenBase) { throw IllegalArgumentException("Stale owned effect preparation") }
        let invalidated = previewInvalidations(frozen, revokedCopy, observedCopy, refreshedCopy)
        let keys = HashMap<Int64, ArrayList<String>>()
        for (owner in invalidated) {
            if (revokedCopy.contains(owner) && !refreshedCopy.contains(owner)) { continue }
            for (read in readDependencies(owner)) {
                if (let Some(selected) <- refreshedCopy.get(owner)) { if (selected.contains(read.key)) { continue } }
                if (candidateToken(winningCandidate(effectIndexGet(root, read.key) ?? ArrayList<EffectCandidate>())) != read.winnerToken) {
                    let values = keys.get(owner) ?? ArrayList<String>()
                    if (!values.contains(read.key)) { values.add(read.key) }; keys[owner] = values
                }
            }
        }
        for (read in observedCopy) {
            if (candidateToken(winningCandidate(effectIndexGet(root, read.key) ?? ArrayList<EffectCandidate>())) != read.winnerToken) {
                let values = keys.get(read.readerOwner) ?? ArrayList<String>()
                if (!values.contains(read.key)) { values.add(read.key) }; keys[read.readerOwner] = values
            }
        }
        let exported = HashMap<Int64, Array<String>>()
        for ((owner, values) in keys) { exported[owner] = values.toArray() }
        return PreparedOwnedEffects(this, expected, tokenBase, tokenEnd, frozen, revokedCopy, observedCopy, root, invalidated, exported, refreshedCopy)
    }

    private func previewInvalidations(changed: HashMap<String, ArrayList<EffectCandidate>>,
        revoked: HashMap<Int64, Bool>, observed: ArrayList<OwnedEffectRead>,
        refreshedReads: HashMap<Int64, Array<String>>): Array<Int64> {
        let result = HashMap<Int64, Bool>()
        for ((owner, _) in invalidated) { if (!revoked.contains(owner)) { result[owner] = true } }
        for ((key, next) in changed) {
            let nextToken = candidateToken(winningCandidate(next))
            if (candidateToken(winningCandidate(values(key))) != nextToken) {
                if (let Some(owners) <- readers.get(key)) {
                    for ((owner, token) in owners) {
                        var retained = !revoked.contains(owner)
                        if (let Some(selected) <- refreshedReads.get(owner)) { retained = !selected.contains(key) }
                        if (retained && token != nextToken) { result[owner] = true }
                    }
                }
            }
        }
        for (read in observed) {
            let next = changed.get(read.key) ?? values(read.key)
            if (candidateToken(winningCandidate(next)) != read.winnerToken) { result[read.readerOwner] = true }
        }
        let output = ArrayList<Int64>()
        for ((owner, _) in result) { output.add(owner) }
        return output.toArray()
    }

    internal func validates(prepared: PreparedOwnedEffects): Bool {
        return refEq(prepared.owner, this) && !prepared.consumed && generation == prepared.expectedVersion && nextToken == prepared.tokenBase
    }

    // Call only after *all* stores validated within the engine's single-thread
    // publication gate. No provider cloning/callbacks or rejection remain here.
    internal func installPrepared(prepared: PreparedOwnedEffects): Unit {
        let changed = prepared.changed; let revoked = prepared.revoked; let observed = prepared.observed
        // Remove dependencies owned by replaced units before notifying consumers.
        for ((owner, _) in revoked) {
            if (let Some(keys) <- readerKeys.get(owner)) {
                let removed = ArrayList<String>()
                if (let Some(selected) <- prepared.refreshedReads.get(owner)) {
                    // The private reverse index permits key-local removal;
                    // unchanged reads never need to be enumerated or replayed.
                    for (key in selected) { removed.add(key) }
                } else { for ((key, _) in keys) { removed.add(key) } }
                for (key in removed) {
                    if (let Some(owners) <- readers.get(key)) {
                        owners.remove(owner)
                        if (owners.isEmpty()) { readers.remove(key) }
                    }
                    keys.remove(key)
                }
                if (keys.isEmpty()) { readerKeys.remove(owner) }
            }
        }
        for ((owner, _) in revoked) { invalidated.remove(owner) }
        for ((key, next) in changed) {
            let old = values(key)
            let oldToken = candidateToken(winningCandidate(old))
            let newToken = candidateToken(winningCandidate(next))
            if (oldToken != newToken) {
                if (let Some(owners) <- readers.get(key)) {
                    for ((owner, token) in owners) {
                        if (token != newToken) { invalidated[owner] = true }
                    }
                }
            }
            for (candidate in old) {
                if (let Some(keys) <- ownerKeys.get(candidate.effect.ownerId)) {
                    var index: Int64 = 0
                    while (index < keys.size) {
                        if (keys[index] == key) { keys.remove(at: index); break }
                        index += 1
                    }
                    if (keys.isEmpty()) { ownerKeys.remove(candidate.effect.ownerId) }
                }
            }
            if (next.isEmpty()) { candidates.remove(key) } else { candidates[key] = next }
            for (candidate in next) {
                let owner = candidate.effect.ownerId
                let keys = ownerKeys.get(owner) ?? ArrayList<String>()
                if (!keys.contains(key)) { keys.add(key) }
                ownerKeys[owner] = keys
            }
        }
        for (read in observed) {
            let token = candidateToken(winningCandidate(values(read.key)))
            if (token != read.winnerToken) { invalidated[read.readerOwner] = true }
            let owners = readers.get(read.key) ?? HashMap<Int64, Int64>()
            owners[read.readerOwner] = read.winnerToken
            readers[read.key] = owners
            let keys = readerKeys.get(read.readerOwner) ?? HashMap<String, Bool>()
            keys[read.key] = true
            readerKeys[read.readerOwner] = keys
        }
        nextToken = prepared.tokenEnd
        snapshotRoot = prepared.root
        generation = prepared.expectedVersion + 1
        prepared.consumed = true
    }
}

private func winningCandidate(values: ArrayList<EffectCandidate>): ?EffectCandidate {
    var winner: ?EffectCandidate = None
    for (candidate in values) {
        if (let Some(previous) <- winner) {
            if (candidate.effect.order < previous.effect.order ||
                (candidate.effect.order == previous.effect.order && candidate.effect.ownerId < previous.effect.ownerId) ||
                (candidate.effect.order == previous.effect.order && candidate.effect.ownerId == previous.effect.ownerId &&
                 candidate.token < previous.token)) { winner = Some(candidate) }
        } else { winner = Some(candidate) }
    }
    return winner
}

private func candidateToken(candidate: ?EffectCandidate): Int64 {
    if (let Some(value) <- candidate) { return value.token }
    return -1
}

internal class EffectScopeFrame {
    let token: Int64
    let changedBefore = HashMap<String, ?ArrayList<EffectCandidate>>()
    let revokedBefore = HashMap<Int64, Bool>()
    let undoReads = ArrayList<() -> Unit>()
    EffectScopeFrame(token: Int64) { this.token = token }
}
public class OwnedEffectsScope {
    private let transaction: OwnedEffectsTransaction
    private let frame: EffectScopeFrame
    private var active: Bool = true
    internal OwnedEffectsScope(transaction: OwnedEffectsTransaction, frame: EffectScopeFrame) { this.transaction = transaction; this.frame = frame }
    public func complete(commit: Bool): Unit {
        if (!active) { throw IllegalArgumentException("Closed owned effect scope") }
        transaction.completeScope(frame, commit)
        active = false
    }
}

public class OwnedEffectsTransaction <: OwnedEffectTransaction {
    private let store: OwnedEffectStore
    private let expected: Int64
    private let changed = HashMap<String, ArrayList<EffectCandidate>>()
    private let revoked = HashMap<Int64, Bool>()
    private let observed = ArrayList<OwnedEffectRead>()
    private let refreshedReads = HashMap<Int64, Array<String>>()
    private var active: Bool = true
    private let tokenBase: Int64
    private var nextLocalToken: Int64
    private var preparedCandidate: ?PreparedOwnedEffects = None
    private let scopes = ArrayList<EffectScopeFrame>()
    private var projectingOrder: Bool = false

    public OwnedEffectsTransaction(store: OwnedEffectStore, expected: Int64, tokenBase: Int64) {
        this.store = store
        this.expected = expected
        this.tokenBase = tokenBase; this.nextLocalToken = tokenBase
    }

    private func requireActive(): Unit {
        if (projectingOrder) { throw IllegalArgumentException("Cannot access an effect transaction from its order projection") }
        if (!active) { throw IllegalArgumentException("Closed owned effect transaction") }
        if (store.version != expected) { throw IllegalArgumentException("Stale owned effect transaction") }
    }
    private func requireMutable(): Unit {
        requireActive()
        preparedCandidate = None
    }
    public func beginScope(): OwnedEffectsScope {
        requireMutable()
        let frame = EffectScopeFrame(nextLocalToken)
        scopes.add(frame)
        return OwnedEffectsScope(this, frame)
    }
    internal func completeScope(frame: EffectScopeFrame, commit: Bool): Unit {
        requireActive()
        if (scopes.isEmpty() || !refEq(scopes[scopes.size - 1], frame)) { throw IllegalArgumentException("Owned effect scopes must close in reverse order") }
        scopes.remove(at: scopes.size - 1)
        preparedCandidate = None
        if (commit) {
            if (!scopes.isEmpty()) {
                let parent = scopes[scopes.size - 1]
                for ((key, before) in frame.changedBefore) { if (!parent.changedBefore.contains(key)) { parent.changedBefore[key] = before } }
                for ((owner, before) in frame.revokedBefore) { if (!parent.revokedBefore.contains(owner)) { parent.revokedBefore[owner] = before } }
                for (undo in frame.undoReads) { parent.undoReads.add(undo) }
            }
            frame.changedBefore.clear(); frame.revokedBefore.clear(); frame.undoReads.clear()
            return
        }
        var index = frame.undoReads.size
        while (index > 0) { index -= 1; frame.undoReads[index]() }
        for ((key, before) in frame.changedBefore) {
            if (let Some(values) <- before) { changed[key] = values } else { changed.remove(key) }
        }
        for ((owner, before) in frame.revokedBefore) { if (before) { revoked[owner] = true } else { revoked.remove(owner) } }
        nextLocalToken = frame.token
        frame.changedBefore.clear(); frame.revokedBefore.clear(); frame.undoReads.clear()
    }
    private func journalKey(key: String): Unit {
        if (scopes.isEmpty()) { return }
        let frame = scopes[scopes.size - 1]
        if (frame.changedBefore.contains(key)) { return }
        if (let Some(values) <- changed.get(key)) {
            let before = ArrayList<EffectCandidate>()
            for (candidate in values) { before.add(candidate) }
            frame.changedBefore[key] = Some(before)
        } else { frame.changedBefore[key] = Option<ArrayList<EffectCandidate>>.None }
    }

    private func editable(key: String): ArrayList<EffectCandidate> {
        if (let Some(values) <- changed.get(key)) { return values }
        let copy = ArrayList<EffectCandidate>()
        for (candidate in store.values(key)) { copy.add(candidate) }
        changed[key] = copy
        return copy
    }

    private func setReadRefresh(ownerId: Int64, selected: ?Array<String>): Unit {
        let previous = refreshedReads.get(ownerId)
        if (!scopes.isEmpty()) {
            scopes[scopes.size - 1].undoReads.add({ =>
                if (let Some(keys) <- previous) { refreshedReads[ownerId] = keys }
                else { refreshedReads.remove(ownerId) }
            })
        }
        if (let Some(keys) <- selected) { refreshedReads[ownerId] = keys.clone() }
        else { refreshedReads.remove(ownerId) }
    }
    public func revokeOwner(ownerId: Int64): Unit { revokeOwnerReads(ownerId, Option<Array<String>>.None) }
    // Explicit partial semantic replay: replace only the named dependencies,
    // preserving all unrelated reads, including this transaction's new reads.
    // Contributions still belong to the refreshed owner and are fully revoked.
    public func refreshOwner(ownerId: Int64, replacedReadKeys: Array<String>): Unit {
        for (key in replacedReadKeys) { if (key.isEmpty()) { throw IllegalArgumentException("Empty refreshed read key") } }
        revokeOwnerReads(ownerId, Some(replacedReadKeys))
    }
    private func revokeOwnerReads(ownerId: Int64, selected: ?Array<String>): Unit {
        requireMutable()
        if (ownerId < 0) { throw IllegalArgumentException("Negative effect owner") }
        if (let Some(keys) <- selected) {
            if (!revoked.contains(ownerId) || refreshedReads.contains(ownerId)) {
                let merged = ArrayList<String>()
                if (let Some(previous) <- refreshedReads.get(ownerId)) { for (key in previous) { merged.add(key) } }
                for (key in keys) { if (!merged.contains(key)) { merged.add(key) } }
                setReadRefresh(ownerId, Some(merged.toArray()))
            }
        } else { setReadRefresh(ownerId, Option<Array<String>>.None) }
        if (!scopes.isEmpty()) {
            let frame = scopes[scopes.size - 1]
            if (!frame.revokedBefore.contains(ownerId)) { frame.revokedBefore[ownerId] = revoked.contains(ownerId) }
        }
        revoked[ownerId] = true
        let keys = ArrayList<String>()
        for (key in store.keysForOwner(ownerId)) { keys.add(key) }
        for ((key, _) in changed) { if (!keys.contains(key)) { keys.add(key) } }
        for (key in keys) {
            journalKey(key)
            let values = editable(key)
            var index: Int64 = values.size
            while (index > 0) {
                index -= 1
                if (values[index].effect.ownerId == ownerId) { values.remove(at: index) }
            }
        }
        var index: Int64 = observed.size
        while (index > 0) {
            index -= 1
            if (observed[index].readerOwner == ownerId &&
                (selected.isNone() || selected.getOrThrow().contains(observed[index].key))) {
                let position = index; let previous = observed[index]
                if (!scopes.isEmpty()) { scopes[scopes.size - 1].undoReads.add({ => observed.add(previous, at: position) }) }
                observed.remove(at: index)
            }
        }
    }

    // Retire only the published generation's contributions/dependencies. Newly
    // parsed writes and observed reads of this transaction keep their owner.
    public func revokeOriginalOwner(ownerId: Int64): Unit {
        requireMutable()
        if (ownerId < 0) { throw IllegalArgumentException("Negative effect owner") }
        setReadRefresh(ownerId, Option<Array<String>>.None)
        if (!scopes.isEmpty()) {
            let frame = scopes[scopes.size - 1]
            if (!frame.revokedBefore.contains(ownerId)) { frame.revokedBefore[ownerId] = revoked.contains(ownerId) }
        }
        revoked[ownerId] = true
        let keys = ArrayList<String>()
        for (key in store.keysForOwner(ownerId)) { keys.add(key) }
        for ((key, _) in changed) { if (!keys.contains(key)) { keys.add(key) } }
        for (key in keys) {
            journalKey(key)
            let values = editable(key)
            var index = values.size
            while (index > 0) {
                index -= 1
                if (values[index].effect.ownerId == ownerId && values[index].token < tokenBase) { values.remove(at: index) }
            }
        }
    }

    public func add(effect: OwnedSemanticEffect): Unit {
        requireMutable()
        if (effect.ownerId < 0 || effect.key.isEmpty()) { throw IllegalArgumentException("Invalid effect ownership/key") }
        let candidate = EffectCandidate(effect, nextLocalToken)
        journalKey(effect.key)
        editable(effect.key).add(candidate)
        nextLocalToken += 1
    }

    // Rebase only an affected key's provider-defined order. Contribution
    // identity stays its token, so an unchanged winner does not invalidate
    // positive/negative readers. Published candidate lists remain immutable.
    public func reorderKey(key: String, order: (OwnedSemanticEffect) -> Int64): Unit {
        requireMutable()
        if (key.isEmpty()) { throw IllegalArgumentException("Empty ordered effect key") }
        let values = changed.get(key) ?? store.values(key)
        if (values.isEmpty()) { return }
        let replacement = ArrayList<EffectCandidate>()
        var differs = false
        projectingOrder = true
        try {
            for (candidate in values) {
                let projected = order(copyOwnedEffect(candidate.effect))
                if (projected != candidate.effect.order) { differs = true }
                replacement.add(EffectCandidate(OwnedSemanticEffect(candidate.effect.ownerId, key,
                    candidate.effect.payload, projected), candidate.token))
            }
        } finally { projectingOrder = false }
        requireMutable()
        if (!differs) { return }
        journalKey(key)
        changed[key] = replacement
    }

    public func replay(ownerId: Int64, effects: Array<OwnedSemanticEffect>): Unit {
        requireMutable()
        // Validate the complete replay before making even transaction-local changes.
        for (effect in effects) {
            if (effect.ownerId != ownerId || effect.key.isEmpty()) {
                throw IllegalArgumentException("Replay effect belongs to another owner")
            }
        }
        revokeOwner(ownerId)
        for (effect in effects) { add(effect) }
    }

    public func read(key: String, readerOwner: Int64): ?OwnedSemanticEffect {
        requireMutable()
        if (readerOwner < 0 || key.isEmpty()) { throw IllegalArgumentException("Invalid dependency ownership/key") }
        let values = changed.get(key) ?? store.values(key)
        let winner = winningCandidate(values)
        let position = observed.size
        if (!scopes.isEmpty()) { scopes[scopes.size - 1].undoReads.add({ => let ignored = observed.remove(at: position) }) }
        observed.add(OwnedEffectRead(key, readerOwner, candidateToken(winner)))
        if (let Some(candidate) <- winner) { return Some(copyOwnedEffect(candidate.effect)) }
        return None
    }

    public func commit(): Unit {
        let candidate = prepare()
        if (!validatePrepared(candidate)) { throw IllegalArgumentException("Stale owned effect transaction") }
        installPrepared(candidate)
    }

    public func prepare(): PreparedOwnedEffects {
        requireActive()
        if (!scopes.isEmpty()) { throw IllegalArgumentException("Open owned effect scope") }
        if (let Some(candidate) <- preparedCandidate) { return candidate }
        let candidate = store.prepare(expected, tokenBase, nextLocalToken, changed, revoked, observed, refreshedReads)
        preparedCandidate = Some(candidate)
        return candidate
    }
    public func validatePrepared(candidate: PreparedOwnedEffects): Bool {
        if (!active || preparedCandidate.isNone()) { return false }
        return refEq(preparedCandidate.getOrThrow(), candidate) && store.validates(candidate)
    }
    public func installPrepared(candidate: PreparedOwnedEffects): Unit {
        requireActive()
        store.installPrepared(candidate)
        active = false
        preparedCandidate = None
        changed.clear()
        observed.clear()
        revoked.clear()
        refreshedReads.clear()
        scopes.clear()
    }

    public func cancel(): Unit {
        if (projectingOrder) { throw IllegalArgumentException("Cannot cancel effects from an order projection") }
        active = false
        preparedCandidate = None
        changed.clear()
        observed.clear()
        revoked.clear()
        refreshedReads.clear()
        for (frame in scopes) { frame.changedBefore.clear(); frame.revokedBefore.clear(); frame.undoReads.clear() }
        scopes.clear()
    }
}
