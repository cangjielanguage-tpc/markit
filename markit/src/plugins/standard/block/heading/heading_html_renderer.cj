package markit.plugins.standard.block.heading

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, RenderRegistry}

public class HeadingHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HeadingPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        let level = if (node.level < 1 || node.level > 6) {
            1
        } else {
            node.level
        }
        let number = node.string("number") ?? ""
        let idAttr = if (node.slug.isEmpty()) {
            ""
        } else {
            " id=\"${node.slug}\""
        }
        let numberAttr = if (!number.isEmpty()) {
            " data-number=\"${HtmlEscaper.escape(number)}\""
        } else {
            ""
        }
        out.raw("<h${level}${idAttr}${numberAttr}${sourceAttributes(node)}${registry.htmlClassAttribute(node)}>")
        if (!number.isEmpty()) {
            out.text(number + " ")
        }
        if (node.children.isEmpty()) {
            out.text(node.literal)
        } else {
            for (child in node.children) {
                registry.writeHtml(child, out)
            }
        }
        out.raw("</h${level}>")
    }

    private func sourceAttributes(node: Node): String {
        if (let Some(startByte) <- node.int("anchor.sourceStartByte")) {
            if (let Some(endByte) <- node.int("anchor.sourceEndByte")) {
                if (endByte > startByte) {
                    return " data-source-start-byte=\"${startByte}\" data-source-end-byte=\"${endByte}\""
                }
            }
        }
        return ""
    }
}
