package markit.plugins.standard.inline.soft_break

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}

public class SoftBreakHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public func writeHtml(_: Node, out: HtmlWriter, _: RenderRegistry): Unit {
        out.raw("\n")
    }
}
