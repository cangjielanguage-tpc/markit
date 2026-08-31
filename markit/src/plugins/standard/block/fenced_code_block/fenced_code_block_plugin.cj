package markit.plugins.standard.block.fenced_code_block

import markit.core.plugin.{Plugin, PluginRegistrar}

public class FencedCodeBlockPlugin <: Plugin {
    private let config: FencedCodeBlockConfig

    public init(config!: FencedCodeBlockConfig = FencedCodeBlockConfig()) {
        this.config = config
    }

    public prop name: String {
        get() {
            return "FencedCodeBlockPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0-scaffold"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(FencedCodeBlockParser(config: config))
        registrar.registerHtmlRenderer("FencedCodeBlock", FencedCodeBlockHtmlRenderer(config: config))
        registrar.registerMarkdownRenderer("FencedCodeBlock", FencedCodeBlockMarkdownRenderer(targetLanguage: config.targetLanguage))
        registrar.registerTypstRenderer("FencedCodeBlock", FencedCodeBlockTypstRenderer(targetLanguage: config.targetLanguage))
    }
}
