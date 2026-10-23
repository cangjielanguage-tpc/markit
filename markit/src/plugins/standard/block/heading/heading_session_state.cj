package markit.plugins.standard.block.heading

import std.collection.ArrayList
import std.collection.HashMap
import markit.core.nodes.Node
import markit.core.session.{SessionState, SessionStateSnapshot, RestorableSessionStateSnapshot}
import markit.utils.{HeadingSlugScope, slug}
import markit.core.editing.{SourceAnchor, OwnedSemanticEffect}
import markit.core.block.BlockEditingContext

public class HeadingSessionState <: SessionState {
    private let slugCounts = HashMap<String, Int64>()
    private let slugKeys = ArrayList<String>()
    private let numberingConfig: HeadingNumberingConfig
    private let closableConfig: HeadingClosableConfig
    private let slugConfig: HeadingSlugConfig
    private var counters: Array<Int64>
    private var hiddenSectionLevel: Int64 = 0
    private var ordered: HeadingOrderedIndex
    private var pendingRemoval: ?HeadingContribution = None
    private let orderedUpdates = ArrayList<HeadingSemanticValue>()
    private var deferredDepth: Int64 = 0
    private var indexOwnerId: Int64 = -1

    public HeadingSessionState(
        numberingConfig!: HeadingNumberingConfig = HeadingNumberingConfig(),
        closableConfig!: HeadingClosableConfig = HeadingClosableConfig(),
        slugConfig!: HeadingSlugConfig = HeadingSlugConfig()
    ) {
        this.numberingConfig = numberingConfig
        this.closableConfig = closableConfig
        this.slugConfig = slugConfig
        this.counters = initialCountersFor(numberingConfig)
        ordered = HeadingOrderedIndex(numbering: numberingConfig, closable: closableConfig, slugConfig: slugConfig)
    }

    public prop orderedIndex: HeadingOrderedIndex { get() { return ordered } }
    public prop orderedEffectOwner: Int64 { get() { return indexOwnerId } }
    public prop contributionsDeferred: Bool { get() { return deferredDepth > 0 } }
    public func deferContributions(): Unit { deferredDepth += 1 }
    public func resumeContributions(): Unit {
        if (deferredDepth < 1) { throw IllegalArgumentException("Unbalanced mapped heading contribution scope") }
        deferredDepth -= 1
    }
    public func retainOrderedIndex(index: HeadingOrderedIndex, ownerId!: Int64 = -1): Unit {
        ordered = index; indexOwnerId = ownerId
    }
    public func publishOrderedIndex(context: BlockEditingContext): Unit {
        if (indexOwnerId < 0) { indexOwnerId = context.session.allocateNodeId() }
        context.effects.replay(indexOwnerId,
            [OwnedSemanticEffect(indexOwnerId, "standard.heading.index", HeadingIndexPayload(ordered), 0)])
    }
    public func beginOrderedChange(previous: HeadingContribution): Unit {
        pendingRemoval = Some(previous); orderedUpdates.clear()
    }
    public func acceptContribution(value: HeadingContribution, resolve: (SourceAnchor) -> ?Int64,
        collect!: Bool = true): HeadingSemanticValue {
        let change = ordered.change(pendingRemoval, Some(value), resolve: resolve)
        ordered = change.index; pendingRemoval = None
        if (collect) { for (update in change.changed) { orderedUpdates.add(update) } }
        return ordered.valueFor(value, resolve: resolve).getOrThrow()
    }
    public func finishOrderedChange(resolve: (SourceAnchor) -> ?Int64): Unit {
        if (let Some(previous) <- pendingRemoval) {
            let change = ordered.change(Some(previous), None, resolve: resolve)
            ordered = change.index; pendingRemoval = None
            for (update in change.changed) { orderedUpdates.add(update) }
        }
    }
    public func revokeContribution(id: Int64, resolve: (SourceAnchor) -> ?Int64): Unit {
        if (let Some(previous) <- ordered.contributionForOwner(id)) {
            let change = ordered.change(Some(previous), None, resolve: resolve); ordered = change.index
            for (update in change.changed) { orderedUpdates.add(update) }
        }
    }
    public func takeOrderedUpdates(): Array<HeadingSemanticValue> {
        let last = HashMap<Int64, HeadingSemanticValue>()
        for (update in orderedUpdates) { last[update.contribution.ownerId] = update }
        let result = ArrayList<HeadingSemanticValue>()
        for ((_, value) in last) { result.add(value) }
        orderedUpdates.clear()
        return result.toArray()
    }

    public func uniqueSlug(text: String): String {
        return allocateSlug(text).uniqueSlug
    }

    public func allocateSlug(text: String): HeadingSlugAllocation {
        let base = slug(text)
        if (base.isEmpty()) {
            return HeadingSlugAllocation("", "", 0, "")
        }
        let seen = slugCounts.get(base) ?? 0
        if (seen == 0) { slugKeys.add(base) }
        let occurrence = seen + 1
        slugCounts[base] = occurrence
        let unique = if (seen == 0) {
            base
        } else {
            "${base}-${occurrence}"
        }
        let typstLabel = if (slugConfig.enablePathLabels && !slugConfig.currentPagePath.isEmpty()) {
            HeadingSlugScope.buildPathLabel(slugConfig.currentPagePath, base, occurrence: occurrence)
        } else {
            base
        }
        return HeadingSlugAllocation(base, unique, occurrence, typstLabel)
    }

    public func assignNumber(level: Int64): String {
        if (!numberingConfig.enabled || level < 1 || level > numberingConfig.maxDepth) {
            return ""
        }

        let index = level - 1
        counters[index] += 1
        for (i in level..6) {
            counters[i] = numberingConfig.startFrom[i] - 1
        }

        let parts = ArrayList<String>()
        for (i in 0..level) {
            parts.add(counters[i].toString())
        }
        return String.join(parts.toArray(), delimiter: numberingConfig.separator)
    }

    public func includeNumberInHtml(): Bool {
        return numberingConfig.includeInHtml
    }

    public func closableEnabled(): Bool {
        return closableConfig.enabled
    }

    public func acceptTopLevelNode(node: Node): Bool {
        if (!closableConfig.enabled) {
            return true
        }

        if (node.kind == "Heading") {
            if (hiddenSectionLevel > 0 && node.level <= hiddenSectionLevel) {
                hiddenSectionLevel = 0
            }

            let closable = node.bool("closable") ?? false
            if (hiddenSectionLevel > 0) {
                return false
            }
            if (closable) {
                hiddenSectionLevel = node.level
                return false
            }
            return true
        }

        return hiddenSectionLevel == 0
    }

    public func reset(): Unit {
        slugCounts.clear()
        slugKeys.clear()
        counters = initialCounters()
        hiddenSectionLevel = 0
        ordered = HeadingOrderedIndex(numbering: numberingConfig, closable: closableConfig, slugConfig: slugConfig)
        pendingRemoval = None; orderedUpdates.clear(); deferredDepth = 0; indexOwnerId = -1
    }

    public func snapshot(): SessionStateSnapshot {
        let keys = slugKeys.toArray()
        let counts = Array<Int64>(keys.size, { i => slugCounts[keys[i]] })
        return RestorableSessionStateSnapshot(HeadingPlugin.stateKey.dynamicName, 0, configFingerprint(),
            HeadingStatePayload(keys, counts, counters, hiddenSectionLevel, orderedIndex: ordered,
                pendingRemoval: pendingRemoval, orderedUpdates: orderedUpdates.toArray(), deferredDepth: deferredDepth,
                indexOwnerId: indexOwnerId))
    }

    public prop supportsStateRestore: Bool { get() { return true } }

    public func restoreSnapshot(saved: SessionStateSnapshot): Bool {
        if (saved.dynamicName != HeadingPlugin.stateKey.dynamicName || saved.sourceVersion != 0 ||
            saved.contextFingerprint != configFingerprint()) { return false }
        if (let Some(payload) <- saved.payloadCopy()) {
            if (let state: HeadingStatePayload <- payload) {
                let keys = state.slugKeys; let counts = state.slugCounts
                slugCounts.clear(); slugKeys.clear()
                for (i in 0..keys.size) { slugKeys.add(keys[i]); slugCounts[keys[i]] = counts[i] }
                counters = state.counters; hiddenSectionLevel = state.hiddenLevel
                ordered = state.orderedIndex; pendingRemoval = state.pendingRemoval; orderedUpdates.clear()
                deferredDepth = state.deferredDepth
                indexOwnerId = state.indexOwnerId
                for (update in state.orderedUpdates) { orderedUpdates.add(update) }
                return true
            }
        }
        return false
    }

    private func configFingerprint(): String {
        let out = StringBuilder()
        out.append("heading-config-v1:${numberingConfig.enabled}:${numberingConfig.maxDepth}:${numberingConfig.includeInHtml}:")
        out.append("${numberingConfig.separator.size}:${numberingConfig.separator}:${numberingConfig.resetBeforeParse}:${closableConfig.enabled}:")
        out.append("${slugConfig.enablePathLabels}:${slugConfig.currentPagePath.size}:${slugConfig.currentPagePath};")
        for (value in numberingConfig.startFrom) { out.append("${value};") }
        for (value in initialCounters()) { out.append("${value};") }
        return out.toString()
    }

    private func initialCounters(): Array<Int64> {
        return initialCountersFor(numberingConfig)
    }

    private static func initialCountersFor(config: HeadingNumberingConfig): Array<Int64> {
        if (let Some(values) <- config.initialCounters) {
            return Array<Int64>(6) { i =>
                if (i < values.size) {
                    values[i]
                } else {
                    config.startFrom[i] - 1
                }
            }
        }
        return Array<Int64>(6) { i => config.startFrom[i] - 1 }
    }
}

public class HeadingSlugAllocation {
    public HeadingSlugAllocation(public let baseSlug: String, public let uniqueSlug: String, public let occurrence: Int64, public let typstLabel: String) {}
}
