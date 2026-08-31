package markit.core.nodes

import seajson.JsonWriter
import markit.core.source.SourceSpan

public class TextNode <: Node {
    public let content: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String
    ) {
        super("Text", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
    }

    public override prop name: String {
        get() {
            return "TextNode"
        }
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        return w
    }
}
