package markit.plugins.gfm.inline.footnote

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class FootnoteReferenceNode <: Node {
    public let footnoteId: String
    public let footnoteNumber: Int64

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        footnoteId: String,
        footnoteNumber: Int64,
        raw: String
    ) {
        super("FootnoteReference", id: id, sourceSpan: sourceSpan, literal: raw)
        this.footnoteId = footnoteId
        this.footnoteNumber = footnoteNumber
        setRawContent(raw)
    }

    public override prop name: String {
        get() {
            return "FootnoteReferenceNode"
        }
    }

    public override func toString(): String {
        return "${name} [footnoteId=${footnoteId}, footnoteNumber=${footnoteNumber}] (${rawContent()})"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("footnoteId").value(footnoteId)
        w.name("footnoteNumber").value(footnoteNumber)
        return w
    }
}
