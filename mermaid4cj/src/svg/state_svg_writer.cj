package mermaid4cj.svg

import std.collection.HashMap
import std.math.sqrt
import mermaid4cj.core.{MermaidRenderOptions, StateDiagram, StateDirection, StateNode, StateNodeKind, StateTransition}

public class StateSvgWriter {
    public init() {}

    public func write(diagram: StateDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let horizontal = isHorizontal(diagram.direction)
        let positions = HashMap<String, StateBox>()
        let kinds = HashMap<String, StateNodeKind>()
        let widthNode = 130.0
        let heightNode = 46.0
        let gap = 86.0
        for (i in 0..diagram.nodes.size) {
            let x = if (horizontal) { 42.0 + Float64(i) * (widthNode + gap) } else { 190.0 }
            let y = if (horizontal) { 90.0 } else { 42.0 + Float64(i) * (heightNode + gap) }
            positions[diagram.nodes[i].id] = StateBox(x, y, widthNode, heightNode)
            kinds[diagram.nodes[i].id] = diagram.nodes[i].kind
        }
        let width = if (horizontal) { max(360.0, 90.0 + Float64(max(1, diagram.nodes.size)) * (widthNode + gap)) } else { 520.0 }
        let height = if (horizontal) { 240.0 } else { max(240.0, 90.0 + Float64(max(1, diagram.nodes.size)) * (heightNode + gap)) }
        let out = StringBuilder(4096 + diagram.source.size)
        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-state mermaid4cj-state\" xmlns=\"http://www.w3.org/2000/svg\" width=\"")
        out.append(width)
        out.append("\" height=\"")
        out.append(height)
        out.append("\" viewBox=\"0 0 ")
        out.append(width)
        out.append(" ")
        out.append(height)
        out.append("\" role=\"img\"><style>")
        appendSvgStyleScope(out, options.idPrefix)
        out.append("{background:")
        out.append(theme.background)
        out.append(";font-family:Arial,sans-serif;font-size:13px}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".state-node")
        out.append("{fill:")
        out.append(theme.nodeFill)
        out.append(";stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1.4}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".state-composite")
        out.append("{fill:none;stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1.2;stroke-dasharray:5 4}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".state-label")
        out.append(",")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".state-edge-label")
        out.append("{fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".state-transition")
        out.append("{stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1.5;fill:none}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".state-edge-label-bg")
        out.append("{fill:")
        out.append(theme.edgeLabelBackground)
        out.append(";stroke:none;opacity:.95}</style><defs><marker id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("-state-arrow\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"8\" markerHeight=\"8\" orient=\"auto\"><path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"")
        SvgEscaper.appendAttribute(out, theme.edge)
        out.append("\"/></marker></defs>")
        out.append("<g class=\"state-transitions\">")
        for (transition in diagram.transitions) {
            appendTransition(out, options, theme, transition, positions, kinds, horizontal)
        }
        out.append("</g><g class=\"state-nodes\">")
        for (node in diagram.nodes) {
            appendNode(out, node, positions.get(node.id).getOrThrow())
        }
        out.append("</g></svg>")
        return out.toString()
    }

    private func appendTransition(out: StringBuilder, options: MermaidRenderOptions, theme: SvgTheme, transition: StateTransition, positions: HashMap<String, StateBox>, kinds: HashMap<String, StateNodeKind>, horizontal: Bool): Unit {
        if (positions.get(transition.source).isNone() || positions.get(transition.target).isNone()) {
            return
        }
        let sourceBox = positions.get(transition.source).getOrThrow()
        let targetBox = positions.get(transition.target).getOrThrow()
        let sourceCenter = center(sourceBox)
        let targetCenter = center(targetBox)
        let start = boundaryPoint(sourceBox, kinds.get(transition.source) ?? StateNodeKind.State, targetCenter)
        let stop = boundaryPoint(targetBox, kinds.get(transition.target) ?? StateNodeKind.State, sourceCenter)
        out.append("<g class=\"state-transition-group\"><path class=\"state-transition\" d=\"M ")
        out.append(start.x)
        out.append(" ")
        out.append(start.y)
        out.append(" L ")
        out.append(stop.x)
        out.append(" ")
        out.append(stop.y)
        out.append("\" marker-end=\"url(#")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("-state-arrow)\"/>")
        if (!transition.label.isEmpty()) {
            let labelX = (start.x + stop.x) / 2.0
            let labelY = if (horizontal) { (start.y + stop.y) / 2.0 - 8.0 } else { (start.y + stop.y) / 2.0 + 5.0 }
            if (!horizontal) {
                let bgWidth = max(30.0, Float64(transition.label.size) * 7.0 + 12.0)
                out.append("<rect class=\"state-edge-label-bg\" x=\"")
                out.append(labelX - bgWidth / 2.0)
                out.append("\" y=\"")
                out.append(labelY - 14.0)
                out.append("\" width=\"")
                out.append(bgWidth)
                out.append("\" height=\"18\" rx=\"3\"/>")
            }
            out.append("<text class=\"state-edge-label\" x=\"")
            out.append(labelX)
            out.append("\" y=\"")
            out.append(labelY)
            out.append("\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, transition.label)
            out.append("</text>")
        }
        out.append("</g>")
    }

    private func appendNode(out: StringBuilder, node: StateNode, box: StateBox): Unit {
        match (node.kind) {
            case StateNodeKind.Start =>
                out.append("<circle class=\"state-node state-start\" cx=\"${box.x + box.width / 2.0}\" cy=\"${box.y + box.height / 2.0}\" r=\"10\"/>")
            case StateNodeKind.End =>
                out.append("<circle class=\"state-node state-end\" cx=\"${box.x + box.width / 2.0}\" cy=\"${box.y + box.height / 2.0}\" r=\"12\"/><circle cx=\"${box.x + box.width / 2.0}\" cy=\"${box.y + box.height / 2.0}\" r=\"7\" fill=\"#111\"/>")
            case StateNodeKind.Composite =>
                out.append("<g class=\"state-composite-group\"><rect class=\"state-node\" x=\"${box.x}\" y=\"${box.y}\" width=\"${box.width}\" height=\"${box.height}\" rx=\"5\"/><text class=\"state-label\" x=\"${box.x + box.width / 2.0}\" y=\"${box.y + box.height / 2.0 + 5.0}\" text-anchor=\"middle\">")
                SvgEscaper.appendText(out, node.label)
                out.append("</text></g>")
            case _ =>
                out.append("<g class=\"state-node-group\"><rect class=\"state-node\" x=\"${box.x}\" y=\"${box.y}\" width=\"${box.width}\" height=\"${box.height}\" rx=\"5\"/><text class=\"state-label\" x=\"${box.x + box.width / 2.0}\" y=\"${box.y + box.height / 2.0 + 5.0}\" text-anchor=\"middle\">")
                SvgEscaper.appendText(out, node.label)
                out.append("</text></g>")
        }
    }

    private func center(box: StateBox): StatePoint {
        return StatePoint(box.x + box.width / 2.0, box.y + box.height / 2.0)
    }

    private func boundaryPoint(box: StateBox, kind: StateNodeKind, toward: StatePoint): StatePoint {
        let c = center(box)
        let dx = toward.x - c.x
        let dy = toward.y - c.y
        let length = sqrt(dx * dx + dy * dy)
        if (length <= 0.000001) {
            return c
        }
        let radius = stateRadius(kind)
        if (radius > 0.0) {
            return StatePoint(c.x + dx / length * radius, c.y + dy / length * radius)
        }
        if (abs64(dx) * box.height > abs64(dy) * box.width) {
            let x = c.x + (if (dx >= 0.0) { box.width / 2.0 } else { -box.width / 2.0 })
            let y = c.y + if (dx == 0.0) { 0.0 } else { dy / abs64(dx) * box.width / 2.0 }
            return StatePoint(x, y)
        }
        let x = c.x + if (dy == 0.0) { 0.0 } else { dx / abs64(dy) * box.height / 2.0 }
        let y = c.y + (if (dy >= 0.0) { box.height / 2.0 } else { -box.height / 2.0 })
        return StatePoint(x, y)
    }

    private func stateRadius(kind: StateNodeKind): Float64 {
        match (kind) {
            case StateNodeKind.Start => return 10.0
            case StateNodeKind.End => return 12.0
            case _ => return 0.0
        }
    }

    private func abs64(value: Float64): Float64 {
        return if (value < 0.0) { -value } else { value }
    }

    private func isHorizontal(direction: StateDirection): Bool {
        match (direction) {
            case StateDirection.LR | StateDirection.RL => return true
            case _ => return false
        }
    }
}

class StateBox {
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

class StatePoint {
    let x: Float64
    let y: Float64

    init(x: Float64, y: Float64) {
        this.x = x
        this.y = y
    }
}
