package markit.plugins.gfm.block.table

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.{TextRenderUtils, TypstRenderUtils}

public class TableHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw(if (node.string("tableStyle") == Some("three-line")) { "<table class=\"table-three-line${registry.htmlClassSuffix(node)}\">" } else { "<table${registry.htmlClassAttribute(node)}>" })
        var wroteHead = false
        var wroteBodyOpen = false
        for (child in node.children) {
            if (child.bool("isHeader") == Some(true)) {
                if (!wroteHead) {
                    out.raw("<thead>")
                    wroteHead = true
                }
                registry.writeHtml(child, out)
            } else {
                if (wroteHead) {
                    out.raw("</thead>")
                    wroteHead = false
                }
                if (!wroteBodyOpen) {
                    out.raw("<tbody>")
                    wroteBodyOpen = true
                }
                registry.writeHtml(child, out)
            }
        }
        if (wroteHead) {
            out.raw("</thead>")
        }
        if (wroteBodyOpen) {
            out.raw("</tbody>")
        }
        out.raw("</table>")
    }
}

public class TableRowHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<tr${registry.htmlClassAttribute(node)}>")
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        out.raw("</tr>")
    }
}

public class TableCellHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        let tag = if (node.bool("isHeader") == Some(true)) { "th" } else { "td" }
        out.raw("<")
        out.raw(tag)
        let alignment = node.string("alignment") ?? "None"
        if (alignment == "Left") {
            out.raw(AnchorRenderUtils.htmlClassAttribute("text-left", node, registry))
        } else if (alignment == "Center") {
            out.raw(AnchorRenderUtils.htmlClassAttribute("text-center", node, registry))
        } else if (alignment == "Right") {
            out.raw(AnchorRenderUtils.htmlClassAttribute("text-right", node, registry))
        } else {
            out.raw(AnchorRenderUtils.htmlAttributes(node, registry))
        }
        out.raw(">")
        if (node.children.isEmpty()) {
            out.text(node.literal)
        } else {
            for (child in node.children) {
                registry.writeHtml(child, out)
            }
        }
        out.raw("</")
        out.raw(tag)
        out.raw(">")
    }
}

public class TableMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (node.string("tableStyle") == Some("three-line")) {
            out.write("---\n")
        }
        if (let Some(id) <- firstCellAnchor(node)) {
            out.write("{#${id}}\n\n")
        }
        for (i in 0..node.children.size) {
            let row = node.children[i]
            out.write(renderRow(row, registry))
            out.write("\n")
            if (i == 0) {
                out.write(renderAlignmentRow(row))
                out.write("\n")
            }
        }
        if (node.string("tableStyle") == Some("three-line")) {
            out.write("---\n")
        }
        out.write("\n")
    }

    private func firstCellAnchor(node: Node): ?String {
        for (row in node.children) {
            if (!row.children.isEmpty()) {
                let firstCell = row.children[0]
                if (firstCell.string("anchor.auto").isSome()) {
                    return None
                }
                return firstCell.string("anchor.id")
            }
        }
        return None
    }

    private func renderRow(row: Node, registry: RenderRegistry): String {
        let cells = ArrayList<String>()
        for (cell in row.children) {
            let content = if (cell.children.isEmpty()) {
                cell.literal
            } else {
                TextRenderUtils.trimRight(registry.renderMarkdown(cell)).replace("\n", " ")
            }
            cells.add(content)
        }
        return "| " + String.join(cells.toArray(), delimiter: " | ") + " |"
    }

    private func renderAlignmentRow(row: Node): String {
        let cells = ArrayList<String>()
        for (cell in row.children) {
            let value = match (cell.string("alignment") ?? "None") {
                case "Left" => ":---"
                case "Center" => ":---:"
                case "Right" => "---:"
                case _ => "---"
            }
            cells.add(value)
        }
        return "| " + String.join(cells.toArray(), delimiter: " | ") + " |"
    }
}

public class TableRowMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let cells = ArrayList<String>()
        for (child in node.children) {
            cells.add(TextRenderUtils.trimRight(registry.renderMarkdown(child)).replace("\n", " "))
        }
        out.write("| " + String.join(cells.toArray(), delimiter: " | ") + " |")
    }
}

public class TableCellMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
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

public class TableTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let headerCells = ArrayList<String>()
        let bodyCells = ArrayList<String>()
        var bodyRowCount: Int64 = 0
        for (row in node.children) {
            let rendered = renderRowTypst(row, registry)
            if (rendered.isEmpty()) {
                continue
            }
            if (row.bool("isHeader") == Some(true)) {
                headerCells.add(rendered)
            } else {
                bodyCells.add(rendered)
                bodyRowCount += 1
            }
        }
        if (headerCells.isEmpty() && bodyCells.isEmpty()) {
            return
        }
        let style = node.string("tableStyle") ?? ""
        let body = StringBuilder()
        if (!headerCells.isEmpty() && style != "three-line") {
            body.append("table.header(")
            body.append(String.join(headerCells.toArray(), delimiter: ", "))
            body.append(")")
        } else if (!headerCells.isEmpty()) {
            body.append(String.join(headerCells.toArray(), delimiter: ", "))
        }
        if (!bodyCells.isEmpty()) {
            if (body.size > 0) {
                body.append(", ")
            }
            body.append(String.join(bodyCells.toArray(), delimiter: ", "))
        }
        let columnCount = node.int("columnCount") ?? node.children[0].children.size
        if (style == "three-line") {
            out.write("#align(center)[\n  #block(width: 100%, above: 1.45em, below: 1.45em)[\n    #table(\n")
        } else {
            out.write("#align(center)[\n  #block(width: 100%)[\n    #table(\n")
        }
        out.write("      columns: ${renderColumns(columnCount)},\n")
        out.write("      align: (${renderAlignment(node)}),\n")
        out.write("      inset: (x: 10pt, y: 6pt),\n")
        if (style == "three-line") {
            let totalRowCount = bodyRowCount + if (!headerCells.isEmpty()) { 1 } else { 0 }
            out.write("      fill: none,\n")
            out.write("      stroke: (x, y) => if ${!headerCells.isEmpty()} and y == 0 {\n")
            out.write("        (left: none, right: none, top: 1.4pt + luma(45), bottom: 0.7pt + luma(120))\n")
            out.write("      } else if y == ${totalRowCount - 1} {\n")
            out.write("        (left: none, right: none, top: none, bottom: 1.4pt + luma(45))\n")
            out.write("      } else {\n        none\n      },\n")
        } else {
            out.write("      fill: (x, y) => if ${!headerCells.isEmpty()} and y == 0 {\n        luma(245)\n      } else {\n        white\n      },\n")
            out.write("      stroke: 0.6pt + luma(180),\n")
        }
        out.write("      ${body.toString()}\n")
        out.write("    )\n  ]\n]" + tableTypstLabel(node) + "\n\n")
    }

    private func tableTypstLabel(node: Node): String {
        for (row in node.children) {
            if (!row.children.isEmpty()) {
                return AnchorRenderUtils.typstLabel(row.children[0])
            }
        }
        return ""
    }

    private func renderRowTypst(row: Node, registry: RenderRegistry): String {
        let cells = ArrayList<String>()
        for (cell in row.children) {
            let content = renderCellTypst(cell, registry)
            if (cell.bool("isHeader") == Some(true)) {
                cells.add("[*" + content + "*]")
            } else {
                cells.add("[" + content + "]")
            }
        }
        return String.join(cells.toArray(), delimiter: ", ")
    }

    private func renderCellTypst(cell: Node, registry: RenderRegistry): String {
        if (cell.children.size == 1 && cell.children[0].kind == "InlineCode") {
            return TypstRenderUtils.renderInlineCodeTable(cell.children[0].literal)
        }
        let sb = StringBuilder()
        for (child in cell.children) {
            sb.append(registry.renderTypst(child))
        }
        return sb.toString().trimAscii()
    }

    private func renderColumns(count: Int64): String {
        let parts = ArrayList<String>()
        for (_ in 0..count) {
            parts.add("1fr")
        }
        return "(" + String.join(parts.toArray(), delimiter: ", ") + ")"
    }

    private func renderAlignment(node: Node): String {
        if (node.children.isEmpty()) {
            return ""
        }
        let parts = ArrayList<String>()
        for (cell in node.children[0].children) {
            let value = match (cell.string("alignment") ?? "None") {
                case "Left" => "left"
                case "Center" => "center"
                case "Right" => "right"
                case _ => "auto"
            }
            parts.add(value)
        }
        return String.join(parts.toArray(), delimiter: ", ")
    }
}

public class TableRowTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        let cells = ArrayList<String>()
        for (child in node.children) {
            cells.add(registry.renderTypst(child))
        }
        out.write(String.join(cells.toArray(), delimiter: ", "))
    }
}

public class TableCellTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        for (child in node.children) {
            registry.writeTypst(child, out)
        }
    }
}
