package mermaid4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.layout.dagre.{
    DagreGraphLabel,
    DagreLayoutEdge,
    DagreLayoutGraph,
    DagreLayoutNode,
    dagreAcyclicRun,
    dagreAcyclicUndo,
    dagreAddBorderSegments,
    dagreAssignRankMinMax,
    dagreBuildLayerMatrix,
    dagreEnterEdge,
    dagreFeasibleTree,
    dagreInjectEdgeLabelProxies,
    dagreInsertSelfEdges,
    dagreInitCutValues,
    dagreInitLowLimValues,
    dagreLeaveEdge,
    dagreLongestPath,
    dagreNetworkSimplex,
    dagreNormalizeRun,
    dagreNormalizeUndo,
    dagreNormalizeRanks,
    dagreInitOrder,
    dagreCrossCount,
    dagreAdjustCoordinateSystem,
    dagreOrder,
    dagrePosition,
    dagrePositionSelfEdges,
    dagreRank,
    dagreRemoveBorderNodes,
    dagreRemoveEdgeLabelProxies,
    dagreRemoveSelfEdges,
    dagreSlack,
    dagreSimplify,
    dagreUndoCoordinateSystem
}

@Test
@Tag[Mermaid4cj]
class MermaidDagreCoreTests {
    @TestCase
    func migratesDagreRankUtilLongestPathAndSlack() {
        let graph = DagreLayoutGraph()
        graph.setNode("a", node: DagreLayoutNode("a"))
        graph.setNode("b", node: DagreLayoutNode("b"))
        graph.setNode("c", node: DagreLayoutNode("c"))
        graph.setEdge("a", "b", edge: DagreLayoutEdge("ab", minlen: 1), name: "ab")
        graph.setEdge("b", "c", edge: DagreLayoutEdge("bc", minlen: 2), name: "bc")

        dagreLongestPath(graph)

        @Expect(graph.node("c").getOrThrow().rank, Some(0))
        @Expect(graph.node("b").getOrThrow().rank, Some(-2))
        @Expect(graph.node("a").getOrThrow().rank, Some(-3))
        @Expect(dagreSlack(graph, graph.edges()[0]), 0)
    }

    @TestCase
    func migratesDagreUtilNormalizeRanksAndBuildLayerMatrix() {
        let graph = DagreLayoutGraph(label: DagreGraphLabel())
        graph.setNode("a", node: DagreLayoutNode("a"))
        graph.setNode("b", node: DagreLayoutNode("b"))
        graph.setNode("c", node: DagreLayoutNode("c"))
        graph.node("a").getOrThrow().rank = Some(-1)
        graph.node("a").getOrThrow().order = Some(1)
        graph.node("b").getOrThrow().rank = Some(-1)
        graph.node("b").getOrThrow().order = Some(0)
        graph.node("c").getOrThrow().rank = Some(0)
        graph.node("c").getOrThrow().order = Some(0)

        dagreNormalizeRanks(graph)
        let layers = dagreBuildLayerMatrix(graph)

        @Expect(layers.size, 2)
        @Expect(layers[0][0], "b")
        @Expect(layers[0][1], "a")
        @Expect(layers[1][0], "c")
    }

    @TestCase
    func migratesDagreUtilSimplifyAggregatesMultiEdges() {
        let graph = DagreLayoutGraph()
        graph.setEdge("a", "b", edge: DagreLayoutEdge("one", minlen: 1, weight: 2.0), name: "one")
        graph.setEdge("a", "b", edge: DagreLayoutEdge("two", minlen: 3, weight: 5.0), name: "two")

        let simplified = dagreSimplify(graph)
        let edge = simplified.edge("a", "b").getOrThrow()

        @Expect(simplified.edges().size, 1)
        @Expect(edge.minlen, 3)
        @Expect(edge.weight, 7.0)
    }

    @TestCase
    func migratesDagreFeasibleTreeAndNetworkSimplexInternals() {
        // Mirrors dagre-d3-es/src/dagre/rank/{feasible-tree,network-simplex}.js
        let graph = DagreLayoutGraph()
        graph.setEdge("a", "b", edge: DagreLayoutEdge("ab", minlen: 1, weight: 1.0))
        graph.setEdge("a", "c", edge: DagreLayoutEdge("ac", minlen: 1, weight: 3.0))
        graph.setEdge("b", "d", edge: DagreLayoutEdge("bd", minlen: 1, weight: 1.0))
        graph.setEdge("c", "d", edge: DagreLayoutEdge("cd", minlen: 1, weight: 1.0))
        graph.setEdge("a", "d", edge: DagreLayoutEdge("ad", minlen: 2, weight: 5.0))

        dagreLongestPath(graph)
        let tree = dagreFeasibleTree(graph)
        dagreInitLowLimValues(tree)
        dagreInitCutValues(tree, graph)
        let leaving = dagreLeaveEdge(tree).getOrThrow()
        let entering = dagreEnterEdge(tree, graph, leaving).getOrThrow()

        @Expect(graph.node("a").getOrThrow().rank, Some(-2))
        @Expect(graph.node("b").getOrThrow().rank, Some(-1))
        @Expect(graph.node("c").getOrThrow().rank, Some(-1))
        @Expect(graph.node("d").getOrThrow().rank, Some(0))
        @Expect(tree.nodes().size, 4)
        @Expect(tree.edges().size, 3)
        @Expect(tree.node("a").getOrThrow().low, Some(1))
        @Expect(tree.node("a").getOrThrow().lim, Some(4))
        @Expect(tree.node("c").getOrThrow().parent, Some("d"))
        @Expect(tree.edge("a", "b").getOrThrow().cutvalue, Some(9.0))
        @Expect(tree.edge("b", "d").getOrThrow().cutvalue, Some(9.0))
        @Expect(tree.edge("c", "d").getOrThrow().cutvalue, Some(-2.0))
        @Expect(leaving.start, "c")
        @Expect(leaving.end, "d")
        @Expect(entering.start, "a")
        @Expect(entering.end, "c")
    }

    @TestCase
    func migratesDagreNetworkSimplexRankerOutput() {
        // Official expected ranks from dagre-d3-es/src/dagre/rank/network-simplex.js.
        let graph = DagreLayoutGraph()
        graph.setEdge("a", "b", edge: DagreLayoutEdge("ab", minlen: 1, weight: 1.0), name: "ab")
        graph.setEdge("b", "c", edge: DagreLayoutEdge("bc", minlen: 1, weight: 1.0), name: "bc")
        graph.setEdge("a", "c", edge: DagreLayoutEdge("ac", minlen: 1, weight: 10.0), name: "ac")
        graph.setEdge("c", "d", edge: DagreLayoutEdge("cd", minlen: 1, weight: 1.0), name: "cd")
        graph.setEdge("b", "d", edge: DagreLayoutEdge("bd", minlen: 1, weight: 10.0), name: "bd")

        dagreNetworkSimplex(graph)

        @Expect(graph.node("a").getOrThrow().rank, Some(-3))
        @Expect(graph.node("b").getOrThrow().rank, Some(-2))
        @Expect(graph.node("c").getOrThrow().rank, Some(-1))
        @Expect(graph.node("d").getOrThrow().rank, Some(0))
    }

    @TestCase
    func migratesDagreRankerDispatchDefaultsToNetworkSimplex() {
        let graph = DagreLayoutGraph(label: DagreGraphLabel())
        graph.setEdge("a", "b", edge: DagreLayoutEdge("ab", minlen: 1, weight: 1.0), name: "ab")
        graph.setEdge("b", "c", edge: DagreLayoutEdge("bc", minlen: 1, weight: 1.0), name: "bc")
        graph.setEdge("a", "c", edge: DagreLayoutEdge("ac", minlen: 1, weight: 10.0), name: "ac")

        dagreRank(graph)

        @Expect(graph.node("a").getOrThrow().rank, Some(-2))
        @Expect(graph.node("b").getOrThrow().rank, Some(-1))
        @Expect(graph.node("c").getOrThrow().rank, Some(0))
    }

    @TestCase
    func migratesDagreNormalizeRunAndUndoDummyChain() {
        // Mirrors dagre-d3-es/src/dagre/normalize.js run/undo behavior.
        let graph = DagreLayoutGraph()
        graph.setNode("a", node: DagreLayoutNode("a"))
        graph.setNode("d", node: DagreLayoutNode("d"))
        graph.node("a").getOrThrow().rank = Some(0)
        graph.node("d").getOrThrow().rank = Some(3)
        let edge = DagreLayoutEdge("ad", minlen: 1, weight: 7.0, width: 30.0, height: 12.0, labelpos: "l")
        edge.labelRank = Some(2)
        graph.setEdge("a", "d", edge: edge)

        dagreNormalizeRun(graph)

        @Expect(graph.hasEdge("a", "d"), false)
        @Expect(graph.graphLabel.dummyChains.size, 1)
        @Expect(graph.graphLabel.dummyChains[0], "_d1")
        @Expect(graph.node("_d1").getOrThrow().rank, Some(1))
        @Expect(graph.node("_d1").getOrThrow().dummy, Some("edge"))
        @Expect(graph.node("_d2").getOrThrow().rank, Some(2))
        @Expect(graph.node("_d2").getOrThrow().dummy, Some("edge-label"))
        @Expect(graph.node("_d2").getOrThrow().width, 30.0)
        @Expect(graph.node("_d2").getOrThrow().height, 12.0)
        @Expect(graph.hasEdge("a", "_d1", name: "a->d"), true)
        @Expect(graph.hasEdge("_d1", "_d2", name: "a->d"), true)
        @Expect(graph.hasEdge("_d2", "d", name: "a->d"), true)

        graph.node("_d1").getOrThrow().x = 10.0
        graph.node("_d1").getOrThrow().y = 20.0
        graph.node("_d2").getOrThrow().x = 30.0
        graph.node("_d2").getOrThrow().y = 40.0
        dagreNormalizeUndo(graph)

        let restored = graph.edge("a", "d").getOrThrow()
        @Expect(graph.hasNode("_d1"), false)
        @Expect(graph.hasNode("_d2"), false)
        @Expect(restored.points.size, 2)
        @Expect(restored.points[0].x, 10.0)
        @Expect(restored.points[1].y, 40.0)
        @Expect(restored.x, Some(30.0))
        @Expect(restored.y, Some(40.0))
        @Expect(restored.width, 30.0)
        @Expect(restored.height, 12.0)
    }

    @TestCase
    func migratesDagreInitOrderDepthFirstLayering() {
        // Mirrors dagre-d3-es/src/dagre/order/init-order.js DFS ordering.
        let graph = DagreLayoutGraph()
        for (id in ["a", "b", "c", "d", "e"]) {
            graph.setNode(id, node: DagreLayoutNode(id))
        }
        graph.node("a").getOrThrow().rank = Some(0)
        graph.node("b").getOrThrow().rank = Some(0)
        graph.node("c").getOrThrow().rank = Some(1)
        graph.node("d").getOrThrow().rank = Some(1)
        graph.node("e").getOrThrow().rank = Some(2)
        graph.setEdge("a", "d", edge: DagreLayoutEdge("ad"))
        graph.setEdge("b", "c", edge: DagreLayoutEdge("bc"))
        graph.setEdge("d", "e", edge: DagreLayoutEdge("de"))
        graph.setEdge("c", "e", edge: DagreLayoutEdge("ce"))

        let layers = dagreInitOrder(graph)

        @Expect(layers.size, 3)
        @Expect(layers[0][0], "a")
        @Expect(layers[0][1], "b")
        @Expect(layers[1][0], "d")
        @Expect(layers[1][1], "c")
        @Expect(layers[2][0], "e")
    }

    @TestCase
    func migratesDagreCrossCountWeightedBilayerCount() {
        // Mirrors dagre-d3-es/src/dagre/order/cross-count.js weighted crossings.
        let graph = DagreLayoutGraph()
        graph.setEdge("a", "d", edge: DagreLayoutEdge("ad", weight: 2.0))
        graph.setEdge("b", "c", edge: DagreLayoutEdge("bc", weight: 3.0))
        let layering = [["a", "b"], ["c", "d"]]

        @Expect(dagreCrossCount(graph, layering), 6.0)
    }

    @TestCase
    func migratesDagreAcyclicDfsRunAndUndo() {
        // Mirrors dagre-d3-es/src/dagre/acyclic.js default dfsFAS behavior.
        let graph = DagreLayoutGraph()
        graph.setEdge("a", "b", edge: DagreLayoutEdge("ab", weight: 1.0), name: "ab")
        graph.setEdge("b", "c", edge: DagreLayoutEdge("bc", weight: 1.0), name: "bc")
        graph.setEdge("c", "a", edge: DagreLayoutEdge("ca", weight: 1.0), name: "ca")

        dagreAcyclicRun(graph)

        @Expect(graph.hasEdge("c", "a", name: "ca"), false)
        @Expect(graph.hasEdge("a", "c", name: "rev0"), true)
        let reversed = graph.edge("a", "c", name: "rev0").getOrThrow()
        @Expect(reversed.reversed, true)
        @Expect(reversed.forwardName, Some("ca"))

        dagreAcyclicUndo(graph)

        @Expect(graph.hasEdge("a", "c", name: "rev0"), false)
        @Expect(graph.hasEdge("c", "a", name: "ca"), true)
        let restored = graph.edge("c", "a", name: "ca").getOrThrow()
        @Expect(restored.reversed, false)
        @Expect(restored.forwardName.isNone(), true)
    }

    @TestCase
    func migratesDagreAcyclicGreedyFeedbackArcSet() {
        // Official greedy-fas.js picks c->a for this weighted cycle.
        let graph = DagreLayoutGraph(label: DagreGraphLabel(acyclicer: Some("greedy")))
        graph.setEdge("a", "b", edge: DagreLayoutEdge("ab", weight: 5.0), name: "ab")
        graph.setEdge("b", "c", edge: DagreLayoutEdge("bc", weight: 1.0), name: "bc")
        graph.setEdge("c", "a", edge: DagreLayoutEdge("ca", weight: 1.0), name: "ca")

        dagreAcyclicRun(graph)

        @Expect(graph.hasEdge("c", "a", name: "ca"), false)
        @Expect(graph.hasEdge("a", "c", name: "rev0"), true)
        @Expect(graph.edge("a", "c", name: "rev0").getOrThrow().forwardName, Some("ca"))

        dagreAcyclicUndo(graph)

        @Expect(graph.hasEdge("c", "a", name: "ca"), true)
        @Expect(graph.edge("c", "a", name: "ca").getOrThrow().reversed, false)
    }

    @TestCase
    func migratesDagreEdgeLabelProxyRankCapture() {
        // Mirrors dagre-d3-es/src/dagre/layout.js inject/remove edge label proxies.
        let graph = DagreLayoutGraph()
        graph.setNode("a", node: DagreLayoutNode("a"))
        graph.setNode("b", node: DagreLayoutNode("b"))
        graph.node("a").getOrThrow().rank = Some(0)
        graph.node("b").getOrThrow().rank = Some(4)
        graph.setEdge("a", "b", edge: DagreLayoutEdge("ab", width: 48.0, height: 24.0), name: "ab")

        dagreInjectEdgeLabelProxies(graph)

        @Expect(graph.hasNode("_ep1"), true)
        @Expect(graph.node("_ep1").getOrThrow().dummy, Some("edge-proxy"))
        @Expect(graph.node("_ep1").getOrThrow().rank, Some(2))

        dagreRemoveEdgeLabelProxies(graph)

        @Expect(graph.hasNode("_ep1"), false)
        @Expect(graph.edge("a", "b", name: "ab").getOrThrow().labelRank, Some(2))
    }

    @TestCase
    func migratesDagreSelfEdgeRemoveInsertAndPosition() {
        // Mirrors dagre-d3-es/src/dagre/layout.js removeSelfEdges/insertSelfEdges/positionSelfEdges.
        let graph = DagreLayoutGraph()
        graph.setNode("a", node: DagreLayoutNode("a", x: 10.0, y: 20.0, width: 30.0, height: 40.0))
        graph.node("a").getOrThrow().rank = Some(0)
        graph.node("a").getOrThrow().order = Some(0)
        graph.setEdge("a", "a", edge: DagreLayoutEdge("aa", width: 24.0, height: 12.0), name: "aa")

        dagreRemoveSelfEdges(graph)

        @Expect(graph.hasEdge("a", "a", name: "aa"), false)
        @Expect(graph.node("a").getOrThrow().selfEdges.size, 1)

        dagreInsertSelfEdges(graph)

        @Expect(graph.hasNode("_se1"), true)
        @Expect(graph.node("_se1").getOrThrow().dummy, Some("selfedge"))
        @Expect(graph.node("_se1").getOrThrow().rank, Some(0))
        @Expect(graph.node("_se1").getOrThrow().order, Some(1))
        @Expect(graph.node("a").getOrThrow().selfEdges.size, 0)

        graph.node("_se1").getOrThrow().x = 70.0
        graph.node("_se1").getOrThrow().y = 20.0
        dagrePositionSelfEdges(graph)

        @Expect(graph.hasNode("_se1"), false)
        @Expect(graph.hasEdge("a", "a", name: "aa"), true)
        let edge = graph.edge("a", "a", name: "aa").getOrThrow()
        @Expect(edge.points.size, 5)
        @Expect(edge.points[0].x, 55.0)
        @Expect(edge.points[0].y, 0.0)
        @Expect(edge.points[2].x, 70.0)
        @Expect(edge.points[2].y, 20.0)
        @Expect(edge.points[4].x, 55.0)
        @Expect(edge.points[4].y, 40.0)
        @Expect(edge.x, Some(70.0))
        @Expect(edge.y, Some(20.0))
    }

    @TestCase
    func migratesDagreClusterBorderRankSegmentsAndRemoval() {
        // Mirrors dagre-d3-es/src/dagre/layout.js assignRankMinMax/removeBorderNodes
        // and src/dagre/add-border-segments.js.
        let graph = DagreLayoutGraph()
        graph.setNode("sg", node: DagreLayoutNode("sg"))
        graph.setNode("_bt", node: DagreLayoutNode("_bt", x: 70.0, y: 10.0))
        graph.setNode("_bb", node: DagreLayoutNode("_bb", x: 70.0, y: 90.0))
        graph.node("_bt").getOrThrow().rank = Some(0)
        graph.node("_bb").getOrThrow().rank = Some(2)
        graph.node("_bt").getOrThrow().dummy = Some("border")
        graph.node("_bb").getOrThrow().dummy = Some("border")
        graph.node("sg").getOrThrow().borderTop = Some("_bt")
        graph.node("sg").getOrThrow().borderBottom = Some("_bb")
        graph.setParent("_bt", "sg")
        graph.setParent("_bb", "sg")

        dagreAssignRankMinMax(graph)
        dagreAddBorderSegments(graph)

        let sg = graph.node("sg").getOrThrow()
        @Expect(sg.minRank, Some(0))
        @Expect(sg.maxRank, Some(2))
        @Expect(graph.graphLabel.maxRank, 2)
        @Expect(sg.borderLeft.size, 3)
        @Expect(sg.borderRight.size, 3)
        @Expect(graph.node(sg.borderLeft[1]).getOrThrow().dummy, Some("border"))
        @Expect(graph.node(sg.borderLeft[1]).getOrThrow().borderType, Some("borderLeft"))
        @Expect(graph.hasEdge(sg.borderLeft[0], sg.borderLeft[1]), true)
        @Expect(graph.hasEdge(sg.borderRight[1], sg.borderRight[2]), true)

        graph.node(sg.borderLeft[2]).getOrThrow().x = 20.0
        graph.node(sg.borderRight[2]).getOrThrow().x = 120.0
        dagreRemoveBorderNodes(graph)

        @Expect(graph.hasNode("_bt"), false)
        @Expect(graph.hasNode(sg.borderLeft[2]), false)
        @Expect(sg.width, 100.0)
        @Expect(sg.height, 80.0)
        @Expect(sg.x, 70.0)
        @Expect(sg.y, 50.0)
    }

    @TestCase
    func migratesDagreOrderSweepToReduceCrossings() {
        // Official dagre-d3-es/order places d before c for this crossing case.
        let graph = DagreLayoutGraph()
        for (id in ["a", "b", "c", "d"]) {
            graph.setNode(id, node: DagreLayoutNode(id, width: 40.0, height: 20.0))
        }
        graph.node("a").getOrThrow().rank = Some(0)
        graph.node("b").getOrThrow().rank = Some(0)
        graph.node("c").getOrThrow().rank = Some(1)
        graph.node("d").getOrThrow().rank = Some(1)
        graph.setEdge("a", "d", edge: DagreLayoutEdge("ad", weight: 1.0), name: "ad")
        graph.setEdge("b", "c", edge: DagreLayoutEdge("bc", weight: 1.0), name: "bc")

        dagreOrder(graph)

        @Expect(graph.node("a").getOrThrow().order, Some(0))
        @Expect(graph.node("b").getOrThrow().order, Some(1))
        @Expect(graph.node("d").getOrThrow().order, Some(0))
        @Expect(graph.node("c").getOrThrow().order, Some(1))
    }

    @TestCase
    func migratesDagrePositionBkAndCoordinateSystemForLr() {
        // Official dagre-d3-es position + coordinate-system gives a(20,0), b(120,0).
        let graph = DagreLayoutGraph(label: DagreGraphLabel(rankdir: "LR"))
        graph.setNode("a", node: DagreLayoutNode("a", width: 40.0, height: 20.0))
        graph.setNode("b", node: DagreLayoutNode("b", width: 60.0, height: 30.0))
        graph.node("a").getOrThrow().rank = Some(0)
        graph.node("a").getOrThrow().order = Some(0)
        graph.node("b").getOrThrow().rank = Some(1)
        graph.node("b").getOrThrow().order = Some(0)
        graph.setEdge("a", "b", edge: DagreLayoutEdge("ab", weight: 1.0), name: "ab")

        dagreAdjustCoordinateSystem(graph)
        dagrePosition(graph)
        dagreUndoCoordinateSystem(graph)

        @Expect(graph.node("a").getOrThrow().x, 20.0)
        @Expect(graph.node("a").getOrThrow().y, 0.0)
        @Expect(graph.node("b").getOrThrow().x, 120.0)
        @Expect(graph.node("b").getOrThrow().y, 0.0)
        @Expect(graph.node("a").getOrThrow().width, 40.0)
        @Expect(graph.node("b").getOrThrow().height, 30.0)
    }
}
