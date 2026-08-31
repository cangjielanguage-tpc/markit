package markit.plugins.standard.inline.italic

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}

public class ItalicMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ItalicPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let delimiter = if (let italic: ItalicNode <- node) { italic.delimiter } else { "*" }
        out.write(delimiter)
        for (child in node.children) {
            registry.writeMarkdown(child, out)
        }
        out.write(delimiter)
    }
}
