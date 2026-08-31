package markit.plugins.standard.inline.inline_code

import markit.core.plugin.{Plugin, PluginRegistrar}

public class InlineCodePlugin <: Plugin {
    public prop name: String {
        get() {
            return "InlineCodePlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(InlineCodeParser())
        registrar.registerHtmlRenderer("InlineCode", InlineCodeHtmlRenderer())
        registrar.registerMarkdownRenderer("InlineCode", InlineCodeMarkdownRenderer())
        registrar.registerTypstRenderer("InlineCode", InlineCodeTypstRenderer())
    }
}
