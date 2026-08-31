package markit.plugins.standard.block.divider

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils

public class DividerTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "DividerPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        out.write("#block(above: 0.9em, below: 0.9em)[#line(length: 100%, stroke: 0.7pt + luma(205))]" + AnchorRenderUtils.typstLabel(node) + "\n\n")
    }
}
