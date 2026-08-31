package mermaid4cj.svg

import std.math.{cos, sin}
import mermaid4cj.core.{MermaidRenderOptions, PieDiagram, PieSlice}

public class PieSvgWriter {
    public init() {}

    public func write(diagram: PieDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let width = 560.0
        let height = 360.0
        let cx = 175.0
        let cy = if (diagram.title.isSome()) { 190.0 } else { 175.0 }
        let radius = 112.0
        let total = totalValue(diagram)
        let out = StringBuilder(4096 + diagram.source.size)
        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-pie mermaid4cj-pie\" xmlns=\"http://www.w3.org/2000/svg\" width=\"")
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
        appendSvgStyleScopeSelector(out, options.idPrefix, ".pie-title")
        out.append("{font-size:18px;font-weight:bold;fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".pie-label")
        out.append(",")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".pie-legend")
        out.append("{fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, options.idPrefix, ".pie-slice")
        out.append("{stroke:")
        out.append(theme.background)
        out.append(";stroke-width:1.5}</style>")
        if (let Some(title) <- diagram.title) {
            out.append("<text class=\"pie-title\" x=\"")
            out.append(width / 2.0)
            out.append("\" y=\"28\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, title)
            out.append("</text>")
        }
        var start = -1.5707963267948966
        out.append("<g class=\"pie-slices\">")
        for (i in 0..diagram.slices.size) {
            let slice = diagram.slices[i]
            let percent = percentOf(slice.value, total)
            let angle = if (total > 0.0) { slice.value / total * 6.283185307179586 } else { 0.0 }
            if (shouldRenderSlice(percent)) {
                appendSlice(out, slice, cx, cy, radius, start, start + angle, colorFor(i), percent)
            }
            start += angle
        }
        out.append("</g><g class=\"pie-legend\">")
        for (i in 0..diagram.slices.size) {
            appendLegend(out, diagram.slices[i], 340.0, 84.0 + Float64(i) * 30.0, colorFor(i), diagram.showData, percentOf(diagram.slices[i].value, total))
        }
        out.append("</g></svg>")
        return out.toString()
    }

    private func appendSlice(out: StringBuilder, slice: PieSlice, cx: Float64, cy: Float64, r: Float64, start: Float64, stop: Float64, color: String, percent: Float64): Unit {
        let x1 = cx + r * cos(start)
        let y1 = cy + r * sin(start)
        let x2 = cx + r * cos(stop)
        let y2 = cy + r * sin(stop)
        let largeArc = if (stop - start > 3.141592653589793) { 1 } else { 0 }
        out.append("<path class=\"pie-slice\" data-label=\"")
        SvgEscaper.appendAttribute(out, slice.label)
        out.append("\" data-value=\"")
        out.append(slice.value)
        out.append("\" data-percent=\"")
        out.append(percent)
        out.append("\" d=\"M ")
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
        out.append("\"/>")
    }

    private func appendLegend(out: StringBuilder, slice: PieSlice, x: Float64, y: Float64, color: String, showData: Bool, percent: Float64): Unit {
        out.append("<rect x=\"")
        out.append(x)
        out.append("\" y=\"")
        out.append(y - 12.0)
        out.append("\" width=\"14\" height=\"14\" fill=\"")
        SvgEscaper.appendAttribute(out, color)
        out.append("\"/><text class=\"pie-legend\" x=\"")
        out.append(x + 22.0)
        out.append("\" y=\"")
        out.append(y)
        out.append("\">")
        SvgEscaper.appendText(out, slice.label)
        out.append(" ")
        out.append(formatPercent(percent))
        out.append("%")
        if (showData) {
            out.append(" (")
            out.append(slice.value)
            out.append(")")
        }
        out.append("</text>")
    }

    private func totalValue(diagram: PieDiagram): Float64 {
        var total = 0.0
        for (slice in diagram.slices) {
            total += slice.value
        }
        return total
    }

    private func percentOf(value: Float64, total: Float64): Float64 {
        if (total <= 0.0) {
            return 0.0
        }
        return value / total * 100.0
    }

    private func shouldRenderSlice(percent: Float64): Bool {
        if (percent < 1.0) {
            return false
        }
        return Int64(percent + 0.5) != 0
    }

    private func formatPercent(value: Float64): String {
        let scaled = Int64(value * 10.0 + 0.5)
        return "${scaled / 10}.${scaled % 10}"
    }

    private func colorFor(index: Int64): String {
        let colors = ["#4e79a7", "#f28e2b", "#59a14f", "#e15759", "#76b7b2", "#edc948", "#b07aa1", "#ff9da7", "#9c755f", "#bab0ab"]
        return colors[index % colors.size]
    }
}
