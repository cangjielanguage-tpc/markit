package markit.plugins.standard.block.list

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class UnorderedListItemNode <: Node {
    public let content: String
    public let indentLevel: Int64
    public let marker: Byte

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        indentLevel: Int64,
        marker: Byte
    ) {
        super("ListItem", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.indentLevel = indentLevel
        this.marker = marker
        setString("marker", String.fromUtf8([marker]))
    }

    public override prop name: String {
        get() {
            return "UnorderedListItemNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [marker=${String.fromUtf8([marker])}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("indentLevel").value(indentLevel)
        w.name("marker").value(String.fromUtf8([marker]))
        return w
    }
}
