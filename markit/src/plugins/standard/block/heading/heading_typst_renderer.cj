package markit.plugins.standard.block.heading

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TextRenderUtils
import markit.utils.TypstEscaper

public class HeadingTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HeadingPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let level = if (node.level < 1 || node.level > 6) {
            1
        } else {
            node.level
        }
        let label = node.string("typstLabel") ?? node.slug
        let labelSuffix = if (label.isEmpty()) {
            ""
        } else {
            " <" + label + ">"
        }
        out.write(TextRenderUtils.repeat("=", level) + " ")
        if (node.children.isEmpty()) {
            out.write(TypstEscaper.escapeText(node.literal))
        } else {
            for (child in node.children) {
                registry.writeTypst(child, out)
            }
        }
        out.write(labelSuffix + "\n\n")
    }
}
