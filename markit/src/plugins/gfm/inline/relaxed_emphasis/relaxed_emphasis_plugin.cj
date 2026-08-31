package markit.plugins.gfm.inline.relaxed_emphasis

import markit.core.plugin.{Plugin, PluginRegistrar}

public class RelaxedEmphasisPlugin <: Plugin {
    public prop name: String {
        get() {
            return "RelaxedEmphasisPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(RelaxedEmphasisParser())
    }
}
