package markit.plugins.gfm.inline.inline_math

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class InlineMathNode <: Node {
    public let content: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        raw: String
    ) {
        super("InlineMath", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
    }

    public override prop name: String {
        get() {
            return "InlineMathNode"
        }
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        return w
    }
}
