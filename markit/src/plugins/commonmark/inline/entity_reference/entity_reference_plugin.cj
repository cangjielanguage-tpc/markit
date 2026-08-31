package markit.plugins.commonmark.inline.entity_reference

import markit.core.plugin.{Plugin, PluginRegistrar}

public class EntityReferencePlugin <: Plugin {
    public prop name: String {
        get() {
            return "EntityReferencePlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(EntityReferenceParser())
        registrar.registerHtmlRenderer("EntityReference", EntityReferenceHtmlRenderer())
        registrar.registerMarkdownRenderer("EntityReference", EntityReferenceMarkdownRenderer())
        registrar.registerTypstRenderer("EntityReference", EntityReferenceTypstRenderer())
    }
}
