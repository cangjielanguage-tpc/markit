package markit.plugins.standard.inline.italic

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}

public class ItalicHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ItalicPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<em${registry.htmlClassAttribute(node)}>")
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        out.raw("</em>")
    }
}
