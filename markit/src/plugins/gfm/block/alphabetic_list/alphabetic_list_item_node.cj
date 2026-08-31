package markit.plugins.gfm.block.alphabetic_list

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class AlphabeticListItemNode <: Node {
    public let content: String
    public let indentLevel: Int64
    public let letter: Byte
    public let delimiter: Byte

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        indentLevel: Int64,
        letter: Byte,
        delimiter: Byte
    ) {
        super("AlphabeticListItem", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.indentLevel = indentLevel
        this.letter = letter
        this.delimiter = delimiter
        setInt("indentLevel", indentLevel)
        setString("letter", String.fromUtf8([letter]))
        setString("delimiter", String.fromUtf8([delimiter]))
    }

    public override prop name: String {
        get() {
            return "AlphabeticListItemNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [letter=${String.fromUtf8([letter])}, delimiter=${String.fromUtf8([delimiter])}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("indentLevel").value(indentLevel)
        w.name("letter").value(String.fromUtf8([letter]))
        w.name("delimiter").value(String.fromUtf8([delimiter]))
        return w
    }
}
