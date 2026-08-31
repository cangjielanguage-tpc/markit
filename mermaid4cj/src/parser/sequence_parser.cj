package mermaid4cj.parser

import std.collection.{ArrayList, HashMap}
import mermaid4cj.core.{
    SequenceDiagram,
    SequenceControl,
    SequenceControlKind,
    SequenceEvent,
    SequenceEventKind,
    SequenceMessage,
    SequenceMessageType,
    SequenceNote,
    SequenceNotePlacement,
    SequenceParseResult,
    SequenceParticipant,
    SequenceParticipantType
}

public class SequenceParser {
    public init() {}

    public func parse(source: String): SequenceParseResult {
        let participants = ArrayList<SequenceParticipant>()
        let participantIndex = HashMap<String, Int64>()
        let messages = ArrayList<SequenceMessage>()
        let notes = ArrayList<SequenceNote>()
        let controls = ArrayList<SequenceControl>()
        let events = ArrayList<SequenceEvent>()
        let diagnostics = ArrayList<String>()
        var sawHeader = false
        var title: ?String = None
        var autonumber = false
        var autonumberStart: Int64 = 100
        var autonumberStep: Int64 = 100
        var controlDepth: Int64 = 0
        var lineNo: Int64 = 0
        let activationCounts = HashMap<String, Int64>()

        for (rawLine in source.lines()) {
            lineNo++
            let line = stripComment(rawLine).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            if (!sawHeader) {
                if (line.toAsciiLower().startsWith("sequencediagram")) {
                    sawHeader = true
                    continue
                }
                diagnostics.add("Line ${lineNo}: expected sequenceDiagram header")
                break
            }

            let lower = line.toAsciiLower()
            if (lower == "autonumber" || lower.startsWith("autonumber ")) {
                if (lower == "autonumber off") {
                    autonumber = false
                } else {
                    autonumber = true
                }
                if (lower.startsWith("autonumber ") && lower != "autonumber off") {
                    let values = line["autonumber ".size..line.size].trimAscii().split(" ", removeEmpty: true)
                    if (values.size > 0) {
                        if (let Some(parsed) <- parseAutonumberValue(values[0])) {
                            autonumberStart = parsed
                        } else {
                            diagnostics.add("Line ${lineNo}: invalid sequence autonumber value")
                        }
                    }
                    if (values.size > 1) {
                        if (let Some(parsed) <- parseAutonumberValue(values[1])) {
                            autonumberStep = parsed
                        } else {
                            diagnostics.add("Line ${lineNo}: invalid sequence autonumber increment")
                        }
                    }
                }
            } else if (lower.startsWith("title:")) {
                title = Some(line["title:".size..line.size].trimAscii())
            } else if (lower.startsWith("title ")) {
                title = Some(line["title ".size..line.size].trimAscii())
            } else if (lower.startsWith("participant ")) {
                parseParticipant(line["participant ".size..line.size], SequenceParticipantType.Participant, participants, participantIndex, diagnostics, lineNo)
            } else if (lower.startsWith("actor ")) {
                parseParticipant(line["actor ".size..line.size], SequenceParticipantType.Actor, participants, participantIndex, diagnostics, lineNo)
            } else if (lower.startsWith("note ")) {
                if (let Some(note) <- parseNote(line)) {
                    ensureNoteParticipants(note, participants, participantIndex)
                    notes.add(note)
                    events.add(SequenceEvent(SequenceEventKind.Note, noteIndex: notes.size - 1))
                }
            } else if (lower.startsWith("activate ")) {
                let id = line["activate ".size..line.size].trimAscii()
                ensureParticipant(id, id, SequenceParticipantType.Participant, participants, participantIndex)
                incrementActivation(activationCounts, id)
                events.add(SequenceEvent(SequenceEventKind.Activate, actor: id))
            } else if (lower.startsWith("deactivate ")) {
                let id = line["deactivate ".size..line.size].trimAscii()
                ensureParticipant(id, id, SequenceParticipantType.Participant, participants, participantIndex)
                if (decrementActivation(activationCounts, id)) {
                    events.add(SequenceEvent(SequenceEventKind.Deactivate, actor: id))
                } else {
                    diagnostics.add("Line ${lineNo}: trying to inactivate an inactive participant (${id})")
                }
            } else if (isControlStart(lower)) {
                let control = parseControlStart(line, lower, controlDepth)
                controls.add(control)
                events.add(SequenceEvent(SequenceEventKind.ControlStart, controlIndex: controls.size - 1))
                controlDepth++
            } else if (lower.startsWith("else") || lower.startsWith("and ")) {
                let control = parseControlDivider(line, lower, max(0, controlDepth - 1))
                controls.add(control)
                events.add(SequenceEvent(SequenceEventKind.ControlDivider, controlIndex: controls.size - 1))
            } else if (line == "end") {
                controlDepth = max(0, controlDepth - 1)
                controls.add(SequenceControl(SequenceControlKind.End, depth: controlDepth))
                events.add(SequenceEvent(SequenceEventKind.ControlEnd, controlIndex: controls.size - 1))
            } else if (let Some(message) <- parseMessage(line)) {
                ensureParticipant(message.source, message.source, SequenceParticipantType.Participant, participants, participantIndex)
                ensureParticipant(message.target, message.target, SequenceParticipantType.Participant, participants, participantIndex)
                messages.add(message)
                events.add(SequenceEvent(SequenceEventKind.Message, messageIndex: messages.size - 1))
                if (message.activateTarget) {
                    incrementActivation(activationCounts, message.target)
                }
                if (message.deactivateSource && !decrementActivation(activationCounts, message.source)) {
                    diagnostics.add("Line ${lineNo}: trying to inactivate an inactive participant (${message.source})")
                }
            }
        }

        if (!sawHeader && diagnostics.isEmpty()) {
            diagnostics.add("Missing sequenceDiagram header")
        }

        return SequenceParseResult(
            SequenceDiagram(
                source,
                title: title,
                autonumber: autonumber,
                autonumberStart: autonumberStart,
                autonumberStep: autonumberStep,
                participants: participants,
                messages: messages,
                notes: notes,
                controls: controls,
                events: events
            ),
            diagnostics: diagnostics.toArray()
        )
    }

    private func parseParticipant(body: String, participantType: SequenceParticipantType, participants: ArrayList<SequenceParticipant>, participantIndex: HashMap<String, Int64>, diagnostics: ArrayList<String>, lineNo: Int64): Unit {
        if (let Some(spec) <- parseParticipantSpec(body, participantType, diagnostics, lineNo)) {
            ensureParticipant(spec.id, spec.description, spec.participantType, participants, participantIndex)
        }
    }

    private func parseParticipantSpec(body: String, defaultType: SequenceParticipantType, diagnostics: ArrayList<String>, lineNo: Int64): ?ParticipantSpec {
        let trimmed = body.trimAscii()
        var base = trimmed
        var externalAlias = ""
        let lower = trimmed.toAsciiLower()
        if (let Some(pos) <- lower.indexOf(" as ")) {
            base = trimmed[0..pos].trimAscii()
            externalAlias = unquote(trimmed[(pos + 4)..trimmed.size].trimAscii())
        }

        var configType = defaultType
        var inlineAlias = ""
        var idText = base
        if (let Some(configStart) <- base.indexOf("@{")) {
            idText = base[0..configStart].trimAscii()
            if (let Some(configEndRel) <- base[(configStart + 2)..base.size].indexOf("}")) {
                let configEnd = configStart + 2 + configEndRel
                let config = base[(configStart + 2)..configEnd]
                configType = parseParticipantTypeConfig(config, defaultType)
                inlineAlias = parseStringConfigValue(config, "alias")
            } else {
                diagnostics.add("Line ${lineNo}: malformed sequence participant config")
                return None
            }
        }
        let id = unquote(idText.trimAscii())
        if (id.isEmpty()) {
            diagnostics.add("Line ${lineNo}: sequence participant id is empty")
            return None
        }
        let description = if (!externalAlias.isEmpty()) { externalAlias } else if (!inlineAlias.isEmpty()) { inlineAlias } else { id }
        return Some(ParticipantSpec(id, description, configType))
    }

    private func parseAutonumberValue(text: String): ?Int64 {
        let trimmed = text.trimAscii()
        if (trimmed.isEmpty()) {
            return None
        }
        var whole: Int64 = 0
        var frac: Int64 = 0
        var fracDigits: Int64 = 0
        var seenDot = false
        for (i in 0..trimmed.size) {
            let ch = trimmed[i]
            if (ch == b'.') {
                if (seenDot) {
                    return None
                }
                seenDot = true
            } else if (ch >= b'0' && ch <= b'9') {
                let digit = Int64(ch - b'0')
                if (seenDot) {
                    fracDigits++
                    if (fracDigits > 2) {
                        return None
                    }
                    frac = frac * 10 + digit
                } else {
                    whole = whole * 10 + digit
                }
            } else {
                return None
            }
        }
        if (fracDigits == 0) {
            frac = 0
        } else if (fracDigits == 1) {
            frac *= 10
        }
        return Some(whole * 100 + frac)
    }

    private func parseNote(line: String): ?SequenceNote {
        let colon = line.indexOf(":")
        if (colon.isNone()) {
            return None
        }
        let head = line[0..colon.getOrThrow()].trimAscii()
        let text = line[(colon.getOrThrow() + 1)..line.size].trimAscii()
        let lower = head.toAsciiLower()
        if (lower.startsWith("note right of ")) {
            return Some(SequenceNote(SequenceNotePlacement.RightOf, splitActors(head["note right of ".size..head.size]), text))
        }
        if (lower.startsWith("note left of ")) {
            return Some(SequenceNote(SequenceNotePlacement.LeftOf, splitActors(head["note left of ".size..head.size]), text))
        }
        if (lower.startsWith("note over ")) {
            return Some(SequenceNote(SequenceNotePlacement.Over, splitActors(head["note over ".size..head.size]), text))
        }
        return None
    }

    private func parseMessage(line: String): ?SequenceMessage {
        let colon = line.indexOf(":")
        if (colon.isNone()) {
            return None
        }
        let head = line[0..colon.getOrThrow()].trimAscii()
        let text = line[(colon.getOrThrow() + 1)..line.size].trimAscii()
        let tokens = [
            "<<-->>", "<<->>", "-->>", "->>", "--x", "->x", "--)", "-)", "-->", "->"
        ]
        for (token in tokens) {
            if (let Some(pos) <- head.indexOf(token)) {
                let source = head[0..pos].trimAscii()
                var target = head[(pos + token.size)..head.size].trimAscii()
                var activateTarget = false
                var deactivateSource = false
                if (target.endsWith("+")) {
                    target = target[0..(target.size - 1)].trimAscii()
                    activateTarget = true
                } else if (target.endsWith("-")) {
                    target = target[0..(target.size - 1)].trimAscii()
                    deactivateSource = true
                }
                if (source.isEmpty() || target.isEmpty()) {
                    return None
                }
                return Some(SequenceMessage(
                    unquote(source),
                    unquote(target),
                    text,
                    messageType: messageTypeFor(token),
                    activateTarget: activateTarget,
                    deactivateSource: deactivateSource
                ))
            }
        }
        return None
    }

    private func isControlStart(lower: String): Bool {
        return lower.startsWith("alt ") || lower.startsWith("opt ") || lower.startsWith("loop ") ||
            lower.startsWith("par ") || lower.startsWith("critical ") || lower.startsWith("break ") ||
            lower.startsWith("rect ")
    }

    private func parseControlStart(line: String, lower: String, depth: Int64): SequenceControl {
        if (lower.startsWith("alt ")) {
            return SequenceControl(SequenceControlKind.Alt, text: line["alt ".size..line.size].trimAscii(), depth: depth)
        }
        if (lower.startsWith("opt ")) {
            return SequenceControl(SequenceControlKind.Opt, text: line["opt ".size..line.size].trimAscii(), depth: depth)
        }
        if (lower.startsWith("loop ")) {
            return SequenceControl(SequenceControlKind.Loop, text: line["loop ".size..line.size].trimAscii(), depth: depth)
        }
        if (lower.startsWith("par ")) {
            return SequenceControl(SequenceControlKind.Par, text: line["par ".size..line.size].trimAscii(), depth: depth)
        }
        if (lower.startsWith("critical ")) {
            return SequenceControl(SequenceControlKind.Critical, text: line["critical ".size..line.size].trimAscii(), depth: depth)
        }
        if (lower.startsWith("break ")) {
            return SequenceControl(SequenceControlKind.Break, text: line["break ".size..line.size].trimAscii(), depth: depth)
        }
        return SequenceControl(SequenceControlKind.Rect, text: line["rect ".size..line.size].trimAscii(), depth: depth)
    }

    private func parseControlDivider(line: String, lower: String, depth: Int64): SequenceControl {
        if (lower.startsWith("and ")) {
            return SequenceControl(SequenceControlKind.And, text: line["and ".size..line.size].trimAscii(), depth: depth)
        }
        if (lower == "else") {
            return SequenceControl(SequenceControlKind.Else, depth: depth)
        }
        return SequenceControl(SequenceControlKind.Else, text: line["else".size..line.size].trimAscii(), depth: depth)
    }

    private func messageTypeFor(token: String): SequenceMessageType {
        match (token) {
            case "-->>" => return SequenceMessageType.Dotted
            case "->>" => return SequenceMessageType.Solid
            case "-->" => return SequenceMessageType.DottedOpen
            case "->" => return SequenceMessageType.SolidOpen
            case "--x" => return SequenceMessageType.DottedCross
            case "->x" => return SequenceMessageType.SolidCross
            case "--)" => return SequenceMessageType.DottedPoint
            case "-)" => return SequenceMessageType.SolidPoint
            case "<<-->>" => return SequenceMessageType.BidirectionalDotted
            case "<<->>" => return SequenceMessageType.BidirectionalSolid
            case _ => return SequenceMessageType.Solid
        }
    }

    private func ensureNoteParticipants(note: SequenceNote, participants: ArrayList<SequenceParticipant>, participantIndex: HashMap<String, Int64>): Unit {
        for (actor in note.actors) {
            ensureParticipant(actor, actor, SequenceParticipantType.Participant, participants, participantIndex)
        }
    }

    private func ensureParticipant(id: String, description: String, participantType: SequenceParticipantType, participants: ArrayList<SequenceParticipant>, participantIndex: HashMap<String, Int64>): Unit {
        if (id.isEmpty()) {
            return
        }
        if (let Some(index) <- participantIndex.get(id)) {
            let current = participants[index]
            if ((current.description == current.id && description != id) || isSpecificParticipantType(participantType)) {
                participants[index] = SequenceParticipant(id, description, participantType: participantType)
            }
            return
        }
        participantIndex[id] = participants.size
        participants.add(SequenceParticipant(id, description, participantType: participantType))
    }

    private func incrementActivation(counts: HashMap<String, Int64>, actor: String): Unit {
        let current = match (counts.get(actor)) {
            case Some(value) => value
            case None => 0
        }
        counts[actor] = current + 1
    }

    private func decrementActivation(counts: HashMap<String, Int64>, actor: String): Bool {
        let current = match (counts.get(actor)) {
            case Some(value) => value
            case None => 0
        }
        if (current < 1) {
            return false
        }
        counts[actor] = current - 1
        return true
    }

    private func splitActors(text: String): Array<String> {
        let out = ArrayList<String>()
        for (part in text.split(",", removeEmpty: true)) {
            let actor = unquote(part.trimAscii())
            if (!actor.isEmpty()) {
                out.add(actor)
            }
        }
        return out.toArray()
    }

    private func stripComment(line: String): String {
        if (let Some(pos) <- line.indexOf("%%")) {
            return line[0..pos]
        }
        return line
    }

    private func unquote(text: String): String {
        if (text.size >= 2 && ((text[0] == b'"' && text[text.size - 1] == b'"') || (text[0] == b'\'' && text[text.size - 1] == b'\''))) {
            return text[1..(text.size - 1)]
        }
        return text
    }

    private func indexOfAsciiWord(text: String, needle: String): ?Int64 {
        return text.indexOf(needle)
    }

    private func parseParticipantTypeConfig(config: String, fallback: SequenceParticipantType): SequenceParticipantType {
        let value = parseStringConfigValue(config, "type").toAsciiLower()
        match (value) {
            case "actor" => return SequenceParticipantType.Actor
            case "boundary" => return SequenceParticipantType.Boundary
            case "control" => return SequenceParticipantType.Control
            case "entity" => return SequenceParticipantType.Entity
            case "database" => return SequenceParticipantType.Database
            case "collections" => return SequenceParticipantType.Collections
            case "queue" => return SequenceParticipantType.Queue
            case _ => return fallback
        }
    }

    private func parseStringConfigValue(config: String, key: String): String {
        let lower = config.toAsciiLower()
        let quotedKey = "\"${key}\""
        var searchStart: Int64 = 0
        var keyPos = lower.indexOf(quotedKey)
        if (keyPos.isNone()) {
            keyPos = lower.indexOf(key)
        }
        if (keyPos.isNone()) {
            return ""
        }
        searchStart = keyPos.getOrThrow() + key.size
        if (let Some(colonRel) <- config[searchStart..config.size].indexOf(":")) {
            let valueStart = searchStart + colonRel + 1
            return readConfigStringValue(config[valueStart..config.size])
        }
        return ""
    }

    private func readConfigStringValue(text: String): String {
        let trimmed = text.trimAscii()
        if (trimmed.isEmpty()) {
            return ""
        }
        let quoteChar = trimmed[0]
        if (quoteChar == b'"' || quoteChar == b'\'') {
            var i: Int64 = 1
            while (i < trimmed.size) {
                if (trimmed[i] == quoteChar) {
                    return trimmed[1..i]
                }
                i++
            }
            return ""
        }
        if (let Some(comma) <- trimmed.indexOf(",")) {
            return trimmed[0..comma].trimAscii()
        }
        return trimmed.trimAscii()
    }

    private func isSpecificParticipantType(participantType: SequenceParticipantType): Bool {
        match (participantType) {
            case SequenceParticipantType.Participant => return false
            case _ => return true
        }
    }
}

class ParticipantSpec {
    let id: String
    let description: String
    let participantType: SequenceParticipantType

    init(id: String, description: String, participantType: SequenceParticipantType) {
        this.id = id
        this.description = description
        this.participantType = participantType
    }
}
