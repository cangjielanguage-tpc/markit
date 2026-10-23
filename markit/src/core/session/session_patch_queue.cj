package markit.core.session

import std.collection.ArrayList
import markit.core.nodes.Node

internal class SessionPatchLink {
    internal SessionPatchLink(internal let node: Node, internal let previous: ?SessionPatchLink) {}
}

// O(1) immutable record roots. Nodes themselves are owned by the syntax
// transaction: queue rollback does not clone or mutate an existing AST.
public class SessionPatchSnapshot {
    internal SessionPatchSnapshot(internal let replacements: ?SessionPatchLink, internal let removals: ?SessionPatchLink) {}
}

public class SessionPatchQueue {
    private var replaceNodes: ?SessionPatchLink = None
    private var removeNodes: ?SessionPatchLink = None

    public func replace(node: Node): Unit {
        if (!containsNode(replaceNodes, node)) { replaceNodes = Some(SessionPatchLink(node, replaceNodes)) }
    }

    public func remove(node: Node): Unit {
        if (!containsNode(removeNodes, node)) { removeNodes = Some(SessionPatchLink(node, removeNodes)) }
    }

    public func drainReplaceNodes(): ArrayList<Node> {
        let drained = orderedNodes(replaceNodes)
        replaceNodes = None
        return drained
    }

    public func drainRemoveNodes(): ArrayList<Node> {
        let drained = orderedNodes(removeNodes)
        removeNodes = None
        return drained
    }

    public func isEmpty(): Bool { return replaceNodes.isNone() && removeNodes.isNone() }

    public func snapshot(): SessionPatchSnapshot { return SessionPatchSnapshot(replaceNodes, removeNodes) }

    public func restore(snapshot: SessionPatchSnapshot): Unit {
        replaceNodes = snapshot.replacements
        removeNodes = snapshot.removals
    }

    private func containsNode(head: ?SessionPatchLink, node: Node): Bool {
        var cursor = head
        while (let Some(link) <- cursor) {
            if (link.node.id == node.id) { return true }
            cursor = link.previous
        }
        return false
    }

    private func orderedNodes(head: ?SessionPatchLink): ArrayList<Node> {
        let reversed = ArrayList<Node>()
        var cursor = head
        while (let Some(link) <- cursor) { reversed.add(link.node); cursor = link.previous }
        let result = ArrayList<Node>()
        var index = reversed.size
        while (index > 0) { index -= 1; result.add(reversed[index]) }
        return result
    }
}
