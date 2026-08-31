package mermaid4cj.layout.dagre

public func dagreRank(graph: DagreLayoutGraph): Unit {
    match (graph.graphLabel.ranker) {
        case Some("network-simplex") => dagreNetworkSimplex(graph)
        case Some("tight-tree") => dagreTightTreeRanker(graph)
        case Some("longest-path") => dagreLongestPath(graph)
        case _ => dagreNetworkSimplex(graph)
    }
}

func dagreTightTreeRanker(graph: DagreLayoutGraph): Unit {
    dagreLongestPath(graph)
    dagreFeasibleTree(graph)
}
