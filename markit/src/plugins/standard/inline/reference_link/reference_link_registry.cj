package markit.plugins.standard.inline.reference_link

import std.collection.{ArrayList, HashMap}
import markit.core.nodes.Node
import markit.core.session.{SessionState, SessionStateSnapshot, SessionStatePayload, RestorableSessionStateSnapshot}
import markit.core.editing.{OwnedEffectPayload, SourceAnchor}

public class LinkDefinition <: OwnedEffectPayload {
    public LinkDefinition(public let url: String, public let title: String, public let anchor!: ?SourceAnchor = None) {}
    public func cloneEffectPayload(): OwnedEffectPayload { return LinkDefinition(url, title, anchor: anchor) }
}

public class ReferenceDefinitionCandidate {
    public ReferenceDefinitionCandidate(public let ownerId: Int64, public let label: String,
        public let url: String, public let title: String, public let order: Int64) {}
}

private class ReferenceRegistryPayload <: SessionStatePayload {
    private let captured: Array<ReferenceDefinitionCandidate>
    public ReferenceRegistryPayload(values: Array<ReferenceDefinitionCandidate>) { captured = values.clone() }
    public prop values: Array<ReferenceDefinitionCandidate> { get() { return captured.clone() } }
    public prop fingerprint: String {
        get() {
            var result = "reference-candidates-v1"
            for (value in captured) {
                result += ":${value.ownerId}/${value.order}/${value.label.size}:${value.label}/${value.url.size}:${value.url}/${value.title.size}:${value.title}"
            }
            return result
        }
    }
    public func detachedCopy(): SessionStatePayload { return ReferenceRegistryPayload(captured) }
}

public class ReferenceLinkRegistry <: SessionState {
    private let candidates = ArrayList<ReferenceDefinitionCandidate>()
    private let definitions = HashMap<String, ReferenceDefinitionCandidate>()
    // Legacy scratch references never enter immutable editing checkpoints.
    private let pendingRefs = ArrayList<Node>()
    private let pendingImages = ArrayList<Node>()

    public func addDefinition(label: String, url: String, title: String): Bool {
        return addCandidate(candidates.size, label, url, title, candidates.size)
    }
    public func addCandidate(ownerId: Int64, label: String, url: String, title: String, order: Int64): Bool {
        let key = normalizeReferenceLabel(label)
        let candidate = ReferenceDefinitionCandidate(ownerId, label, url, title, order)
        candidates.add(candidate)
        if (let Some(previous) <- definitions.get(key)) {
            if (previous.order < order || (previous.order == order && previous.ownerId <= ownerId)) { return false }
        }
        definitions[key] = candidate
        return true
    }
    public func revokeCandidate(ownerId: Int64): Unit {
        var at = candidates.size
        while (at > 0) { at -= 1; if (candidates[at].ownerId == ownerId) { candidates.remove(at: at) } }
        rebuildWinners()
    }
    private func rebuildWinners(): Unit {
        definitions.clear()
        for (candidate in candidates) {
            let key = normalizeReferenceLabel(candidate.label)
            if (let Some(previous) <- definitions.get(key)) {
                if (previous.order < candidate.order ||
                    (previous.order == candidate.order && previous.ownerId <= candidate.ownerId)) { continue }
            }
            definitions[key] = candidate
        }
    }
    public func getDefinition(label: String): ?LinkDefinition {
        if (let Some(value) <- definitions.get(normalizeReferenceLabel(label))) { return Some(LinkDefinition(value.url, value.title)) }
        return None
    }
    public func hasDefinition(label: String): Bool { return definitions.contains(normalizeReferenceLabel(label)) }
    public func addUnresolvedRef(node: Node): Unit { pendingRefs.add(node) }
    public func addUnresolvedImage(node: Node): Unit { pendingImages.add(node) }
    public func getUnresolvedRefs(): ArrayList<Node> { return pendingRefs }
    public func getUnresolvedImages(): ArrayList<Node> { return pendingImages }
    public func definitionCount(): Int64 { return definitions.size }
    public func candidateCount(): Int64 { return candidates.size }
    public func reset(): Unit { candidates.clear(); definitions.clear(); pendingRefs.clear(); pendingImages.clear() }
    public prop supportsStateRestore: Bool { get() { return pendingRefs.isEmpty() && pendingImages.isEmpty() } }
    public func snapshot(): SessionStateSnapshot {
        if (!supportsStateRestore) { return SessionStateSnapshot("ReferenceLinkPlugin.registry") }
        return RestorableSessionStateSnapshot("ReferenceLinkPlugin.registry", 0, "reference-candidates-v1",
            ReferenceRegistryPayload(candidates.toArray()))
    }
    public func restoreSnapshot(snapshot: SessionStateSnapshot): Bool {
        if (snapshot.dynamicName != "ReferenceLinkPlugin.registry") { return false }
        if (let Some(value) <- snapshot.payloadCopy()) {
            if (let payload: ReferenceRegistryPayload <- value) {
                reset()
                for (candidate in payload.values) { candidates.add(candidate) }
                rebuildWinners(); return true
            }
        }
        return false
    }
}
