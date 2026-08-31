package markit.plugins.commonmark.block.setext_heading

import markit.core.plugin.{Plugin, PluginRegistrar}

public class SetextHeadingPlugin <: Plugin {
    public prop name: String {
        get() {
            return "SetextHeadingPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(SetextHeadingParser())
    }
}
