package mermaid4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.layout.dagre.{DagreEdge, DagreEdgeRef, DagreNode, DagrePoint, DagreSelfLoop, MermaidDagreGraph, adjustClustersAndEdges, buildFlowchartDagreGraph, cutPathAtIntersect, extractDescendants, getEdgesToRender, intersectCylinder, intersectEllipse, intersectPolygon, intersectRect, intersection, sortNodesByHierarchy, validate}
import mermaid4cj.parser.FlowchartParser

// Migrated from Mermaid upstream:
// packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.spec.js
@Test
@Tag[Mermaid4cj]
class MermaidDagreLayoutTests {
    @TestCase
    func createsOneCompactRenderEdgeFromSelfLoopLayoutSegments() {
        let graph = MermaidDagreGraph()
        graph.setNode("A", DagreNode("A", x: Some(10.0), y: Some(10.0), width: Some(20.0), height: Some(20.0)))

        let originalEdge = DagreEdge("A-A", "A", "A", label: Some("loop"), arrowTypeStart: Some("normal"), arrowTypeEnd: Some("normal"))
        let segment1 = DagreEdge(
            "A-cyclic-special-1",
            "A",
            "A",
            label: Some("loop"),
            arrowTypeStart: Some("normal"),
            arrowTypeEnd: Some("normal"),
            points: [DagrePoint(0.0, 0.0), DagrePoint(10.0, 0.0)],
            selfLoop: Some(DagreSelfLoop("A-A", 0)),
            originalEdge: Some(originalEdge)
        )
        let segmentMid = DagreEdge(
            "A-cyclic-special-mid",
            "A",
            "A",
            label: Some("loop"),
            arrowTypeStart: Some("normal"),
            arrowTypeEnd: Some("normal"),
            points: [DagrePoint(10.0, 0.0), DagrePoint(20.0, 10.0)],
            selfLoop: Some(DagreSelfLoop("A-A", 1)),
            originalEdge: Some(originalEdge)
        )
        let segment2 = DagreEdge(
            "A-cyclic-special-2",
            "A",
            "A",
            label: Some("loop"),
            arrowTypeStart: Some("normal"),
            arrowTypeEnd: Some("normal"),
            points: [DagrePoint(20.0, 10.0), DagrePoint(30.0, 10.0)],
            selfLoop: Some(DagreSelfLoop("A-A", 2)),
            originalEdge: Some(originalEdge)
        )

        graph.setNode("A---A---1", DagreNode("A---A---1"))
        graph.setNode("A---A---2", DagreNode("A---A---2"))
        graph.setEdge("A", "A---A---1", segment1, "A-cyclic-special-0")
        graph.setEdge("A---A---1", "A---A---2", segmentMid, "A-cyclic-special-1")
        graph.setEdge("A---A---2", "A", segment2, "A-cyclic-special-2")

        let edgesToRender = getEdgesToRender(graph)

        @Expect(edgesToRender.size, 1)
        @Expect(edgesToRender[0].edge.id, "A-A")
        @Expect(edgesToRender[0].edge.selfLoop.isNone(), true)
        expectPoints(edgesToRender[0].edge.points, [DagrePoint(-8.0, 0.0), DagrePoint(-8.0, -24.0), DagrePoint(28.0, -24.0), DagrePoint(28.0, 0.0)])
        @Expect(edgesToRender[0].edge.x.getOrThrow(), 10.0)
        @Expect(edgesToRender[0].edge.y.getOrThrow(), -28.0)
        @Expect(edgesToRender[0].edge.label.getOrThrow(), "loop")
    }

    @TestCase
    func placesCompactSelfLoopsOnTheSideChosenByTheLayout() {
        let graph = MermaidDagreGraph()
        graph.setNode("A", DagreNode("A", x: Some(10.0), y: Some(10.0), width: Some(20.0), height: Some(20.0)))
        graph.setNode("A---A---1", DagreNode("A---A---1", x: Some(80.0), y: Some(5.0)))
        graph.setNode("A---A---2", DagreNode("A---A---2", x: Some(80.0), y: Some(15.0)))

        let originalEdge = DagreEdge("A-A", "A", "A", label: Some("loop"), arrowTypeStart: Some("normal"), arrowTypeEnd: Some("normal"))
        let segment1 = DagreEdge("A-cyclic-special-1", "A", "A", label: Some("loop"), arrowTypeStart: Some("normal"), arrowTypeEnd: Some("normal"), selfLoop: Some(DagreSelfLoop("A-A", 0)), originalEdge: Some(originalEdge))
        let segmentMid = DagreEdge("A-cyclic-special-mid", "A", "A", label: Some("loop"), arrowTypeStart: Some("normal"), arrowTypeEnd: Some("normal"), selfLoop: Some(DagreSelfLoop("A-A", 1)), originalEdge: Some(originalEdge), width: Some(20.0), height: Some(10.0))
        let segment2 = DagreEdge("A-cyclic-special-2", "A", "A", label: Some("loop"), arrowTypeStart: Some("normal"), arrowTypeEnd: Some("normal"), selfLoop: Some(DagreSelfLoop("A-A", 2)), originalEdge: Some(originalEdge))

        graph.setEdge("A", "A---A---1", segment1, "A-cyclic-special-0")
        graph.setEdge("A---A---1", "A---A---2", segmentMid, "A-cyclic-special-1")
        graph.setEdge("A---A---2", "A", segment2, "A-cyclic-special-2")

        let edgesToRender = getEdgesToRender(graph)

        expectPoints(edgesToRender[0].edge.points, [DagrePoint(20.0, -8.0), DagrePoint(44.0, -8.0), DagrePoint(44.0, 28.0), DagrePoint(20.0, 28.0)])
        @Expect(edgesToRender[0].edge.x.getOrThrow(), 58.0)
        @Expect(edgesToRender[0].edge.y.getOrThrow(), 10.0)
    }

    @TestCase
    func keepsRegularEdgesUnchanged() {
        let graph = MermaidDagreGraph()
        graph.setNode("A", DagreNode("A"))
        graph.setNode("B", DagreNode("B"))
        let edge = DagreEdge("A-B", "A", "B", points: [DagrePoint(0.0, 0.0), DagrePoint(10.0, 10.0)])
        graph.setEdge("A", "B", edge, "A-B")

        let edgesToRender = getEdgesToRender(graph)

        @Expect(edgesToRender.size, 1)
        expectEdgeRef(edgesToRender[0], edge, "A", "B")
    }

    @TestCase
    func keepsSelfLoopLayoutSegmentsUnchangedWhenMergingIsDisabled() {
        let graph = MermaidDagreGraph()
        graph.setNode("A", DagreNode("A", x: Some(10.0), y: Some(10.0), width: Some(20.0), height: Some(20.0)))
        graph.setNode("A---A---1", DagreNode("A---A---1"))
        graph.setNode("A---A---2", DagreNode("A---A---2"))

        let originalEdge = DagreEdge("A-A", "A", "A", label: Some("loop"))
        let segment1 = DagreEdge("A-cyclic-special-1", "A", "A", label: Some("loop"), selfLoop: Some(DagreSelfLoop("A-A", 0)), originalEdge: Some(originalEdge))
        let segmentMid = DagreEdge("A-cyclic-special-mid", "A", "A", label: Some("loop"), selfLoop: Some(DagreSelfLoop("A-A", 1)), originalEdge: Some(originalEdge))
        let segment2 = DagreEdge("A-cyclic-special-2", "A", "A", label: Some("loop"), selfLoop: Some(DagreSelfLoop("A-A", 2)), originalEdge: Some(originalEdge))

        graph.setEdge("A", "A---A---1", segment1, "A-cyclic-special-0")
        graph.setEdge("A---A---1", "A---A---2", segmentMid, "A-cyclic-special-1")
        graph.setEdge("A---A---2", "A", segment2, "A-cyclic-special-2")

        let edgesToRender = getEdgesToRender(graph, mergeSelfLoops: false)

        @Expect(edgesToRender.size, 3)
        expectEdgeRef(edgesToRender[0], segment1, "A", "A---A---1")
        expectEdgeRef(edgesToRender[1], segmentMid, "A---A---1", "A---A---2")
        expectEdgeRef(edgesToRender[2], segment2, "A---A---2", "A")
    }

    private func expectEdgeRef(actual: DagreEdgeRef, edge: DagreEdge, start: String, end: String): Unit {
        @Expect(actual.edge.id, edge.id)
        @Expect(actual.start, start)
        @Expect(actual.end, end)
    }

    private func expectPoints(actual: Array<DagrePoint>, expected: Array<DagrePoint>): Unit {
        @Expect(actual.size, expected.size)
        for (i in 0..expected.size) {
            @Expect(actual[i].x, expected[i].x)
            @Expect(actual[i].y, expected[i].y)
        }
    }
}

// Migrated from Mermaid upstream:
// packages/mermaid/src/dagre-wrapper/edges.spec.js
@Test
@Tag[Mermaid4cj]
class MermaidDagreGeometryTests {
    @TestCase
    func intersectionCase1LeftEdgeOfBox() {
        let node = DagreNode("node", x: Some(171.0), y: Some(100.0), width: Some(210.0), height: Some(184.0))
        let actual = intersection(node, DagrePoint(31.0, 143.2257070163421), DagrePoint(99.3359375, 100.0))
        expectClose(actual.x, 66.0)
        expectClose(actual.y, 122.139, tolerance: 0.001)
    }

    @TestCase
    func intersectionCase2LeftEdgeOfBox() {
        let node = DagreNode("node", x: Some(100.23046875), y: Some(176.75), width: Some(184.4609375), height: Some(337.5))
        let actual = intersection(node, DagrePoint(310.2578125, 169.88002060631462), DagrePoint(127.96875, 100.0))
        expectClose(actual.x, 192.4609375)
        expectClose(actual.y, 145.15711441743503)
    }

    @TestCase
    func intersectionCase3TopOfBoxOutsidePointGreaterThanInsidePoint() {
        let node = DagreNode("node", x: Some(114.0), y: Some(164.0), width: Some(212.0), height: Some(176.0))
        let actual = intersection(node, DagrePoint(157.0, 39.0), DagrePoint(104.0, 105.0))
        expectClose(actual.x, 133.71, tolerance: 0.01)
        expectClose(actual.y, 76.0)
    }

    @TestCase
    func intersectionCase4TopOfBoxInsidePointGreaterThanInsidePoint() {
        let node = DagreNode("node", x: Some(114.0), y: Some(164.0), width: Some(212.0), height: Some(176.0))
        let actual = intersection(node, DagrePoint(144.0, 38.0), DagrePoint(198.0, 105.0))
        expectClose(actual.x, 174.626, tolerance: 0.001)
        expectClose(actual.y, 76.0)
    }

    @TestCase
    func intersectRectMatchesDagreWrapperRectBoundary() {
        let node = DagreNode("node", x: Some(100.0), y: Some(100.0), width: Some(80.0), height: Some(40.0))
        let right = intersectRect(node, DagrePoint(200.0, 100.0))
        let top = intersectRect(node, DagrePoint(100.0, 0.0))
        expectClose(right.x, 140.0)
        expectClose(right.y, 100.0)
        expectClose(top.x, 100.0)
        expectClose(top.y, 80.0)
    }

    @TestCase
    func intersectEllipseMatchesOfficialDagreWrapperFormula() {
        let node = DagreNode("circle", x: Some(100.0), y: Some(80.0), width: Some(80.0), height: Some(40.0))
        let actual = intersectEllipse(node, 40.0, 20.0, DagrePoint(200.0, 20.0))

        expectClose(actual.x, 125.6073759865792)
        expectClose(actual.y, 64.63557440805249)
    }

    @TestCase
    func intersectCylinderAdjustsRectIntersectionToOfficialEllipseSurface() {
        let node = DagreNode("database", x: Some(100.0), y: Some(100.0), width: Some(80.0), height: Some(70.0))
        let rect = intersectRect(node, DagrePoint(160.0, 20.0))
        let actual = intersectCylinder(node, DagrePoint(160.0, 20.0))

        expectClose(rect.x, 126.25)
        expectClose(rect.y, 65.0)
        expectClose(actual.x, 126.25)
        expectClose(actual.y, 67.39469727582339)
    }

    @TestCase
    func intersectPolygonChoosesNearestBoundaryPointToEdgeEnd() {
        let node = DagreNode("diamond", x: Some(100.0), y: Some(100.0), width: Some(80.0), height: Some(80.0))
        let diamond = [DagrePoint(40.0, 0.0), DagrePoint(80.0, 40.0), DagrePoint(40.0, 80.0), DagrePoint(0.0, 40.0)]
        let actual = intersectPolygon(node, diamond, DagrePoint(200.0, 100.0))
        expectClose(actual.x, 140.5)
        expectClose(actual.y, 100.5)
    }

    @TestCase
    func cutPathAtIntersectStopsPathOnBoundaryLikeDagreWrapper() {
        let node = DagreNode("node", x: Some(100.0), y: Some(100.0), width: Some(80.0), height: Some(40.0))
        let cut = cutPathAtIntersect([DagrePoint(200.0, 100.0), DagrePoint(120.0, 100.0), DagrePoint(100.0, 100.0)], node)
        @Expect(cut.size, 1)
        expectClose(cut[0].x, 140.0)
        expectClose(cut[0].y, 100.0)
    }

    private func expectClose(actual: Float64, expected: Float64, tolerance!: Float64 = 0.000001): Unit {
        @Expect(absTest(actual - expected) <= tolerance, true)
    }

    private func absTest(value: Float64): Float64 {
        if (value < 0.0) {
            return -value
        }
        return value
    }
}

// Migrated from Mermaid upstream:
// packages/mermaid/src/rendering-util/layout-algorithms/dagre/mermaid-graphlib.spec.js
@Test
@Tag[Mermaid4cj]
class MermaidGraphlibTests {
    @TestCase
    func graphlibCoreQueriesMatchDagreGraphSemantics() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setEdge("a", "b", DagreEdge("a-b", "a", "b"), "ab")
        graph.setEdge("a", "c", DagreEdge("a-c", "a", "c"), "ac")
        graph.setEdge("b", "c", DagreEdge("b-c", "b", "c"), "bc")

        @Expect(graph.hasNode("a"), true)
        @Expect(graph.hasNode("missing"), false)
        @Expect(graph.hasEdge("a", "b", "ab"), true)
        @Expect(graph.hasEdge("a", "b", "missing"), false)
        expectStrings(graph.predecessors("c"), ["a", "b"])
        expectStrings(graph.successors("a"), ["b", "c"])
        expectStrings(graph.neighbors("b"), ["a", "c"])
        @Expect(graph.inEdges("c").size, 2)
        @Expect(graph.outEdges("a").size, 2)
        @Expect(graph.nodeEdges("b").size, 2)
        expectStrings(graph.sources(), ["a"])
        expectStrings(graph.sinks(), ["c"])
    }

    @TestCase
    func graphlibSetEdgeReplacesSameNamedEdge() {
        let graph = MermaidDagreGraph()
        graph.setEdge("a", "b", DagreEdge("old", "a", "b"), "same")
        graph.setEdge("a", "b", DagreEdge("new", "a", "b"), "same")

        @Expect(graph.edges().size, 1)
        @Expect(graph.edge("a", "b", "same").getOrThrow().id, "new")
    }

    @TestCase
    func graphlibGraphConfigStoresDagreLayoutSpacingFields() {
        let graph = MermaidDagreGraph().setGraph(
            rankdir: Some("LR"),
            nodesep: Some(50.0),
            ranksep: Some(80.0),
            marginx: Some(8.0),
            marginy: Some(12.0)
        )

        @Expect(graph.rankdir().getOrThrow(), "LR")
        @Expect(graph.nodesep().getOrThrow(), 50.0)
        @Expect(graph.ranksep().getOrThrow(), 80.0)
        @Expect(graph.marginx().getOrThrow(), 8.0)
        @Expect(graph.marginy().getOrThrow(), 12.0)
    }

    @TestCase
    func validateDetectsEdgesBetweenClusters() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setParent("a", "C1")
        graph.setParent("b", "C1")
        graph.setParent("c", "C2")
        graph.setEdge("a", "b", DagreEdge("a-b", "a", "b"), "a-b")
        graph.setEdge("C1", "C2", DagreEdge("C1-C2", "C1", "C2"), "C1-C2")

        @Expect(validate(graph), false)
    }

    @TestCase
    func validateDoesNotDetectEdgesBetweenClustersAfterAdjustment() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setParent("a", "C1")
        graph.setParent("b", "C1")
        graph.setParent("c", "C2")
        graph.setEdge("a", "b", DagreEdge("a-b", "a", "b"), "a-b")
        graph.setEdge("C1", "C2", DagreEdge("C1-C2", "C1", "C2"), "C1-C2")

        adjustClustersAndEdges(graph)

        @Expect(validate(graph), true)
    }

    @TestCase
    func adjustClustersAndEdgesExtractsSingleChildCluster() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("C1", DagreNode("C1"))
        graph.setParent("a", "C1")
        graph.setEdge("C1", "b", DagreEdge("link1", "C1", "b"), "1")

        adjustClustersAndEdges(graph)

        expectStrings(graph.nodes(), ["b", "C1"])
        @Expect(graph.edges().size, 1)
        @Expect(validate(graph), true)
        let cluster = graph.node("C1").getOrThrow()
        @Expect(cluster.clusterNode, true)
        expectStrings(cluster.graph.getOrThrow().nodes(), ["a"])
    }

    @TestCase
    func adjustClustersAndEdgesPreservesMultipleExternalEdges() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setNode("C1", DagreNode("C1"))
        graph.setParent("a", "C1")
        graph.setEdge("C1", "b", DagreEdge("link1", "C1", "b"), "1")
        graph.setEdge("C1", "c", DagreEdge("link2", "C1", "c"), "2")

        adjustClustersAndEdges(graph)

        expectStrings(graph.nodes(), ["b", "c", "C1"])
        @Expect(graph.edges().size, 2)
        @Expect(graph.edges()[1].edge.id, "link2")
        @Expect(validate(graph), true)
        expectStrings(graph.node("C1").getOrThrow().graph.getOrThrow().nodes(), ["a"])
    }

    @TestCase
    func adjustClustersAndEdgesExtractsSiblingClusters() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setParent("a", "A")
        graph.setParent("b", "B")
        graph.setParent("c", "C")
        graph.setEdge("A", "B", DagreEdge("link1", "A", "B"), "1")
        graph.setEdge("A", "C", DagreEdge("link2", "A", "C"), "2")

        adjustClustersAndEdges(graph)

        expectStrings(graph.nodes(), ["A", "B", "C"])
        @Expect(graph.edges().size, 2)
        @Expect(graph.edges()[1].edge.id, "link2")
        @Expect(validate(graph), true)
        expectStrings(graph.node("C").getOrThrow().graph.getOrThrow().nodes(), ["c"])
    }

    @TestCase
    func adjustClustersAndEdgesExtractsNestedGraphsWithCorrectData() {
        let graph = MermaidDagreGraph()
        graph.setNode("C", DagreNode("C"))
        graph.setNode("D", DagreNode("D"))
        graph.setNode("d", DagreNode("d"))
        graph.setParent("d", "D")
        graph.setParent("D", "C")

        adjustClustersAndEdges(graph)

        let cGraph = graph.node("C").getOrThrow().graph.getOrThrow()
        let dGraph = cGraph.node("D").getOrThrow().graph.getOrThrow()
        expectStrings(cGraph.nodes(), ["D"])
        expectStrings(dGraph.nodes(), ["d"])
        expectStrings(graph.nodes(), ["C"])
    }

    @TestCase
    func adjustClustersAndEdgesExtractsNestedSiblingGraphsWithLinks() {
        let graph = MermaidDagreGraph()
        graph.setNode("C", DagreNode("C"))
        graph.setNode("D", DagreNode("D"))
        graph.setNode("d", DagreNode("d"))
        graph.setNode("B", DagreNode("B"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("A", DagreNode("A"))
        graph.setNode("a", DagreNode("a"))
        graph.setParent("a", "A")
        graph.setParent("b", "B")
        graph.setParent("d", "D")
        graph.setParent("D", "C")
        graph.setEdge("A", "B", DagreEdge("link1", "A", "B"), "1")
        graph.setEdge("A", "C", DagreEdge("link2", "A", "C"), "2")

        adjustClustersAndEdges(graph)

        expectStrings(graph.nodes(), ["C", "B", "A"])
        @Expect(graph.edges().size, 2)
        let aGraph = graph.node("A").getOrThrow().graph.getOrThrow()
        let bGraph = graph.node("B").getOrThrow().graph.getOrThrow()
        let cGraph = graph.node("C").getOrThrow().graph.getOrThrow()
        let dGraph = cGraph.node("D").getOrThrow().graph.getOrThrow()
        expectStrings(aGraph.nodes(), ["a"])
        expectStrings(bGraph.nodes(), ["b"])
        expectStrings(cGraph.nodes(), ["D"])
        expectStrings(dGraph.nodes(), ["d"])
        @Expect(aGraph.edges().size, 0)
        @Expect(bGraph.edges().size, 0)
        @Expect(cGraph.edges().size, 0)
        @Expect(dGraph.edges().size, 0)
    }

    @TestCase
    func adjustClustersAndEdgesKeepsInternalClusterLinks() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setNode("d", DagreNode("d"))
        graph.setNode("e", DagreNode("e"))
        graph.setParent("c", "b")
        graph.setParent("d", "b")
        graph.setParent("e", "b")
        graph.setEdge("a", "b", DagreEdge("link1", "a", "b"), "1")
        graph.setEdge("c", "d", DagreEdge("link2", "c", "d"), "2")
        graph.setEdge("d", "e", DagreEdge("link3", "d", "e"), "3")

        adjustClustersAndEdges(graph)

        let bGraph = graph.node("b").getOrThrow().graph.getOrThrow()
        @Expect(bGraph.nodes().size, 3)
        @Expect(bGraph.edges().size, 2)
        expectStrings(bGraph.nodes(), ["c", "d", "e"])
    }

    @TestCase
    func adjustClustersAndEdgesExtractsDeepStateLikeNesting() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setNode("e", DagreNode("e"))
        graph.setParent("b", "a")
        graph.setParent("c", "b")
        graph.setParent("e", "c")

        adjustClustersAndEdges(graph)

        let aGraph = graph.node("a").getOrThrow().graph.getOrThrow()
        let bGraph = aGraph.node("b").getOrThrow().graph.getOrThrow()
        let cGraph = bGraph.node("c").getOrThrow().graph.getOrThrow()
        @Expect(aGraph.nodes().size, 1)
        @Expect(bGraph.nodes().size, 1)
        @Expect(cGraph.nodes().size, 1)
        @Expect(bGraph.edges().size, 0)
        expectStrings(cGraph.nodes(), ["e"])
    }

    @TestCase
    func explicitDirectionClusterWithExternalConnectionBecomesClusterNode() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("C1", DagreNode("C1", dir: Some("LR"), explicitDir: true))
        graph.setParent("a", "C1")
        graph.setEdge("C1", "b", DagreEdge("link1", "C1", "b"), "1")

        adjustClustersAndEdges(graph)

        let cluster = graph.node("C1").getOrThrow()
        @Expect(cluster.clusterNode, true)
        expectStrings(cluster.graph.getOrThrow().nodes(), ["a"])
        expectStrings(graph.nodes(), ["b", "C1"])
    }

    @TestCase
    func explicitDirectionClusterWithoutExternalConnectionsBecomesClusterNode() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("C1", DagreNode("C1", dir: Some("LR"), explicitDir: true))
        graph.setParent("a", "C1")
        graph.setParent("b", "C1")
        graph.setEdge("a", "b", DagreEdge("internal", "a", "b"), "1")

        adjustClustersAndEdges(graph)

        let clusterGraph = graph.node("C1").getOrThrow().graph.getOrThrow()
        @Expect(graph.node("C1").getOrThrow().clusterNode, true)
        expectStrings(clusterGraph.nodes(), ["a", "b"])
        @Expect(clusterGraph.edges().size, 1)
        expectStrings(graph.nodes(), ["C1"])
    }

    @TestCase
    func explicitDirectionSiblingClustersWithInterClusterEdgeBecomeClusterNodes() {
        let graph = MermaidDagreGraph()
        graph.setNode("i1", DagreNode("i1"))
        graph.setNode("i2", DagreNode("i2"))
        graph.setNode("B1", DagreNode("B1", dir: Some("RL"), explicitDir: true))
        graph.setNode("B2", DagreNode("B2", dir: Some("BT"), explicitDir: true))
        graph.setParent("i1", "B1")
        graph.setParent("i2", "B2")
        graph.setEdge("B1", "B2", DagreEdge("sibling-link", "B1", "B2"), "1")

        adjustClustersAndEdges(graph)

        @Expect(graph.node("B1").getOrThrow().clusterNode, true)
        @Expect(graph.node("B2").getOrThrow().clusterNode, true)
        expectStrings(graph.node("B1").getOrThrow().graph.getOrThrow().nodes(), ["i1"])
        expectStrings(graph.node("B2").getOrThrow().graph.getOrThrow().nodes(), ["i2"])
    }

    @TestCase
    func explicitDirectionCrossBoundaryEdgeRebindsInOuterGraph() {
        let graph = MermaidDagreGraph()
        graph.setNode("D1", DagreNode("D1"))
        graph.setNode("D2", DagreNode("D2"))
        graph.setNode("C2", DagreNode("C2", dir: Some("LR"), explicitDir: true))
        graph.setParent("D1", "C2")
        graph.setEdge("D1", "D2", DagreEdge("cross", "D1", "D2"), "cross1")

        adjustClustersAndEdges(graph)

        let cluster = graph.node("C2").getOrThrow()
        @Expect(cluster.clusterNode, true)
        expectStrings(cluster.graph.getOrThrow().nodes(), ["D1"])
        @Expect(cluster.graph.getOrThrow().edges().size, 0)
        @Expect(hasEdge(graph, "C2", "D2"), true)
    }

    @TestCase
    func adjustClustersAndEdgesHandlesNestedParentingLikeGlb77() {
        let graph = MermaidDagreGraph()
        graph.setNode("A", DagreNode("A"))
        graph.setNode("B", DagreNode("B"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setNode("a", DagreNode("a"))
        graph.setParent("B", "A")
        graph.setParent("b", "A")
        graph.setParent("c", "B")
        graph.setParent("a", "A")
        graph.setEdge("b", "B", DagreEdge("L-b-B", "b", "B"), "1")
        graph.setEdge("a", "c", DagreEdge("L-a-c", "a", "c"), "2")

        adjustClustersAndEdges(graph)

        let aGraph = graph.node("A").getOrThrow().graph.getOrThrow()
        @Expect(aGraph.parent("c").getOrThrow(), "B")
        @Expect(aGraph.parent("B").isNone(), true)
    }

    @TestCase
    func buildsAdjustedDagreGraphFromParsedFlowchartSubgraphs() {
        let parsed = FlowchartParser().parse("""
flowchart TB
subgraph A
  direction RL
  subgraph B
    direction LR
    c
  end
  a --> c
end
""")
        @Expect(parsed.diagnostics.isEmpty(), true)

        let graph = buildFlowchartDagreGraph(parsed.diagram)

        let aGraph = graph.node("A").getOrThrow().graph.getOrThrow()
        let bGraph = aGraph.node("B").getOrThrow().graph.getOrThrow()
        @Expect(graph.rankdir().getOrThrow(), "TB")
        @Expect(graph.node("A").getOrThrow().clusterNode, true)
        @Expect(aGraph.rankdir().getOrThrow(), "RL")
        @Expect(aGraph.parent("B").isNone(), true)
        @Expect(aGraph.node("B").getOrThrow().clusterNode, true)
        @Expect(bGraph.rankdir().getOrThrow(), "LR")
        expectStrings(bGraph.nodes(), ["c"])
    }

    @TestCase
    func buildFlowchartDagreGraphExpandsSelfLoopsLikeUpstreamRenderPath() {
        let parsed = FlowchartParser().parse("""
flowchart TB
C --> C
""")
        @Expect(parsed.diagnostics.isEmpty(), true)

        let graph = buildFlowchartDagreGraph(parsed.diagram)

        @Expect(graph.node("C---C---1").isSome(), true)
        @Expect(graph.node("C---C---2").isSome(), true)
        @Expect(graph.edges().size, 3)
        @Expect(graph.edges()[0].edge.selfLoop.getOrThrow().order, 0)
        @Expect(graph.edges()[1].edge.selfLoop.getOrThrow().order, 1)
        @Expect(graph.edges()[2].edge.selfLoop.getOrThrow().order, 2)
        let renderEdges = getEdgesToRender(graph)
        @Expect(renderEdges.size, 1)
        @Expect(renderEdges[0].edge.id, "L_C_C")
        @Expect(renderEdges[0].edge.selfLoop.isNone(), true)
    }

    @TestCase
    func buildFlowchartDagreGraphKeepsSelfLoopDummyNodesInsideParentCluster() {
        let parsed = FlowchartParser().parse("""
flowchart TB
subgraph A
  C --> C
end
""")
        @Expect(parsed.diagnostics.isEmpty(), true)

        let graph = buildFlowchartDagreGraph(parsed.diagram)
        let clusterGraph = graph.node("A").getOrThrow().graph.getOrThrow()

        @Expect(clusterGraph.node("C---C---1").isSome(), true)
        @Expect(clusterGraph.node("C---C---2").isSome(), true)
        @Expect(clusterGraph.parent("C---C---1").isNone(), true)
        @Expect(clusterGraph.parent("C---C---2").isNone(), true)
        @Expect(getEdgesToRender(clusterGraph).size, 1)
    }

    @TestCase
    func buildFlowchartDagreGraphPreservesParsedEdgeLengthForLayoutMinlen() {
        let parsed = FlowchartParser().parse("""
flowchart TB
A ----> B
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.edges[0].length, 3)

        let graph = buildFlowchartDagreGraph(parsed.diagram)

        @Expect(graph.edges().size, 1)
        @Expect(graph.edges()[0].edge.length, 3)
    }

    @TestCase
    func extractsOneLevelDescendants() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setNode("c", DagreNode("c"))
        graph.setParent("a", "A")
        graph.setParent("b", "B")
        graph.setParent("c", "C")
        graph.setEdge("A", "B", DagreEdge("1", "A", "B"), "1")
        graph.setEdge("A", "C", DagreEdge("2", "A", "C"), "2")

        expectStrings(extractDescendants("A", graph), ["a"])
        expectStrings(extractDescendants("B", graph), ["b"])
        expectStrings(extractDescendants("C", graph), ["c"])
    }

    @TestCase
    func sortsHierarchyWhenNodesAreInReverseOrder() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setNode("b", DagreNode("b"))
        graph.setParent("b", "B")
        graph.setParent("B", "A")
        graph.setEdge("a", "b", DagreEdge("1", "a", "b"), "1")

        expectStrings(sortNodesByHierarchy(graph), ["a", "A", "B", "b"])
    }

    @TestCase
    func sortsHierarchyWhenNodesAreInCorrectOrder() {
        let graph = MermaidDagreGraph()
        graph.setNode("a", DagreNode("a"))
        graph.setParent("B", "A")
        graph.setParent("b", "B")
        graph.setNode("b", DagreNode("b"))
        graph.setEdge("a", "b", DagreEdge("1", "a", "b"), "1")

        expectStrings(sortNodesByHierarchy(graph), ["a", "A", "B", "b"])
    }

    private func expectStrings(actual: Array<String>, expected: Array<String>): Unit {
        @Expect(actual.size, expected.size)
        for (i in 0..expected.size) {
            @Expect(actual[i], expected[i])
        }
    }

    private func hasEdge(graph: MermaidDagreGraph, start: String, end: String): Bool {
        for (edge in graph.edges()) {
            if (edge.start == start && edge.end == end) {
                return true
            }
        }
        return false
    }
}
