package mermaid4cj.tests

import std.fs.{Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.{MermaidHtmlOptions, MermaidRenderOptions, MermaidRenderer, MindmapNodeShape}
import mermaid4cj.layout.{MindmapLayout, MindmapLayoutNode}

@Test
@Tag[Mermaid4cj]
class MermaidMindmapTests {
    @TestCase
    func migratesUpstreamMindmapOutlineShapesIconAndClasses() {
        let parsed = MermaidRenderer().parseMindmap("""
mindmap
  root((mindmap))
    Origins
      Long history
      ::icon(fa fa-book)
      Popularisation
    Research
      id[I am a square]
      id2(I am rounded)
      id3{{I am hexagon}}
      :::urgent large
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size, 8)
        @Expect(parsed.diagram.nodes[0].label, "mindmap")
        @Expect(shapeName(parsed.diagram.nodes[0].shape), "Circle")
        @Expect(parsed.diagram.nodes[2].parentIndex, 1)
        @Expect(parsed.diagram.nodes[2].icon, "fa fa-book")
        @Expect(shapeName(parsed.diagram.nodes[5].shape), "Square")
        @Expect(shapeName(parsed.diagram.nodes[6].shape), "Rounded")
        @Expect(shapeName(parsed.diagram.nodes[7].shape), "Hexagon")
        @Expect(parsed.diagram.nodes[7].className, "urgent large")
    }

    @TestCase
    func rendersDedicatedMindmapSvgHtmlAndFile() {
        let source = """
mindmap
  root((Docs))
    API
      Render SVG
    CLI
      PDF
"""
        let result = MermaidRenderer().renderSvg(source, options: MermaidRenderOptions(idPrefix: "mind1", classPrefix: "mk"))
        @Expect(result.supported, true)
        @Expect(result.svg.contains("mermaid4cj-mindmap mindmapDiagram"), true)
        @Expect(result.svg.contains("edgePaths"), true)
        @Expect(result.svg.contains("C "), true)
        @Expect(result.svg.contains("viewBox=\"0 0 680"), false)

        let html = MermaidRenderer().renderMarkitHtml(source, options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "mind-html"))
        @Expect(html.supported, true)
        @Expect(html.html.contains("mind-html-light"), true)
        @Expect(html.html.contains("mind-html-dark"), true)

        let path = Path("build/mermaid4cj-mindmap-test.svg")
        let fileResult = MermaidRenderer().renderSvgFile(source, path)
        @Expect(fileResult.supported, true)
        @Expect(exists(path), true)
        remove(path)
    }

    @TestCase
    func mindmapViewBoxUsesRenderedNodeBounds() {
        let result = MermaidRenderer().renderSvg("""
mindmap
  root((Docs))
    API
      Render SVG
    CLI
      PDF
    Shapes
      id[I am square]
""", options: MermaidRenderOptions(idPrefix: "mind-bounds"))
        @Expect(result.supported, true)
        @Expect(result.svg.contains("viewBox=\""), true)
        @Expect(result.svg.contains("API"), true)
        @Expect(result.svg.contains("CLI"), true)
        @Expect(result.svg.contains("Shapes"), true)
    }

    @TestCase
    func rendererUsesMigratedMindmapLayoutDataSectionsAndEdges() {
        let result = MermaidRenderer().renderSvg("""
mindmap
  Root
    First
      First child
    Second
      Second child
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("section-root section--1"), true)
        @Expect(result.svg.contains("section-0"), true)
        @Expect(result.svg.contains("section-1"), true)
        @Expect(result.svg.contains("section-edge-0"), true)
        @Expect(result.svg.contains("section-edge-1"), true)
        @Expect(result.svg.contains("edge-depth-3"), true)
    }

    @TestCase
    func mindmapEdgesExtendUnderNodeFillUsingDepthStrokeWidth() {
        let parsed = MermaidRenderer().parseMindmap("""
mindmap
  Root
    First
      First child
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let layout = MindmapLayout().layout(parsed.diagram, MermaidRenderOptions())
        let root = findMindmapNode(layout.nodes, "Root")
        let first = findMindmapNode(layout.nodes, "First")
        let edge = layout.edges[0]
        let start = edge.points[0]
        let end = edge.points[edge.points.size - 1]

        @Expect(edge.depth, 1)
        @Expect(root.width / 2.0 - abs64(start.x - root.x) >= 8.0, true)
        @Expect(first.width / 2.0 - abs64(end.x - first.x) >= 8.0, true)
    }

    @TestCase
    func mindmapHtmlLabelsUseLayoutNodeBoxForClippingAndCentering() {
        let result = MermaidRenderer().renderSvg("""
mindmap
  root((Markit))
    Parser
      CommonMark
""", options: MermaidRenderOptions(idPrefix: "mind-label"))
        @Expect(result.supported, true)
        let svg = result.svg

        @Expect(svg.count("<foreignObject width=\"92.000000\" height=\"44.000000\"><div"), 1)
        @Expect(svg.count("transform=\"translate(-46.000000, -22.000000)\""), 1)
        @Expect(svg.count("<foreignObject width=\"120.000000\" height=\"34.000000\"><div"), 1)
        @Expect(svg.count("width:120.000000px; max-width:120.000000px; height:34.000000px; vertical-align: middle; text-align: center;"), 1)
    }

    @TestCase
    func reportsMindmapIconWithoutNode() {
        let result = MermaidRenderer().renderSvg("mindmap\n  ::icon(fa fa-book)")
        @Expect(result.supported, false)
        @Expect(result.diagnostics[0].contains("icon has no preceding node"), true)
    }

    @TestCase
    func migratesUpstreamMindmapBaseIndentAndSingleRoot() {
        let parsed = MermaidRenderer().parseMindmap("""
mindmap
    root
      child
        grandchild
      sibling
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes[0].level, 0)
        @Expect(parsed.diagram.nodes[1].level, 2)
        @Expect(parsed.diagram.nodes[2].level, 4)
        @Expect(parsed.diagram.nodes[3].parentIndex, 0)

        let invalid = MermaidRenderer().parseMindmap("""
mindmap
root
other
""")
        @Expect(invalid.diagnostics[0].contains("only one mindmap root"), true)
    }

    @TestCase
    func reportsBareMindmapKeywordAsOfficialReservedToken() {
        let parsed = MermaidRenderer().parseMindmap("""
mindmap
  root
    Mindmap layout data
""")
        @Expect(parsed.diagnostics.isEmpty(), false)
        @Expect(parsed.diagnostics[0].contains("MINDMAP token"), true)
    }

}

private func shapeName(shape: MindmapNodeShape): String {
    match (shape) {
        case MindmapNodeShape.Square => return "Square"
        case MindmapNodeShape.Rounded => return "Rounded"
        case MindmapNodeShape.Circle => return "Circle"
        case MindmapNodeShape.Bang => return "Bang"
        case MindmapNodeShape.Cloud => return "Cloud"
        case MindmapNodeShape.Hexagon => return "Hexagon"
        case _ => return "Default"
    }
}

private func findMindmapNode(nodes: Array<MindmapLayoutNode>, label: String): MindmapLayoutNode {
    for (node in nodes) {
        if (node.label == label) {
            return node
        }
    }
    throw Exception("missing mindmap node: ${label}")
}

private func abs64(value: Float64): Float64 {
    return if (value < 0.0) { -value } else { value }
}
