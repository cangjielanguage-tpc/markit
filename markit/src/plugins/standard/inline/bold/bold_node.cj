package markit.plugins.standard.inline.bold

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class BoldNode <: Node {
    public let content: String
    public let delimiter: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        delimiter: String
    ) {
        super("Bold", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.delimiter = delimiter
    }

    public override prop name: String {
        get() {
            return "BoldNode"
        }
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("delimiter").value(delimiter)
        return w
    }
}
