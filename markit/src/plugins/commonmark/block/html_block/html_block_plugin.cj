package markit.plugins.commonmark.block.html_block

import markit.core.plugin.{Plugin, PluginRegistrar}

public class HTMLBlockPlugin <: Plugin {
    public HTMLBlockPlugin(private let config!: HtmlBlockConfig = HtmlBlockConfig()) {}

    public prop name: String {
        get() {
            return "HTMLBlockPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(HTMLBlockParser(config: config))
        registrar.registerHtmlRenderer("HTMLBlock", HTMLBlockHtmlRenderer())
        registrar.registerMarkdownRenderer("HTMLBlock", HTMLBlockMarkdownRenderer())
        registrar.registerTypstRenderer("HTMLBlock", HTMLBlockTypstRenderer())
    }
}
