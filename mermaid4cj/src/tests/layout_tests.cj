package mermaid4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.layout.{FlowchartLayout, FlowchartLayoutResult, LayoutNode}
import mermaid4cj.parser.FlowchartParser

@Test
@Tag[Mermaid4cj]
class MermaidLayoutTests {
    @TestCase
    func doubleEndedEdgeDirectionWinsOverOppositeRegularEdge() {
        let parsed = FlowchartParser().parse("""
flowchart TD
    A([Start]) -->|Plan| B{Choose path}
    B -- Build --> C[[Implement]]
    B -. optional .-> D[(Cache)]
    C ==> E[Review]
    D --o E
    E --x F([Done])
    E <--> D""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let layout = FlowchartLayout().layout(parsed.diagram)
        @Expect(layout.nodes.size, parsed.diagram.nodes.size)
        @Expect(layout.edges.size, parsed.diagram.edges.size)
        @Expect(layout.width > 0.0, true)
        @Expect(layout.height > 0.0, true)
        @Expect(findNodeX(layout, "A") >= 0.0, true)
        @Expect(findNodeY(layout, "F") >= 0.0, true)
    }

    @TestCase
    func diamondEdgesUseShapeBoundaryIntersection() {
        let parsed = FlowchartParser().parse("""
flowchart TD
    A{Choose path}
    A --> B[Left branch]
    A --> C[Right branch]""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let layout = FlowchartLayout().layout(parsed.diagram)
        var checked = 0
        for (edge in layout.edges) {
            if (edge.source == "A") {
                let diamond = findNode(layout, "A")
                let bottomCenterX = diamond.x + diamond.width / 2.0
                let bottomCenterY = diamond.y + diamond.height
                @Expect(edge.x1 == bottomCenterX && edge.y1 == bottomCenterY, false)
                checked++
            }
        }
        @Expect(checked, 2)
    }

    @TestCase
    func multiSourceNodeDataLayoutDoesNotOverlapTopRankAndFitsMultilineDiamond() {
        let parsed = FlowchartParser().parse("""
flowchart TD
A@{ shape: rounded, label: "Start" } & B@{ shape: circle } --> C@{
  shape: diamond
  label: "Check
    result"
}
C -->|yes| D[(Database)]
C -->|no| E[[Retry]]
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let layout = FlowchartLayout().layout(parsed.diagram)
        let a = findNode(layout, "A")
        let b = findNode(layout, "B")
        let c = findNode(layout, "C")
        @Expect(a.x + a.width < b.x || b.x + b.width < a.x, true)
        @Expect(c.height >= 96.0, true)
    }

    @TestCase
    func labeledHorizontalEdgesReserveSpaceBetweenRanks() {
        let parsed = FlowchartParser().parse("""
flowchart LR
API[API] -. optional .-> Cache[(Cache)]
API ==> Worker[[Worker]]
Worker --o Queue((Queue))
Queue --x Error[Error]
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let layout = FlowchartLayout().layout(parsed.diagram)
        let api = findNode(layout, "API")
        let cache = findNode(layout, "Cache")
        @Expect(cache.x - (api.x + api.width) >= 80.0, true)
    }

    @TestCase
    func rectangleFanoutEdgesStartOnSourceBoundary() {
        let parsed = FlowchartParser().parse("""
flowchart LR
D[增量解析会话] --> E[稳定内容]
D --> F[未完成内容]
E --> G[HTML]
E --> H[JSON / AST]
E --> I[Markdown / Typst]
F --> J[实时预览状态]
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let layout = FlowchartLayout().layout(parsed.diagram)
        let stable = findNode(layout, "E")
        var checked = 0
        for (edge in layout.edges) {
            if (edge.source == "E") {
                @Expect(pointInsideRect(edge.x1, edge.y1, stable), true)
                @Expect(pointOnRectBoundary(edge.x1, edge.y1, stable), true)
                @Expect(edge.points.size > 2, true)
                checked++
            }
        }
        @Expect(checked, 3)
    }

    @TestCase
    func upstreamEdgeLengthExpandsDagreRanksInRenderedLayout() {
        let parsed = FlowchartParser().parse("""
flowchart TD
A --> B
A ----> C
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.edges[0].length, 1)
        @Expect(parsed.diagram.edges[1].length, 3)
        let layout = FlowchartLayout().layout(parsed.diagram)
        let a = findNode(layout, "A")
        let b = findNode(layout, "B")
        let c = findNode(layout, "C")
        @Expect(c.y - a.y > b.y - a.y + 40.0, true)
        for (edge in layout.edges) {
            if (edge.source == "A" && edge.target == "C") {
                @Expect(edge.points.size >= 4, true)
                return
            }
        }
        @Fail("missing long edge")
    }

    @TestCase
    func layoutKeepsOuterNodeStrokesInsideViewBoxPadding() {
        let horizontal = FlowchartParser().parse("flowchart LR\nA[Markdown 源文件] --> B[HTML]")
        @Expect(horizontal.diagnostics.isEmpty(), true)
        let horizontalLayout = FlowchartLayout().layout(horizontal.diagram)
        @Expect(minNodeX(horizontalLayout) >= 8.0, true)

        let vertical = FlowchartParser().parse("flowchart TD\nA[Markdown 源文件] --> B[HTML]")
        @Expect(vertical.diagnostics.isEmpty(), true)
        let verticalLayout = FlowchartLayout().layout(vertical.diagram)
        @Expect(minNodeY(verticalLayout) >= 8.0, true)
    }

    private func findNodeX(layout: FlowchartLayoutResult, id: String): Float64 {
        for (node in layout.nodes) {
            if (node.id == id) {
                return node.x
            }
        }
        @Fail("missing layout node")
        return 0.0
    }

    private func findNodeY(layout: FlowchartLayoutResult, id: String): Float64 {
        for (node in layout.nodes) {
            if (node.id == id) {
                return node.y
            }
        }
        @Fail("missing layout node")
        return 0.0
    }

    private func findNode(layout: FlowchartLayoutResult, id: String): LayoutNode {
        for (node in layout.nodes) {
            if (node.id == id) {
                return node
            }
        }
        @Fail("missing layout node")
        return layout.nodes[0]
    }

    private func minNodeX(layout: FlowchartLayoutResult): Float64 {
        var value = layout.nodes[0].x
        for (node in layout.nodes) {
            value = min(value, node.x)
        }
        return value
    }

    private func minNodeY(layout: FlowchartLayoutResult): Float64 {
        var value = layout.nodes[0].y
        for (node in layout.nodes) {
            value = min(value, node.y)
        }
        return value
    }

    private func pointInsideRect(x: Float64, y: Float64, node: LayoutNode): Bool {
        return x >= node.x && x <= node.x + node.width && y >= node.y && y <= node.y + node.height
    }

    private func pointOnRectBoundary(x: Float64, y: Float64, node: LayoutNode): Bool {
        let epsilon = 0.000001
        return absFloat(x - node.x) <= epsilon ||
            absFloat(x - (node.x + node.width)) <= epsilon ||
            absFloat(y - node.y) <= epsilon ||
            absFloat(y - (node.y + node.height)) <= epsilon
    }

    private func absFloat(value: Float64): Float64 {
        if (value < 0.0) {
            return -value
        }
        return value
    }
}
