package markit.core.editing

public struct SyntaxNodeIdentity {

    public SyntaxNodeIdentity(public let documentId: String, public let nodeId: Int64) {
        if (documentId.isEmpty() || nodeId < 0) {
            throw IllegalArgumentException("Invalid syntax identity")
        }
    }
}

// Opaque, typed payloads are decoded by the owner codec. Core never converts
// arbitrary typed nodes to only a kind/literal pair.
public interface SyntaxNodePayload {
    prop codecId: String
    func clonePayload(): SyntaxNodePayload
}

public interface PersistentSyntaxNode {
    prop identity: SyntaxNodeIdentity
    prop version: Int64
    prop startAnchor: SourceAnchor
    prop endAnchor: SourceAnchor
    prop payload: SyntaxNodePayload
    func children(): Array<PersistentSyntaxNode>
}

public interface PersistentSyntaxVersion {
    prop documentId: String
    prop version: Int64
    prop root: PersistentSyntaxNode
    func find(nodeId: Int64): ?PersistentSyntaxNode
}

public interface SyntaxEditTransaction {
    prop expectedVersion: Int64
    func replace(nodeId: Int64, replacement: PersistentSyntaxNode): Unit
    func commit(sourceVersion: Int64): PersistentSyntaxVersion
    func cancel(): Unit
}

public interface PersistentSyntaxStore {
    prop current: PersistentSyntaxVersion
    func beginTransaction(expectedVersion: Int64): SyntaxEditTransaction
}

public interface OwnedEffectPayload {
    func cloneEffectPayload(): OwnedEffectPayload
}

public class StringEffectPayload <: OwnedEffectPayload {
    public StringEffectPayload(public let value: String) {}
    public func cloneEffectPayload(): OwnedEffectPayload { return StringEffectPayload(value) }
}

public struct OwnedSemanticEffect {
    public OwnedSemanticEffect(public let ownerId: Int64, public let key: String, public let payload: OwnedEffectPayload, public let order: Int64) {}
}

// Offsets address the previous logical Text payload in UTF-8 bytes, not raw
// source coordinates. The containing snapshot supplies document/version.
// Consumers validate scalar boundaries and old payload length before applying.
public struct LogicalTextSplice {
    public LogicalTextSplice(public let nodeId: Int64, public let startByte: Int64,
        public let endByte: Int64, public let inserted: String) {
        if (nodeId < 0 || startByte < 0 || endByte < startByte) {
            throw IllegalArgumentException("Invalid logical Text splice")
        }
    }
}

public interface OwnedEffectTransaction {
    func revokeOwner(ownerId: Int64): Unit
    func add(effect: OwnedSemanticEffect): Unit
    func read(key: String, readerOwner: Int64): ?OwnedSemanticEffect
    func commit(): Unit
    func cancel(): Unit
}
