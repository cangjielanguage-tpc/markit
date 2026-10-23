package mermaid4cj.layout.dagre

import std.collection.ArrayList

public class DagrePoint {

    public DagrePoint(public let x: Float64, public let y: Float64) {}
}

public class DagreNode {

    public DagreNode(
        public let id: String,
        public let x!: ?Float64 = None,
        public let y!: ?Float64 = None,
        public let width!: ?Float64 = None,
        public let height!: ?Float64 = None,
        public let clusterNode!: Bool = false,
        public let graph!: ?MermaidDagreGraph = None,
        public let dir!: ?String = None,
        public let explicitDir!: Bool = false
    ) {}
}

public class DagreSelfLoop {

    public DagreSelfLoop(public let id: String, public let order: Int64) {}
}

public class DagreEdge {

    public DagreEdge(
        public let id: String,
        public let start: String,
        public let end: String,
        public let label!: ?String = None,
        public let arrowTypeStart!: ?String = None,
        public let arrowTypeEnd!: ?String = None,
        public let length!: Int64 = 1,
        public let points!: Array<DagrePoint> = [],
        public let selfLoop!: ?DagreSelfLoop = None,
        public let originalEdge!: ?DagreEdge = None,
        public let x!: ?Float64 = None,
        public let y!: ?Float64 = None,
        public let width!: ?Float64 = None,
        public let height!: ?Float64 = None,
        public let labelStyle!: ?String = None,
        public let fromCluster!: ?String = None,
        public let toCluster!: ?String = None
    ) {}
}

public class DagreEdgeRef {

    public DagreEdgeRef(public let edge: DagreEdge, public let start: String, public let end: String, public let name: String) {}
}

public class MermaidDagreGraph {
    private let nodeList = ArrayList<DagreNode>()
    private let edgeList = ArrayList<DagreEdgeRef>()
    private let parentList = ArrayList<DagreParentRef>()
    private var graphRankdir: ?String = None
    private var graphNodesep: ?Float64 = None
    private var graphRanksep: ?Float64 = None
    private var graphMarginx: ?Float64 = None
    private var graphMarginy: ?Float64 = None

    public MermaidDagreGraph() {}

    public func setGraph(rankdir!: ?String = None, nodesep!: ?Float64 = None, ranksep!: ?Float64 = None, marginx!: ?Float64 = None, marginy!: ?Float64 = None): MermaidDagreGraph {
        graphRankdir = rankdir
        graphNodesep = nodesep
        graphRanksep = ranksep
        graphMarginx = marginx
        graphMarginy = marginy
        return this
    }

    public func rankdir(): ?String {
        return graphRankdir
    }

    public func nodesep(): ?Float64 {
        return graphNodesep
    }

    public func ranksep(): ?Float64 {
        return graphRanksep
    }

    public func marginx(): ?Float64 {
        return graphMarginx
    }

    public func marginy(): ?Float64 {
        return graphMarginy
    }

    public func setNode(id: String, node: DagreNode): Unit {
        for (i in 0..nodeList.size) {
            if (nodeList[i].id == id) {
                nodeList[i] = node
                return
            }
        }
        nodeList.add(node)
    }

    public func removeNode(id: String): Unit {
        var nodeIndex = nodeList.size - 1
        while (nodeIndex >= 0) {
            if (nodeList[nodeIndex].id == id) {
                nodeList.remove(at: nodeIndex)
            }
            nodeIndex--
        }
        clearParent(id)
        var parentIndex = parentList.size - 1
        while (parentIndex >= 0) {
            if (parentList[parentIndex].parentId == id) {
                parentList.remove(at: parentIndex)
            }
            parentIndex--
        }
        var edgeIndex = edgeList.size - 1
        while (edgeIndex >= 0) {
            let edge = edgeList[edgeIndex]
            if (edge.start == id || edge.end == id) {
                edgeList.remove(at: edgeIndex)
            }
            edgeIndex--
        }
    }

    private func ensureNode(id: String): Unit {
        if (node(id).isNone()) {
            setNode(id, DagreNode(id))
        }
    }

    public func node(id: String): ?DagreNode {
        for (node in nodeList) {
            if (node.id == id) {
                return Some(node)
            }
        }
        return None
    }

    public func hasNode(id: String): Bool {
        return node(id).isSome()
    }

    public func nodes(): Array<String> {
        return Array<String>(nodeList.size, { i => nodeList[i].id })
    }

    public func setParent(id: String, parentId: String): Unit {
        ensureNode(parentId)
        ensureNode(id)
        for (i in 0..parentList.size) {
            if (parentList[i].id == id) {
                parentList[i] = DagreParentRef(id, parentId)
                return
            }
        }
        parentList.add(DagreParentRef(id, parentId))
    }

    public func parent(id: String): ?String {
        for (item in parentList) {
            if (item.id == id) {
                return Some(item.parentId)
            }
        }
        return None
    }

    public func clearParent(id: String): Unit {
        var index = parentList.size - 1
        while (index >= 0) {
            if (parentList[index].id == id) {
                parentList.remove(at: index)
            }
            index--
        }
    }

    public func children(): Array<String> {
        let out = ArrayList<String>()
        for (node in nodeList) {
            if (parent(node.id).isNone()) {
                out.add(node.id)
            }
        }
        return out.toArray()
    }

    public func children(id: String): Array<String> {
        let out = ArrayList<String>()
        for (item in parentList) {
            if (item.parentId == id) {
                out.add(item.id)
            }
        }
        return out.toArray()
    }

    public func setEdge(start: String, end: String, edge: DagreEdge, name: String): Unit {
        ensureNode(start)
        ensureNode(end)
        for (i in 0..edgeList.size) {
            if (edgeList[i].start == start && edgeList[i].end == end && edgeList[i].name == name) {
                edgeList[i] = DagreEdgeRef(edge, start, end, name)
                return
            }
        }
        edgeList.add(DagreEdgeRef(edge, start, end, name))
    }

    public func edge(start: String, end: String, name: String): ?DagreEdge {
        for (item in edgeList) {
            if (item.start == start && item.end == end && item.name == name) {
                return Some(item.edge)
            }
        }
        return None
    }

    public func removeEdge(start: String, end: String, name: String): Unit {
        var index = edgeList.size - 1
        while (index >= 0) {
            let item = edgeList[index]
            if (item.start == start && item.end == end && item.name == name) {
                edgeList.remove(at: index)
            }
            index--
        }
    }

    public func edges(): Array<DagreEdgeRef> {
        return edgeList.toArray()
    }

    public func hasEdge(start: String, end: String, name: String): Bool {
        return edge(start, end, name).isSome()
    }

    public func predecessors(id: String): Array<String> {
        let out = ArrayList<String>()
        for (edge in edgeList) {
            if (edge.end == id && !containsGraphString(out, edge.start)) {
                out.add(edge.start)
            }
        }
        return out.toArray()
    }

    public func successors(id: String): Array<String> {
        let out = ArrayList<String>()
        for (edge in edgeList) {
            if (edge.start == id && !containsGraphString(out, edge.end)) {
                out.add(edge.end)
            }
        }
        return out.toArray()
    }

    public func neighbors(id: String): Array<String> {
        let out = ArrayList<String>()
        for (value in predecessors(id)) {
            if (!containsGraphString(out, value)) {
                out.add(value)
            }
        }
        for (value in successors(id)) {
            if (!containsGraphString(out, value)) {
                out.add(value)
            }
        }
        return out.toArray()
    }

    public func inEdges(id: String): Array<DagreEdgeRef> {
        let out = ArrayList<DagreEdgeRef>()
        for (edge in edgeList) {
            if (edge.end == id) {
                out.add(edge)
            }
        }
        return out.toArray()
    }

    public func outEdges(id: String): Array<DagreEdgeRef> {
        let out = ArrayList<DagreEdgeRef>()
        for (edge in edgeList) {
            if (edge.start == id) {
                out.add(edge)
            }
        }
        return out.toArray()
    }

    public func nodeEdges(id: String): Array<DagreEdgeRef> {
        let out = ArrayList<DagreEdgeRef>()
        for (edge in edgeList) {
            if (edge.start == id || edge.end == id) {
                out.add(edge)
            }
        }
        return out.toArray()
    }

    public func sources(): Array<String> {
        let out = ArrayList<String>()
        for (node in nodeList) {
            if (inEdges(node.id).isEmpty()) {
                out.add(node.id)
            }
        }
        return out.toArray()
    }

    public func sinks(): Array<String> {
        let out = ArrayList<String>()
        for (node in nodeList) {
            if (outEdges(node.id).isEmpty()) {
                out.add(node.id)
            }
        }
        return out.toArray()
    }
}

func containsGraphString(values: ArrayList<String>, value: String): Bool {
    for (item in values) {
        if (item == value) {
            return true
        }
    }
    return false
}

class DagreParentRef {

    DagreParentRef(let id: String, let parentId: String) {}
}
