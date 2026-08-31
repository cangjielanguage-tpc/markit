package markit.plugins.standard.block.blockquote

import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class BlockquoteNode <: Node {
    public init(
        id: Int64,
        sourceSpan: SourceSpan
    ) {
        super("Blockquote", id: id, sourceSpan: sourceSpan)
    }

    public override prop name: String {
        get() {
            return "BlockquoteNode"
        }
    }

    public override func toString(): String {
        let treeRawContent = rawContent()
        let sb = StringBuilder()
        sb.append("${name} (")
        sb.append(treeRawContent)
        if (!treeRawContent.isEmpty() && !treeRawContent.endsWith("\n")) {
            sb.append("\n")
        }
        sb.append(")")
        for (child in children) {
            let childStr = child.toString()
            for (line in childStr.split('\n')) {
                sb.append("\n  ")
                sb.append(line)
            }
        }
        return sb.toString()
    }
}
