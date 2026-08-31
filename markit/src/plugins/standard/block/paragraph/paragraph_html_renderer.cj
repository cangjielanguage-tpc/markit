package markit.plugins.standard.block.paragraph

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}
import markit.plugins.anchor.AnchorRenderUtils

public class ParagraphHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<p${AnchorRenderUtils.htmlAttributes(node, registry)}>")
        if (node.children.isEmpty()) {
            out.text(node.literal)
        } else {
            let end = trailingSoftBreakStart(node)
            for (i in 0..end) {
                registry.writeHtml(node.children[i], out)
            }
        }
        out.raw("</p>")
    }

    private func trailingSoftBreakStart(node: Node): Int64 {
        var end = node.children.size
        while (end > 0) {
            if (node.children[end - 1].kind != "SoftBreak") {
                break
            }
            end -= 1
        }
        return end
    }
}
