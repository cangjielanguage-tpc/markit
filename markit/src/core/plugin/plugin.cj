package markit.core.plugin

public interface Plugin {
    prop name: String
    prop version: String
    func register(registrar: PluginRegistrar): Unit
}

public interface Bundle {
    prop name: String
    prop version: String
    prop plugins: Array<Plugin>

    prop includesStandardMarkdown: Bool {
        get() {
            return name == "StandardMarkdownBundle"
        }
    }
}
