package mermaid4cj.layout.dagre

import std.collection.ArrayList

class ClusterInfo {
    let id: String
    var anchorId: String
    let descendants: Array<String>
    var externalConnections: Bool
    let explicitDir: Bool
    let dir: ?String

    init(id: String, anchorId: String, descendants: Array<String>, explicitDir: Bool, dir: ?String) {
        this.id = id
        this.anchorId = anchorId
        this.descendants = descendants
        this.externalConnections = false
        this.explicitDir = explicitDir
        this.dir = dir
    }
}

public func extractDescendants(id: String, graph: MermaidDagreGraph): Array<String> {
    let out = ArrayList<String>()
    appendDescendants(out, id, graph)
    return out.toArray()
}

func appendDescendants(out: ArrayList<String>, id: String, graph: MermaidDagreGraph): Unit {
    let children = graph.children(id)
    for (child in children) {
        out.add(child)
    }
    for (child in children) {
        appendDescendants(out, child, graph)
    }
}

public func sortNodesByHierarchy(graph: MermaidDagreGraph): Array<String> {
    return sorter(graph, graph.children())
}

public func validate(graph: MermaidDagreGraph): Bool {
    for (edge in graph.edges()) {
        if (!graph.children(edge.start).isEmpty()) {
            return false
        }
        if (!graph.children(edge.end).isEmpty()) {
            return false
        }
    }
    return true
}

public func adjustClustersAndEdges(graph: MermaidDagreGraph): Unit {
    let clusters = ArrayList<ClusterInfo>()
    for (id in graph.nodes()) {
        if (!graph.children(id).isEmpty()) {
            let node = graph.node(id).getOrThrow()
            clusters.add(ClusterInfo(id, findNonClusterChild(id, graph), extractDescendants(id, graph), node.explicitDir, node.dir))
        }
    }

    for (cluster in clusters) {
        for (edge in graph.edges()) {
            let startInside = containsString(cluster.descendants, edge.start)
            let endInside = containsString(cluster.descendants, edge.end)
            if (startInside != endInside) {
                cluster.externalConnections = true
                if (cluster.explicitDir) {
                    let start = if (startInside) { cluster.id } else { edge.start }
                    let end = if (endInside) { cluster.id } else { edge.end }
                    graph.removeEdge(edge.start, edge.end, edge.name)
                    graph.setEdge(start, end, edge.edge, edge.name)
                }
            }
        }
    }

    for (edge in graph.edges()) {
        let startCluster = findCluster(clusters, edge.start)
        let endCluster = findCluster(clusters, edge.end)
        if (startCluster.isNone() && endCluster.isNone()) {
            continue
        }

        var start = edge.start
        var end = edge.end
        if (let Some(cluster) <- startCluster) {
            start = getAnchorId(cluster)
        }
        if (let Some(cluster) <- endCluster) {
            end = getAnchorId(cluster)
        }
        graph.removeEdge(edge.start, edge.end, edge.name)
        graph.setEdge(start, end, edge.edge, edge.name)
    }

    for (cluster in clusters) {
        if (graph.node(cluster.id).isSome() && (!cluster.externalConnections || cluster.explicitDir) && !cluster.descendants.isEmpty()) {
            extractCluster(graph, cluster)
        }
    }
}

public func findNonClusterChild(id: String, graph: MermaidDagreGraph): String {
    let children = graph.children(id)
    if (children.isEmpty()) {
        return id
    }
    for (child in children) {
        return findNonClusterChild(child, graph)
    }
    return id
}

func sorter(graph: MermaidDagreGraph, nodes: Array<String>): Array<String> {
    let result = ArrayList<String>()
    for (node in nodes) {
        result.add(node)
    }
    for (node in nodes) {
        let sorted = sorter(graph, graph.children(node))
        for (child in sorted) {
            result.add(child)
        }
    }
    return result.toArray()
}

func findCluster(clusters: ArrayList<ClusterInfo>, id: String): ?ClusterInfo {
    for (cluster in clusters) {
        if (cluster.id == id) {
            return Some(cluster)
        }
    }
    return None
}

func extractCluster(graph: MermaidDagreGraph, cluster: ClusterInfo): Unit {
    let clusterGraph = MermaidDagreGraph().setGraph(rankdir: cluster.dir ?? graph.rankdir())
    for (descendant in cluster.descendants) {
        if (let Some(node) <- graph.node(descendant)) {
            clusterGraph.setNode(descendant, node)
        }
    }
    for (descendant in cluster.descendants) {
        if (let Some(parent) <- graph.parent(descendant)) {
            if (parent != cluster.id && containsString(cluster.descendants, parent)) {
                clusterGraph.setParent(descendant, parent)
            }
        }
    }
    for (edge in graph.edges()) {
        if (containsString(cluster.descendants, edge.start) && containsString(cluster.descendants, edge.end)) {
            clusterGraph.setEdge(edge.start, edge.end, edge.edge, edge.name)
        }
    }
    adjustClustersAndEdges(clusterGraph)
    for (descendant in cluster.descendants) {
        graph.removeNode(descendant)
    }
    graph.setNode(cluster.id, DagreNode(cluster.id, clusterNode: true, graph: Some(clusterGraph), dir: cluster.dir, explicitDir: cluster.explicitDir))
}

func getAnchorId(cluster: ClusterInfo): String {
    if (cluster.explicitDir) {
        return cluster.id
    }
    if (!cluster.externalConnections) {
        return cluster.id
    }
    return cluster.anchorId
}

func containsString(values: Array<String>, value: String): Bool {
    for (item in values) {
        if (item == value) {
            return true
        }
    }
    return false
}
