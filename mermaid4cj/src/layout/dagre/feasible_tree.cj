package mermaid4cj.layout.dagre

import std.collection.ArrayList

public func dagreFeasibleTree(graph: DagreLayoutGraph): DagreLayoutGraph {
    let tree = DagreLayoutGraph()
    let nodes = graph.nodes()
    if (nodes.isEmpty()) {
        return tree
    }

    let start = nodes[0]
    let size = nodes.size
    tree.setNode(start)

    while (dagreTightTree(tree, graph) < size) {
        let edge = dagreFindMinSlackEdge(tree, graph)
        let delta = if (tree.hasNode(edge.start)) { dagreSlack(graph, edge) } else { -dagreSlack(graph, edge) }
        dagreShiftRanks(tree, graph, delta)
    }

    return tree
}

func dagreTightTree(tree: DagreLayoutGraph, graph: DagreLayoutGraph): Int64 {
    let roots = ArrayList<String>()
    for (id in tree.nodes()) {
        roots.add(id)
    }
    for (id in roots) {
        dagreTightTreeDfs(tree, graph, id)
    }
    return tree.nodes().size
}

func dagreTightTreeDfs(tree: DagreLayoutGraph, graph: DagreLayoutGraph, id: String): Unit {
    for (edge in graph.nodeEdges(id)) {
        let other = if (edge.start == id) { edge.end } else { edge.start }
        if (!tree.hasNode(other) && dagreSlack(graph, edge) == 0) {
            tree.setNode(other)
            dagreSetTreeEdge(tree, id, other)
            dagreTightTreeDfs(tree, graph, other)
        }
    }
}

func dagreFindMinSlackEdge(tree: DagreLayoutGraph, graph: DagreLayoutGraph): DagreLayoutEdgeKey {
    var found = false
    var best = DagreLayoutEdgeKey("", "", "")
    var bestSlack: Int64 = 0
    for (edge in graph.edges()) {
        if (tree.hasNode(edge.start) != tree.hasNode(edge.end)) {
            let value = dagreSlack(graph, edge)
            if (!found || value < bestSlack) {
                found = true
                best = edge
                bestSlack = value
            }
        }
    }
    return best
}

func dagreShiftRanks(tree: DagreLayoutGraph, graph: DagreLayoutGraph, delta: Int64): Unit {
    for (id in tree.nodes()) {
        let node = graph.node(id).getOrThrow()
        node.rank = Some((node.rank ?? 0) + delta)
    }
}
