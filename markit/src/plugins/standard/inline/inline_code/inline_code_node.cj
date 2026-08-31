package markit.plugins.standard.inline.inline_code

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class InlineCodeNode <: Node {
    public let content: String
    public let fenceLength: Int64

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        fenceLength: Int64
    ) {
        super("InlineCode", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.fenceLength = fenceLength
    }

    public override prop name: String {
        get() {
            return "InlineCodeNode"
        }
    }

    public override func toString(): String {
        return "${name} (${rawContent()})"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("fenceLength").value(fenceLength)
        return w
    }
}
