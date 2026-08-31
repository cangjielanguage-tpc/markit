package markit.plugins.commonmark.inline.commonmark_autolink

import markit.core.plugin.{Plugin, PluginRegistrar}

public class CommonMarkAutolinkPlugin <: Plugin {
    public prop name: String {
        get() {
            return "CommonMarkAutolinkPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(CommonMarkAutolinkParser())
        registrar.registerHtmlRenderer("CommonMarkAutolink", CommonMarkAutolinkHtmlRenderer())
        registrar.registerMarkdownRenderer("CommonMarkAutolink", CommonMarkAutolinkMarkdownRenderer())
        registrar.registerTypstRenderer("CommonMarkAutolink", CommonMarkAutolinkTypstRenderer())
    }
}
