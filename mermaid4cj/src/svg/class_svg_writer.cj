package mermaid4cj.svg

import std.collection.HashMap
import mermaid4cj.core.{ClassDef, ClassDiagram, ClassMember, ClassRelation, MermaidRenderOptions}

public class ClassSvgWriter {
    public init() {}

    public func write(diagram: ClassDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let classWidth = maxClassWidth(diagram, options)
        let top = if (diagram.title.isSome()) { 62.0 } else { 28.0 }
        let gapX = 74.0
        let gapY = 64.0
        let columns = min(3, max(1, diagram.classes.size))
        let positions = HashMap<String, ClassBox>()
        var maxRowBottom = top

        for (i in 0..diagram.classes.size) {
            let classDef = diagram.classes[i]
            let row = i / columns
            let col = i % columns
            let height = classHeight(classDef)
            let x = 38.0 + Float64(col) * (classWidth + gapX)
            let y = top + Float64(row) * (142.0 + gapY)
            positions[classDef.id] = ClassBox(x, y, classWidth, height)
            if (y + height > maxRowBottom) {
                maxRowBottom = y + height
            }
        }

        let noteTop = if (diagram.notes.size > 0) { maxRowBottom + 24.0 } else { maxRowBottom }
        let width = 76.0 + Float64(columns) * classWidth + Float64(max(0, columns - 1)) * gapX
        let height = noteTop + Float64(diagram.notes.size) * 46.0 + 38.0
        let out = StringBuilder(4096 + diagram.source.size)

        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-class mermaid4cj-class\" xmlns=\"http://www.w3.org/2000/svg\" width=\"")
        out.append(width)
        out.append("\" height=\"")
        out.append(height)
        out.append("\" viewBox=\"0 0 ")
        out.append(width)
        out.append(" ")
        out.append(height)
        out.append("\" role=\"img\">")
        appendStyle(out, options.idPrefix, theme)
        appendMarkers(out, options.idPrefix, theme)
        if (let Some(title) <- diagram.title) {
            out.append("<text class=\"class-title\" x=\"")
            out.append(width / 2.0)
            out.append("\" y=\"28\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, title)
            out.append("</text>")
        }
        out.append("<g class=\"class-relations\">")
        for (relation in diagram.relations) {
            appendRelation(out, options, relation, positions)
        }
        out.append("</g><g class=\"class-nodes\">")
        for (classDef in diagram.classes) {
            appendClass(out, options, classDef, positions.get(classDef.id).getOrThrow())
        }
        out.append("</g>")
        if (diagram.notes.size > 0) {
            out.append("<g class=\"class-notes\">")
            for (i in 0..diagram.notes.size) {
                let note = diagram.notes[i]
                out.append("<g class=\"class-note\"><rect x=\"38\" y=\"")
                out.append(noteTop + Float64(i) * 46.0)
                out.append("\" width=\"")
                out.append(max(160.0, Float64(note.text.size) * 7.0 + 28.0))
                out.append("\" height=\"34\" rx=\"2\"/><text x=\"52\" y=\"")
                out.append(noteTop + Float64(i) * 46.0 + 22.0)
                out.append("\">")
                SvgEscaper.appendText(out, note.text)
                out.append("</text></g>")
            }
            out.append("</g>")
        }
        out.append("</svg>")
        return out.toString()
    }

    private func appendStyle(out: StringBuilder, idPrefix: String, theme: SvgTheme): Unit {
        out.append("<style>")
        appendSvgStyleScope(out, idPrefix)
        out.append("{background:")
        out.append(theme.background)
        out.append(";font-family:Arial,sans-serif;font-size:13px}")
        appendSvgStyleScopeSelector(out, idPrefix, "text")
        out.append("{fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-title")
        out.append("{font-size:18px;font-weight:bold}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-box")
        out.append("{fill:")
        out.append(theme.nodeFill)
        out.append(";stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1.4}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-divider")
        out.append("{stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-name")
        out.append("{font-weight:bold;text-anchor:middle}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-annotation")
        out.append("{font-style:italic;text-anchor:middle}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-member")
        out.append("{text-anchor:start}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-relation")
        out.append("{fill:none;stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1.5}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-relation-dashed")
        out.append("{stroke-dasharray:5 5}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-relation-label")
        out.append("{fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, idPrefix, ".class-note rect")
        out.append("{fill:#fff5ad;stroke:#d6b656;stroke-width:1.2}</style>")
    }

    private func appendMarkers(out: StringBuilder, idPrefix: String, theme: SvgTheme): Unit {
        let color = SvgEscaper.attribute(theme.edge)
        out.append("<defs><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-class-association\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"8\" markerHeight=\"8\" orient=\"auto-start-reverse\"><path d=\"M 0 0 L 10 5 L 0 10\" fill=\"none\" stroke=\"")
        out.append(color)
        out.append("\" stroke-width=\"1.7\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-class-inheritance\" viewBox=\"0 0 12 10\" refX=\"11\" refY=\"5\" markerWidth=\"10\" markerHeight=\"10\" orient=\"auto-start-reverse\"><path d=\"M 1 1 L 11 5 L 1 9 Z\" fill=\"")
        out.append(SvgEscaper.attribute(theme.background))
        out.append("\" stroke=\"")
        out.append(color)
        out.append("\" stroke-width=\"1.4\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-class-composition\" viewBox=\"0 0 12 10\" refX=\"11\" refY=\"5\" markerWidth=\"10\" markerHeight=\"10\" orient=\"auto-start-reverse\"><path d=\"M 1 5 L 6 1 L 11 5 L 6 9 Z\" fill=\"")
        out.append(color)
        out.append("\" stroke=\"")
        out.append(color)
        out.append("\" stroke-width=\"1.2\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-class-aggregation\" viewBox=\"0 0 12 10\" refX=\"11\" refY=\"5\" markerWidth=\"10\" markerHeight=\"10\" orient=\"auto-start-reverse\"><path d=\"M 1 5 L 6 1 L 11 5 L 6 9 Z\" fill=\"")
        out.append(SvgEscaper.attribute(theme.background))
        out.append("\" stroke=\"")
        out.append(color)
        out.append("\" stroke-width=\"1.2\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-class-lollipop\" viewBox=\"0 0 12 12\" refX=\"10\" refY=\"6\" markerWidth=\"11\" markerHeight=\"11\" orient=\"auto-start-reverse\"><circle cx=\"6\" cy=\"6\" r=\"4\" fill=\"")
        out.append(SvgEscaper.attribute(theme.background))
        out.append("\" stroke=\"")
        out.append(color)
        out.append("\" stroke-width=\"1.4\"/></marker></defs>")
    }

    private func appendClass(out: StringBuilder, options: MermaidRenderOptions, classDef: ClassDef, box: ClassBox): Unit {
        let attributes = countMembers(classDef, false)
        let methods = countMembers(classDef, true)
        let headerHeight = if (classDef.annotation.isSome()) { 43.0 } else { 27.0 }
        let attrHeight = max(22.0, Float64(attributes) * 18.0 + 10.0)
        out.append("<g class=\"class-node\" id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("-")
        SvgEscaper.appendAttribute(out, classDef.id)
        out.append("\"><rect class=\"class-box\" x=\"")
        out.append(box.x)
        out.append("\" y=\"")
        out.append(box.y)
        out.append("\" width=\"")
        out.append(box.width)
        out.append("\" height=\"")
        out.append(box.height)
        out.append("\" rx=\"2\"/>")
        if (let Some(annotation) <- classDef.annotation) {
            out.append("<text class=\"class-annotation\" x=\"")
            out.append(box.x + box.width / 2.0)
            out.append("\" y=\"")
            out.append(box.y + 16.0)
            out.append("\">&lt;&lt;")
            SvgEscaper.appendText(out, annotation)
            out.append("&gt;&gt;</text>")
        }
        out.append("<text class=\"class-name\" x=\"")
        out.append(box.x + box.width / 2.0)
        out.append("\" y=\"")
        out.append(box.y + headerHeight - 9.0)
        out.append("\">")
        SvgEscaper.appendText(out, classDef.label)
        if (let Some(genericType) <- classDef.genericType) {
            out.append("~")
            SvgEscaper.appendText(out, genericType)
            out.append("~")
        }
        out.append("</text><path class=\"class-divider\" d=\"M ")
        out.append(box.x)
        out.append(" ")
        out.append(box.y + headerHeight)
        out.append(" L ")
        out.append(box.x + box.width)
        out.append(" ")
        out.append(box.y + headerHeight)
        out.append("\"/><path class=\"class-divider\" d=\"M ")
        out.append(box.x)
        out.append(" ")
        out.append(box.y + headerHeight + attrHeight)
        out.append(" L ")
        out.append(box.x + box.width)
        out.append(" ")
        out.append(box.y + headerHeight + attrHeight)
        out.append("\"/>")
        appendMembers(out, classDef, box.x + 10.0, box.y + headerHeight + 18.0, false)
        appendMembers(out, classDef, box.x + 10.0, box.y + headerHeight + attrHeight + 18.0, true)
        out.append("</g>")
    }

    private func appendMembers(out: StringBuilder, classDef: ClassDef, x: Float64, startY: Float64, methods: Bool): Unit {
        var index: Int64 = 0
        for (member in classDef.members) {
            if (member.isMethod == methods) {
                out.append("<text class=\"class-member")
                if (member.text.endsWith("$")) {
                    out.append(" class-static")
                }
                if (member.text.endsWith("*")) {
                    out.append(" class-abstract")
                }
                out.append("\" x=\"")
                out.append(x)
                out.append("\" y=\"")
                out.append(startY + Float64(index) * 18.0)
                out.append("\">")
                SvgEscaper.appendText(out, member.text)
                out.append("</text>")
                index++
            }
        }
    }

    private func appendRelation(out: StringBuilder, options: MermaidRenderOptions, relation: ClassRelation, positions: HashMap<String, ClassBox>): Unit {
        if (positions.get(relation.source).isNone() || positions.get(relation.target).isNone()) {
            return
        }
        let source = positions.get(relation.source).getOrThrow()
        let target = positions.get(relation.target).getOrThrow()
        let start = anchor(source, target)
        let end = anchor(target, source)
        out.append("<g class=\"class-relation-group\"><path class=\"class-relation")
        if (relation.dashed) {
            out.append(" class-relation-dashed")
        }
        out.append("\" d=\"M ")
        out.append(start.x)
        out.append(" ")
        out.append(start.y)
        out.append(" L ")
        out.append(end.x)
        out.append(" ")
        out.append(end.y)
        out.append("\"")
        appendMarker(out, options.idPrefix, "start", relation.startMarker)
        appendMarker(out, options.idPrefix, "end", relation.endMarker)
        out.append("/>")
        if (!relation.label.isEmpty()) {
            let labelX = (start.x + end.x) / 2.0
            let labelY = (start.y + end.y) / 2.0 - 6.0
            out.append("<text class=\"class-relation-label\" x=\"")
            out.append(labelX)
            out.append("\" y=\"")
            out.append(labelY)
            out.append("\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, relation.label)
            out.append("</text>")
        }
        out.append("</g>")
    }

    private func appendMarker(out: StringBuilder, idPrefix: String, attr: String, marker: String): Unit {
        if (marker.isEmpty()) {
            return
        }
        out.append(" marker-")
        out.append(attr)
        out.append("=\"url(#")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-class-")
        out.append(marker)
        out.append(")\"")
    }

    private func classHeight(classDef: ClassDef): Float64 {
        let header = if (classDef.annotation.isSome()) { 43.0 } else { 27.0 }
        let attrs = max(22.0, Float64(countMembers(classDef, false)) * 18.0 + 10.0)
        let methods = max(22.0, Float64(countMembers(classDef, true)) * 18.0 + 10.0)
        return header + attrs + methods
    }

    private func maxClassWidth(diagram: ClassDiagram, options: MermaidRenderOptions): Float64 {
        var width = 184.0
        for (classDef in diagram.classes) {
            width = max(width, classWidth(classDef, options))
        }
        return width
    }

    private func classWidth(classDef: ClassDef, options: MermaidRenderOptions): Float64 {
        var width = options.textMeasurer.measureText(classDef.label) + 32.0
        if (let Some(genericType) <- classDef.genericType) {
            width = max(width, options.textMeasurer.measureText("${classDef.label}~${genericType}~") + 32.0)
        }
        if (let Some(annotation) <- classDef.annotation) {
            width = max(width, options.textMeasurer.measureText("<<${annotation}>>") + 32.0)
        }
        for (member in classDef.members) {
            width = max(width, options.textMeasurer.measureText(member.text) + 28.0)
        }
        return width
    }

    private func countMembers(classDef: ClassDef, methods: Bool): Int64 {
        var count: Int64 = 0
        for (member in classDef.members) {
            if (member.isMethod == methods) {
                count++
            }
        }
        return count
    }

    private func anchor(from: ClassBox, to: ClassBox): ClassPoint {
        let fromCx = from.x + from.width / 2.0
        let fromCy = from.y + from.height / 2.0
        let toCx = to.x + to.width / 2.0
        let toCy = to.y + to.height / 2.0
        let dx = toCx - fromCx
        let dy = toCy - fromCy
        if (absFloat(dx) > absFloat(dy)) {
            if (dx >= 0.0) {
                return ClassPoint(from.x + from.width, fromCy)
            }
            return ClassPoint(from.x, fromCy)
        }
        if (dy >= 0.0) {
            return ClassPoint(fromCx, from.y + from.height)
        }
        return ClassPoint(fromCx, from.y)
    }

    private func absFloat(value: Float64): Float64 {
        if (value < 0.0) {
            return -value
        }
        return value
    }
}

class ClassBox {
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

class ClassPoint {
    let x: Float64
    let y: Float64

    init(x: Float64, y: Float64) {
        this.x = x
        this.y = y
    }
}
