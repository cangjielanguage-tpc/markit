package mermaid4cj.layout.dagre

import std.collection.ArrayList

public class DagreGraphLabel {
    public var rankdir: String
    public var align: ?String
    public var acyclicer: ?String
    public var ranker: ?String
    public var nodesep: Float64
    public var edgesep: Float64
    public var ranksep: Float64
    public var marginx: Float64
    public var marginy: Float64
    public var width: Float64
    public var height: Float64
    public var maxRank: Int64
    public var nodeRankFactor: Int64
    public var nestingRoot: ?String
    public var dummyChains: ArrayList<String>

    public init(
        rankdir!: String = "tb",
        align!: ?String = None,
        acyclicer!: ?String = None,
        ranker!: ?String = None,
        nodesep!: Float64 = 50.0,
        edgesep!: Float64 = 20.0,
        ranksep!: Float64 = 50.0,
        marginx!: Float64 = 0.0,
        marginy!: Float64 = 0.0
    ) {
        this.rankdir = rankdir
        this.align = align
        this.acyclicer = acyclicer
        this.ranker = ranker
        this.nodesep = nodesep
        this.edgesep = edgesep
        this.ranksep = ranksep
        this.marginx = marginx
        this.marginy = marginy
        this.width = 0.0
        this.height = 0.0
        this.maxRank = 0
        this.nodeRankFactor = 1
        this.nestingRoot = None
        this.dummyChains = ArrayList<String>()
    }
}

public class DagreLayoutNode {
    public let id: String
    public var x: Float64
    public var y: Float64
    public var width: Float64
    public var height: Float64
    public var rank: ?Int64
    public var order: ?Int64
    public var low: ?Int64
    public var lim: ?Int64
    public var parent: ?String
    public var dummy: ?String
    public var edgeObj: ?DagreLayoutEdgeKey
    public var edgeLabel: ?DagreLayoutEdge
    public var labelpos: ?String
    public var borderTop: ?String
    public var borderBottom: ?String
    public var borderLeft: ArrayList<String>
    public var borderRight: ArrayList<String>
    public var borderType: ?String
    public var minRank: ?Int64
    public var maxRank: ?Int64
    public var selfEdges: ArrayList<DagreSelfEdge>

    public init(
        id: String,
        x!: Float64 = 0.0,
        y!: Float64 = 0.0,
        width!: Float64 = 0.0,
        height!: Float64 = 0.0
    ) {
        this.id = id
        this.x = x
        this.y = y
        this.width = width
        this.height = height
        this.rank = None
        this.order = None
        this.low = None
        this.lim = None
        this.parent = None
        this.dummy = None
        this.edgeObj = None
        this.edgeLabel = None
        this.labelpos = None
        this.borderTop = None
        this.borderBottom = None
        this.borderLeft = ArrayList<String>()
        this.borderRight = ArrayList<String>()
        this.borderType = None
        this.minRank = None
        this.maxRank = None
        this.selfEdges = ArrayList<DagreSelfEdge>()
    }

    public func copy(): DagreLayoutNode {
        let out = DagreLayoutNode(id, x: x, y: y, width: width, height: height)
        copyInto(out)
        return out
    }

    public func copyWithId(newId: String): DagreLayoutNode {
        let out = DagreLayoutNode(newId, x: x, y: y, width: width, height: height)
        copyInto(out)
        return out
    }

    func copyInto(out: DagreLayoutNode): Unit {
        out.rank = rank
        out.order = order
        out.low = low
        out.lim = lim
        out.parent = parent
        out.dummy = dummy
        out.edgeObj = edgeObj
        out.edgeLabel = edgeLabel
        out.labelpos = labelpos
        out.borderTop = borderTop
        out.borderBottom = borderBottom
        for (value in borderLeft) {
            out.borderLeft.add(value)
        }
        for (value in borderRight) {
            out.borderRight.add(value)
        }
        out.borderType = borderType
        out.minRank = minRank
        out.maxRank = maxRank
        for (value in selfEdges) {
            out.selfEdges.add(value)
        }
    }
}

public class DagreLayoutEdge {
    public var id: String
    public var minlen: Int64
    public var weight: Float64
    public var width: Float64
    public var height: Float64
    public var labeloffset: Float64
    public var labelpos: String
    public var labelRank: ?Int64
    public var points: ArrayList<DagrePoint>
    public var x: ?Float64
    public var y: ?Float64
    public var reversed: Bool
    public var forwardName: ?String
    public var cutvalue: ?Float64
    public var nestingEdge: Bool

    public init(
        id: String,
        minlen!: Int64 = 1,
        weight!: Float64 = 1.0,
        width!: Float64 = 0.0,
        height!: Float64 = 0.0,
        labeloffset!: Float64 = 10.0,
        labelpos!: String = "r"
    ) {
        this.id = id
        this.minlen = minlen
        this.weight = weight
        this.width = width
        this.height = height
        this.labeloffset = labeloffset
        this.labelpos = labelpos
        this.labelRank = None
        this.points = ArrayList<DagrePoint>()
        this.x = None
        this.y = None
        this.reversed = false
        this.forwardName = None
        this.cutvalue = None
        this.nestingEdge = false
    }

    public func copy(): DagreLayoutEdge {
        let out = DagreLayoutEdge(id, minlen: minlen, weight: weight, width: width, height: height, labeloffset: labeloffset, labelpos: labelpos)
        out.labelRank = labelRank
        for (point in points) {
            out.points.add(DagrePoint(point.x, point.y))
        }
        out.x = x
        out.y = y
        out.reversed = reversed
        out.forwardName = forwardName
        out.cutvalue = cutvalue
        out.nestingEdge = nestingEdge
        return out
    }
}

public class DagreLayoutEdgeKey {
    public let start: String
    public let end: String
    public let name: String

    public init(start: String, end: String, name: String) {
        this.start = start
        this.end = end
        this.name = name
    }
}

public class DagreSelfEdge {
    public let key: DagreLayoutEdgeKey
    public let label: DagreLayoutEdge

    public init(key: DagreLayoutEdgeKey, label: DagreLayoutEdge) {
        this.key = key
        this.label = label
    }
}

class DagreLayoutParentRef {
    let id: String
    let parentId: String

    init(id: String, parentId: String) {
        this.id = id
        this.parentId = parentId
    }
}

class DagreLayoutEdgeRef {
    let key: DagreLayoutEdgeKey
    var edge: DagreLayoutEdge

    init(key: DagreLayoutEdgeKey, edge: DagreLayoutEdge) {
        this.key = key
        this.edge = edge
    }
}

public class DagreLayoutGraph {
    public var graphLabel: DagreGraphLabel
    private let nodeList = ArrayList<DagreLayoutNode>()
    private let edgeList = ArrayList<DagreLayoutEdgeRef>()
    private let parentList = ArrayList<DagreLayoutParentRef>()
    private var dummyCount: Int64 = 0

    public init(label!: DagreGraphLabel = DagreGraphLabel()) {
        this.graphLabel = label
    }

    public func setNode(id: String, node!: DagreLayoutNode = DagreLayoutNode("")): Unit {
        let value = if (node.id.isEmpty()) { DagreLayoutNode(id) } else { node }
        for (i in 0..nodeList.size) {
            if (nodeList[i].id == id) {
                nodeList[i] = value
                return
            }
        }
        nodeList.add(value)
    }

    public func node(id: String): ?DagreLayoutNode {
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

    public func removeNode(id: String): Unit {
        var i = nodeList.size - 1
        while (i >= 0) {
            if (nodeList[i].id == id) {
                nodeList.remove(at: i)
            }
            i--
        }
        clearParent(id)
        var p = parentList.size - 1
        while (p >= 0) {
            if (parentList[p].parentId == id) {
                parentList.remove(at: p)
            }
            p--
        }
        var e = edgeList.size - 1
        while (e >= 0) {
            let key = edgeList[e].key
            if (key.start == id || key.end == id) {
                edgeList.remove(at: e)
            }
            e--
        }
    }

    public func setEdge(start: String, end: String, edge!: DagreLayoutEdge = DagreLayoutEdge(""), name!: String = ""): Unit {
        if (!hasNode(start)) {
            setNode(start)
        }
        if (!hasNode(end)) {
            setNode(end)
        }
        let edgeName = if (name.isEmpty()) { start + "->" + end } else { name }
        let value = if (edge.id.isEmpty()) { DagreLayoutEdge(edgeName) } else { edge }
        for (i in 0..edgeList.size) {
            let key = edgeList[i].key
            if (key.start == start && key.end == end && key.name == edgeName) {
                edgeList[i].edge = value
                return
            }
        }
        edgeList.add(DagreLayoutEdgeRef(DagreLayoutEdgeKey(start, end, edgeName), value))
    }

    public func edge(key: DagreLayoutEdgeKey): ?DagreLayoutEdge {
        return edge(key.start, key.end, name: key.name)
    }

    public func edge(start: String, end: String, name!: String = ""): ?DagreLayoutEdge {
        let edgeName = if (name.isEmpty()) { start + "->" + end } else { name }
        for (item in edgeList) {
            let key = item.key
            if (key.start == start && key.end == end && key.name == edgeName) {
                return Some(item.edge)
            }
        }
        return None
    }

    public func hasEdge(start: String, end: String, name!: String = ""): Bool {
        return edge(start, end, name: name).isSome()
    }

    public func removeEdge(key: DagreLayoutEdgeKey): Unit {
        removeEdge(key.start, key.end, name: key.name)
    }

    public func removeEdge(start: String, end: String, name!: String = ""): Unit {
        let edgeName = if (name.isEmpty()) { start + "->" + end } else { name }
        var i = edgeList.size - 1
        while (i >= 0) {
            let key = edgeList[i].key
            if (key.start == start && key.end == end && key.name == edgeName) {
                edgeList.remove(at: i)
            }
            i--
        }
    }

    public func edges(): Array<DagreLayoutEdgeKey> {
        return Array<DagreLayoutEdgeKey>(edgeList.size, { i => edgeList[i].key })
    }

    public func setParent(id: String, parentId: String): Unit {
        if (!hasNode(parentId)) {
            setNode(parentId)
        }
        if (!hasNode(id)) {
            setNode(id)
        }
        for (i in 0..parentList.size) {
            if (parentList[i].id == id) {
                parentList[i] = DagreLayoutParentRef(id, parentId)
                return
            }
        }
        parentList.add(DagreLayoutParentRef(id, parentId))
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
        var i = parentList.size - 1
        while (i >= 0) {
            if (parentList[i].id == id) {
                parentList.remove(at: i)
            }
            i--
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

    public func predecessors(id: String): Array<String> {
        let out = ArrayList<String>()
        for (item in edgeList) {
            if (item.key.end == id && !containsCoreString(out, item.key.start)) {
                out.add(item.key.start)
            }
        }
        return out.toArray()
    }

    public func successors(id: String): Array<String> {
        let out = ArrayList<String>()
        for (item in edgeList) {
            if (item.key.start == id && !containsCoreString(out, item.key.end)) {
                out.add(item.key.end)
            }
        }
        return out.toArray()
    }

    public func neighbors(id: String): Array<String> {
        let out = ArrayList<String>()
        for (value in predecessors(id)) {
            if (!containsCoreString(out, value)) {
                out.add(value)
            }
        }
        for (value in successors(id)) {
            if (!containsCoreString(out, value)) {
                out.add(value)
            }
        }
        return out.toArray()
    }

    public func inEdges(id: String): Array<DagreLayoutEdgeKey> {
        let out = ArrayList<DagreLayoutEdgeKey>()
        for (item in edgeList) {
            if (item.key.end == id) {
                out.add(item.key)
            }
        }
        return out.toArray()
    }

    public func outEdges(id: String): Array<DagreLayoutEdgeKey> {
        let out = ArrayList<DagreLayoutEdgeKey>()
        for (item in edgeList) {
            if (item.key.start == id) {
                out.add(item.key)
            }
        }
        return out.toArray()
    }

    public func nodeEdges(id: String): Array<DagreLayoutEdgeKey> {
        let out = ArrayList<DagreLayoutEdgeKey>()
        for (item in edgeList) {
            if (item.key.start == id || item.key.end == id) {
                out.add(item.key)
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

    public func addDummyNode(dummyType: String, attrs: DagreLayoutNode, prefix: String): String {
        var id = ""
        while (id.isEmpty() || hasNode(id)) {
            dummyCount++
            id = prefix + dummyCount.toString()
        }
        attrs.dummy = Some(dummyType)
        let node = if (attrs.id.isEmpty()) { attrs.copyWithId(id) } else { attrs }
        setNode(id, node: node)
        return id
    }

    public func copy(includeCompound!: Bool = true): DagreLayoutGraph {
        let out = DagreLayoutGraph(label: graphLabel)
        for (id in nodes()) {
            out.setNode(id, node: node(id).getOrThrow().copy())
        }
        if (includeCompound) {
            for (id in nodes()) {
                if (let Some(parentId) <- parent(id)) {
                    out.setParent(id, parentId)
                }
            }
        }
        for (key in edges()) {
            out.setEdge(key.start, key.end, edge: edge(key).getOrThrow().copy(), name: key.name)
        }
        return out
    }
}

func containsCoreString(values: ArrayList<String>, value: String): Bool {
    for (item in values) {
        if (item == value) {
            return true
        }
    }
    return false
}
