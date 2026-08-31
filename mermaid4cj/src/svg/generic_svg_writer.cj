package mermaid4cj.svg

import std.collection.{ArrayList, HashMap}
import std.math.{cos, sin}
import mermaid4cj.core.{DiagramKind, GenericDiagram, GenericEdge, GenericNode, GenericRow, GenericTask, MermaidRenderOptions}

public class GenericSvgWriter {
    public init() {}

    public func write(diagram: GenericDiagram, options: MermaidRenderOptions): String {
        match (diagram.kind) {
            case DiagramKind.Pie => return writePie(diagram, options)
            case DiagramKind.Gantt => return writeGantt(diagram, options)
            case _ => return writeGraphLike(diagram, options)
        }
    }

    private func writeGraphLike(diagram: GenericDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let nodeWidth = 126.0
        let nodeHeight = 38.0
        let xGap = 170.0
        let yGap = 74.0
        let positions = HashMap<String, NodePos>()
        var maxLevel: Int64 = 0
        let levelCounts = HashMap<Int64, Int64>()
        for (i in 0..diagram.nodes.size) {
            let level = diagram.nodes[i].level
            let count = levelCounts.get(level) ?? 0
            levelCounts[level] = count + 1
            if (level > maxLevel) {
                maxLevel = level
            }
            positions[diagram.nodes[i].id] = NodePos(40.0 + Float64(level) * xGap, 50.0 + Float64(count) * yGap)
        }
        match (diagram.kind) {
            case DiagramKind.Mindmap => ()
            case _ =>
                let cols: Int64 = 3
                for (i in 0..diagram.nodes.size) {
                    let col = i % cols
                    let row = i / cols
                    positions[diagram.nodes[i].id] = NodePos(50.0 + Float64(col) * xGap, 70.0 + Float64(row) * yGap)
                }
                maxLevel = min(2, max(0, diagram.nodes.size - 1))
        }
        let rowCount = max(1, diagram.nodes.size)
        let width = max(360.0, 90.0 + Float64(max(1, maxLevel + 1)) * xGap)
        let height = max(220.0, 120.0 + Float64(rowCount) * yGap + Float64(max(0, diagram.edges.size - diagram.nodes.size)) * 8.0)
        let out = StringBuilder(4096 + diagram.source.size)
        appendSvgStart(out, options, theme, width, height, kindClass(diagram.kind))
        out.append("<g class=\"generic-edges\">")
        for (edge in diagram.edges) {
            if (let Some(start) <- positions.get(edge.source)) {
                if (let Some(stop) <- positions.get(edge.target)) {
                    appendEdge(out, theme, edge, start.x + nodeWidth, start.y + nodeHeight / 2.0, stop.x, stop.y + nodeHeight / 2.0)
                }
            }
        }
        out.append("</g><g class=\"generic-nodes\">")
        for (node in diagram.nodes) {
            if (let Some(pos) <- positions.get(node.id)) {
                appendNode(out, theme, node, pos.x, pos.y, nodeWidth, nodeHeight, diagram.kind)
            }
        }
        out.append("</g></svg>")
        return out.toString()
    }

    private func writeGantt(diagram: GenericDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let left = 190.0
        let top = if (diagram.title.isSome()) { 58.0 } else { 30.0 }
        let rowHeight = 34.0
        let dayWidth = 28.0
        let minStart = ganttMinStart(diagram)
        let maxEnd = ganttMaxEnd(diagram, minStart + 1)
        let span = max(1, maxEnd - minStart)
        let width = max(520.0, left + Float64(span) * dayWidth + 48.0)
        let height = max(180.0, top + Float64(max(1, diagram.tasks.size)) * rowHeight + 52.0)
        let out = StringBuilder(4096 + diagram.source.size)
        appendSvgStart(out, options, theme, width, height, "gantt")
        out.append("<style>")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-grid")
        out.append("{stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:.6;opacity:.25}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task")
        out.append("{stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-done")
        out.append("{fill:#7cc576}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-active")
        out.append("{fill:#5b9bd5}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-crit")
        out.append("{fill:#d9534f}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-default")
        out.append("{fill:")
        out.append(theme.nodeFill)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-section")
        out.append("{font-weight:bold}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-axis")
        out.append("{fill:")
        out.append(theme.text)
        out.append(";font-size:11px}</style>")
        if (let Some(title) <- diagram.title) {
            out.append("<text class=\"generic-title\" x=\"")
            out.append(width / 2.0)
            out.append("\" y=\"28\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, title)
            out.append("</text>")
        }
        appendGanttGrid(out, left, top - 18.0, rowHeight, dayWidth, span, diagram.tasks.size, minStart)
        var lastSection = ""
        for (i in 0..diagram.tasks.size) {
            let task = diagram.tasks[i]
            let y = top + Float64(i) * rowHeight
            if (task.section != lastSection && !task.section.isEmpty()) {
                out.append("<text class=\"generic-label gantt-section\" x=\"12\" y=\"")
                out.append(y + 18.0)
                out.append("\">")
                SvgEscaper.appendText(out, task.section)
                out.append("</text>")
                lastSection = task.section
            }
            out.append("<text class=\"generic-label\" x=\"")
            out.append(left - 12.0)
            out.append("\" y=\"")
            out.append(y + 18.0)
            out.append("\" text-anchor=\"end\">")
            SvgEscaper.appendText(out, task.label)
            out.append("</text>")
            appendGanttTask(out, task, left + Float64(task.start - minStart) * dayWidth, y + 7.0, max(8.0, Float64(task.end - task.start) * dayWidth), 18.0)
        }
        out.append("</svg>")
        return out.toString()
    }

    private func writePie(diagram: GenericDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let width = 520.0
        let height = 340.0
        let cx = 170.0
        let cy = 180.0
        let r = 110.0
        let out = StringBuilder(4096 + diagram.source.size)
        appendSvgStart(out, options, theme, width, height, "pie")
        if (let Some(title) <- diagram.title) {
            out.append("<text class=\"generic-title\" x=\"")
            out.append(width / 2.0)
            out.append("\" y=\"28\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, title)
            out.append("</text>")
        }
        let total = pieTotal(diagram.rows)
        var start = -1.5707963267948966
        for (i in 0..diagram.rows.size) {
            let row = diagram.rows[i]
            let angle = if (total > 0.0) { row.value / total * 6.283185307179586 } else { 0.0 }
            appendPieSlice(out, cx, cy, r, start, start + angle, pieColor(i))
            appendLegend(out, row, 340.0, 78.0 + Float64(i) * 28.0, pieColor(i))
            start += angle
        }
        out.append("</svg>")
        return out.toString()
    }

    private func appendSvgStart(out: StringBuilder, options: MermaidRenderOptions, theme: SvgTheme, width: Float64, height: Float64, kind: String): Unit {
        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-")
        out.append(kind)
        out.append(" mermaid4cj-")
        out.append(kind)
        out.append("\" xmlns=\"http://www.w3.org/2000/svg\" width=\"")
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
        out.append(";font-family:Arial,sans-serif;font-size:14px}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".generic-node")
        out.append("{fill:")
        out.append(theme.nodeFill)
        out.append(";stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1.4}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".generic-edge")
        out.append("{stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1.4;fill:none}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".generic-label")
        out.append(",")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".generic-title")
        out.append("{fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".generic-edge-label")
        out.append("{fill:")
        out.append(theme.text)
        out.append(";font-size:12px}</style>")
    }

    private func appendNode(out: StringBuilder, theme: SvgTheme, node: GenericNode, x: Float64, y: Float64, width: Float64, height: Float64, kind: DiagramKind): Unit {
        out.append("<g class=\"generic-node-group\" data-id=\"")
        SvgEscaper.appendAttribute(out, node.id)
        out.append("\">")
        match (kind) {
            case DiagramKind.Mindmap =>
                if (node.level == 0) {
                    out.append("<ellipse class=\"generic-node\" cx=\"")
                    out.append(x + width / 2.0)
                    out.append("\" cy=\"")
                    out.append(y + height / 2.0)
                    out.append("\" rx=\"")
                    out.append(width / 2.0)
                    out.append("\" ry=\"")
                    out.append(height / 2.0)
                    out.append("\"/>")
                } else {
                    appendRectNode(out, x, y, width, height)
                }
            case _ => appendRectNode(out, x, y, width, height)
        }
        out.append("<text class=\"generic-label\" x=\"")
        out.append(x + width / 2.0)
        out.append("\" y=\"")
        out.append(y + height / 2.0 + 5.0)
        out.append("\" text-anchor=\"middle\">")
        SvgEscaper.appendText(out, node.label)
        out.append("</text></g>")
    }

    private func appendEdge(out: StringBuilder, theme: SvgTheme, edge: GenericEdge, x1: Float64, y1: Float64, x2: Float64, y2: Float64): Unit {
        out.append("<path class=\"generic-edge\" d=\"M ")
        out.append(x1)
        out.append(" ")
        out.append(y1)
        out.append(" L ")
        out.append(x2)
        out.append(" ")
        out.append(y2)
        out.append("\"/>")
        if (!edge.label.isEmpty() || !edge.relation.isEmpty()) {
            out.append("<text class=\"generic-edge-label\" x=\"")
            out.append((x1 + x2) / 2.0)
            out.append("\" y=\"")
            out.append((y1 + y2) / 2.0 - 4.0)
            out.append("\" text-anchor=\"middle\">")
            let label = if (!edge.label.isEmpty()) { edge.label } else { edge.relation }
            SvgEscaper.appendText(out, label)
            out.append("</text>")
        }
    }

    private func appendPieSlice(out: StringBuilder, cx: Float64, cy: Float64, r: Float64, start: Float64, stop: Float64, color: String): Unit {
        let x1 = cx + r * cos(start)
        let y1 = cy + r * sin(start)
        let x2 = cx + r * cos(stop)
        let y2 = cy + r * sin(stop)
        let largeArc = if (stop - start > 3.141592653589793) { 1 } else { 0 }
        out.append("<path class=\"pie-slice\" d=\"M ")
        out.append(cx)
        out.append(" ")
        out.append(cy)
        out.append(" L ")
        out.append(x1)
        out.append(" ")
        out.append(y1)
        out.append(" A ")
        out.append(r)
        out.append(" ")
        out.append(r)
        out.append(" 0 ")
        out.append(largeArc)
        out.append(" 1 ")
        out.append(x2)
        out.append(" ")
        out.append(y2)
        out.append(" Z\" fill=\"")
        SvgEscaper.appendAttribute(out, color)
        out.append("\" stroke=\"#ffffff\" stroke-width=\"1\"/>")
    }

    private func appendLegend(out: StringBuilder, row: GenericRow, x: Float64, y: Float64, color: String): Unit {
        out.append("<rect x=\"")
        out.append(x)
        out.append("\" y=\"")
        out.append(y - 12.0)
        out.append("\" width=\"14\" height=\"14\" fill=\"")
        SvgEscaper.appendAttribute(out, color)
        out.append("\"/><text class=\"generic-label\" x=\"")
        out.append(x + 22.0)
        out.append("\" y=\"")
        out.append(y)
        out.append("\">")
        SvgEscaper.appendText(out, row.label)
        out.append(" (")
        out.append(row.value)
        out.append(")</text>")
    }

    private func pieTotal(rows: ArrayList<GenericRow>): Float64 {
        var total = 0.0
        for (row in rows) {
            total += row.value
        }
        return total
    }

    private func pieColor(index: Int64): String {
        let colors = ["#5470c6", "#91cc75", "#fac858", "#ee6666", "#73c0de", "#3ba272", "#fc8452", "#9a60b4"]
        return colors[index % colors.size]
    }

    private func kindClass(kind: DiagramKind): String {
        match (kind) {
            case DiagramKind.Mindmap => return "mindmap"
            case DiagramKind.Class => return "class"
            case DiagramKind.Er => return "er"
            case DiagramKind.Gantt => return "gantt"
            case _ => return "generic"
        }
    }

    private func appendGanttGrid(out: StringBuilder, left: Float64, top: Float64, rowHeight: Float64, dayWidth: Float64, span: Int64, rows: Int64, minStart: Int64): Unit {
        let height = Float64(max(1, rows)) * rowHeight + 16.0
        for (i in 0..(span + 1)) {
            let x = left + Float64(i) * dayWidth
            out.append("<path class=\"gantt-grid\" d=\"M ")
            out.append(x)
            out.append(" ")
            out.append(top)
            out.append(" L ")
            out.append(x)
            out.append(" ")
            out.append(top + height)
            out.append("\"/>")
            if (i % 2 == 0) {
                out.append("<text class=\"gantt-axis\" x=\"")
                out.append(x + 2.0)
                out.append("\" y=\"")
                out.append(top - 4.0)
                out.append("\">")
                out.append(minStart + i)
                out.append("</text>")
            }
        }
    }

    private func appendGanttTask(out: StringBuilder, task: GenericTask, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        out.append("<rect class=\"gantt-task ")
        out.append(ganttTaskClass(task.status))
        out.append("\" data-id=\"")
        SvgEscaper.appendAttribute(out, task.id)
        out.append("\" x=\"")
        out.append(x)
        out.append("\" y=\"")
        out.append(y)
        out.append("\" width=\"")
        out.append(width)
        out.append("\" height=\"")
        out.append(height)
        out.append("\" rx=\"3\"/>")
    }

    private func ganttTaskClass(status: String): String {
        if (status.contains("crit")) {
            return "gantt-task-crit"
        }
        if (status.contains("done")) {
            return "gantt-task-done"
        }
        if (status.contains("active")) {
            return "gantt-task-active"
        }
        return "gantt-task-default"
    }

    private func ganttMinStart(diagram: GenericDiagram): Int64 {
        if (diagram.tasks.size == 0) {
            return 0
        }
        var value = diagram.tasks[0].start
        for (task in diagram.tasks) {
            if (task.start < value) {
                value = task.start
            }
        }
        return value
    }

    private func ganttMaxEnd(diagram: GenericDiagram, fallback: Int64): Int64 {
        var value = fallback
        for (task in diagram.tasks) {
            if (task.end > value) {
                value = task.end
            }
        }
        return value
    }

    private func appendRectNode(out: StringBuilder, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        out.append("<rect class=\"generic-node\" x=\"")
        out.append(x)
        out.append("\" y=\"")
        out.append(y)
        out.append("\" width=\"")
        out.append(width)
        out.append("\" height=\"")
        out.append(height)
        out.append("\" rx=\"6\"/>")
    }
}

class NodePos {
    let x: Float64
    let y: Float64

    init(x: Float64, y: Float64) {
        this.x = x
        this.y = y
    }
}
