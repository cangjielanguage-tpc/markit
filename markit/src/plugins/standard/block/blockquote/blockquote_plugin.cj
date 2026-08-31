package markit.plugins.standard.block.blockquote

import markit.core.plugin.{Plugin, PluginRegistrar}

public class BlockquotePlugin <: Plugin {
    public prop name: String {
        get() {
            return "BlockquotePlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0-scaffold"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(BlockquoteParser())
        registrar.registerHtmlRenderer("Blockquote", BlockquoteHtmlRenderer())
        registrar.registerMarkdownRenderer("Blockquote", BlockquoteMarkdownRenderer())
        registrar.registerTypstRenderer("Blockquote", BlockquoteTypstRenderer())
    }
}
