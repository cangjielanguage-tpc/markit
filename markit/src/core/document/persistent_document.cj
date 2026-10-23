package markit.core.document

import markit.core.editing.*
import markit.core.nodes.*
import markit.core.source.SourceSpan
import std.collection.{ArrayList, HashMap}

private class SyntaxIndexEntry {
    public let node: RawSyntaxNode
    public let parentId: ?Int64
    public let childIndex: Int64
    public let auxiliary: Bool
    public let incoming: Int64
    public let ownerId: Int64
    public SyntaxIndexEntry(node: RawSyntaxNode, parentId: ?Int64, childIndex: Int64, auxiliary!: Bool = false, incoming!: Int64 = 0, ownerId!: Int64 = -1) {
        this.node = node; this.parentId = parentId; this.childIndex = childIndex
        this.auxiliary = auxiliary; this.incoming = incoming
        this.ownerId = ownerId
    }
}

// Immutable AVL map. Commit updates/removes only touched IDs; old versions
// retain their old root. No overlay chain, full HashMap clone, or tombstones.
private class SyntaxIndex {
    public let key: Int64
    public let entry: SyntaxIndexEntry
    public let left: ?SyntaxIndex
    public let right: ?SyntaxIndex
    public let height: Int64
    public let count: Int64
    public let earliestAnchorVersion: Int64
    public SyntaxIndex(key: Int64, entry: SyntaxIndexEntry, left: ?SyntaxIndex, right: ?SyntaxIndex) {
        this.key = key; this.entry = entry; this.left = left; this.right = right
        let lh = indexHeight(left); let rh = indexHeight(right)
        this.height = 1 + if (lh > rh) { lh } else { rh }
        this.count = 1 + indexCount(left) + indexCount(right)
        var earliest = entry.node.earliestAnchorVersion
        if (let Some(node) <- left) { if (node.earliestAnchorVersion < earliest) { earliest = node.earliestAnchorVersion } }
        if (let Some(node) <- right) { if (node.earliestAnchorVersion < earliest) { earliest = node.earliestAnchorVersion } }
        this.earliestAnchorVersion = earliest
    }
}

private func indexHeight(index: ?SyntaxIndex): Int64 {
    if (let Some(node) <- index) { return node.height }; return 0
}
private func indexCount(index: ?SyntaxIndex): Int64 {
    if (let Some(node) <- index) { return node.count }; return 0
}
private func indexGet(index: ?SyntaxIndex, key: Int64): ?SyntaxIndexEntry {
    if (let Some(node) <- index) {
        if (key == node.key) { return Some(node.entry) }
        return indexGet(if (key < node.key) { node.left } else { node.right }, key)
    }
    return None
}
private func indexBalance(key: Int64, entry: SyntaxIndexEntry, left: ?SyntaxIndex, right: ?SyntaxIndex): SyntaxIndex {
    if (indexHeight(left) > indexHeight(right) + 1) {
        let l = left.getOrThrow()
        if (indexHeight(l.left) >= indexHeight(l.right)) {
            return SyntaxIndex(l.key, l.entry, l.left, Some(SyntaxIndex(key, entry, l.right, right)))
        }
        let lr = l.right.getOrThrow()
        return SyntaxIndex(lr.key, lr.entry, Some(SyntaxIndex(l.key, l.entry, l.left, lr.left)),
            Some(SyntaxIndex(key, entry, lr.right, right)))
    }
    if (indexHeight(right) > indexHeight(left) + 1) {
        let r = right.getOrThrow()
        if (indexHeight(r.right) >= indexHeight(r.left)) {
            return SyntaxIndex(r.key, r.entry, Some(SyntaxIndex(key, entry, left, r.left)), r.right)
        }
        let rl = r.left.getOrThrow()
        return SyntaxIndex(rl.key, rl.entry, Some(SyntaxIndex(key, entry, left, rl.left)),
            Some(SyntaxIndex(r.key, r.entry, rl.right, r.right)))
    }
    return SyntaxIndex(key, entry, left, right)
}
private func indexSet(index: ?SyntaxIndex, key: Int64, entry: SyntaxIndexEntry): ?SyntaxIndex {
    if (let Some(node) <- index) {
        if (key < node.key) { return Some(indexBalance(node.key, node.entry, indexSet(node.left, key, entry), node.right)) }
        if (key > node.key) { return Some(indexBalance(node.key, node.entry, node.left, indexSet(node.right, key, entry))) }
        return Some(SyntaxIndex(key, entry, node.left, node.right))
    }
    return Some(SyntaxIndex(key, entry, None, None))
}
private func indexRemove(index: ?SyntaxIndex, key: Int64): ?SyntaxIndex {
    if (index.isNone()) { return None }
    let node = index.getOrThrow()
    if (key < node.key) { return Some(indexBalance(node.key, node.entry, indexRemove(node.left, key), node.right)) }
    if (key > node.key) { return Some(indexBalance(node.key, node.entry, node.left, indexRemove(node.right, key))) }
    if (node.left.isNone()) { return node.right }; if (node.right.isNone()) { return node.left }
    var successor = node.right.getOrThrow()
    while (successor.left.isSome()) { successor = successor.left.getOrThrow() }
    return Some(indexBalance(successor.key, successor.entry, node.left, indexRemove(node.right, successor.key)))
}

private func insertSubtree(index: ?SyntaxIndex, node: RawSyntaxNode, documentId: String,
    parentId: ?Int64, childIndex: Int64, auxiliary!: Bool = false): ?SyntaxIndex {
    if (node.identity.documentId != documentId) { throw IllegalArgumentException("Cross-document raw syntax") }
    if (indexGet(index, node.identity.nodeId).isSome()) { throw IllegalArgumentException("Duplicate stable node ID") }
    var result = indexSet(index, node.identity.nodeId, SyntaxIndexEntry(node, parentId, childIndex, auxiliary: auxiliary))
    for (i in 0..node.childCount) { result = insertSubtree(result, node.childAt(i), documentId, Some(node.identity.nodeId), i, auxiliary: auxiliary) }
    return result
}
private func removeSubtree(index: ?SyntaxIndex, node: RawSyntaxNode): ?SyntaxIndex {
    var result = indexRemove(index, node.identity.nodeId)
    for (i in 0..node.childCount) { result = removeSubtree(result, node.childAt(i)) }
    return result
}

private func graphEdges(node: RawSyntaxNode): Array<Int64> {
    let output = ArrayList<Int64>()
    for (i in 0..node.childCount) { output.add(node.childAt(i).identity.nodeId) }
    for (id in node.referenceIds()) { output.add(id) }
    return output.toArray()
}
private func graphDelta(deltas: HashMap<Int64, Int64>, node: RawSyntaxNode, amount: Int64): Unit {
    for (id in graphEdges(node)) { deltas[id] = (deltas.get(id) ?? 0) + amount }
}
private func graphCollect(node: RawSyntaxNode, output: HashMap<Int64, RawSyntaxNode>): Unit {
    if (output.contains(node.identity.nodeId)) { throw IllegalArgumentException("Duplicate structural node ID") }
    output[node.identity.nodeId] = node
    for (i in 0..node.childCount) { graphCollect(node.childAt(i), output) }
}
private func graphAdjust(index: ?SyntaxIndex, id: Int64, amount: Int64,
    removedIncoming: HashMap<Int64, Int64>): ?SyntaxIndex {
    if (let Some(entry) <- indexGet(index, id)) {
        let next = entry.incoming + amount
        if (next < 0) { throw IllegalArgumentException("Negative syntax reference count") }
        return indexSet(index, id, SyntaxIndexEntry(entry.node, entry.parentId, entry.childIndex,
            auxiliary: entry.auxiliary, incoming: next, ownerId: entry.ownerId))
    }
    if (let Some(previous) <- removedIncoming.get(id)) { removedIncoming[id] = previous + amount; return index }
    if (amount != 0) { throw IllegalArgumentException("Dangling syntax reference") }; return index
}
private func graphInitial(index: ?SyntaxIndex, cursor: ?SyntaxIndex): ?SyntaxIndex {
    if (cursor.isNone()) { return index }; let node = cursor.getOrThrow()
    var next = graphInitial(index, node.left)
    let removed = HashMap<Int64, Int64>()
    for (id in graphEdges(node.entry.node)) { next = graphAdjust(next, id, 1, removed) }
    return graphInitial(next, node.right)
}
private func collectNewAuxiliary(index: ?SyntaxIndex, node: RawSyntaxNode, parentId: ?Int64,
    childIndex: Int64, structural: HashMap<Int64, RawSyntaxNode>,
    added: HashMap<Int64, SyntaxIndexEntry>, documentId: String, ownerId: Int64): Unit {
    if (node.identity.documentId != documentId) { throw IllegalArgumentException("Cross-document auxiliary syntax") }
    if (structural.contains(node.identity.nodeId)) {
        if (parentId.isSome()) { throw IllegalArgumentException("Auxiliary child duplicates structural ID") }; return
    }
    if (let Some(existing) <- indexGet(index, node.identity.nodeId)) {
        if (!existing.auxiliary) {
            if (parentId.isSome()) { throw IllegalArgumentException("Auxiliary child duplicates structural ID") }; return
        }
    }
    if (let Some(previous) <- added.get(node.identity.nodeId)) {
        if (parentId.isSome() || !refEq(previous.node, node)) { throw IllegalArgumentException("Duplicate auxiliary node ID") }; return
    }
    added[node.identity.nodeId] = SyntaxIndexEntry(node, parentId, childIndex, auxiliary: true, ownerId: ownerId)
    for (i in 0..node.childCount) { collectNewAuxiliary(index, node.childAt(i), Some(node.identity.nodeId), i, structural, added, documentId, ownerId) }
}

// Trace only auxiliary closures reached by removed edges. Outside incoming
// edges are live roots; tracing from those also handles unreachable cycles.
private func graphCollectGarbage(index: ?SyntaxIndex, seeds: ArrayList<Int64>,
    removedIncoming: HashMap<Int64, Int64>, removedIds: ArrayList<Int64>): ?SyntaxIndex {
    let closure = HashMap<Int64, SyntaxIndexEntry>(); let queue = ArrayList<Int64>()
    for (id in seeds) { queue.add(id) }
    var cursor: Int64 = 0
    while (cursor < queue.size) {
        let id = queue[cursor]; cursor += 1
        if (closure.contains(id)) { continue }
        if (let Some(entry) <- indexGet(index, id)) {
            if (!entry.auxiliary) { continue }
            closure[id] = entry
            for (target in graphEdges(entry.node)) { queue.add(target) }
        }
    }
    let internalIncoming = HashMap<Int64, Int64>()
    for ((_, entry) in closure) {
        for (target in graphEdges(entry.node)) {
            if (closure.contains(target)) { internalIncoming[target] = (internalIncoming.get(target) ?? 0) + 1 }
        }
    }
    let live = HashMap<Int64, Bool>(); queue.clear()
    for ((id, entry) in closure) { if (entry.incoming > (internalIncoming.get(id) ?? 0)) { queue.add(id) } }
    cursor = 0
    while (cursor < queue.size) {
        let id = queue[cursor]; cursor += 1
        if (live.contains(id)) { continue }
        if (let Some(entry) <- closure.get(id)) {
            live[id] = true
            for (target in graphEdges(entry.node)) { if (closure.contains(target)) { queue.add(target) } }
        }
    }
    var next = index
    for ((id, entry) in closure) {
        if (live.contains(id)) { continue }
        for (target in graphEdges(entry.node)) {
            if (!closure.contains(target) || live.contains(target)) { next = graphAdjust(next, target, -1, removedIncoming) }
        }
    }
    for ((id, _) in closure) { if (!live.contains(id)) { next = indexRemove(next, id); removedIds.add(id) } }
    for ((id, _) in live) {
        let entry = indexGet(next, id).getOrThrow()
        if (let Some(parent) <- entry.parentId) {
            if (closure.contains(parent) && !live.contains(parent)) {
                next = indexSet(next, id, SyntaxIndexEntry(entry.node, None, 0, auxiliary: true, incoming: entry.incoming, ownerId: entry.ownerId))
            }
        }
    }
    return next
}

private func graphChange(original: ?SyntaxIndex, removed: Array<RawSyntaxNode>, bundles: Array<PersistentNodeBundle>,
    parentId: ?Int64, childStart: Int64, documentId: String, removedIds: ArrayList<Int64>,
    targetVersion: Int64, resolve: (SourceAnchor) -> ?Int64, structuralIsAuxiliary!: Bool = false): ?SyntaxIndex {
    let old = HashMap<Int64, RawSyntaxNode>(); let added = HashMap<Int64, RawSyntaxNode>()
    let deltas = HashMap<Int64, Int64>(); let removedIncoming = HashMap<Int64, Int64>()
    var next = original
    for (root in removed) { graphCollect(root, old); next = removeSubtree(next, root) }
    for ((id, node) in old) {
        removedIncoming[id] = indexGet(original, id).getOrThrow().incoming
        graphDelta(deltas, node, -1); removedIds.add(id)
    }
    if (parentId.isSome()) {
        for (root in removed) { let id = root.identity.nodeId; deltas[id] = (deltas.get(id) ?? 0) - 1 }
        for (bundle in bundles) { let id = bundle.root.identity.nodeId; deltas[id] = (deltas.get(id) ?? 0) + 1 }
    }
    for (i in 0..bundles.size) {
        let root = bundles[i].root
        graphCollect(root, added)
        next = insertSubtree(next, root, documentId, parentId, childStart + i, auxiliary: structuralIsAuxiliary)
    }
    for ((id, node) in added) {
        let entry = indexGet(next, id).getOrThrow()
        let incoming = removedIncoming.get(id) ?? 0
        removedIncoming.remove(id)
        let owner = if (entry.auxiliary) { indexGet(original, id).map({ old => old.ownerId }) ?? -1 } else { -1 }
        next = indexSet(next, id, SyntaxIndexEntry(entry.node, entry.parentId, entry.childIndex, auxiliary: entry.auxiliary, incoming: incoming, ownerId: owner))
        graphDelta(deltas, node, 1)
    }
    let auxiliary = HashMap<Int64, SyntaxIndexEntry>()
    for (bundle in bundles) {
        let records = bundle.auxiliaryRecords(); let owners = bundle.auxiliaryOwnerIds()
        for (i in 0..records.size) { collectNewAuxiliary(next, records[i], None, 0, added, auxiliary, documentId, owners[i]) }
    }
    let previousParents = HashMap<Int64, Int64>()
    for ((id, entry) in auxiliary) {
        var incoming: Int64 = 0
        var parentId = entry.parentId
        var childIndex = entry.childIndex
        if (let Some(previous) <- indexGet(next, id)) {
            incoming = previous.incoming; graphDelta(deltas, previous.node, -1); removedIds.add(id)
            if (let Some(parent) <- previous.parentId) { previousParents[id] = parent }
            // An auxiliary record supplied as a graph entry point is not a
            // request to detach its existing structural parent.
            if (parentId.isNone()) { parentId = previous.parentId; childIndex = previous.childIndex }
        }
        next = indexSet(next, id, SyntaxIndexEntry(entry.node, parentId, childIndex, auxiliary: true, incoming: incoming, ownerId: entry.ownerId))
        graphDelta(deltas, entry.node, 1)
    }
    let seeds = ArrayList<Int64>()
    for ((id, amount) in deltas) {
        next = graphAdjust(next, id, amount, removedIncoming)
        if (amount < 0) { seeds.add(id) }
    }
    for ((id, _) in auxiliary) { seeds.add(id) }
    next = graphCollectGarbage(next, seeds, removedIncoming, removedIds)
    for ((_, count) in removedIncoming) { if (count != 0) { throw IllegalArgumentException("Removed structural node still has incoming references") } }
    for ((id, previousParent) in previousParents) {
        if (let Some(entry) <- indexGet(next, id)) {
            if (entry.parentId != Some(previousParent)) {
                if (let Some(parent) <- indexGet(next, previousParent)) {
                    if (parent.node.containsChild(id)) { throw IllegalArgumentException("Auxiliary node has two structural parents") }
                }
            }
        }
    }
    // Updating an auxiliary graph entry point may update an existing child.
    // Refresh just its parent paths so embedded raw children and the ID index
    // agree, without rewriting unrelated records or changing reference edges.
    for ((id, _) in auxiliary) {
        var child = indexGet(next, id)
        while (let Some(entry) <- child) {
            if (entry.parentId.isNone()) { break }
            let parentId = entry.parentId.getOrThrow()
            let parent = indexGet(next, parentId).getOrThrow()
            if (!parent.auxiliary) { throw IllegalArgumentException("Auxiliary child has structural document parent") }
            let rank = parent.node.childPosition(entry.node.identity.nodeId)
            if (!refEq(parent.node.childAt(rank), entry.node)) {
                let updated = parent.node.withChildMapped(rank, entry.node, targetVersion, resolve)
                next = indexSet(next, parentId, SyntaxIndexEntry(updated, parent.parentId, parent.childIndex,
                    auxiliary: true, incoming: parent.incoming, ownerId: parent.ownerId))
            }
            child = indexGet(next, parentId)
        }
    }
    return next
}

public class SyntaxNodeView {
    public let syntax: RawSyntaxNode
    private let snapshot: PersistentDocumentVersion
    public SyntaxNodeView(snapshot: PersistentDocumentVersion, syntax: RawSyntaxNode) { this.snapshot = snapshot; this.syntax = syntax }
    public prop version: Int64 { get() { return snapshot.version } }
    public func parent(): ?SyntaxNodeView { return snapshot.parentOf(syntax.identity.nodeId) }
    public func path(): Array<Int64> { return snapshot.pathTo(syntax.identity.nodeId) }
    public func sourceSpan(): ?SourceSpan { return snapshot.resolvedSpan(syntax) }
}

public class PersistentDocumentVersion <: SyntaxReferenceRegistry {
    private let documentIdentity: String
    private let sourceVersion: Int64
    private let rawRoot: RawSyntaxNode
    private let index: ?SyntaxIndex
    private let source: ?EditableSourceStore
    private let sourceView: ?EditableSourceVersion
    private let removedInOperation: Array<Int64>
    public prop documentId: String { get() { return documentIdentity } }
    public prop version: Int64 { get() { return sourceVersion } }
    public prop root: PersistentSyntaxNode { get() { return rawRoot } }
    public prop nodeCount: Int64 { get() { return indexCount(index) } }
    public prop earliestAnchorVersion: Int64 { get() { return index.getOrThrow().earliestAnchorVersion } }

    public PersistentDocumentVersion(bundle: PersistentNodeBundle, source!: ?EditableSourceStore = None) {
        if (source.isSome() && source.getOrThrow().current.identity.documentId != bundle.root.identity.documentId) {
            throw IllegalArgumentException("Cross-document source store")
        }
        this.documentIdentity = bundle.root.identity.documentId
        this.sourceVersion = bundle.root.version
        this.rawRoot = bundle.root
        this.source = source
        this.sourceView = if (source.isSome() && source.getOrThrow().current.identity.version == sourceVersion) {
            Some(source.getOrThrow().current)
        } else { None }
        var next = insertSubtree(None, bundle.root, documentIdentity, None, 0)
        // Additional references may point back into the structural tree.
        let records = bundle.auxiliaryRecords(); let owners = bundle.auxiliaryOwnerIds()
        for (i in 0..records.size) { next = insertAuxiliary(next, records[i], None, 0, documentIdentity, owners[i]) }
        this.index = graphInitial(next, next)
        this.removedInOperation = []
    }
    private init(documentId: String, version: Int64, root: RawSyntaxNode, index: ?SyntaxIndex,
        source: ?EditableSourceStore, removedIds!: Array<Int64> = []) {
        this.documentIdentity = documentId; this.sourceVersion = version
        this.rawRoot = root; this.index = index; this.source = source
        this.sourceView = if (source.isSome() && source.getOrThrow().current.identity.version == version) {
            Some(source.getOrThrow().current)
        } else { None }
        this.removedInOperation = removedIds.clone()
    }
    private static func insertAuxiliary(index: ?SyntaxIndex, record: RawSyntaxNode, parentId: ?Int64, childIndex: Int64, documentId: String, ownerId: Int64): ?SyntaxIndex {
        if (record.identity.documentId != documentId) { throw IllegalArgumentException("Cross-document auxiliary syntax") }
        var next = index
        if (let Some(existing) <- indexGet(next, record.identity.nodeId)) {
            if (parentId.isSome() || !refEq(existing.node, record)) { throw IllegalArgumentException("Duplicate stable node ID") }
            return next
        }
        next = indexSet(next, record.identity.nodeId, SyntaxIndexEntry(record, parentId, childIndex, auxiliary: true, ownerId: ownerId))
        for (i in 0..record.childCount) { next = insertAuxiliary(next, record.childAt(i), Some(record.identity.nodeId), i, documentId, ownerId) }
        return next
    }
    public func atVersion(version: Int64): PersistentDocumentVersion {
        if (version < this.version) { throw IllegalArgumentException("Regressing syntax version") }
        return PersistentDocumentVersion(documentId, version, rawRoot, index, source, removedIds: removedInOperation)
    }
    public func removedNodeIds(): Array<Int64> { return removedInOperation.clone() }
    public func auxiliaryOwnerId(nodeId: Int64): ?Int64 {
        if (let Some(entry) <- indexGet(index, nodeId)) { if (entry.auxiliary) { return Some(entry.ownerId) } }; return None
    }
    public func ownsAuxiliaryReference(ownerId: Int64, targetId: Int64): Bool {
        if (let Some(owner) <- auxiliaryOwnerId(targetId)) {
            if (owner == ownerId) { return true }
            for (id in pathTo(owner)) { if (id == ownerId) { return true } }
        }; return false
    }
    public func find(nodeId: Int64): ?PersistentSyntaxNode {
        if (let Some(entry) <- indexGet(index, nodeId)) { return Some(entry.node) }; return None
    }
    public func raw(nodeId: Int64): ?RawSyntaxNode {
        if (let Some(entry) <- indexGet(index, nodeId)) { return Some(entry.node) }; return None
    }
    public func view(nodeId: Int64): ?SyntaxNodeView {
        if (let Some(node) <- raw(nodeId)) { return Some(SyntaxNodeView(this, node)) }; return None
    }
    public func parentOf(nodeId: Int64): ?SyntaxNodeView {
        if (let Some(entry) <- indexGet(index, nodeId)) {
            if (let Some(parentId) <- entry.parentId) { return view(parentId) }
        }; return None
    }
    public func pathTo(nodeId: Int64): Array<Int64> {
        let reversed = ArrayList<Int64>()
        var entry = indexGet(index, nodeId)
        while (let Some(current) <- entry) {
            reversed.add(current.node.identity.nodeId)
            if (let Some(parentId) <- current.parentId) { entry = indexGet(index, parentId) } else { break }
        }
        return Array<Int64>(reversed.size, { i => reversed[reversed.size - i - 1] })
    }
    public func nodesInByteRange(start: Int64, end: Int64): Array<RawSyntaxNode> {
        if (start < 0 || end < start) { throw IllegalArgumentException("Invalid syntax query range") }
        let output = ArrayList<RawSyntaxNode>()
        queryRange(rawRoot, start, end, output)
        return output.toArray()
    }
    private func queryRange(node: RawSyntaxNode, start: Int64, end: Int64, output: ArrayList<RawSyntaxNode>): Unit {
        let begin = resolve(node.startAnchor); let finish = resolve(node.endAnchor)
        if (begin.isSome() && finish.isSome() && begin.getOrThrow() <= end && finish.getOrThrow() >= start) { output.add(node) }
        for (child in node.overlappingChildren(start, end, { anchor => resolve(anchor) })) { queryRange(child, start, end, output) }
    }
    public func resolve(anchor: SourceAnchor): ?Int64 {
        return resolveAt(anchor, version)
    }
    // Read coordinates in an immutable earlier source view without forging a
    // historical syntax snapshot. A pruned/foreign source remains unresolved.
    public func resolveAtVersion(anchor: SourceAnchor, targetVersion: Int64): ?Int64 {
        if (targetVersion < 0 || targetVersion > version) { return None }
        return resolveAt(anchor, targetVersion)
    }
    private func resolveAt(anchor: SourceAnchor, targetVersion: Int64): ?Int64 {
        if (anchor.source.documentId != documentId) { return None }
        if (anchor.source.version == targetVersion) { return Some(anchor.byteOffset) }
        if (let Some(store) <- source) { return store.resolve(anchor, targetVersion) }; return None
    }
    public func resolvedSpan(node: RawSyntaxNode): ?SourceSpan {
        let start = resolve(node.startAnchor); let end = resolve(node.endAnchor)
        if (start.isNone() || end.isNone()) { return None }
        if (let Some(view) <- sourceView) {
                let s = view.coordinateAtByte(start.getOrThrow())
                let e = view.coordinateAtByte(end.getOrThrow())
                if (s.isSome() && e.isSome()) {
                    return Some(SourceSpan(start.getOrThrow(), end.getOrThrow(), s.getOrThrow().runeOffset, e.getOrThrow().runeOffset))
                }
        }
        if (let typed: MaterializableNodePayload <- node.payload) {
            if (node.startAnchor.source.version == version && node.endAnchor.source.version == version) { return typed.originalSpan() }
        }
        if (let text: PersistentTextPayload <- node.payload) {
            if (node.startAnchor.source.version == version && node.endAnchor.source.version == version) { return text.originalSpan() }
        }
        return None
    }
    public func replacing(nodeId: Int64, replacement: RawSyntaxNode, targetVersion: Int64): PersistentDocumentVersion {
        return replacingBundle(nodeId, PersistentNodeBundle(replacement), targetVersion)
    }
    // Payload changes preserve the structural sequence and its stable IDs. Only
    // outgoing auxiliary references and the copied ancestor path are touched.
    public func replacingPayload(nodeId: Int64, payload: SyntaxNodePayload, targetVersion: Int64): PersistentDocumentVersion {
        if (targetVersion < version) { throw IllegalArgumentException("Regressing syntax version") }
        let previous = indexGet(index, nodeId).getOrThrow()
        let replacement = previous.node.withPayload(payload, targetVersion)
        let deltas = HashMap<Int64, Int64>()
        for (id in previous.node.referenceIds()) { deltas[id] = (deltas.get(id) ?? 0) - 1 }
        for (id in replacement.referenceIds()) { deltas[id] = (deltas.get(id) ?? 0) + 1 }
        let removedIncoming = HashMap<Int64, Int64>()
        let seeds = ArrayList<Int64>(); let removed = ArrayList<Int64>()
        var nextIndex = indexSet(index, nodeId, SyntaxIndexEntry(replacement, previous.parentId, previous.childIndex,
            auxiliary: previous.auxiliary, incoming: previous.incoming, ownerId: previous.ownerId))
        for ((id, amount) in deltas) {
            if (amount == 0) { continue }
            nextIndex = graphAdjust(nextIndex, id, amount, removedIncoming)
            if (amount < 0) { seeds.add(id) }
        }
        nextIndex = graphCollectGarbage(nextIndex, seeds, removedIncoming, removed)
        var updatedBranch = replacement; var childEntry = previous
        while (let Some(parentId) <- childEntry.parentId) {
            let parent = indexGet(nextIndex, parentId).getOrThrow()
            updatedBranch = parent.node.withChildMapped(parent.node.childPosition(childEntry.node.identity.nodeId), updatedBranch,
                targetVersion, { anchor => resolveAt(anchor, targetVersion) })
            nextIndex = indexSet(nextIndex, parentId, SyntaxIndexEntry(updatedBranch, parent.parentId, parent.childIndex,
                auxiliary: parent.auxiliary, incoming: parent.incoming, ownerId: parent.ownerId))
            childEntry = parent
        }
        let nextRoot = if (childEntry.node.identity.nodeId == rawRoot.identity.nodeId) { updatedBranch } else { rawRoot }
        return PersistentDocumentVersion(documentId, targetVersion, nextRoot, nextIndex, source, removedIds: removed.toArray())
    }
    public func replacingBundle(nodeId: Int64, bundle: PersistentNodeBundle, targetVersion: Int64): PersistentDocumentVersion {
        let replacement = bundle.root
        let previous = indexGet(index, nodeId).getOrThrow()
        if (targetVersion < version) { throw IllegalArgumentException("Regressing syntax version") }
        let removed = ArrayList<Int64>()
        var nextIndex = graphChange(index, [previous.node], [bundle], previous.parentId, previous.childIndex,
            documentId, removed, targetVersion, { anchor => resolveAt(anchor, targetVersion) }, structuralIsAuxiliary: previous.auxiliary)
        var updatedBranch = replacement
        var childEntry = previous
        while (let Some(parentId) <- childEntry.parentId) {
            let parent = indexGet(index, parentId).getOrThrow()
            updatedBranch = parent.node.withChildMapped(parent.node.childPosition(childEntry.node.identity.nodeId), updatedBranch, targetVersion,
                { anchor => resolveAt(anchor, targetVersion) })
            let counts = indexGet(nextIndex, parentId).getOrThrow()
            nextIndex = indexSet(nextIndex, parentId, SyntaxIndexEntry(updatedBranch, parent.parentId, parent.childIndex,
                auxiliary: counts.auxiliary, incoming: counts.incoming, ownerId: counts.ownerId))
            childEntry = parent
        }
        let nextRoot = if (childEntry.node.identity.nodeId == rawRoot.identity.nodeId) { updatedBranch } else { rawRoot }
        return PersistentDocumentVersion(documentId, targetVersion, nextRoot, nextIndex, source, removedIds: removed.toArray())
    }
    public func splicingChildren(parentId: Int64, start: Int64, deleteCount: Int64,
        inserted: Array<RawSyntaxNode>, targetVersion: Int64): PersistentDocumentVersion {
        return splicingBundles(parentId, start, deleteCount,
            Array<PersistentNodeBundle>(inserted.size, { i => PersistentNodeBundle(inserted[i]) }), targetVersion)
    }
    public func splicingBundles(parentId: Int64, start: Int64, deleteCount: Int64,
        bundles: Array<PersistentNodeBundle>, targetVersion: Int64): PersistentDocumentVersion {
        let inserted = Array<RawSyntaxNode>(bundles.size, { i => bundles[i].root })
        if (targetVersion < version) { throw IllegalArgumentException("Regressing syntax version") }
        let previous = indexGet(index, parentId).getOrThrow()
        let nextParent = previous.node.splicingChildren(start, deleteCount, inserted, targetVersion,
            { anchor => resolveAt(anchor, targetVersion) })
        for (node in inserted) { if (node.version > targetVersion) { throw IllegalArgumentException("Future inserted syntax") } }
        let removed = ArrayList<Int64>()
        let oldRoots = Array<RawSyntaxNode>(deleteCount, { i => previous.node.childAt(start + i) })
        var nextIndex = graphChange(index, oldRoots, bundles, Some(parentId), start, documentId, removed,
            targetVersion, { anchor => resolveAt(anchor, targetVersion) }, structuralIsAuxiliary: previous.auxiliary)
        let parentCounts = indexGet(nextIndex, parentId).getOrThrow()
        nextIndex = indexSet(nextIndex, parentId, SyntaxIndexEntry(nextParent, previous.parentId, previous.childIndex,
            auxiliary: parentCounts.auxiliary, incoming: parentCounts.incoming, ownerId: parentCounts.ownerId))
        var updatedBranch = nextParent
        var childEntry = previous
        while (let Some(ancestorId) <- childEntry.parentId) {
            let ancestor = indexGet(index, ancestorId).getOrThrow()
            updatedBranch = ancestor.node.withChildMapped(ancestor.node.childPosition(childEntry.node.identity.nodeId),
                updatedBranch, targetVersion, { anchor => resolveAt(anchor, targetVersion) })
            let counts = indexGet(nextIndex, ancestorId).getOrThrow()
            nextIndex = indexSet(nextIndex, ancestorId, SyntaxIndexEntry(updatedBranch, ancestor.parentId, ancestor.childIndex,
                auxiliary: counts.auxiliary, incoming: counts.incoming, ownerId: counts.ownerId))
            childEntry = ancestor
        }
        let nextRoot = if (childEntry.node.identity.nodeId == rawRoot.identity.nodeId) { updatedBranch } else { rawRoot }
        return PersistentDocumentVersion(documentId, targetVersion, nextRoot, nextIndex, source, removedIds: removed.toArray())
    }

    // Explicit detached legacy graph export. Repeated exports never share a
    // mutable Node, metadata map, parent link or codec-owned array.
    public func materializeLegacy(nodeId!: ?Int64 = None): Node {
        let memo = HashMap<Int64, Node>()
        let pending = ArrayList<Int64>()
        let result = materializeNode(nodeId ?? rawRoot.identity.nodeId, memo, pending)
        var cursor: Int64 = 0
        while (cursor < pending.size) {
            let id = pending[cursor]; cursor += 1
            let record = raw(id).getOrThrow()
            if (let typed: MaterializableNodePayload <- record.payload) {
                let ids = typed.references()
                let refs = Array<Node>(ids.size, { i => materializeNode(ids[i], memo, pending) })
                typed.restore(memo.get(id).getOrThrow(), refs)
            }
        }
        return result
    }
    private func materializeNode(id: Int64, memo: HashMap<Int64, Node>, pending: ArrayList<Int64>): Node {
        if (let Some(existing) <- memo.get(id)) { return existing }
        let record = raw(id).getOrThrow()
        let payload = record.payload
        var copy: Node
        var sourceDerivedRaw = false
        if (let typed: MaterializableNodePayload <- payload) {
            copy = typed.materializeShallow(); sourceDerivedRaw = typed.rawContentFollowsSource()
        }
        else if (let text: PersistentTextPayload <- payload) {
            copy = text.materializeNode(id, resolvedSpan(record) ?? SourceSpan.empty())
        } else { throw IllegalArgumentException("No typed legacy decoder for payload " + payload.codecId) }
        if (copy.id != id || !copy.children.isEmpty() || copy.parent.isSome()) {
            throw IllegalArgumentException("Invalid materialized shallow node")
        }
        memo[id] = copy; pending.add(id)
        if (let Some(span) <- resolvedSpan(record)) { copy.sourceSpan = span }
        if (sourceDerivedRaw) {
            if (let Some(view) <- sourceView) {
                copy.setRawContent(view.sliceBytes(copy.sourceSpan.startByte, copy.sourceSpan.endByte))
            }
        }
        if (copy is DocumentNode) {
            if (let Some(view) <- sourceView) {
                // Only explicit legacy export materializes whole document raw.
                // It reads this snapshot's immutable source version, never the
                // prototype's old mutable append buffer or the latest store.
                copy.sourceSpan = SourceSpan(0, view.byteLength, 0, view.runeLength)
                if (sourceDerivedRaw) { copy.setRawContent(view.sliceBytes(0, view.byteLength)) }
            }
        }
        for (i in 0..record.childCount) {
            let child = materializeNode(record.childAt(i).identity.nodeId, memo, pending)
            child.parent = Some(copy)
            // addChild would recursively rebind source and erase exact bindings.
            copy.children.add(child)
        }
        return copy
    }
}

public class PersistentDocumentStore <: PersistentSyntaxStore {
    private var published: PersistentDocumentVersion
    public PersistentDocumentStore(initial: PersistentDocumentVersion) { this.published = initial }
    public prop current: PersistentSyntaxVersion { get() { return published } }
    public prop snapshot: PersistentDocumentVersion { get() { return published } }
    public func beginTransaction(expectedVersion: Int64): SyntaxEditTransaction {
        return beginPreparedTransaction(expectedVersion)
    }
    public func beginPreparedTransaction(expectedVersion: Int64): PersistentDocumentTransaction {
        if (expectedVersion != published.version) { throw IllegalArgumentException("Stale syntax transaction") }
        return PersistentDocumentTransaction(this, published)
    }
    public func validates(expected: PersistentDocumentVersion): Bool { return refEq(expected, published) }
    // The engine validates every participant before this assignment, under its
    // single-thread publication gate. No provider work is performed here.
    public func installPrepared(next: PersistentDocumentVersion): Unit { published = next }
    public func publish(expected: PersistentDocumentVersion, next: PersistentDocumentVersion): Unit {
        if (!refEq(expected, published)) { throw IllegalArgumentException("Stale syntax commit") }
        published = next
    }
}

public class PersistentDocumentTransaction <: SyntaxEditTransaction {
    private let store: PersistentDocumentStore
    private let original: PersistentDocumentVersion
    private var staged: PersistentDocumentVersion
    private var active: Bool = true
    private var preparedCandidate: ?PersistentDocumentVersion = None
    private let removedOwners = HashMap<Int64, Bool>()
    public prop expectedVersion: Int64 { get() { return original.version } }
    public PersistentDocumentTransaction(store: PersistentDocumentStore, original: PersistentDocumentVersion) {
        this.store = store; this.original = original; this.staged = original
    }
    public func replace(nodeId: Int64, replacement: PersistentSyntaxNode): Unit {
        if (!active || preparedCandidate.isSome()) { throw IllegalArgumentException("Closed/prepared syntax transaction") }
        if (let raw: RawSyntaxNode <- replacement) {
            replaceBundle(nodeId, PersistentNodeBundle(raw))
        }
        else { throw IllegalArgumentException("Persistent store requires detached raw records") }
    }
    public func replaceBundle(nodeId: Int64, bundle: PersistentNodeBundle): Unit {
        if (!active || preparedCandidate.isSome()) { throw IllegalArgumentException("Closed/prepared syntax transaction") }
        let next = staged.replacingBundle(nodeId, bundle, if (bundle.root.version > staged.version) { bundle.root.version } else { staged.version })
        for (id in next.removedNodeIds()) { removedOwners[id] = true }
        staged = next
    }
    public func spliceChildren(parentId: Int64, start: Int64, deleteCount: Int64,
        inserted: Array<RawSyntaxNode>, targetVersion: Int64): Unit {
        if (!active || preparedCandidate.isSome()) { throw IllegalArgumentException("Closed/prepared syntax transaction") }
        spliceBundles(parentId, start, deleteCount,
            Array<PersistentNodeBundle>(inserted.size, { i => PersistentNodeBundle(inserted[i]) }), targetVersion)
    }
    public func spliceBundles(parentId: Int64, start: Int64, deleteCount: Int64,
        bundles: Array<PersistentNodeBundle>, targetVersion: Int64): Unit {
        if (!active || preparedCandidate.isSome()) { throw IllegalArgumentException("Closed/prepared syntax transaction") }
        let next = staged.splicingBundles(parentId, start, deleteCount, bundles, targetVersion)
        for (id in next.removedNodeIds()) { removedOwners[id] = true }
        staged = next
    }
    public func removedNodeIds(): Array<Int64> {
        let ids = ArrayList<Int64>()
        for ((id, _) in removedOwners) { ids.add(id) }
        return ids.toArray()
    }
    public func replacePayload(nodeId: Int64, payload: SyntaxNodePayload, targetVersion: Int64): Unit {
        if (!active || preparedCandidate.isSome()) { throw IllegalArgumentException("Closed/prepared syntax transaction") }
        let next = staged.replacingPayload(nodeId, payload, targetVersion)
        for (id in next.removedNodeIds()) { removedOwners[id] = true }
        staged = next
    }
    public func preview(sourceVersion: Int64): PersistentDocumentVersion {
        if (!active || !store.validates(original)) { throw IllegalArgumentException("Closed/stale syntax preview") }
        return staged.atVersion(sourceVersion)
    }
    public func commit(sourceVersion: Int64): PersistentSyntaxVersion {
        let next = prepare(sourceVersion)
        if (!validatePrepared(next)) { throw IllegalArgumentException("Stale syntax commit") }
        installPrepared(next)
        return next
    }
    public func prepare(sourceVersion: Int64): PersistentDocumentVersion {
        if (!active || sourceVersion <= expectedVersion) { throw IllegalArgumentException("Closed/stale syntax commit") }
        if (let Some(candidate) <- preparedCandidate) {
            if (candidate.version != sourceVersion) { throw IllegalArgumentException("Syntax candidate version changed") }
            return candidate
        }
        // Replacing root with itself updates just the version shell/path; the
        // raw root and all IDs remain shared for an empty syntax transaction.
        let next = staged.atVersion(sourceVersion)
        if (!store.validates(original)) { throw IllegalArgumentException("Stale syntax preparation") }
        preparedCandidate = Some(next)
        return next
    }
    public func validatePrepared(candidate: PersistentDocumentVersion): Bool {
        return active && preparedCandidate.isSome() && refEq(preparedCandidate.getOrThrow(), candidate) && store.validates(original)
    }
    public func installPrepared(candidate: PersistentDocumentVersion): Unit {
        store.installPrepared(candidate)
        active = false
        preparedCandidate = None
    }
    public func cancel(): Unit { active = false; preparedCandidate = None }
}
