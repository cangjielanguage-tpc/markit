package markit.plugins.standard.inline.image

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class ImageNode <: Node {
    public let alt: String
    public var src: String
    public var title: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        alt: String,
        src: String,
        title: String
    ) {
        super("Image", id: id, sourceSpan: sourceSpan, literal: alt)
        this.alt = alt
        this.src = src
        this.title = title
    }

    public override prop name: String {
        get() {
            return "ImageNode"
        }
    }

    public override func toString(): String {
        return "${name} [alt=${alt}, src=${src}, title=${title}] (${rawContent()})"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("alt").value(alt)
        w.name("src").value(src)
        w.name("title").value(title)
        return w
    }
}
