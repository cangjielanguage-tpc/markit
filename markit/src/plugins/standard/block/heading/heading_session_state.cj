package markit.plugins.standard.block.heading

import std.collection.ArrayList
import std.collection.HashMap
import markit.core.nodes.Node
import markit.core.session.{SessionState, SessionStateSnapshot}
import markit.utils.{HeadingSlugScope, slug}

public class HeadingSessionState <: SessionState {
    private let slugCounts = HashMap<String, Int64>()
    private let numberingConfig: HeadingNumberingConfig
    private let closableConfig: HeadingClosableConfig
    private let slugConfig: HeadingSlugConfig
    private var counters: Array<Int64>
    private var hiddenSectionLevel: Int64 = 0

    public init(
        numberingConfig!: HeadingNumberingConfig = HeadingNumberingConfig(),
        closableConfig!: HeadingClosableConfig = HeadingClosableConfig(),
        slugConfig!: HeadingSlugConfig = HeadingSlugConfig()
    ) {
        this.numberingConfig = numberingConfig
        this.closableConfig = closableConfig
        this.slugConfig = slugConfig
        this.counters = initialCountersFor(numberingConfig)
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
        counters = initialCounters()
        hiddenSectionLevel = 0
    }

    public func snapshot(): SessionStateSnapshot {
        return SessionStateSnapshot(HeadingPlugin.stateKey.dynamicName)
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
    public let baseSlug: String
    public let uniqueSlug: String
    public let occurrence: Int64
    public let typstLabel: String

    public init(baseSlug: String, uniqueSlug: String, occurrence: Int64, typstLabel: String) {
        this.baseSlug = baseSlug
        this.uniqueSlug = uniqueSlug
        this.occurrence = occurrence
        this.typstLabel = typstLabel
    }
}
