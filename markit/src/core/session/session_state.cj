package markit.core.session

public class SessionStateSnapshot {
    public let dynamicName: String

    public init(dynamicName: String) {
        this.dynamicName = dynamicName
    }
}

public interface SessionState {
    func reset(): Unit
    func snapshot(): SessionStateSnapshot
}
