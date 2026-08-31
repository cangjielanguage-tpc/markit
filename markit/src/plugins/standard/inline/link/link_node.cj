package markit.plugins.standard.inline.link

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class LinkNode <: Node {
    public let content: String
    public var url: String
    public var title: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        content: String,
        url: String,
        title: String
    ) {
        super("Link", id: id, sourceSpan: sourceSpan, literal: content)
        this.content = content
        this.url = url
        this.title = title
    }

    public override prop name: String {
        get() {
            return "LinkNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [url=${url}, title=${title}] (${rawContent()})")
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
        w.name("content").value(content)
        w.name("url").value(url)
        w.name("title").value(title)
        return w
    }
}
