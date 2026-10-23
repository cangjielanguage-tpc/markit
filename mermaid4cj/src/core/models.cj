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

    public TextRange(public let start: Int64, public let end: Int64) {}

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

    public FlowNodeRef(public let id: String, public let label: TextRange, public let labelText!: ?String = None, public let shape!: FlowNodeShape = FlowNodeShape.Rectangle, public let className!: ?String = None) {}
}

public class MermaidRenderOptions {

    public MermaidRenderOptions(
        public let theme!: MermaidTheme = MermaidTheme.Default,
        public let classPrefix!: String = "mmd",
        public let idPrefix!: String = "mmd",
        public let title!: ?String = None,
        public let errorSvg!: Bool = true,
        public let textMeasurer!: MermaidTextMeasurer = DefaultMermaidTextMeasurer()
    ) {}
}

public class MermaidRenderResult {

    public MermaidRenderResult(public let svg: String, public let kind!: DiagramKind, public let diagnostics!: Array<String> = [], public let supported!: Bool = true) {}
}

public enum MermaidHtmlThemeMode {
    Light | Dark | Dual
}

public class MermaidHtmlOptions {

    public MermaidHtmlOptions(
        public let themeMode!: MermaidHtmlThemeMode = MermaidHtmlThemeMode.Dual,
        public let classPrefix!: String = "mmd",
        public let idPrefix!: String = "mmd",
        public let title!: ?String = None,
        public let includeSource!: Bool = false,
        public let textMeasurer!: MermaidTextMeasurer = DefaultMermaidTextMeasurer()
    ) {}
}

public class MermaidHtmlRenderResult {

    public MermaidHtmlRenderResult(
        public let html: String,
        public let light!: ?MermaidRenderResult = None,
        public let dark!: ?MermaidRenderResult = None,
        public let diagnostics!: Array<String> = [],
        public let supported!: Bool = true
    ) {}
}

public class FlowNode {

    public FlowNode(public let id: String, public let label: TextRange, public let labelText!: ?String = None, public let shape!: FlowNodeShape = FlowNodeShape.Rectangle, public let className!: ?String = None) {}
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

    public FlowEdge(
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

    public FlowNodeStyle(public let fill!: ?String = None, public let stroke!: ?String = None, public let color!: ?String = None) {}
}

public class FlowSubgraph {

    public FlowSubgraph(public let id: String, public let title: TextRange, public let parentId!: ?String = None, public let dir!: ?FlowDirection = None, public let explicitDir!: Bool = false) {}
}

public class FlowchartDiagram {

    public FlowchartDiagram(
        public let source: String,
        public let direction: FlowDirection,
        public let nodes: ArrayList<FlowNode>,
        public let edges: ArrayList<FlowEdge>,
        public let classStyles!: HashMap<String, FlowNodeStyle> = HashMap<String, FlowNodeStyle>(),
        public let nodeClasses!: HashMap<String, String> = HashMap<String, String>(),
        public let nodeStyles!: HashMap<String, FlowNodeStyle> = HashMap<String, FlowNodeStyle>(),
        public let subgraphs!: ArrayList<TextRange> = ArrayList<TextRange>(),
        public let subgraphDefs!: ArrayList<FlowSubgraph> = ArrayList<FlowSubgraph>(),
        public let nodeParents!: HashMap<String, String> = HashMap<String, String>()
    ) {}
}

public class FlowParseResult {

    public FlowParseResult(public let diagram: FlowchartDiagram, public let diagnostics!: Array<String> = []) {}
}

public enum SequenceParticipantType {
    Participant | Actor | Boundary | Control | Entity | Database | Collections | Queue
}

public class SequenceParticipant {

    public SequenceParticipant(public let id: String, public let description: String, public let participantType!: SequenceParticipantType = SequenceParticipantType.Participant) {}
}

public enum SequenceMessageType {
    Solid | Dotted | SolidOpen | DottedOpen | SolidCross | DottedCross | SolidPoint | DottedPoint | BidirectionalSolid | BidirectionalDotted
}

public class SequenceMessage {

    public SequenceMessage(public let source: String, public let target: String, public let text: String, public let messageType!: SequenceMessageType = SequenceMessageType.Solid, public let activateTarget!: Bool = false, public let deactivateSource!: Bool = false) {}
}

public enum SequenceNotePlacement {
    LeftOf | RightOf | Over
}

public class SequenceNote {

    public SequenceNote(public let placement: SequenceNotePlacement, public let actors: Array<String>, public let text: String) {}
}

public enum SequenceEventKind {
    Message | Note | Activate | Deactivate | ControlStart | ControlDivider | ControlEnd
}

public enum SequenceControlKind {
    Alt | Opt | Loop | Par | Critical | Break | Rect | Else | And | End
}

public class SequenceControl {

    public SequenceControl(public let kind: SequenceControlKind, public let text!: String = "", public let depth!: Int64 = 0) {}
}

public class SequenceEvent {

    public SequenceEvent(public let kind: SequenceEventKind, public let messageIndex!: Int64 = -1, public let noteIndex!: Int64 = -1, public let controlIndex!: Int64 = -1, public let actor!: String = "") {}
}

public class SequenceDiagram {

    public SequenceDiagram(
        public let source: String,
        public let title!: ?String = None,
        public let autonumber!: Bool = false,
        public let autonumberStart!: Int64 = 100,
        public let autonumberStep!: Int64 = 100,
        public let participants!: ArrayList<SequenceParticipant> = ArrayList<SequenceParticipant>(),
        public let messages!: ArrayList<SequenceMessage> = ArrayList<SequenceMessage>(),
        public let notes!: ArrayList<SequenceNote> = ArrayList<SequenceNote>(),
        public let controls!: ArrayList<SequenceControl> = ArrayList<SequenceControl>(),
        public let events!: ArrayList<SequenceEvent> = ArrayList<SequenceEvent>()
    ) {}
}

public class SequenceParseResult {

    public SequenceParseResult(public let diagram: SequenceDiagram, public let diagnostics!: Array<String> = []) {}
}

public class GenericNode {

    public GenericNode(public let id: String, public let label: String, public let level!: Int64 = 0) {}
}

public class GenericEdge {

    public GenericEdge(public let source: String, public let target: String, public let label!: String = "", public let relation!: String = "") {}
}

public class GenericRow {

    public GenericRow(public let label: String, public let value: Float64) {}
}

public class GenericTask {

    public GenericTask(public let label: String, public let section!: String = "", public let status!: String = "", public let id!: String = "", public let start!: Int64 = 0, public let end!: Int64 = 1) {}
}

public class GenericDiagram {

    public GenericDiagram(
        public let source: String,
        public let kind: DiagramKind,
        public let title!: ?String = None,
        public let nodes!: ArrayList<GenericNode> = ArrayList<GenericNode>(),
        public let edges!: ArrayList<GenericEdge> = ArrayList<GenericEdge>(),
        public let rows!: ArrayList<GenericRow> = ArrayList<GenericRow>(),
        public let tasks!: ArrayList<GenericTask> = ArrayList<GenericTask>()
    ) {}
}

public class GenericParseResult {

    public GenericParseResult(public let diagram: GenericDiagram, public let diagnostics!: Array<String> = []) {}
}

public enum ClassRelationType {
    Inheritance | Composition | Aggregation | Association | Link | Dependency | Realization | DashedLink | Lollipop
}

public class ClassMember {

    public ClassMember(public let text: String, public let isMethod: Bool) {}
}

public class ClassDef {
    public let id: String
    public let label: String
    public let annotation: ?String
    public let namespaceId: ?String
    public let genericType: ?String
    public let members: ArrayList<ClassMember>

    public ClassDef(
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

    public ClassNamespace(id: String, label!: String = "", parentId!: ?String = None, explicit!: Bool = true) {
        this.id = id
        this.label = if (label.isEmpty()) { id } else { label }
        this.parentId = parentId
        this.explicit = explicit
    }
}

public class ClassRelation {

    public ClassRelation(
        public let source: String,
        public let target: String,
        public let token: String,
        public let relationType: ClassRelationType,
        public let label!: String = "",
        public let startMarker!: String = "",
        public let endMarker!: String = "",
        public let dashed!: Bool = false
    ) {}
}

public class ClassNote {

    public ClassNote(public let text: String, public let classId!: ?String = None) {}
}

public class ClassDiagram {

    public ClassDiagram(
        public let source: String,
        public let title!: ?String = None,
        public let classes!: ArrayList<ClassDef> = ArrayList<ClassDef>(),
        public let relations!: ArrayList<ClassRelation> = ArrayList<ClassRelation>(),
        public let namespaces!: ArrayList<ClassNamespace> = ArrayList<ClassNamespace>(),
        public let notes!: ArrayList<ClassNote> = ArrayList<ClassNote>()
    ) {}
}

public class ClassParseResult {

    public ClassParseResult(public let diagram: ClassDiagram, public let diagnostics!: Array<String> = []) {}
}

public enum ErDirection {
    TB | BT | LR | RL
}

public enum ErCardinality {
    ZeroOrOne | ExactlyOne | ZeroOrMore | OneOrMore
}

public class ErAttribute {

    public ErAttribute(public let attributeType: String, public let name: String, public let key!: String = "", public let comment!: String = "") {}
}

public class ErEntity {
    public let id: String
    public let label: String
    public let attributes: ArrayList<ErAttribute>

    public ErEntity(id: String, label!: String = "", attributes!: ArrayList<ErAttribute> = ArrayList<ErAttribute>()) {
        this.id = id
        this.label = if (label.isEmpty()) { id } else { label }
        this.attributes = attributes
    }
}

public class ErRelationship {

    public ErRelationship(
        public let source: String,
        public let target: String,
        public let label: String,
        public let sourceCardinality: ErCardinality,
        public let targetCardinality: ErCardinality,
        public let identifying: Bool,
        public let token: String
    ) {}
}

public class ErDiagram {

    public ErDiagram(
        public let source: String,
        public let title!: ?String = None,
        public let direction!: ErDirection = ErDirection.TB,
        public let entities!: ArrayList<ErEntity> = ArrayList<ErEntity>(),
        public let relationships!: ArrayList<ErRelationship> = ArrayList<ErRelationship>()
    ) {}
}

public class ErParseResult {

    public ErParseResult(public let diagram: ErDiagram, public let diagnostics!: Array<String> = []) {}
}

public enum MindmapNodeShape {
    Default | Square | Rounded | Circle | Bang | Cloud | Hexagon
}

public class MindmapNode {

    public MindmapNode(public let id: String, public let label: String, public let level: Int64, public let parentIndex: Int64, public let shape!: MindmapNodeShape = MindmapNodeShape.Default, public let icon!: String = "", public let className!: String = "") {}
}

public class MindmapDiagram {

    public MindmapDiagram(public let source: String, public let nodes!: ArrayList<MindmapNode> = ArrayList<MindmapNode>()) {}
}

public class MindmapParseResult {

    public MindmapParseResult(public let diagram: MindmapDiagram, public let diagnostics!: Array<String> = []) {}
}

public class PieSlice {

    public PieSlice(public let label: String, public let value: Float64) {}
}

public class PieDiagram {

    public PieDiagram(public let source: String, public let title!: ?String = None, public let showData!: Bool = false, public let slices!: ArrayList<PieSlice> = ArrayList<PieSlice>()) {}
}

public class PieParseResult {

    public PieParseResult(public let diagram: PieDiagram, public let diagnostics!: Array<String> = []) {}
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

    public StateNode(id: String, label!: String = "", kind!: StateNodeKind = StateNodeKind.State, parentId!: ?String = None) {
        this.id = id
        this.label = if (label.isEmpty()) { id } else { label }
        this.kind = kind
        this.parentId = parentId
    }
}

public class StateTransition {

    public StateTransition(public let source: String, public let target: String, public let label!: String = "") {}
}

public class StateDiagram {

    public StateDiagram(public let source: String, public let direction!: StateDirection = StateDirection.TB, public let nodes!: ArrayList<StateNode> = ArrayList<StateNode>(), public let transitions!: ArrayList<StateTransition> = ArrayList<StateTransition>()) {}
}

public class StateParseResult {

    public StateParseResult(public let diagram: StateDiagram, public let diagnostics!: Array<String> = []) {}
}

public class GanttTask {

    public GanttTask(
        public let label: String,
        public let section: String,
        public let id: String,
        public let start: Int64,
        public let end: Int64,
        public let order: Int64,
        public let done!: Bool = false,
        public let active!: Bool = false,
        public let crit!: Bool = false,
        public let milestone!: Bool = false,
        public let vert!: Bool = false
    ) {}
}

public class GanttDiagram {

    public GanttDiagram(
        public let source: String,
        public let title!: ?String = None,
        public let dateFormat!: String = "YYYY-MM-DD",
        public let axisFormat!: String = "%Y-%m-%d",
        public let tickInterval!: String = "",
        public let weekday!: String = "",
        public let todayMarker!: String = "",
        public let inclusiveEndDates!: Bool = false,
        public let excludes!: Array<String> = [],
        public let sections!: Array<String> = [],
        public let tasks!: ArrayList<GanttTask> = ArrayList<GanttTask>()
    ) {}
}

public class GanttParseResult {

    public GanttParseResult(public let diagram: GanttDiagram, public let diagnostics!: Array<String> = []) {}
}
