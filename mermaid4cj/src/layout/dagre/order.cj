package mermaid4cj.layout.dagre

import std.collection.{ArrayList, HashMap}

public class DagreOrderEntry {
    public let position: Int64
    public let weight: Float64

    public init(position: Int64, weight: Float64) {
        this.position = position
        this.weight = weight
    }
}

public func dagreInitOrder(graph: DagreLayoutGraph): Array<Array<String>> {
    let simpleNodes = ArrayList<String>()
    var maxRank: Int64 = 0
    var found = false
    for (id in graph.nodes()) {
        if (graph.children(id).isEmpty()) {
            simpleNodes.add(id)
            let rank = graph.node(id).getOrThrow().rank ?? 0
            if (!found || rank > maxRank) {
                maxRank = rank
                found = true
            }
        }
    }
    if (!found) {
        return Array<Array<String>>(0, { _ => Array<String>(0, { _ => "" }) })
    }

    dagreSortNodeIdsByRank(graph, simpleNodes)
    let layers = Array<ArrayList<String>>(maxRank + 1, { _ => ArrayList<String>() })
    let visited = ArrayList<String>()
    for (id in simpleNodes) {
        dagreInitOrderDfs(graph, id, visited, layers)
    }
    return Array<Array<String>>(layers.size, { i => layers[i].toArray() })
}

func dagreInitOrderDfs(graph: DagreLayoutGraph, id: String, visited: ArrayList<String>, layers: Array<ArrayList<String>>): Unit {
    if (containsCoreString(visited, id)) {
        return
    }
    visited.add(id)
    let rank = graph.node(id).getOrThrow().rank ?? 0
    layers[rank].add(id)
    for (successor in graph.successors(id)) {
        dagreInitOrderDfs(graph, successor, visited, layers)
    }
}

func dagreSortNodeIdsByRank(graph: DagreLayoutGraph, ids: ArrayList<String>): Unit {
    var i = 1
    while (i < ids.size) {
        let value = ids[i]
        let rank = graph.node(value).getOrThrow().rank ?? 0
        var j = i - 1
        while (j >= 0 && (graph.node(ids[j]).getOrThrow().rank ?? 0) > rank) {
            ids[j + 1] = ids[j]
            j--
        }
        ids[j + 1] = value
        i++
    }
}

public func dagreCrossCount(graph: DagreLayoutGraph, layering: Array<Array<String>>): Float64 {
    var count = 0.0
    for (i in 1..layering.size) {
        count += dagreTwoLayerCrossCount(graph, layering[i - 1], layering[i])
    }
    return count
}

public func dagreOrder(graph: DagreLayoutGraph): Unit {
    let maxRank = dagreMaxRank(graph)
    let downLayerGraphs = Array<DagreLayoutGraph>(maxRank, { i => dagreBuildLayerGraph(graph, i + 1, true) })
    let upLayerGraphs = Array<DagreLayoutGraph>(maxRank, { i => dagreBuildLayerGraph(graph, maxRank - 1 - i, false) })

    var layering = dagreInitOrder(graph)
    dagreAssignOrder(graph, layering)

    var foundBest = false
    var bestCC = 0.0
    var best = layering
    var i: Int64 = 0
    var lastBest: Int64 = 0
    while (lastBest < 4) {
        if (i % 2 == 1) {
            dagreSweepLayerGraphs(downLayerGraphs, i % 4 >= 2)
        } else {
            dagreSweepLayerGraphs(upLayerGraphs, i % 4 >= 2)
        }
        layering = dagreBuildLayerMatrix(graph)
        let cc = dagreCrossCount(graph, layering)
        if (!foundBest || cc < bestCC) {
            lastBest = 0
            best = dagreCloneLayering(layering)
            bestCC = cc
            foundBest = true
        } else {
            lastBest++
        }
        i++
    }
    dagreAssignOrder(graph, best)
}

func dagreBuildLayerGraph(graph: DagreLayoutGraph, rank: Int64, useInEdges: Bool): DagreLayoutGraph {
    let root = dagreCreateRootNode(graph)
    let result = DagreLayoutGraph()
    result.graphLabel.nestingRoot = Some(root)
    result.setNode(root, node: DagreLayoutNode(root))
    for (id in graph.nodes()) {
        let node = graph.node(id).getOrThrow()
        let minRank = node.minRank ?? node.rank ?? 0
        let maxRank = node.maxRank ?? node.rank ?? 0
        if ((node.rank.isSome() && (node.rank ?? 0) == rank) || (node.minRank.isSome() && minRank <= rank && rank <= maxRank)) {
            result.setNode(id, node: node)
            result.setParent(id, graph.parent(id) ?? root)
            let incident = if (useInEdges) { graph.inEdges(id) } else { graph.outEdges(id) }
            for (edgeKey in incident) {
                let u = if (edgeKey.start == id) { edgeKey.end } else { edgeKey.start }
                let existingWeight = if (let Some(edge) <- result.edge(u, id)) { edge.weight } else { 0.0 }
                result.setEdge(u, id, edge: DagreLayoutEdge(u + "->" + id, weight: graph.edge(edgeKey).getOrThrow().weight + existingWeight))
            }
            if (node.minRank.isSome()) {
                let rankIndex = rank
                if (rankIndex >= 0 && rankIndex < node.borderLeft.size && rankIndex < node.borderRight.size) {
                    let layerNode = DagreLayoutNode(id)
                    layerNode.borderLeft.add(node.borderLeft[rankIndex])
                    layerNode.borderRight.add(node.borderRight[rankIndex])
                    result.setNode(id, node: layerNode)
                }
            }
        }
    }
    return result
}

func dagreSweepLayerGraphs(layerGraphs: Array<DagreLayoutGraph>, biasRight: Bool): Unit {
    let constraintGraph = DagreLayoutGraph()
    for (layerGraph in layerGraphs) {
        let root = layerGraph.graphLabel.nestingRoot ?? ""
        let sorted = dagreSortSubgraph(layerGraph, root, constraintGraph, biasRight)
        for (i in 0..sorted.vs.size) {
            layerGraph.node(sorted.vs[i]).getOrThrow().order = Some(i)
        }
        dagreAddSubgraphConstraints(layerGraph, constraintGraph, sorted.vs)
    }
}

func dagreAssignOrder(graph: DagreLayoutGraph, layering: Array<Array<String>>): Unit {
    for (rank in 0..layering.size) {
        for (order in 0..layering[rank].size) {
            graph.node(layering[rank][order]).getOrThrow().order = Some(order)
        }
    }
}

class DagreBarycenterEntry {
    let v: String
    var barycenter: ?Float64
    var weight: ?Float64

    init(v: String, barycenter!: ?Float64 = None, weight!: ?Float64 = None) {
        this.v = v
        this.barycenter = barycenter
        this.weight = weight
    }
}

class DagreSortEntry {
    var vs: ArrayList<String>
    var i: Int64
    var barycenter: ?Float64
    var weight: ?Float64
    var indegree: Int64
    let inEntries: ArrayList<DagreSortEntry>
    let outEntries: ArrayList<DagreSortEntry>
    var merged: Bool

    init(vs: ArrayList<String>, i: Int64, barycenter!: ?Float64 = None, weight!: ?Float64 = None) {
        this.vs = vs
        this.i = i
        this.barycenter = barycenter
        this.weight = weight
        this.indegree = 0
        this.inEntries = ArrayList<DagreSortEntry>()
        this.outEntries = ArrayList<DagreSortEntry>()
        this.merged = false
    }
}

class DagreSortResult {
    var vs: ArrayList<String>
    var barycenter: ?Float64
    var weight: ?Float64

    init(vs: ArrayList<String>, barycenter!: ?Float64 = None, weight!: ?Float64 = None) {
        this.vs = vs
        this.barycenter = barycenter
        this.weight = weight
    }
}

func dagreBarycenter(graph: DagreLayoutGraph, movable: Array<String>): ArrayList<DagreBarycenterEntry> {
    let out = ArrayList<DagreBarycenterEntry>()
    for (v in movable) {
        let inV = graph.inEdges(v)
        if (inV.isEmpty()) {
            out.add(DagreBarycenterEntry(v))
        } else {
            var sum = 0.0
            var weight = 0.0
            for (edgeKey in inV) {
                let edge = graph.edge(edgeKey).getOrThrow()
                let nodeU = graph.node(edgeKey.start).getOrThrow()
                sum += edge.weight * Float64(nodeU.order ?? 0)
                weight += edge.weight
            }
            out.add(DagreBarycenterEntry(v, barycenter: sum / weight, weight: weight))
        }
    }
    return out
}

func dagreSortSubgraph(graph: DagreLayoutGraph, v: String, constraintGraph: DagreLayoutGraph, biasRight: Bool): DagreSortResult {
    var movable = graph.children(v)
    let node = graph.node(v)
    var hasBorder = false
    var borderLeft = ""
    var borderRight = ""
    if (let Some(found) <- node) {
        if (!found.borderLeft.isEmpty() && !found.borderRight.isEmpty()) {
            hasBorder = true
            borderLeft = found.borderLeft[0]
            borderRight = found.borderRight[0]
            let filtered = ArrayList<String>()
            for (w in movable) {
                if (w != borderLeft && w != borderRight) {
                    filtered.add(w)
                }
            }
            movable = filtered.toArray()
        }
    }

    let subgraphs = HashMap<String, DagreSortResult>()
    let barycenters = dagreBarycenter(graph, movable)
    for (entry in barycenters) {
        if (!graph.children(entry.v).isEmpty()) {
            let subgraphResult = dagreSortSubgraph(graph, entry.v, constraintGraph, biasRight)
            subgraphs[entry.v] = subgraphResult
            if (subgraphResult.barycenter.isSome()) {
                dagreMergeBarycenters(entry, subgraphResult)
            }
        }
    }

    let entries = dagreResolveConflicts(barycenters, constraintGraph)
    dagreExpandSubgraphs(entries, subgraphs)
    let result = dagreSort(entries, biasRight)

    if (hasBorder) {
        let withBorders = ArrayList<String>()
        withBorders.add(borderLeft)
        for (id in result.vs) {
            withBorders.add(id)
        }
        withBorders.add(borderRight)
        result.vs = withBorders
        if (!graph.predecessors(borderLeft).isEmpty()) {
            let blPred = graph.node(graph.predecessors(borderLeft)[0]).getOrThrow()
            let brPred = graph.node(graph.predecessors(borderRight)[0]).getOrThrow()
            let currentWeight = result.weight ?? 0.0
            let currentBarycenter = result.barycenter ?? 0.0
            result.barycenter = Some((currentBarycenter * currentWeight + Float64(blPred.order ?? 0) + Float64(brPred.order ?? 0)) / (currentWeight + 2.0))
            result.weight = Some(currentWeight + 2.0)
        }
    }
    return result
}

func dagreResolveConflicts(entries: ArrayList<DagreBarycenterEntry>, constraintGraph: DagreLayoutGraph): ArrayList<DagreSortEntry> {
    let mapped = HashMap<String, DagreSortEntry>()
    for (i in 0..entries.size) {
        let vs = ArrayList<String>()
        vs.add(entries[i].v)
        mapped[entries[i].v] = DagreSortEntry(vs, i, barycenter: entries[i].barycenter, weight: entries[i].weight)
    }
    for (edgeKey in constraintGraph.edges()) {
        if (mapped.get(edgeKey.start).isSome() && mapped.get(edgeKey.end).isSome()) {
            let entryV = mapped.get(edgeKey.start).getOrThrow()
            let entryW = mapped.get(edgeKey.end).getOrThrow()
            entryW.indegree++
            entryV.outEntries.add(entryW)
        }
    }
    let sourceSet = ArrayList<DagreSortEntry>()
    for (key in mapped.keys()) {
        let entry = mapped.get(key).getOrThrow()
        if (entry.indegree == 0) {
            sourceSet.add(entry)
        }
    }
    return dagreDoResolveConflicts(sourceSet)
}

func dagreDoResolveConflicts(sourceSet: ArrayList<DagreSortEntry>): ArrayList<DagreSortEntry> {
    let entries = ArrayList<DagreSortEntry>()
    while (!sourceSet.isEmpty()) {
        let entry = sourceSet[sourceSet.size - 1]
        sourceSet.remove(at: sourceSet.size - 1)
        entries.add(entry)
        var inIndex = entry.inEntries.size - 1
        while (inIndex >= 0) {
            let uEntry = entry.inEntries[inIndex]
            if (!uEntry.merged) {
                if (uEntry.barycenter.isNone() || entry.barycenter.isNone() || uEntry.barycenter.getOrThrow() >= entry.barycenter.getOrThrow()) {
                    dagreMergeSortEntries(entry, uEntry)
                }
            }
            inIndex--
        }
        for (wEntry in entry.outEntries) {
            wEntry.inEntries.add(entry)
            wEntry.indegree--
            if (wEntry.indegree == 0) {
                sourceSet.add(wEntry)
            }
        }
    }
    let out = ArrayList<DagreSortEntry>()
    for (entry in entries) {
        if (!entry.merged) {
            out.add(entry)
        }
    }
    return out
}

func dagreMergeSortEntries(target: DagreSortEntry, source: DagreSortEntry): Unit {
    var sum = 0.0
    var weight = 0.0
    if (target.weight.isSome()) {
        sum += target.barycenter.getOrThrow() * target.weight.getOrThrow()
        weight += target.weight.getOrThrow()
    }
    if (source.weight.isSome()) {
        sum += source.barycenter.getOrThrow() * source.weight.getOrThrow()
        weight += source.weight.getOrThrow()
    }
    let merged = ArrayList<String>()
    for (id in source.vs) {
        merged.add(id)
    }
    for (id in target.vs) {
        merged.add(id)
    }
    target.vs = merged
    target.barycenter = Some(sum / weight)
    target.weight = Some(weight)
    target.i = min(source.i, target.i)
    source.merged = true
}

func dagreExpandSubgraphs(entries: ArrayList<DagreSortEntry>, subgraphs: HashMap<String, DagreSortResult>): Unit {
    for (entry in entries) {
        let expanded = ArrayList<String>()
        for (id in entry.vs) {
            if (let Some(subgraph) <- subgraphs.get(id)) {
                for (subId in subgraph.vs) {
                    expanded.add(subId)
                }
            } else {
                expanded.add(id)
            }
        }
        entry.vs = expanded
    }
}

func dagreMergeBarycenters(target: DagreBarycenterEntry, other: DagreSortResult): Unit {
    if (target.barycenter.isSome()) {
        let targetWeight = target.weight.getOrThrow()
        let otherWeight = other.weight.getOrThrow()
        target.barycenter = Some((target.barycenter.getOrThrow() * targetWeight + other.barycenter.getOrThrow() * otherWeight) / (targetWeight + otherWeight))
        target.weight = Some(targetWeight + otherWeight)
    } else {
        target.barycenter = other.barycenter
        target.weight = other.weight
    }
}

func dagreSort(entries: ArrayList<DagreSortEntry>, biasRight: Bool): DagreSortResult {
    let sortable = ArrayList<DagreSortEntry>()
    let unsortable = ArrayList<DagreSortEntry>()
    for (entry in entries) {
        if (entry.barycenter.isSome()) {
            sortable.add(entry)
        } else {
            unsortable.add(entry)
        }
    }
    dagreSortEntriesByReverseIndex(unsortable)
    dagreSortEntriesByBarycenter(sortable, biasRight)

    let vs = ArrayList<String>()
    var sum = 0.0
    var weight = 0.0
    var vsIndex: Int64 = 0
    vsIndex = dagreConsumeUnsortable(vs, unsortable, vsIndex)
    for (entry in sortable) {
        vsIndex += entry.vs.size
        for (id in entry.vs) {
            vs.add(id)
        }
        sum += entry.barycenter.getOrThrow() * entry.weight.getOrThrow()
        weight += entry.weight.getOrThrow()
        vsIndex = dagreConsumeUnsortable(vs, unsortable, vsIndex)
    }
    if (weight != 0.0) {
        return DagreSortResult(vs, barycenter: Some(sum / weight), weight: Some(weight))
    }
    return DagreSortResult(vs)
}

func dagreConsumeUnsortable(vs: ArrayList<String>, unsortable: ArrayList<DagreSortEntry>, index: Int64): Int64 {
    var localIndex = index
    while (!unsortable.isEmpty() && unsortable[unsortable.size - 1].i <= localIndex) {
        let last = unsortable[unsortable.size - 1]
        unsortable.remove(at: unsortable.size - 1)
        for (id in last.vs) {
            vs.add(id)
        }
        localIndex++
    }
    return localIndex
}

func dagreAddSubgraphConstraints(graph: DagreLayoutGraph, constraintGraph: DagreLayoutGraph, vs: ArrayList<String>): Unit {
    let prev = HashMap<String, String>()
    var rootPrev: ?String = None
    for (v in vs) {
        var child = graph.parent(v)
        var stop = false
        while (child.isSome() && !stop) {
            let childValue = child.getOrThrow()
            let parent = graph.parent(childValue)
            var prevChild: ?String = None
            if (parent.isSome()) {
                let parentValue = parent.getOrThrow()
                prevChild = prev.get(parentValue)
                prev[parentValue] = childValue
            } else {
                prevChild = rootPrev
                rootPrev = Some(childValue)
            }
            if (prevChild.isSome() && prevChild.getOrThrow() != childValue) {
                constraintGraph.setEdge(prevChild.getOrThrow(), childValue)
                stop = true
            }
            child = parent
        }
    }
}

func dagreSortEntriesByReverseIndex(entries: ArrayList<DagreSortEntry>): Unit {
    var i = 1
    while (i < entries.size) {
        let value = entries[i]
        var j = i - 1
        while (j >= 0 && entries[j].i < value.i) {
            entries[j + 1] = entries[j]
            j--
        }
        entries[j + 1] = value
        i++
    }
}

func dagreSortEntriesByBarycenter(entries: ArrayList<DagreSortEntry>, biasRight: Bool): Unit {
    var i = 1
    while (i < entries.size) {
        let value = entries[i]
        var j = i - 1
        while (j >= 0 && dagreCompareSortEntry(entries[j], value, biasRight) > 0) {
            entries[j + 1] = entries[j]
            j--
        }
        entries[j + 1] = value
        i++
    }
}

func dagreCompareSortEntry(left: DagreSortEntry, right: DagreSortEntry, biasRight: Bool): Int64 {
    let leftBarycenter = left.barycenter.getOrThrow()
    let rightBarycenter = right.barycenter.getOrThrow()
    if (leftBarycenter < rightBarycenter) {
        return -1
    }
    if (leftBarycenter > rightBarycenter) {
        return 1
    }
    return if (!biasRight) { left.i - right.i } else { right.i - left.i }
}

func dagreCloneLayering(layering: Array<Array<String>>): Array<Array<String>> {
    return Array<Array<String>>(layering.size, { i =>
        Array<String>(layering[i].size, { j => layering[i][j] })
    })
}

func dagreCreateRootNode(graph: DagreLayoutGraph): String {
    var counter: Int64 = 0
    var id = "_root"
    while (graph.hasNode(id)) {
        counter++
        id = "_root" + counter.toString()
    }
    return id
}

func dagreTwoLayerCrossCount(graph: DagreLayoutGraph, northLayer: Array<String>, southLayer: Array<String>): Float64 {
    let southEntries = ArrayList<DagreOrderEntry>()
    for (north in northLayer) {
        let entries = ArrayList<DagreOrderEntry>()
        for (edge in graph.outEdges(north)) {
            let pos = dagreLayerIndex(southLayer, edge.end)
            if (pos >= 0) {
                entries.add(DagreOrderEntry(pos, graph.edge(edge).getOrThrow().weight))
            }
        }
        dagreSortOrderEntriesByPosition(entries)
        for (entry in entries) {
            southEntries.add(entry)
        }
    }

    var firstIndex: Int64 = 1
    while (firstIndex < southLayer.size) {
        firstIndex = firstIndex << 1
    }
    let treeSize = 2 * firstIndex - 1
    firstIndex--
    let tree = Array<Float64>(treeSize, repeat: 0.0)

    var count = 0.0
    for (entry in southEntries) {
        var index = entry.position + firstIndex
        tree[index] = tree[index] + entry.weight
        var weightSum = 0.0
        while (index > 0) {
            if (index % 2 == 1) {
                weightSum += tree[index + 1]
            }
            index = (index - 1) >> 1
            tree[index] = tree[index] + entry.weight
        }
        count += entry.weight * weightSum
    }
    return count
}

func dagreLayerIndex(layer: Array<String>, id: String): Int64 {
    for (i in 0..layer.size) {
        if (layer[i] == id) {
            return i
        }
    }
    return -1
}

func dagreSortOrderEntriesByPosition(entries: ArrayList<DagreOrderEntry>): Unit {
    var i = 1
    while (i < entries.size) {
        let value = entries[i]
        var j = i - 1
        while (j >= 0 && entries[j].position > value.position) {
            entries[j + 1] = entries[j]
            j--
        }
        entries[j + 1] = value
        i++
    }
}
