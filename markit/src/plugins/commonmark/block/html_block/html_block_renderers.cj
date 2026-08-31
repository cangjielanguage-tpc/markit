package markit.plugins.commonmark.block.html_block

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, MarkdownRenderer, RenderRegistry, TextWriter, HtmlRenderer, HtmlWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils
import markit.plugins.commonmark.HtmlAttributeUtils
import markit.utils.TypstRenderUtils

public class HTMLBlockHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HTMLBlockPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let html: HTMLBlockNode <- node) {
            if (html.children.isEmpty() || html.isContentProtected || !html.isSafeBlockTagType() || html.isSelfClosing) {
                out.raw(html.rawContent())
                return
            }
            out.raw("<${html.tagName}${htmlAttributes(html, node, registry)}>")
            for (child in html.children) {
                registry.writeHtml(child, out)
            }
            out.raw("</${html.tagName}>")
        }
    }

    private func htmlAttributes(html: HTMLBlockNode, node: Node, registry: RenderRegistry): String {
        if (node.string("anchor.id").isNone()) {
            return HtmlAttributeUtils.build(html.attributes, includeLeadingSpace: true)
        }

        let sb = StringBuilder()
        for ((key, value) in html.attributes) {
            if (key == "id" || key == "class") {
                continue
            }
            appendAttribute(sb, key, value)
        }

        let baseClass = html.attributes.get("class") ?? ""
        sb.append(AnchorRenderUtils.htmlClassAttribute(baseClass, node, registry))
        return sb.toString()
    }

    private func appendAttribute(sb: StringBuilder, key: String, value: String): Unit {
        sb.append(" ")
        sb.append(HtmlEscaper.escape(key))
        if (!value.isEmpty()) {
            sb.append("=\"")
            sb.append(HtmlEscaper.escape(value))
            sb.append("\"")
        }
    }
}

public class HTMLBlockMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HTMLBlockPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let html: HTMLBlockNode <- node) {
            let raw = html.rawContent()
            out.write(raw)
            if (!raw.endsWith("\n")) {
                out.write("\n")
            }
            out.write("\n")
        }
    }
}

public class HTMLBlockTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HTMLBlockPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let html: HTMLBlockNode <- node) {
            let raw = html.rawContent()
            out.write(TypstRenderUtils.renderRawBlock(raw))
        }
    }
}
