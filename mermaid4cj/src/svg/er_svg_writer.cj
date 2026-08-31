package mermaid4cj.svg

import std.collection.HashMap
import mermaid4cj.core.{ErCardinality, ErDiagram, ErDirection, ErEntity, ErRelationship, MermaidRenderOptions}

public class ErSvgWriter {
    public init() {}

    public func write(diagram: ErDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let horizontal = isHorizontal(diagram.direction)
        let entityWidth = maxEntityWidth(diagram, options)
        let gapX = 140.0
        let gapY = 80.0
        let columns = if (horizontal) { max(1, diagram.entities.size) } else { min(3, max(1, diagram.entities.size)) }
        let positions = HashMap<String, ErBox>()
        let top = if (diagram.title.isSome()) { 62.0 } else { 30.0 }
        var maxRight = 38.0
        var maxBottom = top

        for (i in 0..diagram.entities.size) {
            let entity = diagram.entities[i]
            let row = if (horizontal) { 0 } else { i / columns }
            let col = if (horizontal) { i } else { i % columns }
            let height = entityHeight(entity)
            let x = 38.0 + Float64(col) * (entityWidth + gapX)
            let y = top + Float64(row) * (112.0 + gapY)
            positions[entity.id] = ErBox(x, y, entityWidth, height)
            maxRight = max(maxRight, x + entityWidth)
            maxBottom = max(maxBottom, y + height)
        }

        let width = maxRight + 38.0
        let height = maxBottom + 38.0
        let out = StringBuilder(4096 + diagram.source.size)
        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-er mermaid4cj-er\" xmlns=\"http://www.w3.org/2000/svg\" width=\"")
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
            out.append("<text class=\"er-title\" x=\"")
            out.append(width / 2.0)
            out.append("\" y=\"28\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, title)
            out.append("</text>")
        }
        out.append("<g class=\"er-relationships\">")
        for (relationship in diagram.relationships) {
            appendRelationship(out, options, theme, relationship, positions)
        }
        out.append("</g><g class=\"er-entities\">")
        for (entity in diagram.entities) {
            appendEntity(out, options, entity, positions.get(entity.id).getOrThrow())
        }
        out.append("</g></svg>")
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
        appendSvgStyleScopeSelector(out, idPrefix, ".er-title")
        out.append("{font-size:18px;font-weight:bold}")
        appendSvgStyleScopeSelector(out, idPrefix, ".er-entity-box")
        out.append("{fill:")
        out.append(theme.nodeFill)
        out.append(";stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1.4}")
        appendSvgStyleScopeSelector(out, idPrefix, ".er-entity-name")
        out.append("{font-weight:bold;text-anchor:middle}")
        appendSvgStyleScopeSelector(out, idPrefix, ".er-divider")
        out.append("{stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1}")
        appendSvgStyleScopeSelector(out, idPrefix, ".er-attribute-type")
        out.append("{font-family:monospace}")
        appendSvgStyleScopeSelector(out, idPrefix, ".er-attribute-key")
        out.append("{font-size:11px;font-weight:bold}")
        appendSvgStyleScopeSelector(out, idPrefix, ".er-relationship")
        out.append("{fill:none;stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1}")
        appendSvgStyleScopeSelector(out, idPrefix, ".er-relationship-dashed")
        out.append("{stroke-dasharray:5 5}")
        appendSvgStyleScopeSelector(out, idPrefix, ".er-relationship-label")
        out.append("{fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, idPrefix, ".marker")
        out.append("{fill:none!important;stroke:")
        out.append(theme.edge)
        out.append("!important;stroke-width:1}")
        out.append("</style>")
    }

    private func appendMarkers(out: StringBuilder, idPrefix: String, theme: SvgTheme): Unit {
        let edge = SvgEscaper.attribute(theme.edge)
        let circleFill = cardinalityCircleFill(theme)
        out.append("<defs><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-er-onlyOneStart\" class=\"marker onlyOne er\" refX=\"0\" refY=\"9\" markerWidth=\"18\" markerHeight=\"18\" orient=\"auto\" markerUnits=\"userSpaceOnUse\"><path d=\"M9,0 L9,18 M15,0 L15,18\" fill=\"none\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-er-onlyOneEnd\" class=\"marker onlyOne er\" refX=\"18\" refY=\"9\" markerWidth=\"18\" markerHeight=\"18\" orient=\"auto\" markerUnits=\"userSpaceOnUse\"><path d=\"M3,0 L3,18 M9,0 L9,18\" fill=\"none\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-er-zeroOrOneStart\" class=\"marker zeroOrOne er\" refX=\"0\" refY=\"9\" markerWidth=\"30\" markerHeight=\"18\" orient=\"auto\" markerUnits=\"userSpaceOnUse\"><circle cx=\"21\" cy=\"9\" r=\"6\" fill=\"")
        out.append(circleFill)
        out.append("\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/><path d=\"M9,0 L9,18\" fill=\"none\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-er-zeroOrOneEnd\" class=\"marker zeroOrOne er\" refX=\"30\" refY=\"9\" markerWidth=\"30\" markerHeight=\"18\" orient=\"auto\" markerUnits=\"userSpaceOnUse\"><circle cx=\"9\" cy=\"9\" r=\"6\" fill=\"")
        out.append(circleFill)
        out.append("\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/><path d=\"M21,0 L21,18\" fill=\"none\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-er-oneOrMoreStart\" class=\"marker oneOrMore er\" refX=\"18\" refY=\"18\" markerWidth=\"45\" markerHeight=\"36\" orient=\"auto\" markerUnits=\"userSpaceOnUse\"><path d=\"M0,18 Q 18,0 36,18 Q 18,36 0,18 M42,9 L42,27\" fill=\"none\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-er-oneOrMoreEnd\" class=\"marker oneOrMore er\" refX=\"27\" refY=\"18\" markerWidth=\"45\" markerHeight=\"36\" orient=\"auto\" markerUnits=\"userSpaceOnUse\"><path d=\"M3,9 L3,27 M9,18 Q27,0 45,18 Q27,36 9,18\" fill=\"none\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-er-zeroOrMoreStart\" class=\"marker zeroOrMore er\" refX=\"18\" refY=\"18\" markerWidth=\"57\" markerHeight=\"36\" orient=\"auto\" markerUnits=\"userSpaceOnUse\"><circle cx=\"45.5\" cy=\"18\" r=\"6\" fill=\"")
        out.append(circleFill)
        out.append("\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/><path d=\"M0,18 Q18,0 36,18 Q18,36 0,18\" fill=\"none\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-er-zeroOrMoreEnd\" class=\"marker zeroOrMore er\" refX=\"39\" refY=\"18\" markerWidth=\"57\" markerHeight=\"36\" orient=\"auto\" markerUnits=\"userSpaceOnUse\"><circle cx=\"11\" cy=\"18\" r=\"6\" fill=\"")
        out.append(circleFill)
        out.append("\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/><path d=\"M21,18 Q39,0 57,18 Q39,36 21,18\" fill=\"none\" stroke=\"")
        out.append(edge)
        out.append("\" stroke-width=\"1\"/></marker></defs>")
    }

    private func cardinalityCircleFill(theme: SvgTheme): String {
        if (theme.background == "transparent") {
            return "#ffffff"
        }
        return SvgEscaper.attribute(theme.background)
    }

    private func appendEntity(out: StringBuilder, options: MermaidRenderOptions, entity: ErEntity, box: ErBox): Unit {
        out.append("<g class=\"er-entity\" id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("-")
        SvgEscaper.appendAttribute(out, entity.id)
        out.append("\"><rect class=\"er-entity-box\" x=\"")
        out.append(box.x)
        out.append("\" y=\"")
        out.append(box.y)
        out.append("\" width=\"")
        out.append(box.width)
        out.append("\" height=\"")
        out.append(box.height)
        out.append("\" rx=\"2\"/><text class=\"er-entity-name\" x=\"")
        out.append(box.x + box.width / 2.0)
        out.append("\" y=\"")
        out.append(box.y + 20.0)
        out.append("\">")
        SvgEscaper.appendText(out, entity.label)
        out.append("</text><path class=\"er-divider\" d=\"M ")
        out.append(box.x)
        out.append(" ")
        out.append(box.y + 30.0)
        out.append(" L ")
        out.append(box.x + box.width)
        out.append(" ")
        out.append(box.y + 30.0)
        out.append("\"/>")
        for (i in 0..entity.attributes.size) {
            let attr = entity.attributes[i]
            let y = box.y + 49.0 + Float64(i) * 18.0
            out.append("<text class=\"er-attribute-type\" x=\"")
            out.append(box.x + 10.0)
            out.append("\" y=\"")
            out.append(y)
            out.append("\">")
            SvgEscaper.appendText(out, attr.attributeType)
            out.append("</text><text class=\"er-attribute-name\" x=\"")
            out.append(box.x + box.width * 0.38)
            out.append("\" y=\"")
            out.append(y)
            out.append("\">")
            SvgEscaper.appendText(out, attr.name)
            out.append("</text>")
            if (!attr.key.isEmpty()) {
                out.append("<text class=\"er-attribute-key\" x=\"")
                out.append(box.x + box.width - 12.0)
                out.append("\" y=\"")
                out.append(y)
                out.append("\" text-anchor=\"end\">")
                SvgEscaper.appendText(out, attr.key)
                out.append("</text>")
            }
        }
        out.append("</g>")
    }

    private func appendRelationship(out: StringBuilder, options: MermaidRenderOptions, theme: SvgTheme, relationship: ErRelationship, positions: HashMap<String, ErBox>): Unit {
        if (positions.get(relationship.source).isNone() || positions.get(relationship.target).isNone()) {
            return
        }
        let source = positions.get(relationship.source).getOrThrow()
        let target = positions.get(relationship.target).getOrThrow()
        let start = anchor(source, target)
        let stop = anchor(target, source)
        out.append("<g class=\"er-relationship-group\"><path class=\"er-relationship")
        if (!relationship.identifying) {
            out.append(" er-relationship-dashed")
        }
        out.append("\" d=\"M ")
        out.append(start.x)
        out.append(" ")
        out.append(start.y)
        out.append(" L ")
        out.append(stop.x)
        out.append(" ")
        out.append(stop.y)
        out.append("\" marker-start=\"url(#")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("-er-")
        out.append(cardinalityMarkerName(relationship.sourceCardinality, true))
        out.append(")\" marker-end=\"url(#")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("-er-")
        out.append(cardinalityMarkerName(relationship.targetCardinality, false))
        out.append(")\"/>")
        if (!relationship.label.isEmpty()) {
            let labelX = (start.x + stop.x) / 2.0
            let labelY = (start.y + stop.y) / 2.0 - 6.0
            out.append("<text class=\"er-relationship-label\" x=\"")
            out.append(labelX)
            out.append("\" y=\"")
            out.append(labelY)
            out.append("\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, relationship.label)
            out.append("</text>")
        }
        out.append("</g>")
    }

    private func maxEntityWidth(diagram: ErDiagram, options: MermaidRenderOptions): Float64 {
        var width = 168.0
        for (entity in diagram.entities) {
            width = max(width, options.textMeasurer.measureText(entity.label) + 32.0)
            for (attr in entity.attributes) {
                let text = "${attr.attributeType} ${attr.name} ${attr.key}"
                width = max(width, options.textMeasurer.measureText(text) + 36.0)
            }
        }
        return width
    }

    private func entityHeight(entity: ErEntity): Float64 {
        return 42.0 + Float64(max(1, entity.attributes.size)) * 18.0
    }

    private func cardinalityMarkerName(cardinality: ErCardinality, start: Bool): String {
        let suffix = if (start) { "Start" } else { "End" }
        match (cardinality) {
            case ErCardinality.ZeroOrOne => return "zeroOrOne" + suffix
            case ErCardinality.ZeroOrMore => return "zeroOrMore" + suffix
            case ErCardinality.OneOrMore => return "oneOrMore" + suffix
            case _ => return "onlyOne" + suffix
        }
    }

    private func isHorizontal(direction: ErDirection): Bool {
        match (direction) {
            case ErDirection.LR | ErDirection.RL => return true
            case _ => return false
        }
    }

    private func anchor(from: ErBox, to: ErBox): ErPoint {
        let fromCx = from.x + from.width / 2.0
        let fromCy = from.y + from.height / 2.0
        let toCx = to.x + to.width / 2.0
        let toCy = to.y + to.height / 2.0
        let dx = toCx - fromCx
        let dy = toCy - fromCy
        if (absFloat(dx) > absFloat(dy)) {
            if (dx >= 0.0) {
                return ErPoint(from.x + from.width, fromCy)
            }
            return ErPoint(from.x, fromCy)
        }
        if (dy >= 0.0) {
            return ErPoint(fromCx, from.y + from.height)
        }
        return ErPoint(fromCx, from.y)
    }

    private func absFloat(value: Float64): Float64 {
        if (value < 0.0) {
            return -value
        }
        return value
    }
}

class ErBox {
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

class ErPoint {
    let x: Float64
    let y: Float64

    init(x: Float64, y: Float64) {
        this.x = x
        this.y = y
    }
}
