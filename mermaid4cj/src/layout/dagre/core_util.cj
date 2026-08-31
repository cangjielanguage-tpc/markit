package mermaid4cj.layout.dagre

import std.collection.{ArrayList, HashMap}

public func dagreSimplify(graph: DagreLayoutGraph): DagreLayoutGraph {
    let out = DagreLayoutGraph(label: graph.graphLabel)
    for (id in graph.nodes()) {
        out.setNode(id, node: graph.node(id).getOrThrow().copy())
    }
    for (key in graph.edges()) {
        let label = graph.edge(key).getOrThrow()
        if (let Some(existing) <- out.edge(key.start, key.end)) {
            existing.weight += label.weight
            existing.minlen = max(existing.minlen, label.minlen)
        } else {
            out.setEdge(
                key.start,
                key.end,
                edge: DagreLayoutEdge(key.start + "->" + key.end, minlen: label.minlen, weight: label.weight),
                name: key.start + "->" + key.end
            )
        }
    }
    return out
}

public func dagreAsNonCompoundGraph(graph: DagreLayoutGraph): DagreLayoutGraph {
    let out = DagreLayoutGraph(label: graph.graphLabel)
    for (id in graph.nodes()) {
        if (graph.children(id).isEmpty()) {
            out.setNode(id, node: graph.node(id).getOrThrow())
        }
    }
    for (key in graph.edges()) {
        out.setEdge(key.start, key.end, edge: graph.edge(key).getOrThrow(), name: key.name)
    }
    return out
}

public func dagreMakeSpaceForEdgeLabels(graph: DagreLayoutGraph): Unit {
    graph.graphLabel.ranksep = graph.graphLabel.ranksep / 2.0
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        edge.minlen = edge.minlen * 2
        if (edge.labelpos != "c") {
            let rankdir = graph.graphLabel.rankdir
            if (rankdir == "TB" || rankdir == "BT") {
                edge.width += edge.labeloffset
            } else {
                edge.height += edge.labeloffset
            }
        }
    }
}

public func dagreInjectEdgeLabelProxies(graph: DagreLayoutGraph): Unit {
    let keys = graph.edges()
    for (key in keys) {
        let edge = graph.edge(key).getOrThrow()
        if (edge.width != 0.0 && edge.height != 0.0) {
            let startRank = graph.node(key.start).getOrThrow().rank ?? 0
            let endRank = graph.node(key.end).getOrThrow().rank ?? 0
            let proxy = DagreLayoutNode("")
            proxy.rank = Some((endRank - startRank) / 2 + startRank)
            proxy.edgeObj = Some(key)
            graph.addDummyNode("edge-proxy", proxy, "_ep")
        }
    }
}

public func dagreRemoveEdgeLabelProxies(graph: DagreLayoutGraph): Unit {
    let nodes = graph.nodes()
    for (id in nodes) {
        if (!graph.hasNode(id)) {
            continue
        }
        let node = graph.node(id).getOrThrow()
        if ((node.dummy ?? "") == "edge-proxy") {
            let edgeObj = node.edgeObj.getOrThrow()
            if (let Some(edge) <- graph.edge(edgeObj)) {
                edge.labelRank = node.rank
            }
            graph.removeNode(id)
        }
    }
}

public func dagreRemoveSelfEdges(graph: DagreLayoutGraph): Unit {
    let keys = graph.edges()
    for (key in keys) {
        if (key.start == key.end) {
            let node = graph.node(key.start).getOrThrow()
            let label = graph.edge(key).getOrThrow()
            node.selfEdges.add(DagreSelfEdge(key, label))
            graph.removeEdge(key)
        }
    }
}

public func dagreInsertSelfEdges(graph: DagreLayoutGraph): Unit {
    let layers = dagreBuildLayerMatrix(graph)
    for (layer in layers) {
        var orderShift: Int64 = 0
        for (i in 0..layer.size) {
            let node = graph.node(layer[i]).getOrThrow()
            node.order = Some(i + orderShift)
            for (selfEdge in node.selfEdges) {
                orderShift++
                let dummy = DagreLayoutNode("", width: selfEdge.label.width, height: selfEdge.label.height)
                dummy.rank = node.rank
                dummy.order = Some(i + orderShift)
                dummy.edgeObj = Some(selfEdge.key)
                dummy.edgeLabel = Some(selfEdge.label)
                graph.addDummyNode("selfedge", dummy, "_se")
            }
            node.selfEdges = ArrayList<DagreSelfEdge>()
        }
    }
}

public func dagreAssignRankMinMax(graph: DagreLayoutGraph): Unit {
    var maxRank: Int64 = 0
    for (id in graph.nodes()) {
        let node = graph.node(id).getOrThrow()
        if (let Some(borderTop) <- node.borderTop) {
            node.minRank = graph.node(borderTop).getOrThrow().rank
            if (let Some(borderBottom) <- node.borderBottom) {
                node.maxRank = graph.node(borderBottom).getOrThrow().rank
            }
            if (let Some(value) <- node.maxRank) {
                maxRank = max(maxRank, value)
            }
        }
    }
    graph.graphLabel.maxRank = maxRank
}

public func dagreParentDummyChains(graph: DagreLayoutGraph): Unit {
    let postorderNums = dagrePostorder(graph)
    for (start in graph.graphLabel.dummyChains) {
        if (!graph.hasNode(start)) {
            continue
        }
        var v = start
        var node = graph.node(v).getOrThrow()
        let edgeObj = node.edgeObj.getOrThrow()
        let pathData = dagreFindPath(graph, postorderNums, edgeObj.start, edgeObj.end)
        let path = pathData.path
        let lca = pathData.lca
        if (path.isEmpty()) {
            continue
        }
        var pathIdx: Int64 = 0
        var pathV = path[pathIdx]
        var ascending = true

        while (v != edgeObj.end) {
            node = graph.node(v).getOrThrow()
            if (ascending) {
                pathV = path[pathIdx]
                while (pathV != lca && (graph.node(pathV).getOrThrow().maxRank ?? 0) < (node.rank ?? 0)) {
                    pathIdx++
                    pathV = path[pathIdx]
                }
                if (pathV == lca) {
                    ascending = false
                }
            }
            if (!ascending) {
                while (pathIdx < path.size - 1) {
                    let nextPathV = path[pathIdx + 1]
                    if ((graph.node(nextPathV).getOrThrow().minRank ?? 0) <= (node.rank ?? 0)) {
                        pathIdx++
                    } else {
                        break
                    }
                }
                pathV = path[pathIdx]
            }
            graph.setParent(v, pathV)
            let successors = graph.successors(v)
            if (successors.isEmpty()) {
                break
            }
            v = successors[0]
        }
    }
}

public func dagreAddBorderSegments(graph: DagreLayoutGraph): Unit {
    for (id in graph.children()) {
        dagreAddBorderSegmentsDfs(graph, id)
    }
}

func dagreAddBorderSegmentsDfs(graph: DagreLayoutGraph, id: String): Unit {
    let children = graph.children(id)
    if (!children.isEmpty()) {
        for (child in children) {
            dagreAddBorderSegmentsDfs(graph, child)
        }
    }
    let node = graph.node(id).getOrThrow()
    if (let Some(minRank) <- node.minRank) {
        let maxRank = node.maxRank ?? minRank
        node.borderLeft = ArrayList<String>()
        node.borderRight = ArrayList<String>()
        for (rank in minRank..(maxRank + 1)) {
            dagreAddBorderSegmentNode(graph, id, node, rank, true)
            dagreAddBorderSegmentNode(graph, id, node, rank, false)
        }
    }
}

func dagreAddBorderSegmentNode(graph: DagreLayoutGraph, sg: String, sgNode: DagreLayoutNode, rank: Int64, left: Bool): Unit {
    let nodes = if (left) { sgNode.borderLeft } else { sgNode.borderRight }
    dagreEnsureStringSlots(nodes, rank)
    let prev = if (rank > 0 && rank - 1 < nodes.size) { nodes[rank - 1] } else { "" }
    let node = DagreLayoutNode("", width: 0.0, height: 0.0)
    node.rank = Some(rank)
    node.borderType = Some(if (left) { "borderLeft" } else { "borderRight" })
    let curr = graph.addDummyNode("border", node, if (left) { "_bl" } else { "_br" })
    nodes[rank] = curr
    graph.setParent(curr, sg)
    if (!prev.isEmpty()) {
        graph.setEdge(prev, curr, edge: DagreLayoutEdge(prev + "->" + curr, weight: 1.0))
    }
}

public func dagreRemoveBorderNodes(graph: DagreLayoutGraph): Unit {
    for (id in graph.nodes()) {
        if (!graph.hasNode(id)) {
            continue
        }
        if (!graph.children(id).isEmpty()) {
            let node = graph.node(id).getOrThrow()
            if (let Some(borderTop) <- node.borderTop) {
                if (let Some(borderBottom) <- node.borderBottom) {
                    if (!node.borderLeft.isEmpty() && !node.borderRight.isEmpty()) {
                        let top = graph.node(borderTop).getOrThrow()
                        let bottom = graph.node(borderBottom).getOrThrow()
                        let left = graph.node(dagreLastNonEmpty(node.borderLeft)).getOrThrow()
                        let right = graph.node(dagreLastNonEmpty(node.borderRight)).getOrThrow()
                        node.width = dagreAbs(right.x - left.x)
                        node.height = dagreAbs(bottom.y - top.y)
                        node.x = left.x + node.width / 2.0
                        node.y = top.y + node.height / 2.0
                    }
                }
            }
        }
    }
    let nodes = graph.nodes()
    for (id in nodes) {
        if (graph.hasNode(id) && (graph.node(id).getOrThrow().dummy ?? "") == "border") {
            graph.removeNode(id)
        }
    }
}

public func dagreMaxRank(graph: DagreLayoutGraph): Int64 {
    var found = false
    var value: Int64 = 0
    for (id in graph.nodes()) {
        if (let Some(rank) <- graph.node(id).getOrThrow().rank) {
            if (!found || rank > value) {
                value = rank
                found = true
            }
        }
    }
    return value
}

public func dagreBuildLayerMatrix(graph: DagreLayoutGraph): Array<Array<String>> {
    let maxRank = dagreMaxRank(graph)
    let layers = Array<ArrayList<String>>(maxRank + 1, { _ => ArrayList<String>() })
    for (id in graph.nodes()) {
        let node = graph.node(id).getOrThrow()
        if (let Some(rank) <- node.rank) {
            let order = node.order ?? layers[rank].size
            while (layers[rank].size <= order) {
                layers[rank].add("")
            }
            layers[rank][order] = id
        }
    }
    return Array<Array<String>>(layers.size, { i =>
        let compact = ArrayList<String>()
        for (id in layers[i]) {
            if (!id.isEmpty()) {
                compact.add(id)
            }
        }
        compact.toArray()
    })
}

public func dagreNormalizeRanks(graph: DagreLayoutGraph): Unit {
    var found = false
    var minRank: Int64 = 0
    for (id in graph.nodes()) {
        if (let Some(rank) <- graph.node(id).getOrThrow().rank) {
            if (!found || rank < minRank) {
                minRank = rank
                found = true
            }
        }
    }
    if (!found) {
        return
    }
    for (id in graph.nodes()) {
        let node = graph.node(id).getOrThrow()
        if (let Some(rank) <- node.rank) {
            node.rank = Some(rank - minRank)
        }
    }
}

public func dagreRemoveEmptyRanks(graph: DagreLayoutGraph): Unit {
    var found = false
    var minRank: Int64 = 0
    var maxRank: Int64 = 0
    for (id in graph.nodes()) {
        if (let Some(rank) <- graph.node(id).getOrThrow().rank) {
            if (!found) {
                minRank = rank
                maxRank = rank
                found = true
            } else {
                minRank = min(minRank, rank)
                maxRank = max(maxRank, rank)
            }
        }
    }
    if (!found) {
        return
    }
    let layers = Array<Bool>(maxRank - minRank + 1, repeat: false)
    for (id in graph.nodes()) {
        if (let Some(rank) <- graph.node(id).getOrThrow().rank) {
            layers[rank - minRank] = true
        }
    }
    var delta: Int64 = 0
    for (i in 0..layers.size) {
        if (!layers[i] && i % graph.graphLabel.nodeRankFactor != 0) {
            delta--
        } else if (delta != 0) {
            for (id in graph.nodes()) {
                let node = graph.node(id).getOrThrow()
                if (let Some(rank) <- node.rank) {
                    if (rank - minRank == i) {
                        node.rank = Some(rank + delta)
                    }
                }
            }
        }
    }
}

public func dagreIntersectRectNode(node: DagreLayoutNode, point: DagrePoint): DagrePoint {
    let rect = DagreNode(node.id, x: Some(node.x), y: Some(node.y), width: Some(node.width), height: Some(node.height))
    return intersectRect(rect, point)
}

public func dagreAddBorderNode(graph: DagreLayoutGraph, prefix: String, rank!: ?Int64 = None, order!: ?Int64 = None): String {
    let node = DagreLayoutNode("", width: 0.0, height: 0.0)
    node.rank = rank
    node.order = order
    return graph.addDummyNode("border", node, prefix)
}

class DagrePostorderEntry {
    let low: Int64
    let lim: Int64

    init(low: Int64, lim: Int64) {
        this.low = low
        this.lim = lim
    }
}

class DagrePathData {
    let path: ArrayList<String>
    let lca: String

    init(path: ArrayList<String>, lca: String) {
        this.path = path
        this.lca = lca
    }
}

func dagrePostorder(graph: DagreLayoutGraph): HashMap<String, DagrePostorderEntry> {
    let result = HashMap<String, DagrePostorderEntry>()
    var lim: Int64 = 0
    for (id in graph.children()) {
        lim = dagrePostorderDfs(graph, result, id, lim)
    }
    return result
}

func dagrePostorderDfs(graph: DagreLayoutGraph, result: HashMap<String, DagrePostorderEntry>, id: String, lim: Int64): Int64 {
    let low = lim
    var next = lim
    for (child in graph.children(id)) {
        next = dagrePostorderDfs(graph, result, child, next)
    }
    result[id] = DagrePostorderEntry(low, next)
    return next + 1
}

func dagreFindPath(graph: DagreLayoutGraph, postorderNums: HashMap<String, DagrePostorderEntry>, v: String, w: String): DagrePathData {
    let vPath = ArrayList<String>()
    let wPath = ArrayList<String>()
    let vPost = postorderNums.get(v).getOrThrow()
    let wPost = postorderNums.get(w).getOrThrow()
    let low = min(vPost.low, wPost.low)
    let lim = max(vPost.lim, wPost.lim)

    var parent = v
    var lca = ""
    var done = false
    while (!done) {
        if (let Some(nextParent) <- graph.parent(parent)) {
            parent = nextParent
            vPath.add(parent)
            let parentPost = postorderNums.get(parent).getOrThrow()
            if (!(parentPost.low > low || lim > parentPost.lim)) {
                lca = parent
                done = true
            }
        } else {
            lca = parent
            done = true
        }
    }

    parent = w
    var walking = true
    while (walking) {
        if (let Some(nextParent) <- graph.parent(parent)) {
            parent = nextParent
            if (parent == lca) {
                walking = false
            } else {
                wPath.add(parent)
            }
        } else {
            walking = false
        }
    }

    var idx = wPath.size - 1
    while (idx >= 0) {
        vPath.add(wPath[idx])
        idx--
    }
    return DagrePathData(vPath, lca)
}

func dagreEnsureStringSlots(values: ArrayList<String>, index: Int64): Unit {
    while (values.size <= index) {
        values.add("")
    }
}

func dagreLastNonEmpty(values: ArrayList<String>): String {
    var index = values.size - 1
    while (index >= 0) {
        if (!values[index].isEmpty()) {
            return values[index]
        }
        index--
    }
    return values[values.size - 1]
}

func dagreAbs(value: Float64): Float64 {
    if (value < 0.0) {
        return -value
    }
    return value
}
