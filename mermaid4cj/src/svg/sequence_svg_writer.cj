package mermaid4cj.svg

import std.collection.HashMap
import mermaid4cj.core.{
    MermaidRenderOptions,
    SequenceControl,
    SequenceControlKind,
    SequenceDiagram,
    SequenceEventKind,
    SequenceMessage,
    SequenceMessageType,
    SequenceNote,
    SequenceNotePlacement,
    SequenceParticipantType
}

public class SequenceSvgWriter {
    public init() {}

    public func write(diagram: SequenceDiagram, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let actorCount = diagram.participants.size
        let actorWidth = 120.0
        let actorHeight = 44.0
        let actorGap = 72.0
        let marginX = 38.0
        let titleHeight = if (diagram.title.isSome()) { 34.0 } else { 0.0 }
        let headerY = 24.0 + titleHeight
        let eventTop = headerY + actorHeight + 34.0
        let eventGap = 52.0
        let eventCount = max(1, diagram.events.size)
        let width = marginX * 2.0 + Float64(max(1, actorCount)) * actorWidth + Float64(max(0, actorCount - 1)) * actorGap
        let footerY = eventTop + Float64(eventCount) * eventGap + 18.0
        let height = footerY + actorHeight + 24.0
        let positions = HashMap<String, Float64>()
        for (i in 0..diagram.participants.size) {
            positions[diagram.participants[i].id] = marginX + actorWidth / 2.0 + Float64(i) * (actorWidth + actorGap)
        }

        let out = StringBuilder(4096 + diagram.source.size)
        out.append("<svg id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-sequence mermaid4cj-sequence\" xmlns=\"http://www.w3.org/2000/svg\" width=\"")
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
            out.append("<text class=\"sequence-title\" x=\"")
            out.append(width / 2.0)
            out.append("\" y=\"24\" text-anchor=\"middle\">")
            SvgEscaper.appendText(out, title)
            out.append("</text>")
        }
        out.append("<g class=\"actors\">")
        for (i in 0..diagram.participants.size) {
            let participant = diagram.participants[i]
            let cx = positions.get(participant.id).getOrThrow()
            appendParticipant(out, options, participant.id, participant.description, participant.participantType, cx - actorWidth / 2.0, headerY, actorWidth, actorHeight)
            appendLifeLine(out, cx, headerY + actorHeight, footerY)
            appendParticipant(out, options, participant.id + "-bottom", participant.description, participant.participantType, cx - actorWidth / 2.0, footerY, actorWidth, actorHeight)
        }
        out.append("</g><g class=\"sequence-events\">")
        var sequenceNo = diagram.autonumberStart
        for (i in 0..diagram.events.size) {
            let event = diagram.events[i]
            let y = eventTop + Float64(i) * eventGap
            match (event.kind) {
                case SequenceEventKind.Message =>
                    let message = diagram.messages[event.messageIndex]
                    appendMessage(out, options, theme, message, positions, y, if (diagram.autonumber) { sequenceNo } else { -1 })
                    sequenceNo += diagram.autonumberStep
                    if (message.activateTarget) {
                        appendActivation(out, positions.get(message.target).getOrThrow(), y + 6.0, eventGap)
                    }
                    if (message.deactivateSource) {
                        appendDeactivation(out, positions.get(message.source).getOrThrow(), y + 6.0)
                    }
                case SequenceEventKind.Note =>
                    appendNote(out, theme, diagram.notes[event.noteIndex], positions, y)
                case SequenceEventKind.Activate =>
                    if (let Some(x) <- positions.get(event.actor)) {
                        appendActivation(out, x, y - 16.0, eventGap)
                    }
                case SequenceEventKind.Deactivate =>
                    if (let Some(x) <- positions.get(event.actor)) {
                        appendDeactivation(out, x, y)
                    }
                case SequenceEventKind.ControlStart =>
                    appendControlStart(out, theme, diagram.controls[event.controlIndex], marginX, y - 22.0, width - marginX * 2.0, eventGap)
                case SequenceEventKind.ControlDivider =>
                    appendControlDivider(out, theme, diagram.controls[event.controlIndex], marginX, y - 10.0, width - marginX * 2.0)
                case SequenceEventKind.ControlEnd =>
                    appendControlEnd(out, theme, diagram.controls[event.controlIndex], marginX, y - 12.0, width - marginX * 2.0)
            }
        }
        out.append("</g></svg>")
        return out.toString()
    }

    private func appendStyle(out: StringBuilder, idPrefix: String, theme: SvgTheme): Unit {
        out.append("<style>")
        appendSvgStyleScope(out, idPrefix)
        out.append("{background:")
        out.append(theme.background)
        out.append(";font-family:Arial,sans-serif;font-size:14px}")
        appendSvgStyleScopeSelector(out, idPrefix, "text")
        out.append("{fill:")
        out.append(theme.text)
        out.append("}")
        appendSvgStyleScopeSelector(out, idPrefix, ".actor-box")
        out.append("{fill:")
        out.append(theme.nodeFill)
        out.append(";stroke:")
        out.append(theme.nodeStroke)
        out.append(";stroke-width:1.5}")
        appendSvgStyleScopeSelector(out, idPrefix, ".actor-line")
        out.append("{stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1;stroke-dasharray:3 3}")
        appendSvgStyleScopeSelector(out, idPrefix, ".message-line")
        out.append("{stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1.6;fill:none}")
        appendSvgStyleScopeSelector(out, idPrefix, ".message-dotted")
        out.append("{stroke-dasharray:4 4}")
        appendSvgStyleScopeSelector(out, idPrefix, ".note")
        out.append("{fill:#fff5ad;stroke:#d6b656;stroke-width:1.2}")
        appendSvgStyleScopeSelector(out, idPrefix, ".activation")
        out.append("{fill:")
        out.append(theme.edgeLabelBackground)
        out.append(";stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1}")
        appendSvgStyleScopeSelector(out, idPrefix, ".sequence-control")
        out.append("{fill:")
        out.append(theme.edgeLabelBackground)
        out.append(";stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1;stroke-dasharray:5 3;opacity:.92}")
        appendSvgStyleScopeSelector(out, idPrefix, ".sequence-control-divider")
        out.append("{stroke:")
        out.append(theme.edge)
        out.append(";stroke-width:1;stroke-dasharray:4 4}</style>")
    }

    private func appendMarkers(out: StringBuilder, idPrefix: String, theme: SvgTheme): Unit {
        out.append("<defs><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-seq-arrow\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"8\" markerHeight=\"8\" orient=\"auto-start-reverse\"><path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"")
        SvgEscaper.appendAttribute(out, theme.edge)
        out.append("\"/></marker><marker id=\"")
        SvgEscaper.appendAttribute(out, idPrefix)
        out.append("-seq-cross\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"8\" markerHeight=\"8\" orient=\"auto\"><path d=\"M 1 1 L 9 9 M 9 1 L 1 9\" stroke=\"")
        SvgEscaper.appendAttribute(out, theme.edge)
        out.append("\" stroke-width=\"2\"/></marker></defs>")
    }

    private func appendParticipant(out: StringBuilder, options: MermaidRenderOptions, id: String, label: String, participantType: SequenceParticipantType, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let theme = SvgTheme.resolve(options.theme)
        out.append("<g class=\"actor actor-")
        out.append(participantTypeClass(participantType))
        out.append("\" id=\"")
        SvgEscaper.appendAttribute(out, options.idPrefix)
        out.append("-")
        SvgEscaper.appendAttribute(out, id)
        out.append("\"><rect class=\"actor-box\" x=\"")
        out.append(x)
        out.append("\" y=\"")
        out.append(y)
        out.append("\" width=\"")
        out.append(width)
        out.append("\" height=\"")
        out.append(height)
        out.append("\" rx=\"4\"/><text fill=\"")
        out.append(theme.text)
        out.append("\" x=\"")
        out.append(x + width / 2.0)
        out.append("\" y=\"")
        out.append(y + height / 2.0 + 5.0)
        out.append("\" text-anchor=\"middle\">")
        SvgEscaper.appendText(out, label)
        out.append("</text></g>")
    }

    private func participantTypeClass(participantType: SequenceParticipantType): String {
        match (participantType) {
            case SequenceParticipantType.Actor => return "person"
            case SequenceParticipantType.Boundary => return "boundary"
            case SequenceParticipantType.Control => return "control"
            case SequenceParticipantType.Entity => return "entity"
            case SequenceParticipantType.Database => return "database"
            case SequenceParticipantType.Collections => return "collections"
            case SequenceParticipantType.Queue => return "queue"
            case _ => return "participant"
        }
    }

    private func formatSequenceNumber(value: Int64): String {
        let whole = value / 100
        let frac = value % 100
        if (frac == 0) {
            return "${whole}"
        }
        if (frac % 10 == 0) {
            return "${whole}.${frac / 10}"
        }
        if (frac < 10) {
            return "${whole}.0${frac}"
        }
        return "${whole}.${frac}"
    }

    private func appendLifeLine(out: StringBuilder, x: Float64, y1: Float64, y2: Float64): Unit {
        out.append("<line class=\"actor-line\" x1=\"")
        out.append(x)
        out.append("\" y1=\"")
        out.append(y1)
        out.append("\" x2=\"")
        out.append(x)
        out.append("\" y2=\"")
        out.append(y2)
        out.append("\"/>")
    }

    private func appendMessage(out: StringBuilder, options: MermaidRenderOptions, theme: SvgTheme, message: SequenceMessage, positions: HashMap<String, Float64>, y: Float64, sequenceNo: Int64): Unit {
        let x1 = positions.get(message.source).getOrThrow()
        let x2 = positions.get(message.target).getOrThrow()
        let dotted = isDotted(message.messageType)
        out.append("<g class=\"message\"><path class=\"message-line")
        if (dotted) {
            out.append(" message-dotted")
        }
        out.append("\" d=\"M ")
        out.append(x1)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x2)
        out.append(" ")
        out.append(y)
        appendMessageMarker(out, options.idPrefix, message.messageType)
        out.append("/>")
        if (isBidirectional(message.messageType)) {
            out.append("<path class=\"message-line")
            if (dotted) {
                out.append(" message-dotted")
            }
            out.append("\" d=\"M ")
            out.append(x2)
            out.append(" ")
            out.append(y + 0.01)
            out.append(" L ")
            out.append(x1)
            out.append(" ")
            out.append(y + 0.01)
            out.append("\" marker-end=\"url(#")
            SvgEscaper.appendAttribute(out, options.idPrefix)
            out.append("-seq-arrow)\"/>")
        }
        out.append("<text class=\"messageText\" x=\"")
        out.append((x1 + x2) / 2.0)
        out.append("\" y=\"")
        out.append(y - 8.0)
        out.append("\" text-anchor=\"middle\">")
        if (sequenceNo >= 0) {
            out.append(formatSequenceNumber(sequenceNo))
            out.append(". ")
        }
        SvgEscaper.appendText(out, message.text)
        out.append("</text></g>")
    }

    private func appendMessageMarker(out: StringBuilder, idPrefix: String, messageType: SequenceMessageType): Unit {
        match (messageType) {
            case SequenceMessageType.SolidOpen | SequenceMessageType.DottedOpen =>
                out.append("\"")
            case SequenceMessageType.SolidCross | SequenceMessageType.DottedCross =>
                out.append("\" marker-end=\"url(#")
                SvgEscaper.appendAttribute(out, idPrefix)
                out.append("-seq-cross)\"")
            case _ =>
                out.append("\" marker-end=\"url(#")
                SvgEscaper.appendAttribute(out, idPrefix)
                out.append("-seq-arrow)\"")
        }
    }

    private func appendNote(out: StringBuilder, theme: SvgTheme, note: SequenceNote, positions: HashMap<String, Float64>, y: Float64): Unit {
        let noteWidth = max(120.0, Float64(note.text.size) * 8.0 + 24.0)
        let noteHeight = 38.0
        var cx = 0.0
        if (note.actors.size == 0) {
            return
        }
        let firstX = positions.get(note.actors[0]).getOrThrow()
        match (note.placement) {
            case SequenceNotePlacement.LeftOf => cx = firstX - noteWidth / 2.0 - 16.0
            case SequenceNotePlacement.RightOf => cx = firstX + noteWidth / 2.0 + 16.0
            case SequenceNotePlacement.Over =>
                if (note.actors.size > 1) {
                    let lastX = positions.get(note.actors[note.actors.size - 1]).getOrThrow()
                    cx = (firstX + lastX) / 2.0
                } else {
                    cx = firstX
                }
        }
        out.append("<g class=\"note\"><rect class=\"note\" x=\"")
        out.append(cx - noteWidth / 2.0)
        out.append("\" y=\"")
        out.append(y - noteHeight / 2.0)
        out.append("\" width=\"")
        out.append(noteWidth)
        out.append("\" height=\"")
        out.append(noteHeight)
        out.append("\"/><text x=\"")
        out.append(cx)
        out.append("\" y=\"")
        out.append(y + 5.0)
        out.append("\" text-anchor=\"middle\">")
        SvgEscaper.appendText(out, note.text)
        out.append("</text></g>")
    }

    private func appendActivation(out: StringBuilder, x: Float64, y: Float64, height: Float64): Unit {
        out.append("<rect class=\"activation\" x=\"")
        out.append(x - 5.0)
        out.append("\" y=\"")
        out.append(y)
        out.append("\" width=\"10\" height=\"")
        out.append(height)
        out.append("\"/>")
    }

    private func appendDeactivation(out: StringBuilder, x: Float64, y: Float64): Unit {
        out.append("<path class=\"activation-end\" d=\"M ")
        out.append(x - 7.0)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + 7.0)
        out.append(" ")
        out.append(y)
        out.append("\"/>")
    }

    private func appendControlStart(out: StringBuilder, theme: SvgTheme, control: SequenceControl, x: Float64, y: Float64, width: Float64, height: Float64): Unit {
        let inset = Float64(control.depth) * 12.0
        out.append("<g class=\"sequence-control-group\"><rect class=\"sequence-control\" x=\"")
        out.append(x + inset)
        out.append("\" y=\"")
        out.append(y)
        out.append("\" width=\"")
        out.append(max(20.0, width - inset * 2.0))
        out.append("\" height=\"")
        out.append(height)
        out.append("\" rx=\"3\"/><text class=\"sequence-control-label\" x=\"")
        out.append(x + inset + 8.0)
        out.append("\" y=\"")
        out.append(y + 16.0)
        out.append("\">")
        SvgEscaper.appendText(out, controlLabel(control))
        out.append("</text></g>")
    }

    private func appendControlDivider(out: StringBuilder, theme: SvgTheme, control: SequenceControl, x: Float64, y: Float64, width: Float64): Unit {
        let inset = Float64(control.depth) * 12.0
        out.append("<g class=\"sequence-control-divider-group\"><path class=\"sequence-control-divider\" d=\"M ")
        out.append(x + inset)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + width - inset)
        out.append(" ")
        out.append(y)
        out.append("\"/><text class=\"sequence-control-label\" x=\"")
        out.append(x + inset + 8.0)
        out.append("\" y=\"")
        out.append(y - 4.0)
        out.append("\">")
        SvgEscaper.appendText(out, controlLabel(control))
        out.append("</text></g>")
    }

    private func appendControlEnd(out: StringBuilder, theme: SvgTheme, control: SequenceControl, x: Float64, y: Float64, width: Float64): Unit {
        let inset = Float64(control.depth) * 12.0
        out.append("<path class=\"sequence-control-divider\" d=\"M ")
        out.append(x + inset)
        out.append(" ")
        out.append(y)
        out.append(" L ")
        out.append(x + width - inset)
        out.append(" ")
        out.append(y)
        out.append("\"/>")
    }

    private func controlLabel(control: SequenceControl): String {
        let prefix = match (control.kind) {
            case SequenceControlKind.Alt => "alt"
            case SequenceControlKind.Opt => "opt"
            case SequenceControlKind.Loop => "loop"
            case SequenceControlKind.Par => "par"
            case SequenceControlKind.Critical => "critical"
            case SequenceControlKind.Break => "break"
            case SequenceControlKind.Rect => "rect"
            case SequenceControlKind.And => "and"
            case SequenceControlKind.Else => "else"
            case _ => "end"
        }
        if (control.text.isEmpty()) {
            return prefix
        }
        return "${prefix} ${control.text}"
    }

    private func isDotted(messageType: SequenceMessageType): Bool {
        match (messageType) {
            case SequenceMessageType.Dotted | SequenceMessageType.DottedOpen | SequenceMessageType.DottedCross | SequenceMessageType.DottedPoint | SequenceMessageType.BidirectionalDotted => return true
            case _ => return false
        }
    }

    private func isBidirectional(messageType: SequenceMessageType): Bool {
        match (messageType) {
            case SequenceMessageType.BidirectionalSolid | SequenceMessageType.BidirectionalDotted => return true
            case _ => return false
        }
    }
}
