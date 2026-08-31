package mermaid4cj.svg

import std.collection.HashMap
import std.math.{sin, sqrt}
import mermaid4cj.core.{DefaultMermaidTextMeasurer, FlowEdgeMarker, FlowEdgeStyle, FlowNodeShape, FlowNodeStyle, FlowchartDiagram, MermaidRenderOptions, MermaidTextMeasurer}
import mermaid4cj.layout.{AnchorPoint, FlowchartLayoutResult, LayoutEdge}

public func appendD3BasisPath(out: StringBuilder, points: Array<AnchorPoint>): Unit {
    let curve = D3BasisPath(out)
    curve.lineStart()
    for (point in points) {
        curve.point(point.x, point.y)
    }
    curve.lineEnd()
}

class D3BasisPath {
    let out: StringBuilder
    var x0: Float64 = 0.0
    var y0: Float64 = 0.0
    var x1: Float64 = 0.0
    var y1: Float64 = 0.0
    var pointCount: Int64 = 0
    var lineState: Int64 = -1

    init(out: StringBuilder) {
        this.out = out
    }

    func lineStart(): Unit {
        x0 = 0.0
        y0 = 0.0
        x1 = 0.0
        y1 = 0.0
        pointCount = 0
    }

    func lineEnd(): Unit {
        match (pointCount) {
            case 3 =>
                appendBasisPoint(x1, y1)
                out.append(" L ")
                out.append(x1)
                out.append(" ")
                out.append(y1)
            case 2 =>
                out.append(" L ")
                out.append(x1)
                out.append(" ")
                out.append(y1)
            case _ => ()
        }
        if (lineState == 1 || (lineState != 0 && pointCount == 1)) {
            out.append(" Z")
        }
        lineState = 1 - lineState
    }

    func point(x: Float64, y: Float64): Unit {
        match (pointCount) {
            case 0 =>
                pointCount = 1
                if (lineState == 1) {
                    out.append(" L ")
                } else {
                    out.append(" M ")
                }
                out.append(x)
                out.append(" ")
                out.append(y)
            case 1 =>
                pointCount = 2
            case 2 =>
                pointCount = 3
                out.append(" L ")
                out.append((5.0 * x0 + x1) / 6.0)
                out.append(" ")
                out.append((5.0 * y0 + y1) / 6.0)
                appendBasisPoint(x, y)
            case _ =>
                appendBasisPoint(x, y)
        }
        x0 = x1
        x1 = x
        y0 = y1
        y1 = y
    }

    func appendBasisPoint(x: Float64, y: Float64): Unit {
        out.append(" C ")
        out.append((2.0 * x0 + x1) / 3.0)
        out.append(" ")
        out.append((2.0 * y0 + y1) / 3.0)
        out.append(", ")
        out.append((x0 + 2.0 * x1) / 3.0)
        out.append(" ")
        out.append((y0 + 2.0 * y1) / 3.0)
        out.append(", ")
        out.append((x0 + 4.0 * x1 + x) / 6.0)
        out.append(" ")
        out.append((y0 + 4.0 * y1 + y) / 6.0)
    }
}

public class FlowchartSvgWriter {
    let textMeasurer: MermaidTextMeasurer

    public init(textMeasurer!: MermaidTextMeasurer = DefaultMermaidTextMeasurer()) {
        this.textMeasurer = textMeasurer
    }

    public func write(diagram: FlowchartDiagram, layout: FlowchartLayoutResult, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let prefix = SvgEscaper.attribute(options.classPrefix)
        let out = StringBuilder(1024 + diagram.nodes.size * 240 + diagram.edges.size * 180)
        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" xmlns=\"http://www.w3.org/2000/svg\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append(" mermaid4cj-flowchart\" role=\"img\" viewBox=\"0 0 ")
        out.append(layout.width)
        out.append(" ")
        out.append(layout.height)
        out.append("\" width=\"")
        out.append(layout.width)
        out.append("\" height=\"")
        out.append(layout.height)
        out.append("\">")
        if (let Some(title) <- options.title) {
            out.append("<title>")
            SvgEscaper.appendText(out, title)
            out.append("</title>")
        }
        writeStyle(out, options.idPrefix, theme)
        writeMarkers(out, options.idPrefix, theme.edge)
        out.append("<g class=\"root\">")
        if (layout.clusters.isEmpty()) {
            out.append("<g class=\"clusters\"/>")
        } else {
            out.append("<g class=\"clusters ")
            SvgEscaper.appendAttribute(out, options.classPrefix)
            out.append("-subgraphs\">")
            for (cluster in layout.clusters) {
                out.append("<g class=\"cluster\" id=\"")
                SvgEscaper.appendAttribute(out, options.idPrefix)
                out.append("-")
                SvgEscaper.appendAttribute(out, cluster.id)
                out.append("\" data-id=\"")
                SvgEscaper.appendAttribute(out, cluster.id)
                out.append("\" transform=\"translate(")
                out.append(cluster.x)
                out.append(", ")
                out.append(cluster.y)
                out.append(")\"><rect class=\"")
                SvgEscaper.appendAttribute(out, options.classPrefix)
                out.append("-cluster\" width=\"")
                out.append(cluster.width)
                out.append("\" height=\"")
                out.append(cluster.height)
                out.append("\" rx=\"4\" fill=\"")
                out.append(theme.background)
                out.append("\" stroke=\"")
                out.append(theme.nodeStroke)
                out.append("\" stroke-width=\"1\" opacity=\"0.92\"/>")
                out.append("<text class=\"cluster-label\" x=\"")
                out.append(cluster.width / 2.0)
                out.append("\" y=\"20\" text-anchor=\"middle\" font-family=\"trebuchet ms,verdana,arial,sans-serif\" font-size=\"14\" fill=\"")
                out.append(theme.text)
                out.append("\">")
                SvgEscaper.appendTextRange(out, diagram.source, cluster.title.start, cluster.title.end)
                out.append("</text></g>")
            }
            out.append("</g>")
        }

        let edgeIds = buildEdgeDataIds(diagram)
        out.append("<g class=\"edgePaths\">")
        for (i in 0..layout.edges.size) {
            let edge = layout.edges[i]
            let model = diagram.edges[i]
            out.append("<path d=\"")
            writeEdgePath(out, edge, model.markerStart, model.markerEnd)
            out.append("\" id=\"")
            SvgEscaper.appendAttribute(out, options.idPrefix)
            out.append("-")
            SvgEscaper.appendAttribute(out, edgeIds[i])
            out.append("\" class=\"")
            SvgEscaper.appendAttribute(out, options.classPrefix)
            out.append("-edge flowchart-link ")
            out.append(edgeThicknessClass(model.style))
            out.append(" ")
            out.append(edgePatternClass(model.style))
            out.append("\" data-edge=\"true\" data-et=\"edge\" data-id=\"")
            SvgEscaper.appendAttribute(out, edgeIds[i])
            out.append("\" data-look=\"classic\" fill=\"none\" stroke=\"")
            out.append(theme.edge)
            out.append("\" stroke-width=\"")
            out.append(edgeStrokeWidth(model.style))
            out.append("\"")
            if (isDotted(model.style)) {
                out.append(" stroke-dasharray=\"2\"")
            }
            writeMarkerRef(out, "marker-start", options.idPrefix, model.markerStart)
            writeMarkerRef(out, "marker-end", options.idPrefix, model.markerEnd)
            out.append("/>")
        }
        out.append("</g>")

        out.append("<g class=\"edgeLabels\">")
        for (i in 0..diagram.edges.size) {
            if (let Some(label) <- diagram.edges[i].label) {
                if (label.isEmpty()) {
                    continue
                }
                let edge = layout.edges[i]
                let labelX = edge.labelX ?? ((edge.x1 + edge.x2) / 2.0)
                let labelY = edge.labelY ?? ((edge.y1 + edge.y2) / 2.0)
                out.append("<g class=\"edgeLabel\" transform=\"translate(")
                out.append(labelX)
                out.append(", ")
                out.append(labelY)
                out.append(")\">")
                out.append("<text class=\"edgeLabel\" x=\"0\" y=\"5\" text-anchor=\"middle\" fill=\"")
                out.append(theme.text)
                out.append("\">")
                SvgEscaper.appendTextRange(out, diagram.source, label.start, label.end)
                out.append("</text></g>")
            }
        }
        out.append("</g>")

        out.append("<g class=\"nodes\">")
        for (i in 0..diagram.nodes.size) {
            let node = diagram.nodes[i]
            let placed = layout.nodes[i]
            let style = resolveStyle(diagram, node.id, node.className)
            out.append("<g class=\"node default")
            appendNodeClass(out, node.className)
            appendAssignedNodeClass(out, diagram, node.id)
            out.append("\" id=\"")
            SvgEscaper.appendAttribute(out, options.idPrefix)
            out.append("-flowchart-")
            SvgEscaper.appendAttribute(out, node.id)
            out.append("-")
            out.append(i)
            out.append("\" data-id=\"")
            SvgEscaper.appendAttribute(out, node.id)
            out.append("\" transform=\"translate(")
            out.append(placed.x + placed.width / 2.0)
            out.append(", ")
            out.append(placed.y + placed.height / 2.0)
            out.append(")\">")
            writeNode(out, prefix, theme, style, node.shape, 0.0 - placed.width / 2.0, 0.0 - placed.height / 2.0, placed.width, placed.height)
            if (shapeUsesLabel(node.shape)) {
                writeNodeLabel(out, theme, style, diagram.source, node.label.start, node.label.end, node.labelText, placed.width)
            }
            out.append("</g>")
        }
        out.append("</g></g>")

        out.append("</svg>")
        return out.toString()
    }

    private func writeStyle(out: StringBuilder, idPrefix: String, theme: SvgTheme): Unit {
        out.append("<style>#")
        SvgEscaper.appendText(out, idPrefix)
        out.append("{font-family:\"trebuchet ms\",verdana,arial,sans-serif;font-size:16px;fill:")
        out.append(theme.text)
        out.append(";}#")
        SvgEscaper.appendText(out, idPrefix)
        out.append(" p{margin:0;}#")
        SvgEscaper.appendText(out, idPrefix)
        out.append(" .label{font-family:\"trebuchet ms\",verdana,arial,sans-serif;color:")
        out.append(theme.text)
        out.append(";text-align:center;}#")
        SvgEscaper.appendText(out, idPrefix)
        out.append(" .nodeLabel,#")
        SvgEscaper.appendText(out, idPrefix)
        out.append(" .edgeLabel{display:inline-block;line-height:1.5;}#")
        SvgEscaper.appendText(out, idPrefix)
        out.append(" .flowchart-link{stroke:")
        out.append(theme.edge)
        out.append(";fill:none;}</style>")
    }

    private func writeNodeLabel(out: StringBuilder, theme: SvgTheme, style: FlowNodeStyle, source: String, start: Int64, end: Int64, labelText: ?String, width: Float64): Unit {
        let labelHeight = labelForeignObjectHeight(labelText)
        out.append("<g class=\"label\"><text class=\"nodeLabel\" x=\"0\" y=\"")
        out.append(0.0 - labelHeight / 2.0 + 17.0)
        out.append("\" text-anchor=\"middle\" fill=\"")
        appendNodeTextColor(out, theme, style)
        out.append("\">")
        if (let Some(text) <- labelText) {
            appendSvgTextLines(out, text, 24.0)
        } else {
            SvgEscaper.appendTextRange(out, source, start, end)
        }
        out.append("</text></g>")
    }

    private func labelForeignObjectHeight(labelText: ?String): Float64 {
        if (let Some(text) <- labelText) {
            return Float64(textMeasurer.countLines(text)) * 24.0
        }
        return 24.0
    }

    private func appendTextWithLineBreaks(out: StringBuilder, text: String): Unit {
        var start: Int64 = 0
        var i: Int64 = 0
        while (i < text.size) {
            if (text[i] == b'\n' || text[i] == b'\r') {
                SvgEscaper.appendText(out, text[start..i])
                out.append("<br/>")
                if (text[i] == b'\r' && i + 1 < text.size && text[i + 1] == b'\n') {
                    i++
                }
                start = i + 1
            }
            i++
        }
        SvgEscaper.appendText(out, text[start..text.size])
    }

    private func appendSvgTextLines(out: StringBuilder, text: String, lineHeight: Float64): Unit {
        var first = true
        var start: Int64 = 0
        var i: Int64 = 0
        while (i < text.size) {
            if (text[i] == b'\n' || text[i] == b'\r') {
                if (!first) {
                    out.append("<tspan x=\"0\" dy=\"")
                    out.append(lineHeight)
                    out.append("\">")
                }
                SvgEscaper.appendText(out, text[start..i])
                if (!first) {
                    out.append("</tspan>")
                }
                first = false
                if (text[i] == b'\r' && i + 1 < text.size && text[i + 1] == b'\n') {
                    i++
                }
                start = i + 1
            }
            i++
        }
        if (!first) {
            out.append("<tspan x=\"0\" dy=\"")
            out.append(lineHeight)
            out.append("\">")
        }
        SvgEscaper.appendText(out, text[start..text.size])
        if (!first) {
            out.append("</tspan>")
        }
    }

    private func buildEdgeDataIds(diagram: FlowchartDiagram): Array<String> {
        let pairCounts = HashMap<String, Int64>()
        return Array<String>(diagram.edges.size, { i =>
            let edge = diagram.edges[i]
            if (let Some(id) <- edge.id) {
                if (!id.isEmpty()) {
                    return sanitizeStableId(id)
                }
            }
            let key = edge.source + "\u{0}" + edge.target
            let count = pairCounts.get(key) ?? 0
            pairCounts[key] = count + 1
            let out = StringBuilder(edge.source.size + edge.target.size + 8)
            out.append("L_")
            appendStableIdPart(out, edge.source)
            out.append("_")
            appendStableIdPart(out, edge.target)
            out.append("_")
            out.append(count)
            out.toString()
        })
    }

    private func sanitizeStableId(id: String): String {
        let out = StringBuilder(id.size)
        appendStableIdPart(out, id)
        return out.toString()
    }

    private func appendStableIdPart(out: StringBuilder, id: String): Unit {
        for (r in id.runes()) {
            if ((r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') || (r >= r'0' && r <= r'9') || r == r'_' || r == r'-') {
                out.append(r)
            } else {
                out.append("_")
            }
        }
    }

    private func appendNodeClass(out: StringBuilder, className: ?String): Unit {
        if (let Some(value) <- className) {
            if (!value.isEmpty()) {
                out.append(" ")
                SvgEscaper.appendAttribute(out, value)
            }
        }
    }

    private func appendAssignedNodeClass(out: StringBuilder, diagram: FlowchartDiagram, id: String): Unit {
        if (let Some(value) <- diagram.nodeClasses.get(id)) {
            if (!value.isEmpty()) {
                out.append(" ")
                SvgEscaper.appendAttribute(out, value)
            }
        }
    }

    private func writeNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, shape: FlowNodeShape, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        match (shape) {
            case FlowNodeShape.Circle =>
                let r = max(width, height) / 2.0
                out.append("<circle class=\"")
                out.append(prefix)
                out.append("-node\" cx=\"")
                out.append(x + width / 2.0)
                out.append("\" cy=\"")
                out.append(y + height / 2.0)
                out.append("\" r=\"")
                out.append(r)
                out.append("\" fill=\"")
                appendNodeFill(out, theme, style)
                out.append("\" stroke=\"")
                appendNodeStroke(out, theme, style)
                out.append("\" stroke-width=\"1.5\"/>")
            case FlowNodeShape.Ellipse =>
                out.append("<ellipse class=\"")
                out.append(prefix)
                out.append("-node\" cx=\"")
                out.append(x + width / 2.0)
                out.append("\" cy=\"")
                out.append(y + height / 2.0)
                out.append("\" rx=\"")
                out.append(width / 2.0)
                out.append("\" ry=\"")
                out.append(height / 2.0)
                out.append("\" fill=\"")
                appendNodeFill(out, theme, style)
                out.append("\" stroke=\"")
                appendNodeStroke(out, theme, style)
                out.append("\" stroke-width=\"1.5\"/>")
            case FlowNodeShape.Diamond =>
                out.append("<path class=\"")
                out.append(prefix)
                out.append("-node\" d=\"M ")
                out.append(x + width / 2.0)
                out.append(" ")
                out.append(y)
                out.append(" L ")
                out.append(x + width)
                out.append(" ")
                out.append(y + height / 2.0)
                out.append(" L ")
                out.append(x + width / 2.0)
                out.append(" ")
                out.append(y + height)
                out.append(" L ")
                out.append(x)
                out.append(" ")
                out.append(y + height / 2.0)
                out.append(" Z\" fill=\"")
                appendNodeFill(out, theme, style)
                out.append("\" stroke=\"")
                appendNodeStroke(out, theme, style)
                out.append("\" stroke-width=\"1.5\"/>")
            case FlowNodeShape.Hexagon =>
                let m = height / 4.0
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x + m, y),
                    AnchorPoint(x + width - m, y),
                    AnchorPoint(x + width, y + height / 2.0),
                    AnchorPoint(x + width - m, y + height),
                    AnchorPoint(x + m, y + height),
                    AnchorPoint(x, y + height / 2.0)
                ])
            case FlowNodeShape.LeanRight =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x + (2.0 * height) / 6.0, y),
                    AnchorPoint(x + width + height / 6.0, y),
                    AnchorPoint(x + width - (2.0 * height) / 6.0, y + height),
                    AnchorPoint(x - height / 6.0, y + height)
                ])
            case FlowNodeShape.LeanLeft =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x - (2.0 * height) / 6.0, y),
                    AnchorPoint(x + width - height / 6.0, y),
                    AnchorPoint(x + width + (2.0 * height) / 6.0, y + height),
                    AnchorPoint(x + height / 6.0, y + height)
                ])
            case FlowNodeShape.Trapezoid =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x - (2.0 * height) / 6.0, y),
                    AnchorPoint(x + width + (2.0 * height) / 6.0, y),
                    AnchorPoint(x + width - height / 6.0, y + height),
                    AnchorPoint(x + height / 6.0, y + height)
                ])
            case FlowNodeShape.InvTrapezoid =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x + height / 6.0, y),
                    AnchorPoint(x + width - height / 6.0, y),
                    AnchorPoint(x + width + (2.0 * height) / 6.0, y + height),
                    AnchorPoint(x - (2.0 * height) / 6.0, y + height)
                ])
            case FlowNodeShape.Subroutine =>
                writeRectNode(out, prefix, theme, style, x, y, width, height, 4.0)
                out.append("<path class=\"")
                out.append(prefix)
                out.append("-node-divider\" d=\"M ")
                out.append(x + 10.0)
                out.append(" ")
                out.append(y)
                out.append(" L ")
                out.append(x + 10.0)
                out.append(" ")
                out.append(y + height)
                out.append(" M ")
                out.append(x + width - 10.0)
                out.append(" ")
                out.append(y)
                out.append(" L ")
                out.append(x + width - 10.0)
                out.append(" ")
                out.append(y + height)
                out.append("\" stroke=\"")
                appendNodeStroke(out, theme, style)
                out.append("\" stroke-width=\"1\"/>")
            case FlowNodeShape.Cylinder =>
                let rx = width / 2.0
                let ry = rx / (2.5 + width / 50.0)
                let bodyHeight = height - ry * 2.0
                out.append("<path class=\"")
                out.append(prefix)
                out.append("-node outer-path\" d=\"M")
                out.append(x)
                out.append(",")
                out.append(y + ry)
                out.append(" a")
                out.append(rx)
                out.append(",")
                out.append(ry)
                out.append(" 0,0,0 ")
                out.append(width)
                out.append(",0 a")
                out.append(rx)
                out.append(",")
                out.append(ry)
                out.append(" 0,0,0 ")
                out.append(0.0 - width)
                out.append(",0 l0,")
                out.append(bodyHeight)
                out.append(" a")
                out.append(rx)
                out.append(",")
                out.append(ry)
                out.append(" 0,0,0 ")
                out.append(width)
                out.append(",0 l0,")
                out.append(0.0 - bodyHeight)
                out.append("\" fill=\"")
                appendNodeFill(out, theme, style)
                out.append("\" stroke=\"")
                appendNodeStroke(out, theme, style)
                out.append("\" stroke-width=\"1.5\"/>")
            case FlowNodeShape.Datastore =>
                writeDatastoreNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.DoubleCircle =>
                writeDoubleCircleNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.Text =>
                ()
            case FlowNodeShape.Odd =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x, y),
                    AnchorPoint(x + width, y),
                    AnchorPoint(x + width, y + height),
                    AnchorPoint(x, y + height),
                    AnchorPoint(x + width * 0.18, y + height / 2.0)
                ])
            case FlowNodeShape.Card =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x + 12.0, y),
                    AnchorPoint(x + width, y),
                    AnchorPoint(x + width, y + height),
                    AnchorPoint(x, y + height),
                    AnchorPoint(x, y + 12.0)
                ])
            case FlowNodeShape.ShadedProcess =>
                writeShadedProcessNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.SmallCircle =>
                writeCircleNode(out, prefix, theme, style, x, y, width, height, true, false)
            case FlowNodeShape.FramedCircle =>
                writeCircleNode(out, prefix, theme, style, x, y, width, height, false, true)
            case FlowNodeShape.FilledCircle =>
                writeCircleNode(out, prefix, theme, style, x, y, width, height, true, false)
            case FlowNodeShape.Fork =>
                writeRectNode(out, prefix, theme, FlowNodeStyle(fill: Some(theme.edge), stroke: Some(theme.edge)), x, y, width, height, 0.0)
            case FlowNodeShape.Document =>
                writeDocumentNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.MultiProcess =>
                writeMultiProcessNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.DividedProcess =>
                writeDividedProcessNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.Triangle =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x, y + height),
                    AnchorPoint(x + width, y + height),
                    AnchorPoint(x + width / 2.0, y)
                ])
            case FlowNodeShape.SlopedRectangle =>
                writeSlopedRectangleNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.CrossedCircle =>
                writeCrossedCircleNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.TaggedProcess =>
                writeTaggedProcessNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.TaggedDocument =>
                writeTaggedDocumentNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.Flag =>
                writeWaveRectangleNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.Hourglass =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x, y),
                    AnchorPoint(x + width, y),
                    AnchorPoint(x, y + height),
                    AnchorPoint(x + width, y + height)
                ])
            case FlowNodeShape.NotchedPentagon =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x + width * 0.1, y),
                    AnchorPoint(x + width * 0.9, y),
                    AnchorPoint(x + width, y + height * 0.2),
                    AnchorPoint(x + width, y + height),
                    AnchorPoint(x, y + height),
                    AnchorPoint(x, y + height * 0.2)
                ])
            case FlowNodeShape.FlippedTriangle =>
                writePolygonNode(out, prefix, theme, style, [
                    AnchorPoint(x, y),
                    AnchorPoint(x + width, y),
                    AnchorPoint(x + width / 2.0, y + height)
                ])
            case FlowNodeShape.Delay =>
                writeDelayNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.CurvedTrapezoid =>
                writeCurvedTrapezoidNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.WindowPane =>
                writeWindowPaneNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.LinedCylinder =>
                writeLinedCylinderNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.HorizontalCylinder =>
                writeHorizontalCylinderNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.MultiDocument =>
                writeMultiDocumentNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.LinedDocument =>
                writeLinedDocumentNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.Bang =>
                writeBangNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.Cloud =>
                writeCloudNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.LightningBolt =>
                writeLightningBoltNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.BowTieRectangle =>
                writeBowTieRectangleNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.CurlyBraceLeft =>
                writeCurlyBraceLeftNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.CurlyBraceRight =>
                writeCurlyBraceRightNode(out, prefix, theme, style, x, y, width, height)
            case FlowNodeShape.CurlyBraces =>
                writeCurlyBraceLeftNode(out, prefix, theme, style, x, y, width * 0.28, height)
                writeCurlyBraceRightNode(out, prefix, theme, style, x + width * 0.72, y, width * 0.28, height)
            case FlowNodeShape.Rounded =>
                writeRectNode(out, prefix, theme, style, x, y, width, height, 10.0)
            case FlowNodeShape.Stadium =>
                writeRectNode(out, prefix, theme, style, x, y, width, height, height / 2.0)
            case _ =>
                writeRectNode(out, prefix, theme, style, x, y, width, height, 4.0)
        }
    }

    private func shapeUsesLabel(shape: FlowNodeShape): Bool {
        match (shape) {
            case FlowNodeShape.SmallCircle | FlowNodeShape.FramedCircle | FlowNodeShape.FilledCircle | FlowNodeShape.Fork | FlowNodeShape.CrossedCircle | FlowNodeShape.Hourglass | FlowNodeShape.LightningBolt => return false
            case _ => return true
        }
    }

    private func writeEdgePath(out: StringBuilder, edge: LayoutEdge, markerStart: FlowEdgeMarker, markerEnd: FlowEdgeMarker): Unit {
        let adjustedPoints = markerAdjustedPoints(edge, markerStart, markerEnd)
        if (!edge.points.isEmpty()) {
            writePointPath(out, adjustedPoints)
            return
        }
        let x1 = adjustedPoints[0].x
        let y1 = adjustedPoints[0].y
        let x2 = adjustedPoints[adjustedPoints.size - 1].x
        let y2 = adjustedPoints[adjustedPoints.size - 1].y
        let dx = if (x2 >= x1) { x2 - x1 } else { x1 - x2 }
        let dy = if (y2 >= y1) { y2 - y1 } else { y1 - y2 }
        out.append("M ")
        out.append(x1)
        out.append(" ")
        out.append(y1)
        if (dy >= dx) {
            let midY = (y1 + y2) / 2.0
            out.append(" C ")
            out.append(x1)
            out.append(" ")
            out.append(midY)
            out.append(", ")
            out.append(x2)
            out.append(" ")
            out.append(midY)
            out.append(", ")
            out.append(x2)
            out.append(" ")
            out.append(y2)
        } else {
            let midX = (x1 + x2) / 2.0
            out.append(" C ")
            out.append(midX)
            out.append(" ")
            out.append(y1)
            out.append(", ")
            out.append(midX)
            out.append(" ")
            out.append(y2)
            out.append(", ")
            out.append(x2)
            out.append(" ")
            out.append(y2)
        }
    }

    private func writePointPath(out: StringBuilder, points: Array<AnchorPoint>): Unit {
        appendD3BasisPath(out, points)
    }

    private func markerAdjustedPoints(edge: LayoutEdge, markerStart: FlowEdgeMarker, markerEnd: FlowEdgeMarker): Array<AnchorPoint> {
        let base = if (edge.points.isEmpty()) {
            [AnchorPoint(edge.x1, edge.y1), AnchorPoint(edge.x2, edge.y2)]
        } else {
            edge.points
        }
        let points = Array<AnchorPoint>(base.size, { i => AnchorPoint(base[i].x, base[i].y) })
        if (points.size < 2) {
            return points
        }
        let startOffset = markerOffset(markerStart)
        if (startOffset > 0.0) {
            points[0] = movePointToward(points[0], points[1], startOffset)
        }
        let endOffset = markerOffset(markerEnd)
        if (endOffset > 0.0) {
            let last = points.size - 1
            points[last] = movePointToward(points[last], points[last - 1], endOffset)
        }
        return points
    }

    private func movePointToward(point: AnchorPoint, toward: AnchorPoint, distance: Float64): AnchorPoint {
        let dx = toward.x - point.x
        let dy = toward.y - point.y
        let length = sqrt(dx * dx + dy * dy)
        if (length <= 0.000001) {
            return point
        }
        return AnchorPoint(point.x + dx / length * distance, point.y + dy / length * distance)
    }

    private func markerOffset(marker: FlowEdgeMarker): Float64 {
        match (marker) {
            case FlowEdgeMarker.Point => return 4.0
            case FlowEdgeMarker.Circle | FlowEdgeMarker.Cross => return 12.5
            case _ => return 0.0
        }
    }

    private func writeMarkers(out: StringBuilder, idPrefix: String, color: String): Unit {
        out.append("<defs>")
        writePointMarker(out, idPrefix, "pointEnd", color, true)
        writePointMarker(out, idPrefix, "pointStart", color, false)
        writeCircleMarker(out, idPrefix, "circleEnd", color, true)
        writeCircleMarker(out, idPrefix, "circleStart", color, false)
        writeCrossMarker(out, idPrefix, "crossEnd", color, true)
        writeCrossMarker(out, idPrefix, "crossStart", color, false)
        out.append("</defs>")
    }

    private func writePointMarker(out: StringBuilder, idPrefix: String, name: String, color: String, end: Bool): Unit {
        out.append("<marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("_flowchart-v2-")
        out.append(name)
        out.append("\" class=\"marker flowchart-v2\" viewBox=\"0 0 10 10\" refX=\"")
        out.append(if (end) { "5" } else { "4.5" })
        out.append("\" refY=\"5\" markerUnits=\"userSpaceOnUse\" markerWidth=\"8\" markerHeight=\"8\" orient=\"auto\" fill=\"")
        out.append(color)
        out.append("\" stroke=\"")
        out.append(color)
        out.append("\"><path d=\"")
        out.append(if (end) { "M 0 0 L 10 5 L 0 10 z" } else { "M 0 5 L 10 10 L 10 0 z" })
        out.append("\" class=\"arrowMarkerPath\" style=\"stroke-width: 1; stroke-dasharray: 1, 0;\"/>")
        out.append("</marker>")
    }

    private func writeCircleMarker(out: StringBuilder, idPrefix: String, name: String, color: String, end: Bool): Unit {
        out.append("<marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("_flowchart-v2-")
        out.append(name)
        out.append("\" class=\"marker flowchart-v2\" viewBox=\"0 0 10 10\" refX=\"")
        out.append(if (end) { "11" } else { "-1" })
        out.append("\" refY=\"5\" markerUnits=\"userSpaceOnUse\" markerWidth=\"11\" markerHeight=\"11\" orient=\"auto\" fill=\"")
        out.append(color)
        out.append("\" stroke=\"")
        out.append(color)
        out.append("\"><circle cx=\"5\" cy=\"5\" r=\"5\" class=\"arrowMarkerPath\" style=\"stroke-width: 1; stroke-dasharray: 1, 0;\"/>")
        out.append("</marker>")
    }

    private func writeCrossMarker(out: StringBuilder, idPrefix: String, name: String, color: String, end: Bool): Unit {
        out.append("<marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("_flowchart-v2-")
        out.append(name)
        out.append("\" class=\"marker cross flowchart-v2\" viewBox=\"0 0 11 11\" refX=\"")
        out.append(if (end) { "12" } else { "-1" })
        out.append("\" refY=\"5.2\" markerUnits=\"userSpaceOnUse\" markerWidth=\"11\" markerHeight=\"11\" orient=\"auto\" fill=\"")
        out.append(color)
        out.append("\" stroke=\"")
        out.append(color)
        out.append("\"><path d=\"M 1,1 l 9,9 M 10,1 l -9,9\" class=\"arrowMarkerPath\" style=\"stroke-width: 2; stroke-dasharray: 1, 0;\"/>")
        out.append("</marker>")
    }

    private func writeMarkerRef(out: StringBuilder, attr: String, idPrefix: String, marker: FlowEdgeMarker): Unit {
        let suffix = markerIdSuffix(attr, marker)
        if (suffix.isEmpty()) {
            return
        }
        out.append(" ")
        out.append(attr)
        out.append("=\"url(#")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("_flowchart-v2-")
        out.append(suffix)
        out.append(")\"")
    }

    private func markerIdSuffix(attr: String, marker: FlowEdgeMarker): String {
        let end = attr == "marker-end"
        match (marker) {
            case FlowEdgeMarker.Point => return if (end) { "pointEnd" } else { "pointStart" }
            case FlowEdgeMarker.Circle => return if (end) { "circleEnd" } else { "circleStart" }
            case FlowEdgeMarker.Cross => return if (end) { "crossEnd" } else { "crossStart" }
            case _ => return ""
        }
    }

    private func writeRectNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64, rx: Float64): Unit {
        out.append("<rect class=\"")
        out.append(prefix)
        out.append("-node\" x=\"")
        out.append(x)
        out.append("\" y=\"")
        out.append(y)
        out.append("\" width=\"")
        out.append(width)
        out.append("\" height=\"")
        out.append(height)
        out.append("\" rx=\"")
        out.append(rx)
        out.append("\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeCircleNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64, filled: Bool, framed: Bool): Unit {
        let r = max(width, height) / 2.0
        let cx = x + width / 2.0
        let cy = y + height / 2.0
        out.append("<circle class=\"")
        out.append(prefix)
        out.append("-node\" cx=\"")
        out.append(cx)
        out.append("\" cy=\"")
        out.append(cy)
        out.append("\" r=\"")
        out.append(r)
        out.append("\" fill=\"")
        if (filled) {
            out.append(theme.nodeStroke)
        } else {
            appendNodeFill(out, theme, style)
        }
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
        if (framed) {
            out.append("<circle class=\"")
            out.append(prefix)
            out.append("-node-inner\" cx=\"")
            out.append(cx)
            out.append("\" cy=\"")
            out.append(cy)
            out.append("\" r=\"")
            out.append((r * 5.0) / 7.0)
            out.append("\" fill=\"")
            appendNodeStroke(out, theme, style)
            out.append("\" stroke=\"")
            appendNodeStroke(out, theme, style)
            out.append("\" stroke-width=\"1.5\"/>")
        }
    }

    private func writeDoubleCircleNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let outer = max(width, height) / 2.0
        let inner = outer - 5.0
        let cx = x + width / 2.0
        let cy = y + height / 2.0
        out.append("<g class=\"")
        out.append(prefix)
        out.append("-node basic label-container\"><circle class=\"outer-circle\" cx=\"")
        out.append(cx)
        out.append("\" cy=\"")
        out.append(cy)
        out.append("\" r=\"")
        out.append(outer)
        out.append("\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/><circle class=\"inner-circle\" cx=\"")
        out.append(cx)
        out.append("\" cy=\"")
        out.append(cy)
        out.append("\" r=\"")
        out.append(inner)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/></g>")
    }

    private func writeDatastoreNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        out.append("<rect class=\"")
        out.append(prefix)
        out.append("-node\" x=\"")
        out.append(x)
        out.append("\" y=\"")
        out.append(y)
        out.append("\" width=\"")
        out.append(width)
        out.append("\" height=\"")
        out.append(height)
        out.append("\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\" stroke-dasharray=\"")
        out.append(width)
        out.append(" ")
        out.append(height)
        out.append("\"/>")
    }

    private func writeShadedProcessNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let frame = 8.0
        writeRectNode(out, prefix, theme, style, x, y, width, height, 0.0)
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node-divider\" d=\"M ")
        out.append(x + frame)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + frame)
        out.append(" ")
        out.append(y + height)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeDocumentNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let wave = height / 8.0
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M ")
        out.append(x)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y + height - wave)
        appendSineWave(out, x + width, y + height - wave, x, y + height - wave, wave, 0.8)
        out.append(" Z\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func appendSineWave(out: StringBuilder, x1: Float64, y1: Float64, x2: Float64, y2: Float64, amplitude: Float64, cycles: Float64): Unit {
        let steps: Int64 = 50
        let deltaX = x2 - x1
        let deltaY = y2 - y1
        let cycleLength = deltaX / cycles
        let frequency = (2.0 * 3.141592653589793) / cycleLength
        let midY = y1 + deltaY / 2.0
        for (i in 0..(steps + 1)) {
            let t = Float64(i) / Float64(steps)
            let x = x1 + t * deltaX
            let y = midY + amplitude * sin(frequency * (x - x1))
            out.append(" L ")
            out.append(x)
            out.append(" ")
            out.append(y)
        }
    }

    private func writeMultiProcessNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let offset = 5.0
        writePolygonNode(out, prefix, theme, style, [
            AnchorPoint(x, y + offset),
            AnchorPoint(x, y + height),
            AnchorPoint(x + width - offset, y + height),
            AnchorPoint(x + width - offset, y + height - offset),
            AnchorPoint(x + width, y + height - offset),
            AnchorPoint(x + width, y),
            AnchorPoint(x + offset, y),
            AnchorPoint(x + offset, y + offset)
        ])
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node-inner\" d=\"M ")
        out.append(x + offset)
        out.append(" ")
        out.append(y + offset)
        out.append(" L ")
        out.append(x + width - offset)
        out.append(" ")
        out.append(y + offset)
        out.append(" L ")
        out.append(x + width - offset)
        out.append(" ")
        out.append(y + height)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1\"/>")
    }

    private func writeDividedProcessNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let offset = height * 0.2
        writeRectNode(out, prefix, theme, style, x, y, width, height, 0.0)
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node-divider\" d=\"M ")
        out.append(x)
        out.append(" ")
        out.append(y + offset)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y + offset)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeSlopedRectangleNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let h = height / 1.5
        writePolygonNode(out, prefix, theme, style, [
            AnchorPoint(x, y + h / 2.0),
            AnchorPoint(x, y + h + h / 2.0),
            AnchorPoint(x + width, y + h + h / 2.0),
            AnchorPoint(x + width, y)
        ])
    }

    private func writeCrossedCircleNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let r = max(width, height) / 2.0
        let cx = x + width / 2.0
        let cy = y + height / 2.0
        let p = r * 0.7071067811865476
        writeCircleNode(out, prefix, theme, style, x, y, width, height, false, false)
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node-cross\" d=\"M ")
        out.append(cx - p)
        out.append(",")
        out.append(cy + p)
        out.append(" L ")
        out.append(cx + p)
        out.append(",")
        out.append(cy - p)
        out.append(" M ")
        out.append(cx + p)
        out.append(",")
        out.append(cy + p)
        out.append(" L ")
        out.append(cx - p)
        out.append(",")
        out.append(cy - p)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeTaggedProcessNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let tag = height * 0.2
        writeRectNode(out, prefix, theme, style, x, y, width, height, 0.0)
        writePolygonNode(out, prefix, theme, style, [
            AnchorPoint(x + width - tag, y + height),
            AnchorPoint(x + width, y + height),
            AnchorPoint(x + width, y + height - tag)
        ])
    }

    private func writeTaggedDocumentNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        writeDocumentNode(out, prefix, theme, style, x, y, width, height)
        let tag = height * 0.2
        writePolygonNode(out, prefix, theme, style, [
            AnchorPoint(x + width - tag, y + height),
            AnchorPoint(x + width, y + height),
            AnchorPoint(x + width, y + height - tag)
        ])
    }

    private func writeWaveRectangleNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let wave = height / 8.0
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M ")
        out.append(x)
        out.append(" ")
        out.append(y + wave)
        appendSineWave(out, x, y + wave, x + width, y + wave, wave, 1.0)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y + height - wave)
        appendSineWave(out, x + width, y + height - wave, x, y + height - wave, wave, -1.0)
        out.append(" Z\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeDelayNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let r = height / 2.0
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M ")
        out.append(x)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + width - r)
        out.append(" ")
        out.append(y)
        out.append(" A ")
        out.append(r)
        out.append(" ")
        out.append(r)
        out.append(" 0 0 1 ")
        out.append(x + width - r)
        out.append(" ")
        out.append(y + height)
        out.append(" L ")
        out.append(x)
        out.append(" ")
        out.append(y + height)
        out.append(" Z\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeCurvedTrapezoidNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let radius = height / 2.0
        let rw = width - radius
        let tw = height / 4.0
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M ")
        out.append(x + rw)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + tw)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x)
        out.append(" ")
        out.append(y + height / 2.0)
        out.append(" L ")
        out.append(x + tw)
        out.append(" ")
        out.append(y + height)
        out.append(" L ")
        out.append(x + rw)
        out.append(" ")
        out.append(y + height)
        out.append(" A ")
        out.append(radius)
        out.append(" ")
        out.append(radius)
        out.append(" 0 0 0 ")
        out.append(x + rw)
        out.append(" ")
        out.append(y)
        out.append(" Z\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeWindowPaneNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let offset = 10.0
        writeRectNode(out, prefix, theme, style, x, y, width, height, 0.0)
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node-divider\" d=\"M ")
        out.append(x)
        out.append(" ")
        out.append(y + offset)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y + offset)
        out.append(" M ")
        out.append(x + offset)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + offset)
        out.append(" ")
        out.append(y + height)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeLinedCylinderNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let rx = width / 2.0
        let ry = rx / (2.5 + width / 50.0)
        let bodyHeight = height - ry * 2.0
        let offset = height * 0.1
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M")
        out.append(x)
        out.append(",")
        out.append(y + ry)
        out.append(" a")
        out.append(rx)
        out.append(",")
        out.append(ry)
        out.append(" 0,0,0 ")
        out.append(width)
        out.append(",0 a")
        out.append(rx)
        out.append(",")
        out.append(ry)
        out.append(" 0,0,0 ")
        out.append(0.0 - width)
        out.append(",0 l0,")
        out.append(bodyHeight)
        out.append(" a")
        out.append(rx)
        out.append(",")
        out.append(ry)
        out.append(" 0,0,0 ")
        out.append(width)
        out.append(",0 l0,")
        out.append(0.0 - bodyHeight)
        out.append(" M")
        out.append(x)
        out.append(",")
        out.append(y + ry + offset)
        out.append(" a")
        out.append(rx)
        out.append(",")
        out.append(ry)
        out.append(" 0,0,0 ")
        out.append(width)
        out.append(",0\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeHorizontalCylinderNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let ry = height / 2.0
        let rx = ry / (2.5 + height / 50.0)
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M")
        out.append(x)
        out.append(",")
        out.append(y + height)
        out.append(" a")
        out.append(rx)
        out.append(",")
        out.append(ry)
        out.append(" 0,0,1 0,")
        out.append(0.0 - height)
        out.append(" l")
        out.append(width)
        out.append(",0 a")
        out.append(rx)
        out.append(",")
        out.append(ry)
        out.append(" 0,0,1 0,")
        out.append(height)
        out.append(" M")
        out.append(x + width)
        out.append(",")
        out.append(y)
        out.append(" a")
        out.append(rx)
        out.append(",")
        out.append(ry)
        out.append(" 0,0,0 0,")
        out.append(height)
        out.append(" l")
        out.append(0.0 - width)
        out.append(",0\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeMultiDocumentNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let offset = 10.0
        writeWaveRectangleNode(out, prefix, theme, style, x, y + offset, width - offset, height - offset)
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node-inner\" d=\"M ")
        out.append(x + offset)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y + height - offset)
        out.append(" L ")
        out.append(x + width - offset)
        out.append(" ")
        out.append(y + height - offset)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1\"/>")
    }

    private func writeLinedDocumentNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        writeDocumentNode(out, prefix, theme, style, x, y, width, height)
        let gap = height * 0.16
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node-divider\" d=\"M ")
        out.append(x)
        out.append(" ")
        out.append(y + gap)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y + gap)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeBangNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let r = 0.15 * width
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M")
        out.append(x)
        out.append(" ")
        out.append(y)
        out.append(" a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(width * 0.25)
        out.append(",")
        out.append(0.0 - height * 0.1)
        out.append(" a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(width * 0.25)
        out.append(",0 a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(width * 0.25)
        out.append(",0 a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(width * 0.25)
        out.append(",")
        out.append(height * 0.1)
        out.append(" a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(width * 0.15)
        out.append(",")
        out.append(height * 0.33)
        out.append(" a")
        out.append(r * 0.8)
        out.append(",")
        out.append(r * 0.8)
        out.append(" 1 0,0 0,")
        out.append(height * 0.34)
        out.append(" a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(0.0 - width * 0.15)
        out.append(",")
        out.append(height * 0.33)
        out.append(" a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(0.0 - width * 0.25)
        out.append(",")
        out.append(height * 0.15)
        out.append(" a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(0.0 - width * 0.25)
        out.append(",0 a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(0.0 - width * 0.25)
        out.append(",0 a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(0.0 - width * 0.25)
        out.append(",")
        out.append(0.0 - height * 0.15)
        out.append(" a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(0.0 - width * 0.1)
        out.append(",")
        out.append(0.0 - height * 0.33)
        out.append(" a")
        out.append(r * 0.8)
        out.append(",")
        out.append(r * 0.8)
        out.append(" 1 0,0 0,")
        out.append(0.0 - height * 0.34)
        out.append(" a")
        out.append(r)
        out.append(",")
        out.append(r)
        out.append(" 1 0,0 ")
        out.append(width * 0.1)
        out.append(",")
        out.append(0.0 - height * 0.33)
        out.append(" H")
        out.append(x)
        out.append(" V")
        out.append(y)
        out.append(" Z\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeCloudNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let r1 = 0.15 * width
        let r2 = 0.25 * width
        let r3 = 0.35 * width
        let r4 = 0.2 * width
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M")
        out.append(x)
        out.append(" ")
        out.append(y)
        out.append(" a")
        out.append(r1)
        out.append(",")
        out.append(r1)
        out.append(" 0 0,1 ")
        out.append(width * 0.25)
        out.append(",")
        out.append(0.0 - width * 0.1)
        out.append(" a")
        out.append(r3)
        out.append(",")
        out.append(r3)
        out.append(" 1 0,1 ")
        out.append(width * 0.4)
        out.append(",")
        out.append(0.0 - width * 0.1)
        out.append(" a")
        out.append(r2)
        out.append(",")
        out.append(r2)
        out.append(" 1 0,1 ")
        out.append(width * 0.35)
        out.append(",")
        out.append(width * 0.2)
        out.append(" a")
        out.append(r1)
        out.append(",")
        out.append(r1)
        out.append(" 1 0,1 ")
        out.append(width * 0.15)
        out.append(",")
        out.append(height * 0.35)
        out.append(" a")
        out.append(r4)
        out.append(",")
        out.append(r4)
        out.append(" 1 0,1 ")
        out.append(0.0 - width * 0.15)
        out.append(",")
        out.append(height * 0.65)
        out.append(" a")
        out.append(r2)
        out.append(",")
        out.append(r1)
        out.append(" 1 0,1 ")
        out.append(0.0 - width * 0.25)
        out.append(",")
        out.append(width * 0.15)
        out.append(" a")
        out.append(r3)
        out.append(",")
        out.append(r3)
        out.append(" 1 0,1 ")
        out.append(0.0 - width * 0.5)
        out.append(",0 a")
        out.append(r1)
        out.append(",")
        out.append(r1)
        out.append(" 1 0,1 ")
        out.append(0.0 - width * 0.25)
        out.append(",")
        out.append(0.0 - width * 0.15)
        out.append(" a")
        out.append(r1)
        out.append(",")
        out.append(r1)
        out.append(" 1 0,1 ")
        out.append(0.0 - width * 0.1)
        out.append(",")
        out.append(0.0 - height * 0.35)
        out.append(" a")
        out.append(r4)
        out.append(",")
        out.append(r4)
        out.append(" 1 0,1 ")
        out.append(width * 0.1)
        out.append(",")
        out.append(0.0 - height * 0.65)
        out.append(" H")
        out.append(x)
        out.append(" V")
        out.append(y)
        out.append(" Z\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeLightningBoltNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let h = height / 2.0
        let gap = 7.0
        writePolygonNode(out, prefix, theme, style, [
            AnchorPoint(x + width, y),
            AnchorPoint(x, y + h + gap / 2.0),
            AnchorPoint(x + width - 2.0 * gap, y + h + gap / 2.0),
            AnchorPoint(x, y + 2.0 * h),
            AnchorPoint(x + width, y + h - gap / 2.0),
            AnchorPoint(x + 2.0 * gap, y + h - gap / 2.0)
        ])
    }

    private func writeBowTieRectangleNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let ry = height / 2.0
        let rx = ry / (2.5 + height / 50.0)
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M ")
        out.append(x + width)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x)
        out.append(" ")
        out.append(y)
        out.append(" A ")
        out.append(rx)
        out.append(" ")
        out.append(ry)
        out.append(" 0 0 0 ")
        out.append(x)
        out.append(" ")
        out.append(y + height)
        out.append(" L ")
        out.append(x + width)
        out.append(" ")
        out.append(y + height)
        out.append(" A ")
        out.append(rx)
        out.append(" ")
        out.append(ry)
        out.append(" 0 0 0 ")
        out.append(x + width)
        out.append(" ")
        out.append(y)
        out.append(" Z\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeCurlyBraceLeftNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let radius = max(5.0, height * 0.1)
        let cx = x + radius
        let right = x + width
        let top = y
        let middle = y + height / 2.0
        let bottom = y + height
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M ")
        out.append(right)
        out.append(" ")
        out.append(top)
        out.append(" C ")
        out.append(cx)
        out.append(" ")
        out.append(top)
        out.append(", ")
        out.append(cx)
        out.append(" ")
        out.append(middle - radius)
        out.append(", ")
        out.append(x)
        out.append(" ")
        out.append(middle - radius)
        out.append(" C ")
        out.append(cx)
        out.append(" ")
        out.append(middle - radius)
        out.append(", ")
        out.append(cx)
        out.append(" ")
        out.append(middle + radius)
        out.append(", ")
        out.append(x)
        out.append(" ")
        out.append(middle + radius)
        out.append(" C ")
        out.append(cx)
        out.append(" ")
        out.append(middle + radius)
        out.append(", ")
        out.append(cx)
        out.append(" ")
        out.append(bottom)
        out.append(", ")
        out.append(right)
        out.append(" ")
        out.append(bottom)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writeCurlyBraceRightNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let radius = max(5.0, height * 0.1)
        let left = x
        let cx = x + width - radius
        let right = x + width
        let top = y
        let middle = y + height / 2.0
        let bottom = y + height
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node outer-path\" d=\"M ")
        out.append(left)
        out.append(" ")
        out.append(top)
        out.append(" C ")
        out.append(cx)
        out.append(" ")
        out.append(top)
        out.append(", ")
        out.append(cx)
        out.append(" ")
        out.append(middle - radius)
        out.append(", ")
        out.append(right)
        out.append(" ")
        out.append(middle - radius)
        out.append(" C ")
        out.append(cx)
        out.append(" ")
        out.append(middle - radius)
        out.append(", ")
        out.append(cx)
        out.append(" ")
        out.append(middle + radius)
        out.append(", ")
        out.append(right)
        out.append(" ")
        out.append(middle + radius)
        out.append(" C ")
        out.append(cx)
        out.append(" ")
        out.append(middle + radius)
        out.append(", ")
        out.append(cx)
        out.append(" ")
        out.append(bottom)
        out.append(", ")
        out.append(left)
        out.append(" ")
        out.append(bottom)
        out.append("\" fill=\"none\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func writePolygonNode(out: StringBuilder, prefix: String, theme: SvgTheme, style: FlowNodeStyle, points: Array<AnchorPoint>): Unit {
        out.append("<path class=\"")
        out.append(prefix)
        out.append("-node\" d=\"M ")
        out.append(points[0].x)
        out.append(" ")
        out.append(points[0].y)
        for (i in 1..points.size) {
            out.append(" L ")
            out.append(points[i].x)
            out.append(" ")
            out.append(points[i].y)
        }
        out.append(" Z\" fill=\"")
        appendNodeFill(out, theme, style)
        out.append("\" stroke=\"")
        appendNodeStroke(out, theme, style)
        out.append("\" stroke-width=\"1.5\"/>")
    }

    private func resolveStyle(diagram: FlowchartDiagram, id: String, inlineClass: ?String): FlowNodeStyle {
        if (let Some(style) <- diagram.nodeStyles.get(id)) {
            return style
        }
        if (let Some(className) <- diagram.nodeClasses.get(id)) {
            if (let Some(style) <- diagram.classStyles.get(className)) {
                return style
            }
        }
        if (let Some(className) <- inlineClass) {
            if (let Some(style) <- diagram.classStyles.get(className)) {
                return style
            }
        }
        return FlowNodeStyle()
    }

    private func appendNodeFill(out: StringBuilder, theme: SvgTheme, style: FlowNodeStyle): Unit {
        if (let Some(fill) <- style.fill) {
            SvgEscaper.appendAttribute(out, fill)
            return
        }
        out.append(theme.nodeFill)
    }

    private func appendNodeStroke(out: StringBuilder, theme: SvgTheme, style: FlowNodeStyle): Unit {
        if (let Some(stroke) <- style.stroke) {
            SvgEscaper.appendAttribute(out, stroke)
            return
        }
        out.append(theme.nodeStroke)
    }

    private func appendNodeTextColor(out: StringBuilder, theme: SvgTheme, style: FlowNodeStyle): Unit {
        if (let Some(color) <- style.color) {
            SvgEscaper.appendAttribute(out, color)
            return
        }
        out.append(theme.text)
    }

    private func isDotted(style: FlowEdgeStyle): Bool {
        match (style) {
            case FlowEdgeStyle.Dotted => return true
            case _ => return false
        }
    }

    private func edgeStrokeWidth(style: FlowEdgeStyle): String {
        match (style) {
            case FlowEdgeStyle.Thick => return "3.5"
            case _ => return "1"
        }
    }

    private func edgeThicknessClass(style: FlowEdgeStyle): String {
        match (style) {
            case FlowEdgeStyle.Thick => return "edge-thickness-thick"
            case _ => return "edge-thickness-normal"
        }
    }

    private func edgePatternClass(style: FlowEdgeStyle): String {
        match (style) {
            case FlowEdgeStyle.Dotted => return "edge-pattern-dotted"
            case _ => return "edge-pattern-solid"
        }
    }
}
