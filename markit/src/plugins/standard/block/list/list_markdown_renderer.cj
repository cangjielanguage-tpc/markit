package markit.plugins.standard.block.list

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TextRenderUtils

public class ListMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ListPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let ordered = node.bool("ordered") ?? false
        let delimiter = node.string("delimiter") ?? "."
        let parts = ArrayList<String>()

        for (child in node.children) {
            let itemBody = renderItemBody(child, registry)
            if (itemBody.isEmpty()) {
                continue
            }

            let marker = if (ordered) {
                (child.int("number") ?? 1).toString() + delimiter + " "
            } else {
                (child.string("marker") ?? "-") + " "
            }

            let labeledBody = itemBody + AnchorRenderUtils.markdownLabel(child)
            parts.add(
                marker + TextRenderUtils.indentContinuationLines(
                    labeledBody,
                    TextRenderUtils.indentSpaces(marker.size)
                )
            )
        }

        if (parts.isEmpty()) {
            return
        }
        out.write(String.join(parts.toArray(), delimiter: "\n") + "\n\n")
    }

    private func renderItemBody(node: Node, registry: RenderRegistry): String {
        if (node.children.isEmpty()) {
            return node.literal
        }

        let segments = ArrayList<String>()
        for (child in node.children) {
            let rendered = TextRenderUtils.trimRight(registry.renderMarkdown(child))
            if (!rendered.isEmpty()) {
                segments.add(rendered)
            }
        }

        return String.join(segments.toArray(), delimiter: "\n\n")
    }
}
