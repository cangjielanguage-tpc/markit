package markit.plugins.standard.inline.image

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, RenderRegistry}

public class ImageHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ImagePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let image: ImageNode <- node) {
            out.raw("<img src=\"")
            out.raw(HtmlEscaper.escape(image.src))
            out.raw("\" alt=\"")
            out.raw(HtmlEscaper.escape(image.alt))
            out.raw("\"")
            if (!image.title.isEmpty()) {
                out.raw(" title=\"")
                out.raw(HtmlEscaper.escape(image.title))
                out.raw("\"")
            }
            out.raw(registry.htmlClassAttribute(node))
            out.raw(" />")
        }
    }
}
