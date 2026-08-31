package mermaid4cj.layout

import std.collection.{ArrayList, HashMap}
import mermaid4cj.core.{DefaultMermaidTextMeasurer, FlowDirection, FlowEdgeMarker, FlowNodeShape, FlowSubgraph, FlowchartDiagram, MermaidTextMeasurer, TextRange}
import mermaid4cj.layout.dagre.{
    DagreEdge,
    DagreEdgeRef,
    DagreGraphLabel,
    DagreLayoutEdge,
    DagreLayoutGraph,
    DagreLayoutNode,
    DagreNode,
    DagrePoint,
    MermaidDagreGraph,
    dagreAcyclicRun,
    dagreAcyclicUndo,
    dagreAddBorderSegments,
    dagreAssignNodeIntersects,
    dagreAssignRankMinMax,
    buildFlowchartDagreGraph,
    dagreAdjustCoordinateSystem,
    dagreAsNonCompoundGraph,
    dagreFixupEdgeLabelCoords,
    dagreInjectEdgeLabelProxies,
    dagreInsertSelfEdges,
    dagreMakeSpaceForEdgeLabels,
    dagreNestingGraphCleanup,
    dagreNestingGraphRun,
    dagreNormalizeRun,
    dagreNormalizeUndo,
    dagreNormalizeRanks,
    dagreOrder,
    dagreParentDummyChains,
    dagrePosition,
    dagrePositionSelfEdges,
    dagreRemoveBorderNodes,
    dagreRemoveEmptyRanks,
    dagreRank,
    dagreRemoveEdgeLabelProxies,
    dagreRemoveSelfEdges,
    dagreReversePointsForReversedEdges,
    dagreTranslateGraph,
    dagreUndoCoordinateSystem,
    getEdgesToRender,
    intersectPolygon,
    intersectRect,
    intersectEllipse,
    intersectCylinder
}

public class LayoutNode {
    public let id: String
    public let x: Float64
    public let y: Float64
    public let width: Float64
    public let height: Float64

    public init(id: String, x: Float64, y: Float64, width: Float64, height: Float64) {
        this.id = id
        this.x = x
        this.y = y
        this.width = width
        this.height = height
    }
}

public class LayoutEdge {
    public let source: String
    public let target: String
    public let x1: Float64
    public let y1: Float64
    public let x2: Float64
    public let y2: Float64
    public let points: Array<AnchorPoint>
    public let labelX: ?Float64
    public let labelY: ?Float64

    public init(
        source: String,
        target: String,
        x1: Float64,
        y1: Float64,
        x2: Float64,
        y2: Float64,
        points!: Array<AnchorPoint> = [],
        labelX!: ?Float64 = None,
        labelY!: ?Float64 = None
    ) {
        this.source = source
        this.target = target
        this.x1 = x1
        this.y1 = y1
        this.x2 = x2
        this.y2 = y2
        this.points = points
        this.labelX = labelX
        this.labelY = labelY
    }
}

public class LayoutCluster {
    public let id: String
    public let title: TextRange
    public let parentId: ?String
    public let x: Float64
    public let y: Float64
    public let width: Float64
    public let height: Float64

    public init(id: String, title: TextRange, parentId: ?String, x: Float64, y: Float64, width: Float64, height: Float64) {
        this.id = id
        this.title = title
        this.parentId = parentId
        this.x = x
        this.y = y
        this.width = width
        this.height = height
    }
}

public class AnchorPoint {
    public let x: Float64
    public let y: Float64

    public init(x: Float64, y: Float64) {
        this.x = x
        this.y = y
    }
}

public class FlowchartLayoutResult {
    public let width: Float64
    public let height: Float64
    public let nodes: Array<LayoutNode>
    public let edges: Array<LayoutEdge>
    public let clusters: Array<LayoutCluster>

    public init(width: Float64, height: Float64, nodes: Array<LayoutNode>, edges: Array<LayoutEdge>, clusters!: Array<LayoutCluster> = []) {
        this.width = width
        this.height = height
        this.nodes = nodes
        this.edges = edges
        this.clusters = clusters
    }
}

public class FlowchartLayout {
    let textMeasurer: MermaidTextMeasurer

    public init(textMeasurer!: MermaidTextMeasurer = DefaultMermaidTextMeasurer()) {
        this.textMeasurer = textMeasurer
    }

    public func layout(diagram: FlowchartDiagram): FlowchartLayoutResult {
        let dagreGraph = buildFlowchartDagreGraph(diagram)
        let dagreEdges = collectRenderEdges(dagreGraph)
        let logicalEdges = Array<DagreEdge>(dagreEdges.size, { i => dagreEdges[i].edge })
        let horizontal = isHorizontal(diagram.direction)
        let indexes = HashMap<String, Int64>()
        for (i in 0..diagram.nodes.size) {
            indexes[diagram.nodes[i].id] = i
        }
        let officialLayoutGraph = buildOfficialDagreLayoutGraph(diagram, logicalEdges, indexes)
        dagreMakeSpaceForEdgeLabels(officialLayoutGraph)
        dagreRemoveSelfEdges(officialLayoutGraph)
        dagreAcyclicRun(officialLayoutGraph)
        dagreNestingGraphRun(officialLayoutGraph)
        dagreRank(dagreAsNonCompoundGraph(officialLayoutGraph))
        dagreInjectEdgeLabelProxies(officialLayoutGraph)
        dagreRemoveEmptyRanks(officialLayoutGraph)
        dagreNestingGraphCleanup(officialLayoutGraph)
        dagreNormalizeRanks(officialLayoutGraph)
        dagreAssignRankMinMax(officialLayoutGraph)
        dagreRemoveEdgeLabelProxies(officialLayoutGraph)
        let nodeWidths = Array<Float64>(diagram.nodes.size, { i =>
            let node = diagram.nodes[i]
            nodeWidth(node.shape, nodeLabelVisualWidth(diagram.source, node.label.start, node.label.end, node.labelText))
        })
        let nodeHeights = Array<Float64>(diagram.nodes.size, { i =>
            let node = diagram.nodes[i]
            nodeHeight(node.shape, countNodeLabelLines(diagram.source, node.label.start, node.label.end, node.labelText))
        })
        setOfficialNodeSizes(officialLayoutGraph, diagram, nodeWidths, nodeHeights)
        dagreNormalizeRun(officialLayoutGraph)
        dagreParentDummyChains(officialLayoutGraph)
        dagreAddBorderSegments(officialLayoutGraph)
        dagreOrder(officialLayoutGraph)
        dagreInsertSelfEdges(officialLayoutGraph)
        dagreAdjustCoordinateSystem(officialLayoutGraph)
        dagrePosition(officialLayoutGraph)
        dagrePositionSelfEdges(officialLayoutGraph)
        dagreRemoveBorderNodes(officialLayoutGraph)
        dagreNormalizeUndo(officialLayoutGraph)
        dagreFixupEdgeLabelCoords(officialLayoutGraph)
        dagreUndoCoordinateSystem(officialLayoutGraph)
        dagreTranslateGraph(officialLayoutGraph)
        dagreAssignNodeIntersects(officialLayoutGraph)
        dagreReversePointsForReversedEdges(officialLayoutGraph)
        dagreAcyclicUndo(officialLayoutGraph)

        let positions = HashMap<String, LayoutNode>()
        let layoutNodes = Array<LayoutNode>(diagram.nodes.size, { i =>
            let node = diagram.nodes[i]
            let width = nodeWidths[i]
            let height = nodeHeights[i]
            let officialNode = officialLayoutGraph.node(node.id).getOrThrow()
            let x = officialNode.x - width / 2.0
            let y = officialNode.y - height / 2.0
            LayoutNode(node.id, x, y, width, height)
        })
        for (node in layoutNodes) {
            positions[node.id] = node
        }

        applyPositionsToGraph(dagreGraph, positions)
        let positionedRenderEdges = collectRenderEdges(dagreGraph)
        let layoutEdges = Array<LayoutEdge>(diagram.edges.size, { i =>
            let edge = diagram.edges[i]
            let sourceIndex = indexes.get(edge.source).getOrThrow()
            let targetIndex = indexes.get(edge.target).getOrThrow()
            let source = positions.get(edge.source).getOrThrow()
            let target = positions.get(edge.target).getOrThrow()
            let edgeOccurrence = countPreviousEdges(diagram, i, edge.source, edge.target)
            if (let Some(officialEdge) <- findOfficialEdge(officialLayoutGraph, edge.source, edge.target, edgeOccurrence)) {
                if (!officialEdge.points.isEmpty()) {
                    let points = ArrayList<AnchorPoint>()
                    let firstGuideIndex = if (officialEdge.points.size > 2) { 1 } else { 0 }
                    let lastGuideIndex = if (officialEdge.points.size > 2) { officialEdge.points.size - 2 } else { officialEdge.points.size - 1 }
                    let firstGuide = officialEdge.points[firstGuideIndex]
                    let lastGuide = officialEdge.points[lastGuideIndex]
                    let sourcePoint = boundaryPoint(diagram.nodes[sourceIndex].shape, source, firstGuide.x, firstGuide.y)
                    let targetPoint = boundaryPoint(diagram.nodes[targetIndex].shape, target, lastGuide.x, lastGuide.y)
                    points.add(sourcePoint)
                    let middleStart = if (officialEdge.points.size > 2) { 1 } else { 0 }
                    let middleEnd = if (officialEdge.points.size > 2) { officialEdge.points.size - 1 } else { officialEdge.points.size }
                    for (p in middleStart..middleEnd) {
                        points.add(AnchorPoint(officialEdge.points[p].x, officialEdge.points[p].y))
                    }
                    points.add(targetPoint)
                    return LayoutEdge(
                        edge.source,
                        edge.target,
                        sourcePoint.x,
                        sourcePoint.y,
                        targetPoint.x,
                        targetPoint.y,
                        points: points.toArray(),
                        labelX: officialEdge.x,
                        labelY: officialEdge.y
                    )
                }
            }
            if (edge.source == edge.target) {
                if (let Some(renderEdge) <- findRenderEdge(positionedRenderEdges, edge.id ?? ("L_" + edge.source + "_" + edge.target))) {
                    if (!renderEdge.edge.points.isEmpty()) {
                        let points = Array<AnchorPoint>(renderEdge.edge.points.size, { p => AnchorPoint(renderEdge.edge.points[p].x, renderEdge.edge.points[p].y) })
                        return LayoutEdge(
                            edge.source,
                            edge.target,
                            points[0].x,
                            points[0].y,
                            points[points.size - 1].x,
                            points[points.size - 1].y,
                            points: points,
                            labelX: renderEdge.edge.x,
                            labelY: renderEdge.edge.y
                        )
                    }
                }
                let cx = centerX(source)
                let cy = centerY(source)
                return LayoutEdge(edge.source, edge.target, cx, cy, cx, cy)
            }
            let sourcePoint = boundaryPoint(diagram.nodes[sourceIndex].shape, source, centerX(target), centerY(target))
            let targetPoint = boundaryPoint(diagram.nodes[targetIndex].shape, target, centerX(source), centerY(source))
            let labelPosition = labelPositionForEdge(diagram, edge.source, edge.target, positions, horizontal)
            let points = ArrayList<AnchorPoint>()
            points.add(sourcePoint)
            points.add(targetPoint)
            LayoutEdge(edge.source, edge.target, sourcePoint.x, sourcePoint.y, targetPoint.x, targetPoint.y, points: points.toArray(), labelX: labelPosition[0], labelY: labelPosition[1])
        })

        let clusters = layoutClusters(diagram, positions)
        return padLayout(layoutNodes, layoutEdges, clusters)
    }

    private func padLayout(nodes: Array<LayoutNode>, edges: Array<LayoutEdge>, clusters: Array<LayoutCluster>): FlowchartLayoutResult {
        let padding = 8.0
        var minX = 0.0
        var minY = 0.0
        var maxX = 0.0
        var maxY = 0.0
        var hasBounds = false

        for (node in nodes) {
            if (!hasBounds) {
                minX = node.x
                minY = node.y
                maxX = node.x + node.width
                maxY = node.y + node.height
                hasBounds = true
            } else {
                minX = min(minX, node.x)
                minY = min(minY, node.y)
                maxX = max(maxX, node.x + node.width)
                maxY = max(maxY, node.y + node.height)
            }
        }
        for (cluster in clusters) {
            if (!hasBounds) {
                minX = cluster.x
                minY = cluster.y
                maxX = cluster.x + cluster.width
                maxY = cluster.y + cluster.height
                hasBounds = true
            } else {
                minX = min(minX, cluster.x)
                minY = min(minY, cluster.y)
                maxX = max(maxX, cluster.x + cluster.width)
                maxY = max(maxY, cluster.y + cluster.height)
            }
        }
        for (edge in edges) {
            let points = if (edge.points.isEmpty()) { [AnchorPoint(edge.x1, edge.y1), AnchorPoint(edge.x2, edge.y2)] } else { edge.points }
            for (point in points) {
                if (!hasBounds) {
                    minX = point.x
                    minY = point.y
                    maxX = point.x
                    maxY = point.y
                    hasBounds = true
                } else {
                    minX = min(minX, point.x)
                    minY = min(minY, point.y)
                    maxX = max(maxX, point.x)
                    maxY = max(maxY, point.y)
                }
            }
            if (let Some(labelX) <- edge.labelX) {
                if (let Some(labelY) <- edge.labelY) {
                    minX = min(minX, labelX)
                    minY = min(minY, labelY)
                    maxX = max(maxX, labelX)
                    maxY = max(maxY, labelY)
                }
            }
        }

        if (!hasBounds) {
            return FlowchartLayoutResult(160.0, 120.0, nodes, edges, clusters: clusters)
        }

        let dx = padding - minX
        let dy = padding - minY
        let shiftedNodes = Array<LayoutNode>(nodes.size, { i =>
            let node = nodes[i]
            LayoutNode(node.id, node.x + dx, node.y + dy, node.width, node.height)
        })
        let shiftedEdges = Array<LayoutEdge>(edges.size, { i =>
            let edge = edges[i]
            let shiftedPoints = Array<AnchorPoint>(edge.points.size, { p =>
                AnchorPoint(edge.points[p].x + dx, edge.points[p].y + dy)
            })
            LayoutEdge(
                edge.source,
                edge.target,
                edge.x1 + dx,
                edge.y1 + dy,
                edge.x2 + dx,
                edge.y2 + dy,
                points: shiftedPoints,
                labelX: shiftOption(edge.labelX, dx),
                labelY: shiftOption(edge.labelY, dy)
            )
        })
        let shiftedClusters = Array<LayoutCluster>(clusters.size, { i =>
            let cluster = clusters[i]
            LayoutCluster(cluster.id, cluster.title, cluster.parentId, cluster.x + dx, cluster.y + dy, cluster.width, cluster.height)
        })

        let width = max(160.0, maxX - minX + padding * 2.0)
        let height = max(120.0, maxY - minY + padding * 2.0)
        return FlowchartLayoutResult(width, height, shiftedNodes, shiftedEdges, clusters: shiftedClusters)
    }

    private func shiftOption(value: ?Float64, delta: Float64): ?Float64 {
        if (let Some(v) <- value) {
            return Some(v + delta)
        }
        return None
    }

    private func collectRenderEdges(graph: MermaidDagreGraph): Array<DagreEdgeRef> {
        let out = ArrayList<DagreEdgeRef>()
        appendRenderEdges(out, graph)
        return out.toArray()
    }

    private func appendRenderEdges(out: ArrayList<DagreEdgeRef>, graph: MermaidDagreGraph): Unit {
        for (edge in getEdgesToRender(graph)) {
            out.add(edge)
        }
        for (id in graph.nodes()) {
            if (let Some(node) <- graph.node(id)) {
                if (let Some(childGraph) <- node.graph) {
                    appendRenderEdges(out, childGraph)
                }
            }
        }
    }

    private func applyPositionsToGraph(graph: MermaidDagreGraph, positions: HashMap<String, LayoutNode>): Unit {
        for (id in graph.nodes()) {
            if (let Some(node) <- graph.node(id)) {
                if (let Some(placed) <- positions.get(id)) {
                    graph.setNode(id, DagreNode(
                        id,
                        x: Some(centerX(placed)),
                        y: Some(centerY(placed)),
                        width: Some(placed.width),
                        height: Some(placed.height),
                        clusterNode: node.clusterNode,
                        graph: node.graph,
                        dir: node.dir,
                        explicitDir: node.explicitDir
                    ))
                }
                if (let Some(childGraph) <- node.graph) {
                    applyPositionsToGraph(childGraph, positions)
                }
            }
        }
    }

    private func findRenderEdge(edges: Array<DagreEdgeRef>, id: String): ?DagreEdgeRef {
        for (edge in edges) {
            if (edge.edge.id == id) {
                return Some(edge)
            }
        }
        return None
    }

    private func buildOfficialDagreLayoutGraph(diagram: FlowchartDiagram, edges: Array<DagreEdge>, indexes: HashMap<String, Int64>): DagreLayoutGraph {
        let label = DagreGraphLabel(ranker: Some("network-simplex"), rankdir: dagreRankdir(diagram.direction))
        let graph = DagreLayoutGraph(label: label)
        for (subgraph in diagram.subgraphDefs) {
            graph.setNode(subgraph.id, node: DagreLayoutNode(subgraph.id))
            if (let Some(parentId) <- subgraph.parentId) {
                graph.setParent(subgraph.id, parentId)
            }
        }
        for (node in diagram.nodes) {
            graph.setNode(node.id, node: DagreLayoutNode(node.id))
            if (let Some(parentId) <- diagram.nodeParents.get(node.id)) {
                graph.setParent(node.id, parentId)
            }
        }
        for (edge in edges) {
            if (isReverseOfDoubleEndedEdge(diagram, edge.start, edge.end)) {
                continue
            }
            if (indexes.get(edge.start).isNone() || indexes.get(edge.end).isNone()) {
                continue
            }
            graph.setEdge(
                edge.start,
                edge.end,
                edge: buildOfficialDagreLayoutEdge(diagram, edge),
                name: edge.id
            )
        }
        return graph
    }

    private func buildOfficialDagreLayoutEdge(diagram: FlowchartDiagram, edge: DagreEdge): DagreLayoutEdge {
        let out = DagreLayoutEdge(edge.id, minlen: edge.length, weight: 1.0)
        if (let Some(label) <- labelRangeForEdge(diagram, edge)) {
            out.width = edgeLabelWidth(diagram.source, label.start, label.end)
            out.height = 24.0
        }
        return out
    }

    private func labelRangeForEdge(diagram: FlowchartDiagram, dagreEdge: DagreEdge): ?TextRange {
        for (edge in diagram.edges) {
            if ((edge.id ?? "") == dagreEdge.id && edge.label.isSome()) {
                return edge.label
            }
        }
        for (edge in diagram.edges) {
            if (edge.source == dagreEdge.start && edge.target == dagreEdge.end && edge.label.isSome()) {
                return edge.label
            }
        }
        return None
    }

    private func setOfficialNodeSizes(graph: DagreLayoutGraph, diagram: FlowchartDiagram, nodeWidths: Array<Float64>, nodeHeights: Array<Float64>): Unit {
        for (i in 0..diagram.nodes.size) {
            if (let Some(node) <- graph.node(diagram.nodes[i].id)) {
                node.width = nodeWidths[i]
                node.height = nodeHeights[i]
            }
        }
    }

    private func dagreRankdir(direction: FlowDirection): String {
        match (direction) {
            case FlowDirection.TB => "TB"
            case FlowDirection.TD => "TB"
            case FlowDirection.BT => "BT"
            case FlowDirection.LR => "LR"
            case FlowDirection.RL => "RL"
        }
    }

    private func ranksFromOfficialGraph(diagram: FlowchartDiagram, graph: DagreLayoutGraph): Array<Int64> {
        return Array<Int64>(diagram.nodes.size, { i =>
            graph.node(diagram.nodes[i].id).getOrThrow().rank ?? 0
        })
    }

    private func orderHintsFromOfficialGraph(diagram: FlowchartDiagram, graph: DagreLayoutGraph): Array<Float64> {
        return Array<Float64>(diagram.nodes.size, { i =>
            Float64(graph.node(diagram.nodes[i].id).getOrThrow().order ?? i)
        })
    }

    private func countPreviousEdges(diagram: FlowchartDiagram, endIndex: Int64, source: String, target: String): Int64 {
        var count: Int64 = 0
        for (i in 0..endIndex) {
            let edge = diagram.edges[i]
            if (edge.source == source && edge.target == target) {
                count++
            }
        }
        return count
    }

    private func findOfficialEdge(graph: DagreLayoutGraph, source: String, target: String, occurrence: Int64): ?DagreLayoutEdge {
        var count: Int64 = 0
        for (key in graph.edges()) {
            if (key.start == source && key.end == target) {
                if (count == occurrence) {
                    return graph.edge(key)
                }
                count++
            }
        }
        return None
    }

    private func layoutClusters(diagram: FlowchartDiagram, positions: HashMap<String, LayoutNode>): Array<LayoutCluster> {
        if (diagram.subgraphDefs.isEmpty()) {
            return []
        }
        let out = ArrayList<LayoutCluster>()
        var offset = diagram.subgraphDefs.size - 1
        while (offset >= 0) {
            let subgraph = diagram.subgraphDefs[offset]
            if (let Some(cluster) <- layoutCluster(diagram, subgraph, positions, out)) {
                out.add(cluster)
            }
            offset--
        }
        let ordered = ArrayList<LayoutCluster>()
        var index = out.size - 1
        while (index >= 0) {
            ordered.add(out[index])
            index--
        }
        return ordered.toArray()
    }

    private func layoutCluster(diagram: FlowchartDiagram, subgraph: FlowSubgraph, positions: HashMap<String, LayoutNode>, existing: ArrayList<LayoutCluster>): ?LayoutCluster {
        var hasMember = false
        var minX = 0.0
        var minY = 0.0
        var maxX = 0.0
        var maxY = 0.0
        for (nodeId in diagram.nodeParents.keys()) {
            if (diagram.nodeParents.get(nodeId).getOrThrow() == subgraph.id) {
                if (let Some(node) <- positions.get(nodeId)) {
                    if (!hasMember) {
                        minX = node.x
                        minY = node.y
                        maxX = node.x + node.width
                        maxY = node.y + node.height
                        hasMember = true
                    } else {
                        minX = min(minX, node.x)
                        minY = min(minY, node.y)
                        maxX = max(maxX, node.x + node.width)
                        maxY = max(maxY, node.y + node.height)
                    }
                }
            }
        }
        for (cluster in existing) {
            if (let Some(parentId) <- cluster.parentId) {
                if (parentId == subgraph.id) {
                    if (!hasMember) {
                        minX = cluster.x
                        minY = cluster.y
                        maxX = cluster.x + cluster.width
                        maxY = cluster.y + cluster.height
                        hasMember = true
                    } else {
                        minX = min(minX, cluster.x)
                        minY = min(minY, cluster.y)
                        maxX = max(maxX, cluster.x + cluster.width)
                        maxY = max(maxY, cluster.y + cluster.height)
                    }
                }
            }
        }
        if (!hasMember) {
            return None
        }
        let padX = 24.0
        let padTop = 38.0
        let padBottom = 20.0
        return Some(LayoutCluster(subgraph.id, subgraph.title, subgraph.parentId, minX - padX, minY - padTop, (maxX - minX) + padX * 2.0, (maxY - minY) + padTop + padBottom))
    }

    private func minHint(hints: Array<Float64>): Float64 {
        if (hints.isEmpty()) {
            return 0.0
        }
        var value = hints[0]
        for (hint in hints) {
            value = min(value, hint)
        }
        return value
    }

    private func computeRanks(diagram: FlowchartDiagram): Array<Int64> {
        let indexes = HashMap<String, Int64>()
        for (i in 0..diagram.nodes.size) {
            indexes[diagram.nodes[i].id] = i
        }
        let ranks = Array<Int64>(diagram.nodes.size, repeat: 0)
        for (_ in 0..diagram.nodes.size) {
            var changed = false
            for (edge in diagram.edges) {
                if (let Some(sourceIndex) <- indexes.get(edge.source)) {
                    if (let Some(targetIndex) <- indexes.get(edge.target)) {
                        if (isReverseOfDoubleEndedEdge(diagram, edge.source, edge.target)) {
                            continue
                        }
                        if (targetIndex <= sourceIndex && !hasStartMarker(edge.markerStart)) {
                            continue
                        }
                        let nextRank = ranks[sourceIndex] + 1
                        if (nextRank > ranks[targetIndex]) {
                            ranks[targetIndex] = nextRank
                            changed = true
                        }
                    }
                }
            }
            if (!changed) {
                break
            }
        }
        return ranks
    }

    private func computeDagreRanks(diagram: FlowchartDiagram, edges: Array<DagreEdge>): Array<Int64> {
        let indexes = HashMap<String, Int64>()
        for (i in 0..diagram.nodes.size) {
            indexes[diagram.nodes[i].id] = i
        }
        let ranks = Array<Int64>(diagram.nodes.size, repeat: 0)
        for (_ in 0..diagram.nodes.size) {
            var changed = false
            for (edge in edges) {
                if (edge.start == edge.end) {
                    continue
                }
                if (isReverseOfDoubleEndedEdge(diagram, edge.start, edge.end)) {
                    continue
                }
                if (let Some(sourceIndex) <- indexes.get(edge.start)) {
                    if (let Some(targetIndex) <- indexes.get(edge.end)) {
                        if (targetIndex <= sourceIndex) {
                            continue
                        }
                        let nextRank = ranks[sourceIndex] + edge.length
                        if (nextRank > ranks[targetIndex]) {
                            ranks[targetIndex] = nextRank
                            changed = true
                        }
                    }
                }
            }
            if (!changed) {
                break
            }
        }
        return ranks
    }

    private func nodeWidth(shape: FlowNodeShape, textWidth: Float64): Float64 {
        match (shape) {
            case FlowNodeShape.Stadium => return max(62.0, textWidth + 28.0)
            case FlowNodeShape.Cylinder => return max(58.0, textWidth + 30.0)
            case FlowNodeShape.Datastore => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.Subroutine => return max(74.0, textWidth + 37.0)
            case FlowNodeShape.Diamond => return max(108.0, textWidth + 34.0)
            case FlowNodeShape.Hexagon => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.LeanRight => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.LeanLeft => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.Trapezoid => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.InvTrapezoid => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.DoubleCircle => return max(58.0, textWidth + 34.0)
            case FlowNodeShape.Text => return max(24.0, textWidth + 8.0)
            case FlowNodeShape.Card => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.ShadedProcess => return max(88.0, textWidth + 50.0)
            case FlowNodeShape.SmallCircle => return 14.0
            case FlowNodeShape.FramedCircle => return 14.0
            case FlowNodeShape.FilledCircle => return 14.0
            case FlowNodeShape.Fork => return 70.0
            case FlowNodeShape.Document => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.MultiProcess => return max(84.0, textWidth + 44.0)
            case FlowNodeShape.DividedProcess => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.Triangle => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.SlopedRectangle => return max(84.0, textWidth + 34.0)
            case FlowNodeShape.CrossedCircle => return 60.0
            case FlowNodeShape.TaggedProcess => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.TaggedDocument => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.Flag => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.Hourglass => return 30.0
            case FlowNodeShape.NotchedPentagon => return max(84.0, textWidth + 34.0)
            case FlowNodeShape.FlippedTriangle => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.Delay => return max(84.0, textWidth + 34.0)
            case FlowNodeShape.CurvedTrapezoid => return max(90.0, (textWidth + 34.0) * 1.25)
            case FlowNodeShape.WindowPane => return max(84.0, textWidth + 44.0)
            case FlowNodeShape.LinedCylinder => return max(58.0, textWidth + 30.0)
            case FlowNodeShape.HorizontalCylinder => return max(78.0, textWidth + 42.0)
            case FlowNodeShape.MultiDocument => return max(84.0, textWidth + 44.0)
            case FlowNodeShape.LinedDocument => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.Bang => return max(72.0, textWidth + 44.0)
            case FlowNodeShape.Cloud => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.LightningBolt => return 35.0
            case FlowNodeShape.BowTieRectangle => return max(84.0, textWidth + 44.0)
            case FlowNodeShape.CurlyBraceLeft => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.CurlyBraceRight => return max(72.0, textWidth + 34.0)
            case FlowNodeShape.CurlyBraces => return max(84.0, textWidth + 46.0)
            case FlowNodeShape.Circle | FlowNodeShape.Ellipse => return max(48.0, textWidth + 24.0)
            case FlowNodeShape.Odd => return max(72.0, textWidth + 34.0)
            case _ => return max(72.0, textWidth + 34.0)
        }
    }

    private func nodeHeight(shape: FlowNodeShape, labelLines: Int64): Float64 {
        let labelHeight = Float64(max(1, labelLines)) * 24.0
        match (shape) {
            case FlowNodeShape.Diamond => return max(88.0, labelHeight + 48.0)
            case FlowNodeShape.Hexagon => return max(58.0, labelHeight + 30.0)
            case FlowNodeShape.LeanRight => return max(58.0, labelHeight + 30.0)
            case FlowNodeShape.LeanLeft => return max(58.0, labelHeight + 30.0)
            case FlowNodeShape.Trapezoid => return max(58.0, labelHeight + 30.0)
            case FlowNodeShape.InvTrapezoid => return max(58.0, labelHeight + 30.0)
            case FlowNodeShape.Circle | FlowNodeShape.Ellipse => return max(48.0, labelHeight + 15.0)
            case FlowNodeShape.Odd => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.Cylinder => return max(62.0, labelHeight + 38.0)
            case FlowNodeShape.DoubleCircle => return max(58.0, labelHeight + 34.0)
            case FlowNodeShape.Text => return max(24.0, labelHeight)
            case FlowNodeShape.Card => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.ShadedProcess => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.SmallCircle => return 14.0
            case FlowNodeShape.FramedCircle => return 14.0
            case FlowNodeShape.FilledCircle => return 14.0
            case FlowNodeShape.Fork => return 10.0
            case FlowNodeShape.Document => return max(62.0, labelHeight + 38.0)
            case FlowNodeShape.MultiProcess => return max(64.0, labelHeight + 40.0)
            case FlowNodeShape.DividedProcess => return max(64.0, labelHeight + 38.0)
            case FlowNodeShape.Triangle => return max(72.0, labelHeight + 48.0)
            case FlowNodeShape.SlopedRectangle => return max(81.0, (labelHeight + 30.0) * 1.5)
            case FlowNodeShape.CrossedCircle => return 60.0
            case FlowNodeShape.TaggedProcess => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.TaggedDocument => return max(62.0, labelHeight + 38.0)
            case FlowNodeShape.Flag => return max(64.0, labelHeight + 40.0)
            case FlowNodeShape.Hourglass => return 30.0
            case FlowNodeShape.NotchedPentagon => return max(58.0, labelHeight + 30.0)
            case FlowNodeShape.FlippedTriangle => return max(72.0, labelHeight + 48.0)
            case FlowNodeShape.Delay => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.CurvedTrapezoid => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.WindowPane => return max(64.0, labelHeight + 40.0)
            case FlowNodeShape.LinedCylinder => return max(72.0, labelHeight + 50.0)
            case FlowNodeShape.HorizontalCylinder => return max(58.0, labelHeight + 30.0)
            case FlowNodeShape.MultiDocument => return max(72.0, labelHeight + 48.0)
            case FlowNodeShape.LinedDocument => return max(62.0, labelHeight + 38.0)
            case FlowNodeShape.Bang => return max(62.0, labelHeight + 44.0)
            case FlowNodeShape.Cloud => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.LightningBolt => return 70.0
            case FlowNodeShape.BowTieRectangle => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.CurlyBraceLeft => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.CurlyBraceRight => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.CurlyBraces => return max(54.0, labelHeight + 30.0)
            case FlowNodeShape.Subroutine => return max(39.0, labelHeight + 15.0)
            case _ => return max(54.0, labelHeight + 30.0)
        }
    }

    private func computeDagreRankSizes(
        diagram: FlowchartDiagram,
        indexes: HashMap<String, Int64>,
        visualRanks: Array<Int64>,
        nodeWidths: Array<Float64>,
        nodeHeights: Array<Float64>,
        maxRank: Int64,
        horizontal: Bool
    ): Array<Float64> {
        let rankSizes = Array<Float64>(maxRank + 1, repeat: 0.0)
        for (i in 0..diagram.nodes.size) {
            let rank = visualRanks[i]
            let size = if (horizontal) { nodeWidths[i] } else { nodeHeights[i] }
            rankSizes[rank] = max(rankSizes[rank], size)
        }
        for (edge in diagram.edges) {
            if (let Some(label) <- edge.label) {
                if (let Some(sourceIndex) <- indexes.get(edge.source)) {
                    if (let Some(targetIndex) <- indexes.get(edge.target)) {
                        let sourceRank = visualRanks[sourceIndex]
                        let targetRank = visualRanks[targetIndex]
                        if (sourceRank == targetRank) {
                            continue
                        }
                        let labelRank = (sourceRank + targetRank) / 2
                        if (labelRank >= 0 && labelRank < rankSizes.size) {
                            let size = if (horizontal) { edgeLabelWidth(diagram.source, label.start, label.end) } else { 24.0 }
                            rankSizes[labelRank] = max(rankSizes[labelRank], size)
                        }
                    }
                }
            }
        }
        return rankSizes
    }

    private func computeRankHasRealNode(visualRanks: Array<Int64>, maxRank: Int64): Array<Bool> {
        let values = Array<Bool>(maxRank + 1, repeat: false)
        for (rank in visualRanks) {
            values[rank] = true
        }
        return values
    }

    private func computeDagreRankOffsets(rankSizes: Array<Float64>, rankHasRealNode: Array<Bool>, margin: Float64): Array<Float64> {
        let offsets = Array<Float64>(rankSizes.size, repeat: margin)
        for (rank in 1..offsets.size) {
            let rankSep = if (!rankHasRealNode[rank - 1] || !rankHasRealNode[rank]) { 32.0 } else { 50.0 }
            offsets[rank] = offsets[rank - 1] + rankSizes[rank - 1] + rankSep
        }
        return offsets
    }

    private func edgeMinLen(diagram: FlowchartDiagram, source: String, target: String): Int64 {
        for (edge in diagram.edges) {
            if (edge.source == source && edge.target == target && edge.label.isSome()) {
                return 2
            }
        }
        for (edge in diagram.edges) {
            if (edge.source == source && edge.label.isSome()) {
                return 2
            }
        }
        return 1
    }

    private func computeDagreCrossCenters(
        diagram: FlowchartDiagram,
        visualRanks: Array<Int64>,
        slotHints: Array<Float64>,
        minSlotHint: Float64,
        nodeWidths: Array<Float64>,
        nodeHeights: Array<Float64>,
        horizontal: Bool,
        margin: Float64
    ): Array<Float64> {
        let normalizedSlots = Array<Float64>(slotHints.size, { i => slotHints[i] - minSlotHint })
        let templateRank = densestRank(visualRanks)
        let templateIndexes = indexesForRank(visualRanks, templateRank)
        sortIndexesByHint(templateIndexes, normalizedSlots)
        let templateSlots = ArrayList<Float64>()
        let templateCenters = ArrayList<Float64>()
        var cursor = margin
        for (idx in templateIndexes) {
            let size = if (horizontal) { nodeHeights[idx] } else { nodeWidths[idx] }
            templateSlots.add(normalizedSlots[idx])
            templateCenters.add(cursor + size / 2.0)
            cursor += size + 50.0
        }
        if (templateCenters.isEmpty()) {
            return Array<Float64>(diagram.nodes.size, repeat: margin + 27.0)
        }
        return Array<Float64>(diagram.nodes.size, { i =>
            centerForSlot(normalizedSlots[i], templateSlots, templateCenters)
        })
    }

    private func densestRank(ranks: Array<Int64>): Int64 {
        let seen = ArrayList<Int64>()
        var bestRank: Int64 = 0
        var bestCount: Int64 = 0
        for (rank in ranks) {
            if (containsInt64(seen, rank)) {
                continue
            }
            seen.add(rank)
            var count: Int64 = 0
            for (candidate in ranks) {
                if (candidate == rank) {
                    count++
                }
            }
            if (count > bestCount || (count == bestCount && rank > bestRank)) {
                bestCount = count
                bestRank = rank
            }
        }
        return bestRank
    }

    private func indexesForRank(ranks: Array<Int64>, rank: Int64): ArrayList<Int64> {
        let indexes = ArrayList<Int64>()
        for (i in 0..ranks.size) {
            if (ranks[i] == rank) {
                indexes.add(i)
            }
        }
        return indexes
    }

    private func sortIndexesByHint(indexes: ArrayList<Int64>, hints: Array<Float64>): Unit {
        for (i in 0..indexes.size) {
            var best = i
            var j = i + 1
            while (j < indexes.size) {
                if (hints[indexes[j]] < hints[indexes[best]]) {
                    best = j
                }
                j++
            }
            if (best != i) {
                let temp = indexes[i]
                indexes[i] = indexes[best]
                indexes[best] = temp
            }
        }
    }

    private func centerForSlot(slot: Float64, templateSlots: ArrayList<Float64>, templateCenters: ArrayList<Float64>): Float64 {
        if (templateSlots.size == 1) {
            return templateCenters[0]
        }
        if (slot <= templateSlots[0]) {
            return extrapolateSlot(slot, templateSlots[0], templateCenters[0], templateSlots[1], templateCenters[1])
        }
        var i: Int64 = 1
        while (i < templateSlots.size) {
            if (slot <= templateSlots[i]) {
                return extrapolateSlot(slot, templateSlots[i - 1], templateCenters[i - 1], templateSlots[i], templateCenters[i])
            }
            i++
        }
        let last = templateSlots.size - 1
        return extrapolateSlot(slot, templateSlots[last - 1], templateCenters[last - 1], templateSlots[last], templateCenters[last])
    }

    private func extrapolateSlot(slot: Float64, leftSlot: Float64, leftCenter: Float64, rightSlot: Float64, rightCenter: Float64): Float64 {
        let deltaSlot = rightSlot - leftSlot
        if (deltaSlot == 0.0) {
            return leftCenter
        }
        return leftCenter + (slot - leftSlot) * (rightCenter - leftCenter) / deltaSlot
    }

    private func labelPositionForEdge(diagram: FlowchartDiagram, sourceId: String, targetId: String, positions: HashMap<String, LayoutNode>, horizontal: Bool): Array<?Float64> {
        var hasLabel = false
        for (edge in diagram.edges) {
            if (edge.source == sourceId && edge.target == targetId && edge.label.isSome()) {
                hasLabel = true
                break
            }
        }
        if (!hasLabel) {
            return [None, None]
        }
        let source = positions.get(sourceId).getOrThrow()
        let target = positions.get(targetId).getOrThrow()
        if (horizontal) {
            return [Some((centerX(source) + centerX(target)) / 2.0), Some(centerY(target))]
        }
        return [Some(centerX(target)), Some((centerY(source) + centerY(target)) / 2.0)]
    }

    private func resolveRankOverlaps(nodes: Array<LayoutNode>, ranks: Array<Int64>, horizontal: Bool, margin: Float64, gap: Float64): Unit {
        let seenRanks = ArrayList<Int64>()
        for (rank in ranks) {
            if (!containsInt64(seenRanks, rank)) {
                seenRanks.add(rank)
            }
        }
        for (rank in seenRanks) {
            let indexes = ArrayList<Int64>()
            for (i in 0..ranks.size) {
                if (ranks[i] == rank) {
                    indexes.add(i)
                }
            }
            sortLayoutIndexesBySlot(indexes, nodes, horizontal)
            var nextStart = margin
            for (idx in indexes) {
                let node = nodes[idx]
                if (horizontal) {
                    let y = max(node.y, nextStart)
                    nodes[idx] = LayoutNode(node.id, node.x, y, node.width, node.height)
                    nextStart = y + node.height + gap
                } else {
                    let x = max(node.x, nextStart)
                    nodes[idx] = LayoutNode(node.id, x, node.y, node.width, node.height)
                    nextStart = x + node.width + gap
                }
            }
        }
    }

    private func computeRankOffsets(
        diagram: FlowchartDiagram,
        indexes: HashMap<String, Int64>,
        visualRanks: Array<Int64>,
        nodeWidths: Array<Float64>,
        nodeHeights: Array<Float64>,
        maxRank: Int64,
        horizontal: Bool
    ): Array<Float64> {
        let baseRankGap = 128.0
        let offsets = Array<Float64>(maxRank + 1, { i => Float64(i) * baseRankGap })
        var changed = true
        while (changed) {
            changed = false
            for (rank in 1..offsets.size) {
                let required = offsets[rank - 1] + baseRankGap
                if (offsets[rank] < required) {
                    offsets[rank] = required
                    changed = true
                }
            }
            for (edge in diagram.edges) {
                if (edge.label.isNone()) {
                    continue
                }
                if (let Some(sourceIndex) <- indexes.get(edge.source)) {
                    if (let Some(targetIndex) <- indexes.get(edge.target)) {
                        let sourceRank = visualRanks[sourceIndex]
                        let targetRank = visualRanks[targetIndex]
                        if (sourceRank == targetRank) {
                            continue
                        }
                        let lowerRank = min(sourceRank, targetRank)
                        let upperRank = max(sourceRank, targetRank)
                        if (upperRank != lowerRank + 1) {
                            continue
                        }
                        let lowerIndex = if (sourceRank < targetRank) { sourceIndex } else { targetIndex }
                        let labelRange = edge.label.getOrThrow()
                        let labelSpace = estimatedEdgeLabelWidth(diagram.source, labelRange.start, labelRange.end) + 16.0
                        let nodeSpan = if (horizontal) { nodeWidths[lowerIndex] } else { nodeHeights[lowerIndex] }
                        let required = offsets[lowerRank] + nodeSpan + labelSpace
                        if (offsets[upperRank] < required) {
                            offsets[upperRank] = required
                            changed = true
                        }
                    }
                }
            }
        }
        return offsets
    }

    private func estimatedEdgeLabelWidth(source: String, start: Int64, end: Int64): Float64 {
        return edgeLabelWidth(source, start, end)
    }

    private func edgeLabelWidth(source: String, start: Int64, end: Int64): Float64 {
        return max(24.0, textMeasurer.measureText(source[start..end]) + 12.0)
    }

    private func sortLayoutIndexesBySlot(indexes: ArrayList<Int64>, nodes: Array<LayoutNode>, horizontal: Bool): Unit {
        for (i in 0..indexes.size) {
            var best = i
            var j = i + 1
            while (j < indexes.size) {
                let current = nodes[indexes[j]]
                let selected = nodes[indexes[best]]
                let currentSlot = if (horizontal) { current.y } else { current.x }
                let selectedSlot = if (horizontal) { selected.y } else { selected.x }
                if (currentSlot < selectedSlot) {
                    best = j
                }
                j++
            }
            if (best != i) {
                let temp = indexes[i]
                indexes[i] = indexes[best]
                indexes[best] = temp
            }
        }
    }

    private func containsInt64(values: ArrayList<Int64>, value: Int64): Bool {
        for (item in values) {
            if (item == value) {
                return true
            }
        }
        return false
    }

    private func centerX(node: LayoutNode): Float64 {
        return node.x + node.width / 2.0
    }

    private func centerY(node: LayoutNode): Float64 {
        return node.y + node.height / 2.0
    }

    private func boundaryPoint(shape: FlowNodeShape, node: LayoutNode, towardX: Float64, towardY: Float64): AnchorPoint {
        let cx = centerX(node)
        let cy = centerY(node)
        let dx = towardX - cx
        let dy = towardY - cy
        if (dx == 0.0 && dy == 0.0) {
            return AnchorPoint(cx, cy)
        }
        match (shape) {
            case FlowNodeShape.Diamond =>
                let diamond = [
                    DagrePoint(node.width / 2.0, 0.0),
                    DagrePoint(node.width, node.height / 2.0),
                    DagrePoint(node.width / 2.0, node.height),
                    DagrePoint(0.0, node.height / 2.0)
                ]
                let point = intersectPolygon(toDagreNode(node), diamond, DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Circle =>
                let radius = max(node.width, node.height) / 2.0
                let point = intersectEllipse(toDagreNode(node), radius, radius, DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Ellipse =>
                let point = intersectEllipse(toDagreNode(node), node.width / 2.0, node.height / 2.0, DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.DoubleCircle | FlowNodeShape.SmallCircle | FlowNodeShape.FramedCircle | FlowNodeShape.FilledCircle | FlowNodeShape.CrossedCircle =>
                let radius = max(node.width, node.height) / 2.0
                let point = intersectEllipse(toDagreNode(node), radius, radius, DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Cylinder =>
                let point = intersectCylinder(toDagreNode(node), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.LinedCylinder =>
                let point = intersectCylinder(toDagreNode(node), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.HorizontalCylinder =>
                return intersectHorizontalCylinder(node, towardX, towardY)
            case FlowNodeShape.Hexagon =>
                let point = intersectPolygon(toDagreNode(node), hexagonPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.LeanRight =>
                let point = intersectPolygon(toDagreNode(node), leanRightPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.LeanLeft =>
                let point = intersectPolygon(toDagreNode(node), leanLeftPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Trapezoid =>
                let point = intersectPolygon(toDagreNode(node), trapezoidPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.InvTrapezoid =>
                let point = intersectPolygon(toDagreNode(node), invTrapezoidPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Card =>
                let point = intersectPolygon(toDagreNode(node), cardPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Document =>
                let point = intersectPolygon(toDagreNode(node), documentPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.MultiProcess =>
                let point = intersectPolygon(toDagreNode(node), multiProcessOuterPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Triangle =>
                let point = intersectPolygon(toDagreNode(node), trianglePoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.SlopedRectangle =>
                let point = intersectPolygon(toDagreNode(node), slopedRectanglePoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.TaggedProcess =>
                let point = intersectPolygon(toDagreNode(node), taggedRectPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.TaggedDocument | FlowNodeShape.Flag =>
                let point = intersectPolygon(toDagreNode(node), waveRectanglePoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.LinedDocument =>
                let point = intersectPolygon(toDagreNode(node), waveRectanglePoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.MultiDocument =>
                let point = intersectPolygon(toDagreNode(node), multiDocumentOuterPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Hourglass =>
                let point = intersectPolygon(toDagreNode(node), hourglassPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.NotchedPentagon =>
                let point = intersectPolygon(toDagreNode(node), notchedPentagonPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.FlippedTriangle =>
                let point = intersectPolygon(toDagreNode(node), flippedTrianglePoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Delay =>
                let point = intersectPolygon(toDagreNode(node), delayPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.CurvedTrapezoid =>
                let point = intersectPolygon(toDagreNode(node), curvedTrapezoidPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.WindowPane =>
                let point = intersectPolygon(toDagreNode(node), windowPaneOuterPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.LightningBolt =>
                let point = intersectPolygon(toDagreNode(node), lightningBoltPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.BowTieRectangle =>
                let point = intersectPolygon(toDagreNode(node), bowTieRectanglePoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.CurlyBraceLeft =>
                let point = intersectPolygon(toDagreNode(node), curlyBraceLeftBounds(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.CurlyBraceRight =>
                let point = intersectPolygon(toDagreNode(node), curlyBraceRightBounds(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.CurlyBraces =>
                let point = intersectPolygon(toDagreNode(node), windowPaneOuterPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case FlowNodeShape.Odd =>
                let point = intersectPolygon(toDagreNode(node), oddPoints(node.width, node.height), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
            case _ =>
                let point = intersectRect(toDagreNode(node), DagrePoint(towardX, towardY))
                return AnchorPoint(point.x, point.y)
        }
    }

    private func hexagonPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let m = height / 4.0
        return [
            DagrePoint(m, 0.0),
            DagrePoint(width - m, 0.0),
            DagrePoint(width, height / 2.0),
            DagrePoint(width - m, height),
            DagrePoint(m, height),
            DagrePoint(0.0, height / 2.0)
        ]
    }

    private func leanRightPoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint((2.0 * height) / 6.0, 0.0),
            DagrePoint(width + height / 6.0, 0.0),
            DagrePoint(width - (2.0 * height) / 6.0, height),
            DagrePoint(0.0 - height / 6.0, height)
        ]
    }

    private func leanLeftPoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(0.0 - (2.0 * height) / 6.0, 0.0),
            DagrePoint(width - height / 6.0, 0.0),
            DagrePoint(width + (2.0 * height) / 6.0, height),
            DagrePoint(height / 6.0, height)
        ]
    }

    private func trapezoidPoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(0.0 - (2.0 * height) / 6.0, 0.0),
            DagrePoint(width + (2.0 * height) / 6.0, 0.0),
            DagrePoint(width - height / 6.0, height),
            DagrePoint(height / 6.0, height)
        ]
    }

    private func invTrapezoidPoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(height / 6.0, 0.0),
            DagrePoint(width - height / 6.0, 0.0),
            DagrePoint(width + (2.0 * height) / 6.0, height),
            DagrePoint(0.0 - (2.0 * height) / 6.0, height)
        ]
    }

    private func cardPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let notch = 12.0
        return [
            DagrePoint(notch, 0.0),
            DagrePoint(width, 0.0),
            DagrePoint(width, height),
            DagrePoint(0.0, height),
            DagrePoint(0.0, notch)
        ]
    }

    private func documentPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let wave = height / 8.0
        return [
            DagrePoint(0.0, 0.0),
            DagrePoint(width, 0.0),
            DagrePoint(width, height - wave),
            DagrePoint(width * 0.75, height),
            DagrePoint(width * 0.5, height - wave),
            DagrePoint(width * 0.25, height - (wave * 2.0)),
            DagrePoint(0.0, height - wave)
        ]
    }

    private func multiProcessOuterPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let offset = 5.0
        return [
            DagrePoint(0.0, offset),
            DagrePoint(0.0, height),
            DagrePoint(width - offset, height),
            DagrePoint(width - offset, height - offset),
            DagrePoint(width, height - offset),
            DagrePoint(width, 0.0),
            DagrePoint(offset, 0.0),
            DagrePoint(offset, offset)
        ]
    }

    private func trianglePoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(0.0, height),
            DagrePoint(width, height),
            DagrePoint(width / 2.0, 0.0)
        ]
    }

    private func slopedRectanglePoints(width: Float64, height: Float64): Array<DagrePoint> {
        let h = height / 1.5
        return [
            DagrePoint(0.0, h / 2.0),
            DagrePoint(0.0, h + h / 2.0),
            DagrePoint(width, h + h / 2.0),
            DagrePoint(width, 0.0)
        ]
    }

    private func taggedRectPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let tag = height * 0.2
        return [
            DagrePoint(0.0, 0.0),
            DagrePoint(width, 0.0),
            DagrePoint(width, height),
            DagrePoint(0.0, height)
        ]
    }

    private func waveRectanglePoints(width: Float64, height: Float64): Array<DagrePoint> {
        let wave = height / 8.0
        return [
            DagrePoint(0.0, wave),
            DagrePoint(width * 0.25, 0.0),
            DagrePoint(width * 0.5, wave),
            DagrePoint(width * 0.75, wave * 2.0),
            DagrePoint(width, wave),
            DagrePoint(width, height - wave),
            DagrePoint(width * 0.75, height),
            DagrePoint(width * 0.5, height - wave),
            DagrePoint(width * 0.25, height - (wave * 2.0)),
            DagrePoint(0.0, height - wave)
        ]
    }

    private func hourglassPoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(0.0, 0.0),
            DagrePoint(width, 0.0),
            DagrePoint(0.0, height),
            DagrePoint(width, height)
        ]
    }

    private func notchedPentagonPoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(width * 0.1, 0.0),
            DagrePoint(width * 0.9, 0.0),
            DagrePoint(width, height * 0.2),
            DagrePoint(width, height),
            DagrePoint(0.0, height),
            DagrePoint(0.0, height * 0.2)
        ]
    }

    private func flippedTrianglePoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(0.0, 0.0),
            DagrePoint(width, 0.0),
            DagrePoint(width / 2.0, height)
        ]
    }

    private func delayPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let radius = height / 2.0
        return [
            DagrePoint(0.0, 0.0),
            DagrePoint(width - radius, 0.0),
            DagrePoint(width, radius),
            DagrePoint(width - radius, height),
            DagrePoint(0.0, height)
        ]
    }

    private func curvedTrapezoidPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let radius = height / 2.0
        let rw = width - radius
        let tw = height / 4.0
        return [
            DagrePoint(rw, 0.0),
            DagrePoint(tw, 0.0),
            DagrePoint(0.0, height / 2.0),
            DagrePoint(tw, height),
            DagrePoint(rw, height),
            DagrePoint(width, height * 0.75),
            DagrePoint(width, height * 0.25)
        ]
    }

    private func windowPaneOuterPoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(0.0, 0.0),
            DagrePoint(width, 0.0),
            DagrePoint(width, height),
            DagrePoint(0.0, height)
        ]
    }

    private func multiDocumentOuterPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let offset = 10.0
        let base = waveRectanglePoints(width - offset, height - offset)
        let out = ArrayList<DagrePoint>()
        for (point in base) {
            out.add(DagrePoint(point.x, point.y + offset))
        }
        out.add(DagrePoint(width - offset, height - offset))
        out.add(DagrePoint(width, height - offset))
        out.add(DagrePoint(width, 0.0))
        out.add(DagrePoint(offset, 0.0))
        return out.toArray()
    }

    private func intersectHorizontalCylinder(node: LayoutNode, towardX: Float64, towardY: Float64): AnchorPoint {
        let dagreNode = toDagreNode(node)
        let rectPoint = intersectRect(dagreNode, DagrePoint(towardX, towardY))
        let ry = node.height / 2.0
        let rx = ry / (2.5 + node.height / 50.0)
        let cy = centerY(node)
        let y = rectPoint.y - cy
        if (ry != 0.0 && (absFloat(y) < node.height / 2.0 || (absFloat(y) == node.height / 2.0 && absFloat(rectPoint.x - centerX(node)) > node.width / 2.0 - rx))) {
            var x = rx * rx * (1.0 - (y * y) / (ry * ry))
            if (x > 0.0) {
                x = sqrtFloat(x)
            }
            x = rx - x
            if (towardX - centerX(node) > 0.0) {
                x = -x
            }
            return AnchorPoint(rectPoint.x + x, rectPoint.y)
        }
        return AnchorPoint(rectPoint.x, rectPoint.y)
    }

    private func lightningBoltPoints(width: Float64, height: Float64): Array<DagrePoint> {
        let h = height / 2.0
        let gap = 7.0
        return [
            DagrePoint(width, 0.0),
            DagrePoint(0.0, h + gap / 2.0),
            DagrePoint(width - 2.0 * gap, h + gap / 2.0),
            DagrePoint(0.0, 2.0 * h),
            DagrePoint(width, h - gap / 2.0),
            DagrePoint(2.0 * gap, h - gap / 2.0)
        ]
    }

    private func bowTieRectanglePoints(width: Float64, height: Float64): Array<DagrePoint> {
        let inset = min(width * 0.12, height * 0.24)
        return [
            DagrePoint(inset, 0.0),
            DagrePoint(width - inset, 0.0),
            DagrePoint(width, height * 0.25),
            DagrePoint(width, height * 0.75),
            DagrePoint(width - inset, height),
            DagrePoint(inset, height),
            DagrePoint(0.0, height * 0.75),
            DagrePoint(0.0, height * 0.25)
        ]
    }

    private func curlyBraceLeftBounds(width: Float64, height: Float64): Array<DagrePoint> {
        let radius = max(5.0, height * 0.1)
        return [
            DagrePoint(radius, 0.0),
            DagrePoint(width, 0.0),
            DagrePoint(width, height),
            DagrePoint(radius, height),
            DagrePoint(0.0, height / 2.0)
        ]
    }

    private func curlyBraceRightBounds(width: Float64, height: Float64): Array<DagrePoint> {
        let radius = max(5.0, height * 0.1)
        return [
            DagrePoint(0.0, 0.0),
            DagrePoint(width - radius, 0.0),
            DagrePoint(width, height / 2.0),
            DagrePoint(width - radius, height),
            DagrePoint(0.0, height)
        ]
    }

    private func oddPoints(width: Float64, height: Float64): Array<DagrePoint> {
        return [
            DagrePoint(0.0, 0.0),
            DagrePoint(width, 0.0),
            DagrePoint(width, height),
            DagrePoint(0.0, height),
            DagrePoint(width * 0.18, height / 2.0)
        ]
    }

    private func sqrtFloat(value: Float64): Float64 {
        var x = if (value > 1.0) { value } else { 1.0 }
        var i: Int64 = 0
        while (i < 12) {
            x = (x + value / x) / 2.0
            i++
        }
        return x
    }

    private func toDagreNode(node: LayoutNode): DagreNode {
        return DagreNode(node.id, x: Some(centerX(node)), y: Some(centerY(node)), width: Some(node.width), height: Some(node.height))
    }

    private func absFloat(value: Float64): Float64 {
        if (value < 0.0) {
            return -value
        }
        return value
    }

    private func computeSlotHints(diagram: FlowchartDiagram, ranks: Array<Int64>): Array<Float64> {
        let indexes = HashMap<String, Int64>()
        for (i in 0..diagram.nodes.size) {
            indexes[diagram.nodes[i].id] = i
        }
        let hints = Array<Float64>(diagram.nodes.size, repeat: 0.0)
        let counts = Array<Int64>(diagram.nodes.size, repeat: 0)
        for (i in 0..diagram.nodes.size) {
            if (ranks[i] == 0) {
                hints[i] = Float64(i)
                counts[i] = 1
            }
        }

        var maxRank: Int64 = 0
        for (rank in ranks) {
            maxRank = max(maxRank, rank)
        }

        for (rank in 0..(maxRank + 1)) {
            for (sourceIndex in 0..diagram.nodes.size) {
                if (ranks[sourceIndex] != rank || counts[sourceIndex] == 0) {
                    continue
                }
                let outgoing = forwardOutgoingIndexes(diagram, indexes, ranks, sourceIndex)
                for (j in 0..outgoing.size) {
                    let targetIndex = outgoing[j]
                    let offset = if (outgoing.size == 1) {
                        0.0
                    } else if (hints[sourceIndex] < 0.0) {
                        Float64(j)
                    } else {
                        Float64(j) - (Float64(outgoing.size - 1) / 2.0)
                    }
                    hints[targetIndex] = hints[targetIndex] + hints[sourceIndex] + offset
                    counts[targetIndex] = counts[targetIndex] + 1
                }
            }
            for (i in 0..diagram.nodes.size) {
                if (counts[i] > 1 && ranks[i] == rank + 1) {
                    hints[i] = hints[i] / Float64(counts[i])
                    counts[i] = 1
                }
            }
        }
        refineParentHints(diagram, indexes, ranks, hints)
        return hints
    }

    private func computeDagreSlotHints(diagram: FlowchartDiagram, edges: Array<DagreEdge>, ranks: Array<Int64>): Array<Float64> {
        let indexes = HashMap<String, Int64>()
        for (i in 0..diagram.nodes.size) {
            indexes[diagram.nodes[i].id] = i
        }
        let hints = Array<Float64>(diagram.nodes.size, repeat: 0.0)
        let counts = Array<Int64>(diagram.nodes.size, repeat: 0)
        for (i in 0..diagram.nodes.size) {
            if (ranks[i] == 0) {
                hints[i] = Float64(i)
                counts[i] = 1
            }
        }

        var maxRank: Int64 = 0
        for (rank in ranks) {
            maxRank = max(maxRank, rank)
        }

        for (rank in 0..(maxRank + 1)) {
            for (sourceIndex in 0..diagram.nodes.size) {
                if (ranks[sourceIndex] != rank || counts[sourceIndex] == 0) {
                    continue
                }
                let outgoing = forwardDagreOutgoingIndexes(diagram, edges, indexes, ranks, sourceIndex)
                for (j in 0..outgoing.size) {
                    let targetIndex = outgoing[j]
                    let offset = if (outgoing.size == 1) {
                        0.0
                    } else if (hints[sourceIndex] < 0.0) {
                        Float64(j)
                    } else {
                        Float64(j) - (Float64(outgoing.size - 1) / 2.0)
                    }
                    hints[targetIndex] = hints[targetIndex] + hints[sourceIndex] + offset
                    counts[targetIndex] = counts[targetIndex] + 1
                }
            }
            for (i in 0..diagram.nodes.size) {
                if (counts[i] > 1 && ranks[i] == rank + 1) {
                    hints[i] = hints[i] / Float64(counts[i])
                    counts[i] = 1
                }
            }
        }
        refineDagreParentHints(diagram, edges, indexes, ranks, hints)
        return hints
    }

    private func refineDagreParentHints(diagram: FlowchartDiagram, edges: Array<DagreEdge>, indexes: HashMap<String, Int64>, ranks: Array<Int64>, hints: Array<Float64>): Unit {
        var maxRank: Int64 = 0
        for (rank in ranks) {
            maxRank = max(maxRank, rank)
        }
        for (rankOffset in 0..(maxRank + 1)) {
            let rank = maxRank - rankOffset
            for (sourceIndex in 0..diagram.nodes.size) {
                if (ranks[sourceIndex] != rank) {
                    continue
                }
                let outgoing = forwardDagreOutgoingIndexes(diagram, edges, indexes, ranks, sourceIndex)
                if (outgoing.isEmpty()) {
                    continue
                }
                if (outgoing.size == 1) {
                    if (incomingDagreCount(edges, diagram.nodes[outgoing[0]].id) <= 1) {
                        hints[sourceIndex] = hints[outgoing[0]]
                    }
                    continue
                }
                var sumTargetHint = 0.0
                for (targetIndex in outgoing) {
                    sumTargetHint += hints[targetIndex]
                }
                hints[sourceIndex] = sumTargetHint / Float64(outgoing.size)
            }
        }
    }

    private func forwardDagreOutgoingIndexes(diagram: FlowchartDiagram, edges: Array<DagreEdge>, indexes: HashMap<String, Int64>, ranks: Array<Int64>, sourceIndex: Int64): Array<Int64> {
        let out = ArrayList<Int64>()
        let sourceId = diagram.nodes[sourceIndex].id
        for (edge in edges) {
            if (edge.start != sourceId || edge.start == edge.end) {
                continue
            }
            if (isReverseOfDoubleEndedEdge(diagram, edge.start, edge.end)) {
                continue
            }
            if (let Some(targetIndex) <- indexes.get(edge.end)) {
                if (ranks[targetIndex] > ranks[sourceIndex]) {
                    out.add(targetIndex)
                }
            }
        }
        return out.toArray()
    }

    private func incomingDagreCount(edges: Array<DagreEdge>, nodeId: String): Int64 {
        var count: Int64 = 0
        for (edge in edges) {
            if (edge.end == nodeId && edge.start != edge.end) {
                count++
            }
        }
        return count
    }

    private func refineParentHints(diagram: FlowchartDiagram, indexes: HashMap<String, Int64>, ranks: Array<Int64>, hints: Array<Float64>): Unit {
        var maxRank: Int64 = 0
        for (rank in ranks) {
            maxRank = max(maxRank, rank)
        }
        for (rankOffset in 0..(maxRank + 1)) {
            let rank = maxRank - rankOffset
            for (sourceIndex in 0..diagram.nodes.size) {
                if (ranks[sourceIndex] != rank) {
                    continue
                }
                let outgoing = forwardOutgoingIndexes(diagram, indexes, ranks, sourceIndex)
                if (outgoing.isEmpty()) {
                    continue
                }
                if (outgoing.size == 1) {
                    hints[sourceIndex] = hints[outgoing[0]]
                    continue
                }
                var hasLongEdge = false
                var maxTargetHint = hints[outgoing[0]]
                for (targetIndex in outgoing) {
                    if (ranks[targetIndex] > ranks[sourceIndex] + 1) {
                        hasLongEdge = true
                    }
                    maxTargetHint = max(maxTargetHint, hints[targetIndex])
                }
                if (hasLongEdge) {
                    hints[sourceIndex] = maxTargetHint
                }
            }
        }
    }

    private func forwardOutgoingIndexes(diagram: FlowchartDiagram, indexes: HashMap<String, Int64>, ranks: Array<Int64>, sourceIndex: Int64): Array<Int64> {
        let out = ArrayList<Int64>()
        let sourceId = diagram.nodes[sourceIndex].id
        for (edge in diagram.edges) {
            if (edge.source != sourceId) {
                continue
            }
            if (isReverseOfDoubleEndedEdge(diagram, edge.source, edge.target)) {
                continue
            }
            if (let Some(targetIndex) <- indexes.get(edge.target)) {
                if (ranks[targetIndex] > ranks[sourceIndex]) {
                    out.add(targetIndex)
                }
            }
        }
        return out.toArray()
    }

    private func isReverseOfDoubleEndedEdge(diagram: FlowchartDiagram, source: String, target: String): Bool {
        for (edge in diagram.edges) {
            if (edge.source == target && edge.target == source && hasStartMarker(edge.markerStart)) {
                return true
            }
        }
        return false
    }

    private func hasStartMarker(marker: FlowEdgeMarker): Bool {
        match (marker) {
            case FlowEdgeMarker.None => return false
            case _ => return true
        }
    }

    private func isHorizontal(direction: FlowDirection): Bool {
        match (direction) {
            case FlowDirection.LR => return true
            case FlowDirection.RL => return true
            case _ => return false
        }
    }

    private func isReverse(direction: FlowDirection): Bool {
        match (direction) {
            case FlowDirection.RL => return true
            case FlowDirection.BT => return true
            case _ => return false
        }
    }

    private func directionName(direction: FlowDirection): String {
        match (direction) {
            case FlowDirection.TD => return "TD"
            case FlowDirection.TB => return "TB"
            case FlowDirection.BT => return "BT"
            case FlowDirection.LR => return "LR"
            case FlowDirection.RL => return "RL"
        }
    }

    private func nodeLabelVisualWidth(source: String, start: Int64, end: Int64, labelText: ?String): Float64 {
        if (let Some(text) <- labelText) {
            var longest = 0.0
            var lineStart: Int64 = 0
            var i: Int64 = 0
            while (i < text.size) {
                if (text[i] == b'\n' || text[i] == b'\r') {
                    longest = max(longest, textMeasurer.measureText(text[lineStart..i]))
                    if (text[i] == b'\r' && i + 1 < text.size && text[i + 1] == b'\n') {
                        i++
                    }
                    lineStart = i + 1
                }
                i++
            }
            return max(longest, textMeasurer.measureText(text[lineStart..text.size]))
        }
        return textMeasurer.measureText(source[start..end])
    }

    private func countNodeLabelLines(source: String, start: Int64, end: Int64, labelText: ?String): Int64 {
        if (let Some(text) <- labelText) {
            return textMeasurer.countLines(text)
        }
        return 1
    }
}
