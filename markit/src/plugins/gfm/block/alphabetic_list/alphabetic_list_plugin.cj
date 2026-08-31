package markit.plugins.gfm.block.alphabetic_list

import markit.core.plugin.{Plugin, PluginRegistrar}

public class AlphabeticListPlugin <: Plugin {
    public prop name: String {
        get() {
            return "AlphabeticListPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(AlphabeticListParser())
        registrar.registerHtmlRenderer("AlphabeticList", AlphabeticListHtmlRenderer())
        registrar.registerHtmlRenderer("AlphabeticListItem", AlphabeticListItemHtmlRenderer())
        registrar.registerMarkdownRenderer("AlphabeticList", AlphabeticListMarkdownRenderer())
        registrar.registerMarkdownRenderer("AlphabeticListItem", AlphabeticListItemMarkdownRenderer())
        registrar.registerTypstRenderer("AlphabeticList", AlphabeticListTypstRenderer())
        registrar.registerTypstRenderer("AlphabeticListItem", AlphabeticListItemTypstRenderer())
    }
}
