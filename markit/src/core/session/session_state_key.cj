package markit.core.session

public struct SessionStateKey<T> where T <: SessionState {
    public let pluginName: String
    public let name: String

    public init(pluginName: String, name: String) {
        this.pluginName = pluginName
        this.name = name
    }

    public prop dynamicName: String {
        get() {
            return pluginName + "." + name
        }
    }
}
