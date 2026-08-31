package markit.plugins.gfm.block.task_list

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class TaskListItemNode <: Node {
    public let content: String
    public let indentLevel: Int64
    public let checked: Bool
    public let marker: Byte

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        indentLevel: Int64,
        checked: Bool,
        marker: Byte
    ) {
        super("TaskListItem", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.indentLevel = indentLevel
        this.checked = checked
        this.marker = marker
        setBool("checked", checked)
        setInt("indentLevel", indentLevel)
        setString("marker", String.fromUtf8([marker]))
    }

    public override prop name: String {
        get() {
            return "TaskListItemNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [checked=${checked}, marker=${String.fromUtf8([marker])}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("indentLevel").value(indentLevel)
        w.name("checked").value(checked)
        w.name("marker").value(String.fromUtf8([marker]))
        return w
    }
}
