package mermaid4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.ArrayList
import mermaid4cj.MermaidRenderer
import mermaid4cj.core.{FlowDirection, FlowEdgeMarker, FlowEdgeStyle, FlowNode, FlowNodeShape}
import mermaid4cj.parser.FlowchartParser

@Test
@Tag[Mermaid4cj]
class MermaidParserTests {
    @TestCase
    func parsesUpstreamSingleLineSemicolonCase() {
        let source = "graph TD; A-->B"
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 2)
        @Expect(parsed.diagram.edges.size, 1)
        @Expect(parsed.diagram.edges[0].source, "A")
        @Expect(parsed.diagram.edges[0].target, "B")
        @Expect(markerName(parsed.diagram.edges[0].markerEnd), "point")
    }

    @TestCase
    func migratesUpstreamArrowDirectionAliases() {
        let lr = FlowchartParser().parse("graph >;A-->B;")
        let rl = FlowchartParser().parse("graph <;A-->B;")
        let bt = FlowchartParser().parse("graph ^;A-->B;")
        let tb = FlowchartParser().parse("graph v;A-->B;")
        @Expect(lr.diagnostics.isEmpty(), true)
        @Expect(rl.diagnostics.isEmpty(), true)
        @Expect(bt.diagnostics.isEmpty(), true)
        @Expect(tb.diagnostics.isEmpty(), true)
        @Expect(directionName(lr.diagram.direction), "LR")
        @Expect(directionName(rl.diagram.direction), "RL")
        @Expect(directionName(bt.diagram.direction), "BT")
        @Expect(directionName(tb.diagram.direction), "TB")
    }

    @TestCase
    func migratesUpstreamOpenCircleCrossAndPointEdges() {
        let open = FlowchartParser().parse("graph TD;A---B;")
        let point = FlowchartParser().parse("graph TD;A-->B;")
        let circle = FlowchartParser().parse("graph TD;A--oB;")
        let cross = FlowchartParser().parse("graph TD;A--xB;")
        @Expect(open.diagnostics.isEmpty(), true)
        @Expect(point.diagnostics.isEmpty(), true)
        @Expect(circle.diagnostics.isEmpty(), true)
        @Expect(cross.diagnostics.isEmpty(), true)
        @Expect(markerName(open.diagram.edges[0].markerEnd), "none")
        @Expect(markerName(point.diagram.edges[0].markerEnd), "point")
        @Expect(markerName(circle.diagram.edges[0].markerEnd), "circle")
        @Expect(markerName(cross.diagram.edges[0].markerEnd), "cross")
    }

    @TestCase
    func migratesUpstreamDoubleEndedEdgesAsSingleEdge() {
        let normal = FlowchartParser().parse("graph TD;A<-- text -->B;")
        let thick = FlowchartParser().parse("graph TD;A<== text ==>B;")
        let dotted = FlowchartParser().parse("graph TD;A<-. text .->B;")
        let cross = FlowchartParser().parse("graph TD;A x-- cross --x B;")
        let circle = FlowchartParser().parse("graph TD;A o-- circle --o B;")
        @Expect(normal.diagnostics.isEmpty(), true)
        @Expect(thick.diagnostics.isEmpty(), true)
        @Expect(dotted.diagnostics.isEmpty(), true)
        @Expect(cross.diagnostics.isEmpty(), true)
        @Expect(circle.diagnostics.isEmpty(), true)
        @Expect(normal.diagram.edges.size, 1)
        @Expect(cross.diagram.edges.size, 1)
        @Expect(circle.diagram.edges.size, 1)
        @Expect(markerName(normal.diagram.edges[0].markerStart), "point")
        @Expect(markerName(normal.diagram.edges[0].markerEnd), "point")
        @Expect(markerName(cross.diagram.edges[0].markerStart), "cross")
        @Expect(markerName(cross.diagram.edges[0].markerEnd), "cross")
        @Expect(markerName(circle.diagram.edges[0].markerStart), "circle")
        @Expect(markerName(circle.diagram.edges[0].markerEnd), "circle")
        @Expect(styleName(thick.diagram.edges[0].style), "thick")
        @Expect(styleName(dotted.diagram.edges[0].style), "dotted")
        if (let Some(label) <- normal.diagram.edges[0].label) {
            @Expect(normal.diagram.source[label.start..label.end], "text")
        } else {
            @Fail("expected double edge label")
        }
        if (let Some(label) <- cross.diagram.edges[0].label) {
            @Expect(cross.diagram.source[label.start..label.end], "cross")
        } else {
            @Fail("expected double cross edge label")
        }
    }

    @TestCase
    func migratesUpstreamEdgeIdSyntax() {
        let parsed = FlowchartParser().parse("flowchart TD\nA e1@--> B")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 2)
        @Expect(parsed.diagram.edges.size, 1)
        @Expect(parsed.diagram.edges[0].source, "A")
        @Expect(parsed.diagram.edges[0].target, "B")
        @Expect(parsed.diagram.edges[0].id.getOrThrow(), "e1")
    }

    @TestCase
    func nodeLabelsKeepSourceRanges() {
        let source = "flowchart TD\nA[开始 <go>] --> B[结束 & 完成]"
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 2)
        let first = parsed.diagram.nodes[0].label
        let second = parsed.diagram.nodes[1].label
        @Expect(source[first.start..first.end], "开始 <go>")
        @Expect(source[second.start..second.end], "结束 & 完成")
    }

    @TestCase
    func edgeLabelsKeepSourceRanges() {
        let source = "flowchart LR\nA -->|确认 & 继续| B"
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        if (let Some(label) <- parsed.diagram.edges[0].label) {
            @Expect(source[label.start..label.end], "确认 & 继续")
        } else {
            @Fail("expected edge label")
        }
    }

    @TestCase
    func parsesUpstreamBasicFlowchartExample() {
        let source = """
flowchart TD
    A[Christmas] -->|Get money| B(Go shopping)
    B --> C{Let me think}
    C -->|One| D[Laptop]
    C -->|Two| E[iPhone]
    C -->|Three| F[fa:fa-car Car]"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 6)
        @Expect(parsed.diagram.edges.size, 5)
        @Expect(parsed.diagram.edges[0].source, "A")
        @Expect(parsed.diagram.edges[0].target, "B")
        let c = parsed.diagram.nodes[2].label
        @Expect(source[c.start..c.end], "Let me think")
    }

    @TestCase
    func parsesSpaceSeparatedEdgeLabels() {
        let source = "graph TD\nA -- text including URL space --> B"
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 2)
        @Expect(parsed.diagram.edges.size, 1)
        if (let Some(label) <- parsed.diagram.edges[0].label) {
            @Expect(source[label.start..label.end], "text including URL space")
        } else {
            @Fail("expected edge label")
        }
    }

    @TestCase
    func acceptsFlowchartV2AndElkHeaders() {
        let v2 = FlowchartParser().parse("flowchart-v2 TD; A-->B")
        let elk = FlowchartParser().parse("flowchart-elk LR; A-->B")
        @Expect(v2.diagnostics.isEmpty(), true)
        @Expect(elk.diagnostics.isEmpty(), true)
        @Expect(v2.diagram.edges.size, 1)
        @Expect(elk.diagram.edges.size, 1)
    }

    @TestCase
    func detectsGraphWithLeadingSpacesLikeUpstreamUtilsSpec() {
        let renderer = MermaidRenderer()
        @Expect(renderer.supportsDiagramKind(renderer.detectDiagramKind("    graph TB\nbfs1:queue")), true)
        @Expect(renderer.supportsDiagramKind(renderer.detectDiagramKind("  \n  graph TB\nbfs1:queue")), true)
    }

    @TestCase
    func reportsDanglingEdgeLikeUpstreamDiagramSpec() {
        let parsed = FlowchartParser().parse("graph TD; A-->")
        @Expect(parsed.diagnostics.isEmpty(), false)
        @Expect(parsed.diagnostics[0].contains("invalid or incomplete flowchart edge"), true)
    }

    @TestCase
    func parsesClassDefClassAndStyleSubset() {
        let source = """
flowchart TD
A[Start]:::hot --> B[Done]
classDef hot fill:#f9f,stroke:#333,color:#111
class B hot
style B fill:#bbf,stroke:#00f,color:#fff"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.classStyles.contains("hot"), true)
        let hot = parsed.diagram.classStyles.get("hot").getOrThrow()
        @Expect(hot.fill.getOrThrow(), "#f9f")
        @Expect(hot.stroke.getOrThrow(), "#333")
        @Expect(hot.color.getOrThrow(), "#111")
        @Expect(parsed.diagram.nodeClasses.get("A").getOrThrow(), "hot")
        @Expect(parsed.diagram.nodeClasses.get("B").getOrThrow(), "hot")
        @Expect(parsed.diagram.nodeStyles.contains("B"), true)
        let styled = parsed.diagram.nodeStyles.get("B").getOrThrow()
        @Expect(styled.fill.getOrThrow(), "#bbf")
        @Expect(styled.stroke.getOrThrow(), "#00f")
        @Expect(styled.color.getOrThrow(), "#fff")
    }

    @TestCase
    func migratesUpstreamStyleMultipleClassDefsAndLinkStyleControlStatements() {
        let parsed = FlowchartParser().parse("""
graph TD
style Q background:#fff
style R background:#fff,border:1px solid red
classDef firstClass,secondClass background:#bbb,border:1px solid red
A-->B1
A-->B2
linkStyle 10 stroke-width:1px
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodeStyles.get("Q").getOrThrow().fill.getOrThrow(), "#fff")
        @Expect(parsed.diagram.nodeStyles.get("R").getOrThrow().stroke.getOrThrow(), "red")
        @Expect(parsed.diagram.classStyles.get("firstClass").getOrThrow().fill.getOrThrow(), "#bbb")
        @Expect(parsed.diagram.classStyles.get("secondClass").getOrThrow().stroke.getOrThrow(), "red")
        @Expect(parsed.diagram.edges.size, 2)
        @Expect(hasNode(parsed.diagram.nodes, "linkStyle"), false)
    }

    @TestCase
    func parsesDatabaseShapeAndBidirectionalEdge() {
        let source = "flowchart LR\nDB[(Database)] <--> API[Service]"
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 2)
        @Expect(parsed.diagram.edges.size, 1)
        @Expect(markerName(parsed.diagram.edges[0].markerStart), "point")
        @Expect(markerName(parsed.diagram.edges[0].markerEnd), "point")
        let label = parsed.diagram.nodes[0].label
        @Expect(source[label.start..label.end], "Database")
    }

    @TestCase
    func parsesChainedEdgesAsMultipleEdges() {
        let parsed = FlowchartParser().parse("flowchart TD\nA-->B-->C")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 3)
        @Expect(parsed.diagram.edges.size, 2)
        @Expect(parsed.diagram.edges[0].source, "A")
        @Expect(parsed.diagram.edges[0].target, "B")
        @Expect(parsed.diagram.edges[1].source, "B")
        @Expect(parsed.diagram.edges[1].target, "C")
    }

    @TestCase
    func parsesMultipleTargetsWithAmpersand() {
        let parsed = FlowchartParser().parse("flowchart TD\nA --> B & C")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 3)
        @Expect(parsed.diagram.edges.size, 2)
        @Expect(parsed.diagram.edges[0].source, "A")
        @Expect(parsed.diagram.edges[0].target, "B")
        @Expect(parsed.diagram.edges[1].source, "A")
        @Expect(parsed.diagram.edges[1].target, "C")
    }

    @TestCase
    func migratesUpstreamVerticeChainingWithMiddleMultiNodeStatement() {
        let parsed = FlowchartParser().parse("""
graph TD
A --> B & B2 & C --> D2
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 5)
        @Expect(parsed.diagram.edges.size, 6)
        expectEdgeEndpoints(parsed.diagram.edges[0].source, parsed.diagram.edges[0].target, "A", "B")
        expectEdgeEndpoints(parsed.diagram.edges[1].source, parsed.diagram.edges[1].target, "A", "B2")
        expectEdgeEndpoints(parsed.diagram.edges[2].source, parsed.diagram.edges[2].target, "A", "C")
        expectEdgeEndpoints(parsed.diagram.edges[3].source, parsed.diagram.edges[3].target, "B", "D2")
        expectEdgeEndpoints(parsed.diagram.edges[4].source, parsed.diagram.edges[4].target, "B2", "D2")
        expectEdgeEndpoints(parsed.diagram.edges[5].source, parsed.diagram.edges[5].target, "C", "D2")
    }

    @TestCase
    func migratesUpstreamVerticeChainingWithExtraInfoAndInlineClass() {
        let source = """
graph TD
A[ h ] -- hello --> B[" test "]:::exClass & C --> D
classDef exClass background:#bbb,border:1px solid red
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.edges.size, 4)
        @Expect(parsed.diagram.nodeClasses.get("B").getOrThrow(), "exClass")
        @Expect(parsed.diagram.classStyles.get("exClass").getOrThrow().fill.getOrThrow(), "#bbb")
        @Expect(parsed.diagram.classStyles.get("exClass").getOrThrow().stroke.getOrThrow(), "red")
        for (i in 0..2) {
            let label = parsed.diagram.edges[i].label.getOrThrow()
            @Expect(parsed.diagram.source[label.start..label.end], "hello")
        }
        expectEdgeEndpoints(parsed.diagram.edges[0].source, parsed.diagram.edges[0].target, "A", "B")
        expectEdgeEndpoints(parsed.diagram.edges[1].source, parsed.diagram.edges[1].target, "A", "C")
        expectEdgeEndpoints(parsed.diagram.edges[2].source, parsed.diagram.edges[2].target, "B", "D")
        expectEdgeEndpoints(parsed.diagram.edges[3].source, parsed.diagram.edges[3].target, "C", "D")
    }

    @TestCase
    func parsesSubgraphMembershipForDagreGraphlibLayout() {
        let source = """
flowchart TB
subgraph A
  subgraph B [Inner]
    c
  end
  a --> c
end
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.subgraphDefs.size, 2)
        @Expect(parsed.diagram.subgraphDefs[0].id, "A")
        @Expect(parsed.diagram.subgraphDefs[0].parentId.isNone(), true)
        @Expect(parsed.diagram.subgraphDefs[1].id, "B")
        @Expect(parsed.diagram.subgraphDefs[1].parentId.getOrThrow(), "A")
        @Expect(source[parsed.diagram.subgraphDefs[1].title.start..parsed.diagram.subgraphDefs[1].title.end], "Inner")
        @Expect(parsed.diagram.nodeParents.get("a").getOrThrow(), "A")
        @Expect(parsed.diagram.nodeParents.get("c").getOrThrow(), "B")
        @Expect(parsed.diagram.edges.size, 1)
        @Expect(parsed.diagram.edges[0].source, "a")
        @Expect(parsed.diagram.edges[0].target, "c")
    }

    @TestCase
    func migratesUpstreamSubgraphDirectionParsing() {
        let parsed = FlowchartParser().parse("""
flowchart TB
subgraph A
  direction BT
  a --> b
end
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.subgraphDefs.size, 1)
        @Expect(parsed.diagram.subgraphDefs[0].id, "A")
        @Expect(directionName(parsed.diagram.subgraphDefs[0].dir.getOrThrow()), "BT")
        @Expect(parsed.diagram.subgraphDefs[0].explicitDir, true)
        @Expect(parsed.diagram.nodeParents.get("a").getOrThrow(), "A")
        @Expect(parsed.diagram.nodeParents.get("b").getOrThrow(), "A")
    }

    @TestCase
    func migratesUpstreamSubgraphTitleForms() {
        let quoted = FlowchartParser().parse("graph TD;subgraph \"title in quotes\";c-->d;end;")
        @Expect(quoted.diagnostics.isEmpty(), true)
        @Expect(quoted.diagram.subgraphDefs[0].id, "subGraph0")
        @Expect(quoted.diagram.source[quoted.diagram.subgraphDefs[0].title.start..quoted.diagram.subgraphDefs[0].title.end], "title in quotes")

        let bracket = FlowchartParser().parse("graph TD;subgraph uid1[text of doom];c-->d;end;")
        @Expect(bracket.diagnostics.isEmpty(), true)
        @Expect(bracket.diagram.subgraphDefs[0].id, "uid1")
        @Expect(bracket.diagram.source[bracket.diagram.subgraphDefs[0].title.start..bracket.diagram.subgraphDefs[0].title.end], "text of doom")

        let bracketQuoted = FlowchartParser().parse("graph TD;subgraph uid2[\"text of doom\"];c-->d;end;")
        @Expect(bracketQuoted.diagnostics.isEmpty(), true)
        @Expect(bracketQuoted.diagram.subgraphDefs[0].id, "uid2")
        @Expect(bracketQuoted.diagram.source[bracketQuoted.diagram.subgraphDefs[0].title.start..bracketQuoted.diagram.subgraphDefs[0].title.end], "text of doom")

        let oldStyle = FlowchartParser().parse("graph TD;subgraph old style that is broken;c-->d;end;")
        @Expect(oldStyle.diagnostics.isEmpty(), true)
        @Expect(oldStyle.diagram.source[oldStyle.diagram.subgraphDefs[0].title.start..oldStyle.diagram.subgraphDefs[0].title.end], "old style that is broken")
    }

    @TestCase
    func migratesUpstreamSubgraphIndentationIdsAndNestedMembership() {
        let tabIndented = FlowchartParser().parse("graph TB\nsubgraph One\n\ta1-->a2\nend")
        @Expect(tabIndented.diagnostics.isEmpty(), true)
        @Expect(tabIndented.diagram.subgraphDefs.size, 1)
        @Expect(tabIndented.diagram.subgraphDefs[0].id, "One")
        @Expect(tabIndented.diagram.source[tabIndented.diagram.subgraphDefs[0].title.start..tabIndented.diagram.subgraphDefs[0].title.end], "One")
        @Expect(tabIndented.diagram.nodeParents.get("a1").getOrThrow(), "One")
        @Expect(tabIndented.diagram.nodeParents.get("a2").getOrThrow(), "One")

        let numericId = FlowchartParser().parse("""
graph TD
A[Christmas] -->|Get money| B(Go shopping)
subgraph 1test
A
end
""")
        @Expect(numericId.diagnostics.isEmpty(), true)
        @Expect(numericId.diagram.subgraphDefs[0].id, "1test")
        @Expect(numericId.diagram.nodeParents.get("A").getOrThrow(), "1test")

        let nested = FlowchartParser().parse("""
flowchart TB
subgraph A
b-->B
a
end
a-->c
subgraph B
c
end
""")
        @Expect(nested.diagnostics.isEmpty(), true)
        @Expect(nested.diagram.subgraphDefs.size, 2)
        @Expect(nested.diagram.subgraphDefs[0].id, "A")
        @Expect(nested.diagram.subgraphDefs[1].id, "B")
        @Expect(nested.diagram.nodeParents.get("a").getOrThrow(), "A")
        @Expect(nested.diagram.nodeParents.get("b").getOrThrow(), "A")
        @Expect(nested.diagram.nodeParents.get("B").getOrThrow(), "A")
        @Expect(nested.diagram.nodeParents.get("c").getOrThrow(), "B")
    }

    @TestCase
    func migratesUpstreamNodeDataShapeAndLabelSyntax() {
        let source = """
flowchart TD
D@{ shape: rounded, label: "DD" } & E@{ shape: circle } --> F@{ shape: diamond }
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 3)
        @Expect(parsed.diagram.edges.size, 2)
        @Expect(parsed.diagram.edges[0].source, "D")
        @Expect(parsed.diagram.edges[0].target, "F")
        @Expect(styleShapeName(parsed.diagram.nodes[0].shape), "rounded")
        @Expect(styleShapeName(parsed.diagram.nodes[1].shape), "circle")
        @Expect(styleShapeName(parsed.diagram.nodes[2].shape), "diamond")
        @Expect(source[parsed.diagram.nodes[0].label.start..parsed.diagram.nodes[0].label.end], "DD")
    }

    @TestCase
    func migratesUpstreamMultilineNodeDataAfterEdge() {
        let source = """
flowchart TB
A --> D@{
  shape: circle
  other: "clock"
}
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 2)
        @Expect(parsed.diagram.edges.size, 1)
        @Expect(parsed.diagram.edges[0].source, "A")
        @Expect(parsed.diagram.edges[0].target, "D")
        @Expect(styleShapeName(parsed.diagram.nodes[1].shape), "circle")
        @Expect(source[parsed.diagram.nodes[1].label.start..parsed.diagram.nodes[1].label.end], "D")
    }

    @TestCase
    func migratesUpstreamMultilineNodeDataAfterMultiSourceEdge() {
        let source = """
flowchart TD
A@{ shape: rounded, label: "Start" } & B@{ shape: circle } --> C@{
  shape: diamond
  label: "Check
    result"
}
C -->|yes| D[(Database)]
C -->|no| E[[Retry]]
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 5)
        @Expect(parsed.diagram.edges.size, 4)
        @Expect(parsed.diagram.edges[0].source, "A")
        @Expect(parsed.diagram.edges[0].target, "C")
        @Expect(parsed.diagram.edges[1].source, "B")
        @Expect(parsed.diagram.edges[1].target, "C")
        @Expect(styleShapeName(parsed.diagram.nodes[0].shape), "rounded")
        @Expect(styleShapeName(parsed.diagram.nodes[1].shape), "circle")
        @Expect(styleShapeName(parsed.diagram.nodes[2].shape), "diamond")
        @Expect(parsed.diagram.nodes[2].labelText.getOrThrow(), "Check\nresult")
    }

    @TestCase
    func migratesUpstreamNodeDataAfterShapedNodeKeepsBaseLabel() {
        let source = """
flowchart TB
A[hello]
B@{
  shape: circle
  other: "clock"
}
C[Hello]@{
  shape: circle
  other: "clock"
}
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 3)
        @Expect(source[parsed.diagram.nodes[0].label.start..parsed.diagram.nodes[0].label.end], "hello")
        @Expect(styleShapeName(parsed.diagram.nodes[1].shape), "circle")
        @Expect(source[parsed.diagram.nodes[1].label.start..parsed.diagram.nodes[1].label.end], "B")
        @Expect(styleShapeName(parsed.diagram.nodes[2].shape), "circle")
        @Expect(source[parsed.diagram.nodes[2].label.start..parsed.diagram.nodes[2].label.end], "Hello")
    }

    @TestCase
    func migratesUpstreamNodeDataQuotedBraceAndAtInLabels() {
        let source = """
flowchart TB
A@{
  label: "This is a string with } and @"
  other: "clock"
}
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 1)
        @Expect(source[parsed.diagram.nodes[0].label.start..parsed.diagram.nodes[0].label.end], "This is a string with } and @")
    }

    @TestCase
    func migratesUpstreamNodeDataLabelsOnMultiNodeStatements() {
        let source = """
flowchart TD
n2["label for n2"] & n4@{ label: "label for n4"} & n5@{ label: "label for n5"}
A["A"] --> B["for B"] & C@{ label: "for c"} & E@{label : "for E"}
D@{label: "for D"}
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 8)
        @Expect(source[parsed.diagram.nodes[0].label.start..parsed.diagram.nodes[0].label.end], "label for n2")
        @Expect(source[parsed.diagram.nodes[1].label.start..parsed.diagram.nodes[1].label.end], "label for n4")
        @Expect(source[parsed.diagram.nodes[2].label.start..parsed.diagram.nodes[2].label.end], "label for n5")
        @Expect(source[parsed.diagram.nodes[3].label.start..parsed.diagram.nodes[3].label.end], "A")
        @Expect(source[parsed.diagram.nodes[4].label.start..parsed.diagram.nodes[4].label.end], "for B")
        @Expect(source[parsed.diagram.nodes[5].label.start..parsed.diagram.nodes[5].label.end], "for c")
        @Expect(source[parsed.diagram.nodes[6].label.start..parsed.diagram.nodes[6].label.end], "for E")
        @Expect(source[parsed.diagram.nodes[7].label.start..parsed.diagram.nodes[7].label.end], "for D")
        @Expect(parsed.diagram.edges.size, 3)
    }

    @TestCase
    func migratesUpstreamNodeDataInvalidShapeErrors() {
        let unknown = FlowchartParser().parse("""
flowchart TB
A@{ shape: this-shape-does-not-exist }
""")
        @Expect(unknown.diagnostics.isEmpty(), false)
        @Expect(unknown.diagnostics[0], "No such shape: this-shape-does-not-exist.")

        let internalOnly = FlowchartParser().parse("""
flowchart TB
A@{ shape: rect_left_inv_arrow }
""")
        @Expect(internalOnly.diagnostics.isEmpty(), false)
        @Expect(internalOnly.diagnostics[0], "No such shape: rect_left_inv_arrow. Shape names should be lowercase.")
    }

    @TestCase
    func migratesUpstreamNodeDataShapeAliasesForCommonRenderedShapes() {
        let source = """
flowchart TB
A@{ shape: proc }
B@{ shape: event }
C@{ shape: terminal }
D@{ shape: subproc }
E@{ shape: db }
F@{ shape: diam }
G@{ shape: hex }
H@{ shape: in-out }
I@{ shape: out-in }
J@{ shape: trapezoid }
K@{ shape: manual }
L@{ shape: double-circle }
M@{ shape: card }
N@{ shape: lined-process }
O@{ shape: start }
P@{ shape: stop }
Q@{ shape: junction }
R@{ shape: fork }
S@{ shape: doc }
T@{ shape: stacked-rectangle }
U@{ shape: divided-process }
V@{ shape: datastore }
W@{ shape: triangle }
X@{ shape: sloped-rectangle }
Y@{ shape: crossed-circle }
Z@{ shape: tagged-process }
AA@{ shape: tagged-document }
AB@{ shape: paper-tape }
AC@{ shape: hourglass }
AD@{ shape: notched-pentagon }
AE@{ shape: flipped-triangle }
AF@{ shape: delay }
AG@{ shape: curved-trapezoid }
AH@{ shape: window-pane }
AI@{ shape: lined-cylinder }
AJ@{ shape: horizontal-cylinder }
AK@{ shape: stacked-document }
AL@{ shape: lined-document }
AM@{ shape: bang }
AN@{ shape: cloud }
AO@{ shape: lightning-bolt }
AP@{ shape: bow-tie-rectangle }
AQ@{ shape: brace }
AR@{ shape: text }
AS@{ shape: small-triangle }
AT@{ shape: brace-r }
AU@{ shape: braces }
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(styleShapeName(parsed.diagram.nodes[0].shape), "rect")
        @Expect(styleShapeName(parsed.diagram.nodes[1].shape), "rounded")
        @Expect(styleShapeName(parsed.diagram.nodes[2].shape), "stadium")
        @Expect(styleShapeName(parsed.diagram.nodes[3].shape), "subroutine")
        @Expect(styleShapeName(parsed.diagram.nodes[4].shape), "cylinder")
        @Expect(styleShapeName(parsed.diagram.nodes[5].shape), "diamond")
        @Expect(styleShapeName(parsed.diagram.nodes[6].shape), "hexagon")
        @Expect(styleShapeName(parsed.diagram.nodes[7].shape), "lean-right")
        @Expect(styleShapeName(parsed.diagram.nodes[8].shape), "lean-left")
        @Expect(styleShapeName(parsed.diagram.nodes[9].shape), "trapezoid")
        @Expect(styleShapeName(parsed.diagram.nodes[10].shape), "inv-trapezoid")
        @Expect(styleShapeName(parsed.diagram.nodes[11].shape), "double-circle")
        @Expect(styleShapeName(parsed.diagram.nodes[12].shape), "card")
        @Expect(styleShapeName(parsed.diagram.nodes[13].shape), "lined-process")
        @Expect(styleShapeName(parsed.diagram.nodes[14].shape), "small-circle")
        @Expect(styleShapeName(parsed.diagram.nodes[15].shape), "framed-circle")
        @Expect(styleShapeName(parsed.diagram.nodes[16].shape), "filled-circle")
        @Expect(styleShapeName(parsed.diagram.nodes[17].shape), "fork")
        @Expect(styleShapeName(parsed.diagram.nodes[18].shape), "document")
        @Expect(styleShapeName(parsed.diagram.nodes[19].shape), "multi-process")
        @Expect(styleShapeName(parsed.diagram.nodes[20].shape), "divided-process")
        @Expect(styleShapeName(parsed.diagram.nodes[21].shape), "datastore")
        @Expect(styleShapeName(parsed.diagram.nodes[22].shape), "triangle")
        @Expect(styleShapeName(parsed.diagram.nodes[23].shape), "sloped-rectangle")
        @Expect(styleShapeName(parsed.diagram.nodes[24].shape), "crossed-circle")
        @Expect(styleShapeName(parsed.diagram.nodes[25].shape), "tagged-process")
        @Expect(styleShapeName(parsed.diagram.nodes[26].shape), "tagged-document")
        @Expect(styleShapeName(parsed.diagram.nodes[27].shape), "flag")
        @Expect(styleShapeName(parsed.diagram.nodes[28].shape), "hourglass")
        @Expect(styleShapeName(parsed.diagram.nodes[29].shape), "notched-pentagon")
        @Expect(styleShapeName(parsed.diagram.nodes[30].shape), "flipped-triangle")
        @Expect(styleShapeName(parsed.diagram.nodes[31].shape), "delay")
        @Expect(styleShapeName(parsed.diagram.nodes[32].shape), "curved-trapezoid")
        @Expect(styleShapeName(parsed.diagram.nodes[33].shape), "window-pane")
        @Expect(styleShapeName(parsed.diagram.nodes[34].shape), "lined-cylinder")
        @Expect(styleShapeName(parsed.diagram.nodes[35].shape), "horizontal-cylinder")
        @Expect(styleShapeName(parsed.diagram.nodes[36].shape), "multi-document")
        @Expect(styleShapeName(parsed.diagram.nodes[37].shape), "lined-document")
        @Expect(styleShapeName(parsed.diagram.nodes[38].shape), "bang")
        @Expect(styleShapeName(parsed.diagram.nodes[39].shape), "cloud")
        @Expect(styleShapeName(parsed.diagram.nodes[40].shape), "lightning-bolt")
        @Expect(styleShapeName(parsed.diagram.nodes[41].shape), "bow-tie-rectangle")
        @Expect(styleShapeName(parsed.diagram.nodes[42].shape), "brace")
        @Expect(styleShapeName(parsed.diagram.nodes[43].shape), "text")
        @Expect(styleShapeName(parsed.diagram.nodes[44].shape), "triangle")
        @Expect(styleShapeName(parsed.diagram.nodes[45].shape), "brace-r")
        @Expect(styleShapeName(parsed.diagram.nodes[46].shape), "braces")
    }

    @TestCase
    func migratesUpstreamOldShapeTextSyntaxForCommonStaticShapes() {
        let source = """
graph TD
A{{Hex text}}
B[/Trap text\\]
C[\\Inv trap text/]
D[/Lean right/]
E[\\Lean left\\]
F(((Double circle)))
G(-Ellipse text-)
H>Odd text]
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(styleShapeName(parsed.diagram.nodes[0].shape), "hexagon")
        @Expect(styleShapeName(parsed.diagram.nodes[1].shape), "trapezoid")
        @Expect(styleShapeName(parsed.diagram.nodes[2].shape), "inv-trapezoid")
        @Expect(styleShapeName(parsed.diagram.nodes[3].shape), "lean-right")
        @Expect(styleShapeName(parsed.diagram.nodes[4].shape), "lean-left")
        @Expect(styleShapeName(parsed.diagram.nodes[5].shape), "double-circle")
        @Expect(styleShapeName(parsed.diagram.nodes[6].shape), "ellipse")
        @Expect(styleShapeName(parsed.diagram.nodes[7].shape), "odd")
        @Expect(source[parsed.diagram.nodes[0].label.start..parsed.diagram.nodes[0].label.end], "Hex text")
        @Expect(source[parsed.diagram.nodes[3].label.start..parsed.diagram.nodes[3].label.end], "Lean right")
    }

    @TestCase
    func migratesUpstreamFlowTextStaticLabelsAndOldShapeText() {
        let edgeSlash = FlowchartParser().parse("graph TD;A--x|text with / should work|B;")
        @Expect(edgeSlash.diagnostics.isEmpty(), true)
        @Expect(markerName(edgeSlash.diagram.edges[0].markerEnd), "cross")
        let slashLabel = edgeSlash.diagram.edges[0].label.getOrThrow()
        @Expect(edgeSlash.diagram.source[slashLabel.start..slashLabel.end], "text with / should work")

        let unicode = FlowchartParser().parse("graph TD;A-->C(Начало);")
        @Expect(unicode.diagnostics.isEmpty(), true)
        let unicodeLabel = unicode.diagram.nodes[1].label
        @Expect(unicode.diagram.source[unicodeLabel.start..unicodeLabel.end], "Начало")

        let backslash = FlowchartParser().parse("graph TD;A-->C(c:\\windows);")
        @Expect(backslash.diagnostics.isEmpty(), true)
        let backslashLabel = backslash.diagram.nodes[1].label
        @Expect(backslash.diagram.source[backslashLabel.start..backslashLabel.end], "c:\\windows")

        let ellipse = FlowchartParser().parse("graph TD\nA(-this is an ellipse-)-->B")
        @Expect(ellipse.diagnostics.isEmpty(), true)
        @Expect(styleShapeName(ellipse.diagram.nodes[0].shape), "ellipse")
        @Expect(ellipse.diagram.source[ellipse.diagram.nodes[0].label.start..ellipse.diagram.nodes[0].label.end], "this is an ellipse")

        let odd = FlowchartParser().parse("graph TD;A_node-->odd->Vertex Text];")
        @Expect(odd.diagnostics.isEmpty(), true)
        @Expect(odd.diagram.nodes[1].id, "odd-")
        @Expect(styleShapeName(odd.diagram.nodes[1].shape), "odd")
        @Expect(odd.diagram.source[odd.diagram.nodes[1].label.start..odd.diagram.nodes[1].label.end], "Vertex Text")
    }

    @TestCase
    func migratesUpstreamNodeDataMultilineStringLabels() {
        let quoted = FlowchartParser().parse("""
flowchart TB
A@{
  label: "This is a
    multiline string"
  other: "clock"
}
""")
        @Expect(quoted.diagnostics.isEmpty(), true)
        @Expect(quoted.diagram.nodes[0].labelText.getOrThrow(), "This is a\nmultiline string")

        let block = FlowchartParser().parse("""
flowchart TB
A@{
  label: |
    This is a
    multiline string
  other: "clock"
}
""")
        @Expect(block.diagnostics.isEmpty(), true)
        @Expect(block.diagram.nodes[0].labelText.getOrThrow(), "This is a\nmultiline string\n")
    }

    @TestCase
    func migratesUpstreamMarkdownStringLabelsAsLabelTextWithoutBackticks() {
        let source = """
flowchart TD
A["`The cat in **the** hat`"] -- "`The *bat* in the chat`" --> B["The dog in the hog"]
C@{ label: "`Node **data** label`" }
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(source[parsed.diagram.nodes[0].label.start..parsed.diagram.nodes[0].label.end], "The cat in **the** hat")
        @Expect(source[parsed.diagram.nodes[1].label.start..parsed.diagram.nodes[1].label.end], "The dog in the hog")
        @Expect(source[parsed.diagram.nodes[2].label.start..parsed.diagram.nodes[2].label.end], "Node **data** label")
        @Expect(parsed.diagram.edges.size, 1)
        let edgeLabel = parsed.diagram.edges[0].label.getOrThrow()
        @Expect(source[edgeLabel.start..edgeLabel.end], "The *bat* in the chat")
    }

    @TestCase
    func migratesUpstreamMarkdownStringSubgraphTitlesWithoutBackticks() {
        let source = """
flowchart LR
subgraph "`**Two**`"
  c("`The **cat** in the hat`") -- "`1o **ipa**`" --> d("The dog in the hog")
end
"""
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.subgraphDefs.size, 1)
        let title = parsed.diagram.subgraphDefs[0].title
        @Expect(source[title.start..title.end], "**Two**")
        @Expect(source[parsed.diagram.nodes[0].label.start..parsed.diagram.nodes[0].label.end], "The **cat** in the hat")
        let edgeLabel = parsed.diagram.edges[0].label.getOrThrow()
        @Expect(source[edgeLabel.start..edgeLabel.end], "1o **ipa**")
    }

    @TestCase
    func migratesUpstreamUniqueEdgeCreationWithAtAndAmpersand() {
        let parsed = FlowchartParser().parse("""
flowchart TD
A & B e1@--> C & D
A1 e2@--> C1 & D1
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.edges.size, 6)
        @Expect(parsed.diagram.edges[0].id.isNone(), true)
        @Expect(parsed.diagram.edges[1].id.isNone(), true)
        @Expect(parsed.diagram.edges[2].id.getOrThrow(), "e1")
        @Expect(parsed.diagram.edges[3].id.isNone(), true)
        @Expect(parsed.diagram.edges[4].id.getOrThrow(), "e2")
        @Expect(parsed.diagram.edges[5].id.isNone(), true)
    }

    @TestCase
    func migratesUpstreamRedefinedEdgeIdsFallbackToGeneratedIds() {
        let parsed = FlowchartParser().parse("""
flowchart TD
A & B e1@--> C & D
A1 e1@--> C1 & D1
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.edges.size, 6)
        @Expect(parsed.diagram.edges[2].id.getOrThrow(), "e1")
        @Expect(parsed.diagram.edges[4].id.isNone(), true)
        @Expect(parsed.diagram.edges[5].id.isNone(), true)
    }

    @TestCase
    func migratesUpstreamFlowEdgesLengthMatrix() {
        expectEdgeLength("graph TD;\nA --- B;", 1, "normal", "none", "none", "")
        expectEdgeLength("graph TD;\nA ---- B;", 2, "normal", "none", "none", "")
        expectEdgeLength("graph TD;\nA ----- B;", 3, "normal", "none", "none", "")
        expectEdgeLength("graph TD;\nA --> B;", 1, "normal", "none", "point", "")
        expectEdgeLength("graph TD;\nA ---> B;", 2, "normal", "none", "point", "")
        expectEdgeLength("graph TD;\nA ----> B;", 3, "normal", "none", "point", "")
        expectEdgeLength("graph TD;\nA <--> B;", 1, "normal", "point", "point", "")
        expectEdgeLength("graph TD;\nA <---> B;", 2, "normal", "point", "point", "")
        expectEdgeLength("graph TD;\nA <----> B;", 3, "normal", "point", "point", "")

        expectEdgeLength("graph TD;\nA === B;", 1, "thick", "none", "none", "")
        expectEdgeLength("graph TD;\nA ==== B;", 2, "thick", "none", "none", "")
        expectEdgeLength("graph TD;\nA ===== B;", 3, "thick", "none", "none", "")
        expectEdgeLength("graph TD;\nA ==> B;", 1, "thick", "none", "point", "")
        expectEdgeLength("graph TD;\nA ===> B;", 2, "thick", "none", "point", "")
        expectEdgeLength("graph TD;\nA ====> B;", 3, "thick", "none", "point", "")
        expectEdgeLength("graph TD;\nA <==> B;", 1, "thick", "point", "point", "")
        expectEdgeLength("graph TD;\nA <===> B;", 2, "thick", "point", "point", "")
        expectEdgeLength("graph TD;\nA <====> B;", 3, "thick", "point", "point", "")

        expectEdgeLength("graph TD;\nA -.- B;", 1, "dotted", "none", "none", "")
        expectEdgeLength("graph TD;\nA -..- B;", 2, "dotted", "none", "none", "")
        expectEdgeLength("graph TD;\nA -...- B;", 3, "dotted", "none", "none", "")
        expectEdgeLength("graph TD;\nA -.-> B;", 1, "dotted", "none", "point", "")
        expectEdgeLength("graph TD;\nA -..-> B;", 2, "dotted", "none", "point", "")
        expectEdgeLength("graph TD;\nA -...-> B;", 3, "dotted", "none", "point", "")
        expectEdgeLength("graph TD;\nA <-.-> B;", 1, "dotted", "point", "point", "")
        expectEdgeLength("graph TD;\nA <-..-> B;", 2, "dotted", "point", "point", "")
        expectEdgeLength("graph TD;\nA <-...-> B;", 3, "dotted", "point", "point", "")
    }

    @TestCase
    func migratesUpstreamFlowEdgesLabelledLengthMatrix() {
        expectEdgeLength("graph TD;\nA -- Label --- B;", 1, "normal", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA -- Label ---- B;", 2, "normal", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA -- Label ----- B;", 3, "normal", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA -- Label --> B;", 1, "normal", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA -- Label ---> B;", 2, "normal", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA -- Label ----> B;", 3, "normal", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA <-- Label --> B;", 1, "normal", "point", "point", "Label")
        expectEdgeLength("graph TD;\nA <-- Label ---> B;", 2, "normal", "point", "point", "Label")
        expectEdgeLength("graph TD;\nA <-- Label ----> B;", 3, "normal", "point", "point", "Label")

        expectEdgeLength("graph TD;\nA == Label === B;", 1, "thick", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA == Label ==== B;", 2, "thick", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA == Label ===== B;", 3, "thick", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA == Label ==> B;", 1, "thick", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA == Label ===> B;", 2, "thick", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA == Label ====> B;", 3, "thick", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA <== Label ==> B;", 1, "thick", "point", "point", "Label")
        expectEdgeLength("graph TD;\nA <== Label ===> B;", 2, "thick", "point", "point", "Label")
        expectEdgeLength("graph TD;\nA <== Label ====> B;", 3, "thick", "point", "point", "Label")

        expectEdgeLength("graph TD;\nA -. Label .- B;", 1, "dotted", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA -. Label ..- B;", 2, "dotted", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA -. Label ...- B;", 3, "dotted", "none", "none", "Label")
        expectEdgeLength("graph TD;\nA -. Label .-> B;", 1, "dotted", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA -. Label ..-> B;", 2, "dotted", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA -. Label ...-> B;", 3, "dotted", "none", "point", "Label")
        expectEdgeLength("graph TD;\nA <-. Label .-> B;", 1, "dotted", "point", "point", "Label")
        expectEdgeLength("graph TD;\nA <-. Label ..-> B;", 2, "dotted", "point", "point", "Label")
        expectEdgeLength("graph TD;\nA <-. Label ...-> B;", 3, "dotted", "point", "point", "Label")
    }

    @TestCase
    func migratesUpstreamFlowEdgesIdsAndKeywordLabels() {
        let idEdge = FlowchartParser().parse("flowchart TD;\nA e1@x-- label --x B;")
        @Expect(idEdge.diagnostics.isEmpty(), true)
        @Expect(idEdge.diagram.edges.size, 1)
        @Expect(idEdge.diagram.edges[0].id.getOrThrow(), "e1")
        @Expect(markerName(idEdge.diagram.edges[0].markerStart), "cross")
        @Expect(markerName(idEdge.diagram.edges[0].markerEnd), "cross")
        @Expect(idEdge.diagram.edges[0].length, 1)
        let idLabel = idEdge.diagram.edges[0].label.getOrThrow()
        @Expect(idEdge.diagram.source[idLabel.start..idLabel.end], "label")

        for (keyword in ["graph", "flowchart", "style", "default", "linkStyle", "classDef", "class", "href", "call", "click", "end", "subgraph", "kitty"]) {
            let parsed = FlowchartParser().parse("graph TD;\nA <-- ${keyword} --> B;")
            @Expect(parsed.diagnostics.isEmpty(), true)
            @Expect(parsed.diagram.edges.size, 1)
            @Expect(parsed.diagram.edges[0].length, 1)
            @Expect(markerName(parsed.diagram.edges[0].markerStart), "point")
            @Expect(markerName(parsed.diagram.edges[0].markerEnd), "point")
            let label = parsed.diagram.edges[0].label.getOrThrow()
            @Expect(parsed.diagram.source[label.start..label.end], keyword)
        }
    }

    @TestCase
    func migratesUpstreamFlowEdgesIdCombinationsAndMultipleEdges() {
        expectEdgeIdMarkers("flowchart TD;\nA e1@----x B;", "e1", 3, "normal", "none", "cross")
        expectEdgeIdMarkers("flowchart TD;\nA e2@====o B;", "e2", 3, "thick", "none", "circle")
        expectEdgeIdMarkers("flowchart TD;\nA e3@-...-> B;", "e3", 3, "dotted", "none", "point")
        expectEdgeIdMarkers("flowchart TD;\nA e4@x== label ==x B;", "e4", 1, "thick", "cross", "cross")
        expectEdgeIdMarkers("flowchart TD;\nA e5@o-. label .-o B;", "e5", 1, "dotted", "circle", "circle")
        expectEdgeIdMarkers("flowchart TD;\nA e6@<-- label --> B;", "e6", 1, "normal", "point", "point")

        let parsed = FlowchartParser().parse("graph TD;A---|This is the 123 s text|B;\nA---|This is the second edge|B;")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.edges.size, 2)
        @Expect(parsed.diagram.edges[0].length, 1)
        @Expect(parsed.diagram.edges[1].length, 1)
        let first = parsed.diagram.edges[0].label.getOrThrow()
        let second = parsed.diagram.edges[1].label.getOrThrow()
        @Expect(parsed.diagram.source[first.start..first.end], "This is the 123 s text")
        @Expect(parsed.diagram.source[second.start..second.end], "This is the second edge")
    }

    private func expectEdgeLength(source: String, length: Int64, style: String, markerStart: String, markerEnd: String, labelText: String): Unit {
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.edges.size, 1)
        let edge = parsed.diagram.edges[0]
        @Expect(edge.source, "A")
        @Expect(edge.target, "B")
        @Expect(edge.length, length)
        @Expect(styleName(edge.style), style)
        @Expect(markerName(edge.markerStart), markerStart)
        @Expect(markerName(edge.markerEnd), markerEnd)
        if (labelText.isEmpty()) {
            @Expect(edge.label.isNone(), true)
        } else {
            let label = edge.label.getOrThrow()
            @Expect(parsed.diagram.source[label.start..label.end], labelText)
        }
    }

    private func expectEdgeIdMarkers(source: String, id: String, length: Int64, style: String, markerStart: String, markerEnd: String): Unit {
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.edges.size, 1)
        let edge = parsed.diagram.edges[0]
        @Expect(edge.id.getOrThrow(), id)
        @Expect(edge.length, length)
        @Expect(styleName(edge.style), style)
        @Expect(markerName(edge.markerStart), markerStart)
        @Expect(markerName(edge.markerEnd), markerEnd)
    }

    private func expectEdgeEndpoints(source: String, target: String, expectedSource: String, expectedTarget: String): Unit {
        @Expect(source, expectedSource)
        @Expect(target, expectedTarget)
    }

    private func hasNode(nodes: ArrayList<FlowNode>, id: String): Bool {
        for (node in nodes) {
            if (node.id == id) {
                return true
            }
        }
        return false
    }

    private func markerName(marker: FlowEdgeMarker): String {
        match (marker) {
            case FlowEdgeMarker.Point => return "point"
            case FlowEdgeMarker.Circle => return "circle"
            case FlowEdgeMarker.Cross => return "cross"
            case _ => return "none"
        }
    }

    private func directionName(direction: FlowDirection): String {
        match (direction) {
            case FlowDirection.LR => return "LR"
            case FlowDirection.RL => return "RL"
            case FlowDirection.BT => return "BT"
            case FlowDirection.TB => return "TB"
            case _ => return "TD"
        }
    }

    private func styleName(style: FlowEdgeStyle): String {
        match (style) {
            case FlowEdgeStyle.Thick => return "thick"
            case FlowEdgeStyle.Dotted => return "dotted"
            case _ => return "normal"
        }
    }

    private func styleShapeName(shape: FlowNodeShape): String {
        match (shape) {
            case FlowNodeShape.Rounded => return "rounded"
            case FlowNodeShape.Circle => return "circle"
            case FlowNodeShape.Diamond => return "diamond"
            case FlowNodeShape.Cylinder => return "cylinder"
            case FlowNodeShape.Stadium => return "stadium"
            case FlowNodeShape.Subroutine => return "subroutine"
            case FlowNodeShape.Datastore => return "datastore"
            case FlowNodeShape.Hexagon => return "hexagon"
            case FlowNodeShape.LeanRight => return "lean-right"
            case FlowNodeShape.LeanLeft => return "lean-left"
            case FlowNodeShape.Trapezoid => return "trapezoid"
            case FlowNodeShape.InvTrapezoid => return "inv-trapezoid"
            case FlowNodeShape.DoubleCircle => return "double-circle"
            case FlowNodeShape.Ellipse => return "ellipse"
            case FlowNodeShape.Odd => return "odd"
            case FlowNodeShape.Text => return "text"
            case FlowNodeShape.Card => return "card"
            case FlowNodeShape.ShadedProcess => return "lined-process"
            case FlowNodeShape.SmallCircle => return "small-circle"
            case FlowNodeShape.FramedCircle => return "framed-circle"
            case FlowNodeShape.FilledCircle => return "filled-circle"
            case FlowNodeShape.Fork => return "fork"
            case FlowNodeShape.Document => return "document"
            case FlowNodeShape.MultiProcess => return "multi-process"
            case FlowNodeShape.DividedProcess => return "divided-process"
            case FlowNodeShape.Triangle => return "triangle"
            case FlowNodeShape.SlopedRectangle => return "sloped-rectangle"
            case FlowNodeShape.CrossedCircle => return "crossed-circle"
            case FlowNodeShape.TaggedProcess => return "tagged-process"
            case FlowNodeShape.TaggedDocument => return "tagged-document"
            case FlowNodeShape.Flag => return "flag"
            case FlowNodeShape.Hourglass => return "hourglass"
            case FlowNodeShape.NotchedPentagon => return "notched-pentagon"
            case FlowNodeShape.FlippedTriangle => return "flipped-triangle"
            case FlowNodeShape.Delay => return "delay"
            case FlowNodeShape.CurvedTrapezoid => return "curved-trapezoid"
            case FlowNodeShape.WindowPane => return "window-pane"
            case FlowNodeShape.LinedCylinder => return "lined-cylinder"
            case FlowNodeShape.HorizontalCylinder => return "horizontal-cylinder"
            case FlowNodeShape.MultiDocument => return "multi-document"
            case FlowNodeShape.LinedDocument => return "lined-document"
            case FlowNodeShape.Bang => return "bang"
            case FlowNodeShape.Cloud => return "cloud"
            case FlowNodeShape.LightningBolt => return "lightning-bolt"
            case FlowNodeShape.BowTieRectangle => return "bow-tie-rectangle"
            case FlowNodeShape.CurlyBraceLeft => return "brace"
            case FlowNodeShape.CurlyBraceRight => return "brace-r"
            case FlowNodeShape.CurlyBraces => return "braces"
            case _ => return "rect"
        }
    }
}
