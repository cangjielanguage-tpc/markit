package markit.plugins.gfm.block.table

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class TableCellNode <: Node {
    public let content: String
    public let alignment: TableAlignment
    public let isHeader: Bool

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        alignment: TableAlignment,
        isHeader: Bool
    ) {
        super("TableCell", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.alignment = alignment
        this.isHeader = isHeader
        setString("alignment", alignment.toString())
        setBool("isHeader", isHeader)
    }

    public override prop name: String {
        get() {
            return "TableCellNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [isHeader=${isHeader}, alignment=${alignment}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("alignment").value(alignment.toString())
        w.name("isHeader").value(isHeader)
        return w
    }
}
