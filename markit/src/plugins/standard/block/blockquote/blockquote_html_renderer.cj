package markit.plugins.standard.block.blockquote

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}
import markit.plugins.anchor.AnchorRenderUtils

public class BlockquoteHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "BlockquotePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<blockquote${AnchorRenderUtils.htmlAttributes(node, registry)}>")
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        out.raw("</blockquote>")
    }
}
