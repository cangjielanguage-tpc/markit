package markit.plugins.commonmark.inline.commonmark_autolink

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public enum AutolinkType {
    |Url
    |Email
}

public class CommonMarkAutolinkNode <: Node {
    public let autolinkType: AutolinkType
    public let url: String
    public let displayText: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        autolinkType: AutolinkType,
        url: String,
        displayText: String,
        raw: String
    ) {
        super("CommonMarkAutolink", id: id, sourceSpan: sourceSpan, literal: displayText)
        this.autolinkType = autolinkType
        this.url = url
        this.displayText = displayText
        setRawContent(raw)
    }

    public override prop name: String {
        get() {
            return "CommonMarkAutolink"
        }
    }

    public override func toString(): String {
        return "${name} [autolinkType=${autolinkTypeName()}, url=${url}] (${rawContent()})"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("autolinkType").value(autolinkTypeName())
        w.name("url").value(url)
        w.name("displayText").value(displayText)
        return w
    }

    public func autolinkTypeName(): String {
        match (autolinkType) {
            case Url => return "Url"
            case Email => return "Email"
        }
    }
}
