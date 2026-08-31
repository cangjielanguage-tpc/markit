package markit.plugins.commonmark.inline.html_inline

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TypstRenderUtils

public class HTMLInlineHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HTMLInlinePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let html: HTMLInlineNode <- node) {
            if (html.isInvalid()) {
                out.raw(HtmlEscaper.escape(html.rawContent()))
                return
            }
            if (html.isContainer()) {
                let childrenHtml = StringBuilder()
                for (child in html.children) {
                    childrenHtml.append(registry.renderHtml(child))
                }
                out.raw(html.htmlContent(childrenHtml.toString()))
            } else {
                out.raw(html.htmlContent(""))
            }
        }
    }
}

public class HTMLInlineMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HTMLInlinePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let html: HTMLInlineNode <- node) {
            out.write(html.rawContent())
        }
    }
}

public class HTMLInlineTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "HTMLInlinePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (let html: HTMLInlineNode <- node) {
            let childrenTypst = StringBuilder()
            if (html.isContainer()) {
                for (child in html.children) {
                    childrenTypst.append(registry.renderTypst(child))
                }
            }
            out.write(TypstRenderUtils.renderRawInline(html.htmlContent(childrenTypst.toString())))
        }
    }
}
