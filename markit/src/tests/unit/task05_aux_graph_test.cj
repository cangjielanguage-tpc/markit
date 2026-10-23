package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.document.*
import markit.core.editing.*
import markit.core.nodes.*
import markit.core.session.OwnedEffectStore
import markit.core.source.{EditableRopeStore, SourceSpan}

// Only test grammar data lives here. The production capture/export machinery
// follows additionalReferences, including shared and cyclic typed aliases.
private class AuxGraphNode <: Node {
    public var detail: String
    public var rank: Int64
    public let references = ArrayList<Node>()
    public init(id: Int64, detail: String, rank: Int64, start!: Int64 = 0, end!: Int64 = 1) {
        super("AuxGraph", id: id, sourceSpan: SourceSpan(start, end, start, end), literal: detail)
        this.detail = detail
        this.rank = rank
    }
}

private class AuxGraphCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "task05-aux-graph" } }
    public func accepts(node: Node): Bool { return node is AuxGraphNode }
    public func createShallow(node: Node): Node {
        let typed = (node as AuxGraphNode).getOrThrow()
        return AuxGraphNode(typed.id, typed.detail, typed.rank,
            start: typed.sourceSpan.startByte, end: typed.sourceSpan.endByte)
    }
    public func additionalReferences(node: Node): Array<Node> {
        return (node as AuxGraphNode).getOrThrow().references.toArray()
    }
    public func restoreReferences(target: Node, references: Array<Node>): Unit {
        let typed = (target as AuxGraphNode).getOrThrow()
        for (reference in references) { typed.references.add(reference) }
    }
}

private func auxGraphCodec(): NodeCodec {
    let codec = NodeCodec()
    codec.register(AuxGraphCodec())
    return codec
}
private func auxTyped(node: Node): AuxGraphNode { return (node as AuxGraphNode).getOrThrow() }
private func auxExport(version: PersistentDocumentVersion): AuxGraphNode { return auxTyped(version.materializeLegacy()) }
private func auxContains(ids: Array<Int64>, id: Int64): Bool {
    for (candidate in ids) { if (candidate == id) { return true } }
    return false
}
private func auxAdvance(source: EditableRopeStore): Unit {
    let current = source.current
    // An explicit same-text edit advances the real source epoch without
    // changing geometry, making birth-floor assertions independent of syntax.
    source.applyEdits(current.identity.version,
        [EditingTextEdit(EditingRange(0, 1), current.sliceBytes(0, 1))])
}
private func auxReborn(raw: RawSyntaxNode, source: SourceVersionIdentity,
    children!: Array<RawSyntaxNode> = []): RawSyntaxNode {
    return RawSyntaxNode(raw.identity, source.version,
        SourceAnchor(source, raw.startAnchor.byteOffset, affinity: raw.startAnchor.affinity),
        SourceAnchor(source, raw.endAnchor.byteOffset, affinity: raw.endAnchor.affinity),
        raw.payload, children: children)
}

@Test
@Tag[Task05AuxGraph]
class Task05AuxGraphTests {
    @TestCase
    func localBundleReplacementUpdatesSameIdAuxAndAddsTypedAliasesWithoutMutatingOldSnapshot() {
        let source = EditableRopeStore("aux-graph", text: "abcdefgh")
        let root = AuxGraphNode(0, "root", 0, end: 8)
        let owner = AuxGraphNode(1, "owner-old", 1)
        let sibling = AuxGraphNode(2, "global-sibling", 2, start: 1, end: 2)
        let oldAux = AuxGraphNode(10, "aux-old", 10, start: 2, end: 3)
        let obsolete = AuxGraphNode(12, "exclusive-old", 12, start: 3, end: 4)
        owner.references.add(oldAux)
        owner.references.add(sibling)
        owner.references.add(oldAux)
        owner.references.add(obsolete)
        root.addChild(owner)
        root.addChild(sibling)
        let capture = PersistentNodeCapture(auxGraphCodec())
        let original = PersistentDocumentVersion(capture.capture(root, source.current.identity), source: Some(source))
        let oldExport = auxExport(original)
        auxAdvance(source)
        let updatedOwner = AuxGraphNode(1, "owner-new", 101)
        let updatedAux = AuxGraphNode(10, "aux-new", 110, start: 2, end: 3)
        let addedAux = AuxGraphNode(20, "aux-added", 120, start: 4, end: 5)
        updatedOwner.references.add(updatedAux)
        updatedOwner.references.add(oldExport.children[1])
        updatedOwner.references.add(addedAux)
        updatedOwner.references.add(updatedAux)
        let bundle = capture.capture(updatedOwner, source.current.identity, existing: Some(original))
        let store = PersistentDocumentStore(original)
        let tx = store.beginPreparedTransaction(0)
        tx.replaceBundle(1, bundle)
        @Expect(auxContains(tx.removedNodeIds(), 12), true)
        // Replaced same-ID records revoke their original effects as well as
        // disappeared records; the new candidate with ID 10 remains live.
        @Expect(auxContains(tx.removedNodeIds(), 10), true)
        tx.commit(1)
        let next = store.snapshot
        @Expect(refEq(next.raw(2).getOrThrow(), original.raw(2).getOrThrow()), true)
        @Expect(refEq(next.raw(10).getOrThrow(), original.raw(10).getOrThrow()), false)
        @Expect(next.find(12).isNone(), true)
        @Expect(next.find(20).isSome(), true)
        let exported = auxExport(next)
        let changed = auxTyped(exported.children[0])
        @Expect(changed.detail, "owner-new")
        @Expect(changed.rank, 101)
        @Expect(auxTyped(changed.references[0]).detail, "aux-new")
        @Expect(auxTyped(changed.references[0]).rank, 110)
        @Expect(auxTyped(changed.references[2]).detail, "aux-added")
        @Expect(refEq(changed.references[0], changed.references[3]), true)
        @Expect(refEq(changed.references[1], exported.children[1]), true)
        let oldOwner = auxTyped(auxExport(original).children[0])
        @Expect(oldOwner.detail, "owner-old")
        @Expect(auxTyped(oldOwner.references[0]).detail, "aux-old")
        @Expect(refEq(oldOwner.references[0], oldOwner.references[2]), true)
        @Expect(original.find(12).isSome(), true)
        // Mutating a detached typed export must not alter either frozen version.
        auxTyped(changed.references[0]).detail = "detached mutation"
        @Expect(auxTyped(auxTyped(auxExport(next).children[0]).references[0]).detail, "aux-new")
        @Expect(auxTyped(auxTyped(auxExport(original).children[0]).references[0]).detail, "aux-old")
    }

    @TestCase
    func spliceBundleKeepsGlobalReferenceAndReclaimsExclusiveAuxOwnersAndBirthFloor() {
        let source = EditableRopeStore("aux-graph", text: "abcdefgh")
        let root = AuxGraphNode(0, "root", 0, end: 8)
        let owner = AuxGraphNode(1, "old-owner", 1)
        let global = AuxGraphNode(2, "global", 2, start: 1, end: 2)
        let exclusive = AuxGraphNode(10, "exclusive", 10, start: 3, end: 4)
        owner.references.add(exclusive)
        root.addChild(owner)
        root.addChild(global)
        let capture = PersistentNodeCapture(auxGraphCodec())
        let original = PersistentDocumentVersion(capture.capture(root, source.current.identity), source: Some(source))
        auxAdvance(source)
        // Rebind only the three structural records to epoch 1 while preserving
        // the actual typed auxiliary record at epoch 0. It alone pins the floor.
        let reboundOwner = auxReborn(original.raw(1).getOrThrow(), source.current.identity)
        let reboundGlobal = auxReborn(original.raw(2).getOrThrow(), source.current.identity)
        let reboundRoot = auxReborn(original.raw(0).getOrThrow(), source.current.identity,
            children: [reboundOwner, reboundGlobal])
        let before = PersistentDocumentVersion(PersistentNodeBundle(reboundRoot,
            records: [original.raw(10).getOrThrow()], ownerIds: [1]), source: Some(source))
        @Expect(before.earliestAnchorVersion, 0)
        let beforeExport = auxExport(before)
        auxAdvance(source)
        let newOwner = AuxGraphNode(3, "new-owner", 3, start: 2, end: 3)
        let newAux = AuxGraphNode(30, "new-aux", 30, start: 4, end: 5)
        newOwner.references.add(beforeExport.children[1])
        newOwner.references.add(newAux)
        let inserted = capture.capture(newOwner, source.current.identity, existing: Some(before))
        let store = PersistentDocumentStore(before)
        let tx = store.beginPreparedTransaction(1)
        tx.spliceBundles(0, 0, 1, [inserted], 2)
        let removed = tx.removedNodeIds()
        @Expect(auxContains(removed, 1), true)
        @Expect(auxContains(removed, 10), true)
        @Expect(auxContains(removed, 2), false)
        let effects = OwnedEffectStore()
        let initialEffects = effects.beginTransaction()
        initialEffects.add(OwnedSemanticEffect(1, "old-owner", StringEffectPayload("old"), 1))
        initialEffects.add(OwnedSemanticEffect(10, "old-aux", StringEffectPayload("old aux"), 10))
        initialEffects.add(OwnedSemanticEffect(2, "global", StringEffectPayload("kept"), 2))
        initialEffects.read("old-aux", 90)
        initialEffects.commit()
        let oldEffects = effects.snapshot()
        let semantic = effects.beginTransaction()
        for (ownerId in removed) { semantic.revokeOriginalOwner(ownerId) }
        semantic.add(OwnedSemanticEffect(3, "new-owner", StringEffectPayload("new"), 3))
        semantic.add(OwnedSemanticEffect(30, "new-aux", StringEffectPayload("new aux"), 30))
        let syntaxCandidate = tx.prepare(2)
        let effectCandidate = semantic.prepare()
        @Expect(tx.validatePrepared(syntaxCandidate), true)
        @Expect(semantic.validatePrepared(effectCandidate), true)
        @Expect(auxContains(effectCandidate.invalidatedOwners(), 90), true)
        if (tx.validatePrepared(syntaxCandidate) && semantic.validatePrepared(effectCandidate)) {
            tx.installPrepared(syntaxCandidate)
            semantic.installPrepared(effectCandidate)
        }
        let next = store.snapshot
        @Expect(next.earliestAnchorVersion, 1)
        @Expect(next.find(10).isNone(), true)
        @Expect(next.find(30).isSome(), true)
        @Expect(refEq(next.raw(2).getOrThrow(), before.raw(2).getOrThrow()), true)
        let exported = auxExport(next)
        let insertedOwner = auxTyped(exported.children[0])
        @Expect(insertedOwner.id, 3)
        @Expect(refEq(insertedOwner.references[0], exported.children[1]), true)
        @Expect(auxTyped(insertedOwner.references[1]).detail, "new-aux")
        @Expect(effects.effectsForOwner(1).isEmpty(), true)
        @Expect(effects.effectsForOwner(10).isEmpty(), true)
        @Expect(effects.effectsForOwner(2).size, 1)
        @Expect(effects.effectsForOwner(30).size, 1)
        @Expect(effects.winner("old-aux").isNone(), true)
        @Expect(oldEffects.winner("old-aux").isSome(), true)
        @Expect(before.find(10).isSome(), true)
        @Expect(auxTyped(auxTyped(auxExport(before).children[0]).references[0]).detail, "exclusive")
    }

    @TestCase
    func sharedAuxiliaryAndItsChildSurviveUntilTheLastStructuralOwnerDisappears() {
        let source = EditableRopeStore("aux-graph", text: "abcdefgh")
        let root = AuxGraphNode(0, "root", 0, end: 8)
        let left = AuxGraphNode(1, "left", 1)
        let right = AuxGraphNode(2, "right", 2, start: 1, end: 2)
        let shared = AuxGraphNode(10, "shared", 10, start: 2, end: 3)
        shared.addChild(AuxGraphNode(11, "aux-child", 11, start: 3, end: 4))
        left.references.add(shared)
        right.references.add(shared)
        root.addChild(left)
        root.addChild(right)
        let capture = PersistentNodeCapture(auxGraphCodec())
        let original = PersistentDocumentVersion(capture.capture(root,
            source.current.identity), source: Some(source))
        let oldExport = auxExport(original)
        @Expect(refEq(auxTyped(oldExport.children[0]).references[0], auxTyped(oldExport.children[1]).references[0]), true)
        // A separate real-source branch precisely exercises bundle aux 11
        // replacement that copies parent 10's child path without reparsing 10.
        // The right owner keeps 10 reachable while left now references 11.
        let ancestorSource = EditableRopeStore("aux-ancestor", text: "abcdefgh")
        let ancestorOriginal = PersistentDocumentVersion(capture.capture(root,
            ancestorSource.current.identity), source: Some(ancestorSource))
        auxAdvance(ancestorSource)
        let newLeft = AuxGraphNode(1, "left-updated", 101)
        newLeft.references.add(AuxGraphNode(11, "aux-child-updated", 111, start: 3, end: 4))
        let ancestorBundle = capture.capture(newLeft, ancestorSource.current.identity, existing: Some(ancestorOriginal))
        let ancestorStore = PersistentDocumentStore(ancestorOriginal)
        let ancestorTx = ancestorStore.beginPreparedTransaction(0)
        ancestorTx.replaceBundle(1, ancestorBundle)
        let changedOwners = ancestorTx.removedNodeIds()
        @Expect(auxContains(changedOwners, 1), true)
        @Expect(auxContains(changedOwners, 11), true)
        @Expect(auxContains(changedOwners, 10), false)
        let effects = OwnedEffectStore()
        let initialEffects = effects.beginTransaction()
        initialEffects.add(OwnedSemanticEffect(10, "aux-parent", StringEffectPayload("parent kept"), 10))
        initialEffects.add(OwnedSemanticEffect(11, "aux-child", StringEffectPayload("old child"), 11))
        initialEffects.commit()
        let semantic = effects.beginTransaction()
        for (ownerId in changedOwners) { semantic.revokeOriginalOwner(ownerId) }
        semantic.add(OwnedSemanticEffect(11, "aux-child", StringEffectPayload("new child"), 11))
        let ancestorCandidate = ancestorTx.prepare(1)
        let effectCandidate = semantic.prepare()
        @Expect(ancestorTx.validatePrepared(ancestorCandidate), true)
        @Expect(semantic.validatePrepared(effectCandidate), true)
        if (ancestorTx.validatePrepared(ancestorCandidate) && semantic.validatePrepared(effectCandidate)) {
            ancestorTx.installPrepared(ancestorCandidate)
            semantic.installPrepared(effectCandidate)
        }
        @Expect(effects.effectsForOwner(10).size, 1)
        @Expect((effects.winner("aux-parent").getOrThrow().payload as StringEffectPayload).getOrThrow().value, "parent kept")
        @Expect((effects.winner("aux-child").getOrThrow().payload as StringEffectPayload).getOrThrow().value, "new child")
        let keptParent = auxTyped(auxTyped(auxExport(ancestorStore.snapshot).children[1]).references[0])
        @Expect(keptParent.id, 10)
        @Expect(auxTyped(keptParent.children[0]).detail, "aux-child-updated")
        @Expect(auxTyped(auxTyped(auxExport(ancestorOriginal).children[1]).references[0]).children[0].literal, "aux-child")
        auxAdvance(source)
        let store = PersistentDocumentStore(original)
        let first = store.beginPreparedTransaction(0)
        first.spliceBundles(0, 0, 1, [], 1)
        @Expect(auxContains(first.removedNodeIds(), 1), true)
        @Expect(auxContains(first.removedNodeIds(), 10), false)
        @Expect(auxContains(first.removedNodeIds(), 11), false)
        first.commit(1)
        let oneOwner = store.snapshot
        @Expect(refEq(oneOwner.raw(10).getOrThrow(), original.raw(10).getOrThrow()), true)
        @Expect(oneOwner.find(11).isSome(), true)
        @Expect(oneOwner.earliestAnchorVersion, 0)
        @Expect(auxTyped(auxTyped(auxExport(oneOwner).children[0]).references[0]).children[0].id, 11)
        auxAdvance(source)
        let second = store.beginPreparedTransaction(1)
        second.spliceBundles(0, 0, 1, [], 2)
        @Expect(auxContains(second.removedNodeIds(), 2), true)
        @Expect(auxContains(second.removedNodeIds(), 10), true)
        @Expect(auxContains(second.removedNodeIds(), 11), true)
        second.commit(2)
        @Expect(store.snapshot.nodeCount, 1)
        @Expect(store.snapshot.find(10).isNone(), true)
        @Expect(store.snapshot.find(11).isNone(), true)
        @Expect(store.snapshot.earliestAnchorVersion, 2)
        @Expect(original.find(10).isSome(), true)
        @Expect(oneOwner.find(11).isSome(), true)
    }

    @TestCase
    func affectedAuxClosureCollectsMutualAndSelfCyclesWithoutARemainingExternalOwner() {
        let source = EditableRopeStore("aux-graph", text: "abcdefgh")
        let root = AuxGraphNode(0, "root", 0, end: 8)
        let owner = AuxGraphNode(1, "owner", 1)
        let firstAux = AuxGraphNode(10, "cycle-a", 10, start: 2, end: 3)
        let secondAux = AuxGraphNode(11, "cycle-b", 11, start: 3, end: 4)
        owner.references.add(firstAux)
        firstAux.references.add(secondAux)
        secondAux.references.add(firstAux)
        secondAux.references.add(secondAux)
        root.addChild(owner)
        let original = PersistentDocumentVersion(PersistentNodeCapture(auxGraphCodec()).capture(root,
            source.current.identity), source: Some(source))
        let exportedOwner = auxTyped(auxExport(original).children[0])
        let exportedFirst = auxTyped(exportedOwner.references[0])
        let exportedSecond = auxTyped(exportedFirst.references[0])
        @Expect(refEq(exportedSecond.references[0], exportedFirst), true)
        @Expect(refEq(exportedSecond.references[1], exportedSecond), true)
        auxAdvance(source)
        let store = PersistentDocumentStore(original)
        let tx = store.beginPreparedTransaction(0)
        tx.spliceBundles(0, 0, 1, [], 1)
        let removed = tx.removedNodeIds()
        @Expect(auxContains(removed, 1), true)
        @Expect(auxContains(removed, 10), true)
        @Expect(auxContains(removed, 11), true)
        tx.commit(1)
        @Expect(store.snapshot.nodeCount, 1)
        @Expect(store.snapshot.find(10).isNone(), true)
        @Expect(store.snapshot.find(11).isNone(), true)
        @Expect(store.snapshot.earliestAnchorVersion, 1)
        @Expect(original.find(10).isSome(), true)
        @Expect(original.find(11).isSome(), true)
    }
}
