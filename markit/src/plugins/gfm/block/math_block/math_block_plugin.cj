package markit.plugins.gfm.block.math_block

import markit.core.plugin.{Plugin, PluginRegistrar}

public class MathBlockPlugin <: Plugin {
    public MathBlockPlugin(private let config!: MathBlockConfig = MathBlockConfig()) {}

    public prop name: String {
        get() {
            return "MathBlockPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(MathBlockParser())
        registrar.registerHtmlRenderer("MathBlock", MathBlockHtmlRenderer(config: config))
        registrar.registerMarkdownRenderer("MathBlock", MathBlockMarkdownRenderer())
        registrar.registerTypstRenderer("MathBlock", MathBlockTypstRenderer(config: config))
    }
}
