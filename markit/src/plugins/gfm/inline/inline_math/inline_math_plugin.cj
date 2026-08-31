package markit.plugins.gfm.inline.inline_math

import markit.core.plugin.{Plugin, PluginRegistrar}

public class InlineMathPlugin <: Plugin {
    private let config: InlineMathConfig

    public init(config!: InlineMathConfig = InlineMathConfig()) {
        this.config = config
    }

    public prop name: String {
        get() {
            return "InlineMathPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(InlineMathParser())
        registrar.registerHtmlRenderer("InlineMath", InlineMathHtmlRenderer(config: config))
        registrar.registerMarkdownRenderer("InlineMath", InlineMathMarkdownRenderer())
        registrar.registerTypstRenderer("InlineMath", InlineMathTypstRenderer(config: config))
    }
}
