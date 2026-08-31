package mermaid4cj.layout.dagre

import std.collection.{ArrayList, HashMap}

public func dagreAcyclicRun(graph: DagreLayoutGraph): Unit {
    let feedbackEdges = if ((graph.graphLabel.acyclicer ?? "") == "greedy") {
        dagreGreedyFas(graph)
    } else {
        dagreDfsFas(graph)
    }
    var reverseIndex: Int64 = 0
    for (key in feedbackEdges) {
        if (!graph.hasEdge(key.start, key.end, name: key.name)) {
            continue
        }
        let label = graph.edge(key).getOrThrow()
        graph.removeEdge(key)
        label.forwardName = Some(key.name)
        label.reversed = true
        var reverseName = "rev" + reverseIndex.toString()
        while (graph.hasEdge(key.end, key.start, name: reverseName)) {
            reverseIndex++
            reverseName = "rev" + reverseIndex.toString()
        }
        graph.setEdge(key.end, key.start, edge: label, name: reverseName)
        reverseIndex++
    }
}

public func dagreAcyclicUndo(graph: DagreLayoutGraph): Unit {
    let keys = graph.edges()
    for (key in keys) {
        if (!graph.hasEdge(key.start, key.end, name: key.name)) {
            continue
        }
        let label = graph.edge(key).getOrThrow()
        if (label.reversed) {
            let forwardName = label.forwardName ?? (key.end + "->" + key.start)
            graph.removeEdge(key)
            label.reversed = false
            label.forwardName = None
            graph.setEdge(key.end, key.start, edge: label, name: forwardName)
        }
    }
}

func dagreDfsFas(graph: DagreLayoutGraph): ArrayList<DagreLayoutEdgeKey> {
    let fas = ArrayList<DagreLayoutEdgeKey>()
    let stack = HashMap<String, Bool>()
    let visited = HashMap<String, Bool>()
    for (id in graph.nodes()) {
        dagreDfsFasVisit(graph, id, fas, stack, visited)
    }
    return fas
}

func dagreDfsFasVisit(
    graph: DagreLayoutGraph,
    id: String,
    fas: ArrayList<DagreLayoutEdgeKey>,
    stack: HashMap<String, Bool>,
    visited: HashMap<String, Bool>
): Unit {
    if (visited.get(id) ?? false) {
        return
    }
    visited[id] = true
    stack[id] = true
    for (edge in graph.outEdges(id)) {
        if (stack.get(edge.end) ?? false) {
            fas.add(edge)
        } else {
            dagreDfsFasVisit(graph, edge.end, fas, stack, visited)
        }
    }
    stack[id] = false
}

class DagreGreedyEntry {
    let v: String
    var inWeight: Float64
    var outWeight: Float64
    var bucketIndex: ?Int64
    var active: Bool

    init(v: String) {
        this.v = v
        this.inWeight = 0.0
        this.outWeight = 0.0
        this.bucketIndex = None
        this.active = true
    }
}

class DagreGreedyEdge {
    let start: String
    let end: String
    var weight: Float64
    var active: Bool

    init(start: String, end: String, weight: Float64) {
        this.start = start
        this.end = end
        this.weight = weight
        this.active = true
    }
}

func dagreGreedyFas(graph: DagreLayoutGraph): ArrayList<DagreLayoutEdgeKey> {
    let out = ArrayList<DagreLayoutEdgeKey>()
    if (graph.nodes().size <= 1) {
        return out
    }
    let entries = HashMap<String, DagreGreedyEntry>()
    let edges = ArrayList<DagreGreedyEdge>()
    var maxIn = 0.0
    var maxOut = 0.0

    for (id in graph.nodes()) {
        entries[id] = DagreGreedyEntry(id)
    }
    for (key in graph.edges()) {
        let weight = graph.edge(key).getOrThrow().weight
        let existing = dagreFindGreedyEdge(edges, key.start, key.end)
        if (let Some(edge) <- existing) {
            edge.weight += weight
        } else {
            edges.add(DagreGreedyEdge(key.start, key.end, weight))
        }
        let startEntry = entries.get(key.start).getOrThrow()
        let endEntry = entries.get(key.end).getOrThrow()
        startEntry.outWeight += weight
        endEntry.inWeight += weight
        maxOut = max(maxOut, startEntry.outWeight)
        maxIn = max(maxIn, endEntry.inWeight)
    }

    let zeroIdx = dagreBucketIndexCeil(maxIn) + 1
    let bucketCount = dagreBucketIndexCeil(maxOut + maxIn) + 3
    let buckets = Array<ArrayList<DagreGreedyEntry>>(bucketCount, { _ => ArrayList<DagreGreedyEntry>() })
    for (id in graph.nodes()) {
        dagreAssignGreedyBucket(buckets, zeroIdx, entries.get(id).getOrThrow())
    }

    var activeCount = graph.nodes().size
    while (activeCount > 0) {
        var removed = true
        while (removed) {
            let entry = dagreDequeueGreedyBucket(buckets[0])
            if (let Some(value) <- entry) {
                if (value.active) {
                    dagreRemoveGreedyNode(graph, edges, entries, buckets, zeroIdx, value, false, out)
                    activeCount--
                }
            } else {
                removed = false
            }
        }

        removed = true
        while (removed) {
            let entry = dagreDequeueGreedyBucket(buckets[buckets.size - 1])
            if (let Some(value) <- entry) {
                if (value.active) {
                    dagreRemoveGreedyNode(graph, edges, entries, buckets, zeroIdx, value, false, out)
                    activeCount--
                }
            } else {
                removed = false
            }
        }

        if (activeCount > 0) {
            var i = buckets.size - 2
            var found = false
            while (i > 0 && !found) {
                let entry = dagreDequeueGreedyBucket(buckets[i])
                if (let Some(value) <- entry) {
                    if (value.active) {
                        dagreRemoveGreedyNode(graph, edges, entries, buckets, zeroIdx, value, true, out)
                        activeCount--
                        found = true
                    }
                }
                if (!found) {
                    i--
                }
            }
        }
    }
    return out
}

func dagreRemoveGreedyNode(
    graph: DagreLayoutGraph,
    edges: ArrayList<DagreGreedyEdge>,
    entries: HashMap<String, DagreGreedyEntry>,
    buckets: Array<ArrayList<DagreGreedyEntry>>,
    zeroIdx: Int64,
    entry: DagreGreedyEntry,
    collectPredecessors: Bool,
    results: ArrayList<DagreLayoutEdgeKey>
): Unit {
    for (edge in edges) {
        if (!edge.active) {
            continue
        }
        if (edge.end == entry.v) {
            let uEntry = entries.get(edge.start).getOrThrow()
            if (collectPredecessors) {
                for (original in graph.outEdges(edge.start)) {
                    if (original.end == edge.end) {
                        results.add(original)
                    }
                }
            }
            uEntry.outWeight -= edge.weight
            edge.active = false
            dagreAssignGreedyBucket(buckets, zeroIdx, uEntry)
        }
    }
    for (edge in edges) {
        if (!edge.active) {
            continue
        }
        if (edge.start == entry.v) {
            let wEntry = entries.get(edge.end).getOrThrow()
            wEntry.inWeight -= edge.weight
            edge.active = false
            dagreAssignGreedyBucket(buckets, zeroIdx, wEntry)
        }
    }
    entry.active = false
}

func dagreAssignGreedyBucket(buckets: Array<ArrayList<DagreGreedyEntry>>, zeroIdx: Int64, entry: DagreGreedyEntry): Unit {
    if (!entry.active) {
        return
    }
    if (let Some(index) <- entry.bucketIndex) {
        dagreRemoveGreedyEntryFromBucket(buckets[index], entry.v)
    }
    let index = if (entry.outWeight == 0.0) {
        0
    } else if (entry.inWeight == 0.0) {
        buckets.size - 1
    } else {
        dagreClampBucketIndex(dagreBucketIndexRound(entry.outWeight - entry.inWeight) + zeroIdx, buckets.size)
    }
    entry.bucketIndex = Some(index)
    buckets[index].add(entry)
}

func dagreDequeueGreedyBucket(bucket: ArrayList<DagreGreedyEntry>): ?DagreGreedyEntry {
    while (!bucket.isEmpty()) {
        let index = bucket.size - 1
        let value = bucket[index]
        bucket.remove(at: index)
        value.bucketIndex = None
        if (value.active) {
            return Some(value)
        }
    }
    return None
}

func dagreRemoveGreedyEntryFromBucket(bucket: ArrayList<DagreGreedyEntry>, id: String): Unit {
    var i = bucket.size - 1
    while (i >= 0) {
        if (bucket[i].v == id) {
            bucket.remove(at: i)
            return
        }
        i--
    }
}

func dagreFindGreedyEdge(edges: ArrayList<DagreGreedyEdge>, start: String, end: String): ?DagreGreedyEdge {
    for (edge in edges) {
        if (edge.start == start && edge.end == end) {
            return Some(edge)
        }
    }
    return None
}

func dagreBucketIndexRound(value: Float64): Int64 {
    if (value >= 0.0) {
        return Int64(value + 0.5)
    }
    return Int64(value - 0.5)
}

func dagreBucketIndexCeil(value: Float64): Int64 {
    let base = Int64(value)
    if (Float64(base) < value) {
        return base + 1
    }
    return base
}

func dagreClampBucketIndex(index: Int64, size: Int64): Int64 {
    if (index < 0) {
        return 0
    }
    if (index >= size) {
        return size - 1
    }
    return index
}
