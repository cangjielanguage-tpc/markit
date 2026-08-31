package markit.plugins.gfm.block.table

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.plugin.NodeBatchProcessor
import markit.core.session.ParseSession
import markit.plugins.standard.block.divider.DividerNode

public class TableThreeLineProcessor <: NodeBatchProcessor {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func process(_: ParseSession, nodes: ArrayList<Node>): ArrayList<Node> {
        mark(nodes)
        return nodes
    }

    private func mark(nodes: ArrayList<Node>): Unit {
        var index: Int64 = 0
        while (index + 2 < nodes.size) {
            let first = nodes[index]
            let second = nodes[index + 1]
            let third = nodes[index + 2]
            if (isThreeLineDivider(first) && second.kind == "Table" && isThreeLineDivider(third)) {
                second.setString("tableStyle", "three-line")
                index += 3
                continue
            }
            index += 1
        }

        for (node in nodes) {
            if (!node.children.isEmpty()) {
                mark(node.children)
            }
        }
    }

    private func isThreeLineDivider(node: Node): Bool {
        if (let divider: DividerNode <- node) {
            return divider.isHyphenLine()
        }
        return false
    }
}
