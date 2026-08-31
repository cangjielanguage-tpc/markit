package markit.plugins.standard.block.blockquote

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TextRenderUtils

public class BlockquoteTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "BlockquotePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let parts = ArrayList<String>()
        for (child in node.children) {
            let rendered = TextRenderUtils.trimRight(registry.renderTypst(child))
            if (!rendered.isEmpty()) {
                parts.add(rendered)
            }
        }

        if (parts.isEmpty()) {
            return
        }

        out.write("#quote(block: true)[\n" + String.join(parts.toArray(), delimiter: "\n\n") + "\n]" + AnchorRenderUtils.typstLabel(node) + "\n\n")
    }
}
