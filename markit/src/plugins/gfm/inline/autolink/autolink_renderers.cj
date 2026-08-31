package markit.plugins.gfm.inline.autolink

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TypstEscaper

public class AutolinkHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AutolinkPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let autolink: AutolinkNode <- node) {
            out.raw("<a href=\"")
            out.raw(HtmlEscaper.escape(autolink.url))
            out.raw("\"")
            out.raw(registry.htmlClassAttribute(node))
            out.raw(">")
            out.text(autolink.displayText)
            out.raw("</a>")
        }
    }
}

public class AutolinkMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AutolinkPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let autolink: AutolinkNode <- node) {
            out.write(autolink.rawContent())
        }
    }
}

public class AutolinkTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AutolinkPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let autolink: AutolinkNode <- node) {
            out.write("#link(\"${TypstEscaper.escapeString(autolink.url)}\")[${TypstEscaper.escapeText(autolink.displayText)}]")
        }
    }
}
