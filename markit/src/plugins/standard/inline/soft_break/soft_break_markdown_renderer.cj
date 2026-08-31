package markit.plugins.standard.inline.soft_break

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}

public class SoftBreakMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public func writeMarkdown(_: Node, out: TextWriter, _: RenderRegistry): Unit {
        out.write("\n")
    }
}
