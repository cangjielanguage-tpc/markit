package mermaid4cj.layout.dagre

import std.collection.ArrayList

class SelfLoopGroup {
    let id: String
    let segments: ArrayList<DagreEdgeRef>

    init(id: String) {
        this.id = id
        this.segments = ArrayList<DagreEdgeRef>()
    }
}

class SelfLoopLabelSize {
    let width: Float64
    let height: Float64

    init(width: Float64, height: Float64) {
        this.width = width
        this.height = height
    }
}

public func shouldMergeSelfLoopSegments(diagramType: String): Bool {
    return diagramType == "flowchart" || diagramType == "flowchart-v2" || diagramType == "stateDiagram"
}

func getDefaultSelfLoopSide(rankdir: ?String): String {
    if (let Some(value) <- rankdir) {
        match (value) {
            case "BT" => return "bottom"
            case "LR" => return "right"
            case "RL" => return "left"
            case _ => return "top"
        }
    }
    return "top"
}

func getSelfLoopSide(graph: MermaidDagreGraph, node: DagreNode, segments: Array<DagreEdgeRef>, originalNodeId: String, rankdir: ?String): String {
    let layoutHints = ArrayList<DagrePoint>()
    let dummyNodeIds = ArrayList<String>()

    for (segment in segments) {
        if (segment.start != originalNodeId && !containsString(dummyNodeIds, segment.start)) {
            dummyNodeIds.add(segment.start)
        }
        if (segment.end != originalNodeId && !containsString(dummyNodeIds, segment.end)) {
            dummyNodeIds.add(segment.end)
        }
    }

    for (id in dummyNodeIds) {
        if (let Some(dummyNode) <- graph.node(id)) {
            if (let Some(x) <- dummyNode.x) {
                if (let Some(y) <- dummyNode.y) {
                    layoutHints.add(DagrePoint(x, y))
                }
            }
        }
    }

    if (layoutHints.isEmpty()) {
        for (segment in segments) {
            for (point in segment.edge.points) {
                layoutHints.add(point)
            }
        }
    }

    if (layoutHints.isEmpty()) {
        return getDefaultSelfLoopSide(rankdir)
    }

    var centerX = 0.0
    var centerY = 0.0
    for (point in layoutHints) {
        centerX += point.x / Float64(layoutHints.size)
        centerY += point.y / Float64(layoutHints.size)
    }
    let nodeX = node.x ?? 0.0
    let nodeY = node.y ?? 0.0
    let dx = centerX - nodeX
    let dy = centerY - nodeY

    if (absFloat(dx) > absFloat(dy)) {
        if (dx > 0.0) {
            return "right"
        }
        return "left"
    }
    if (absFloat(dy) > 0.0) {
        if (dy > 0.0) {
            return "bottom"
        }
        return "top"
    }
    return getDefaultSelfLoopSide(rankdir)
}

func getSelfLoopPoints(node: DagreNode, side: String, yOffset: Float64, labelWidth: Float64): Array<DagrePoint> {
    let x = node.x ?? 0.0
    let y = (node.y ?? 0.0) - yOffset
    let width = node.width ?? 0.0
    let height = node.height ?? 0.0
    let halfWidth = width / 2.0
    let halfHeight = height / 2.0
    let maxSpan = maxFloat(36.0, minFloat(100.0, width * 0.8))
    let span = clamp(maxFloat(labelWidth, width * 0.35), 36.0, maxSpan)
    let depth = clamp(minFloat(width, height) * 0.45, 24.0, 48.0)

    match (side) {
        case "bottom" =>
            let bottom = y + halfHeight
            return [
                DagrePoint(x - span / 2.0, bottom),
                DagrePoint(x - span / 2.0, bottom + depth),
                DagrePoint(x + span / 2.0, bottom + depth),
                DagrePoint(x + span / 2.0, bottom)
            ]
        case "right" =>
            let right = x + halfWidth
            return [
                DagrePoint(right, y - span / 2.0),
                DagrePoint(right + depth, y - span / 2.0),
                DagrePoint(right + depth, y + span / 2.0),
                DagrePoint(right, y + span / 2.0)
            ]
        case "left" =>
            let left = x - halfWidth
            return [
                DagrePoint(left, y - span / 2.0),
                DagrePoint(left - depth, y - span / 2.0),
                DagrePoint(left - depth, y + span / 2.0),
                DagrePoint(left, y + span / 2.0)
            ]
        case _ =>
            let top = y - halfHeight
            return [
                DagrePoint(x - span / 2.0, top),
                DagrePoint(x - span / 2.0, top - depth),
                DagrePoint(x + span / 2.0, top - depth),
                DagrePoint(x + span / 2.0, top)
            ]
    }
}

func getSelfLoopLabelPosition(node: DagreNode, points: Array<DagrePoint>, side: String, yOffset: Float64, label: SelfLoopLabelSize): DagrePoint {
    let gap = 4.0
    let x = node.x ?? 0.0
    let y = (node.y ?? 0.0) - yOffset

    match (side) {
        case "bottom" => return DagrePoint(x, maxY(points) + label.height / 2.0 + gap)
        case "right" => return DagrePoint(maxX(points) + label.width / 2.0 + gap, y)
        case "left" => return DagrePoint(minX(points) - label.width / 2.0 - gap, y)
        case _ => return DagrePoint(x, minY(points) - label.height / 2.0 - gap)
    }
}

public func getEdgesToRender(graph: MermaidDagreGraph, yOffset!: Float64 = 0.0, mergeSelfLoops!: Bool = true): Array<DagreEdgeRef> {
    let selfLoopEdgeGroups = ArrayList<SelfLoopGroup>()
    let edgesToRender = ArrayList<DagreEdgeRef>()
    let rankdir = graph.rankdir()

    for (edgeRef in graph.edges()) {
        let edge = edgeRef.edge
        if (mergeSelfLoops) {
            if (let Some(selfLoop) <- edge.selfLoop) {
                let group = findOrAddGroup(selfLoopEdgeGroups, selfLoop.id)
                group.segments.add(edgeRef)
                continue
            }
        }
        edgesToRender.add(edgeRef)
    }

    for (group in selfLoopEdgeGroups) {
        if (group.segments.size != 3) {
            for (segment in group.segments) {
                edgesToRender.add(segment)
            }
            continue
        }

        let firstSegment = findSegmentByOrder(group.segments, 0) ?? group.segments[0]
        let middleSegment = findSegmentByOrder(group.segments, 1) ?? group.segments[1]
        let lastSegment = findSegmentByOrder(group.segments, 2) ?? group.segments[2]
        let originalEdge = firstSegment.edge.originalEdge ?? middleSegment.edge.originalEdge ?? lastSegment.edge.originalEdge ?? middleSegment.edge

        if (let Some(node) <- graph.node(originalEdge.start)) {
            let label = SelfLoopLabelSize(middleSegment.edge.width ?? 0.0, middleSegment.edge.height ?? 0.0)
            let segments = [firstSegment, middleSegment, lastSegment]
            let side = getSelfLoopSide(graph, node, segments, originalEdge.start, rankdir)
            let points = getSelfLoopPoints(node, side, yOffset, label.width)
            let labelPosition = getSelfLoopLabelPosition(node, points, side, yOffset, label)
            let mergedEdge = DagreEdge(
                originalEdge.id,
                originalEdge.start,
                originalEdge.end,
                label: originalEdge.label,
                arrowTypeStart: originalEdge.arrowTypeStart,
                arrowTypeEnd: originalEdge.arrowTypeEnd,
                length: originalEdge.length,
                points: points,
                x: Some(labelPosition.x),
                y: Some(labelPosition.y),
                width: Some(label.width),
                height: Some(label.height),
                labelStyle: middleSegment.edge.labelStyle,
                fromCluster: firstSegment.edge.fromCluster ?? middleSegment.edge.fromCluster ?? lastSegment.edge.fromCluster,
                toCluster: firstSegment.edge.toCluster ?? middleSegment.edge.toCluster ?? lastSegment.edge.toCluster
            )
            edgesToRender.add(DagreEdgeRef(mergedEdge, mergedEdge.start, mergedEdge.end, mergedEdge.id))
        } else {
            edgesToRender.add(firstSegment)
            edgesToRender.add(middleSegment)
            edgesToRender.add(lastSegment)
        }
    }

    return edgesToRender.toArray()
}

func findOrAddGroup(groups: ArrayList<SelfLoopGroup>, id: String): SelfLoopGroup {
    for (group in groups) {
        if (group.id == id) {
            return group
        }
    }
    let group = SelfLoopGroup(id)
    groups.add(group)
    return group
}

func findSegmentByOrder(segments: ArrayList<DagreEdgeRef>, order: Int64): ?DagreEdgeRef {
    for (segment in segments) {
        if (let Some(selfLoop) <- segment.edge.selfLoop) {
            if (selfLoop.order == order) {
                return Some(segment)
            }
        }
    }
    return None
}

func containsString(values: ArrayList<String>, value: String): Bool {
    for (item in values) {
        if (item == value) {
            return true
        }
    }
    return false
}

func clamp(value: Float64, minValue: Float64, maxValue: Float64): Float64 {
    return maxFloat(minValue, minFloat(maxValue, value))
}

func absFloat(value: Float64): Float64 {
    if (value < 0.0) {
        return -value
    }
    return value
}

func minFloat(left: Float64, right: Float64): Float64 {
    if (left < right) {
        return left
    }
    return right
}

func maxFloat(left: Float64, right: Float64): Float64 {
    if (left > right) {
        return left
    }
    return right
}

func minX(points: Array<DagrePoint>): Float64 {
    var value = points[0].x
    for (point in points) {
        value = minFloat(value, point.x)
    }
    return value
}

func maxX(points: Array<DagrePoint>): Float64 {
    var value = points[0].x
    for (point in points) {
        value = maxFloat(value, point.x)
    }
    return value
}

func minY(points: Array<DagrePoint>): Float64 {
    var value = points[0].y
    for (point in points) {
        value = minFloat(value, point.y)
    }
    return value
}

func maxY(points: Array<DagrePoint>): Float64 {
    var value = points[0].y
    for (point in points) {
        value = maxFloat(value, point.y)
    }
    return value
}
