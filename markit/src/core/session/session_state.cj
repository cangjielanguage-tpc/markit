package markit.core.session

public interface SessionStatePayload {
    prop fingerprint: String
    func detachedCopy(): SessionStatePayload
}

// Keep the legacy name-only object layout: batch parsing does not store edit
// payloads, versions, or nested context unless a provider explicitly opts in.
public open class SessionStateSnapshot {
    public let dynamicName: String

    public init(dynamicName: String) {
        this.dynamicName = dynamicName
    }

    public open prop sourceVersion: Int64 { get() { return -1 } }
    public open prop contextFingerprint: String { get() { return "" } }
    public open prop hasRestorablePayload: Bool { get() { return false } }
    public open prop fingerprint: String { get() { return "" } }
    public open func payloadCopy(): ?SessionStatePayload { return None }
}

public class RestorableSessionStateSnapshot <: SessionStateSnapshot {
    private let capturedSourceVersion: Int64
    private let capturedContext: String
    private let capturedPayload: SessionStatePayload

    public init(dynamicName: String, sourceVersion: Int64, contextFingerprint: String, payload: SessionStatePayload) {
        super(dynamicName)
        if (sourceVersion < 0 || contextFingerprint.isEmpty() || payload.fingerprint.isEmpty()) {
            throw IllegalArgumentException("Restorable state requires source version, context, and payload fingerprint")
        }
        this.capturedSourceVersion = sourceVersion
        this.capturedContext = contextFingerprint
        this.capturedPayload = payload.detachedCopy()
    }

    public override prop sourceVersion: Int64 { get() { return capturedSourceVersion } }
    public override prop contextFingerprint: String { get() { return capturedContext } }
    public override prop hasRestorablePayload: Bool { get() { return true } }
    public override prop fingerprint: String { get() { return capturedPayload.fingerprint } }
    public override func payloadCopy(): ?SessionStatePayload {
        return Some(capturedPayload.detachedCopy())
    }
}

public interface SessionState {
    func reset(): Unit
    func snapshot(): SessionStateSnapshot
    prop supportsStateRestore: Bool { get() { return false } }
    func restoreSnapshot(snapshot: SessionStateSnapshot): Bool { return false }
}
