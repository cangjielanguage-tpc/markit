package markit.plugins.standard.inline.inline_code

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}

public class InlineCodeHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "InlineCodePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let code: InlineCodeNode <- node) {
            out.raw("<code${registry.htmlClassAttribute(node)}>")
            out.text(code.content)
            out.raw("</code>")
        }
    }
}
