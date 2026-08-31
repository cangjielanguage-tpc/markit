package markit.plugins.standard.block.divider

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}
import markit.plugins.anchor.AnchorRenderUtils

public class DividerHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "DividerPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        out.raw("<hr${AnchorRenderUtils.htmlAttributes(node, registry)} />")
    }
}
