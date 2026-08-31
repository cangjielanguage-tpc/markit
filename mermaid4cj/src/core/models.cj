package mermaid4cj.core

import std.collection.{ArrayList, HashMap}

public enum DiagramKind {
    Flowchart | Sequence | Mindmap | Class | State | Er | Pie | Gantt | Unsupported
}

public enum MermaidTheme {
    Default | Dark
}

public enum FlowDirection {
    TD | TB | BT | LR | RL
}

public enum FlowNodeShape {
    Rectangle | Rounded | Circle | Stadium | Diamond | Subroutine | Cylinder | Datastore |
    Hexagon | LeanRight | LeanLeft | Trapezoid | InvTrapezoid | DoubleCircle | Ellipse | Odd | Text |
    Card | ShadedProcess | SmallCircle | FramedCircle | FilledCircle | Fork |
    Document | MultiProcess | DividedProcess | Triangle | SlopedRectangle |
    CrossedCircle | TaggedProcess | TaggedDocument | Flag | Hourglass |
    NotchedPentagon | FlippedTriangle | Delay | CurvedTrapezoid |
    WindowPane | LinedCylinder | HorizontalCylinder | MultiDocument |
    LinedDocument | Bang | Cloud | LightningBolt | BowTieRectangle |
    CurlyBraceLeft | CurlyBraceRight | CurlyBraces
}

public enum FlowEdgeStyle {
    Solid | Dotted | Thick
}

public enum FlowEdgeMarker {
    None | Point | Circle | Cross
}

public struct TextRange {
    public let start: Int64
    public let end: Int64

    public init(start: Int64, end: Int64) {
        this.start = start
        this.end = end
    }

    public prop size: Int64 {
        get() {
            return end - start
        }
    }

    public func isEmpty(): Bool {
        return start >= end
    }
}

public struct FlowNodeRef {
    public let id: String
    public let label: TextRange
    public let labelText: ?String
    public let shape: FlowNodeShape
    public let className: ?String

    public init(id: String, label: TextRange, labelText!: ?String = None, shape!: FlowNodeShape = FlowNodeShape.Rectangle, className!: ?String = None) {
        this.id = id
        this.label = label
        this.labelText = labelText
        this.shape = shape
        this.className = className
    }
}

public class MermaidRenderOptions {
    public let theme: MermaidTheme
    public let classPrefix: String
    public let idPrefix: String
    public let title: ?String
    public let errorSvg: Bool
    public let textMeasurer: MermaidTextMeasurer

    public init(
        theme!: MermaidTheme = MermaidTheme.Default,
        classPrefix!: String = "mmd",
        idPrefix!: String = "mmd",
        title!: ?String = None,
        errorSvg!: Bool = true,
        textMeasurer!: MermaidTextMeasurer = DefaultMermaidTextMeasurer()
    ) {
        this.theme = theme
        this.classPrefix = classPrefix
        this.idPrefix = idPrefix
        this.title = title
        this.errorSvg = errorSvg
        this.textMeasurer = textMeasurer
    }
}

public class MermaidRenderResult {
    public let svg: String
    public let kind: DiagramKind
    public let diagnostics: Array<String>
    public let supported: Bool

    public init(svg: String, kind!: DiagramKind, diagnostics!: Array<String> = [], supported!: Bool = true) {
        this.svg = svg
        this.kind = kind
        this.diagnostics = diagnostics
        this.supported = supported
    }
}

public enum MermaidHtmlThemeMode {
    Light | Dark | Dual
}

public class MermaidHtmlOptions {
    public let themeMode: MermaidHtmlThemeMode
    public let classPrefix: String
    public let idPrefix: String
    public let title: ?String
    public let includeSource: Bool
    public let textMeasurer: MermaidTextMeasurer

    public init(
        themeMode!: MermaidHtmlThemeMode = MermaidHtmlThemeMode.Dual,
        classPrefix!: String = "mmd",
        idPrefix!: String = "mmd",
        title!: ?String = None,
        includeSource!: Bool = false,
        textMeasurer!: MermaidTextMeasurer = DefaultMermaidTextMeasurer()
    ) {
        this.themeMode = themeMode
        this.classPrefix = classPrefix
        this.idPrefix = idPrefix
        this.title = title
        this.includeSource = includeSource
        this.textMeasurer = textMeasurer
    }
}

public class MermaidHtmlRenderResult {
    public let html: String
    public let light: ?MermaidRenderResult
    public let dark: ?MermaidRenderResult
    public let diagnostics: Array<String>
    public let supported: Bool

    public init(
        html: String,
        light!: ?MermaidRenderResult = None,
        dark!: ?MermaidRenderResult = None,
        diagnostics!: Array<String> = [],
        supported!: Bool = true
    ) {
        this.html = html
        this.light = light
        this.dark = dark
        this.diagnostics = diagnostics
        this.supported = supported
    }
}

public class FlowNode {
    public let id: String
    public let label: TextRange
    public let labelText: ?String
    public let shape: FlowNodeShape
    public let className: ?String

    public init(id: String, label: TextRange, labelText!: ?String = None, shape!: FlowNodeShape = FlowNodeShape.Rectangle, className!: ?String = None) {
        this.id = id
        this.label = label
        this.labelText = labelText
        this.shape = shape
        this.className = className
    }
}

public class FlowEdge {
    public let id: ?String
    public let source: String
    public let target: String
    public let label: ?TextRange
    public let style: FlowEdgeStyle
    public let length: Int64
    public let directed: Bool
    public let markerStart: FlowEdgeMarker
    public let markerEnd: FlowEdgeMarker

    public init(
        source: String,
        target: String,
        id!: ?String = None,
        label!: ?TextRange = None,
        style!: FlowEdgeStyle = FlowEdgeStyle.Solid,
        length!: Int64 = 1,
        directed!: Bool = true,
        markerStart!: FlowEdgeMarker = FlowEdgeMarker.None,
        markerEnd!: FlowEdgeMarker = FlowEdgeMarker.Point
    ) {
        this.id = id
        this.source = source
        this.target = target
        this.label = label
        this.style = style
        this.length = length
        this.directed = directed
        this.markerStart = markerStart
        this.markerEnd = if (directed) { markerEnd } else { FlowEdgeMarker.None }
    }
}

public class FlowNodeStyle {
    public let fill: ?String
    public let stroke: ?String
    public let color: ?String

    public init(fill!: ?String = None, stroke!: ?String = None, color!: ?String = None) {
        this.fill = fill
        this.stroke = stroke
        this.color = color
    }
}

public class FlowSubgraph {
    public let id: String
    public let title: TextRange
    public let parentId: ?String
    public let dir: ?FlowDirection
    public let explicitDir: Bool

    public init(id: String, title: TextRange, parentId!: ?String = None, dir!: ?FlowDirection = None, explicitDir!: Bool = false) {
        this.id = id
        this.title = title
        this.parentId = parentId
        this.dir = dir
        this.explicitDir = explicitDir
    }
}

public class FlowchartDiagram {
    public let source: String
    public let direction: FlowDirection
    public let nodes: ArrayList<FlowNode>
    public let edges: ArrayList<FlowEdge>
    public let classStyles: HashMap<String, FlowNodeStyle>
    public let nodeClasses: HashMap<String, String>
    public let nodeStyles: HashMap<String, FlowNodeStyle>
    public let subgraphs: ArrayList<TextRange>
    public let subgraphDefs: ArrayList<FlowSubgraph>
    public let nodeParents: HashMap<String, String>

    public init(
        source: String,
        direction: FlowDirection,
        nodes: ArrayList<FlowNode>,
        edges: ArrayList<FlowEdge>,
        classStyles!: HashMap<String, FlowNodeStyle> = HashMap<String, FlowNodeStyle>(),
        nodeClasses!: HashMap<String, String> = HashMap<String, String>(),
        nodeStyles!: HashMap<String, FlowNodeStyle> = HashMap<String, FlowNodeStyle>(),
        subgraphs!: ArrayList<TextRange> = ArrayList<TextRange>(),
        subgraphDefs!: ArrayList<FlowSubgraph> = ArrayList<FlowSubgraph>(),
        nodeParents!: HashMap<String, String> = HashMap<String, String>()
    ) {
        this.source = source
        this.direction = direction
        this.nodes = nodes
        this.edges = edges
        this.classStyles = classStyles
        this.nodeClasses = nodeClasses
        this.nodeStyles = nodeStyles
        this.subgraphs = subgraphs
        this.subgraphDefs = subgraphDefs
        this.nodeParents = nodeParents
    }
}

public class FlowParseResult {
    public let diagram: FlowchartDiagram
    public let diagnostics: Array<String>

    public init(diagram: FlowchartDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}

public enum SequenceParticipantType {
    Participant | Actor | Boundary | Control | Entity | Database | Collections | Queue
}

public class SequenceParticipant {
    public let id: String
    public let description: String
    public let participantType: SequenceParticipantType

    public init(id: String, description: String, participantType!: SequenceParticipantType = SequenceParticipantType.Participant) {
        this.id = id
        this.description = description
        this.participantType = participantType
    }
}

public enum SequenceMessageType {
    Solid | Dotted | SolidOpen | DottedOpen | SolidCross | DottedCross | SolidPoint | DottedPoint | BidirectionalSolid | BidirectionalDotted
}

public class SequenceMessage {
    public let source: String
    public let target: String
    public let text: String
    public let messageType: SequenceMessageType
    public let activateTarget: Bool
    public let deactivateSource: Bool

    public init(source: String, target: String, text: String, messageType!: SequenceMessageType = SequenceMessageType.Solid, activateTarget!: Bool = false, deactivateSource!: Bool = false) {
        this.source = source
        this.target = target
        this.text = text
        this.messageType = messageType
        this.activateTarget = activateTarget
        this.deactivateSource = deactivateSource
    }
}

public enum SequenceNotePlacement {
    LeftOf | RightOf | Over
}

public class SequenceNote {
    public let placement: SequenceNotePlacement
    public let actors: Array<String>
    public let text: String

    public init(placement: SequenceNotePlacement, actors: Array<String>, text: String) {
        this.placement = placement
        this.actors = actors
        this.text = text
    }
}

public enum SequenceEventKind {
    Message | Note | Activate | Deactivate | ControlStart | ControlDivider | ControlEnd
}

public enum SequenceControlKind {
    Alt | Opt | Loop | Par | Critical | Break | Rect | Else | And | End
}

public class SequenceControl {
    public let kind: SequenceControlKind
    public let text: String
    public let depth: Int64

    public init(kind: SequenceControlKind, text!: String = "", depth!: Int64 = 0) {
        this.kind = kind
        this.text = text
        this.depth = depth
    }
}

public class SequenceEvent {
    public let kind: SequenceEventKind
    public let messageIndex: Int64
    public let noteIndex: Int64
    public let controlIndex: Int64
    public let actor: String

    public init(kind: SequenceEventKind, messageIndex!: Int64 = -1, noteIndex!: Int64 = -1, controlIndex!: Int64 = -1, actor!: String = "") {
        this.kind = kind
        this.messageIndex = messageIndex
        this.noteIndex = noteIndex
        this.controlIndex = controlIndex
        this.actor = actor
    }
}

public class SequenceDiagram {
    public let source: String
    public let title: ?String
    public let autonumber: Bool
    public let autonumberStart: Int64
    public let autonumberStep: Int64
    public let participants: ArrayList<SequenceParticipant>
    public let messages: ArrayList<SequenceMessage>
    public let notes: ArrayList<SequenceNote>
    public let controls: ArrayList<SequenceControl>
    public let events: ArrayList<SequenceEvent>

    public init(
        source: String,
        title!: ?String = None,
        autonumber!: Bool = false,
        autonumberStart!: Int64 = 100,
        autonumberStep!: Int64 = 100,
        participants!: ArrayList<SequenceParticipant> = ArrayList<SequenceParticipant>(),
        messages!: ArrayList<SequenceMessage> = ArrayList<SequenceMessage>(),
        notes!: ArrayList<SequenceNote> = ArrayList<SequenceNote>(),
        controls!: ArrayList<SequenceControl> = ArrayList<SequenceControl>(),
        events!: ArrayList<SequenceEvent> = ArrayList<SequenceEvent>()
    ) {
        this.source = source
        this.title = title
        this.autonumber = autonumber
        this.autonumberStart = autonumberStart
        this.autonumberStep = autonumberStep
        this.participants = participants
        this.messages = messages
        this.notes = notes
        this.controls = controls
        this.events = events
    }
}

public class SequenceParseResult {
    public let diagram: SequenceDiagram
    public let diagnostics: Array<String>

    public init(diagram: SequenceDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}

public class GenericNode {
    public let id: String
    public let label: String
    public let level: Int64

    public init(id: String, label: String, level!: Int64 = 0) {
        this.id = id
        this.label = label
        this.level = level
    }
}

public class GenericEdge {
    public let source: String
    public let target: String
    public let label: String
    public let relation: String

    public init(source: String, target: String, label!: String = "", relation!: String = "") {
        this.source = source
        this.target = target
        this.label = label
        this.relation = relation
    }
}

public class GenericRow {
    public let label: String
    public let value: Float64

    public init(label: String, value: Float64) {
        this.label = label
        this.value = value
    }
}

public class GenericTask {
    public let label: String
    public let section: String
    public let status: String
    public let id: String
    public let start: Int64
    public let end: Int64

    public init(label: String, section!: String = "", status!: String = "", id!: String = "", start!: Int64 = 0, end!: Int64 = 1) {
        this.label = label
        this.section = section
        this.status = status
        this.id = id
        this.start = start
        this.end = end
    }
}

public class GenericDiagram {
    public let source: String
    public let kind: DiagramKind
    public let title: ?String
    public let nodes: ArrayList<GenericNode>
    public let edges: ArrayList<GenericEdge>
    public let rows: ArrayList<GenericRow>
    public let tasks: ArrayList<GenericTask>

    public init(
        source: String,
        kind: DiagramKind,
        title!: ?String = None,
        nodes!: ArrayList<GenericNode> = ArrayList<GenericNode>(),
        edges!: ArrayList<GenericEdge> = ArrayList<GenericEdge>(),
        rows!: ArrayList<GenericRow> = ArrayList<GenericRow>(),
        tasks!: ArrayList<GenericTask> = ArrayList<GenericTask>()
    ) {
        this.source = source
        this.kind = kind
        this.title = title
        this.nodes = nodes
        this.edges = edges
        this.rows = rows
        this.tasks = tasks
    }
}

public class GenericParseResult {
    public let diagram: GenericDiagram
    public let diagnostics: Array<String>

    public init(diagram: GenericDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}

public enum ClassRelationType {
    Inheritance | Composition | Aggregation | Association | Link | Dependency | Realization | DashedLink | Lollipop
}

public class ClassMember {
    public let text: String
    public let isMethod: Bool

    public init(text: String, isMethod: Bool) {
        this.text = text
        this.isMethod = isMethod
    }
}

public class ClassDef {
    public let id: String
    public let label: String
    public let annotation: ?String
    public let namespaceId: ?String
    public let genericType: ?String
    public let members: ArrayList<ClassMember>

    public init(
        id: String,
        label!: String = "",
        annotation!: ?String = None,
        namespaceId!: ?String = None,
        genericType!: ?String = None,
        members!: ArrayList<ClassMember> = ArrayList<ClassMember>()
    ) {
        this.id = id
        this.label = if (label.isEmpty()) { id } else { label }
        this.annotation = annotation
        this.namespaceId = namespaceId
        this.genericType = genericType
        this.members = members
    }
}

public class ClassNamespace {
    public let id: String
    public let label: String
    public let parentId: ?String
    public let explicit: Bool

    public init(id: String, label!: String = "", parentId!: ?String = None, explicit!: Bool = true) {
        this.id = id
        this.label = if (label.isEmpty()) { id } else { label }
        this.parentId = parentId
        this.explicit = explicit
    }
}

public class ClassRelation {
    public let source: String
    public let target: String
    public let token: String
    public let relationType: ClassRelationType
    public let label: String
    public let startMarker: String
    public let endMarker: String
    public let dashed: Bool

    public init(
        source: String,
        target: String,
        token: String,
        relationType: ClassRelationType,
        label!: String = "",
        startMarker!: String = "",
        endMarker!: String = "",
        dashed!: Bool = false
    ) {
        this.source = source
        this.target = target
        this.token = token
        this.relationType = relationType
        this.label = label
        this.startMarker = startMarker
        this.endMarker = endMarker
        this.dashed = dashed
    }
}

public class ClassNote {
    public let classId: ?String
    public let text: String

    public init(text: String, classId!: ?String = None) {
        this.text = text
        this.classId = classId
    }
}

public class ClassDiagram {
    public let source: String
    public let title: ?String
    public let classes: ArrayList<ClassDef>
    public let relations: ArrayList<ClassRelation>
    public let namespaces: ArrayList<ClassNamespace>
    public let notes: ArrayList<ClassNote>

    public init(
        source: String,
        title!: ?String = None,
        classes!: ArrayList<ClassDef> = ArrayList<ClassDef>(),
        relations!: ArrayList<ClassRelation> = ArrayList<ClassRelation>(),
        namespaces!: ArrayList<ClassNamespace> = ArrayList<ClassNamespace>(),
        notes!: ArrayList<ClassNote> = ArrayList<ClassNote>()
    ) {
        this.source = source
        this.title = title
        this.classes = classes
        this.relations = relations
        this.namespaces = namespaces
        this.notes = notes
    }
}

public class ClassParseResult {
    public let diagram: ClassDiagram
    public let diagnostics: Array<String>

    public init(diagram: ClassDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}

public enum ErDirection {
    TB | BT | LR | RL
}

public enum ErCardinality {
    ZeroOrOne | ExactlyOne | ZeroOrMore | OneOrMore
}

public class ErAttribute {
    public let attributeType: String
    public let name: String
    public let key: String
    public let comment: String

    public init(attributeType: String, name: String, key!: String = "", comment!: String = "") {
        this.attributeType = attributeType
        this.name = name
        this.key = key
        this.comment = comment
    }
}

public class ErEntity {
    public let id: String
    public let label: String
    public let attributes: ArrayList<ErAttribute>

    public init(id: String, label!: String = "", attributes!: ArrayList<ErAttribute> = ArrayList<ErAttribute>()) {
        this.id = id
        this.label = if (label.isEmpty()) { id } else { label }
        this.attributes = attributes
    }
}

public class ErRelationship {
    public let source: String
    public let target: String
    public let label: String
    public let sourceCardinality: ErCardinality
    public let targetCardinality: ErCardinality
    public let identifying: Bool
    public let token: String

    public init(
        source: String,
        target: String,
        label: String,
        sourceCardinality: ErCardinality,
        targetCardinality: ErCardinality,
        identifying: Bool,
        token: String
    ) {
        this.source = source
        this.target = target
        this.label = label
        this.sourceCardinality = sourceCardinality
        this.targetCardinality = targetCardinality
        this.identifying = identifying
        this.token = token
    }
}

public class ErDiagram {
    public let source: String
    public let title: ?String
    public let direction: ErDirection
    public let entities: ArrayList<ErEntity>
    public let relationships: ArrayList<ErRelationship>

    public init(
        source: String,
        title!: ?String = None,
        direction!: ErDirection = ErDirection.TB,
        entities!: ArrayList<ErEntity> = ArrayList<ErEntity>(),
        relationships!: ArrayList<ErRelationship> = ArrayList<ErRelationship>()
    ) {
        this.source = source
        this.title = title
        this.direction = direction
        this.entities = entities
        this.relationships = relationships
    }
}

public class ErParseResult {
    public let diagram: ErDiagram
    public let diagnostics: Array<String>

    public init(diagram: ErDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}

public enum MindmapNodeShape {
    Default | Square | Rounded | Circle | Bang | Cloud | Hexagon
}

public class MindmapNode {
    public let id: String
    public let label: String
    public let level: Int64
    public let parentIndex: Int64
    public let shape: MindmapNodeShape
    public let icon: String
    public let className: String

    public init(id: String, label: String, level: Int64, parentIndex: Int64, shape!: MindmapNodeShape = MindmapNodeShape.Default, icon!: String = "", className!: String = "") {
        this.id = id
        this.label = label
        this.level = level
        this.parentIndex = parentIndex
        this.shape = shape
        this.icon = icon
        this.className = className
    }
}

public class MindmapDiagram {
    public let source: String
    public let nodes: ArrayList<MindmapNode>

    public init(source: String, nodes!: ArrayList<MindmapNode> = ArrayList<MindmapNode>()) {
        this.source = source
        this.nodes = nodes
    }
}

public class MindmapParseResult {
    public let diagram: MindmapDiagram
    public let diagnostics: Array<String>

    public init(diagram: MindmapDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}

public class PieSlice {
    public let label: String
    public let value: Float64

    public init(label: String, value: Float64) {
        this.label = label
        this.value = value
    }
}

public class PieDiagram {
    public let source: String
    public let title: ?String
    public let showData: Bool
    public let slices: ArrayList<PieSlice>

    public init(source: String, title!: ?String = None, showData!: Bool = false, slices!: ArrayList<PieSlice> = ArrayList<PieSlice>()) {
        this.source = source
        this.title = title
        this.showData = showData
        this.slices = slices
    }
}

public class PieParseResult {
    public let diagram: PieDiagram
    public let diagnostics: Array<String>

    public init(diagram: PieDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}

public enum StateDirection {
    TB | BT | LR | RL
}

public enum StateNodeKind {
    State | Start | End | Composite
}

public class StateNode {
    public let id: String
    public let label: String
    public let kind: StateNodeKind
    public let parentId: ?String

    public init(id: String, label!: String = "", kind!: StateNodeKind = StateNodeKind.State, parentId!: ?String = None) {
        this.id = id
        this.label = if (label.isEmpty()) { id } else { label }
        this.kind = kind
        this.parentId = parentId
    }
}

public class StateTransition {
    public let source: String
    public let target: String
    public let label: String

    public init(source: String, target: String, label!: String = "") {
        this.source = source
        this.target = target
        this.label = label
    }
}

public class StateDiagram {
    public let source: String
    public let direction: StateDirection
    public let nodes: ArrayList<StateNode>
    public let transitions: ArrayList<StateTransition>

    public init(source: String, direction!: StateDirection = StateDirection.TB, nodes!: ArrayList<StateNode> = ArrayList<StateNode>(), transitions!: ArrayList<StateTransition> = ArrayList<StateTransition>()) {
        this.source = source
        this.direction = direction
        this.nodes = nodes
        this.transitions = transitions
    }
}

public class StateParseResult {
    public let diagram: StateDiagram
    public let diagnostics: Array<String>

    public init(diagram: StateDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}

public class GanttTask {
    public let label: String
    public let section: String
    public let id: String
    public let start: Int64
    public let end: Int64
    public let order: Int64
    public let done: Bool
    public let active: Bool
    public let crit: Bool
    public let milestone: Bool
    public let vert: Bool

    public init(
        label: String,
        section: String,
        id: String,
        start: Int64,
        end: Int64,
        order: Int64,
        done!: Bool = false,
        active!: Bool = false,
        crit!: Bool = false,
        milestone!: Bool = false,
        vert!: Bool = false
    ) {
        this.label = label
        this.section = section
        this.id = id
        this.start = start
        this.end = end
        this.order = order
        this.done = done
        this.active = active
        this.crit = crit
        this.milestone = milestone
        this.vert = vert
    }
}

public class GanttDiagram {
    public let source: String
    public let title: ?String
    public let dateFormat: String
    public let axisFormat: String
    public let tickInterval: String
    public let weekday: String
    public let todayMarker: String
    public let inclusiveEndDates: Bool
    public let excludes: Array<String>
    public let sections: Array<String>
    public let tasks: ArrayList<GanttTask>

    public init(
        source: String,
        title!: ?String = None,
        dateFormat!: String = "YYYY-MM-DD",
        axisFormat!: String = "%Y-%m-%d",
        tickInterval!: String = "",
        weekday!: String = "",
        todayMarker!: String = "",
        inclusiveEndDates!: Bool = false,
        excludes!: Array<String> = [],
        sections!: Array<String> = [],
        tasks!: ArrayList<GanttTask> = ArrayList<GanttTask>()
    ) {
        this.source = source
        this.title = title
        this.dateFormat = dateFormat
        this.axisFormat = axisFormat
        this.tickInterval = tickInterval
        this.weekday = weekday
        this.todayMarker = todayMarker
        this.inclusiveEndDates = inclusiveEndDates
        this.excludes = excludes
        this.sections = sections
        this.tasks = tasks
    }
}

public class GanttParseResult {
    public let diagram: GanttDiagram
    public let diagnostics: Array<String>

    public init(diagram: GanttDiagram, diagnostics!: Array<String> = []) {
        this.diagram = diagram
        this.diagnostics = diagnostics
    }
}
