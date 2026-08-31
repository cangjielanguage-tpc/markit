package mermaid4cj.layout.dagre

import std.collection.{ArrayList, HashMap}

public func dagreAdjustCoordinateSystem(graph: DagreLayoutGraph): Unit {
    let rankdir = dagreAsciiLower(graph.graphLabel.rankdir)
    if (rankdir == "lr" || rankdir == "rl") {
        dagreSwapWidthHeight(graph)
    }
}

public func dagreUndoCoordinateSystem(graph: DagreLayoutGraph): Unit {
    let rankdir = dagreAsciiLower(graph.graphLabel.rankdir)
    if (rankdir == "bt" || rankdir == "rl") {
        dagreReverseY(graph)
    }
    if (rankdir == "lr" || rankdir == "rl") {
        dagreSwapXY(graph)
        dagreSwapWidthHeight(graph)
    }
}

public func dagrePosition(graph: DagreLayoutGraph): Unit {
    let simple = dagreAsNonCompoundGraph(graph)
    dagrePositionY(simple)
    let xs = dagrePositionX(simple)
    for (id in xs.keys()) {
        if (let Some(node) <- simple.node(id)) {
            node.x = xs.get(id).getOrThrow()
        }
    }
}

public func dagrePositionSelfEdges(graph: DagreLayoutGraph): Unit {
    let nodes = graph.nodes()
    for (id in nodes) {
        if (!graph.hasNode(id)) {
            continue
        }
        let node = graph.node(id).getOrThrow()
        if ((node.dummy ?? "") == "selfedge") {
            let edgeObj = node.edgeObj.getOrThrow()
            let label = node.edgeLabel.getOrThrow()
            let selfNode = graph.node(edgeObj.start).getOrThrow()
            let x = selfNode.x + selfNode.width / 2.0
            let y = selfNode.y
            let dx = node.x - x
            let dy = selfNode.height / 2.0
            graph.setEdge(edgeObj.start, edgeObj.end, edge: label, name: edgeObj.name)
            graph.removeNode(id)
            label.points = ArrayList<DagrePoint>()
            label.points.add(DagrePoint(x + (2.0 * dx) / 3.0, y - dy))
            label.points.add(DagrePoint(x + (5.0 * dx) / 6.0, y - dy))
            label.points.add(DagrePoint(x + dx, y))
            label.points.add(DagrePoint(x + (5.0 * dx) / 6.0, y + dy))
            label.points.add(DagrePoint(x + (2.0 * dx) / 3.0, y + dy))
            label.x = Some(node.x)
            label.y = Some(node.y)
        }
    }
}

public func dagreTranslateGraph(graph: DagreLayoutGraph): Unit {
    var found = false
    var minX = 0.0
    var maxX = 0.0
    var minY = 0.0
    var maxY = 0.0
    let marginX = graph.graphLabel.marginx
    let marginY = graph.graphLabel.marginy

    for (id in graph.nodes()) {
        let node = graph.node(id).getOrThrow()
        let left = node.x - node.width / 2.0
        let right = node.x + node.width / 2.0
        let top = node.y - node.height / 2.0
        let bottom = node.y + node.height / 2.0
        if (!found) {
            minX = left
            maxX = right
            minY = top
            maxY = bottom
            found = true
        } else {
            minX = min(minX, left)
            maxX = max(maxX, right)
            minY = min(minY, top)
            maxY = max(maxY, bottom)
        }
    }
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        for (point in edge.points) {
            if (!found) {
                minX = point.x
                maxX = point.x
                minY = point.y
                maxY = point.y
                found = true
            } else {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }
        if (let Some(x) <- edge.x) {
            let y = edge.y ?? 0.0
            let left = x - edge.width / 2.0
            let right = x + edge.width / 2.0
            let top = y - edge.height / 2.0
            let bottom = y + edge.height / 2.0
            if (!found) {
                minX = left
                maxX = right
                minY = top
                maxY = bottom
                found = true
            } else {
                minX = min(minX, left)
                maxX = max(maxX, right)
                minY = min(minY, top)
                maxY = max(maxY, bottom)
            }
        }
    }

    if (!found) {
        graph.graphLabel.width = marginX * 2.0
        graph.graphLabel.height = marginY * 2.0
        return
    }

    let deltaX = marginX - minX
    let deltaY = marginY - minY
    for (id in graph.nodes()) {
        let node = graph.node(id).getOrThrow()
        node.x += deltaX
        node.y += deltaY
    }
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        for (i in 0..edge.points.size) {
            let point = edge.points[i]
            edge.points[i] = DagrePoint(point.x + deltaX, point.y + deltaY)
        }
        if (let Some(x) <- edge.x) {
            edge.x = Some(x + deltaX)
        }
        if (let Some(y) <- edge.y) {
            edge.y = Some(y + deltaY)
        }
    }
    graph.graphLabel.width = maxX - minX + marginX
    graph.graphLabel.height = maxY - minY + marginY
}

public func dagreAssignNodeIntersects(graph: DagreLayoutGraph): Unit {
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        let nodeV = graph.node(key.start).getOrThrow()
        let nodeW = graph.node(key.end).getOrThrow()
        let p1 = if (edge.points.isEmpty()) {
            DagrePoint(nodeW.x, nodeW.y)
        } else {
            edge.points[0]
        }
        let p2 = if (edge.points.isEmpty()) {
            DagrePoint(nodeV.x, nodeV.y)
        } else {
            edge.points[edge.points.size - 1]
        }
        let points = ArrayList<DagrePoint>()
        points.add(dagreIntersectRectNode(nodeV, p1))
        for (point in edge.points) {
            points.add(point)
        }
        points.add(dagreIntersectRectNode(nodeW, p2))
        edge.points = points
    }
}

public func dagreFixupEdgeLabelCoords(graph: DagreLayoutGraph): Unit {
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        if (edge.x.isSome()) {
            if (edge.labelpos == "l" || edge.labelpos == "r") {
                edge.width -= edge.labeloffset
            }
            match (edge.labelpos) {
                case "l" =>
                    edge.x = Some(edge.x.getOrThrow() - edge.width / 2.0 - edge.labeloffset)
                case "r" =>
                    edge.x = Some(edge.x.getOrThrow() + edge.width / 2.0 + edge.labeloffset)
                case _ => ()
            }
        }
    }
}

public func dagreReversePointsForReversedEdges(graph: DagreLayoutGraph): Unit {
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        if (edge.reversed) {
            let reversed = ArrayList<DagrePoint>()
            var index = edge.points.size - 1
            while (index >= 0) {
                reversed.add(edge.points[index])
                index--
            }
            edge.points = reversed
        }
    }
}

func dagrePositionY(graph: DagreLayoutGraph): Unit {
    let layering = dagreBuildLayerMatrix(graph)
    var previousY = 0.0
    for (layer in layering) {
        var maxHeight = 0.0
        for (id in layer) {
            maxHeight = max(maxHeight, graph.node(id).getOrThrow().height)
        }
        for (id in layer) {
            graph.node(id).getOrThrow().y = previousY + maxHeight / 2.0
        }
        previousY += maxHeight + graph.graphLabel.ranksep
    }
}

public func dagrePositionX(graph: DagreLayoutGraph): HashMap<String, Float64> {
    let layering = dagreBuildLayerMatrix(graph)
    let conflicts = dagreFindType1Conflicts(graph, layering)
    dagreMergeConflicts(conflicts, dagreFindType2Conflicts(graph, layering))
    let xss = HashMap<String, HashMap<String, Float64>>()

    for (vert in ["u", "d"]) {
        var adjustedLayering = if (vert == "u") { layering } else { dagreReverseLayers(layering) }
        for (horiz in ["l", "r"]) {
            if (horiz == "r") {
                adjustedLayering = dagreReverseLayerEntries(adjustedLayering)
            }
            let align = dagreVerticalAlignment(graph, adjustedLayering, conflicts, vert == "u")
            var xs = dagreHorizontalCompaction(graph, adjustedLayering, align.root, align.align, horiz == "r")
            if (horiz == "r") {
                for (id in xs.keys()) {
                    xs[id] = -xs.get(id).getOrThrow()
                }
            }
            xss[vert + horiz] = xs
        }
    }

    let smallest = dagreFindSmallestWidthAlignment(graph, xss)
    dagreAlignCoordinates(xss, smallest)
    return dagreBalance(xss, graph.graphLabel.align)
}

class DagreVerticalAlignmentResult {
    let root: HashMap<String, String>
    let align: HashMap<String, String>

    init(root: HashMap<String, String>, align: HashMap<String, String>) {
        this.root = root
        this.align = align
    }
}

class DagreBlockEdge {
    let start: String
    let end: String
    var weight: Float64

    init(start: String, end: String, weight: Float64) {
        this.start = start
        this.end = end
        this.weight = weight
    }
}

class DagreBlockGraph {
    let nodeIds = ArrayList<String>()
    let edges = ArrayList<DagreBlockEdge>()

    func setNode(id: String): Unit {
        if (!dagreContainsString(nodeIds, id)) {
            nodeIds.add(id)
        }
    }

    func setEdge(start: String, end: String, weight: Float64): Unit {
        setNode(start)
        setNode(end)
        for (edge in edges) {
            if (edge.start == start && edge.end == end) {
                edge.weight = weight
                return
            }
        }
        edges.add(DagreBlockEdge(start, end, weight))
    }

    func edge(start: String, end: String): ?Float64 {
        for (edge in edges) {
            if (edge.start == start && edge.end == end) {
                return Some(edge.weight)
            }
        }
        return None
    }

    func nodes(): Array<String> {
        return nodeIds.toArray()
    }

    func predecessors(id: String): Array<String> {
        let out = ArrayList<String>()
        for (edge in edges) {
            if (edge.end == id && !dagreContainsString(out, edge.start)) {
                out.add(edge.start)
            }
        }
        return out.toArray()
    }

    func successors(id: String): Array<String> {
        let out = ArrayList<String>()
        for (edge in edges) {
            if (edge.start == id && !dagreContainsString(out, edge.end)) {
                out.add(edge.end)
            }
        }
        return out.toArray()
    }

    func inEdges(id: String): Array<DagreBlockEdge> {
        let out = ArrayList<DagreBlockEdge>()
        for (edge in edges) {
            if (edge.end == id) {
                out.add(edge)
            }
        }
        return out.toArray()
    }

    func outEdges(id: String): Array<DagreBlockEdge> {
        let out = ArrayList<DagreBlockEdge>()
        for (edge in edges) {
            if (edge.start == id) {
                out.add(edge)
            }
        }
        return out.toArray()
    }
}

func dagreFindType1Conflicts(graph: DagreLayoutGraph, layering: Array<Array<String>>): HashMap<String, Bool> {
    let conflicts = HashMap<String, Bool>()
    if (layering.size < 2) {
        return conflicts
    }
    for (layerIndex in 1..layering.size) {
        let prevLayer = layering[layerIndex - 1]
        let layer = layering[layerIndex]
        var k0: Int64 = 0
        var scanPos: Int64 = 0
        let prevLayerLength = prevLayer.size
        for (i in 0..layer.size) {
            let v = layer[i]
            let w = dagreFindOtherInnerSegmentNode(graph, v)
            let k1 = if (let Some(other) <- w) { graph.node(other).getOrThrow().order ?? prevLayerLength } else { prevLayerLength }
            if (w.isSome() || i == layer.size - 1) {
                for (scan in scanPos..(i + 1)) {
                    let scanNode = layer[scan]
                    for (u in graph.predecessors(scanNode)) {
                        let uLabel = graph.node(u).getOrThrow()
                        let uPos = uLabel.order ?? 0
                        if ((uPos < k0 || k1 < uPos) && !(uLabel.dummy.isSome() && graph.node(scanNode).getOrThrow().dummy.isSome())) {
                            dagreAddConflict(conflicts, u, scanNode)
                        }
                    }
                }
                scanPos = i + 1
                k0 = k1
            }
        }
    }
    return conflicts
}

func dagreFindType2Conflicts(graph: DagreLayoutGraph, layering: Array<Array<String>>): HashMap<String, Bool> {
    let conflicts = HashMap<String, Bool>()
    if (layering.size < 2) {
        return conflicts
    }
    for (layerIndex in 1..layering.size) {
        let north = layering[layerIndex - 1]
        let south = layering[layerIndex]
        var prevNorthPos: Int64 = -1
        var nextNorthPos: Int64 = north.size
        var southPos: Int64 = 0
        for (southLookahead in 0..south.size) {
            let v = south[southLookahead]
            if ((graph.node(v).getOrThrow().dummy ?? "") == "border") {
                let predecessors = graph.predecessors(v)
                if (!predecessors.isEmpty()) {
                    nextNorthPos = graph.node(predecessors[0]).getOrThrow().order ?? north.size
                    dagreScanType2(graph, conflicts, south, southPos, southLookahead, prevNorthPos, nextNorthPos)
                    southPos = southLookahead
                    prevNorthPos = nextNorthPos
                }
            }
            dagreScanType2(graph, conflicts, south, southPos, south.size, nextNorthPos, north.size)
        }
    }
    return conflicts
}

func dagreScanType2(graph: DagreLayoutGraph, conflicts: HashMap<String, Bool>, south: Array<String>, southPos: Int64, southEnd: Int64, prevNorthBorder: Int64, nextNorthBorder: Int64): Unit {
    for (i in southPos..southEnd) {
        let v = south[i]
        if (graph.node(v).getOrThrow().dummy.isSome()) {
            for (u in graph.predecessors(v)) {
                let uNode = graph.node(u).getOrThrow()
                let order = uNode.order ?? 0
                if (uNode.dummy.isSome() && (order < prevNorthBorder || order > nextNorthBorder)) {
                    dagreAddConflict(conflicts, u, v)
                }
            }
        }
    }
}

func dagreFindOtherInnerSegmentNode(graph: DagreLayoutGraph, id: String): ?String {
    if (graph.node(id).getOrThrow().dummy.isSome()) {
        for (predecessor in graph.predecessors(id)) {
            if (graph.node(predecessor).getOrThrow().dummy.isSome()) {
                return Some(predecessor)
            }
        }
    }
    return None
}

func dagreVerticalAlignment(graph: DagreLayoutGraph, layering: Array<Array<String>>, conflicts: HashMap<String, Bool>, usePredecessors: Bool): DagreVerticalAlignmentResult {
    let root = HashMap<String, String>()
    let align = HashMap<String, String>()
    let pos = HashMap<String, Int64>()
    for (layer in layering) {
        for (order in 0..layer.size) {
            let id = layer[order]
            root[id] = id
            align[id] = id
            pos[id] = order
        }
    }
    for (layer in layering) {
        var prevIdx: Int64 = -1
        for (v in layer) {
            var ws = if (usePredecessors) { graph.predecessors(v) } else { graph.successors(v) }
            dagreSortByPosition(ws, pos)
            if (!ws.isEmpty()) {
                let mp = Float64(ws.size - 1) / 2.0
                let first = floorToInt(mp)
                let last = ceilToInt(mp)
                for (i in first..(last + 1)) {
                    let w = ws[i]
                    let wPos = pos.get(w).getOrThrow()
                    if (align.get(v).getOrThrow() == v && prevIdx < wPos && !dagreHasConflict(conflicts, v, w)) {
                        align[w] = v
                        align[v] = root.get(w).getOrThrow()
                        root[v] = root.get(w).getOrThrow()
                        prevIdx = wPos
                    }
                }
            }
        }
    }
    return DagreVerticalAlignmentResult(root, align)
}

func dagreHorizontalCompaction(graph: DagreLayoutGraph, layering: Array<Array<String>>, root: HashMap<String, String>, align: HashMap<String, String>, reverseSep: Bool): HashMap<String, Float64> {
    let xs = HashMap<String, Float64>()
    let blockGraph = dagreBuildBlockGraph(graph, layering, root, reverseSep)
    let borderType = if (reverseSep) { "borderLeft" } else { "borderRight" }

    dagreBlockGraphIterate(blockGraph, true, { elem: String =>
        var value = 0.0
        for (edge in blockGraph.inEdges(elem)) {
            value = max(value, (xs.get(edge.start) ?? 0.0) + edge.weight)
        }
        xs[elem] = value
    })

    dagreBlockGraphIterate(blockGraph, false, { elem: String =>
        var found = false
        var minValue = 0.0
        for (edge in blockGraph.outEdges(elem)) {
            let value = (xs.get(edge.end) ?? 0.0) - edge.weight
            if (!found || value < minValue) {
                minValue = value
                found = true
            }
        }
        if (found) {
            let node = graph.node(elem).getOrThrow()
            if ((node.borderType ?? "") != borderType) {
                xs[elem] = max(xs.get(elem) ?? 0.0, minValue)
            }
        }
    })

    for (id in align.keys()) {
        xs[id] = xs.get(root.get(id).getOrThrow()) ?? 0.0
    }
    return xs
}

func dagreBuildBlockGraph(graph: DagreLayoutGraph, layering: Array<Array<String>>, root: HashMap<String, String>, reverseSep: Bool): DagreBlockGraph {
    let blockGraph = DagreBlockGraph()
    for (layer in layering) {
        var hasPrevious = false
        var previous = ""
        for (v in layer) {
            let vRoot = root.get(v).getOrThrow()
            blockGraph.setNode(vRoot)
            if (hasPrevious) {
                let uRoot = root.get(previous).getOrThrow()
                let prevMax = blockGraph.edge(uRoot, vRoot) ?? 0.0
                blockGraph.setEdge(uRoot, vRoot, max(dagreSep(graph, v, previous, reverseSep), prevMax))
            }
            previous = v
            hasPrevious = true
        }
    }
    return blockGraph
}

func dagreBlockGraphIterate(graph: DagreBlockGraph, usePredecessors: Bool, setXsFunc: (String) -> Unit): Unit {
    let stack = ArrayList<String>()
    for (id in graph.nodes()) {
        stack.add(id)
    }
    let visited = HashMap<String, Bool>()
    while (!stack.isEmpty()) {
        let elem = stack[stack.size - 1]
        stack.remove(at: stack.size - 1)
        if (visited.get(elem) ?? false) {
            setXsFunc(elem)
        } else {
            visited[elem] = true
            stack.add(elem)
            let nextNodes = if (usePredecessors) { graph.predecessors(elem) } else { graph.successors(elem) }
            for (next in nextNodes) {
                stack.add(next)
            }
        }
    }
}

func dagreFindSmallestWidthAlignment(graph: DagreLayoutGraph, xss: HashMap<String, HashMap<String, Float64>>): HashMap<String, Float64> {
    var found = false
    var bestWidth = 0.0
    var best = HashMap<String, Float64>()
    for (alignment in xss.keys()) {
        let xs = xss.get(alignment).getOrThrow()
        var localFound = false
        var minX = 0.0
        var maxX = 0.0
        for (id in xs.keys()) {
            let halfWidth = graph.node(id).getOrThrow().width / 2.0
            let x = xs.get(id).getOrThrow()
            if (!localFound) {
                minX = x - halfWidth
                maxX = x + halfWidth
                localFound = true
            } else {
                minX = min(minX, x - halfWidth)
                maxX = max(maxX, x + halfWidth)
            }
        }
        let width = maxX - minX
        if (!found || width < bestWidth) {
            bestWidth = width
            best = xs
            found = true
        }
    }
    return best
}

func dagreAlignCoordinates(xss: HashMap<String, HashMap<String, Float64>>, alignTo: HashMap<String, Float64>): Unit {
    let alignToExtremes = dagreMapMinMax(alignTo)
    for (vert in ["u", "d"]) {
        for (horiz in ["l", "r"]) {
            let alignment = vert + horiz
            let xs = xss.get(alignment).getOrThrow()
            let extremes = dagreMapMinMax(xs)
            let delta = if (horiz == "l") { alignToExtremes[0] - extremes[0] } else { alignToExtremes[1] - extremes[1] }
            if (delta != 0.0) {
                for (id in xs.keys()) {
                    xs[id] = xs.get(id).getOrThrow() + delta
                }
            }
        }
    }
}

func dagreBalance(xss: HashMap<String, HashMap<String, Float64>>, align: ?String): HashMap<String, Float64> {
    if (let Some(value) <- align) {
        let key = dagreAsciiLower(value)
        if (xss.get(key).isSome()) {
            return xss.get(key).getOrThrow()
        }
    }
    let out = HashMap<String, Float64>()
    let ul = xss.get("ul").getOrThrow()
    for (id in ul.keys()) {
        let values = ArrayList<Float64>()
        for (alignment in ["ul", "ur", "dl", "dr"]) {
            values.add(xss.get(alignment).getOrThrow().get(id).getOrThrow())
        }
        dagreSortFloats(values)
        out[id] = (values[1] + values[2]) / 2.0
    }
    return out
}

func dagreSep(graph: DagreLayoutGraph, v: String, w: String, reverseSep: Bool): Float64 {
    let vLabel = graph.node(v).getOrThrow()
    let wLabel = graph.node(w).getOrThrow()
    var sum = vLabel.width / 2.0
    var delta = 0.0
    match (vLabel.labelpos ?? "") {
        case "l" => delta = -vLabel.width / 2.0
        case "r" => delta = vLabel.width / 2.0
        case _ => ()
    }
    if (delta != 0.0) {
        sum += if (reverseSep) { delta } else { -delta }
    }
    sum += (if (vLabel.dummy.isSome()) { graph.graphLabel.edgesep } else { graph.graphLabel.nodesep }) / 2.0
    sum += (if (wLabel.dummy.isSome()) { graph.graphLabel.edgesep } else { graph.graphLabel.nodesep }) / 2.0
    sum += wLabel.width / 2.0
    delta = 0.0
    match (wLabel.labelpos ?? "") {
        case "l" => delta = wLabel.width / 2.0
        case "r" => delta = -wLabel.width / 2.0
        case _ => ()
    }
    if (delta != 0.0) {
        sum += if (reverseSep) { delta } else { -delta }
    }
    return sum
}

func dagreSwapWidthHeight(graph: DagreLayoutGraph): Unit {
    for (id in graph.nodes()) {
        let node = graph.node(id).getOrThrow()
        let width = node.width
        node.width = node.height
        node.height = width
    }
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        let width = edge.width
        edge.width = edge.height
        edge.height = width
    }
}

func dagreReverseY(graph: DagreLayoutGraph): Unit {
    for (id in graph.nodes()) {
        graph.node(id).getOrThrow().y = -graph.node(id).getOrThrow().y
    }
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        for (i in 0..edge.points.size) {
            let point = edge.points[i]
            edge.points[i] = DagrePoint(point.x, -point.y)
        }
        if (let Some(y) <- edge.y) {
            edge.y = Some(-y)
        }
    }
}

func dagreSwapXY(graph: DagreLayoutGraph): Unit {
    for (id in graph.nodes()) {
        let node = graph.node(id).getOrThrow()
        let x = node.x
        node.x = node.y
        node.y = x
    }
    for (key in graph.edges()) {
        let edge = graph.edge(key).getOrThrow()
        for (i in 0..edge.points.size) {
            let point = edge.points[i]
            edge.points[i] = DagrePoint(point.y, point.x)
        }
        if (edge.x.isSome()) {
            let x = edge.x.getOrThrow()
            edge.x = edge.y
            edge.y = Some(x)
        }
    }
}

func dagreReverseLayers(layers: Array<Array<String>>): Array<Array<String>> {
    return Array<Array<String>>(layers.size, { i => layers[layers.size - 1 - i] })
}

func dagreReverseLayerEntries(layers: Array<Array<String>>): Array<Array<String>> {
    return Array<Array<String>>(layers.size, { i =>
        let layer = layers[i]
        Array<String>(layer.size, { j => layer[layer.size - 1 - j] })
    })
}

func dagreSortByPosition(values: Array<String>, positions: HashMap<String, Int64>): Unit {
    var i = 1
    while (i < values.size) {
        let value = values[i]
        let pos = positions.get(value) ?? 0
        var j = i - 1
        while (j >= 0 && (positions.get(values[j]) ?? 0) > pos) {
            values[j + 1] = values[j]
            j--
        }
        values[j + 1] = value
        i++
    }
}

func dagreSortFloats(values: ArrayList<Float64>): Unit {
    var i = 1
    while (i < values.size) {
        let value = values[i]
        var j = i - 1
        while (j >= 0 && values[j] > value) {
            values[j + 1] = values[j]
            j--
        }
        values[j + 1] = value
        i++
    }
}

func dagreMapMinMax(values: HashMap<String, Float64>): Array<Float64> {
    var found = false
    var minValue = 0.0
    var maxValue = 0.0
    for (id in values.keys()) {
        let value = values.get(id).getOrThrow()
        if (!found) {
            minValue = value
            maxValue = value
            found = true
        } else {
            minValue = min(minValue, value)
            maxValue = max(maxValue, value)
        }
    }
    return [minValue, maxValue]
}

func dagreAddConflict(conflicts: HashMap<String, Bool>, v: String, w: String): Unit {
    conflicts[dagreConflictKey(v, w)] = true
    conflicts[dagreConflictKey(w, v)] = true
}

func dagreHasConflict(conflicts: HashMap<String, Bool>, v: String, w: String): Bool {
    return conflicts.get(dagreConflictKey(v, w)) ?? false
}

func dagreMergeConflicts(target: HashMap<String, Bool>, source: HashMap<String, Bool>): Unit {
    for (key in source.keys()) {
        target[key] = true
    }
}

func dagreConflictKey(v: String, w: String): String {
    return v + "\u{1f}" + w
}

func dagreAsciiLower(value: String): String {
    match (value) {
        case "TB" => return "tb"
        case "TD" => return "td"
        case "BT" => return "bt"
        case "LR" => return "lr"
        case "RL" => return "rl"
        case "UL" => return "ul"
        case "UR" => return "ur"
        case "DL" => return "dl"
        case "DR" => return "dr"
        case _ => return value
    }
}

func dagreContainsString(values: ArrayList<String>, value: String): Bool {
    for (item in values) {
        if (item == value) {
            return true
        }
    }
    return false
}

func floorToInt(value: Float64): Int64 {
    let asInt = Int64(value)
    if (Float64(asInt) > value) {
        return asInt - 1
    }
    return asInt
}

func ceilToInt(value: Float64): Int64 {
    let asInt = Int64(value)
    if (Float64(asInt) < value) {
        return asInt + 1
    }
    return asInt
}
