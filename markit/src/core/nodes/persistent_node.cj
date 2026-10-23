package markit.core.nodes

import markit.core.editing.*
import markit.core.source.SourceSpan
import std.collection.{ArrayList, HashMap}

// Optional opaque-payload reference capability, independent of plugin names.
public interface SyntaxReferencePayload <: SyntaxNodePayload {
    func references(): Array<Int64>
}
// Explicit legacy export capability. Providers may retain immutable views and
// persistent child-session state instead of eagerly constructing typed strings.
public interface MaterializableNodePayload <: SyntaxReferencePayload {
    func materializeShallow(): Node
    func restore(target: Node, references: Array<Node>): Unit
    func rawContentFollowsSource(): Bool { return false }
    func originalSpan(): ?SourceSpan { return None }
    // Initial child-session handoff includes every auxiliary binding. Normal
    // payload-only updates do not call capture or enumerate these children.
    func captureChildren(): ?Array<PersistentNodeBundle> { return None }
}
public interface SyntaxReferenceRegistry <: PersistentSyntaxVersion {
    func ownsAuxiliaryReference(ownerId: Int64, targetId: Int64): Bool
}

// Fractional lexicographic keys give inserted siblings an order without
// renumbering any existing sibling. The digit array never escapes this class.
private class ChildOrderKey {
    private let digits: Array<Int64>
    public ChildOrderKey(digits: Array<Int64>) { this.digits = digits.clone() }
    public func compare(other: ChildOrderKey): Int64 {
        let count = if (digits.size < other.digits.size) { digits.size } else { other.digits.size }
        for (i in 0..count) {
            if (digits[i] < other.digits[i]) { return -1 }; if (digits[i] > other.digits[i]) { return 1 }
        }
        return if (digits.size < other.digits.size) { -1 } else if (digits.size > other.digits.size) { 1 } else { 0 }
    }
    public static func between(left: ?ChildOrderKey, right: ?ChildOrderKey): ChildOrderKey {
        let output = ArrayList<Int64>()
        var depth: Int64 = 0; var unboundedRight = right.isNone()
        while (true) {
            let a = if (left.isSome() && depth < left.getOrThrow().digits.size) { left.getOrThrow().digits[depth] } else { 0 }
            let b = if (!unboundedRight && depth < right.getOrThrow().digits.size) { right.getOrThrow().digits[depth] } else { 9223372036854775807 }
            if (b - a > 1) { output.add(a + (b - a) / 2); return ChildOrderKey(output.toArray()) }
            output.add(a)
            if (a < b) { unboundedRight = true }
            depth += 1
        }
        throw IllegalArgumentException("Unable to allocate sibling order key")
    }
}

private class ChildKeyIndex {
    public let id: Int64
    public let key: ChildOrderKey
    public let left: ?ChildKeyIndex
    public let right: ?ChildKeyIndex
    public let height: Int64
    public ChildKeyIndex(id: Int64, key: ChildOrderKey, left: ?ChildKeyIndex, right: ?ChildKeyIndex) {
        this.id = id; this.key = key; this.left = left; this.right = right
        let a = childKeyHeight(left); let b = childKeyHeight(right)
        this.height = 1 + if (a > b) { a } else { b }
    }
}
private func childKeyHeight(root: ?ChildKeyIndex): Int64 {
    if (let Some(node) <- root) { return node.height }; return 0
}
private func childKeyGet(root: ?ChildKeyIndex, id: Int64): ?ChildOrderKey {
    if (let Some(node) <- root) {
        if (id == node.id) { return Some(node.key) }
        return childKeyGet(if (id < node.id) { node.left } else { node.right }, id)
    }; return None
}
private func childKeyBalance(id: Int64, key: ChildOrderKey, left: ?ChildKeyIndex, right: ?ChildKeyIndex): ChildKeyIndex {
    if (childKeyHeight(left) > childKeyHeight(right) + 1) {
        let l = left.getOrThrow()
        if (childKeyHeight(l.left) >= childKeyHeight(l.right)) {
            return ChildKeyIndex(l.id, l.key, l.left, Some(ChildKeyIndex(id, key, l.right, right)))
        }
        let m = l.right.getOrThrow()
        return ChildKeyIndex(m.id, m.key, Some(ChildKeyIndex(l.id, l.key, l.left, m.left)), Some(ChildKeyIndex(id, key, m.right, right)))
    }
    if (childKeyHeight(right) > childKeyHeight(left) + 1) {
        let r = right.getOrThrow()
        if (childKeyHeight(r.right) >= childKeyHeight(r.left)) {
            return ChildKeyIndex(r.id, r.key, Some(ChildKeyIndex(id, key, left, r.left)), r.right)
        }
        let m = r.left.getOrThrow()
        return ChildKeyIndex(m.id, m.key, Some(ChildKeyIndex(id, key, left, m.left)), Some(ChildKeyIndex(r.id, r.key, m.right, r.right)))
    }
    return ChildKeyIndex(id, key, left, right)
}
private func childKeySet(root: ?ChildKeyIndex, id: Int64, key: ChildOrderKey): ?ChildKeyIndex {
    if (let Some(node) <- root) {
        if (id < node.id) { return Some(childKeyBalance(node.id, node.key, childKeySet(node.left, id, key), node.right)) }
        if (id > node.id) { return Some(childKeyBalance(node.id, node.key, node.left, childKeySet(node.right, id, key))) }
        return Some(ChildKeyIndex(id, key, node.left, node.right))
    }; return Some(ChildKeyIndex(id, key, None, None))
}
private func childKeyRemove(root: ?ChildKeyIndex, id: Int64): ?ChildKeyIndex {
    if (root.isNone()) { return None }; let node = root.getOrThrow()
    if (id < node.id) { return Some(childKeyBalance(node.id, node.key, childKeyRemove(node.left, id), node.right)) }
    if (id > node.id) { return Some(childKeyBalance(node.id, node.key, node.left, childKeyRemove(node.right, id))) }
    if (node.left.isNone()) { return node.right }; if (node.right.isNone()) { return node.left }
    var next = node.right.getOrThrow()
    while (next.left.isSome()) { next = next.left.getOrThrow() }
    return Some(childKeyBalance(next.id, next.key, node.left, childKeyRemove(node.right, next.id)))
}

// A binary persistent vector avoids copying the document root's entire sibling
// array when one child changes.
private class RawChildSequence {
    public let count: Int64
    public let height: Int64
    public let firstKey: ChildOrderKey
    public let lastKey: ChildOrderKey
    public let earliestVersion: Int64
    private let value: ?RawSyntaxNode
    private let left: ?RawChildSequence
    private let right: ?RawChildSequence
    private let low: ?SourceAnchor
    private let high: ?SourceAnchor
    public RawChildSequence(value: RawSyntaxNode, key: ChildOrderKey) {
        this.value = Some(value); this.left = None; this.right = None; this.count = 1
        this.height = 1; this.firstKey = key; this.lastKey = key; this.earliestVersion = value.earliestAnchorVersion
        this.low = Some(value.startAnchor); this.high = Some(value.endAnchor)
    }
    public init(left: RawChildSequence, right: RawChildSequence) {
        this.value = None; this.left = Some(left); this.right = Some(right); this.count = left.count + right.count
        this.height = 1 + if (left.height > right.height) { left.height } else { right.height }
        this.firstKey = left.firstKey; this.lastKey = right.lastKey
        this.earliestVersion = if (left.earliestVersion < right.earliestVersion) { left.earliestVersion } else { right.earliestVersion }
        this.low = selectBoundary(left.low, right.low, true)
        this.high = selectBoundary(left.high, right.high, false)
    }
    public init(left: RawChildSequence, right: RawChildSequence, resolve: (SourceAnchor) -> ?SourceAnchor) {
        this.value = None; this.left = Some(left); this.right = Some(right); this.count = left.count + right.count
        this.height = 1 + if (left.height > right.height) { left.height } else { right.height }
        this.firstKey = left.firstKey; this.lastKey = right.lastKey
        this.earliestVersion = if (left.earliestVersion < right.earliestVersion) { left.earliestVersion } else { right.earliestVersion }
        this.low = selectBoundary(mapBoundary(left.low, resolve), mapBoundary(right.low, resolve), true)
        this.high = selectBoundary(mapBoundary(left.high, resolve), mapBoundary(right.high, resolve), false)
    }
    private static func mapBoundary(anchor: ?SourceAnchor, resolve: (SourceAnchor) -> ?SourceAnchor): ?SourceAnchor {
        if (let Some(value) <- anchor) { return resolve(value) }; return None
    }
    private static func selectBoundary(a: ?SourceAnchor, b: ?SourceAnchor, minimum: Bool): ?SourceAnchor {
        if (a.isNone() || b.isNone()) { return None }
        let x = a.getOrThrow(); let y = b.getOrThrow()
        if (x.source.documentId != y.source.documentId || x.source.version != y.source.version) { return None }
        if (x.byteOffset == y.byteOffset) {
            return if ((minimum && x.affinity == AnchorAffinity.Before) || (!minimum && x.affinity == AnchorAffinity.After)) { a } else { b }
        }
        return if ((minimum && x.byteOffset < y.byteOffset) || (!minimum && x.byteOffset > y.byteOffset)) { a } else { b }
    }
    public func overlapping(start: Int64, end: Int64, resolve: (SourceAnchor) -> ?Int64,
        output: ArrayList<RawSyntaxNode>): Unit {
        if (low.isSome() && high.isSome()) {
            let begin = resolve(low.getOrThrow()); let finish = resolve(high.getOrThrow())
            if (begin.isSome() && finish.isSome() && (begin.getOrThrow() > end || finish.getOrThrow() < start)) { return }
        }
        if (let Some(node) <- value) { output.add(node); return }
        left.getOrThrow().overlapping(start, end, resolve, output)
        right.getOrThrow().overlapping(start, end, resolve, output)
    }
    public static func build(values: Array<RawSyntaxNode>, start: Int64, end: Int64): ?RawChildSequence {
        if (start == end) { return None }
        if (end - start == 1) { return Some(RawChildSequence(values[start], ChildOrderKey([start + 1]))) }
        let middle = start + (end - start) / 2
        return Some(RawChildSequence(build(values, start, middle).getOrThrow(), build(values, middle, end).getOrThrow()))
    }
    public func at(index: Int64): RawSyntaxNode {
        if (index < 0 || index >= count) { throw IllegalArgumentException("Child index out of range") }
        if (let Some(node) <- value) { return node }
        let l = left.getOrThrow()
        return if (index < l.count) { l.at(index) } else { right.getOrThrow().at(index - l.count) }
    }
    public func replacing(index: Int64, node: RawSyntaxNode): RawChildSequence {
        if (index < 0 || index >= count) { throw IllegalArgumentException("Child index out of range") }
        if (value.isSome()) { return RawChildSequence(node, firstKey) }
        let l = left.getOrThrow(); let r = right.getOrThrow()
        return if (index < l.count) { RawChildSequence(l.replacing(index, node), r) }
            else { RawChildSequence(l, r.replacing(index - l.count, node)) }
    }
    public func replacingMapped(index: Int64, node: RawSyntaxNode, resolve: (SourceAnchor) -> ?SourceAnchor): RawChildSequence {
        if (index < 0 || index >= count) { throw IllegalArgumentException("Child index out of range") }
        if (value.isSome()) { return RawChildSequence(node, firstKey) }
        let l = left.getOrThrow(); let r = right.getOrThrow()
        return if (index < l.count) { RawChildSequence(l.replacingMapped(index, node, resolve), r, resolve) }
            else { RawChildSequence(l, r.replacingMapped(index - l.count, node, resolve), resolve) }
    }
    public func keyAt(index: Int64): ChildOrderKey {
        if (index < 0 || index >= count) { throw IllegalArgumentException("Child key out of range") }
        if (value.isSome()) { return firstKey }
        let l = left.getOrThrow()
        return if (index < l.count) { l.keyAt(index) } else { right.getOrThrow().keyAt(index - l.count) }
    }
    public func rank(key: ChildOrderKey): Int64 {
        if (value.isSome()) {
            if (key.compare(firstKey) != 0) { throw IllegalArgumentException("Missing sibling key") }; return 0
        }
        let l = left.getOrThrow()
        return if (key.compare(l.lastKey) <= 0) { l.rank(key) } else { l.count + right.getOrThrow().rank(key) }
    }
    private static func balance(l: RawChildSequence, r: RawChildSequence,
        resolve: (SourceAnchor) -> ?SourceAnchor): RawChildSequence {
        if (l.height > r.height + 1) {
            let a = l.left.getOrThrow(); let b = l.right.getOrThrow()
            if (a.height >= b.height) { return RawChildSequence(a, RawChildSequence(b, r, resolve), resolve) }
            return RawChildSequence(RawChildSequence(a, b.left.getOrThrow(), resolve), RawChildSequence(b.right.getOrThrow(), r, resolve), resolve)
        }
        if (r.height > l.height + 1) {
            let a = r.left.getOrThrow(); let b = r.right.getOrThrow()
            if (b.height >= a.height) { return RawChildSequence(RawChildSequence(l, a, resolve), b, resolve) }
            return RawChildSequence(RawChildSequence(l, a.left.getOrThrow(), resolve), RawChildSequence(a.right.getOrThrow(), b, resolve), resolve)
        }
        return RawChildSequence(l, r, resolve)
    }
    public static func join(left: ?RawChildSequence, right: ?RawChildSequence,
        resolve: (SourceAnchor) -> ?SourceAnchor): ?RawChildSequence {
        if (left.isNone()) { return right }; if (right.isNone()) { return left }
        let l = left.getOrThrow(); let r = right.getOrThrow()
        if (l.height > r.height + 1) { return Some(balance(l.left.getOrThrow(), join(l.right, right, resolve).getOrThrow(), resolve)) }
        if (r.height > l.height + 1) { return Some(balance(join(left, r.left, resolve).getOrThrow(), r.right.getOrThrow(), resolve)) }
        return Some(RawChildSequence(l, r, resolve))
    }
    public static func split(root: ?RawChildSequence, count: Int64,
        resolve: (SourceAnchor) -> ?SourceAnchor): (?RawChildSequence, ?RawChildSequence) {
        if (root.isNone()) { if (count != 0) { throw IllegalArgumentException("Invalid child split") }; return (None, None) }
        let node = root.getOrThrow()
        if (count < 0 || count > node.count) { throw IllegalArgumentException("Invalid child split") }
        if (count == 0) { return (None, root) }; if (count == node.count) { return (root, None) }
        let l = node.left.getOrThrow()
        if (count < l.count) { let (a, b) = split(node.left, count, resolve); return (a, join(b, node.right, resolve)) }
        let (a, b) = split(node.right, count - l.count, resolve); return (join(node.left, a, resolve), b)
    }
}

// The raw record has no mutable parent, absolute-position rewrite, or semantic
// projection. Arrays and provider payloads are detached at the public boundary.
public class RawSyntaxNode <: PersistentSyntaxNode {
    private let nodeIdentity: SyntaxNodeIdentity
    private let bornVersion: Int64
    private let beginAnchor: SourceAnchor
    private let finishAnchor: SourceAnchor
    private let data: SyntaxNodePayload
    private let childRecords: ?RawChildSequence
    private let childKeys: ?ChildKeyIndex
    private let earliestVersion: Int64
    private let referencedIds: Array<Int64>

    public RawSyntaxNode(identity: SyntaxNodeIdentity, version: Int64, startAnchor: SourceAnchor,
        endAnchor: SourceAnchor, payload: SyntaxNodePayload, children!: Array<RawSyntaxNode> = []) {
        if (version < 0 || identity.documentId != startAnchor.source.documentId ||
            identity.documentId != endAnchor.source.documentId) {
            throw IllegalArgumentException("Raw syntax/source identity mismatch")
        }
        this.nodeIdentity = identity
        this.bornVersion = version
        this.beginAnchor = startAnchor
        this.finishAnchor = endAnchor
        this.data = payload.clonePayload()
        this.referencedIds = referencesOf(this.data)
        this.childRecords = RawChildSequence.build(children, 0, children.size)
        var keys: ?ChildKeyIndex = None
        for (i in 0..children.size) {
            if (childKeyGet(keys, children[i].identity.nodeId).isSome()) { throw IllegalArgumentException("Duplicate sibling ID") }
            keys = childKeySet(keys, children[i].identity.nodeId, ChildOrderKey([i + 1]))
        }
        this.childKeys = keys
        this.earliestVersion = minimumVersion(startAnchor, endAnchor, childRecords)
    }
    private init(identity: SyntaxNodeIdentity, version: Int64, startAnchor: SourceAnchor,
        endAnchor: SourceAnchor, payload: SyntaxNodePayload, sequence: ?RawChildSequence, keys: ?ChildKeyIndex,
        references: Array<Int64>) {
        this.nodeIdentity = identity; this.bornVersion = version
        this.beginAnchor = startAnchor; this.finishAnchor = endAnchor
        this.data = payload; this.childRecords = sequence
        this.childKeys = keys; this.earliestVersion = minimumVersion(startAnchor, endAnchor, sequence)
        this.referencedIds = references
    }
    private static func referencesOf(payload: SyntaxNodePayload): Array<Int64> {
        if (let referenced: SyntaxReferencePayload <- payload) { return referenced.references().clone() }; return []
    }
    private static func minimumVersion(start: SourceAnchor, end: SourceAnchor, children: ?RawChildSequence): Int64 {
        let own = if (start.source.version < end.source.version) { start.source.version } else { end.source.version }
        if (let Some(sequence) <- children) { return if (sequence.earliestVersion < own) { sequence.earliestVersion } else { own } }
        return own
    }

    public prop identity: SyntaxNodeIdentity { get() { return nodeIdentity } }
    public prop version: Int64 { get() { return bornVersion } }
    public prop startAnchor: SourceAnchor { get() { return beginAnchor } }
    public prop endAnchor: SourceAnchor { get() { return finishAnchor } }
    public prop payload: SyntaxNodePayload { get() { return data.clonePayload() } }
    public prop childCount: Int64 { get() { return childRecords.map({ sequence => sequence.count }) ?? 0 } }
    public prop earliestAnchorVersion: Int64 { get() { return earliestVersion } }
    public prop childrenHeight: Int64 { get() { return childRecords.map({ sequence => sequence.height }) ?? 0 } }
    public func childPosition(nodeId: Int64): Int64 { return childRecords.getOrThrow().rank(childKeyGet(childKeys, nodeId).getOrThrow()) }
    public func containsChild(nodeId: Int64): Bool { return childKeyGet(childKeys, nodeId).isSome() }
    public func referenceIds(): Array<Int64> { return referencedIds.clone() }
    public func childAt(index: Int64): RawSyntaxNode { return childRecords.getOrThrow().at(index) }
    public func overlappingChildren(start: Int64, end: Int64, resolve: (SourceAnchor) -> ?Int64): Array<RawSyntaxNode> {
        let output = ArrayList<RawSyntaxNode>()
        if (let Some(sequence) <- childRecords) { sequence.overlapping(start, end, resolve, output) }
        return output.toArray()
    }
    public func children(): Array<PersistentSyntaxNode> {
        return Array<PersistentSyntaxNode>(childCount, { i => childAt(i) })
    }
    public func withChild(index: Int64, child: RawSyntaxNode, version: Int64): RawSyntaxNode {
        return withChildMapped(index, child, version, { anchor => if (anchor.source.version == version) { Some(anchor.byteOffset) } else { None } })
    }
    public func withChildMapped(index: Int64, child: RawSyntaxNode, version: Int64,
        resolve: (SourceAnchor) -> ?Int64): RawSyntaxNode {
        let target = SourceVersionIdentity(identity.documentId, version)
        let mapped = childRecords.getOrThrow().replacingMapped(index, child, { anchor =>
            if (let Some(offset) <- resolve(anchor)) { Some(SourceAnchor(target, offset, affinity: anchor.affinity)) } else { None }
        })
        let oldId = childAt(index).identity.nodeId
        var keys = childKeys
        if (oldId != child.identity.nodeId) {
            if (childKeyGet(keys, child.identity.nodeId).isSome()) { throw IllegalArgumentException("Duplicate sibling ID") }
            let key = childKeyGet(keys, oldId).getOrThrow()
            keys = childKeySet(childKeyRemove(keys, oldId), child.identity.nodeId, key)
        }
        let start = resolve(startAnchor); let end = resolve(endAnchor)
        return RawSyntaxNode(identity, version,
            if (start.isSome()) { SourceAnchor(target, start.getOrThrow(), affinity: startAnchor.affinity) } else { startAnchor },
            if (end.isSome()) { SourceAnchor(target, end.getOrThrow(), affinity: endAnchor.affinity) } else { endAnchor }, data, Some(mapped), keys, referencedIds)
    }
    public func withPayload(payload: SyntaxNodePayload, version: Int64): RawSyntaxNode {
        let copy = payload.clonePayload()
        return RawSyntaxNode(identity, version, startAnchor, endAnchor, copy, childRecords, childKeys, referencesOf(copy))
    }
    public func splicingChildren(start: Int64, deleteCount: Int64, inserted: Array<RawSyntaxNode>, version: Int64,
        resolve: (SourceAnchor) -> ?Int64): RawSyntaxNode {
        if (start < 0 || deleteCount < 0 || start > childCount || deleteCount > childCount - start) { throw IllegalArgumentException("Invalid child splice") }
        let target = SourceVersionIdentity(identity.documentId, version)
        let project: (SourceAnchor) -> ?SourceAnchor = { anchor =>
            if (let Some(offset) <- resolve(anchor)) { Some(SourceAnchor(target, offset, affinity: anchor.affinity)) } else { None }
        }
        let (before, remainder) = RawChildSequence.split(childRecords, start, project)
        let (_, after) = RawChildSequence.split(remainder, deleteCount, project)
        var keys = childKeys
        for (i in 0..deleteCount) { keys = childKeyRemove(keys, childAt(start + i).identity.nodeId) }
        var middle: ?RawChildSequence = None
        var preceding = before.map({ node => node.lastKey })
        let following = after.map({ node => node.firstKey })
        for (node in inserted) {
            if (childKeyGet(keys, node.identity.nodeId).isSome()) { throw IllegalArgumentException("Duplicate sibling ID") }
            let key = ChildOrderKey.between(preceding, following)
            keys = childKeySet(keys, node.identity.nodeId, key)
            middle = RawChildSequence.join(middle, Some(RawChildSequence(node, key)), project)
            preceding = Some(key)
        }
        let sequence = RawChildSequence.join(RawChildSequence.join(before, middle, project), after, project)
        let begin = resolve(startAnchor); let end = resolve(endAnchor)
        return RawSyntaxNode(identity, version,
            if (begin.isSome()) { SourceAnchor(target, begin.getOrThrow(), affinity: startAnchor.affinity) } else { startAnchor },
            if (end.isSome()) { SourceAnchor(target, end.getOrThrow(), affinity: endAnchor.affinity) } else { endAnchor }, data, sequence, keys, referencedIds)
    }
}

// The private prototype preserves every derived field and base metadata. It is
// never returned to consumers, and its children/additional references are IDs.
public class TypedSyntaxPayload <: MaterializableNodePayload {
    private let codec: NodeCodec
    private let prototype: Node
    private let referenceIds: Array<Int64>
    public let sourceDerivedRaw: Bool
    public prop codecId: String { get() { return "typed-node" } }

    public TypedSyntaxPayload(codec: NodeCodec, node: Node, references!: Array<Int64> = [], sourceDerivedRaw!: Bool = false) {
        this.codec = codec
        this.prototype = codec.copyShallow(node)
        this.referenceIds = references.clone()
        this.sourceDerivedRaw = sourceDerivedRaw
    }
    public func clonePayload(): SyntaxNodePayload {
        return TypedSyntaxPayload(codec, prototype, references: referenceIds, sourceDerivedRaw: sourceDerivedRaw)
    }
    public func materializeShallow(): Node { return codec.copyShallow(prototype) }
    public func references(): Array<Int64> { return referenceIds.clone() }
    public func restore(target: Node, references: Array<Node>): Unit { codec.restore(target, references) }
    public func rawContentFollowsSource(): Bool { return sourceDerivedRaw }
    public func originalSpan(): ?SourceSpan { return Some(prototype.sourceSpan) }
}

public class PersistentNodeBundle {
    public let root: RawSyntaxNode
    private let records: Array<RawSyntaxNode>
    private let owners: Array<Int64>
    public PersistentNodeBundle(root: RawSyntaxNode, records!: Array<RawSyntaxNode> = [], ownerIds!: Array<Int64> = []) {
        if (!ownerIds.isEmpty() && ownerIds.size != records.size) { throw IllegalArgumentException("Auxiliary owner count mismatch") }
        this.root = root
        this.records = records.clone()
        this.owners = if (ownerIds.isEmpty()) { Array<Int64>(records.size, repeat: root.identity.nodeId) } else { ownerIds.clone() }
    }
    public func auxiliaryRecords(): Array<RawSyntaxNode> { return records.clone() }
    public func auxiliaryOwnerIds(): Array<Int64> { return owners.clone() }
}

// Explicit legacy ingestion is linear in the supplied graph. It is not used
// for unchanged subtrees on commit. IDs serve as an O(1)-average graph memo.
public class PersistentNodeCapture {
    private let codec: NodeCodec
    public PersistentNodeCapture(codec: NodeCodec) { this.codec = codec }
    public func capture(root: Node, source: SourceVersionIdentity, existing!: ?PersistentSyntaxVersion = None): PersistentNodeBundle {
        if (existing.isSome() && existing.getOrThrow().documentId != source.documentId) { throw IllegalArgumentException("Cross-document capture references") }
        let originals = HashMap<Int64, Node>()
        let memo = HashMap<Int64, RawSyntaxNode>()
        let pending = ArrayList<(Node, Int64)>()
        let auxiliary = ArrayList<RawSyntaxNode>()
        let owners = ArrayList<Int64>()
        let result = captureTree(root, source, originals, memo, pending, None, auxiliary, owners)
        var cursor: Int64 = 0
        while (cursor < pending.size) {
            let (referenced, owner) = pending[cursor]
            cursor += 1
            if (let Some(original) <- originals.get(referenced.id)) {
                if (!refEq(original, referenced)) { throw IllegalArgumentException("Duplicate stable node ID") }
                continue
            }
            if (existing.isSome() && existing.getOrThrow().find(referenced.id).isSome()) {
                if (let registry: SyntaxReferenceRegistry <- existing.getOrThrow()) {
                    if (!registry.ownsAuxiliaryReference(root.id, referenced.id)) { continue }
                }
            }
            if (memo.contains(referenced.id)) { throw IllegalArgumentException("Typed reference aliases an opaque raw handoff") }
            auxiliary.add(captureTree(referenced, source, originals, memo, pending, Some(owner), auxiliary, owners))
            owners.add(owner)
        }
        return PersistentNodeBundle(result, records: auxiliary.toArray(), ownerIds: owners.toArray())
    }
    private func captureTree(node: Node, source: SourceVersionIdentity,
        originals: HashMap<Int64, Node>, memo: HashMap<Int64, RawSyntaxNode>, pending: ArrayList<(Node, Int64)>, auxOwner: ?Int64,
        auxiliary: ArrayList<RawSyntaxNode>, owners: ArrayList<Int64>): RawSyntaxNode {
        if (originals.contains(node.id) || memo.contains(node.id)) { throw IllegalArgumentException("Duplicate/cyclic child node ID") }
        originals[node.id] = node
        let custom = codec.capturePayload(node, source)
        var handed: ?Array<PersistentNodeBundle> = None
        if (let Some(value) <- custom) {
            if (let typed: MaterializableNodePayload <- value) { handed = typed.captureChildren() }
            else { throw IllegalArgumentException("Custom typed payload requires legacy export capability") }
        }
        var children: Array<RawSyntaxNode>
        if (let Some(bundles) <- handed) {
            if (!node.children.isEmpty()) { throw IllegalArgumentException("Ambiguous typed/raw child capture") }
            children = Array<RawSyntaxNode>(bundles.size, { i => bundles[i].root })
            for (bundle in bundles) {
                registerHandedTree(bundle.root, source, originals, memo)
                let records = bundle.auxiliaryRecords(); let recordOwners = bundle.auxiliaryOwnerIds()
                for (i in 0..records.size) {
                    validateHandedVersion(records[i], source)
                    auxiliary.add(records[i]); owners.add(recordOwners[i])
                }
            }
        } else {
            children = Array<RawSyntaxNode>(node.children.size, { i =>
                captureTree(node.children[i], source, originals, memo, pending, auxOwner, auxiliary, owners)
            })
        }
        let refs = codec.references(node)
        let ids = Array<Int64>(refs.size, { i => refs[i].id })
        for (reference in refs) { pending.add((reference, auxOwner ?? node.id)) }
        var payload: SyntaxNodePayload
        if (let Some(value) <- custom) {
            if (let typed: MaterializableNodePayload <- value) {
                let capturedIds = typed.references()
                if (capturedIds.size != ids.size) { throw IllegalArgumentException("Custom payload references mismatch") }
                for (i in 0..ids.size) {
                    if (capturedIds[i] != ids[i]) { throw IllegalArgumentException("Custom payload references mismatch") }
                }
                payload = value.clonePayload()
            } else { throw IllegalArgumentException("Custom typed payload requires legacy export capability") }
        } else {
        let prototype = codec.copyShallow(node)
        let sourceDerivedRaw = codec.rawContentFollowsSource(node, source)
        // Freeze the public shallow bridge even if the parser buffer later
        // rebinds. Provenance permits explicit snapshot export to refresh raw.
        // Capture visits only new/changed units, never copied ancestor paths.
        prototype.setRawContent(node.rawContent())
        payload = TypedSyntaxPayload(codec, prototype, references: ids, sourceDerivedRaw: sourceDerivedRaw)
        if (let text: TextNode <- node) {
            if (text.literal == text.content) { payload = PersistentTextPayload.fromNode(text) }
        }
        }
        let result = RawSyntaxNode(SyntaxNodeIdentity(source.documentId, node.id), source.version,
            SourceAnchor(source, node.sourceSpan.startByte, affinity: AnchorAffinity.Before),
            SourceAnchor(source, node.sourceSpan.endByte, affinity: AnchorAffinity.After), payload, children: children)
        memo[node.id] = result
        return result
    }
    private func registerHandedTree(node: RawSyntaxNode, source: SourceVersionIdentity,
        originals: HashMap<Int64, Node>, memo: HashMap<Int64, RawSyntaxNode>): Unit {
        if (node.identity.documentId != source.documentId || node.version > source.version ||
            originals.contains(node.identity.nodeId) || memo.contains(node.identity.nodeId)) {
            throw IllegalArgumentException("Foreign/future/duplicate raw child handoff")
        }
        memo[node.identity.nodeId] = node
        for (i in 0..node.childCount) { registerHandedTree(node.childAt(i), source, originals, memo) }
    }
    private func validateHandedVersion(node: RawSyntaxNode, source: SourceVersionIdentity): Unit {
        if (node.identity.documentId != source.documentId || node.version > source.version) {
            throw IllegalArgumentException("Foreign/future auxiliary handoff")
        }
        for (i in 0..node.childCount) { validateHandedVersion(node.childAt(i), source) }
    }
}
