package markit.plugins.standard.block.heading

import std.collection.{ArrayList, HashMap}
import markit.core.editing.SourceAnchor
import markit.utils.{slug, HeadingSlugScope}

public class HeadingSemanticValue {
    public let contribution: HeadingContribution
    public let slugAllocation: HeadingSlugAllocation
    public let number: String
    public let visible: Bool
    public let hiddenAfter: Int64
    private let nextCounters: Array<Int64>
    public let fingerprint: String
    public prop countersAfter: Array<Int64> { get() { return nextCounters.clone() } }
    public HeadingSemanticValue(contribution: HeadingContribution, allocation: HeadingSlugAllocation,
        number: String, visible: Bool, hiddenAfter: Int64, counters: Array<Int64>) {
        this.contribution = contribution; this.slugAllocation = allocation; this.number = number
        this.visible = visible; this.hiddenAfter = hiddenAfter; this.nextCounters = counters.clone()
        let summary = StringBuilder()
        summary.append("${contribution.ownerId}:${contribution.order}:${contribution.text.hashCode()}:${contribution.level}:${contribution.closable}:")
        summary.append("${allocation.uniqueSlug.hashCode()}:${allocation.typstLabel.hashCode()}:${allocation.occurrence}:${number}:${visible}:${hiddenAfter};")
        if (let Some(anchor) <- contribution.anchor) { summary.append("${anchor.source.documentId}:${anchor.source.version}:${anchor.byteOffset};") }
        for (counter in counters) { summary.append("${counter};") }
        fingerprint = summary.toString()
    }
    public func sameContinuation(other: HeadingSemanticValue): Bool {
        if (hiddenAfter != other.hiddenAfter) { return false }
        for (i in 0..6) { if (nextCounters[i] != other.nextCounters[i]) { return false } }
        return true
    }
    public func applyTo(node: HeadingNode, includeNumberInHtml!: Bool = true): Unit {
        if (node.id != contribution.ownerId) { throw IllegalArgumentException("Heading projection owner mismatch") }
        node.slug = slugAllocation.uniqueSlug
        node.setString("baseSlug", slugAllocation.baseSlug)
        node.setInt("slugOccurrence", slugAllocation.occurrence)
        if (slugAllocation.typstLabel.isEmpty()) { node.removeString("typstLabel") }
        else { node.setString("typstLabel", slugAllocation.typstLabel) }
        if (number.isEmpty()) { node.removeString("number") }
        else { node.setString("number", number); node.setBool("numberInHtml", includeNumberInHtml) }
        if (let editing: EditingHeadingNode <- node) { editing.visible = visible }
    }
}

// Immutable AVL records are shared by snapshots; no body nodes enter this index.
private class HeadingIndexBranch {
    let value: HeadingSemanticValue
    let left: ?HeadingIndexBranch
    let right: ?HeadingIndexBranch
    let height: Int64
    let size: Int64
    let fingerprint: Int64
    HeadingIndexBranch(value: HeadingSemanticValue, left: ?HeadingIndexBranch, right: ?HeadingIndexBranch) {
        this.value = value; this.left = left; this.right = right
        let a = headingHeight(left); let b = headingHeight(right)
        this.height = 1 + if (a > b) { a } else { b }
        this.size = 1 + headingSize(left) + headingSize(right)
        let aHash = if (let Some(n) <- left) { n.fingerprint } else { 0 }
        let bHash = if (let Some(n) <- right) { n.fingerprint } else { 0 }
        this.fingerprint = "${aHash}:${value.fingerprint.hashCode()}:${bHash}".hashCode()
    }
}
private func headingHeight(root: ?HeadingIndexBranch): Int64 { return if (let Some(n) <- root) { n.height } else { 0 } }
private func headingSize(root: ?HeadingIndexBranch): Int64 { return if (let Some(n) <- root) { n.size } else { 0 } }
private func headingBalance(value: HeadingSemanticValue, left: ?HeadingIndexBranch, right: ?HeadingIndexBranch): HeadingIndexBranch {
    if (headingHeight(left) > headingHeight(right) + 1) {
        let l = left.getOrThrow()
        if (headingHeight(l.left) >= headingHeight(l.right)) {
            return HeadingIndexBranch(l.value, l.left, Some(HeadingIndexBranch(value, l.right, right)))
        }
        let m = l.right.getOrThrow()
        return HeadingIndexBranch(m.value, Some(HeadingIndexBranch(l.value, l.left, m.left)), Some(HeadingIndexBranch(value, m.right, right)))
    }
    if (headingHeight(right) > headingHeight(left) + 1) {
        let r = right.getOrThrow()
        if (headingHeight(r.right) >= headingHeight(r.left)) {
            return HeadingIndexBranch(r.value, Some(HeadingIndexBranch(value, left, r.left)), r.right)
        }
        let m = r.left.getOrThrow()
        return HeadingIndexBranch(m.value, Some(HeadingIndexBranch(value, left, m.left)), Some(HeadingIndexBranch(r.value, m.right, r.right)))
    }
    return HeadingIndexBranch(value, left, right)
}
private func headingBefore(a: HeadingContribution, b: HeadingContribution, resolve: (SourceAnchor) -> ?Int64): Bool {
    if (a.ownerId == b.ownerId) { return false }
    let x = if (let Some(anchor) <- a.anchor) { resolve(anchor).getOrThrow() } else { a.order }
    let y = if (let Some(anchor) <- b.anchor) { resolve(anchor).getOrThrow() } else { b.order }
    return x < y || (x == y && a.ownerId < b.ownerId)
}

private class HeadingOwnerIndex {
    let zero: ?HeadingOwnerIndex
    let one: ?HeadingOwnerIndex
    let value: ?HeadingContribution
    HeadingOwnerIndex(zero: ?HeadingOwnerIndex, one: ?HeadingOwnerIndex, value: ?HeadingContribution) {
        this.zero = zero; this.one = one; this.value = value
    }
}
private func headingOwnerGet(root: ?HeadingOwnerIndex, id: Int64, bit!: Int64 = 62): ?HeadingContribution {
    if (root.isNone()) { return None }; let n = root.getOrThrow()
    if (bit < 0) { return n.value }
    return headingOwnerGet(if (((id >> bit) & 1) == 0) { n.zero } else { n.one }, id, bit: bit - 1)
}
private func headingOwnerSet(root: ?HeadingOwnerIndex, id: Int64, value: ?HeadingContribution, bit!: Int64 = 62): ?HeadingOwnerIndex {
    let n = root ?? HeadingOwnerIndex(None, None, None)
    if (bit < 0) { return Some(HeadingOwnerIndex(n.zero, n.one, value)) }
    if (((id >> bit) & 1) == 0) { return Some(HeadingOwnerIndex(headingOwnerSet(n.zero, id, value, bit: bit - 1), n.one, n.value)) }
    return Some(HeadingOwnerIndex(n.zero, headingOwnerSet(n.one, id, value, bit: bit - 1), n.value))
}
private func headingSet(root: ?HeadingIndexBranch, value: HeadingSemanticValue,
    resolve: (SourceAnchor) -> ?Int64): ?HeadingIndexBranch {
    if (let Some(n) <- root) {
        if (headingBefore(value.contribution, n.value.contribution, resolve)) {
            return Some(headingBalance(n.value, headingSet(n.left, value, resolve), n.right))
        }
        if (headingBefore(n.value.contribution, value.contribution, resolve)) {
            return Some(headingBalance(n.value, n.left, headingSet(n.right, value, resolve)))
        }
        return Some(HeadingIndexBranch(value, n.left, n.right))
    }
    return Some(HeadingIndexBranch(value, None, None))
}
private func headingRemove(root: ?HeadingIndexBranch, value: HeadingContribution,
    resolve: (SourceAnchor) -> ?Int64): ?HeadingIndexBranch {
    if (root.isNone()) { return None }; let n = root.getOrThrow()
    if (headingBefore(value, n.value.contribution, resolve)) { return Some(headingBalance(n.value, headingRemove(n.left, value, resolve), n.right)) }
    if (headingBefore(n.value.contribution, value, resolve)) { return Some(headingBalance(n.value, n.left, headingRemove(n.right, value, resolve))) }
    if (n.left.isNone()) { return n.right }; if (n.right.isNone()) { return n.left }
    var next = n.right.getOrThrow()
    while (next.left.isSome()) { next = next.left.getOrThrow() }
    return Some(headingBalance(next.value, n.left, headingRemove(n.right, next.value.contribution, resolve)))
}
private func headingRank(root: ?HeadingIndexBranch, value: HeadingContribution, resolve: (SourceAnchor) -> ?Int64): Int64 {
    if (root.isNone()) { return 0 }; let n = root.getOrThrow()
    if (headingBefore(n.value.contribution, value, resolve)) { return headingSize(n.left) + 1 + headingRank(n.right, value, resolve) }
    return headingRank(n.left, value, resolve)
}
private func headingAt(root: ?HeadingIndexBranch, rank: Int64): ?HeadingSemanticValue {
    if (root.isNone() || rank < 0 || rank >= headingSize(root)) { return None }; let n = root.getOrThrow()
    let left = headingSize(n.left)
    if (rank < left) { return headingAt(n.left, rank) }
    if (rank == left) { return Some(n.value) }
    return headingAt(n.right, rank - left - 1)
}

// Keys remain shared immutable strings. AVL depth depends on distinct slugs,
// so a very long heading does not allocate one trie node per source bit.
private class HeadingSlugBuckets {
    let key: String
    let left: ?HeadingSlugBuckets
    let right: ?HeadingSlugBuckets
    let bucket: ?HeadingIndexBranch
    let height: Int64
    HeadingSlugBuckets(key: String, bucket: ?HeadingIndexBranch, left: ?HeadingSlugBuckets, right: ?HeadingSlugBuckets) {
        this.key = key; this.bucket = bucket; this.left = left; this.right = right
        let a = headingBucketHeight(left); let b = headingBucketHeight(right)
        height = 1 + if (a > b) { a } else { b }
    }
}
private func headingBucketHeight(root: ?HeadingSlugBuckets): Int64 { return if (let Some(n) <- root) { n.height } else { 0 } }
private func headingBucketBalance(key: String, bucket: ?HeadingIndexBranch,
    left: ?HeadingSlugBuckets, right: ?HeadingSlugBuckets): HeadingSlugBuckets {
    if (headingBucketHeight(left) > headingBucketHeight(right) + 1) {
        let l = left.getOrThrow()
        if (headingBucketHeight(l.left) >= headingBucketHeight(l.right)) {
            return HeadingSlugBuckets(l.key, l.bucket, l.left, Some(HeadingSlugBuckets(key, bucket, l.right, right)))
        }
        let m = l.right.getOrThrow()
        return HeadingSlugBuckets(m.key, m.bucket, Some(HeadingSlugBuckets(l.key, l.bucket, l.left, m.left)),
            Some(HeadingSlugBuckets(key, bucket, m.right, right)))
    }
    if (headingBucketHeight(right) > headingBucketHeight(left) + 1) {
        let r = right.getOrThrow()
        if (headingBucketHeight(r.right) >= headingBucketHeight(r.left)) {
            return HeadingSlugBuckets(r.key, r.bucket, Some(HeadingSlugBuckets(key, bucket, left, r.left)), r.right)
        }
        let m = r.left.getOrThrow()
        return HeadingSlugBuckets(m.key, m.bucket, Some(HeadingSlugBuckets(key, bucket, left, m.left)),
            Some(HeadingSlugBuckets(r.key, r.bucket, m.right, r.right)))
    }
    return HeadingSlugBuckets(key, bucket, left, right)
}
private func headingBucket(root: ?HeadingSlugBuckets, key: String): ?HeadingIndexBranch {
    if (root.isNone()) { return None }; let n = root.getOrThrow()
    if (key == n.key) { return n.bucket }
    return headingBucket(if (key < n.key) { n.left } else { n.right }, key)
}
private func headingBucketSet(root: ?HeadingSlugBuckets, key: String, bucket: ?HeadingIndexBranch): ?HeadingSlugBuckets {
    if (root.isNone()) { return if (bucket.isNone()) { None } else { Some(HeadingSlugBuckets(key, bucket, None, None)) } }
    let n = root.getOrThrow()
    if (key < n.key) { return Some(headingBucketBalance(n.key, n.bucket, headingBucketSet(n.left, key, bucket), n.right)) }
    if (key > n.key) { return Some(headingBucketBalance(n.key, n.bucket, n.left, headingBucketSet(n.right, key, bucket))) }
    if (bucket.isSome()) { return Some(HeadingSlugBuckets(key, bucket, n.left, n.right)) }
    if (n.left.isNone()) { return n.right }; if (n.right.isNone()) { return n.left }
    var next = n.right.getOrThrow()
    while (next.left.isSome()) { next = next.left.getOrThrow() }
    return Some(headingBucketBalance(next.key, next.bucket, n.left, headingBucketSet(n.right, next.key, None)))
}

public class HeadingIndexChange {
    public let index: HeadingOrderedIndex
    private let updates: Array<HeadingSemanticValue>
    public prop changed: Array<HeadingSemanticValue> { get() { return updates.clone() } }
    public HeadingIndexChange(index: HeadingOrderedIndex, changed: Array<HeadingSemanticValue>) { this.index = index; updates = changed.clone() }
}

public class HeadingOrderedIndex {
    private let root: ?HeadingIndexBranch
    private let buckets: ?HeadingSlugBuckets
    private let owners: ?HeadingOwnerIndex
    private let numbering: HeadingNumberingConfig
    private let closable: HeadingClosableConfig
    private let slugConfig: HeadingSlugConfig
    public HeadingOrderedIndex(numbering!: HeadingNumberingConfig = HeadingNumberingConfig(),
        closable!: HeadingClosableConfig = HeadingClosableConfig(), slugConfig!: HeadingSlugConfig = HeadingSlugConfig()) {
        root = None; buckets = None; owners = None; this.numbering = numbering; this.closable = closable; this.slugConfig = slugConfig
    }
    private init(root: ?HeadingIndexBranch, buckets: ?HeadingSlugBuckets, owners: ?HeadingOwnerIndex,
        numbering: HeadingNumberingConfig, closable: HeadingClosableConfig, slugConfig: HeadingSlugConfig) {
        this.root = root; this.buckets = buckets; this.owners = owners
        this.numbering = numbering; this.closable = closable; this.slugConfig = slugConfig
    }
    public prop size: Int64 { get() { return headingSize(root) } }
    public prop fingerprint: String { get() { return if (let Some(node) <- root) { node.fingerprint.toString() } else { "empty" } } }
    public func at(rank: Int64): ?HeadingSemanticValue { return headingAt(root, rank) }
    public func contributionForOwner(id: Int64): ?HeadingContribution { return headingOwnerGet(owners, id) }
    public func valueFor(value: HeadingContribution,
        resolve!: (SourceAnchor) -> ?Int64 = { anchor: SourceAnchor => Some(anchor.byteOffset) }): ?HeadingSemanticValue {
        let result = headingAt(root, headingRank(root, value, resolve))
        if (let Some(found) <- result) { if (found.contribution.ownerId == value.ownerId) { return result } }
        return None
    }
    // Render-time visibility reads the nearest preceding heading in logarithmic
    // time; changing a section boundary never parses or copies its body.
    public func visibleAt(position: Int64,
        resolve!: (SourceAnchor) -> ?Int64 = { anchor: SourceAnchor => Some(anchor.byteOffset) }): Bool {
        if (!closable.enabled) { return true }
        var cursor = root; var hidden: Int64 = 0
        while (let Some(node) <- cursor) {
            let value = node.value.contribution
            let order = if (let Some(anchor) <- value.anchor) { resolve(anchor).getOrThrow() } else { value.order }
            if (order <= position) { hidden = node.value.hiddenAfter; cursor = node.right } else { cursor = node.left }
        }
        return hidden == 0
    }
    public func change(previous: ?HeadingContribution, current: ?HeadingContribution,
        resolve!: (SourceAnchor) -> ?Int64 = { anchor: SourceAnchor => Some(anchor.byteOffset) }): HeadingIndexChange {
        var nextRoot = root; var nextBuckets = buckets; var nextOwners = owners
        let keys = ArrayList<String>(); var start = size
        var previousValue: ?HeadingSemanticValue = None
        if (let Some(requested) <- previous) {
            let old = headingOwnerGet(owners, requested.ownerId).getOrThrow()
            let key = slug(old.text); keys.add(key)
            start = headingRank(nextRoot, old, resolve)
            previousValue = headingAt(nextRoot, start)
            nextRoot = headingRemove(nextRoot, old, resolve)
            nextBuckets = headingBucketSet(nextBuckets, key, headingRemove(headingBucket(nextBuckets, key), old, resolve))
            nextOwners = headingOwnerSet(nextOwners, old.ownerId, None)
        }
        if (let Some(value) <- current) {
            let key = slug(value.text); if (!keys.contains(key)) { keys.add(key) }
            let rank = headingRank(nextRoot, value, resolve); if (rank < start) { start = rank }
            let blank = if (let Some(old) <- previousValue) {
                HeadingSemanticValue(value, HeadingSlugAllocation("", "", 0, ""), old.number, old.visible, old.hiddenAfter, old.countersAfter)
            } else { HeadingSemanticValue(value, HeadingSlugAllocation("", "", 0, ""), "", true, 0, initialCounters()) }
            nextRoot = headingSet(nextRoot, blank, resolve)
            nextBuckets = headingBucketSet(nextBuckets, key, headingSet(headingBucket(nextBuckets, key), blank, resolve))
            nextOwners = headingOwnerSet(nextOwners, value.ownerId, Some(value))
        }
        let changed = ArrayList<HeadingSemanticValue>()
        // Slug uniqueness only visits the exact changed key buckets.
        for (key in keys) {
            let bucket = headingBucket(nextBuckets, key)
            for (i in 0..headingSize(bucket)) {
                let value = headingAt(bucket, i).getOrThrow().contribution
                let rank = headingRank(nextRoot, value, resolve)
                let old = headingAt(nextRoot, rank).getOrThrow()
                let allocation = allocate(key, if (key.isEmpty()) { 0 } else { i + 1 })
                if (old.slugAllocation.uniqueSlug != allocation.uniqueSlug || old.slugAllocation.occurrence != allocation.occurrence) {
                    let updated = HeadingSemanticValue(value, allocation, old.number, old.visible, old.hiddenAfter, old.countersAfter)
                    nextRoot = headingSet(nextRoot, updated, resolve); changed.add(updated)
                }
            }
        }
        var counters = if (start > 0) { headingAt(nextRoot, start - 1).getOrThrow().countersAfter } else { initialCounters() }
        var hidden = if (start > 0) { headingAt(nextRoot, start - 1).getOrThrow().hiddenAfter } else { 0 }
        var rank = start
        while (rank < headingSize(nextRoot)) {
            let old = headingAt(nextRoot, rank).getOrThrow(); let value = old.contribution
            var number = ""
            if (numbering.enabled && value.level <= numbering.maxDepth) {
                counters[value.level - 1] += 1
                for (i in value.level..6) { counters[i] = numbering.startFrom[i] - 1 }
                let parts = ArrayList<String>()
                for (i in 0..value.level) { parts.add(counters[i].toString()) }
                number = String.join(parts.toArray(), delimiter: numbering.separator)
            }
            if (hidden > 0 && value.level <= hidden) { hidden = 0 }
            let visible = !closable.enabled || (hidden == 0 && !value.closable)
            if (closable.enabled && hidden == 0 && value.closable) { hidden = value.level }
            let updated = HeadingSemanticValue(value, old.slugAllocation, number, visible, hidden, counters)
            nextRoot = headingSet(nextRoot, updated, resolve); changed.add(updated)
            rank += 1
            if (updated.sameContinuation(old)) { break }
        }
        // Keep only the final version of each changed owner in the public delta.
        let final = ArrayList<HeadingSemanticValue>()
        let seen = HashMap<Int64, Bool>()
        var cursor = changed.size
        while (cursor > 0) {
            cursor -= 1
            let value = changed[cursor]
            if (!seen.contains(value.contribution.ownerId)) { seen[value.contribution.ownerId] = true; final.add(value) }
        }
        let ordered = Array<HeadingSemanticValue>(final.size, { i => final[final.size - i - 1] })
        return HeadingIndexChange(HeadingOrderedIndex(nextRoot, nextBuckets, nextOwners, numbering, closable, slugConfig), ordered)
    }
    private func allocate(base: String, occurrence: Int64): HeadingSlugAllocation {
        if (base.isEmpty()) { return HeadingSlugAllocation("", "", 0, "") }
        let unique = if (occurrence == 1) { base } else { "${base}-${occurrence}" }
        let label = if (slugConfig.enablePathLabels && !slugConfig.currentPagePath.isEmpty()) {
            HeadingSlugScope.buildPathLabel(slugConfig.currentPagePath, base, occurrence: occurrence)
        } else { base }
        return HeadingSlugAllocation(base, unique, occurrence, label)
    }
    private func initialCounters(): Array<Int64> {
        if (let Some(values) <- numbering.initialCounters) { return values.clone() }
        return Array<Int64>(6, { i => numbering.startFrom[i] - 1 })
    }
}
