package markit.plugins.standard.block.heading

import markit.core.session.SessionStatePayload

public class HeadingStatePayload <: SessionStatePayload {
    private let keys: Array<String>
    private let counts: Array<Int64>
    private let numbers: Array<Int64>
    public let hiddenLevel: Int64
    public let orderedIndex: HeadingOrderedIndex
    public let pendingRemoval: ?HeadingContribution
    public let deferredDepth: Int64
    public let indexOwnerId: Int64
    private let updates: Array<HeadingSemanticValue>
    public prop orderedUpdates: Array<HeadingSemanticValue> { get() { return updates.clone() } }
    public HeadingStatePayload(keys: Array<String>, counts: Array<Int64>, numbers: Array<Int64>, hiddenLevel: Int64,
        orderedIndex!: HeadingOrderedIndex = HeadingOrderedIndex(), pendingRemoval!: ?HeadingContribution = None,
        orderedUpdates!: Array<HeadingSemanticValue> = [], deferredDepth!: Int64 = 0, indexOwnerId!: Int64 = -1) {
        if (keys.size != counts.size || numbers.size != 6 || hiddenLevel < 0 || hiddenLevel > 6) {
            throw IllegalArgumentException("Invalid heading state payload")
        }
        for (i in 0..keys.size) {
            if (keys[i].isEmpty() || counts[i] < 1) { throw IllegalArgumentException("Invalid heading slug count") }
            for (j in 0..i) {
                if (keys[i] == keys[j]) { throw IllegalArgumentException("Duplicate heading slug key") }
            }
        }
        this.keys = keys.clone(); this.counts = counts.clone(); this.numbers = numbers.clone()
        this.hiddenLevel = hiddenLevel
        this.orderedIndex = orderedIndex; this.pendingRemoval = pendingRemoval; updates = orderedUpdates.clone()
        this.deferredDepth = deferredDepth
        this.indexOwnerId = indexOwnerId
    }
    public prop slugKeys: Array<String> { get() { return keys.clone() } }
    public prop slugCounts: Array<Int64> { get() { return counts.clone() } }
    public prop counters: Array<Int64> { get() { return numbers.clone() } }
    public prop fingerprint: String {
        get() {
            let out = StringBuilder()
            out.append("heading-state-v1:${hiddenLevel}:${orderedIndex.fingerprint}:${deferredDepth}:${indexOwnerId};")
            for (i in 0..keys.size) { out.append("${keys[i].size}:${keys[i]}=${counts[i]};") }
            for (number in numbers) { out.append("${number};") }
            if (let Some(value) <- pendingRemoval) { out.append("pending:${value.ownerId}:${value.text.hashCode()}:${value.level}:${value.closable};") }
            for (value in updates) { out.append("update:${value.fingerprint};") }
            return out.toString()
        }
    }
    public func detachedCopy(): SessionStatePayload {
        return HeadingStatePayload(keys, counts, numbers, hiddenLevel, orderedIndex: orderedIndex,
            pendingRemoval: pendingRemoval, orderedUpdates: updates, deferredDepth: deferredDepth, indexOwnerId: indexOwnerId)
    }
}
