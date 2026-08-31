package markit.plugins.standard.inline.hard_break

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}

public class HardBreakHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HardBreakPlugin"
        }
    }

    public func writeHtml(_: Node, out: HtmlWriter, _: RenderRegistry): Unit {
        out.raw("<br />")
    }
}
