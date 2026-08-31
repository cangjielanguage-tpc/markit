package markit.plugins.standard.block.list

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TextRenderUtils

public class ListTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ListPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let ordered = node.bool("ordered") ?? false
        let marker = if (ordered) { "+ " } else { "- " }
        let rows = ArrayList<String>()

        for (child in node.children) {
            let itemBody = renderItemBody(child, registry)
            if (!itemBody.isEmpty()) {
                rows.add(marker + TextRenderUtils.indentContinuationLines(itemBody + AnchorRenderUtils.typstLabel(child), "  "))
            }
        }

        if (rows.isEmpty()) {
            return
        }

        out.write(String.join(rows.toArray(), delimiter: "\n") + "\n\n")
    }

    private func renderItemBody(node: Node, registry: RenderRegistry): String {
        if (node.children.isEmpty()) {
            return node.literal
        }

        let segments = ArrayList<String>()
        for (child in node.children) {
            let rendered = TextRenderUtils.trimRight(registry.renderTypst(child))
            if (!rendered.isEmpty()) {
                segments.add(rendered)
            }
        }
        return String.join(segments.toArray(), delimiter: "\n\n")
    }
}
