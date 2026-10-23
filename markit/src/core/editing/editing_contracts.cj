package markit.core.editing

import std.collection.ArrayList

public enum EditingPolicy <: Equatable<EditingPolicy> {
    | Compat
    | Strict

    public operator func ==(right: EditingPolicy): Bool {
        match ((this, right)) { case (Compat, Compat) | (Strict, Strict) => true; case _ => false }
    }
}

public enum EditingFallbackScope <: Equatable<EditingFallbackScope> {
    | NoFallback
    | IsolatedUnit
    | Session
    | Rejected

    public operator func ==(right: EditingFallbackScope): Bool {
        match ((this, right)) {
            case (NoFallback, NoFallback) | (IsolatedUnit, IsolatedUnit) | (Session, Session) | (Rejected, Rejected) => true
            case _ => false
        }
    }
}

// A provider must justify all three boundaries before a legacy parser can be
// rebuilt locally. Absence of evidence always means a session rebuild.
public class ParserIsolationProof {
    public ParserIsolationProof(public let syntaxBoundary!: Bool = false, public let stateBoundary!: Bool = false,
        public let semanticBoundary!: Bool = false, public let evidence!: String = "") {}

    public prop verified: Bool {
        get() { return syntaxBoundary && stateBoundary && semanticBoundary && !evidence.isEmpty() }
    }
}

public class IncrementalReadDependency {
    public IncrementalReadDependency(public let owner: String, public let key: String, public let found: Bool, public let version: Int64) {}
}

// Payload ownership is the provider's responsibility: clone must not alias a
// mutable live state. The engine never invents an empty successful restore.
public interface IncrementalStatePayload {
    func clonePayload(): IncrementalStatePayload
    func fingerprint(): String
}

public interface IncrementalParserContext {
    prop documentId: String
    prop sourceVersion: Int64
    func readState(key: String): ?IncrementalStatePayload
    func writeState(key: String, payload: IncrementalStatePayload): Bool
    func revokeOwnerEffects(owner: String): Bool
}

public class IncrementalCheckpoint {
    public let documentId: String
    public let owner: String
    public let sourceVersion: Int64
    private let capturedPayload: IncrementalStatePayload
    public prop payload: IncrementalStatePayload { get() { return capturedPayload.clonePayload() } }

    public IncrementalCheckpoint(documentId: String, owner: String, sourceVersion: Int64, payload: IncrementalStatePayload,
        public let syntaxContext!: String = "") {
        if (documentId.isEmpty() || owner.isEmpty() || sourceVersion < 0) {
            throw IllegalArgumentException("Invalid checkpoint ownership/version")
        }
        this.documentId = documentId
        this.owner = owner
        this.sourceVersion = sourceVersion
        this.capturedPayload = payload.clonePayload()
    }
}

// Opt-in is a real provider object, not a flag that silently assumes restore,
// effect rollback or a node codec. The defaults on existing parsers return None.
public interface IncrementalParserFacet {
    prop owner: String
    prop hasStateCodec: Bool
    prop hasEffectRollback: Bool
    prop hasReadEvidence: Bool
    prop hasNodeCodec: Bool
    func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint
    func restore(context: IncrementalParserContext, checkpoint: IncrementalCheckpoint): Bool
    func rollbackEffects(context: IncrementalParserContext, checkpoint: IncrementalCheckpoint): Bool
    func syntaxEquivalent(previous: IncrementalCheckpoint, current: IncrementalCheckpoint): Bool
    func readDependencies(): ArrayList<IncrementalReadDependency>
}

public class EditingVersionState {
    public let documentId: String
    private var acceptedSource: Int64
    private var committedParse: Int64
    private var committedRender: Int64
    public prop sourceVersion: Int64 { get() { return acceptedSource } }
    public prop parseVersion: Int64 { get() { return committedParse } }
    public prop renderVersion: Int64 { get() { return committedRender } }

    public EditingVersionState(documentId: String, initialVersion!: Int64 = 0) {
        if (documentId.isEmpty() || initialVersion < 0) {
            throw IllegalArgumentException("Invalid document/version")
        }
        this.documentId = documentId
        this.acceptedSource = initialVersion
        this.committedParse = initialVersion
        this.committedRender = initialVersion
    }

    public func acceptSource(expectedVersion: Int64): Int64 {
        if (expectedVersion != sourceVersion) {
            throw IllegalArgumentException("Stale source version")
        }
        acceptedSource += 1
        return sourceVersion
    }

    public func commitParse(version: Int64): Bool {
        if (version != sourceVersion || version < parseVersion) { return false }
        committedParse = version
        return true
    }

    public func commitRender(version: Int64): Bool {
        if (version != sourceVersion || version != parseVersion || version < renderVersion) { return false }
        committedRender = version
        return true
    }

    // Cancellation discards unpublished work; accepted source remains intact.
    public func cancelComputation(): Unit {}
}
