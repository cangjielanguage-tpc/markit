package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.core.document.*
import markit.core.editing.*
import markit.core.nodes.*
import markit.core.session.*
import markit.core.source.{EditableRopeStore, SourceBuffer, SourceSpan}

private class AtomicSyntaxPayload <: SyntaxNodePayload {
    public let value: String
    public init(value: String) { this.value = value }
    public prop codecId: String { get() { return "atomic-test" } }
    public func clonePayload(): SyntaxNodePayload { return AtomicSyntaxPayload(value) }
}
private class AtomicCloneGate { public var fail: Bool = false }
private class AtomicLegacyCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "atomic-legacy" } }
    public func accepts(node: Node): Bool { return (node is DocumentNode) || (node is TextNode) }
    public func rawContentFollowsSource(node: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        if (node is DocumentNode) { return DocumentNode(SourceBuffer()) }
        if (let text: TextNode <- node) { return TextNode(text.id, text.sourceSpan, text.content) }
        throw IllegalArgumentException("Unsupported atomic legacy codec")
    }
}
private class AtomicEffectPayload <: OwnedEffectPayload {
    public let value: String
    private let gate: AtomicCloneGate
    public init(value: String, gate: AtomicCloneGate) { this.value = value; this.gate = gate }
    public func cloneEffectPayload(): OwnedEffectPayload {
        if (gate.fail) { throw IllegalArgumentException("Provider clone failure") }
        return AtomicEffectPayload(value, gate)
    }
}
private func atomicEffect(owner: Int64, key: String, value: String, gate: AtomicCloneGate): OwnedSemanticEffect {
    return OwnedSemanticEffect(owner, key, AtomicEffectPayload(value, gate), owner)
}
private func atomicValue(effect: OwnedSemanticEffect): String { return (effect.payload as AtomicEffectPayload).getOrThrow().value }
private func atomicRaw(id: Int64, version!: Int64 = 0, children!: Array<RawSyntaxNode> = [], start!: Int64 = 0,
    end!: Int64 = 0): RawSyntaxNode {
    let source = SourceVersionIdentity("atomic", version)
    return RawSyntaxNode(SyntaxNodeIdentity("atomic", id), version,
        SourceAnchor(source, start, affinity: AnchorAffinity.Before), SourceAnchor(source, end, affinity: AnchorAffinity.After),
        AtomicSyntaxPayload(id.toString()), children: children)
}

@Test
@Tag[Task05AtomicStores]
class Task05AtomicStoreTests {
    @TestCase
    func providerFailureDuringPreparationLeavesBothStoresAndTokenClockUnchanged() {
        let tree = PersistentDocumentStore(PersistentDocumentVersion(PersistentNodeBundle(atomicRaw(0, children: [atomicRaw(1)]))))
        let effects = OwnedEffectStore(); let gate = AtomicCloneGate()
        let syntax = tree.beginPreparedTransaction(0); syntax.replace(1, atomicRaw(2, version: 1))
        let candidateTree = syntax.prepare(1)
        let semantic = effects.beginTransaction(); semantic.add(atomicEffect(1, "key", "candidate", gate))
        gate.fail = true
        var rejected = false
        try { semantic.prepare() } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true); @Expect(tree.snapshot.version, 0); @Expect(effects.version, 0)
        @Expect(tree.snapshot.find(1).isSome(), true); @Expect(tree.snapshot.find(2).isNone(), true)
        @Expect(syntax.validatePrepared(candidateTree), true)
        semantic.cancel(); syntax.cancel(); gate.fail = false
        let next = effects.beginTransaction(); next.add(atomicEffect(2, "key", "committed", gate)); next.read("key", 20); next.commit()
        @Expect(effects.readDependencies(20)[0].winnerToken, 0)
    }

    @TestCase
    func preparedEffectsAreImmutableRepreparableAndPreviewPositiveAndMissingReaders() {
        let effects = OwnedEffectStore(); let gate = AtomicCloneGate()
        let initial = effects.beginTransaction(); initial.add(atomicEffect(1, "present", "old", gate))
        initial.read("present", 10); initial.read("missing", 11); initial.commit()
        let old = effects.snapshot()
        let next = effects.beginTransaction(); next.revokeOwner(1); next.add(atomicEffect(2, "present", "new", gate))
        let first = next.prepare()
        @Expect(first.invalidatedOwners().size, 1); @Expect(first.invalidatedOwners()[0], 10)
        @Expect(first.invalidatedKeysForOwner(10).size, 1)
        @Expect(first.invalidatedKeysForOwner(10)[0], "present")
        next.add(atomicEffect(3, "missing", "defined", gate))
        let second = next.prepare()
        @Expect(next.validatePrepared(first), false); @Expect(next.validatePrepared(second), true)
        @Expect(first.snapshot.winner("missing").isNone(), true)
        @Expect(second.invalidatedOwners().size, 2)
        @Expect(second.invalidatedKeysForOwner(11).size, 1)
        @Expect(second.invalidatedKeysForOwner(11)[0], "missing")
        @Expect(first.invalidatedKeysForOwner(11).size, 0)
        @Expect(atomicValue(second.snapshot.winner("missing").getOrThrow()), "defined")
        @Expect(atomicValue(old.winner("present").getOrThrow()), "old")
        next.cancel(); @Expect(effects.winner("missing").isNone(), true); @Expect(effects.version, 1)
    }

    @TestCase
    func validatedInstallCallsNoProviderAndPublishesIndependentCandidates() {
        let tree = PersistentDocumentStore(PersistentDocumentVersion(PersistentNodeBundle(atomicRaw(0, children: [atomicRaw(1)]))))
        let effects = OwnedEffectStore(); let gate = AtomicCloneGate(); let old = effects.snapshot()
        let syntax = tree.beginPreparedTransaction(0); syntax.replace(1, atomicRaw(2, version: 1)); let treeCandidate = syntax.prepare(1)
        let semantic = effects.beginTransaction(); semantic.add(atomicEffect(1, "key", "new", gate)); let effectCandidate = semantic.prepare()
        gate.fail = true
        @Expect(syntax.validatePrepared(treeCandidate), true); @Expect(semantic.validatePrepared(effectCandidate), true)
        syntax.installPrepared(treeCandidate); semantic.installPrepared(effectCandidate)
        @Expect(tree.snapshot.version, 1); @Expect(effects.version, 1)
        @Expect(syntax.validatePrepared(treeCandidate), false); @Expect(semantic.validatePrepared(effectCandidate), false)
        gate.fail = false
        @Expect(atomicValue(effects.winner("key").getOrThrow()), "new")
        @Expect(old.winner("key").isNone(), true)
    }

    @TestCase
    func staleParticipantRejectsBeforeEitherStoreIsInstalled() {
        let tree = PersistentDocumentStore(PersistentDocumentVersion(PersistentNodeBundle(atomicRaw(0))))
        let effects = OwnedEffectStore()
        let syntax = tree.beginPreparedTransaction(0); let candidateTree = syntax.prepare(1)
        let semantic = effects.beginTransaction(); let candidateEffects = semantic.prepare()
        effects.beginTransaction().commit()
        @Expect(syntax.validatePrepared(candidateTree), true); @Expect(semantic.validatePrepared(candidateEffects), false)
        if (syntax.validatePrepared(candidateTree) && semantic.validatePrepared(candidateEffects)) {
            syntax.installPrepared(candidateTree); semantic.installPrepared(candidateEffects)
        }
        @Expect(tree.snapshot.version, 0); @Expect(effects.version, 1)
        syntax.cancel(); semantic.cancel()
    }

    @TestCase
    func nestedProbeScopesRollbackWritesReadsRevocationsAndLocalTokens() {
        let effects = OwnedEffectStore(); let gate = AtomicCloneGate()
        let initial = effects.beginTransaction(); initial.add(atomicEffect(1, "existing", "kept", gate)); initial.commit()
        let tx = effects.beginTransaction(); tx.read("existing", 20)
        let outer = tx.beginScope(); tx.revokeOwner(1); tx.add(atomicEffect(2, "probe", "discard", gate)); tx.read("missing", 30)
        let inner = tx.beginScope(); tx.add(atomicEffect(3, "nested", "discard", gate)); inner.complete(true)
        outer.complete(false)
        @Expect(tx.read("probe", 21).isNone(), true); @Expect(tx.read("nested", 22).isNone(), true)
        tx.add(atomicEffect(4, "stable", "committed", gate)); tx.read("stable", 40); tx.commit()
        @Expect(effects.effectsForOwner(1).size, 1); @Expect(effects.effectsForOwner(2).size, 0)
        @Expect(effects.readDependencies(30).size, 0)
        @Expect(effects.readDependencies(20).size, 1)
        @Expect(effects.readDependencies(40)[0].winnerToken, 1)
        let rewrite = effects.beginTransaction()
        rewrite.add(atomicEffect(1, "existing", "rewritten", gate)); rewrite.read("existing", 1)
        rewrite.revokeOriginalOwner(1); rewrite.commit()
        @Expect(effects.effectsForOwner(1).size, 1)
        @Expect(atomicValue(effects.effectsForOwner(1)[0]), "rewritten")
        @Expect(effects.readDependencies(1).size, 1)
    }

    @TestCase
    func structuralSpliceKeepsSiblingRecordsAndCanEditSuffixAfterItsRankChanges() {
        let source = EditableRopeStore("atomic", text: String.fromUtf8(Array<Byte>(2048, repeat: 97)))
        let children = Array<RawSyntaxNode>(2048, { i => atomicRaw(i + 1, start: i, end: i + 1) })
        let original = PersistentDocumentVersion(PersistentNodeBundle(atomicRaw(0, children: children, end: 2048)), source: Some(source))
        source.applyEdits(0, [EditingTextEdit(EditingRange(100, 100), "x")])
        let next = original.splicingChildren(0, 100, 0, [atomicRaw(9999, version: 1, start: 100, end: 101)], 1)
        @Expect(next.raw(0).getOrThrow().childCount, 2049)
        @Expect(refEq(original.raw(2048).getOrThrow(), next.raw(2048).getOrThrow()), true)
        @Expect(next.raw(0).getOrThrow().childPosition(2048), 2048)
        @Expect(original.raw(0).getOrThrow().childPosition(2048), 2047)
        let replaced = next.replacing(2048, atomicRaw(2048, version: 1, start: 2048, end: 2049), 1)
        @Expect(replaced.raw(0).getOrThrow().childAt(2048).identity.nodeId, 2048)
        @Expect(refEq(replaced.raw(2047).getOrThrow(), original.raw(2047).getOrThrow()), true)
        let removed = replaced.splicingChildren(0, 99, 3, [], 1)
        @Expect(removed.nodeCount, 2047); @Expect(removed.find(100).isNone(), true)
        @Expect(removed.find(9999).isNone(), true); @Expect(removed.find(101).isNone(), true)
        @Expect(removed.raw(0).getOrThrow().childPosition(2048), 2045)
        @Expect(removed.raw(0).getOrThrow().childrenHeight < 24, true)
        @Expect(original.raw(0).getOrThrow().childCount, 2048)
        let shared = atomicRaw(30)
        var rejected = false
        try {
            PersistentDocumentVersion(PersistentNodeBundle(atomicRaw(0), records: [
                atomicRaw(10, children: [shared]), atomicRaw(20, children: [shared])
            ]))
        } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
    }

    @TestCase
    func earliestAnchorFloorIncludesAuxiliaryAndAdvancesOnlyWhenLastOldAnchorDisappears() {
        let source = EditableRopeStore("atomic", text: "ab")
        let initial = PersistentDocumentVersion(PersistentNodeBundle(atomicRaw(0, children: [atomicRaw(1, end: 1), atomicRaw(2, start: 1, end: 2)], end: 2)), source: Some(source))
        source.applyEdits(0, [EditingTextEdit(EditingRange(0, 1), "c")])
        let first = initial.replacing(1, atomicRaw(1, version: 1, end: 1), 1)
        @Expect(first.earliestAnchorVersion, 0)
        source.applyEdits(1, [EditingTextEdit(EditingRange(1, 2), "d")])
        let second = first.replacing(2, atomicRaw(2, version: 2, start: 1, end: 2), 2)
        @Expect(second.earliestAnchorVersion, 1); @Expect(initial.earliestAnchorVersion, 0)
        let withAuxiliary = PersistentDocumentVersion(PersistentNodeBundle(second.raw(0).getOrThrow(), records: [atomicRaw(9)]), source: Some(source))
        @Expect(withAuxiliary.earliestAnchorVersion, 0)
        @Expect(withAuxiliary.replacing(9, atomicRaw(9, version: 2), 2).earliestAnchorVersion, 1)
    }

    @TestCase
    func repeatedDenseSiblingInsertionsStayBalancedWithoutRenumberingOldSiblings() {
        let initial = PersistentDocumentVersion(PersistentNodeBundle(atomicRaw(0, children: Array<RawSyntaxNode>(32, { i => atomicRaw(i + 1) }))))
        var version = initial
        for (step in 0..256) { version = version.splicingChildren(0, 0, 0, [atomicRaw(1000 + step)], 1) }
        @Expect(version.raw(0).getOrThrow().childCount, 288)
        @Expect(version.raw(0).getOrThrow().childrenHeight < 20, true)
        @Expect(version.raw(0).getOrThrow().childPosition(32), 287)
        @Expect(refEq(version.raw(32).getOrThrow(), initial.raw(32).getOrThrow()), true)
        let remaining = version.splicingChildren(0, 0, 256, [], 1)
        @Expect(remaining.nodeCount, 33); @Expect(remaining.raw(0).getOrThrow().childPosition(32), 31)
        @Expect(refEq(remaining.raw(32).getOrThrow(), initial.raw(32).getOrThrow()), true)
    }

    @TestCase
    func explicitLegacyDocumentRawAndSpanUseItsImmutableSnapshotSource() {
        // An unrelated append buffer has no editable identity proof. Its raw
        // getter stays frozen rather than being projected onto a source store.
        let buffer = SourceBuffer(); buffer.append("ab")
        let legacy = DocumentNode(buffer); legacy.addChild(TextNode(1, SourceSpan(0, 2, 0, 2), "ab"))
        let codec = NodeCodec(); codec.register(AtomicLegacyCodec())
        let source = EditableRopeStore("atomic", text: "ab")
        let fallback = PersistentDocumentVersion(PersistentNodeCapture(codec).capture(legacy, source.current.identity), source: Some(source))
        @Expect(fallback.materializeLegacy().rawContent(), legacy.rawContent())
        let boundSource = SourceBuffer(editableSource: Some(source.current))
        let bound = DocumentNode(boundSource)
        bound.addChild(TextNode(1, SourceSpan(0, 2, 0, 2), "ab"))
        let original = PersistentDocumentVersion(PersistentNodeCapture(codec).capture(bound, source.current.identity), source: Some(source))
        let explicit = DocumentNode(SourceBuffer(editableSource: Some(source.current)))
        explicit.setRawContent("synthetic explicit")
        let overridden = PersistentDocumentVersion(PersistentNodeCapture(codec).capture(explicit, source.current.identity), source: Some(source))
        source.applyEdits(0, [EditingTextEdit(EditingRange(0, 0), "c")])
        let next = original.atVersion(1)
        source.applyEdits(1, [EditingTextEdit(EditingRange(0, 3), "d")])
        boundSource.bindEditableSource(source.current)
        @Expect(original.materializeLegacy().rawContent(), "ab")
        @Expect(original.materializeLegacy().sourceSpan.endByte, 2)
        @Expect((original.raw(0).getOrThrow().payload as TypedSyntaxPayload).getOrThrow().materializeShallow().rawContent(), "ab")
        @Expect(next.materializeLegacy().rawContent(), "cab")
        @Expect(next.materializeLegacy().sourceSpan.endByte, 3)
        @Expect(next.materializeLegacy().sourceSpan.endRune, 3)
        @Expect(overridden.atVersion(2).materializeLegacy().rawContent(), "synthetic explicit")
        @Expect(fallback.atVersion(2).materializeLegacy().rawContent(), legacy.rawContent())
        @Expect(source.current.sliceBytes(0, 1), "d")
    }
}
