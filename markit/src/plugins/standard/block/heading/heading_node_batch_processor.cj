package markit.plugins.standard.block.heading

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.plugin.NodeBatchProcessor
import markit.core.session.ParseSession

public class HeadingNodeBatchProcessor <: NodeBatchProcessor {
    public prop ownerPlugin: String {
        get() {
            return "HeadingPlugin"
        }
    }

    public func process(session: ParseSession, nodes: ArrayList<Node>): ArrayList<Node> {
        let state = session.symbolTables.get(HeadingPlugin.stateKey)
        return rewriteNodes(nodes, state.closableEnabled())
    }

    private func rewriteNodes(nodes: ArrayList<Node>, closableEnabled: Bool): ArrayList<Node> {
        let rewritten = ArrayList<Node>()
        var hiddenLevel: Int64 = 0

        for (node in nodes) {
            if (!node.children.isEmpty()) {
                let rewrittenChildren = rewriteNodes(node.children, closableEnabled)
                node.children.clear()
                for (child in rewrittenChildren) {
                    node.addChild(child)
                }
            }

            if (!closableEnabled) {
                rewritten.add(node)
                continue
            }

            if (node.kind == "Heading") {
                if (hiddenLevel > 0 && node.level <= hiddenLevel) {
                    hiddenLevel = 0
                }

                let closable = node.bool("closable") ?? false
                if (hiddenLevel > 0) {
                    continue
                }
                if (closable) {
                    hiddenLevel = node.level
                    continue
                }
            } else if (hiddenLevel > 0) {
                continue
            }

            rewritten.add(node)
        }

        return rewritten
    }
}
