package markit.plugins.standard.inline.italic

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}

public class ItalicTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ItalicPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        out.write("_")
        for (child in node.children) {
            registry.writeTypst(child, out)
        }
        out.write("_")
    }
}
