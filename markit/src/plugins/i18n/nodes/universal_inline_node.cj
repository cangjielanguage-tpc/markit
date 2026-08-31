package markit.plugins.i18n.nodes

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class UniversalInlineNode <: Node {
    public let content: String
    public let originalSyntax: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        originalSyntax: String
    ) {
        super("UniversalInline", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.originalSyntax = originalSyntax
    }

    public override prop name: String {
        get() {
            return "UniversalInlineNode"
        }
    }

    public func getContent(): String {
        return content
    }

    public func getOriginalSyntax(): String {
        return originalSyntax
    }

    public override func toString(): String {
        return "${name}(content: ${content}, children: ${children.size})"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("originalSyntax").value(originalSyntax)
        return w
    }
}
