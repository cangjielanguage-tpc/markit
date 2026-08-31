package mermaid4cj.layout.dagre

import std.collection.ArrayList

public func dagreNetworkSimplex(graph: DagreLayoutGraph): Unit {
    let working = dagreSimplify(graph)
    dagreLongestPath(working)
    let tree = dagreFeasibleTree(working)
    dagreInitLowLimValues(tree)
    dagreInitCutValues(tree, working)

    var leaving = dagreLeaveEdge(tree)
    while (leaving.isSome()) {
        let edge = leaving.getOrThrow()
        let entering = dagreEnterEdge(tree, working, edge)
        if (entering.isNone()) {
            break
        }
        dagreExchangeEdges(tree, working, edge, entering.getOrThrow())
        leaving = dagreLeaveEdge(tree)
    }

    for (id in graph.nodes()) {
        if (let Some(node) <- graph.node(id)) {
            if (let Some(workingNode) <- working.node(id)) {
                node.rank = workingNode.rank
            }
        }
    }
}

public func dagreInitCutValues(tree: DagreLayoutGraph, graph: DagreLayoutGraph): Unit {
    let nodes = dagrePostorder(tree, tree.nodes())
    if (nodes.isEmpty()) {
        return
    }
    for (i in 0..nodes.size - 1) {
        dagreAssignCutValue(tree, graph, nodes[i])
    }
}

func dagreAssignCutValue(tree: DagreLayoutGraph, graph: DagreLayoutGraph, child: String): Unit {
    let childLabel = tree.node(child).getOrThrow()
    if (let Some(parent) <- childLabel.parent) {
        let edge = dagreTreeEdge(tree, child, parent).getOrThrow()
        edge.cutvalue = Some(dagreCalcCutValue(tree, graph, child))
    }
}

public func dagreCalcCutValue(tree: DagreLayoutGraph, graph: DagreLayoutGraph, child: String): Float64 {
    let childLabel = tree.node(child).getOrThrow()
    let parent = childLabel.parent.getOrThrow()
    var childIsTail = true
    var graphEdge = graph.edge(child, parent)

    if (graphEdge.isNone()) {
        childIsTail = false
        graphEdge = graph.edge(parent, child)
    }

    var cutValue = graphEdge.getOrThrow().weight

    for (edge in graph.nodeEdges(child)) {
        let isOutEdge = edge.start == child
        let other = if (isOutEdge) { edge.end } else { edge.start }
        if (other != parent) {
            let pointsToHead = isOutEdge == childIsTail
            let otherWeight = graph.edge(edge).getOrThrow().weight
            cutValue += if (pointsToHead) { otherWeight } else { -otherWeight }
            if (dagreIsTreeEdge(tree, child, other)) {
                let otherCutValue = dagreTreeEdge(tree, child, other).getOrThrow().cutvalue ?? 0.0
                cutValue += if (pointsToHead) { -otherCutValue } else { otherCutValue }
            }
        }
    }

    return cutValue
}

public func dagreInitLowLimValues(tree: DagreLayoutGraph, root!: ?String = None): Unit {
    let nodes = tree.nodes()
    if (nodes.isEmpty()) {
        return
    }
    let start = root ?? nodes[0]
    let visited = ArrayList<String>()
    dagreDfsAssignLowLim(tree, visited, 1, start, None)
}

func dagreDfsAssignLowLim(tree: DagreLayoutGraph, visited: ArrayList<String>, nextLim: Int64, id: String, parent: ?String): Int64 {
    var next = nextLim
    let low = next
    let label = tree.node(id).getOrThrow()
    visited.add(id)

    for (neighbor in tree.neighbors(id)) {
        if (!containsCoreString(visited, neighbor)) {
            next = dagreDfsAssignLowLim(tree, visited, next, neighbor, Some(id))
        }
    }

    label.low = Some(low)
    label.lim = Some(next)
    next++
    label.parent = parent
    return next
}

public func dagreLeaveEdge(tree: DagreLayoutGraph): ?DagreLayoutEdgeKey {
    for (edge in tree.edges()) {
        if ((tree.edge(edge).getOrThrow().cutvalue ?? 0.0) < 0.0) {
            return Some(edge)
        }
    }
    return None
}

public func dagreEnterEdge(tree: DagreLayoutGraph, graph: DagreLayoutGraph, edge: DagreLayoutEdgeKey): ?DagreLayoutEdgeKey {
    var tail = edge.start
    var head = edge.end

    if (!graph.hasEdge(tail, head)) {
        tail = edge.end
        head = edge.start
    }

    let tailLabelOriginal = tree.node(tail).getOrThrow()
    let headLabel = tree.node(head).getOrThrow()
    var tailLabel = tailLabelOriginal
    var flip = false

    if ((tailLabelOriginal.lim ?? 0) > (headLabel.lim ?? 0)) {
        tailLabel = headLabel
        flip = true
    }

    var found = false
    var best = DagreLayoutEdgeKey("", "", "")
    var bestSlack: Int64 = 0
    for (candidate in graph.edges()) {
        let startDescendant = dagreIsDescendant(tree, tree.node(candidate.start).getOrThrow(), tailLabel)
        let endDescendant = dagreIsDescendant(tree, tree.node(candidate.end).getOrThrow(), tailLabel)
        if (flip == startDescendant && flip != endDescendant) {
            let value = dagreSlack(graph, candidate)
            if (!found || value < bestSlack) {
                found = true
                best = candidate
                bestSlack = value
            }
        }
    }

    return if (found) { Some(best) } else { None }
}

public func dagreExchangeEdges(tree: DagreLayoutGraph, graph: DagreLayoutGraph, leaving: DagreLayoutEdgeKey, entering: DagreLayoutEdgeKey): Unit {
    dagreRemoveTreeEdge(tree, leaving.start, leaving.end)
    dagreSetTreeEdge(tree, entering.start, entering.end)
    dagreInitLowLimValues(tree)
    dagreInitCutValues(tree, graph)
    dagreUpdateRanks(tree, graph)
}

func dagreUpdateRanks(tree: DagreLayoutGraph, graph: DagreLayoutGraph): Unit {
    var root = ""
    for (id in tree.nodes()) {
        if ((tree.node(id).getOrThrow().parent).isNone()) {
            root = id
            break
        }
    }
    if (root.isEmpty()) {
        return
    }

    let nodes = dagrePreorder(tree, root)
    for (i in 1..nodes.size) {
        let id = nodes[i]
        let parent = tree.node(id).getOrThrow().parent.getOrThrow()
        var edge = graph.edge(id, parent)
        var flipped = false
        if (edge.isNone()) {
            edge = graph.edge(parent, id)
            flipped = true
        }
        let parentRank = graph.node(parent).getOrThrow().rank ?? 0
        let minlen = edge.getOrThrow().minlen
        graph.node(id).getOrThrow().rank = Some(parentRank + if (flipped) { minlen } else { -minlen })
    }
}

func dagreTreeEdge(tree: DagreLayoutGraph, start: String, end: String): ?DagreLayoutEdge {
    if (let Some(edge) <- tree.edge(start, end)) {
        return Some(edge)
    }
    return tree.edge(end, start)
}

func dagreSetTreeEdge(tree: DagreLayoutGraph, start: String, end: String): Unit {
    if (start <= end) {
        tree.setEdge(start, end)
    } else {
        tree.setEdge(end, start)
    }
}

func dagreIsTreeEdge(tree: DagreLayoutGraph, start: String, end: String): Bool {
    return tree.hasEdge(start, end) || tree.hasEdge(end, start)
}

func dagreRemoveTreeEdge(tree: DagreLayoutGraph, start: String, end: String): Unit {
    if (tree.hasEdge(start, end)) {
        tree.removeEdge(start, end)
    } else {
        tree.removeEdge(end, start)
    }
}

func dagreIsDescendant(tree: DagreLayoutGraph, nodeLabel: DagreLayoutNode, rootLabel: DagreLayoutNode): Bool {
    let rootLow = rootLabel.low ?? 0
    let rootLim = rootLabel.lim ?? 0
    let nodeLim = nodeLabel.lim ?? 0
    return rootLow <= nodeLim && nodeLim <= rootLim
}

func dagrePreorder(tree: DagreLayoutGraph, root: String): Array<String> {
    let out = ArrayList<String>()
    let visited = ArrayList<String>()
    dagrePreorderDfs(tree, root, visited, out)
    return out.toArray()
}

func dagrePreorderDfs(tree: DagreLayoutGraph, id: String, visited: ArrayList<String>, out: ArrayList<String>): Unit {
    visited.add(id)
    out.add(id)
    for (neighbor in tree.neighbors(id)) {
        if (!containsCoreString(visited, neighbor)) {
            dagrePreorderDfs(tree, neighbor, visited, out)
        }
    }
}

func dagrePostorder(tree: DagreLayoutGraph, roots: Array<String>): Array<String> {
    let out = ArrayList<String>()
    let visited = ArrayList<String>()
    for (root in roots) {
        if (!containsCoreString(visited, root)) {
            dagrePostorderDfs(tree, root, visited, out)
        }
    }
    return out.toArray()
}

func dagrePostorderDfs(tree: DagreLayoutGraph, id: String, visited: ArrayList<String>, out: ArrayList<String>): Unit {
    visited.add(id)
    for (neighbor in tree.neighbors(id)) {
        if (!containsCoreString(visited, neighbor)) {
            dagrePostorderDfs(tree, neighbor, visited, out)
        }
    }
    out.add(id)
}
