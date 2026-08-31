package markit.plugins.standard.inline.bold

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}

public class BoldTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "BoldPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        out.write("*")
        for (child in node.children) {
            registry.writeTypst(child, out)
        }
        out.write("*")
    }
}
