package markit.plugins.standard.inline.bold

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}

public class BoldMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "BoldPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let delimiter = if (let bold: BoldNode <- node) { bold.delimiter } else { "**" }
        out.write(delimiter)
        for (child in node.children) {
            registry.writeMarkdown(child, out)
        }
        out.write(delimiter)
    }
}
