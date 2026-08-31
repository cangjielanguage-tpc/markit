package markit.plugins.standard.block.paragraph

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class ParagraphNode <: Node {
    public let content: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String
    ) {
        super("Paragraph", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
    }

    public override prop name: String {
        get() {
            return "ParagraphNode"
        }
    }

    public override func toString(): String {
        let treeRawContent = rawContent()
        let sb = StringBuilder()
        sb.append("${name} (")
        sb.append(treeRawContent)
        if (ParagraphChildrenBuilder.hasTerminalSoftBreak(this) && !treeRawContent.endsWith("\n")) {
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

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        return w
    }
}
