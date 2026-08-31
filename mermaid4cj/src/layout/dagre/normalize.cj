package mermaid4cj.layout.dagre

public func dagreNormalizeRun(graph: DagreLayoutGraph): Unit {
    graph.graphLabel.dummyChains.clear()
    let originalEdges = graph.edges()
    for (edge in originalEdges) {
        if (graph.hasEdge(edge.start, edge.end, name: edge.name)) {
            dagreNormalizeEdge(graph, edge)
        }
    }
}

func dagreNormalizeEdge(graph: DagreLayoutGraph, edge: DagreLayoutEdgeKey): Unit {
    var start = edge.start
    var startRank = graph.node(start).getOrThrow().rank ?? 0
    let end = edge.end
    let endRank = graph.node(end).getOrThrow().rank ?? 0
    let edgeLabel = graph.edge(edge).getOrThrow()
    let labelRank = edgeLabel.labelRank

    if (endRank == startRank + 1) {
        return
    }

    graph.removeEdge(edge)

    var i: Int64 = 0
    startRank++
    while (startRank < endRank) {
        edgeLabel.points.clear()
        let attrs = DagreLayoutNode("", width: 0.0, height: 0.0)
        attrs.edgeLabel = Some(edgeLabel)
        attrs.edgeObj = Some(edge)
        attrs.rank = Some(startRank)
        if (let Some(rank) <- labelRank) {
            if (startRank == rank) {
                attrs.width = edgeLabel.width
                attrs.height = edgeLabel.height
                attrs.dummy = Some("edge-label")
                attrs.labelpos = Some(edgeLabel.labelpos)
            }
        }
        let dummyType = attrs.dummy ?? "edge"
        var dummy = graph.addDummyNode(dummyType, attrs, "_d")

        graph.setEdge(start, dummy, edge: DagreLayoutEdge("", weight: edgeLabel.weight), name: edge.name)
        if (i == 0) {
            graph.graphLabel.dummyChains.add(dummy)
        }
        start = dummy
        i++
        startRank++
    }

    graph.setEdge(start, end, edge: DagreLayoutEdge("", weight: edgeLabel.weight), name: edge.name)
}

public func dagreNormalizeUndo(graph: DagreLayoutGraph): Unit {
    let chains = graph.graphLabel.dummyChains.toArray()
    for (chainStart in chains) {
        var id = chainStart
        var node = graph.node(id).getOrThrow()
        let originalLabel = node.edgeLabel.getOrThrow()
        let originalEdge = node.edgeObj.getOrThrow()
        graph.setEdge(originalEdge.start, originalEdge.end, edge: originalLabel, name: originalEdge.name)

        while (node.dummy.isSome()) {
            let successors = graph.successors(id)
            let next = if (successors.isEmpty()) { "" } else { successors[0] }
            graph.removeNode(id)
            originalLabel.points.add(DagrePoint(node.x, node.y))
            if ((node.dummy.getOrThrow()) == "edge-label") {
                originalLabel.x = Some(node.x)
                originalLabel.y = Some(node.y)
                originalLabel.width = node.width
                originalLabel.height = node.height
            }
            if (next.isEmpty()) {
                break
            }
            id = next
            node = graph.node(id).getOrThrow()
        }
    }
}
