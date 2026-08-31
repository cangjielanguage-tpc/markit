package mermaid4cj.svg

import mermaid4cj.core.{GanttDiagram, GanttTask, MermaidRenderOptions}

public class GanttSvgWriter {
    public init() {}

    public func write(diagram: GanttDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let minStart = minStart(diagram)
        let maxEnd = maxEnd(diagram, minStart + 1440)
        let span = max(1, maxEnd - minStart)
        let left = 210.0
        let top = if (diagram.title.isSome()) { 66.0 } else { 38.0 }
        let rowHeight = 34.0
        let barHeight = 18.0
        let axisWidth = 480.0
        let scale = axisWidth / Float64(span)
        let width = left + axisWidth + 64.0
        let height = top + Float64(max(1, diagram.tasks.size)) * rowHeight + 54.0
        let out = StringBuilder(4096 + diagram.source.size)

        appendStart(out, options, theme, width, height)
        if (let Some(title) <- diagram.title) {
            out.append("<text class=\"gantt-title\" x=\"")
            out.append(width / 2.0)
            out.append("\" y=\"28\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, title)
            out.append("</text>")
        }
        appendAxis(out, diagram, left, top - 20.0, axisWidth, rowHeight, minStart, maxEnd)
        appendTodayMarker(out, diagram, left, top - 20.0, axisWidth, height - top + 8.0)
        var lastSection = ""
        for (i in 0..diagram.tasks.size) {
            let task = diagram.tasks[i]
            let y = top + Float64(i) * rowHeight
            if (task.section != lastSection && !task.section.isEmpty()) {
                out.append("<text class=\"gantt-section\" x=\"14\" y=\"")
                out.append(y + 19.0)
                out.append("\">")
                SvgEscaper.appendText(out, task.section)
                out.append("</text>")
                lastSection = task.section
            }
            out.append("<text class=\"gantt-task-label\" x=\"")
            out.append(left - 12.0)
            out.append("\" y=\"")
            out.append(y + 20.0)
            out.append("\" text-anchor=\"end\">")
            SvgEscaper.appendText(out, task.label)
            out.append("</text>")
            let x = left + Float64(task.start - minStart) * scale
            let w = max(8.0, Float64(max(1, task.end - task.start)) * scale)
            appendTask(out, task, x, y + 8.0, w, barHeight)
        }
        out.append("</svg>")
        return out.toString()
    }

    private func appendStart(out: StringBuilder, options: MermaidRenderOptions, theme: SvgTheme, width: Float64, height: Float64): Unit {
        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-gantt mermaid4cj-gantt\" xmlns=\"http://www.w3.org/2000/svg\" width=\"")
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
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-title")
        out.append("{font-size:18px;font-weight:bold;fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-section")
        out.append("{font-size:14px;font-weight:bold;fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-label")
        out.append(",")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-axis")
        out.append("{fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-grid")
        out.append("{stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:.6;opacity:.25}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task")
        out.append("{stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-default")
        out.append("{fill:")
        out.append(theme.nodeFill)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-active")
        out.append("{fill:#5b9bd5}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-done")
        out.append("{fill:#7cc576}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-crit")
        out.append("{fill:#d9534f}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-task-milestone")
        out.append("{fill:#f0ad4e}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".gantt-today")
        out.append("{stroke:#d9534f;stroke-width:2;stroke-dasharray:5 4}</style>")
    }

    private func appendAxis(out: StringBuilder, diagram: GanttDiagram, left: Float64, top: Float64, axisWidth: Float64, rowHeight: Float64, minStart: Int64, maxEnd: Int64): Unit {
        let rows = max(1, diagram.tasks.size)
        let ticks: Int64 = min(8, max(2, rows + 1))
        let gridHeight = Float64(rows) * rowHeight + 16.0
        for (i in 0..(ticks + 1)) {
            let x = left + axisWidth * Float64(i) / Float64(ticks)
            let value = minStart + (maxEnd - minStart) * i / ticks
            out.append("<path class=\"gantt-grid\" d=\"M ")
            out.append(x)
            out.append(" ")
            out.append(top)
            out.append(" L ")
            out.append(x)
            out.append(" ")
            out.append(top + gridHeight)
            out.append("\"/>")
            out.append("<text class=\"gantt-axis\" x=\"")
            out.append(x + 2.0)
            out.append("\" y=\"")
            out.append(top - 4.0)
            out.append("\">")
            out.append(axisLabel(value, diagram.dateFormat))
            out.append("</text>")
        }
    }

    private func appendTodayMarker(out: StringBuilder, diagram: GanttDiagram, left: Float64, top: Float64, axisWidth: Float64, height: Float64): Unit {
        if (diagram.todayMarker.toAsciiLower() == "off" || diagram.todayMarker.isEmpty()) {
            return
        }
        let x = left + axisWidth / 2.0
        out.append("<path class=\"gantt-today\" d=\"M ")
        out.append(x)
        out.append(" ")
        out.append(top)
        out.append(" L ")
        out.append(x)
        out.append(" ")
        out.append(top + height)
        out.append("\"/>")
    }

    private func appendTask(out: StringBuilder, task: GanttTask, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        if (task.milestone || task.vert) {
            let cx = x + width / 2.0
            let cy = y + height / 2.0
            out.append("<path class=\"gantt-task gantt-task-milestone")
            appendTaskStateClasses(out, task)
            out.append("\" data-id=\"")
            SvgEscaper.appendAttribute(out, task.id)
            out.append("\" d=\"M ")
            out.append(cx)
            out.append(" ")
            out.append(cy - 9.0)
            out.append(" L ")
            out.append(cx + 9.0)
            out.append(" ")
            out.append(cy)
            out.append(" L ")
            out.append(cx)
            out.append(" ")
            out.append(cy + 9.0)
            out.append(" L ")
            out.append(cx - 9.0)
            out.append(" ")
            out.append(cy)
            out.append(" Z\"/>")
            return
        }
        out.append("<rect class=\"gantt-task gantt-task-default")
        appendTaskStateClasses(out, task)
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

    private func appendTaskStateClasses(out: StringBuilder, task: GanttTask): Unit {
        if (task.done) {
            out.append(" gantt-task-done")
        }
        if (task.active) {
            out.append(" gantt-task-active")
        }
        if (task.crit) {
            out.append(" gantt-task-crit")
        }
    }

    private func minStart(diagram: GanttDiagram): Int64 {
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

    private func maxEnd(diagram: GanttDiagram, fallback: Int64): Int64 {
        var value = fallback
        for (task in diagram.tasks) {
            if (task.end > value) {
                value = task.end
            }
        }
        return value
    }

    private func axisLabel(value: Int64, dateFormat: String): String {
        if (dateFormat == "HH:mm") {
            let h = value / 60
            let m = value % 60
            return "${pad2(h)}:${pad2(m)}"
        }
        if (dateFormat == "YYYY") {
            return "${value / 525600}"
        }
        return "${value / 1440}"
    }

    private func pad2(value: Int64): String {
        if (value < 10) {
            return "0${value}"
        }
        return "${value}"
    }
}
