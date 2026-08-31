package markit.plugins.toc

import std.collection.ArrayList
import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.render.HtmlEscaper
import markit.core.source.SourceSpan

public class TocNode <: Node {
    public let items = ArrayList<TocItem>()
    public let title: String

    public init(title!: String = "Table of Contents") {
        super("Toc", sourceSpan: SourceSpan.empty(), literal: title)
        this.title = title
    }

    public override prop name: String {
        get() {
            return "TocNode"
        }
    }

    public func addItem(item: TocItem): Unit {
        items.add(item)
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} - ${title}")
        for (item in items) {
            sb.append("\n")
            appendItemString(sb, item, 0)
        }
        return sb.toString()
    }

    public override func toHtml(): String {
        if (items.isEmpty()) {
            return ""
        }

        let sb = StringBuilder()
        if (!title.isEmpty()) {
            sb.append("<h2>")
            sb.append(HtmlEscaper.escape(title))
            sb.append("</h2>")
        }
        sb.append("<nav class=\"toc\" role=\"navigation\" aria-label=\"Table of contents\"><ul>")
        for (item in items) {
            appendItemHtml(sb, item)
        }
        sb.append("</ul></nav>")
        return sb.toString()
    }

    public override func toMarkdown(): String {
        if (items.isEmpty()) {
            return ""
        }

        let sb = StringBuilder()
        if (!title.isEmpty()) {
            sb.append("## ")
            sb.append(title)
            sb.append("\n\n")
        }
        for (item in items) {
            appendItemMarkdown(sb, item, 0)
        }
        return sb.toString()
    }

    public override func toTypst(): String {
        if (items.isEmpty()) {
            return ""
        }

        let sb = StringBuilder()
        if (!title.isEmpty()) {
            sb.append("= ")
            sb.append(title)
            sb.append("\n\n")
        }
        for (item in items) {
            appendItemTypst(sb, item, 0)
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("title").value(title)
        w.name("items").beginArray()
        for (item in items) {
            item.writeJson(w)
        }
        w.endArray()
        return w
    }

    private func appendItemString(sb: StringBuilder, item: TocItem, depth: Int64): Unit {
        appendRepeat(sb, "  ", depth)
        sb.append("- ")
        if (!item.number.isEmpty()) {
            sb.append(item.number)
            sb.append(" ")
        }
        sb.append(item.text)
        sb.append(" (level=${item.level}, id=${item.anchorId})")
        for (child in item.children) {
            if (let tocChild: TocItem <- child) {
                sb.append("\n")
                appendItemString(sb, tocChild, depth + 1)
            }
        }
    }

    private func appendItemHtml(sb: StringBuilder, item: TocItem): Unit {
        sb.append("<li class=\"toc-level-${item.level}\"><a href=\"#")
        sb.append(item.anchorId)
        sb.append("\">")
        if (!item.number.isEmpty()) {
            sb.append(HtmlEscaper.escape(item.number))
            sb.append(" ")
        }
        sb.append(HtmlEscaper.escape(item.text))
        sb.append("</a>")
        if (!item.children.isEmpty()) {
            sb.append("<ul>")
            for (child in item.children) {
                if (let tocChild: TocItem <- child) {
                    appendItemHtml(sb, tocChild)
                }
            }
            sb.append("</ul>")
        }
        sb.append("</li>")
    }

    private func appendItemMarkdown(sb: StringBuilder, item: TocItem, depth: Int64): Unit {
        appendRepeat(sb, "  ", depth)
        sb.append("- [")
        if (!item.number.isEmpty()) {
            sb.append(item.number)
            sb.append(" ")
        }
        sb.append(item.text)
        sb.append("](#")
        sb.append(item.anchorId)
        sb.append(")\n")
        for (child in item.children) {
            if (let tocChild: TocItem <- child) {
                appendItemMarkdown(sb, tocChild, depth + 1)
            }
        }
    }

    private func appendItemTypst(sb: StringBuilder, item: TocItem, depth: Int64): Unit {
        appendRepeat(sb, "  ", depth)
        sb.append("- ")
        if (!item.number.isEmpty()) {
            sb.append(item.number)
            sb.append(" ")
        }
        sb.append(item.text)
        sb.append("\n")
        for (child in item.children) {
            if (let tocChild: TocItem <- child) {
                appendItemTypst(sb, tocChild, depth + 1)
            }
        }
    }

    private func appendRepeat(sb: StringBuilder, value: String, count: Int64): Unit {
        for (_ in 0..count) {
            sb.append(value)
        }
    }
}
