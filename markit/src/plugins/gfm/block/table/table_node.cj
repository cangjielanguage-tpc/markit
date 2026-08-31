package markit.plugins.gfm.block.table

import std.collection.ArrayList
import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class TableNode <: Node {
    public let alignments: ArrayList<TableAlignment>
    public let columnCount: Int64

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        alignments: ArrayList<TableAlignment>,
        columnCount: Int64
    ) {
        super("Table", id: id, sourceSpan: sourceSpan)
        this.alignments = alignments
        this.columnCount = columnCount
        setInt("columnCount", columnCount)
    }

    public override prop name: String {
        get() {
            return "TableNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [columnCount=${columnCount}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("columnCount").value(columnCount)
        w.name("alignments").beginArray()
        for (alignment in alignments) {
            w.value(alignment.toString())
        }
        w.endArray()
        return w
    }
}
