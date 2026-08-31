package markit.plugins.toc

import markit.core.plugin.{Plugin, PluginRegistrar}

public class TocPlugin <: Plugin {
    public prop name: String {
        get() {
            return "TocPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerHtmlRenderer("Toc", TocHtmlRenderer())
        registrar.registerMarkdownRenderer("Toc", TocMarkdownRenderer())
        registrar.registerTypstRenderer("Toc", TocTypstRenderer())
    }
}
