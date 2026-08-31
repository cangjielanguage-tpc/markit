package mermaid4cj.layout.dagre

import std.collection.{ArrayList, HashMap}

public func dagreNestingGraphRun(graph: DagreLayoutGraph): Unit {
    let root = graph.addDummyNode("root", DagreLayoutNode(""), "_root")
    let depths = dagreTreeDepths(graph)
    let height = dagreMaxDepth(depths) - 1
    let nodeSep = 2 * height + 1
    graph.graphLabel.nestingRoot = Some(root)

    for (edge in graph.edges()) {
        let label = graph.edge(edge).getOrThrow()
        label.minlen = label.minlen * nodeSep
    }

    let weight = dagreSumWeights(graph) + 1.0
    for (child in graph.children()) {
        dagreNestingDfs(graph, root, nodeSep, weight, height, depths, child)
    }

    graph.graphLabel.nodeRankFactor = nodeSep
}

func dagreNestingDfs(graph: DagreLayoutGraph, root: String, nodeSep: Int64, weight: Float64, height: Int64, depths: HashMap<String, Int64>, id: String): Unit {
    let children = graph.children(id)
    if (children.isEmpty()) {
        if (id != root) {
            graph.setEdge(root, id, edge: DagreLayoutEdge("", minlen: nodeSep, weight: 0.0))
        }
        return
    }

    let top = dagreAddBorderNode(graph, "_bt")
    let bottom = dagreAddBorderNode(graph, "_bb")
    let label = graph.node(id).getOrThrow()
    graph.setParent(top, id)
    label.borderTop = Some(top)
    graph.setParent(bottom, id)
    label.borderBottom = Some(bottom)

    for (child in children) {
        dagreNestingDfs(graph, root, nodeSep, weight, height, depths, child)
        let childNode = graph.node(child).getOrThrow()
        let childTop = childNode.borderTop ?? child
        let childBottom = childNode.borderBottom ?? child
        let thisWeight = if (childNode.borderTop.isSome()) { weight } else { 2.0 * weight }
        let minlen = if (childTop != childBottom) { 1 } else { height - (depths.get(id) ?? 1) + 1 }

        let topEdge = DagreLayoutEdge("", minlen: minlen, weight: thisWeight)
        topEdge.nestingEdge = true
        graph.setEdge(top, childTop, edge: topEdge)

        let bottomEdge = DagreLayoutEdge("", minlen: minlen, weight: thisWeight)
        bottomEdge.nestingEdge = true
        graph.setEdge(childBottom, bottom, edge: bottomEdge)
    }

    if (graph.parent(id).isNone()) {
        graph.setEdge(root, top, edge: DagreLayoutEdge("", minlen: height + (depths.get(id) ?? 1), weight: 0.0))
    }
}

func dagreTreeDepths(graph: DagreLayoutGraph): HashMap<String, Int64> {
    let depths = HashMap<String, Int64>()
    for (id in graph.children()) {
        dagreTreeDepthsDfs(graph, depths, id, 1)
    }
    return depths
}

func dagreTreeDepthsDfs(graph: DagreLayoutGraph, depths: HashMap<String, Int64>, id: String, depth: Int64): Unit {
    let children = graph.children(id)
    if (!children.isEmpty()) {
        for (child in children) {
            dagreTreeDepthsDfs(graph, depths, child, depth + 1)
        }
    }
    depths[id] = depth
}

func dagreMaxDepth(depths: HashMap<String, Int64>): Int64 {
    var found = false
    var value: Int64 = 1
    for (depth in depths.values()) {
        if (!found || depth > value) {
            value = depth
            found = true
        }
    }
    return value
}

func dagreSumWeights(graph: DagreLayoutGraph): Float64 {
    var sum = 0.0
    for (edge in graph.edges()) {
        sum += graph.edge(edge).getOrThrow().weight
    }
    return sum
}

public func dagreNestingGraphCleanup(graph: DagreLayoutGraph): Unit {
    if (let Some(root) <- graph.graphLabel.nestingRoot) {
        graph.removeNode(root)
    }
    graph.graphLabel.nestingRoot = None
    let edges = graph.edges()
    for (edge in edges) {
        if (graph.hasEdge(edge.start, edge.end, name: edge.name) && graph.edge(edge).getOrThrow().nestingEdge) {
            graph.removeEdge(edge)
        }
    }
}
