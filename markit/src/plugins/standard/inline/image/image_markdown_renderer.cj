package markit.plugins.standard.inline.image

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}

public class ImageMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ImagePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let image: ImageNode <- node) {
            if (image.title.isEmpty()) {
                out.write("![${image.alt}](${image.src})")
            } else {
                out.write("![${image.alt}](${image.src} \"${image.title}\")")
            }
        }
    }
}
