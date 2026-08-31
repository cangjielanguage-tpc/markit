package markit.plugins.standard.block.paragraph

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TextRenderUtils

public class ParagraphMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let content = StringBuilder()
        if (node.children.isEmpty()) {
            content.append(node.literal)
        } else {
            for (child in node.children) {
                content.append(registry.renderMarkdown(child))
            }
        }
        out.write(TextRenderUtils.trimRight(content.toString()) + AnchorRenderUtils.markdownLabel(node) + "\n\n")
    }
}
