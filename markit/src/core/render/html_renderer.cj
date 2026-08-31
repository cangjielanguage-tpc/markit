package markit.core.render

import markit.core.nodes.Node

public interface HtmlRenderer {
    prop ownerPlugin: String
    func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit
}
