package mermaid4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.MermaidRenderer
import mermaid4cj.core.{DiagramKind, SequenceControlKind, SequenceEventKind, SequenceMessageType, SequenceNotePlacement, SequenceParticipantType}
import mermaid4cj.parser.SequenceParser

@Test
@Tag[Mermaid4cj]
class MermaidSequenceTests {
    @TestCase
    func migratesUpstreamBasicSequenceDefinitionAndNotes() {
        let parsed = SequenceParser().parse("""
sequenceDiagram
Alice->Bob:Hello Bob, how are you?
Note right of Bob: Bob thinks
Bob-->Alice: I am good thanks!
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.participants.size, 2)
        @Expect(parsed.diagram.participants[0].id, "Alice")
        @Expect(parsed.diagram.participants[1].id, "Bob")
        @Expect(parsed.diagram.messages.size, 2)
        @Expect(parsed.diagram.messages[0].source, "Alice")
        @Expect(parsed.diagram.messages[0].target, "Bob")
        @Expect(messageTypeName(parsed.diagram.messages[0].messageType), "solid-open")
        @Expect(parsed.diagram.notes.size, 1)
        @Expect(notePlacementName(parsed.diagram.notes[0].placement), "right-of")
        @Expect(parsed.diagram.notes[0].actors[0], "Bob")
        @Expect(parsed.diagram.notes[0].text, "Bob thinks")
    }

    @TestCase
    func migratesUpstreamTitleAutonumberAndParticipantAliases() {
        let parsed = SequenceParser().parse("""
sequenceDiagram
title: Diagram Title
autonumber
participant A as Alice
actor B as Bob
A->>B:Hello Bob
B-->>A:Hello Alice
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.title.getOrThrow(), "Diagram Title")
        @Expect(parsed.diagram.autonumber, true)
        @Expect(parsed.diagram.participants.size, 2)
        @Expect(parsed.diagram.participants[0].id, "A")
        @Expect(parsed.diagram.participants[0].description, "Alice")
        @Expect(participantTypeName(parsed.diagram.participants[0].participantType), "participant")
        @Expect(parsed.diagram.participants[1].id, "B")
        @Expect(parsed.diagram.participants[1].description, "Bob")
        @Expect(participantTypeName(parsed.diagram.participants[1].participantType), "actor")
        @Expect(messageTypeName(parsed.diagram.messages[0].messageType), "solid")
        @Expect(messageTypeName(parsed.diagram.messages[1].messageType), "dotted")
    }

    @TestCase
    func migratesUpstreamSequenceMessageArrowTypes() {
        expectMessageType("sequenceDiagram\nAlice->xBob:Hello", "solid-cross")
        expectMessageType("sequenceDiagram\nAlice--xBob:Hello", "dotted-cross")
        expectMessageType("sequenceDiagram\nAlice-)Bob:Hello", "solid-point")
        expectMessageType("sequenceDiagram\nAlice--)Bob:Hello", "dotted-point")
        expectMessageType("sequenceDiagram\nAlice->>Bob:Hello", "solid")
        expectMessageType("sequenceDiagram\nAlice-->>Bob:Hello", "dotted")
        expectMessageType("sequenceDiagram\nAlice<<->>Bob:Hello", "bidirectional-solid")
        expectMessageType("sequenceDiagram\nAlice<<-->>Bob:Hello", "bidirectional-dotted")
    }

    @TestCase
    func migratesUpstreamActivationAndComments() {
        let parsed = SequenceParser().parse("""
sequenceDiagram
%% comment should be ignored
Alice-->>Bob+: Hello Bob
activate Bob
Bob-->>Alice-: Hello Alice
deactivate Bob
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.messages.size, 2)
        @Expect(parsed.diagram.messages[0].activateTarget, true)
        @Expect(parsed.diagram.messages[1].deactivateSource, true)
        @Expect(parsed.diagram.events.size, 4)
    }

    @TestCase
    func migratesCommonSequenceControlBlocks() {
        let parsed = SequenceParser().parse("""
sequenceDiagram
participant A as Alice
participant B as Bob
alt success
A->>B: request
else failure
B-->>A: error
end
loop retry
A->>B: again
end
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.controls.size, 5)
        @Expect(controlKindName(parsed.diagram.controls[0].kind), "alt")
        @Expect(parsed.diagram.controls[0].text, "success")
        @Expect(controlKindName(parsed.diagram.controls[1].kind), "else")
        @Expect(parsed.diagram.controls[1].text, "failure")
        @Expect(controlKindName(parsed.diagram.controls[3].kind), "loop")
        @Expect(eventKindName(parsed.diagram.events[0].kind), "control-start")
        @Expect(eventKindName(parsed.diagram.events[2].kind), "control-divider")
        @Expect(eventKindName(parsed.diagram.events[4].kind), "control-end")

        let rendered = MermaidRenderer().renderSvg(parsed.diagram.source)
        @Expect(rendered.supported, true)
        @Expect(rendered.svg.contains("sequence-control"), true)
        @Expect(rendered.svg.contains("alt success"), true)
        @Expect(rendered.svg.contains("else failure"), true)
        @Expect(rendered.svg.contains("loop retry"), true)
    }

    @TestCase
    func migratesUpstreamExtendedParticipantTypesAndAliases() {
        let parsed = SequenceParser().parse("""
sequenceDiagram
participant API@{ "type" : "boundary", "alias": "Internal API" } as Public API
participant Auth@{ type: "control", alias: "Auth Controller" }
participant DB@{ "type" : 'database' }
participant Jobs@{ "type" : "queue" }
actor User@{ "type" : "actor", "alias": "End User" }
API->>Auth: Request
Auth->>DB: Query
Jobs-->>Auth: Done
User->>API: Visit
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.participants.size, 5)
        @Expect(parsed.diagram.participants[0].id, "API")
        @Expect(parsed.diagram.participants[0].description, "Public API")
        @Expect(participantTypeName(parsed.diagram.participants[0].participantType), "boundary")
        @Expect(parsed.diagram.participants[1].description, "Auth Controller")
        @Expect(participantTypeName(parsed.diagram.participants[1].participantType), "control")
        @Expect(participantTypeName(parsed.diagram.participants[2].participantType), "database")
        @Expect(participantTypeName(parsed.diagram.participants[3].participantType), "queue")
        @Expect(parsed.diagram.participants[4].description, "End User")
        @Expect(participantTypeName(parsed.diagram.participants[4].participantType), "actor")

        let rendered = MermaidRenderer().renderSvg(parsed.diagram.source)
        @Expect(rendered.supported, true)
        @Expect(rendered.svg.contains("actor-boundary"), true)
        @Expect(rendered.svg.contains("actor-control"), true)
        @Expect(rendered.svg.contains("actor-database"), true)
        @Expect(rendered.svg.contains("actor-queue"), true)
        @Expect(rendered.svg.contains("Public API"), true)
    }

    @TestCase
    func migratesUpstreamDecimalAutonumberStartAndIncrement() {
        let parsed = SequenceParser().parse("""
sequenceDiagram
autonumber 10.1 .01
Alice->>Bob: Hello Bob
Bob-->>Alice: Hi Alice
Alice->>Bob: Bye
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.autonumber, true)
        @Expect(parsed.diagram.autonumberStart, 1010)
        @Expect(parsed.diagram.autonumberStep, 1)

        let rendered = MermaidRenderer().renderSvg(parsed.diagram.source)
        @Expect(rendered.supported, true)
        @Expect(rendered.svg.contains("10.1. Hello Bob"), true)
        @Expect(rendered.svg.contains("10.11. Hi Alice"), true)
        @Expect(rendered.svg.contains("10.12. Bye"), true)
    }

    @TestCase
    func rejectsAutonumberDecimalsBeyondHundredthsLikeUpstream() {
        let result = MermaidRenderer().renderSvg("""
sequenceDiagram
autonumber 10.001
Alice->>Bob: Hello
""")
        @Expect(result.supported, false)
        @Expect(result.diagnostics[0].contains("invalid sequence autonumber value"), true)
    }

    @TestCase
    func migratesUpstreamAutonumberOffAndInactiveDeactivateErrors() {
        let off = SequenceParser().parse("""
sequenceDiagram
autonumber
autonumber off
A->>B: hello
""")
        @Expect(off.diagnostics.isEmpty(), true)
        @Expect(off.diagram.autonumber, false)

        let explicitInactive = MermaidRenderer().renderSvg("""
sequenceDiagram
deactivate A
""")
        @Expect(explicitInactive.supported, false)
        @Expect(explicitInactive.diagnostics[0].contains("inactive participant"), true)

        let arrowInactive = MermaidRenderer().renderSvg("""
sequenceDiagram
A->>B-: done
""")
        @Expect(arrowInactive.supported, false)
        @Expect(arrowInactive.diagnostics[0].contains("inactive participant"), true)
    }

    @TestCase
    func reportsMalformedSequenceParticipantConfig() {
        let result = MermaidRenderer().renderSvg("""
sequenceDiagram
participant D@{ "type": "entity"
D->>D: process
""")
        @Expect(result.supported, false)
        @Expect(result.diagnostics[0].contains("malformed sequence participant config"), true)
        @Expect(result.svg.contains("Mermaid parse error"), true)
    }

    @TestCase
    func detectorRecognizesPrioritizedNonFlowchartKinds() {
        let renderer = MermaidRenderer()
        @Expect(diagramKindName(renderer.detectDiagramKind("sequenceDiagram\nA->>B: hi")), "sequence")
        @Expect(diagramKindName(renderer.detectDiagramKind("mindmap\n  root")), "mindmap")
        @Expect(diagramKindName(renderer.detectDiagramKind("classDiagram\nA <|-- B")), "class")
        @Expect(diagramKindName(renderer.detectDiagramKind("erDiagram\nA ||--|| B : has")), "er")
        @Expect(diagramKindName(renderer.detectDiagramKind("pie title Pets\n\"Cats\" : 10")), "pie")
        @Expect(diagramKindName(renderer.detectDiagramKind("gantt\ntitle Plan")), "gantt")
        @Expect(renderer.supportsDiagramKind(DiagramKind.Sequence), true)
        @Expect(renderer.supportsDiagramKind(DiagramKind.Mindmap), true)
        @Expect(renderer.supportsDiagramKind(DiagramKind.Class), true)
        @Expect(renderer.supportsDiagramKind(DiagramKind.Er), true)
        @Expect(renderer.supportsDiagramKind(DiagramKind.Pie), true)
        @Expect(renderer.supportsDiagramKind(DiagramKind.Gantt), true)
    }

    private func expectMessageType(source: String, expected: String): Unit {
        let parsed = SequenceParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.messages.size, 1)
        @Expect(messageTypeName(parsed.diagram.messages[0].messageType), expected)
    }

    private func participantTypeName(value: SequenceParticipantType): String {
        match (value) {
            case SequenceParticipantType.Actor => return "actor"
            case SequenceParticipantType.Boundary => return "boundary"
            case SequenceParticipantType.Control => return "control"
            case SequenceParticipantType.Entity => return "entity"
            case SequenceParticipantType.Database => return "database"
            case SequenceParticipantType.Collections => return "collections"
            case SequenceParticipantType.Queue => return "queue"
            case _ => return "participant"
        }
    }

    private func notePlacementName(value: SequenceNotePlacement): String {
        match (value) {
            case SequenceNotePlacement.LeftOf => return "left-of"
            case SequenceNotePlacement.RightOf => return "right-of"
            case _ => return "over"
        }
    }

    private func messageTypeName(value: SequenceMessageType): String {
        match (value) {
            case SequenceMessageType.Solid => return "solid"
            case SequenceMessageType.Dotted => return "dotted"
            case SequenceMessageType.SolidOpen => return "solid-open"
            case SequenceMessageType.DottedOpen => return "dotted-open"
            case SequenceMessageType.SolidCross => return "solid-cross"
            case SequenceMessageType.DottedCross => return "dotted-cross"
            case SequenceMessageType.SolidPoint => return "solid-point"
            case SequenceMessageType.DottedPoint => return "dotted-point"
            case SequenceMessageType.BidirectionalSolid => return "bidirectional-solid"
            case SequenceMessageType.BidirectionalDotted => return "bidirectional-dotted"
        }
    }

    private func controlKindName(value: SequenceControlKind): String {
        match (value) {
            case SequenceControlKind.Alt => return "alt"
            case SequenceControlKind.Opt => return "opt"
            case SequenceControlKind.Loop => return "loop"
            case SequenceControlKind.Par => return "par"
            case SequenceControlKind.Critical => return "critical"
            case SequenceControlKind.Break => return "break"
            case SequenceControlKind.Rect => return "rect"
            case SequenceControlKind.Else => return "else"
            case SequenceControlKind.And => return "and"
            case _ => return "end"
        }
    }

    private func eventKindName(value: SequenceEventKind): String {
        match (value) {
            case SequenceEventKind.ControlStart => return "control-start"
            case SequenceEventKind.ControlDivider => return "control-divider"
            case SequenceEventKind.ControlEnd => return "control-end"
            case SequenceEventKind.Note => return "note"
            case SequenceEventKind.Activate => return "activate"
            case SequenceEventKind.Deactivate => return "deactivate"
            case _ => return "message"
        }
    }

    private func diagramKindName(kind: DiagramKind): String {
        match (kind) {
            case DiagramKind.Sequence => return "sequence"
            case DiagramKind.Flowchart => return "flowchart"
            case DiagramKind.Mindmap => return "mindmap"
            case DiagramKind.Class => return "class"
            case DiagramKind.Er => return "er"
            case DiagramKind.Pie => return "pie"
            case DiagramKind.Gantt => return "gantt"
            case DiagramKind.State => return "state"
            case _ => return "unsupported"
        }
    }
}
