package markit.core.block

import markit.core.editing.*
import markit.core.document.PersistentDocumentVersion
import markit.core.nodes.{Node, RawSyntaxNode, PersistentNodeBundle}
import markit.core.session.{ParseSession, ParseSessionCheckpoint, OwnedEffectsTransaction, OwnedEffectsScope, ParseSessionTransactionParticipant, ParseSessionTransactionScope}
import markit.core.source.{SourceLine, SourceSpan}
import std.collection.{ArrayList, HashMap}

// Recovery boundaries are grammar-provider evidence. The scheduler never
// selects a boundary from a marker, node kind, or built-in plugin list.
public class BlockRecoveryUnit {
    public let owner: String
    public let nodeId: Int64
    public let start: SourceAnchor
    public let end: SourceAnchor
    public let session: ParseSessionCheckpoint
    public let kernel: BlockKernelCheckpoint
    public let syntax: IncrementalCheckpoint
    public let expectedExit: ?IncrementalCheckpoint
    public let expectedKernel: ?BlockKernelCheckpoint
    public let mappingVersion: Int64
    public let nestedContext: String
    public let provider: ?BlockEditingFacet
    public BlockRecoveryUnit(owner: String, nodeId: Int64, start: SourceAnchor, end: SourceAnchor,
        session: ParseSessionCheckpoint, kernel: BlockKernelCheckpoint,
        syntax: IncrementalCheckpoint, mappingVersion!: Int64 = -1, nestedContext!: String = "",
        expectedExit!: ?IncrementalCheckpoint = None, expectedKernel!: ?BlockKernelCheckpoint = None,
        provider!: ?BlockEditingFacet = None) {
        if (owner.isEmpty() || nodeId < 0 || owner != syntax.owner ||
            start.source.documentId != syntax.documentId || end.source.documentId != syntax.documentId) {
            throw IllegalArgumentException("Recovery unit identity mismatch")
        }
        this.owner = owner; this.nodeId = nodeId; this.start = start; this.end = end
        this.session = session; this.kernel = kernel; this.syntax = syntax
        this.mappingVersion = mappingVersion; this.nestedContext = nestedContext
        this.expectedExit = expectedExit; this.expectedKernel = expectedKernel
        this.provider = provider
    }
}

public class BlockUnitParseResult {
    private let changedPayloads: Array<BlockPayloadUpdate>
    public let replacement: Node
    public let exit: IncrementalCheckpoint
    public prop payloadUpdates: Array<BlockPayloadUpdate> { get() { return changedPayloads.clone() } }
    public BlockUnitParseResult(replacement: Node, exit: IncrementalCheckpoint,
        payloadUpdates!: Array<BlockPayloadUpdate> = [],
        public let converged!: Bool = true, public let reason!: String = "",
        public let splice!: ?BlockChildrenEdit = None, public let rawReplacement!: ?PersistentNodeBundle = None,
        public let rawSplice!: ?BlockRawChildrenEdit = None) {
        this.replacement = replacement; this.exit = exit; this.changedPayloads = payloadUpdates.clone()
    }
}

// Payload-only updates retain child identities and the persistent child index.
// Both the input and each exported payload are detached from provider objects.
public class BlockPayloadUpdate {
    private let captured: SyntaxNodePayload
    public let nodeId: Int64
    public BlockPayloadUpdate(payload: SyntaxNodePayload, nodeId: Int64) {
        if (nodeId < 0) { throw IllegalArgumentException("Invalid payload update identity") }
        this.nodeId = nodeId; this.captured = payload.clonePayload()
    }
    public prop payload: SyntaxNodePayload { get() { return captured.clonePayload() } }
}

public class BlockRawChildrenEdit {
    private let insertedRecords: Array<PersistentNodeBundle>
    private let literalChanges: Array<LogicalTextSplice>
    private let followingEdits: Array<BlockRawChildrenEdit>
    public let parentId: Int64
    public let start: Int64
    public let deleteCount: Int64
    public prop textSplices: Array<LogicalTextSplice> { get() { return literalChanges.clone() } }
    public prop inserted: Array<PersistentNodeBundle> { get() { return insertedRecords.clone() } }
    public prop following: Array<BlockRawChildrenEdit> { get() { return followingEdits.clone() } }
    public BlockRawChildrenEdit(inserted: Array<PersistentNodeBundle>, textSplices: Array<LogicalTextSplice>,
        parentId: Int64, start: Int64, deleteCount: Int64, following!: Array<BlockRawChildrenEdit> = []) {
        if (parentId < 0 || start < 0 || deleteCount < 0) { throw IllegalArgumentException("Invalid raw children edit") }
        this.parentId = parentId; this.start = start; this.deleteCount = deleteCount
        this.insertedRecords = inserted.clone(); this.literalChanges = textSplices.clone()
        this.followingEdits = following.clone()
    }
}

public class BlockChildrenEdit {
    public let parentId: Int64
    public let start: Int64
    public let deleteCount: Int64
    public let inserted: Array<Node>
    public BlockChildrenEdit(parentId: Int64, start: Int64, deleteCount: Int64, inserted: Array<Node>) {
        this.parentId = parentId; this.start = start; this.deleteCount = deleteCount
        this.inserted = inserted.clone()
    }
}

public class BlockEditingContext <: IncrementalParserContext & ParseSessionTransactionParticipant {
    public let session: ParseSession
    public let source: EditableSourceVersion
    public let previous: ?PersistentDocumentVersion
    public let effects: OwnedEffectsTransaction
    public let recoveryCheckpoint: ?ParseSessionCheckpoint
    public let baseSourceVersion: Int64
    private var states = HashMap<String, IncrementalStatePayload>()
    private let stateParents = ArrayList<HashMap<String, IncrementalStatePayload>>()
    private var effectOwner: Int64 = -1
    private var providerOwner: String = ""
    private var changedSemanticKeys: Array<String> = []
    public prop invalidatedKeys: Array<String> { get() { return changedSemanticKeys.clone() } }
    private let resolver: (SourceAnchor) -> ?Int64
    public prop documentId: String { get() { return source.identity.documentId } }
    public prop sourceVersion: Int64 { get() { return source.identity.version } }
    public BlockEditingContext(session: ParseSession, source: EditableSourceVersion,
        previous: ?PersistentDocumentVersion, effects: OwnedEffectsTransaction,
        resolve!: ?(SourceAnchor) -> ?Int64 = None, recoveryCheckpoint!: ?ParseSessionCheckpoint = None,
        baseSourceVersion!: Int64 = -1) {
        this.session = session; this.source = source; this.previous = previous; this.effects = effects
        this.recoveryCheckpoint = recoveryCheckpoint
        this.baseSourceVersion = if (baseSourceVersion < 0) { source.identity.version } else { baseSourceVersion }
        this.resolver = resolve ?? { anchor: SourceAnchor =>
            if (anchor.source.documentId == source.identity.documentId && anchor.source.version == source.identity.version) {
                Some(anchor.byteOffset)
            } else { Option<Int64>.None }
        }
    }
    public func readState(key: String): ?IncrementalStatePayload {
        if (let Some(payload) <- states.get(key)) { return Some(payload.clonePayload()) }
        var index = stateParents.size
        while (index > 0) {
            index -= 1
            if (let Some(payload) <- stateParents[index].get(key)) { return Some(payload.clonePayload()) }
        }
        return None
    }
    public func writeState(key: String, payload: IncrementalStatePayload): Bool {
        states[key] = payload.clonePayload(); return true
    }
    // A semantic callback observes the staged candidate, while state and effects
    // stay in the same transaction. Fork only outside an active parser scope.
    public func withPrevious(candidate: PersistentDocumentVersion, invalidatedKeys!: Array<String> = []): BlockEditingContext {
        if (!stateParents.isEmpty() || candidate.documentId != documentId || candidate.version != sourceVersion) {
            throw IllegalArgumentException("Invalid staged editing context")
        }
        let next = BlockEditingContext(session, source, Some(candidate), effects, resolve: Some(resolver),
            recoveryCheckpoint: recoveryCheckpoint, baseSourceVersion: baseSourceVersion)
        next.states = states
        next.changedSemanticKeys = invalidatedKeys.clone()
        return next
    }
    public func enterOwner(ownerId: Int64, owner: String): Unit { effectOwner = ownerId; providerOwner = owner }
    public func revokeOwnerEffects(owner: String): Bool {
        if (effectOwner < 0 || owner != providerOwner) { return false }
        effects.revokeOwner(effectOwner); return true
    }
    public func resolve(anchor: SourceAnchor): ?Int64 { return resolver(anchor) }
    public func remapRawLine(line: SourceLine, bornVersion: Int64, pending: Bool): SourceLine {
        let identity = SourceVersionIdentity(documentId, bornVersion)
        let start = resolve(SourceAnchor(identity, line.span.startByte, affinity: AnchorAffinity.Before)).getOrThrow()
        let end = resolve(SourceAnchor(identity, line.span.endByte, affinity: AnchorAffinity.After)).getOrThrow()
        if (!pending) {
            let position = source.coordinateAtByte(start).getOrThrow()
            let current = source.lineAt(position.line).getOrThrow()
            let finish = current.startByte + current.content.size
            let a = source.coordinateAtByte(current.startByte).getOrThrow()
            let b = source.coordinateAtByte(finish).getOrThrow()
            return SourceLine(current.content, SourceSpan(a.byteOffset, b.byteOffset, a.runeOffset, b.runeOffset),
                terminated: !current.lineEnding.isEmpty())
        }
        let a = source.coordinateAtByte(start).getOrThrow(); let b = source.coordinateAtByte(end).getOrThrow()
        return SourceLine(source.sliceBytes(start, end), SourceSpan(start, end, a.runeOffset, b.runeOffset), terminated: line.terminated)
    }
    public func beginSessionScope(): ParseSessionTransactionScope {
        let effectScope = effects.beginScope()
        let previous = states
        stateParents.add(previous)
        states = HashMap<String, IncrementalStatePayload>()
        return BlockEditingScope(this, previous, effectScope, effectOwner, providerOwner)
    }
    internal func finishScope(previous: HashMap<String, IncrementalStatePayload>, commit: Bool,
        ownerId: Int64, owner: String): Unit {
        if (commit) {
            for ((key, payload) in states) { previous[key] = payload }
        }
        states = previous
        stateParents.remove(at: stateParents.size - 1)
        effectOwner = ownerId; providerOwner = owner
    }

    // Convert only the selected recovery window. The immutable rope remains
    // the source of truth, including CRLF and Unicode coordinate information.
    public func lines(start: Int64, end: Int64): ArrayList<SourceLine> {
        if (start < 0 || end < start || end > source.byteLength) {
            throw IllegalArgumentException("Invalid recovery window")
        }
        let output = ArrayList<SourceLine>()
        let begin = source.coordinateAtByte(start).getOrThrow()
        if (begin.line < 0) { throw IllegalArgumentException("Recovery starts inside CRLF") }
        var index = begin.line
        while (index < source.lineCount) {
            let line = source.lineAt(index).getOrThrow()
            if (line.startByte >= end && !(start == end && line.startByte == start)) { break }
            let finish = line.startByte + line.content.size
            if (line.startByte < start || finish > end) { throw IllegalArgumentException("Provider recovery is not a complete line window") }
            let a = source.coordinateAtByte(line.startByte).getOrThrow()
            let b = source.coordinateAtByte(finish).getOrThrow()
            output.add(SourceLine(line.content, SourceSpan(a.byteOffset, b.byteOffset, a.runeOffset, b.runeOffset),
                terminated: !line.lineEnding.isEmpty()))
            index += 1
        }
        return output
    }
}

private class BlockEditingScope <: ParseSessionTransactionScope {
    private var context: ?BlockEditingContext
    private var previous: ?HashMap<String, IncrementalStatePayload>
    private var effects: ?OwnedEffectsScope
    private var active: Bool = true
    public BlockEditingScope(context: BlockEditingContext, previous: HashMap<String, IncrementalStatePayload>,
        effects: OwnedEffectsScope, private let ownerId: Int64, private let owner: String) {
        this.context = Some(context); this.previous = Some(previous); this.effects = Some(effects)
    }
    public func complete(commit: Bool): Unit {
        if (active) {
            effects.getOrThrow().complete(commit)
            context.getOrThrow().finishScope(previous.getOrThrow(), commit, ownerId, owner)
            active = false
            // A provider may retain a completed scope; it no longer owns the
            // borrowed context or the previous published syntax version.
            context = None; previous = None; effects = None
        }
    }
}

public interface BlockEditingFacet <: IncrementalParserFacet {
    prop grammarVersion: String
    // The provider owns a proven local child window and revokes only that
    // window before parsing; untouched descendants retain their contributions.
    prop preservesUntouchedChildEffects: Bool { get() { return false } }
    // Opt-in semantic replay replaces only the actual invalidated read keys.
    // Legacy/full-owner providers retain complete dependency replacement.
    prop preservesUnchangedSemanticReads: Bool { get() { return false } }
    // False is safe for opaque state/mapping payloads: the session pins its
    // original epoch until close. True is a provider promise that no retained
    // checkpoint or mapping predates its reachable raw records' birth floor.
    prop retainsOnlyRawBirthEpochs: Bool { get() { return false } }
    // None is unknown and conservatively treats actual invalidated reads as
    // grammar dependencies. Some([]) explicitly declares semantic-only reads.
    func syntaxReadKeys(node: RawSyntaxNode): ?Array<String> { return None }
    func restoreSession(context: BlockEditingContext, unit: BlockRecoveryUnit): Bool {
        // Synthetic/normalized views must supply their provider's own mapping.
        if (unit.mappingVersion >= 0) { return false }
        return context.session.restoreEditingCheckpoint(unit.session, remapLine: Some({ line: SourceLine, pending: Bool =>
            context.remapRawLine(line, unit.syntax.sourceVersion, pending)
        }))
    }
    func restoreKernel(context: BlockEditingContext, unit: BlockRecoveryUnit, kernel: BlockParsingKernel): Bool {
        if (unit.kernel.hasOpenFrame && unit.syntax.sourceVersion != context.sourceVersion) { return false }
        kernel.restore(unit.kernel); return true
    }
    func owns(node: RawSyntaxNode): Bool
    func recoverGap(context: BlockEditingContext, editStart: Int64, editEnd: Int64): ?BlockRecoveryUnit { return None }
    func recover(context: BlockEditingContext, node: RawSyntaxNode,
        editStart: Int64, editEnd: Int64): ?BlockRecoveryUnit
    // Providers invoke the shared kernel, or the same registered parser entry
    // with an explicit mapped child view. They do not supply a second parser.
    func parseUnit(context: BlockEditingContext, unit: BlockRecoveryUnit,
        kernel: BlockParsingKernel): BlockUnitParseResult
    func expandRecovery(context: BlockEditingContext, unit: BlockRecoveryUnit,
        reason: String): ?BlockRecoveryUnit { return None }
    func replaySemantic(context: BlockEditingContext, node: RawSyntaxNode): Unit {}
    // Existing providers keep their Unit override. Opt-in providers may publish
    // local typed/tree changes through the same atomic tree/effects gate.
    func replaySemanticResult(context: BlockEditingContext, node: RawSyntaxNode): ?BlockUnitParseResult {
        replaySemantic(context, node); return None
    }
}
