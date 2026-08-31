package markit.plugins.standard.block.divider

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}
import markit.plugins.anchor.AnchorRenderUtils

public class DividerMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "DividerPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        out.write("---" + AnchorRenderUtils.markdownLabel(node) + "\n\n")
    }
}
