package markit.plugins.standard.inline.italic

import markit.core.plugin.{Plugin, PluginRegistrar}

public class ItalicPlugin <: Plugin {
    public prop name: String {
        get() {
            return "ItalicPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(ItalicParser())
        registrar.registerHtmlRenderer("Italic", ItalicHtmlRenderer())
        registrar.registerMarkdownRenderer("Italic", ItalicMarkdownRenderer())
        registrar.registerTypstRenderer("Italic", ItalicTypstRenderer())
    }
}
