package markit.plugins.gfm.block.task_list

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TextRenderUtils

public class TaskListHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TaskListPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<ul class=\"task-list${registry.htmlClassSuffix(node)}\">")
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        out.raw("</ul>")
    }
}

public class TaskListItemHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TaskListPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let item: TaskListItemNode <- node) {
            out.raw("<li${AnchorRenderUtils.htmlClassAttribute("task-list-item", node, registry)}><input type=\"checkbox\"")
            if (item.checked) {
                out.raw(" checked=\"checked\"")
            }
            out.raw(" /> ")
            if (item.children.isEmpty()) {
                out.text(item.content)
            } else {
                for (child in item.children) {
                    if (child.kind == "Paragraph") {
                        writeParagraphChildrenInline(child, out, registry)
                    } else {
                        registry.writeHtml(child, out)
                    }
                }
            }
            out.raw("</li>")
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

public class TaskListMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TaskListPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let parts = ArrayList<String>()
        for (child in node.children) {
            if (let item: TaskListItemNode <- child) {
                let box = if (item.checked) { "[x]" } else { "[ ]" }
                let marker = String.fromUtf8([item.marker]) + " " + box + " "
                let body = renderItemBody(item, registry)
                parts.add(marker + TextRenderUtils.indentContinuationLines(body + AnchorRenderUtils.markdownLabel(item), TextRenderUtils.indentSpaces(marker.size)))
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

public class TaskListTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TaskListPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let rows = ArrayList<String>()
        for (child in node.children) {
            if (let item: TaskListItemNode <- child) {
                let body = renderItemTypst(item, registry).trimAscii()
                if (body.isEmpty()) {
                    continue
                }
                let marker = if (item.checked) {
                    "#box(width: 0.95em, height: 0.95em, baseline: -0.05em, inset: 0pt, radius: 2.5pt, fill: rgb(\"#2563eb\"))[#align(center + horizon)[#text(fill: white, weight: \"bold\", size: 0.72em)[✓]]]"
                } else {
                    "#box(width: 0.95em, height: 0.95em, baseline: -0.05em, inset: 0pt, radius: 2.5pt, stroke: 0.75pt + rgb(\"#94a3b8\"))[]"
                }
                rows.add("[${marker}], [#set par(first-line-indent: 0em, leading: 1em, spacing: 0.18em)\n${body}${AnchorRenderUtils.typstLabel(item)}]")
            }
        }
        if (!rows.isEmpty()) {
            out.write("#grid(\n  columns: (1.2em, 1fr),\n  align: (left, horizon),\n  column-gutter: 0.65em,\n  row-gutter: 0.38em,\n  ")
            out.write(String.join(rows.toArray(), delimiter: ",\n  "))
            out.write("\n)\n\n")
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

public class TaskListItemMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TaskListPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (let item: TaskListItemNode <- node) {
            let box = if (item.checked) { "[x]" } else { "[ ]" }
            out.write(String.fromUtf8([item.marker]) + " " + box + " ")
            if (item.children.isEmpty()) {
                out.write(item.content)
            } else {
                for (child in item.children) {
                    registry.writeMarkdown(child, out)
                }
            }
        }
    }
}

public class TaskListItemTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TaskListPlugin"
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
