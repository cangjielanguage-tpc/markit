package markit.plugins.standard.inline.hard_break

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}

public class HardBreakMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HardBreakPlugin"
        }
    }

    public func writeMarkdown(_: Node, out: TextWriter, _: RenderRegistry): Unit {
        out.write("  \n")
    }
}
