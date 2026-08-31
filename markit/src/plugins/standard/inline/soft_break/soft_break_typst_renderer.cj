package markit.plugins.standard.inline.soft_break

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}

public class SoftBreakTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public func writeTypst(_: Node, out: TextWriter, _: RenderRegistry): Unit {
        out.write(" ")
    }
}
