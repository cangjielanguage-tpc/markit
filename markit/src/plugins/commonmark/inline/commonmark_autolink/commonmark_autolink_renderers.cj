package markit.plugins.commonmark.inline.commonmark_autolink

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TypstEscaper

public class CommonMarkAutolinkHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "CommonMarkAutolinkPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let autolink: CommonMarkAutolinkNode <- node) {
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

public class CommonMarkAutolinkMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "CommonMarkAutolinkPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let autolink: CommonMarkAutolinkNode <- node) {
            out.write(autolink.rawContent())
        }
    }
}

public class CommonMarkAutolinkTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "CommonMarkAutolinkPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let autolink: CommonMarkAutolinkNode <- node) {
            out.write("#link(\"${TypstEscaper.escapeString(autolink.url)}\")[${TypstEscaper.escapeText(autolink.displayText)}]")
        }
    }
}
