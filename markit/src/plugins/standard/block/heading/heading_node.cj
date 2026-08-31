package markit.plugins.standard.block.heading

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class HeadingNode <: Node {
    public let content: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        level: Int64,
        slug!: String = ""
    ) {
        super("Heading", id: id, sourceSpan: sourceSpan, literal: content, level: level, slug: slug)
        this.content = content
    }

    public override prop name: String {
        get() {
            return "Heading${level}Node"
        }
    }

    public override func toString(): String {
        let number = string("number") ?? ""
        let numberPrefix = if (number.isEmpty()) {
            ""
        } else {
            "${number} "
        }
        let sb = StringBuilder()
        sb.append("${numberPrefix}${name} [level=${level}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("content").value(content)
        w.name("level").value(level)
        let number = string("number") ?? ""
        if (!number.isEmpty()) {
            w.name("number").value(number)
        }
        let baseSlug = string("baseSlug") ?? ""
        if (!baseSlug.isEmpty()) {
            w.name("baseSlug").value(baseSlug)
        }
        if (let Some(occurrence) <- int("slugOccurrence")) {
            if (occurrence > 0) {
                w.name("slugOccurrence").value(occurrence)
            }
        }
        let typstLabel = string("typstLabel") ?? ""
        if (!typstLabel.isEmpty() && typstLabel != slug) {
            w.name("typstLabel").value(typstLabel)
        }
        return w
    }
}
