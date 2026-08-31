package markit.plugins.gfm.block.table

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class TableRowNode <: Node {
    public let isHeader: Bool

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        isHeader: Bool
    ) {
        super("TableRow", id: id, sourceSpan: sourceSpan)
        this.isHeader = isHeader
        setBool("isHeader", isHeader)
    }

    public override prop name: String {
        get() {
            return "TableRowNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [isHeader=${isHeader}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("isHeader").value(isHeader)
        return w
    }
}
