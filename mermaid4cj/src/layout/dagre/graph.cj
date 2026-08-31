package mermaid4cj.layout.dagre

import std.collection.ArrayList

public class DagrePoint {
    public let x: Float64
    public let y: Float64

    public init(x: Float64, y: Float64) {
        this.x = x
        this.y = y
    }
}

public class DagreNode {
    public let id: String
    public let x: ?Float64
    public let y: ?Float64
    public let width: ?Float64
    public let height: ?Float64
    public let clusterNode: Bool
    public let graph: ?MermaidDagreGraph
    public let dir: ?String
    public let explicitDir: Bool

    public init(
        id: String,
        x!: ?Float64 = None,
        y!: ?Float64 = None,
        width!: ?Float64 = None,
        height!: ?Float64 = None,
        clusterNode!: Bool = false,
        graph!: ?MermaidDagreGraph = None,
        dir!: ?String = None,
        explicitDir!: Bool = false
    ) {
        this.id = id
        this.x = x
        this.y = y
        this.width = width
        this.height = height
        this.clusterNode = clusterNode
        this.graph = graph
        this.dir = dir
        this.explicitDir = explicitDir
    }
}

public class DagreSelfLoop {
    public let id: String
    public let order: Int64

    public init(id: String, order: Int64) {
        this.id = id
        this.order = order
    }
}

public class DagreEdge {
    public let id: String
    public let start: String
    public let end: String
    public let label: ?String
    public let arrowTypeStart: ?String
    public let arrowTypeEnd: ?String
    public let length: Int64
    public let points: Array<DagrePoint>
    public let selfLoop: ?DagreSelfLoop
    public let originalEdge: ?DagreEdge
    public let x: ?Float64
    public let y: ?Float64
    public let width: ?Float64
    public let height: ?Float64
    public let labelStyle: ?String
    public let fromCluster: ?String
    public let toCluster: ?String

    public init(
        id: String,
        start: String,
        end: String,
        label!: ?String = None,
        arrowTypeStart!: ?String = None,
        arrowTypeEnd!: ?String = None,
        length!: Int64 = 1,
        points!: Array<DagrePoint> = [],
        selfLoop!: ?DagreSelfLoop = None,
        originalEdge!: ?DagreEdge = None,
        x!: ?Float64 = None,
        y!: ?Float64 = None,
        width!: ?Float64 = None,
        height!: ?Float64 = None,
        labelStyle!: ?String = None,
        fromCluster!: ?String = None,
        toCluster!: ?String = None
    ) {
        this.id = id
        this.start = start
        this.end = end
        this.label = label
        this.arrowTypeStart = arrowTypeStart
        this.arrowTypeEnd = arrowTypeEnd
        this.length = length
        this.points = points
        this.selfLoop = selfLoop
        this.originalEdge = originalEdge
        this.x = x
        this.y = y
        this.width = width
        this.height = height
        this.labelStyle = labelStyle
        this.fromCluster = fromCluster
        this.toCluster = toCluster
    }
}

public class DagreEdgeRef {
    public let edge: DagreEdge
    public let start: String
    public let end: String
    public let name: String

    public init(edge: DagreEdge, start: String, end: String, name: String) {
        this.edge = edge
        this.start = start
        this.end = end
        this.name = name
    }
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

    public init() {}

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
    let id: String
    let parentId: String

    init(id: String, parentId: String) {
        this.id = id
        this.parentId = parentId
    }
}
