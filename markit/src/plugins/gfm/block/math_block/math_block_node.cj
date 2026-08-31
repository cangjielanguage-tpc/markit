package markit.plugins.gfm.block.math_block

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class MathBlockNode <: Node {
    public let content: String
    public let indentLevel: Int64

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        indentLevel: Int64
    ) {
        super("MathBlock", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.indentLevel = indentLevel
        setInt("indentLevel", indentLevel)
    }

    public override prop name: String {
        get() {
            return "MathBlockNode"
        }
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("indentLevel").value(indentLevel)
        return w
    }
}
