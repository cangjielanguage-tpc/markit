package markit.plugins.standard.inline.bold

import markit.core.plugin.{Plugin, PluginRegistrar}

public class BoldPlugin <: Plugin {
    public prop name: String {
        get() {
            return "BoldPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(BoldParser())
        registrar.registerHtmlRenderer("Bold", BoldHtmlRenderer())
        registrar.registerMarkdownRenderer("Bold", BoldMarkdownRenderer())
        registrar.registerTypstRenderer("Bold", BoldTypstRenderer())
    }
}
