package markit.plugins.standard.inline.link

import markit.core.plugin.{Plugin, PluginRegistrar}

public class LinkPlugin <: Plugin {
    public let resolver: SmartHeadingLinkResolver

    public init(config!: LinkConfig = LinkConfig()) {
        this.resolver = SmartHeadingLinkResolver(config)
    }

    public func updateConfig(config: LinkConfig): Unit {
        resolver.updateConfig(config)
    }

    public prop name: String {
        get() {
            return "LinkPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(LinkParser())
        registrar.registerHtmlRenderer("Link", LinkHtmlRenderer(resolver: resolver))
        registrar.registerMarkdownRenderer("Link", LinkMarkdownRenderer(resolver: resolver))
        registrar.registerTypstRenderer("Link", LinkTypstRenderer(resolver: resolver))
    }
}
