package markit.core.incremental

import std.collection.{ArrayList, HashMap}
import markit.core.block.*
import markit.core.document.*
import markit.core.editing.*
import markit.core.nodes.*
import markit.core.session.*
import markit.core.source.*

// Editing-only staging, shared by initialization and later semantic replay.
// A payload update visits the identity/path index, never captures its subtree.
private class BlockResultStage {
    private var current: PersistentDocumentVersion
    private let transaction: ?PersistentDocumentTransaction
    private let codec: NodeCodec
    private let effects: OwnedEffectsTransaction
    private let patches: ArrayList<EditingNodePatch>
    public prop view: PersistentDocumentVersion { get() { return current } }
    public BlockResultStage(view: PersistentDocumentVersion, transaction: ?PersistentDocumentTransaction,
        codec: NodeCodec, effects: OwnedEffectsTransaction, patches: ArrayList<EditingNodePatch>) {
        this.current = view; this.transaction = transaction; this.codec = codec
        this.effects = effects; this.patches = patches
    }
    private func changed(revokeGone: Bool): Unit {
        if (revokeGone) {
            for (id in current.removedNodeIds()) {
                if (current.raw(id).isNone()) { effects.revokeOwner(id) }
            }
        }
    }
    public func apply(owner: Int64, result: BlockUnitParseResult, revokeGone!: Bool = false): Unit {
        let identity = SourceVersionIdentity(current.documentId, current.version)
        let payloads = result.payloadUpdates
        if (let Some(first) <- result.rawSplice) {
            let pending = ArrayList<BlockRawChildrenEdit>(); pending.add(first)
            while (!pending.isEmpty()) {
                let edit = pending.remove(at: pending.size - 1)
                let bundles = edit.inserted
                splice(edit.parentId, edit.start, edit.deleteCount, bundles)
                changed(revokeGone)
                patches.add(EditingNodePatch(owner, Option<RawSyntaxNode>.None, parentId: edit.parentId,
                    start: edit.start, deleteCount: edit.deleteCount,
                    inserted: Array<RawSyntaxNode>(bundles.size, { i => bundles[i].root }), textSplices: edit.textSplices))
                let following = edit.following; var i = following.size
                while (i > 0) { i -= 1; pending.add(following[i]) }
            }
        } else if (let Some(edit) <- result.splice) {
            let nodes = edit.inserted
            let bundles = Array<PersistentNodeBundle>(nodes.size, { i =>
                PersistentNodeCapture(codec).capture(nodes[i], identity, existing: Some(current))
            })
            splice(edit.parentId, edit.start, edit.deleteCount, bundles); changed(revokeGone)
            patches.add(EditingNodePatch(owner, Option<RawSyntaxNode>.None, parentId: edit.parentId,
                start: edit.start, deleteCount: edit.deleteCount,
                inserted: Array<RawSyntaxNode>(bundles.size, { i => bundles[i].root })))
        } else if (result.rawReplacement.isSome() || payloads.isEmpty()) {
            let bundle = result.rawReplacement ?? PersistentNodeCapture(codec).capture(result.replacement, identity, existing: Some(current))
            if (let Some(tx) <- transaction) { tx.replaceBundle(owner, bundle); current = tx.preview(current.version) }
            else { current = current.replacingBundle(owner, bundle, current.version) }
            changed(revokeGone)
            patches.add(EditingNodePatch(owner, Some(bundle.root)))
        }
        for (update in payloads) {
            if (let Some(tx) <- transaction) {
                tx.replacePayload(update.nodeId, update.payload, current.version); current = tx.preview(current.version)
            } else { current = current.replacingPayload(update.nodeId, update.payload, current.version) }
            changed(revokeGone)
            patches.add(EditingNodePatch(update.nodeId, Some(current.raw(update.nodeId).getOrThrow())))
        }
    }
    private func splice(parentId: Int64, start: Int64, count: Int64, bundles: Array<PersistentNodeBundle>): Unit {
        if (let Some(tx) <- transaction) {
            tx.spliceBundles(parentId, start, count, bundles, current.version); current = tx.preview(current.version)
        } else { current = current.splicingBundles(parentId, start, count, bundles, current.version) }
    }
}

private func validateSemanticResult(result: BlockUnitParseResult, provider: BlockEditingFacet,
    context: BlockEditingContext): Unit {
    if (!result.converged || result.exit.documentId != context.documentId ||
        result.exit.owner != provider.owner || result.exit.sourceVersion != context.sourceVersion) {
        throw IllegalArgumentException("Invalid semantic result identity/convergence")
    }
}

public class EditingNodePatch {
    public let replacedId: Int64
    public let replacement: ?RawSyntaxNode
    public let parentId: Int64
    public let start: Int64
    public let deleteCount: Int64
    private let insertedRecords: Array<RawSyntaxNode>
    private let literalChanges: Array<LogicalTextSplice>
    public prop textSplices: Array<LogicalTextSplice> { get() { return literalChanges.clone() } }
    public prop inserted: Array<RawSyntaxNode> { get() { return insertedRecords.clone() } }
    public EditingNodePatch(replacedId: Int64, replacement: ?RawSyntaxNode,
        parentId!: Int64 = -1, start!: Int64 = 0, deleteCount!: Int64 = 0, inserted!: Array<RawSyntaxNode> = [], textSplices!: Array<LogicalTextSplice> = []) {
        this.replacedId = replacedId; this.replacement = replacement
        this.parentId = parentId; this.start = start; this.deleteCount = deleteCount; this.insertedRecords = inserted.clone(); this.literalChanges = textSplices.clone()
    }
}

// A retained snapshot owns the anchor history needed by its oldest reachable
// raw record, as well as the exact immutable source root through its tree view.
public class EditingDocumentSnapshot {
    internal let persistentTree: PersistentDocumentVersion
    public let legacySnapshot: ?DocumentSnapshot
    public prop fallbackScope: EditingFallbackScope {
        get() { return if (legacySnapshot.isSome()) { EditingFallbackScope.Session } else { EditingFallbackScope.NoFallback } }
    }
    public prop fallbackReason: String {
        get() { return if (legacySnapshot.isSome()) { "Executable incremental provider unavailable; complete legacy graph published" } else { "" } }
    }
    public prop tree: PersistentDocumentVersion {
        get() {
            if (legacySnapshot.isSome()) { throw IllegalArgumentException("Session fallback exposes legacySnapshot; no incremental raw identity is claimed") }
            return persistentTree
        }
    }
    public let effects: OwnedEffectSnapshot
    private let patchRecords: Array<EditingNodePatch>
    public prop patches: Array<EditingNodePatch> { get() { return patchRecords.clone() } }
    private let lease: SourceVersionLease
    private var closed: Bool = false
    public EditingDocumentSnapshot(tree: PersistentDocumentVersion, effects: OwnedEffectSnapshot,
        patches: Array<EditingNodePatch>, lease: SourceVersionLease, legacySnapshot!: ?DocumentSnapshot = None) {
        this.persistentTree = tree; this.effects = effects; this.patchRecords = patches.clone(); this.lease = lease
        this.legacySnapshot = legacySnapshot
    }
    public func release(): Unit { if (!closed) { lease.release(); closed = true } }
}

private class LegacySessionMarker <: SyntaxNodePayload {
    public prop codecId: String { get() { return "legacy-session-fallback" } }
    public func clonePayload(): SyntaxNodePayload { return LegacySessionMarker() }
}

private func legacySessionRaw(source: EditableSourceVersion): RawSyntaxNode {
    return RawSyntaxNode(SyntaxNodeIdentity(source.identity.documentId, 0), source.identity.version,
        SourceAnchor(source.identity, 0, affinity: AnchorAffinity.Before),
        SourceAnchor(source.identity, source.byteLength, affinity: AnchorAffinity.After), LegacySessionMarker())
}

public class EditingFlushResult {
    public let committed: Bool
    public let sourceVersion: Int64
    public let parseVersion: Int64
    public let syntaxUnitsParsed: Int64
    public let semanticOwnersReplayed: Int64
    public let reason: String
    public EditingFlushResult(committed: Bool, sourceVersion: Int64, parseVersion: Int64,
        syntaxUnitsParsed!: Int64 = 0, semanticOwnersReplayed!: Int64 = 0, reason!: String = "") {
        this.committed = committed; this.sourceVersion = sourceVersion; this.parseVersion = parseVersion
        this.syntaxUnitsParsed = syntaxUnitsParsed; this.semanticOwnersReplayed = semanticOwnersReplayed
        this.reason = reason
    }
}

private class DirtySourceRange {
    public let start: SourceAnchor
    public let end: SourceAnchor
    public DirtySourceRange(start: SourceAnchor, end: SourceAnchor) { this.start = start; this.end = end }
}

// Source acknowledgement and parse publication have separate lifetimes. This
// object is serialized by its caller; provider reentry is guarded by epoch and
// source-version checks immediately before the common publish gate.
public class DocumentEditingSession {
    public let source: EditableRopeStore
    public let versions: EditingVersionState
    private let lifecycle: EditableSourceLifecycle
    private let parser: ParseSession
    private let kernelFactory: (ParseSession) -> BlockParsingKernel
    private let providers: Array<BlockEditingFacet>
    private let grammarIdentities: Array<String>
    private let codec: NodeCodec
    private let conservativeHistory: ?SourceVersionLease
    private let fallbackParser: ?(EditableSourceVersion) -> DocumentSnapshot
    private let validateExecution: ?() -> Unit
    private let effects = OwnedEffectStore()
    private let tree: PersistentDocumentStore
    private var published: EditingDocumentSnapshot
    private let dirty = ArrayList<DirtySourceRange>()
    private var computationEpoch: Int64 = 0
    private var nextNodeId: Int64 = 1
    private var computing: Bool = false
    private var closed: Bool = false
    private let retiredSnapshots = ArrayList<EditingDocumentSnapshot>()
    private let deferredLeases = ArrayList<SourceVersionLease>()

    public DocumentEditingSession(source: EditableRopeStore, parser: ParseSession,
        kernelFactory: (ParseSession) -> BlockParsingKernel, providers: Array<BlockEditingFacet>, codec: NodeCodec,
        fallbackParser!: ?(EditableSourceVersion) -> DocumentSnapshot = None,
        validateExecution!: ?() -> Unit = None) {
        let initialSource = source.current
        this.source = source; this.parser = parser; this.kernelFactory = kernelFactory
        this.providers = providers.clone(); this.codec = codec
        this.grammarIdentities = Array<String>(providers.size, { i => providers[i].grammarVersion })
        this.fallbackParser = fallbackParser
        this.validateExecution = validateExecution
        if (let Some(validate) <- validateExecution) { validate() }
        this.lifecycle = EditableSourceLifecycle(source)
        var unknownRetention = false
        for (provider in providers) { if (!provider.retainsOnlyRawBirthEpochs) { unknownRetention = true } }
        this.conservativeHistory = if (unknownRetention) { Some(lifecycle.retention.retain(initialSource.identity.version)) } else { None }
        this.versions = EditingVersionState(initialSource.identity.documentId, initialVersion: initialSource.identity.version)
        let initialEffects = effects.beginTransaction()
        let context = BlockEditingContext(parser, initialSource, Option<PersistentDocumentVersion>.None, initialEffects)
        parser.editingContext = Some(context)
        parser.lineIndex.bindEditableSource(initialSource)
        var initialRoot = parser.root
        var legacyInitial: ?DocumentSnapshot = Option<DocumentSnapshot>.None
        if (let Some(parse) <- fallbackParser) {
            let legacy = parse(initialSource); legacyInitial = Some(legacy); initialRoot = legacy.root
        }
        else {
            let kernel = kernelFactory(parser)
            kernel.setEmissionSink({ node: Node => parser.root.addChild(node) })
            for (line in context.lines(0, initialSource.byteLength)) { kernel.feed(line) }
            kernel.finish()
            let end = initialSource.coordinateAtByte(initialSource.byteLength).getOrThrow()
            parser.root.sourceSpan = SourceSpan(0, end.byteOffset, 0, end.runeOffset)
        }
        if (let Some(validate) <- validateExecution) { validate() }
        let bundle = if (fallbackParser.isSome()) { PersistentNodeBundle(legacySessionRaw(initialSource)) }
            else { PersistentNodeCapture(codec).capture(initialRoot, initialSource.identity) }
        let initial = PersistentDocumentVersion(bundle, source: Some(source))
        let initialPatches = ArrayList<EditingNodePatch>()
        let initialStage = BlockResultStage(initial, Option<PersistentDocumentTransaction>.None, codec, initialEffects, initialPatches)
        var initialContext = context
        var initialPrepared = initialEffects.prepare()
        var initialRounds: Int64 = 0
        while (!initialPrepared.invalidatedOwners().isEmpty()) {
            initialRounds += 1
            if (initialRounds > initialStage.view.nodeCount + 1) { throw IllegalArgumentException("Initial semantic effects did not converge") }
            for (owner in initialPrepared.invalidatedOwners()) {
                if (let Some(node) <- initialStage.view.raw(owner)) {
                    var replayed = false
                    for (provider in providers) {
                        if (provider.owns(node)) {
                            let keys = initialPrepared.invalidatedKeysForOwner(owner)
                            let syntaxKeys = provider.syntaxReadKeys(node)
                            if (syntaxKeys.isNone()) { throw IllegalArgumentException("Initial syntax dependencies require provider recovery") }
                            for (key in keys) {
                                if (syntaxKeys.getOrThrow().contains(key)) { throw IllegalArgumentException("Initial syntax dependencies require provider recovery") }
                            }
                            initialContext = initialContext.withPrevious(initialStage.view, invalidatedKeys: keys)
                            parser.editingContext = Some(initialContext)
                            if (provider.preservesUnchangedSemanticReads) { initialEffects.refreshOwner(owner, keys) }
                            else { initialEffects.revokeOwner(owner) }
                            initialContext.enterOwner(owner, provider.owner)
                            if (let Some(result) <- provider.replaySemanticResult(initialContext, node)) {
                                validateSemanticResult(result, provider, initialContext)
                                initialStage.apply(owner, result, revokeGone: true)
                            }
                            replayed = true; break
                        }
                    }
                    if (!replayed) { throw IllegalArgumentException("Missing initial semantic replay provider") }
                } else { initialEffects.revokeOwner(owner) }
                if (let Some(validate) <- validateExecution) { validate() }
                for (i in 0..providers.size) {
                    if (providers[i].grammarVersion != grammarIdentities[i]) { throw IllegalArgumentException("Editing grammar identity changed") }
                }
                if (source.current.identity.version != initialSource.identity.version) { throw IllegalArgumentException("Stale initial editing source") }
            }
            initialPrepared = initialEffects.prepare()
        }
        if (!initialEffects.validatePrepared(initialPrepared)) { throw IllegalArgumentException("Stale initial effects") }
        if (let Some(validate) <- validateExecution) { validate() }
        for (i in 0..providers.size) {
            if (providers[i].grammarVersion != grammarIdentities[i]) { throw IllegalArgumentException("Editing grammar identity changed") }
        }
        if (source.current.identity.version != initialSource.identity.version) { throw IllegalArgumentException("Stale initial editing source") }
        this.tree = PersistentDocumentStore(initialStage.view)
        initialEffects.installPrepared(initialPrepared)
        this.nextNodeId = parser.nextNodeId
        this.lifecycle.retention.setCurrent(initialSource.identity.version)
        this.published = EditingDocumentSnapshot(initialStage.view, effects.snapshot(), [],
            lifecycle.retention.retain(initialStage.view.earliestAnchorVersion), legacySnapshot: legacyInitial)
        parser.releaseEditingWorkspace()
        parser.editingContext = None
    }

    public func snapshot(): EditingDocumentSnapshot {
        requireOpen()
        return EditingDocumentSnapshot(published.persistentTree, published.effects, published.patches,
            lifecycle.retention.retain(published.persistentTree.earliestAnchorVersion), legacySnapshot: published.legacySnapshot)
    }

    public func applyEdits(expectedVersion: Int64, edits: Array<EditingTextEdit>): EditableSourceVersion {
        requireOpen()
        let before = source.current
        // Convert and validate all edit coordinates before acknowledgement.
        let ranges = ArrayList<DirtySourceRange>()
        for (edit in edits) {
            let start = before.byteAtCoordinate(edit.range.start, edit.range.coordinate).getOrThrow()
            let end = before.byteAtCoordinate(edit.range.end, edit.range.coordinate).getOrThrow()
            ranges.add(DirtySourceRange(SourceAnchor(before.identity, start, affinity: AnchorAffinity.Before),
                SourceAnchor(before.identity, end, affinity: AnchorAffinity.After)))
        }
        let accepted = source.applyEdits(expectedVersion, edits)
        if (accepted.identity.version == before.identity.version) { return accepted }
        versions.acceptSource(expectedVersion)
        lifecycle.retention.setCurrent(accepted.identity.version)
        for (range in ranges) { dirty.add(range) }
        computationEpoch += 1
        return accepted
    }

    public func cancelComputation(): Unit { computationEpoch += 1; versions.cancelComputation() }

    public func flush(): EditingFlushResult {
        requireOpen()
        if (computing) { throw IllegalArgumentException("Editing computation is already active") }
        let target = source.current
        if (target.identity.version == versions.parseVersion) {
            return EditingFlushResult(true, versions.sourceVersion, versions.parseVersion)
        }
        computing = true
        try {
            retryCleanup()
            if (let Some(parse) <- fallbackParser) { return flushFallback(parse, target) }
            var totalSyntax: Int64 = 0
            var totalSemantic: Int64 = 0
            var passes: Int64 = 0
            while (true) {
                passes += 1
                if (passes > tree.snapshot.nodeCount + 1) { throw IllegalArgumentException("Syntax dependency expansion did not converge") }
                let result = flushIncremental(target)
                totalSyntax += result.syntaxUnitsParsed; totalSemantic += result.semanticOwnersReplayed
                if (result.reason != "syntax-dependency-expansion") {
                    return EditingFlushResult(result.committed, result.sourceVersion, result.parseVersion,
                        syntaxUnitsParsed: totalSyntax, semanticOwnersReplayed: totalSemantic, reason: result.reason)
                }
            }
            throw IllegalArgumentException("Unreachable editing computation exit")
        } finally { computing = false }
    }

    private func flushIncremental(target: EditableSourceVersion): EditingFlushResult {
        let epoch = computationEpoch
        let rollback = parser.checkpoint()
        let sourceLease = lifecycle.retention.retain(target.identity.version)
        let syntax = PersistentDocumentTransaction(tree, tree.snapshot)
        let semantic = effects.beginTransaction()
        let recoveryLeases = ArrayList<SourceVersionLease>()
        var syntaxCount: Int64 = 0
        var semanticCount: Int64 = 0
        var allocatedNext = nextNodeId
        var candidateSnapshot: ?EditingDocumentSnapshot = None
        var committed = false
        var outcome = EditingFlushResult(false, versions.sourceVersion, versions.parseVersion)
        try {
            guardCurrent(epoch, target.identity.version)
            parser.source.bindEditableSource(target)
            let currentView = tree.snapshot.atVersion(target.identity.version)
            var context = BlockEditingContext(parser, target, Some(currentView), semantic,
                resolve: Some({ anchor: SourceAnchor => source.resolve(anchor, target.identity.version) }),
                recoveryCheckpoint: Some(rollback), baseSourceVersion: tree.snapshot.version)
            parser.editingContext = Some(context)
            let selected = ArrayList<BlockRecoveryUnit>()
            let selectedProviders = HashMap<Int64, BlockEditingFacet>()
            for (range in dirty) {
                let start = source.resolve(range.start, target.identity.version).getOrThrow()
                let end = source.resolve(range.end, target.identity.version).getOrThrow()
                var best: ?BlockRecoveryUnit = None
                var bestProvider: ?BlockEditingFacet = Option<BlockEditingFacet>.None
                var bestDepth: Int64 = -1
                for (node in currentView.nodesInByteRange(start, end)) {
                    let depth = currentView.pathTo(node.identity.nodeId).size
                    if (depth <= bestDepth) { continue }
                    for (provider in providers) {
                        if (provider.owns(node)) {
                            if (let Some(unit) <- provider.recover(context, node, start, end)) {
                                best = Some(unit); bestProvider = Some(provider); bestDepth = depth
                            }
                        }
                    }
                }
                if (best.isNone()) {
                    for (provider in providers) {
                        if (let Some(unit) <- provider.recoverGap(context, start, end)) {
                            if (best.isSome()) { throw IllegalArgumentException("Ambiguous gap recovery provider") }
                            best = Some(unit); bestProvider = Some(provider)
                        }
                    }
                }
                let unit = best.getOrThrow()
                if (let Some(explicit) <- unit.provider) { bestProvider = Some(requireRegistered(explicit)) }
                let path = currentView.pathTo(unit.nodeId)
                var covered = false
                for (previous in selected) { if (path.contains(previous.nodeId)) { covered = true } }
                if (!covered) {
                    var index = selected.size
                    while (index > 0) {
                        index -= 1
                        if (currentView.pathTo(selected[index].nodeId).contains(unit.nodeId)) { selected.remove(at: index) }
                    }
                    selected.add(unit)
                    selectedProviders[unit.nodeId] = bestProvider.getOrThrow()
                }
            }
            let patches = ArrayList<EditingNodePatch>()
            let completedUnits = ArrayList<Int64>()
            for (selectedUnit in selected) {
                var covered = false
                for (id in completedUnits) { if (currentView.pathTo(selectedUnit.nodeId).contains(id)) { covered = true } }
                if (covered) { continue }
                var unit = selectedUnit
                var provider = selectedProviders.get(unit.nodeId).getOrThrow()
                var complete = false
                var expansions: Int64 = 0
                while (!complete) {
                    expansions += 1
                    if (expansions > currentView.nodeCount + 1) { throw IllegalArgumentException("Recovery boundary did not converge") }
                    guardCurrent(epoch, target.identity.version)
                    if (let Some(explicit) <- unit.provider) { provider = requireRegistered(explicit) }
                    else if (provider.owner != unit.owner) { provider = providerFor(unit.owner, currentView.raw(unit.nodeId).getOrThrow()) }
                    if (unit.syntax.documentId != target.identity.documentId || unit.syntax.owner != provider.owner ||
                        unit.syntax.sourceVersion > target.identity.version || unit.start.source.documentId != target.identity.documentId ||
                        unit.end.source.documentId != target.identity.documentId) {
                        throw IllegalArgumentException("Invalid recovery ownership/version")
                    }
                    var epochFloor = unit.syntax.sourceVersion
                    if (unit.start.source.version < epochFloor) { epochFloor = unit.start.source.version }
                    if (unit.end.source.version < epochFloor) { epochFloor = unit.end.source.version }
                    if (unit.mappingVersion >= 0 && unit.mappingVersion < epochFloor) { epochFloor = unit.mappingVersion }
                    recoveryLeases.add(lifecycle.retention.retain(epochFloor))
                    var recovered = false
                    var restoreReason = "Recovery checkpoint mapping rejected"
                    try { recovered = provider.restoreSession(context, unit) } catch (error: Exception) { restoreReason = error.message }
                    if (!recovered) {
                        unit = provider.expandRecovery(context, unit, restoreReason).getOrThrow()
                        continue
                    }
                    parser.editingContext = Some(context)
                    parser.lineIndex.bindEditableSource(target)
                    parser.setNextNodeIdForEditing(allocatedNext)
                    let kernel = kernelFactory(parser)
                    if (!provider.restoreKernel(context, unit, kernel)) {
                        unit = provider.expandRecovery(context, unit, "Open frame needs provider source mapping").getOrThrow()
                        continue
                    }
                    let attemptNext = allocatedNext
                    let attempt = context.beginSessionScope()
                    var keepAttempt = false
                    try {
                    context.enterOwner(unit.nodeId, unit.owner)
                    if (!provider.restore(context, unit.syntax) || !provider.rollbackEffects(context, unit.syntax)) {
                        throw IllegalArgumentException("Provider rejected recovery checkpoint")
                    }
                    if (!provider.preservesUntouchedChildEffects) {
                        revokeSubtree(semantic, currentView.raw(unit.nodeId).getOrThrow())
                    }
                    let result = provider.parseUnit(context, unit, kernel)
                    syntaxCount += 1
                    allocatedNext = parser.nextNodeId
                    guardCurrent(epoch, target.identity.version)
                    if (!result.converged) {
                        unit = provider.expandRecovery(context, unit, result.reason).getOrThrow()
                        continue
                    }
                    let expectedExit = unit.expectedExit.getOrThrow()
                    let expectedKernel = unit.expectedKernel.getOrThrow()
                    if (expectedExit.documentId != target.identity.documentId || expectedExit.owner != unit.owner ||
                        expectedExit.sourceVersion > target.identity.version || result.exit.documentId != target.identity.documentId ||
                        result.exit.owner != unit.owner || result.exit.sourceVersion != target.identity.version) {
                        throw IllegalArgumentException("Invalid recovery exit ownership/version")
                    }
                    if (!provider.syntaxEquivalent(expectedExit, result.exit) || !kernel.checkpoint().syntaxEquivalent(expectedKernel)) {
                        unit = provider.expandRecovery(context, unit, "syntax context did not converge").getOrThrow()
                        continue
                    }
                    let patchBase = patches.size
                    let resultStage = BlockResultStage(syntax.preview(target.identity.version), Some(syntax), codec, semantic, patches)
                    resultStage.apply(unit.nodeId, result)
                    // Supersede earlier recovery-unit patches, retaining every
                    // ordered child edit emitted by this result's atomic batch.
                    var patchIndex = patchBase
                    while (patchIndex > 0) {
                        patchIndex -= 1
                        if (currentView.pathTo(patches[patchIndex].replacedId).contains(unit.nodeId)) { patches.remove(at: patchIndex) }
                    }
                    completedUnits.add(unit.nodeId)
                    complete = true
                    keepAttempt = true
                    } finally {
                        attempt.complete(keepAttempt)
                        if (!keepAttempt) { allocatedNext = attemptNext }
                    }
                }
            }
            // Semantic readers are a separate worklist. Raw syntax convergence
            // never depends on a global semantic-map fingerprint.
            var preparedTree = syntax.preview(target.identity.version)
            for (removed in syntax.removedNodeIds()) {
                if (preparedTree.find(removed).isSome()) { semantic.revokeOriginalOwner(removed) }
                else { semantic.revokeOwner(removed) }
            }
            var preparedEffects = semantic.prepare()
            var progressed = true
            var semanticRounds: Int64 = 0
            while (progressed) {
                guardCurrent(epoch, target.identity.version)
                semanticRounds += 1
                if (semanticRounds > preparedTree.nodeCount + 1) { throw IllegalArgumentException("Semantic effects did not converge") }
                progressed = false
                for (owner in preparedEffects.invalidatedOwners()) {
                    guardCurrent(epoch, target.identity.version)
                    if (let Some(node) <- preparedTree.raw(owner)) {
                        var foundProvider = false
                        for (provider in providers) {
                            if (provider.owns(node)) {
                                let syntaxKeys = provider.syntaxReadKeys(node)
                                var syntaxInvalidated = syntaxKeys.isNone()
                                if (let Some(keys) <- syntaxKeys) {
                                    for (key in preparedEffects.invalidatedKeysForOwner(owner)) {
                                        if (keys.contains(key)) { syntaxInvalidated = true }
                                    }
                                }
                                if (syntaxInvalidated) {
                                    let span = preparedTree.resolvedSpan(node).getOrThrow()
                                    var alreadyDirty = false
                                    for (range in dirty) {
                                        if (source.resolve(range.start, target.identity.version) == Some(span.startByte) &&
                                            source.resolve(range.end, target.identity.version) == Some(span.endByte)) { alreadyDirty = true }
                                    }
                                    if (alreadyDirty) { throw IllegalArgumentException("Syntax read dependencies did not converge") }
                                    dirty.add(DirtySourceRange(SourceAnchor(target.identity, span.startByte, affinity: AnchorAffinity.Before),
                                        SourceAnchor(target.identity, span.endByte, affinity: AnchorAffinity.After)))
                                    throw IllegalArgumentException("syntax-dependency-expansion")
                                }
                                context = context.withPrevious(preparedTree,
                                    invalidatedKeys: preparedEffects.invalidatedKeysForOwner(owner))
                                parser.editingContext = Some(context)
                                if (provider.preservesUnchangedSemanticReads) {
                                    semantic.refreshOwner(owner, preparedEffects.invalidatedKeysForOwner(owner))
                                } else { semantic.revokeOwner(owner) }
                                context.enterOwner(owner, provider.owner)
                                if (let Some(result) <- provider.replaySemanticResult(context, node)) {
                                    validateSemanticResult(result, provider, context)
                                    let resultStage = BlockResultStage(preparedTree, Some(syntax), codec, semantic, patches)
                                    resultStage.apply(owner, result, revokeGone: true)
                                    preparedTree = resultStage.view
                                }
                                semanticCount += 1; progressed = true; foundProvider = true; break
                            }
                        }
                        if (!foundProvider) { throw IllegalArgumentException("Missing semantic replay provider") }
                    } else { semantic.revokeOwner(owner); progressed = true }
                }
                if (progressed) { preparedEffects = semantic.prepare() }
            }
            // Seal syntax only after all local semantic changes have converged.
            preparedTree = syntax.prepare(target.identity.version)
            let candidate = EditingDocumentSnapshot(preparedTree, preparedEffects.snapshot, patches.toArray(),
                lifecycle.retention.retain(preparedTree.earliestAnchorVersion))
            candidateSnapshot = Some(candidate)
            // Workspace disposal belongs to preparation; it cannot invalidate
            // an already installed document if it fails.
            parser.releaseEditingWorkspace()
            parser.editingContext = None
            guardCurrent(epoch, target.identity.version)
            if (!syntax.validatePrepared(preparedTree) || !semantic.validatePrepared(preparedEffects)) {
                throw IllegalArgumentException("Stale prepared editing transaction")
            }
            // No user/provider/render callbacks occur between this precheck and
            // the single published snapshot pointer. Both installs are prepared.
            syntax.installPrepared(preparedTree)
            semantic.installPrepared(preparedEffects)
            let previous = published
            published = candidate
            candidateSnapshot = None
            nextNodeId = allocatedNext
            versions.commitParse(target.identity.version)
            dirty.clear()
            committed = true
            retiredSnapshots.add(previous)
            retryCleanup()
            outcome = EditingFlushResult(true, versions.sourceVersion, versions.parseVersion,
                syntaxUnitsParsed: syntaxCount, semanticOwnersReplayed: semanticCount)
        } catch (error: Exception) {
            if (!committed) {
                if (let Some(candidate) <- candidateSnapshot) { retiredSnapshots.add(candidate) }
                syntax.cancel(); semantic.cancel()
                parser.restoreCheckpoint(rollback)
                parser.editingContext = None
            }
            outcome = EditingFlushResult(committed, versions.sourceVersion, versions.parseVersion,
                syntaxUnitsParsed: syntaxCount, semanticOwnersReplayed: semanticCount, reason: error.message)
        } finally {
            // Preserve failed cleanup handles for close/next flush. Cleanup
            // must never turn a successful atomic publication into a rollback.
            for (lease in recoveryLeases) { deferredLeases.add(lease) }
            deferredLeases.add(sourceLease)
            try { retryCleanup() } catch (error: Exception) {
                outcome = EditingFlushResult(committed, versions.sourceVersion, versions.parseVersion,
                    syntaxUnitsParsed: syntaxCount, semanticOwnersReplayed: semanticCount, reason: error.message)
            }
        }
        return outcome
    }

    public func close(): Unit {
        if (computing) { throw IllegalArgumentException("Cannot close during editing computation") }
        if (!closed) {
            retryCleanup()
            published.release()
            if (let Some(lease) <- conservativeHistory) { lease.release() }
            lifecycle.retention.clearCurrent(); lifecycle.pruneHistory()
            closed = true
        }
    }
    private func retryCleanup(): Unit {
        while (!retiredSnapshots.isEmpty()) {
            retiredSnapshots[retiredSnapshots.size - 1].release()
            retiredSnapshots.remove(at: retiredSnapshots.size - 1)
        }
        while (!deferredLeases.isEmpty()) {
            deferredLeases[deferredLeases.size - 1].release()
            deferredLeases.remove(at: deferredLeases.size - 1)
        }
        lifecycle.pruneHistory()
    }
    private func revokeSubtree(transaction: OwnedEffectsTransaction, node: RawSyntaxNode): Unit {
        transaction.revokeOwner(node.identity.nodeId)
        for (index in 0..node.childCount) { revokeSubtree(transaction, node.childAt(index)) }
    }
    private func requireRegistered(candidate: BlockEditingFacet): BlockEditingFacet {
        let identity = (candidate as Object).getOrThrow()
        for (provider in providers) {
            if (let Some(registered) <- (provider as Object)) {
                if (refEq(identity, registered)) { return provider }
            }
        }
        throw IllegalArgumentException("Unregistered editing recovery provider")
    }
    private func providerFor(owner: String, node: RawSyntaxNode): BlockEditingFacet {
        var selected: ?BlockEditingFacet = Option<BlockEditingFacet>.None
        for (provider in providers) {
            if (provider.owner == owner && provider.owns(node)) {
                if (selected.isSome()) { throw IllegalArgumentException("Ambiguous recovery provider") }
                selected = Some(provider)
            }
        }
        if (let Some(provider) <- selected) { return provider }
        throw IllegalArgumentException("Missing block editing provider: " + owner)
    }
    private func flushFallback(parse: (EditableSourceVersion) -> DocumentSnapshot, target: EditableSourceVersion): EditingFlushResult {
        let epoch = computationEpoch
        let syntax = PersistentDocumentTransaction(tree, tree.snapshot)
        let semantic = effects.beginTransaction()
        var candidate: ?EditingDocumentSnapshot = None
        var committed = false
        try {
            let legacy = parse(target)
            let raw = legacySessionRaw(target)
            syntax.replace(tree.snapshot.root.identity.nodeId, raw)
            let preparedTree = syntax.prepare(target.identity.version)
            let preparedEffects = semantic.prepare()
            let next = EditingDocumentSnapshot(preparedTree, preparedEffects.snapshot,
                [], lifecycle.retention.retain(preparedTree.earliestAnchorVersion), legacySnapshot: Some(legacy))
            candidate = Some(next)
            guardCurrent(epoch, target.identity.version)
            if (!syntax.validatePrepared(preparedTree) || !semantic.validatePrepared(preparedEffects)) {
                throw IllegalArgumentException("Stale prepared fallback transaction")
            }
            syntax.installPrepared(preparedTree); semantic.installPrepared(preparedEffects)
            let old = published; published = next; candidate = None
            versions.commitParse(target.identity.version); dirty.clear(); committed = true
            retiredSnapshots.add(old); retryCleanup()
            return EditingFlushResult(true, versions.sourceVersion, versions.parseVersion,
                reason: "session fallback: executable incremental provider unavailable")
        } catch (error: Exception) {
            if (!committed) {
                if (let Some(next) <- candidate) { retiredSnapshots.add(next) }
                syntax.cancel(); semantic.cancel()
            }
            return EditingFlushResult(committed, versions.sourceVersion, versions.parseVersion, reason: error.message)
        }
    }
    private func guardCurrent(epoch: Int64, version: Int64): Unit {
        if (let Some(validate) <- validateExecution) { validate() }
        for (index in 0..providers.size) {
            if (providers[index].grammarVersion != grammarIdentities[index]) {
                throw IllegalArgumentException("Editing grammar identity changed")
            }
        }
        if (computationEpoch != epoch || source.current.identity.version != version) {
            throw IllegalArgumentException("Cancelled or stale editing computation")
        }
    }
    private func requireOpen(): Unit { if (closed) { throw IllegalArgumentException("Closed editing session") } }
}
