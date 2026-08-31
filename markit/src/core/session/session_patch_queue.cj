package markit.core.session

import std.collection.ArrayList
import markit.core.nodes.Node

public class SessionPatchQueue {
    private let replaceNodes = ArrayList<Node>()
    private let removeNodes = ArrayList<Node>()

    public func replace(node: Node): Unit {
        if (!containsNode(replaceNodes, node)) {
            replaceNodes.add(node)
        }
    }

    public func remove(node: Node): Unit {
        if (!containsNode(removeNodes, node)) {
            removeNodes.add(node)
        }
    }

    public func drainReplaceNodes(): ArrayList<Node> {
        let drained = ArrayList<Node>()
        for (node in replaceNodes) {
            drained.add(node)
        }
        replaceNodes.clear()
        return drained
    }

    public func drainRemoveNodes(): ArrayList<Node> {
        let drained = ArrayList<Node>()
        for (node in removeNodes) {
            drained.add(node)
        }
        removeNodes.clear()
        return drained
    }

    public func isEmpty(): Bool {
        return replaceNodes.isEmpty() && removeNodes.isEmpty()
    }

    private func containsNode(nodes: ArrayList<Node>, node: Node): Bool {
        for (existing in nodes) {
            if (existing.id == node.id) {
                return true
            }
        }
        return false
    }
}
