package markit.plugins.standard.block.list

import markit.core.plugin.{Plugin, PluginRegistrar}

public class ListPlugin <: Plugin {
    private let config: ListConfig

    public init(config!: ListConfig = ListConfig()) {
        this.config = config
    }

    public prop name: String {
        get() {
            return "ListPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0-scaffold"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(ListBlockParser())
        registrar.registerHtmlRenderer("List", ListHtmlRenderer())
        registrar.registerMarkdownRenderer("List", ListMarkdownRenderer())
        registrar.registerTypstRenderer("List", ListTypstRenderer())
    }
}
