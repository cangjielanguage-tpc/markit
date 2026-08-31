package markit.plugins.standard.block.paragraph

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TextRenderUtils

public class ParagraphTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (node.children.isEmpty()) {
            out.write(node.literal)
        } else {
            let sb = StringBuilder()
            for (child in node.children) {
                sb.append(registry.renderTypst(child))
            }
            out.write(TextRenderUtils.trimRight(sb.toString()))
        }
        out.write(AnchorRenderUtils.typstLabel(node) + "\n\n")
    }
}
