package markit.plugins.gfm.inline.footnote

import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.SessionStateKey

public class FootnotePlugin <: Plugin {
    public static let stateKey = SessionStateKey<FootnoteRegistry>("FootnotePlugin", "registry")

    public prop name: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerState(FootnotePlugin.stateKey, { => FootnoteRegistry() })
        registrar.registerContinuationBlockParser(FootnoteDefinitionParser())
        registrar.registerInlineParser(FootnoteReferenceParser())
        registrar.registerNodeEmissionFilter(FootnoteDefinitionEmissionFilter())
        registrar.registerHtmlRenderer("FootnoteDefinition", FootnoteDefinitionHtmlRenderer())
        registrar.registerMarkdownRenderer("FootnoteDefinition", FootnoteDefinitionMarkdownRenderer())
        registrar.registerTypstRenderer("FootnoteDefinition", FootnoteDefinitionTypstRenderer())
        registrar.registerHtmlRenderer("FootnoteReference", FootnoteReferenceHtmlRenderer())
        registrar.registerMarkdownRenderer("FootnoteReference", FootnoteReferenceMarkdownRenderer())
        registrar.registerTypstRenderer("FootnoteReference", FootnoteReferenceTypstRenderer())
    }
}
