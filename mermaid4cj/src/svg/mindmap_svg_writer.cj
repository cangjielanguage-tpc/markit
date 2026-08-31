package mermaid4cj.svg

import std.collection.HashMap
import mermaid4cj.core.{MermaidRenderOptions, MindmapDiagram, MindmapNode, MindmapNodeShape}
import mermaid4cj.layout.{MindmapLayoutEdge, MindmapLayoutNode, MindmapLayoutResult}

public class MindmapSvgWriter {
    public init() {}

    public func write(diagram: MindmapDiagram, layout: MindmapLayoutResult, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let width = layout.width
        let height = layout.height
        let out = StringBuilder(4096 + diagram.source.size)
        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-mindmap mermaid4cj-mindmap mindmapDiagram\" xmlns=\"http://www.w3.org/2000/svg\" width=\"")
        out.append(width)
        out.append("\" height=\"")
        out.append(height)
        out.append("\" viewBox=\"")
        out.append(0)
        out.append(" ")
        out.append(0)
        out.append(" ")
        out.append(width)
        out.append(" ")
        out.append(height)
        out.append("\" role=\"graphics-document document\" aria-roledescription=\"mindmap\"><style>")
        appendSvgStyleScope(out, options.idPrefix)
        out.append("{background:")
        out.append(theme.background)
        out.append(";font-family:\"trebuchet ms\",verdana,arial,sans-serif;font-size:16px}")
        appendSvgStyleScopeSelector(out, options.idPrefix, "p")
        out.append("{margin:0}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".edge")
        out.append("{fill:none;stroke-width:3}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".edge-thickness-normal")
        out.append("{stroke-width:1px}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".edge-pattern-solid")
        out.append("{stroke-dasharray:0}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".mindmap-node-label")
        out.append("{alignment-baseline:middle;text-anchor:middle;dominant-baseline:middle;text-align:center}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".section-root rect")
        out.append(",")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".section-root path")
        out.append(",")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".section-root circle")
        out.append(",")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".section-root polygon")
        out.append("{fill:hsl(240, 100%, 46.2745098039%)}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".section-root text")
        out.append(",")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".section-root span")
        out.append("{fill:#ffffff;color:#ffffff}")
        appendSectionStyles(out, options.idPrefix)
        out.append("</style><g><g class=\"subgraphs\"/><g class=\"edgePaths\">")
        for (edge in layout.edges) {
            appendEdge(out, edge)
        }
        out.append("</g><g class=\"edgeLabels\"></g><g class=\"nodes\">")
        for (node in layout.nodes) {
            appendNode(out, options, node)
        }
        out.append("</g></g></svg>")
        return out.toString()
    }

    private func appendEdge(out: StringBuilder, edge: MindmapLayoutEdge): Unit {
        out.append("<path id=\"")
        SvgEscaper.appendAttribute(out, edge.id)
        out.append("\" class=\"edge-thickness-normal edge-pattern-solid ")
        SvgEscaper.appendAttribute(out, edge.cssClasses)
        out.append("\" data-edge=\"true\" data-et=\"edge\" data-id=\"")
        SvgEscaper.appendAttribute(out, edge.id)
        out.append("\" d=\"")
        appendD3BasisPath(out, edge.points)
        out.append("\"/>")
    }

    private func appendNode(out: StringBuilder, options: MermaidRenderOptions, node: MindmapLayoutNode): Unit {
        out.append("<g class=\"node ")
        SvgEscaper.appendAttribute(out, node.cssClasses)
        out.append("\" id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("-")
        SvgEscaper.appendAttribute(out, node.id)
        out.append("\" data-look=\"classic\" transform=\"translate(")
        out.append(node.x)
        out.append(", ")
        out.append(node.y)
        out.append(")\">")
        appendShape(out, node.shape, 0.0, 0.0, node.width, node.height)
        let labelWidth = labelWidthFor(node)
        let labelHeight = labelHeightFor(node)
        out.append("<g class=\"label\" transform=\"translate(")
        out.append(-labelWidth / 2.0)
        out.append(", ")
        out.append(-labelHeight / 2.0)
        out.append(")\"><rect/><foreignObject width=\"")
        out.append(labelWidth)
        out.append("\" height=\"")
        out.append(labelHeight)
        out.append("\"><div xmlns=\"http://www.w3.org/1999/xhtml\" style=\"display: table-cell; white-space: nowrap; line-height: 1.5; width:")
        out.append(labelWidth)
        out.append("px; max-width:")
        out.append(labelWidth)
        out.append("px; height:")
        out.append(labelHeight)
        out.append("px; vertical-align: middle; text-align: center;\"><span class=\"nodeLabel markdown-node-label\"><p>")
        if (!node.icon.isEmpty()) {
            SvgEscaper.appendText(out, node.icon)
            out.append(" ")
        }
        SvgEscaper.appendText(out, node.label)
        out.append("</p></span></div></foreignObject></g></g>")
    }

    private func appendShape(out: StringBuilder, shape: MindmapNodeShape, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        match (shape) {
            case MindmapNodeShape.Default =>
                appendDefaultMindmapNode(out, x, y, width, height)
            case MindmapNodeShape.Circle =>
                out.append("<circle class=\"basic label-container\" r=\"${max(width, height) / 2.0}\" cx=\"${x}\" cy=\"${y}\"/>")
            case MindmapNodeShape.Hexagon =>
                let w = width / 2.0
                let h = height / 2.0
                let m = h / 4.0
                out.append("<polygon class=\"node-bkg\" points=\"${x - w + m},${y - h} ${x + w - m},${y - h} ${x + w},${y} ${x + w - m},${y + h} ${x - w + m},${y + h} ${x - w},${y}\"/>")
            case MindmapNodeShape.Bang =>
                out.append("<path class=\"node-bkg\" d=\"M ${x - width / 2.0} ${y - height / 2.0} L ${x + width / 2.0} ${y - height / 2.0} L ${x + width / 2.0 - 10.0} ${y} L ${x + width / 2.0} ${y + height / 2.0} L ${x - width / 2.0} ${y + height / 2.0} Z\"/>")
            case MindmapNodeShape.Cloud =>
                out.append("<ellipse class=\"node-bkg\" cx=\"${x}\" cy=\"${y}\" rx=\"${width / 2.0}\" ry=\"${height / 2.0}\"/>")
            case _ =>
                let rx = match (shape) {
                    case MindmapNodeShape.Rounded => 8.0
                    case _ => 2.0
                }
                out.append("<rect class=\"basic label-container\" x=\"${x - width / 2.0}\" y=\"${y - height / 2.0}\" width=\"${width}\" height=\"${height}\" rx=\"${rx}\"/>")
        }
    }

    private func labelWidthFor(node: MindmapLayoutNode): Float64 {
        return max(1.0, node.width)
    }

    private func labelHeightFor(node: MindmapLayoutNode): Float64 {
        return max(24.0, node.height)
    }

    private func appendDefaultMindmapNode(out: StringBuilder, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let rd = 5.0
        let left = x - width / 2.0
        let right = x + width / 2.0
        let top = y - height / 2.0
        let bottom = y + height / 2.0
        out.append("<path class=\"node-bkg node-0\" d=\"M ${left} ${bottom - rd} v${-height + 2.0 * rd} q0 -${rd} ${rd} -${rd} h${width - 2.0 * rd} q${rd} 0 ${rd} ${rd} v${height - 2.0 * rd} q0 ${rd} -${rd} ${rd} h${-(width - 2.0 * rd)} q${-rd} 0 ${-rd} -${rd} Z\"/>")
        out.append("<line class=\"node-line-\" x1=\"${left}\" y1=\"${bottom}\" x2=\"${right}\" y2=\"${bottom}\"/>")
    }

    private func appendSectionStyles(out: StringBuilder, idPrefix: String): Unit {
        let fills = ["hsl(60, 100%, 73.5294117647%)", "hsl(80, 100%, 76.2745098039%)", "hsl(270, 100%, 76.2745098039%)", "hsl(300, 100%, 76.2745098039%)", "hsl(330, 100%, 76.2745098039%)", "hsl(0, 100%, 76.2745098039%)", "hsl(30, 100%, 76.2745098039%)", "hsl(90, 100%, 76.2745098039%)", "hsl(150, 100%, 76.2745098039%)", "hsl(180, 100%, 76.2745098039%)", "hsl(210, 100%, 76.2745098039%)"]
        let lineStrokes = ["hsl(240, 100%, 83.5294117647%)", "hsl(260, 100%, 86.2745098039%)", "hsl(90, 100%, 86.2745098039%)", "hsl(120, 100%, 86.2745098039%)", "hsl(150, 100%, 86.2745098039%)", "hsl(180, 100%, 86.2745098039%)", "hsl(210, 100%, 86.2745098039%)", "hsl(270, 100%, 86.2745098039%)", "hsl(330, 100%, 86.2745098039%)", "hsl(0, 100%, 86.2745098039%)", "hsl(30, 100%, 86.2745098039%)"]
        let labels = ["black", "black", "#ffffff", "black", "black", "black", "black", "black", "black", "black", "black"]
        for (i in 0..fills.size) {
            appendSvgStyleScope(out, idPrefix)
            out.append(" .section-")
            out.append(i)
            out.append(" rect,")
            appendSvgStyleScope(out, idPrefix)
            out.append(" .section-")
            out.append(i)
            out.append(" path,")
            appendSvgStyleScope(out, idPrefix)
            out.append(" .section-")
            out.append(i)
            out.append(" circle,")
            appendSvgStyleScope(out, idPrefix)
            out.append(" .section-")
            out.append(i)
            out.append(" polygon{fill:")
            out.append(fills[i])
            out.append("}")
            appendSvgStyleScope(out, idPrefix)
            out.append(" .section-")
            out.append(i)
            out.append(" text,")
            appendSvgStyleScope(out, idPrefix)
            out.append(" .section-")
            out.append(i)
            out.append(" span{fill:")
            out.append(labels[i])
            out.append(";color:")
            out.append(labels[i])
            out.append("}")
            appendSvgStyleScope(out, idPrefix)
            out.append(" .section-edge-")
            out.append(i)
            out.append("{stroke:")
            out.append(fills[i])
            out.append("}")
            appendSvgStyleScope(out, idPrefix)
            out.append(" .section-")
            out.append(i)
            out.append(" line{stroke:")
            out.append(lineStrokes[i])
            out.append(";stroke-width:3}")
        }
        for (depth in 0..11) {
            appendSvgStyleScope(out, idPrefix)
            out.append(" .edge-depth-")
            out.append(depth)
            out.append("{stroke-width:")
            out.append(14.0 - 3.0 * Float64(depth))
            out.append("}")
        }
    }
}
