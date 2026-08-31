package markit.plugins.gfm.inline.strikethrough

import markit.core.plugin.{Plugin, PluginRegistrar}

public class StrikethroughPlugin <: Plugin {
    public prop name: String {
        get() {
            return "StrikethroughPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(StrikethroughParser())
        registrar.registerHtmlRenderer("Strikethrough", StrikethroughHtmlRenderer())
        registrar.registerMarkdownRenderer("Strikethrough", StrikethroughMarkdownRenderer())
        registrar.registerTypstRenderer("Strikethrough", StrikethroughTypstRenderer())
    }
}
