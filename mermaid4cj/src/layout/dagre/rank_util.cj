package mermaid4cj.layout.dagre

import std.collection.ArrayList

public func dagreLongestPath(graph: DagreLayoutGraph): Unit {
    let visited = ArrayList<String>()
    for (source in graph.sources()) {
        longestPathDfs(graph, source, visited)
    }
}

func longestPathDfs(graph: DagreLayoutGraph, id: String, visited: ArrayList<String>): Int64 {
    let node = graph.node(id).getOrThrow()
    if (containsCoreString(visited, id)) {
        return node.rank ?? 0
    }
    visited.add(id)

    var hasOutgoing = false
    var rank: Int64 = 0
    for (edgeKey in graph.outEdges(id)) {
        let edge = graph.edge(edgeKey).getOrThrow()
        let candidate = longestPathDfs(graph, edgeKey.end, visited) - edge.minlen
        if (!hasOutgoing || candidate < rank) {
            rank = candidate
            hasOutgoing = true
        }
    }
    if (!hasOutgoing) {
        rank = 0
    }
    node.rank = Some(rank)
    return rank
}

public func dagreSlack(graph: DagreLayoutGraph, edge: DagreLayoutEdgeKey): Int64 {
    let startRank = graph.node(edge.start).getOrThrow().rank ?? 0
    let endRank = graph.node(edge.end).getOrThrow().rank ?? 0
    let minlen = graph.edge(edge).getOrThrow().minlen
    return endRank - startRank - minlen
}
