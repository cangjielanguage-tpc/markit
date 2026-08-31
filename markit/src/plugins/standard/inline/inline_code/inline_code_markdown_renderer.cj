package markit.plugins.standard.inline.inline_code

import markit.core.nodes.Node
import markit.core.inline.InlineUtils
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}

public class InlineCodeMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "InlineCodePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let code: InlineCodeNode <- node) {
            let fence = InlineUtils.repeat("`", code.fenceLength)
            out.write(fence + code.content + fence)
        }
    }
}
