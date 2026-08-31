package markit.plugins.gfm.inline.strikethrough

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}

public class StrikethroughHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "StrikethroughPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<del${registry.htmlClassAttribute(node)}>")
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        out.raw("</del>")
    }
}

public class StrikethroughMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "StrikethroughPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        out.write("~~")
        for (child in node.children) {
            registry.writeMarkdown(child, out)
        }
        out.write("~~")
    }
}

public class StrikethroughTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "StrikethroughPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        out.write("#strike[")
        for (child in node.children) {
            registry.writeTypst(child, out)
        }
        out.write("]")
    }
}
