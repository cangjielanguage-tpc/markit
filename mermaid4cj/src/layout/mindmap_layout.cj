package mermaid4cj.layout

import std.collection.{ArrayList, HashMap}
import std.math.{cos, sin, sqrt}
import mermaid4cj.core.{MermaidRenderOptions, MindmapDiagram, MindmapNode, MindmapNodeShape}

public let MindmapMaxSections: Int64 = 12

public class MindmapLayoutNode {
    public let id: String
    public let label: String
    public let level: Int64
    public let parentIndex: Int64
    public let section: ?Int64
    public let shape: MindmapNodeShape
    public let icon: String
    public let className: String
    public let cssClasses: String
    public let padding: Float64
    public let width: Float64
    public let height: Float64
    public let x: Float64
    public let y: Float64

    public init(
        id: String,
        label: String,
        level: Int64,
        parentIndex: Int64,
        section: ?Int64,
        shape: MindmapNodeShape,
        icon: String,
        className: String,
        cssClasses: String,
        padding: Float64,
        width: Float64,
        height: Float64,
        x: Float64,
        y: Float64
    ) {
        this.id = id
        this.label = label
        this.level = level
        this.parentIndex = parentIndex
        this.section = section
        this.shape = shape
        this.icon = icon
        this.className = className
        this.cssClasses = cssClasses
        this.padding = padding
        this.width = width
        this.height = height
        this.x = x
        this.y = y
    }
}

public class MindmapLayoutEdge {
    public let id: String
    public let source: String
    public let target: String
    public let depth: Int64
    public let section: ?Int64
    public let cssClasses: String
    public let points: Array<AnchorPoint>

    public init(id: String, source: String, target: String, depth: Int64, section: ?Int64, cssClasses: String, points!: Array<AnchorPoint> = []) {
        this.id = id
        this.source = source
        this.target = target
        this.depth = depth
        this.section = section
        this.cssClasses = cssClasses
        this.points = points
    }
}

public class MindmapLayoutResult {
    public let width: Float64
    public let height: Float64
    public let nodes: Array<MindmapLayoutNode>
    public let edges: Array<MindmapLayoutEdge>

    public init(width: Float64, height: Float64, nodes: Array<MindmapLayoutNode>, edges: Array<MindmapLayoutEdge>) {
        this.width = width
        this.height = height
        this.nodes = nodes
        this.edges = edges
    }
}

public class MindmapLayout {
    public init() {}

    public func layout(diagram: MindmapDiagram, options: MermaidRenderOptions): MindmapLayoutResult {
        if (diagram.nodes.isEmpty()) {
            return MindmapLayoutResult(360.0, 220.0, [], [])
        }
        let sections = assignSections(diagram)
        let widths = Array<Float64>(diagram.nodes.size, { i => nodeWidth(diagram.nodes[i], options) })
        let heights = Array<Float64>(diagram.nodes.size, { i => nodeHeight(diagram.nodes[i]) })
        let rawNodes = executeMindmapRadialLayout(diagram, widths, heights)
        let nodeOut = ArrayList<MindmapLayoutNode>()
        for (i in 0..diagram.nodes.size) {
            let node = diagram.nodes[i]
            let section = sections[i]
            nodeOut.add(MindmapLayoutNode(
                node.id,
                node.label,
                node.level,
                node.parentIndex,
                section,
                node.shape,
                node.icon,
                node.className,
                cssClasses(node, section, i == 0),
                paddingFor(node.shape),
                widths[i],
                heights[i],
                rawNodes[i].x,
                rawNodes[i].y
            ))
        }

        let edges = ArrayList<MindmapLayoutEdge>()
        for (i in 0..diagram.nodes.size) {
            let node = diagram.nodes[i]
            if (node.parentIndex >= 0) {
                let parent = nodeOut[node.parentIndex]
                let child = nodeOut[i]
                let depth = max(1, child.level / 2)
                let overlap = edgeEndpointOverlap(depth)
                let points = ArrayList<AnchorPoint>()
                points.add(boundaryPointInside(parent, child.x, child.y, overlap))
                points.add(AnchorPoint((parent.x + child.x) / 2.0, (parent.y + child.y) / 2.0))
                points.add(boundaryPointInside(child, parent.x, parent.y, overlap))
                edges.add(MindmapLayoutEdge("edge_${node.parentIndex}_${i}", parent.id, child.id, depth, child.section, edgeClasses(child.section, depth), points: points.toArray()))
            }
        }

        let bounds = computeBounds(nodeOut)
        let shiftedNodes = Array<MindmapLayoutNode>(nodeOut.size, { i =>
            let node = nodeOut[i]
            MindmapLayoutNode(node.id, node.label, node.level, node.parentIndex, node.section, node.shape, node.icon, node.className, node.cssClasses, node.padding, node.width, node.height, node.x - bounds.x + 42.0, node.y - bounds.y + 42.0)
        })
        let shiftedEdges = Array<MindmapLayoutEdge>(edges.size, { i =>
            let edge = edges[i]
            let shiftedPoints = Array<AnchorPoint>(edge.points.size, { p => AnchorPoint(edge.points[p].x - bounds.x + 42.0, edge.points[p].y - bounds.y + 42.0) })
            MindmapLayoutEdge(edge.id, edge.source, edge.target, edge.depth, edge.section, edge.cssClasses, points: shiftedPoints)
        })
        return MindmapLayoutResult(max(360.0, bounds.width + 84.0), max(220.0, bounds.height + 84.0), shiftedNodes, shiftedEdges)
    }

    private func executeMindmapRadialLayout(diagram: MindmapDiagram, widths: Array<Float64>, heights: Array<Float64>): Array<MindmapRawNode> {
        let rootChildren = ArrayList<Int64>()
        for (i in 1..diagram.nodes.size) {
            if (diagram.nodes[i].parentIndex == 0) {
                rootChildren.add(i)
            }
        }
        let positions = Array<MindmapRawNode>(diagram.nodes.size, { _ => MindmapRawNode(0.0, 0.0) })
        positions[0] = MindmapRawNode(0.0, 0.0)
        if (rootChildren.isEmpty()) {
            return positions
        }
        let startAngle = -12.0
        let step = 360.0 / Float64(rootChildren.size)
        for (i in 0..rootChildren.size) {
            placeRadialSubtree(diagram, widths, heights, positions, rootChildren[i], startAngle + step * Float64(i), 150.0)
        }
        return positions
    }

    private func placeRadialSubtree(diagram: MindmapDiagram, widths: Array<Float64>, heights: Array<Float64>, positions: Array<MindmapRawNode>, index: Int64, angleDeg: Float64, distance: Float64): Unit {
        let node = diagram.nodes[index]
        let parent = positions[node.parentIndex]
        let radians = angleDeg * 3.141592653589793 / 180.0
        let spacing = distance + widths[node.parentIndex] / 3.0 + widths[index] / 3.0
        positions[index] = MindmapRawNode(parent.x + cos(radians) * spacing, parent.y + sin(radians) * spacing)
        let children = childrenOf(diagram, index)
        if (children.isEmpty()) {
            return
        }
        let spread = min(150.0, max(54.0, 42.0 * Float64(children.size - 1)))
        let first = angleDeg - spread / 2.0
        let childStep = if (children.size <= 1) { 0.0 } else { spread / Float64(children.size - 1) }
        for (i in 0..children.size) {
            placeRadialSubtree(diagram, widths, heights, positions, children[i], first + childStep * Float64(i), max(112.0, distance * 0.82))
        }
    }

    private func assignSections(diagram: MindmapDiagram): Array<?Int64> {
        let sections = Array<?Int64>(diagram.nodes.size, { _ => None })
        var rootChild: Int64 = 0
        for (i in 1..diagram.nodes.size) {
            let node = diagram.nodes[i]
            if (node.parentIndex == 0) {
                sections[i] = Some(rootChild % (MindmapMaxSections - 1))
                rootChild++
            } else if (node.parentIndex > 0) {
                sections[i] = sections[node.parentIndex]
            }
        }
        return sections
    }

    private func childrenOf(diagram: MindmapDiagram, parentIndex: Int64): ArrayList<Int64> {
        let out = ArrayList<Int64>()
        for (i in 0..diagram.nodes.size) {
            if (diagram.nodes[i].parentIndex == parentIndex) {
                out.add(i)
            }
        }
        return out
    }

    private func subtreeSpan(diagram: MindmapDiagram, heights: Array<Float64>, index: Int64): Float64 {
        let children = childrenOf(diagram, index)
        if (children.isEmpty()) {
            return heights[index]
        }
        var total = 0.0
        for (child in children) {
            total += subtreeSpan(diagram, heights, child)
        }
        total += Float64(max(0, children.size - 1)) * 28.0
        return max(heights[index], total)
    }

    private func nodeWidth(node: MindmapNode, options: MermaidRenderOptions): Float64 {
        let iconWidth = if (node.icon.isEmpty()) { 0.0 } else { 50.0 }
        let labelWidth = options.textMeasurer.measureText(node.label) + iconWidth
        let shapePadding = match (node.shape) {
            case MindmapNodeShape.Circle | MindmapNodeShape.Cloud => paddingFor(node.shape) * 2.0
            case _ => 40.0
        }
        return max(92.0, min(240.0, labelWidth + shapePadding))
    }

    private func nodeHeight(node: MindmapNode): Float64 {
        if (!node.icon.isEmpty()) {
            return max(60.0, 38.0 + paddingFor(node.shape))
        }
        match (node.shape) {
            case MindmapNodeShape.Default => return 34.0
            case _ => ()
        }
        return 34.0 + paddingFor(node.shape)
    }

    private func paddingFor(shape: MindmapNodeShape): Float64 {
        match (shape) {
            case MindmapNodeShape.Square | MindmapNodeShape.Rounded | MindmapNodeShape.Hexagon => return 20.0
            case MindmapNodeShape.Circle => return 10.0
            case _ => return 10.0
        }
    }

    private func cssClasses(node: MindmapNode, section: ?Int64, root: Bool): String {
        let out = StringBuilder(64 + node.className.size)
        out.append("mindmap-node")
        if (root) {
            out.append(" section-root section--1")
        } else if (let Some(value) <- section) {
            out.append(" section-")
            out.append(value)
        }
        if (!node.className.isEmpty()) {
            out.append(" ")
            out.append(node.className)
        }
        return out.toString()
    }

    private func edgeClasses(section: ?Int64, depth: Int64): String {
        let out = StringBuilder(48)
        out.append("edge")
        if (let Some(value) <- section) {
            out.append(" section-edge-")
            out.append(value)
        }
        out.append(" edge-depth-")
        out.append(depth)
        return out.toString()
    }

    private func boundaryPoint(node: MindmapLayoutNode, towardX: Float64, towardY: Float64): AnchorPoint {
        let dx = towardX - node.x
        let dy = towardY - node.y
        if (abs64(dx) * node.height > abs64(dy) * node.width) {
            return AnchorPoint(node.x + (if (dx >= 0.0) { node.width / 2.0 } else { -node.width / 2.0 }), node.y + if (dx == 0.0) { 0.0 } else { dy / abs64(dx) * node.width / 2.0 })
        }
        return AnchorPoint(node.x + if (dy == 0.0) { 0.0 } else { dx / abs64(dy) * node.height / 2.0 }, node.y + (if (dy >= 0.0) { node.height / 2.0 } else { -node.height / 2.0 }))
    }

    private func boundaryPointInside(node: MindmapLayoutNode, towardX: Float64, towardY: Float64, overlap: Float64): AnchorPoint {
        let boundary = boundaryPoint(node, towardX, towardY)
        let dx = node.x - boundary.x
        let dy = node.y - boundary.y
        let length = sqrt(dx * dx + dy * dy)
        if (length <= 0.000001) {
            return boundary
        }
        return AnchorPoint(boundary.x + dx / length * overlap, boundary.y + dy / length * overlap)
    }

    private func edgeEndpointOverlap(depth: Int64): Float64 {
        let strokeWidth = max(2.0, 14.0 - 3.0 * Float64(depth))
        return max(6.0, strokeWidth / 2.0 + 4.0)
    }

    private func abs64(value: Float64): Float64 {
        return if (value < 0.0) { -value } else { value }
    }

    private func computeBounds(nodes: ArrayList<MindmapLayoutNode>): MindmapBounds {
        let first = nodes[0]
        var minX = first.x - first.width / 2.0
        var maxX = first.x + first.width / 2.0
        var minY = first.y - first.height / 2.0
        var maxY = first.y + first.height / 2.0
        for (node in nodes) {
            minX = min(minX, node.x - node.width / 2.0)
            maxX = max(maxX, node.x + node.width / 2.0)
            minY = min(minY, node.y - node.height / 2.0)
            maxY = max(maxY, node.y + node.height / 2.0)
        }
        return MindmapBounds(minX, minY, maxX - minX, maxY - minY)
    }
}

class MindmapRawNode {
    let x: Float64
    let y: Float64

    init(x: Float64, y: Float64) {
        this.x = x
        this.y = y
    }
}

class MindmapBounds {
    let x: Float64
    let y: Float64
    let width: Float64
    let height: Float64

    init(x: Float64, y: Float64, width: Float64, height: Float64) {
        this.x = x
        this.y = y
        this.width = width
        this.height = height
    }
}
