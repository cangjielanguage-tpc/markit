package markit.plugins.standard.block.divider

import markit.core.plugin.{Plugin, PluginRegistrar}

public class DividerPlugin <: Plugin {
    public prop name: String {
        get() {
            return "DividerPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0-scaffold"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(DividerBlockParser())
        registrar.registerHtmlRenderer("Divider", DividerHtmlRenderer())
        registrar.registerMarkdownRenderer("Divider", DividerMarkdownRenderer())
        registrar.registerTypstRenderer("Divider", DividerTypstRenderer())
    }
}
