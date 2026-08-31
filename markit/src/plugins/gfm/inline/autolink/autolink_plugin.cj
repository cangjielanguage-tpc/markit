package markit.plugins.gfm.inline.autolink

import markit.core.plugin.{Plugin, PluginRegistrar}

public class AutolinkPlugin <: Plugin {
    public prop name: String {
        get() {
            return "AutolinkPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(AutolinkParser())
        registrar.registerHtmlRenderer("Autolink", AutolinkHtmlRenderer())
        registrar.registerMarkdownRenderer("Autolink", AutolinkMarkdownRenderer())
        registrar.registerTypstRenderer("Autolink", AutolinkTypstRenderer())
    }
}
