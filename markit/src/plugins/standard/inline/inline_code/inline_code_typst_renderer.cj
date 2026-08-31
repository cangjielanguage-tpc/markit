package markit.plugins.standard.inline.inline_code

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TypstRenderUtils

public class InlineCodeTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "InlineCodePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let code: InlineCodeNode <- node) {
            out.write(TypstRenderUtils.renderInlineCode(code.content))
        }
    }
}
