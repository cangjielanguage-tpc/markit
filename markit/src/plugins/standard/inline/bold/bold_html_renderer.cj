package markit.plugins.standard.inline.bold

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}

public class BoldHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "BoldPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<strong${registry.htmlClassAttribute(node)}>")
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        out.raw("</strong>")
    }
}
