package markit.plugins.toc

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}

public class TocHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TocPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let toc: TocNode <- node) {
            out.raw(toc.toHtml())
        }
    }
}

public class TocMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TocPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (let toc: TocNode <- node) {
            out.write(toc.toMarkdown())
        }
    }
}

public class TocTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TocPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (let toc: TocNode <- node) {
            out.write(toc.toTypst())
        }
    }
}
