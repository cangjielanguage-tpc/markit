package markit.plugins.standard.block.list

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}
import markit.plugins.anchor.AnchorRenderUtils

public class ListHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ListPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        let ordered = node.bool("ordered") ?? false
        let tight = node.bool("i18n_tight_override") ?? (node.bool("tight") ?? true)

        if (ordered) {
            let startNumber = node.int("startNumber") ?? 1
            if (startNumber == 1) {
                out.raw("<ol${registry.htmlClassAttribute(node)}>")
            } else {
                out.raw("<ol start=\"${startNumber}\"${registry.htmlClassAttribute(node)}>")
            }
        } else {
            out.raw("<ul${registry.htmlClassAttribute(node)}>")
        }

        for (child in node.children) {
            out.raw("<li${AnchorRenderUtils.htmlAttributes(child, registry)}>")
            writeItem(child, tight, out, registry)
            out.raw("</li>")
        }

        out.raw(if (ordered) { "</ol>" } else { "</ul>" })
    }

    private func writeItem(
        node: Node,
        tight: Bool,
        out: HtmlWriter,
        registry: RenderRegistry
    ): Unit {
        if (node.children.isEmpty()) {
            out.text(node.literal)
            return
        }

        for (child in node.children) {
            if (tight && child.kind == "Paragraph" && !(child.bool("force_block_paragraph") ?? false)) {
                writeParagraphChildrenInline(child, out, registry)
            } else {
                registry.writeHtml(child, out)
            }
        }
    }

    private func writeParagraphChildrenInline(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (node.children.isEmpty()) {
            out.text(node.literal)
            return
        }

        for (child in node.children) {
            registry.writeHtml(child, out)
        }
    }
}
