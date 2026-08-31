package markit.plugins.gfm.inline.footnote

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class FootnoteDefinitionNode <: Node {
    public let footnoteId: String
    public let content: String
    public let footnoteNumber: Int64

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        footnoteId: String,
        content: String,
        footnoteNumber: Int64,
        raw: String
    ) {
        super("FootnoteDefinition", id: id, sourceSpan: sourceSpan, literal: content)
        this.footnoteId = footnoteId
        this.content = content
        this.footnoteNumber = footnoteNumber
        setRawContent(raw)
    }

    public override prop name: String {
        get() {
            return "FootnoteDefinitionNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [footnoteId=${footnoteId}, footnoteNumber=${footnoteNumber}] (${rawContent()})")
        for (child in children) {
            let childStr = child.toString()
            for (line in childStr.split('\n')) {
                sb.append("\n  ")
                sb.append(line)
            }
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("footnoteId").value(footnoteId)
        w.name("content").value(content)
        w.name("footnoteNumber").value(footnoteNumber)
        return w
    }
}
