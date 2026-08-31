package markit.plugins.gfm.inline.strikethrough

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class StrikethroughNode <: Node {
    public let content: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String
    ) {
        super("Strikethrough", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
    }

    public override prop name: String {
        get() {
            return "StrikethroughNode"
        }
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        return w
    }
}
