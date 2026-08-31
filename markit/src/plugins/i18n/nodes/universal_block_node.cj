package markit.plugins.i18n.nodes

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class UniversalBlockNode <: Node {
    public let content: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String
    ) {
        super("UniversalBlock", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
    }

    public override prop name: String {
        get() {
            return "UniversalBlockNode"
        }
    }

    public func getContent(): String {
        return content
    }

    public override func toString(): String {
        return "${name}(content: ${children.size} children)"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        return w
    }
}
