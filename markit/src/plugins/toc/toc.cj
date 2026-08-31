package markit.plugins.toc

import std.collection.ArrayList
import markit.core.nodes.{Node, TextNode}
import markit.plugins.standard.block.heading.HeadingNode
import markit.utils.slug

public class Toc {
    public static func parse(
        document: Node,
        title!: String = "Table of Contents",
        minLevel!: Int64 = 1,
        maxLevel!: Int64 = 6
    ): TocNode {
        let tocNode = TocNode(title: title)
        let headings = extractHeadings(document, minLevel, maxLevel)
        buildHierarchy(tocNode, headings)
        return tocNode
    }

    public static func extractHeadingList(document: Node): ArrayList<(String, Int64)> {
        let result = ArrayList<(String, Int64)>()
        for (heading in extractHeadings(document, 1, 6)) {
            let text = extractHeadingText(heading)
            result.add((text, heading.level))
        }
        return result
    }

    public static func extractDetailedHeadingList(
        document: Node,
        minLevel!: Int64 = 1,
        maxLevel!: Int64 = 6
    ): ArrayList<(String, Int64, String, String)> {
        let result = ArrayList<(String, Int64, String, String)>()
        for (heading in extractHeadings(document, minLevel, maxLevel)) {
            let text = extractHeadingText(heading)
            let number = heading.string("number") ?? ""
            let id = headingId(heading, text)
            result.add((text, heading.level, number, id))
        }
        return result
    }

    public static func generateTextToc(document: Node, indent!: String = "  "): String {
        let headings = extractHeadings(document, 1, 6)
        if (headings.isEmpty()) {
            return ""
        }

        var minHeadingLevel = headings[0].level
        for (heading in headings) {
            if (heading.level < minHeadingLevel) {
                minHeadingLevel = heading.level
            }
        }

        let sb = StringBuilder()
        for (heading in headings) {
            let depth = heading.level - minHeadingLevel
            appendRepeat(sb, indent, depth)
            sb.append("- ")
            let number = heading.string("number") ?? ""
            if (!number.isEmpty()) {
                sb.append(number.toString())
                sb.append(" ")
            }
            let text = extractHeadingText(heading)
            sb.append(text)
            sb.append("\n")
        }
        return sb.toString()
    }

    private static func extractHeadings(
        node: Node,
        minLevel: Int64,
        maxLevel: Int64
    ): ArrayList<HeadingNode> {
        let headings = ArrayList<HeadingNode>()
        if (node.string("render") == Some("false")) {
            return headings
        }

        if (let heading: HeadingNode <- node) {
            if (heading.level >= minLevel && heading.level <= maxLevel) {
                headings.add(heading)
            }
        }

        for (child in node.children) {
            for (heading in extractHeadings(child, minLevel, maxLevel)) {
                headings.add(heading)
            }
        }
        return headings
    }

    private static func buildHierarchy(tocNode: TocNode, headings: ArrayList<HeadingNode>): Unit {
        let stack = ArrayList<TocItem>()
        for (heading in headings) {
            let text = extractHeadingText(heading)
            let item = TocItem(
                text,
                heading.level,
                headingId(heading, text),
                number: heading.string("number") ?? ""
            )

            while (!stack.isEmpty() && stack[stack.size - 1].level >= item.level) {
                stack.remove(at: stack.size - 1)
            }

            if (stack.isEmpty()) {
                tocNode.addItem(item)
            } else {
                stack[stack.size - 1].addChild(item)
            }
            stack.add(item)
        }
    }

    private static func extractHeadingText(heading: HeadingNode): String {
        let sb = StringBuilder()
        for (child in heading.children) {
            appendText(child, sb)
        }
        return sb.toString()
    }

    private static func appendText(node: Node, sb: StringBuilder): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        if (let text: TextNode <- node) {
            sb.append(text.content)
            return
        }
        if (!node.literal.isEmpty() && node.children.isEmpty()) {
            sb.append(node.literal)
            return
        }
        for (child in node.children) {
            appendText(child, sb)
        }
    }

    private static func headingId(heading: HeadingNode, text: String): String {
        if (!heading.slug.isEmpty()) {
            return heading.slug
        }
        return slug(text)
    }

    private static func appendRepeat(sb: StringBuilder, value: String, count: Int64): Unit {
        for (_ in 0..count) {
            sb.append(value)
        }
    }
}
