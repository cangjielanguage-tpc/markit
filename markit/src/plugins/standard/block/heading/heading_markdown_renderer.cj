package markit.plugins.standard.block.heading

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}
import markit.utils.TextRenderUtils

public class HeadingMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HeadingPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let level = if (node.level < 1 || node.level > 6) {
            1
        } else {
            node.level
        }
        let number = node.string("number") ?? ""
        let numberPrefix = if (number.isEmpty()) { "" } else { number + " " }
        out.write(TextRenderUtils.repeat("#", level) + " " + numberPrefix)
        if (node.children.isEmpty()) {
            out.write(node.literal)
        } else {
            for (child in node.children) {
                registry.writeMarkdown(child, out)
            }
        }
        out.write("\n\n")
    }
}
