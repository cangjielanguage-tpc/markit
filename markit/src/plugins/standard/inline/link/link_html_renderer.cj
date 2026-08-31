package markit.plugins.standard.inline.link

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, RenderRegistry}

public class LinkHtmlRenderer <: HtmlRenderer {
    private let resolver: SmartHeadingLinkResolver

    public init(resolver!: SmartHeadingLinkResolver = SmartHeadingLinkResolver(LinkConfig())) {
        this.resolver = resolver
    }

    public prop ownerPlugin: String {
        get() {
            return "LinkPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let link: LinkNode <- node) {
            let (resolvedUrl, error) = resolver.resolve(link.url, LinkRenderUtils.extractText(node))
            out.raw("<a href=\"")
            out.raw(HtmlEscaper.escape(resolvedUrl))
            out.raw("\"")
            if (!link.title.isEmpty()) {
                out.raw(" title=\"")
                out.raw(HtmlEscaper.escape(link.title))
                out.raw("\"")
            }
            out.raw(registry.htmlClassAttribute(node))
            out.raw(">")
            for (child in node.children) {
                registry.writeHtml(child, out)
            }
            if (let Some(message) <- error) {
                out.raw(" <span class=\"link-error\">[❌ ")
                out.raw(HtmlEscaper.escape(message))
                out.raw("]</span>")
            }
            out.raw("</a>")
        }
    }
}
