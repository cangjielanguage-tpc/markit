package markit.plugins.standard.block.blockquote

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TextRenderUtils

public class BlockquoteMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "BlockquotePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let parts = ArrayList<String>()
        for (child in node.children) {
            let rendered = TextRenderUtils.trimRight(registry.renderMarkdown(child))
            if (!rendered.isEmpty()) {
                parts.add(rendered)
            }
        }

        if (parts.isEmpty()) {
            return
        }
        let rendered = String.join(parts.toArray(), delimiter: "\n\n")
        out.write(TextRenderUtils.prefixLines(rendered, "> ") + AnchorRenderUtils.markdownLabel(node) + "\n\n")
    }
}
