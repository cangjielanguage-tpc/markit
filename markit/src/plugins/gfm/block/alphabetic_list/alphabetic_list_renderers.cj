package markit.plugins.gfm.block.alphabetic_list

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TextRenderUtils

public class AlphabeticListHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AlphabeticListPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        let isUpperCase = node.bool("isUpperCase") ?? false
        out.raw(if (isUpperCase) { "<ol class=\"alphabetic-list uppercase${registry.htmlClassSuffix(node)}\">" } else { "<ol class=\"alphabetic-list${registry.htmlClassSuffix(node)}\">" })
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        out.raw("</ol>")
    }
}

public class AlphabeticListItemHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AlphabeticListPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<li${registry.htmlClassAttribute(node)}>")
        if (node.children.isEmpty()) {
            out.text(node.literal)
        } else {
            for (child in node.children) {
                if (child.kind == "Paragraph") {
                    writeParagraphChildrenInline(child, out, registry)
                } else {
                    registry.writeHtml(child, out)
                }
            }
        }
        out.raw("</li>")
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

public class AlphabeticListMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AlphabeticListPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let parts = ArrayList<String>()
        for (child in node.children) {
            if (let item: AlphabeticListItemNode <- child) {
                let marker = String.fromUtf8([item.letter]) + String.fromUtf8([item.delimiter]) + " "
                let body = renderItemBody(item, registry)
                parts.add(marker + TextRenderUtils.indentContinuationLines(body, TextRenderUtils.indentSpaces(marker.size)))
            }
        }
        if (!parts.isEmpty()) {
            out.write(String.join(parts.toArray(), delimiter: "\n") + "\n\n")
        }
    }

    private func renderItemBody(node: Node, registry: RenderRegistry): String {
        if (node.children.isEmpty()) {
            return node.literal
        }
        let segments = ArrayList<String>()
        for (child in node.children) {
            let rendered = if (child.kind == "Paragraph") {
                child.literal
            } else {
                TextRenderUtils.trimRight(registry.renderMarkdown(child))
            }
            if (!rendered.isEmpty()) {
                segments.add(rendered)
            }
        }
        return String.join(segments.toArray(), delimiter: "\n\n")
    }
}

public class AlphabeticListTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AlphabeticListPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let parts = ArrayList<String>()
        for (child in node.children) {
            let rendered = renderItemTypst(child, registry).trimAscii()
            if (!rendered.isEmpty()) {
                parts.add("+ " + TextRenderUtils.indentContinuationLines(rendered, "  "))
            }
        }
        if (!parts.isEmpty()) {
            out.write(String.join(parts.toArray(), delimiter: "\n") + "\n\n")
        }
    }

    private func renderItemTypst(node: Node, registry: RenderRegistry): String {
        if (node.children.isEmpty()) {
            return node.literal
        }
        let sb = StringBuilder()
        for (child in node.children) {
            sb.append(registry.renderTypst(child))
        }
        return sb.toString()
    }
}

public class AlphabeticListItemMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AlphabeticListPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (node.children.isEmpty()) {
            out.write(node.literal)
            return
        }
        for (child in node.children) {
            registry.writeMarkdown(child, out)
        }
    }
}

public class AlphabeticListItemTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "AlphabeticListPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (node.children.isEmpty()) {
            out.write(node.literal)
            return
        }
        for (child in node.children) {
            registry.writeTypst(child, out)
        }
    }
}
