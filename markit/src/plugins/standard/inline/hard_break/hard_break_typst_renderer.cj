package markit.plugins.standard.inline.hard_break

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}

public class HardBreakTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HardBreakPlugin"
        }
    }

    public func writeTypst(_: Node, out: TextWriter, _: RenderRegistry): Unit {
        out.write("#linebreak()")
    }
}
