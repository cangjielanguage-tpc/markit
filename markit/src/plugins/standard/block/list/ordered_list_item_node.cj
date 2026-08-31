package markit.plugins.standard.block.list

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class OrderedListItemNode <: Node {
    public let content: String
    public let indentLevel: Int64
    public let number: Int64
    public let delimiter: Byte

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        indentLevel: Int64,
        number: Int64,
        delimiter: Byte
    ) {
        super("ListItem", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.indentLevel = indentLevel
        this.number = number
        this.delimiter = delimiter
        setInt("number", number)
        setString("delimiter", String.fromUtf8([delimiter]))
    }

    public override prop name: String {
        get() {
            return "OrderedListItemNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [number=${number}, delimiter=${String.fromUtf8([delimiter])}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("indentLevel").value(indentLevel)
        w.name("number").value(number)
        w.name("delimiter").value(String.fromUtf8([delimiter]))
        return w
    }
}
