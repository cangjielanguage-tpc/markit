package markit.plugins.anchor

import markit.core.plugin.{Plugin, PluginRegistrar}

public class AutoAnchorPlugin <: Plugin {
    public AutoAnchorPlugin(private let config!: AutoAnchorConfig = AutoAnchorConfig()) {}

    public prop name: String {
        get() {
            return "AutoAnchorPlugin"
        }
    }

    public prop version: String {
        get() {
            return "0.1.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        if (!config.anyEnabled()) {
            return
        }
        registrar.registerPostFinalizeProcessor({ root, _ =>
            AutoAnchorPostProcessor(config).process(root)
        })
    }
}
