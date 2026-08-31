package markit.plugins.anchor

import std.collection.{ArrayList, HashMap, HashSet}
import markit.core.nodes.Node

public class AutoAnchorPostProcessor {
    private let config: AutoAnchorConfig
    private let seen = HashSet<String>()
    private let listCounters = HashMap<String, Int64>()
    private let sectionNumbers = Array<Int64>(6, repeat: 0)
    private var currentSectionPrefix: String = "0"
    private var codeIndex: Int64 = 0
    private var mathIndex: Int64 = 0
    private var tableIndex: Int64 = 0
    private var blockIndex: Int64 = 0

    public init(config: AutoAnchorConfig) {
        this.config = config
    }

    public func process(root: Node): Unit {
        walkChildren(root, "")
    }

    private func walkChildren(parent: Node, listPath: String): Unit {
        for (child in parent.children) {
            if (child.kind == "Heading") {
                enterHeading(child)
                setSourceRange(child, child)
                continue
            }

            if (isListNode(child)) {
                let kind = listKind(child)
                let listIndex = nextListIndex(kind, listPath)
                processList(child, listPath, kind, listIndex)
                continue
            }

            if (config.code && child.kind == "FencedCodeBlock") {
                codeIndex += 1
                setAnchor(child, "${sectionPrefix()}-code-${codeIndex}")
            } else if (config.math && child.kind == "MathBlock") {
                mathIndex += 1
                setAnchor(child, "${sectionPrefix()}-math-${mathIndex}")
            } else if (config.table && child.kind == "Table") {
                tableIndex += 1
                setTableAnchor(child, "${sectionPrefix()}-table-${tableIndex}")
            } else if (config.block && isGenericBlockNode(child, parent)) {
                blockIndex += 1
                setAnchor(child, "${sectionPrefix()}-block-${blockIndex}")
            }

            if (!child.children.isEmpty()) {
                walkChildren(child, listPath)
            }
        }
    }

    private func processList(list: Node, parentPath: String, kind: String, listIndex: Int64): Unit {
        let listSegment = "${kind}-${listIndex}"
        var itemIndex: Int64 = 0
        for (item in list.children) {
            itemIndex += 1
            let itemSegment = "${listSegment}.${itemIndex}"
            let path = if (parentPath.isEmpty()) {
                itemSegment
            } else {
                "${parentPath}-${itemSegment}"
            }
            if (config.list) {
                setAnchor(item, "${sectionPrefix()}-${path}")
            }
            if (!item.children.isEmpty()) {
                walkChildren(item, path)
            }
        }
    }

    private func nextListIndex(kind: String, parentPath: String): Int64 {
        let key = "${sectionPrefix()}|${parentPath}|${kind}"
        let next = (listCounters.get(key) ?? 0) + 1
        listCounters[key] = next
        return next
    }

    private func setTableAnchor(table: Node, id: String): Unit {
        for (row in table.children) {
            if (!row.children.isEmpty()) {
                setAnchor(row.children[0], id, sourceNode: table)
                return
            }
        }
    }

    private func setAnchor(node: Node, id: String, sourceNode!: ?Node = None): Unit {
        if (seen.contains(id)) {
            throw IllegalArgumentException("Duplicate auto anchor id: ${id}")
        }
        seen.add(id)
        node.setString("anchor.id", id)
        node.setString("anchor.auto", id)
        node.setBool("anchor.target", true)
        setSourceRange(node, sourceNode ?? node)
    }

    private func setSourceRange(node: Node, spanNode: Node): Unit {
        node.setInt("anchor.sourceStartByte", spanNode.sourceSpan.startByte)
        node.setInt("anchor.sourceEndByte", spanNode.sourceSpan.endByte)
    }

    private func enterHeading(node: Node): Unit {
        let level = node.level
        if (level < 1 || level > 6) {
            return
        }
        let index = level - 1
        sectionNumbers[index] = sectionNumbers[index] + 1
        for (i in level..6) {
            sectionNumbers[i] = 0
        }
        currentSectionPrefix = node.string("number") ?? fallbackSectionPrefix()
        codeIndex = 0
        mathIndex = 0
        tableIndex = 0
        blockIndex = 0
        listCounters.clear()
    }

    private func sectionPrefix(): String {
        return currentSectionPrefix
    }

    private func fallbackSectionPrefix(): String {
        let parts = ArrayList<String>()
        for (value in sectionNumbers) {
            if (value > 0) {
                parts.add(value.toString())
            }
        }
        if (parts.isEmpty()) {
            return "0"
        }
        return String.join(parts.toArray(), delimiter: ".")
    }

    private func isListNode(node: Node): Bool {
        return node.kind == "List" || node.kind == "TaskList"
    }

    private func listKind(node: Node): String {
        if (node.kind == "TaskList") {
            return "tl"
        }
        return if (node.bool("ordered") == Some(true)) { "ol" } else { "ul" }
    }

    private func isGenericBlockNode(node: Node, parent: Node): Bool {
        return (node.kind == "Paragraph" && parent.kind == "Document") ||
            node.kind == "Blockquote" ||
            node.kind == "Divider" ||
            node.kind == "HTMLBlock"
    }
}
