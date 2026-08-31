package markit.plugins.standard.inline.image

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TypstEscaper

public class ImageTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ImagePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let image: ImageNode <- node) {
            if (image.alt.isEmpty()) {
                out.write("#image(\"${TypstEscaper.escapeString(image.src)}\")")
            } else {
                out.write("#image(\"${TypstEscaper.escapeString(image.src)}\", alt: \"${TypstEscaper.escapeString(image.alt)}\")")
            }
        }
    }
}
