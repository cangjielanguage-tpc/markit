package mermaid4cj.tests

import std.fs.{File, Path, exists, remove}
import std.io.{ByteBuffer, readToEnd}
import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.{DiagramKind, MermaidHtmlOptions, MermaidHtmlThemeMode, MermaidRenderOptions, MermaidRenderer, MermaidTextMeasurer, MermaidTheme}
import mermaid4cj.layout.{AnchorPoint, FlowchartLayout}
import mermaid4cj.parser.FlowchartParser
import mermaid4cj.svg.appendD3BasisPath

class FixedMermaidTextMeasurer <: MermaidTextMeasurer {
    public init() {}

    public func measureText(text: String): Float64 {
        return Float64(text.size) * 25.0
    }

    public func countLines(text: String): Int64 {
        return 1
    }
}

@Test
@Tag[Mermaid4cj]
class MermaidRendererTests {
    @TestCase
    func d3BasisPathMatchesOfficialCurveBasisControlPoints() {
        // Expected values come from d3-shape/src/curve/basis.js for:
        // [[0,0],[12,6],[30,18],[42,0],[60,12]]
        let out = StringBuilder()
        appendD3BasisPath(out, [
            AnchorPoint(0.0, 0.0),
            AnchorPoint(12.0, 6.0),
            AnchorPoint(30.0, 18.0),
            AnchorPoint(42.0, 0.0),
            AnchorPoint(60.0, 12.0)
        ])
        let path = out.toString()

        @Expect(path.contains("M 0.000000 0.000000"), true)
        @Expect(path.contains("L 2.000000 1.000000"), true)
        @Expect(path.contains("C 4.000000 2.000000, 8.000000 4.000000, 13.000000 7.000000"), true)
        @Expect(path.contains("C 18.000000 10.000000, 24.000000 14.000000, 29.000000 13.000000"), true)
        @Expect(path.contains("C 34.000000 12.000000, 38.000000 6.000000, 43.000000 5.000000"), true)
        @Expect(path.contains("C 48.000000 4.000000, 54.000000 8.000000, 57.000000 10.000000"), true)
        @Expect(path.contains("L 60.000000 12.000000"), true)
    }

    @TestCase
    func detectsFlowchartHeader() {
        let renderer = MermaidRenderer()
        @Expect(renderer.supportsDiagramKind(renderer.detectDiagramKind("flowchart LR\nA-->B")), true)
        @Expect(renderer.supportsDiagramKind(renderer.detectDiagramKind("graph TD\nA-->B")), true)
    }

    @TestCase
    func rendersSequenceDiagramSvgString() {
        let result = MermaidRenderer().renderSvg("sequenceDiagram\nA->>B: hello")
        @Expect(result.supported, true)
        @Expect(diagramKindName(result.kind), "sequence")
        @Expect(result.svg.contains("class=\"mmd-sequence mermaid4cj-sequence\""), true)
        @Expect(result.svg.contains("hello"), true)
        @Expect(result.svg.contains("marker-end=\"url(#mmd-seq-arrow)\""), true)
    }

    @TestCase
    func unsupportedDiagramReturnsErrorSvg() {
        let result = MermaidRenderer().renderSvg("journey\nsection A\nTask: 5: Me")
        @Expect(result.supported, false)
        @Expect(result.svg.contains("mermaid4cj-error"), true)
        @Expect(result.svg.contains("Unsupported Mermaid diagram"), true)
    }

    @TestCase
    func unsupportedDiagramReturnsErrorMarkitHtml() {
        let result = MermaidRenderer().renderMarkitHtml("journey\nsection A\nTask: 5: Me")
        @Expect(result.supported, false)
        @Expect(result.html.contains("mermaid4cj-error"), true)
        @Expect(result.html.contains("Unsupported Mermaid diagram"), true)
        @Expect(result.html.contains("data-mermaid4cj-theme=\"dual\""), true)
    }

    @TestCase
    func rendersFlowchartSvgStringWithEscapedUnicodeLabel() {
        let source = "flowchart TD\nA[开始 <go>] --> B[结束 & 完成]"
        let result = MermaidRenderer().renderSvg(source, options: MermaidRenderOptions(idPrefix: "case1", title: Some("流程")))
        @Expect(result.supported, true)
        @Expect(result.svg.contains("<svg"), true)
        @Expect(result.svg.contains("开始 &lt;go&gt;"), true)
        @Expect(result.svg.contains("结束 &amp; 完成"), true)
        @Expect(result.svg.contains("id=\"case1_flowchart-v2-pointEnd\""), true)
    }

    @TestCase
    func renderOptionsCanUseCustomTextMeasurerForCliMeasurementAdapter() {
        let source = "flowchart LR\nA -->|wide| B"
        let parsed = FlowchartParser().parse(source)
        @Expect(parsed.diagnostics.isEmpty(), true)

        let defaultLayout = FlowchartLayout().layout(parsed.diagram)
        let measuredLayout = FlowchartLayout(textMeasurer: FixedMermaidTextMeasurer()).layout(parsed.diagram)
        let result = MermaidRenderer().renderSvg(
            source,
            options: MermaidRenderOptions(textMeasurer: FixedMermaidTextMeasurer())
        )

        @Expect(result.supported, true)
        @Expect(measuredLayout.width > defaultLayout.width, true)
        @Expect(result.svg.contains(">wide</text>"), true)
        @Expect(result.svg.contains("edge-label-bg"), false)
    }

    @TestCase
    func writesSvgToOutputStream() {
        let out = ByteBuffer()
        let result = MermaidRenderer().renderSvgToStream("graph LR\nA --> B", out)
        @Expect(result.supported, true)
        let written = String.fromUtf8(readToEnd(out))
        @Expect(written, result.svg)
    }

    @TestCase
    func writesSvgFile() {
        let path = Path("build/mermaid4cj-test.svg")
        let result = MermaidRenderer().renderSvgFile("graph TD\nA --> B", path)
        @Expect(result.supported, true)
        @Expect(exists(path), true)
        remove(path)
    }

    @TestCase
    func renderMarkitHtmlUsesDualThemeClassProtocol() {
        let result = MermaidRenderer().renderMarkitHtml(
            "graph TD\nA[Light] --> B[Dark]",
            options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "diagram-1")
        )
        @Expect(result.supported, true)
        @Expect(result.html.contains("class=\"mk-mermaid-container mermaid4cj-container\""), true)
        @Expect(result.html.contains("data-mermaid4cj=\"native\""), true)
        @Expect(result.html.contains("data-mermaid4cj-theme=\"dual\""), true)
        @Expect(result.html.contains("mk-mermaid-theme-light"), true)
        @Expect(result.html.contains("mk-mermaid-theme-dark"), true)
        @Expect(result.html.contains("id=\"diagram-1-light_flowchart-v2-pointEnd\""), true)
        @Expect(result.html.contains("id=\"diagram-1-dark_flowchart-v2-pointEnd\""), true)
    }

    @TestCase
    func renderMarkitHtmlSupportsDualThemeSequence() {
        let result = MermaidRenderer().renderMarkitHtml(
            "sequenceDiagram\nparticipant A as Alice\nparticipant B as Bob\nA-->>B: hello",
            options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "seq-1")
        )
        @Expect(result.supported, true)
        @Expect(result.html.contains("data-mermaid4cj-theme=\"dual\""), true)
        @Expect(result.html.contains("seq-1-light-seq-arrow"), true)
        @Expect(result.html.contains("seq-1-dark-seq-arrow"), true)
        @Expect(result.html.contains("Alice"), true)
        @Expect(result.html.contains("Bob"), true)
    }

    @TestCase
    func renderMarkitHtmlScopesNonFlowchartSvgStylesByRenderedSvgId() {
        let classResult = MermaidRenderer().renderMarkitHtml(
            "classDiagram\nclass Animal\nAnimal : +name\nAnimal : +speak()",
            options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "class-scope")
        )
        @Expect(classResult.supported, true)
        @Expect(classResult.html.count("#class-scope-light .class-box{"), 1)
        @Expect(classResult.html.count("#class-scope-dark .class-box{"), 1)
        @Expect(classResult.html.count("<style>.class-box{"), 0)
        @Expect(classResult.html.count("}.class-box{"), 0)

        let stateResult = MermaidRenderer().renderMarkitHtml(
            "stateDiagram-v2\n[*] --> Ready\nReady --> Done\nDone --> [*]",
            options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "state-scope")
        )
        @Expect(stateResult.supported, true)
        @Expect(stateResult.html.count("#state-scope-light{background:"), 1)
        @Expect(stateResult.html.count("#state-scope-dark{background:"), 1)
        @Expect(stateResult.html.count("<style>svg{background:"), 0)
        @Expect(stateResult.html.count("}.state-node{"), 0)

        let ganttResult = MermaidRenderer().renderMarkitHtml(
            "gantt\ntitle Plan\nsection Build\nTask :a1, 2024-01-01, 2d",
            options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "gantt-scope")
        )
        @Expect(ganttResult.supported, true)
        @Expect(ganttResult.html.count("#gantt-scope-light .gantt-task{"), 1)
        @Expect(ganttResult.html.count("#gantt-scope-dark .gantt-task{"), 1)
        @Expect(ganttResult.html.count("}.gantt-task{"), 0)
    }

    @TestCase
    func renderMarkitHtmlCanEmitSingleDarkTheme() {
        let result = MermaidRenderer().renderMarkitHtml(
            "graph TD\nA --> B",
            options: MermaidHtmlOptions(themeMode: MermaidHtmlThemeMode.Dark, classPrefix: "mmdx", idPrefix: "dark-only")
        )
        @Expect(result.supported, true)
        @Expect(result.html.contains("data-mermaid4cj-theme=\"dark\""), true)
        @Expect(result.html.contains("mmdx-theme-dark"), true)
        @Expect(result.html.contains("mmdx-theme-light"), false)
        @Expect(result.html.contains("id=\"dark-only-dark_flowchart-v2-pointEnd\""), true)
    }

    @TestCase
    func renderMarkitHtmlCanIncludeEscapedSourceForFallbackUi() {
        let result = MermaidRenderer().renderMarkitHtml(
            "graph TD\nA[开始 <go>] --> B",
            options: MermaidHtmlOptions(classPrefix: "mmd", includeSource: true)
        )
        @Expect(result.html.contains("<pre class=\"mmd-source\"><code class=\"language-mermaid\">"), true)
        @Expect(result.html.contains("开始 &lt;go&gt;"), true)
    }

    @TestCase
    func exposesThemeCssForMarkitWebsite() {
        let css = MermaidRenderer.markitThemeCss(classPrefix: "mk-mermaid")
        @Expect(css.contains("html[data-theme=\"dark\"] .mk-mermaid-diagram.mk-mermaid-theme-light{display:none}"), true)
        @Expect(css.contains("html[data-theme=\"dark\"] .mk-mermaid-diagram.mk-mermaid-theme-dark{display:block}"), true)
        @Expect(css.contains("html[data-theme=\"light\"] .mk-mermaid-diagram.mk-mermaid-theme-dark{display:none}"), true)
    }

    @TestCase
    func renderSvgFileWithThemeNameSupportsCliPdfAssets() {
        let path = Path("build/mermaid4cj-dark-test.svg")
        let result = MermaidRenderer().renderSvgFileWithTheme(
            "graph LR\nA --> B",
            path,
            "dark-plus",
            options: MermaidRenderOptions(idPrefix: "pdf-mermaid")
        )
        @Expect(result.supported, true)
        @Expect(exists(path), true)
        @Expect(String.fromUtf8(File.readFrom(path)).contains("id=\"pdf-mermaid_flowchart-v2-pointEnd\""), true)
        remove(path)
    }

    @TestCase
    func rendersCommonShapesAndEdgeStyles() {
        let source = """
flowchart TD
A([Start]) -. optional .-> B[[Work]]
B ==> C{Decision}
C --- D((End))"""
        let result = MermaidRenderer().renderSvg(source)
        @Expect(result.supported, true)
        let svg = result.svg
        @Expect(svg.contains("stroke-dasharray=\"2\""), true)
        @Expect(svg.contains("stroke-width=\"3.5\""), true)
        @Expect(svg.contains("<circle"), true)
        @Expect(svg.contains("-node-divider"), true)
        @Expect(svg.contains(" Z\" fill=\""), true)
        @Expect(svg.contains("optional"), true)
    }

    @TestCase
    func rendersMigratedOfficialNodeDataShapes() {
        let result = MermaidRenderer().renderSvg("""
flowchart TD
A@{ shape: hex, label: "Hex" }
B@{ shape: in-out, label: "Input" }
C@{ shape: out-in, label: "Output" }
D@{ shape: trapezoid, label: "Trap" }
E@{ shape: manual, label: "Manual" }
F@{ shape: double-circle, label: "Stop" }
G@{ shape: card, label: "Card" }
H@{ shape: lined-process, label: "Lined" }
I@{ shape: start }
J@{ shape: stop }
K@{ shape: junction }
L@{ shape: fork }
M@{ shape: doc, label: "Doc" }
N@{ shape: stacked-rectangle, label: "Stack" }
O@{ shape: divided-process, label: "Divided" }
P@{ shape: datastore, label: "Store" }
Q@{ shape: triangle, label: "Tri" }
R@{ shape: sloped-rectangle, label: "Slope" }
S@{ shape: crossed-circle }
T@{ shape: tagged-process, label: "Tagged" }
U@{ shape: tagged-document, label: "TagDoc" }
V@{ shape: paper-tape, label: "Tape" }
W@{ shape: hourglass }
X@{ shape: notched-pentagon, label: "Loop" }
Y@{ shape: flipped-triangle, label: "File" }
Z@{ shape: delay, label: "Delay" }
AA@{ shape: curved-trapezoid, label: "Display" }
AB@{ shape: window-pane, label: "Storage" }
AC@{ shape: lined-cylinder, label: "Disk" }
AD@{ shape: horizontal-cylinder, label: "Das" }
AE@{ shape: stacked-document, label: "Docs" }
AF@{ shape: lined-document, label: "LineDoc" }
AG@{ shape: bang, label: "Bang" }
AH@{ shape: cloud, label: "Cloud" }
AI@{ shape: lightning-bolt }
AJ@{ shape: bow-tie-rectangle, label: "Stored" }
AK@{ shape: brace, label: "Note" }
AL@{ shape: text, label: "Plain" }
AM@{ shape: brace-r, label: "Right" }
AN@{ shape: braces, label: "Both" }
""")
        @Expect(result.supported, true)
        let svg = result.svg
        @Expect(svg.contains("outer-circle"), true)
        @Expect(svg.contains("inner-circle"), true)
        @Expect(svg.contains("-node-divider"), true)
        @Expect(svg.contains("-node-inner"), true)
        @Expect(svg.contains("outer-path"), true)
        @Expect(svg.contains("stroke-dasharray=\""), true)
        @Expect(svg.contains("class=\"nodeLabel\""), true)
        @Expect(svg.contains(">Doc</text>"), true)
        @Expect(svg.contains("-node-cross"), true)
        @Expect(svg.contains(">Tape</text>"), true)
        @Expect(svg.contains(">Delay</text>"), true)
        @Expect(svg.contains(">Disk</text>"), true)
        @Expect(svg.contains(">Docs</text>"), true)
        @Expect(svg.contains(">Cloud</text>"), true)
        @Expect(svg.contains(">Bang</text>"), true)
        @Expect(svg.contains(">Stored</text>"), true)
        @Expect(svg.contains(">Note</text>"), true)
        @Expect(svg.contains(">Plain</text>"), true)
        @Expect(svg.contains(">Right</text>"), true)
        @Expect(svg.contains(">Both</text>"), true)
    }

    @TestCase
    func rendersMigratedOldEllipseAndOddShapesWithoutFallbacks() {
        let result = MermaidRenderer().renderSvg("""
flowchart TD
A(-Ellipse text-) --> B>Odd text]
""")
        @Expect(result.supported, true)
        let svg = result.svg
        @Expect(svg.contains("<ellipse class=\"mmd-node\""), true)
        @Expect(svg.contains(">Ellipse text</text>"), true)
        @Expect(svg.contains(">Odd text</text>"), true)
        @Expect(svg.contains(" L "), true)
    }

    @TestCase
    func rendersComplexShapesWithOfficialPathFamilies() {
        let result = MermaidRenderer().renderSvg("""
flowchart TD
A@{ shape: cloud, label: "Cloud" }
B@{ shape: bang, label: "Bang" }
C@{ shape: bow-tie-rectangle, label: "Stored" }
D@{ shape: stacked-document, label: "Docs" }
E@{ shape: brace, label: "Note" }
F@{ shape: brace-r, label: "Right" }
G@{ shape: braces, label: "Both" }
""")
        @Expect(result.supported, true)
        let svg = result.svg
        @Expect(svg.contains(" a"), true)
        @Expect(svg.count(" a") > 12, true)
        @Expect(svg.contains("-node-inner"), true)
        @Expect(svg.contains("fill=\"none\""), true)
        @Expect(svg.contains(">Stored</text>"), true)
        @Expect(svg.contains(">Docs</text>"), true)
        @Expect(svg.contains(">Both</text>"), true)
    }

    @TestCase
    func rendersStadiumRadiusFromHeightLikeOfficialShape() {
        let result = MermaidRenderer().renderSvg("flowchart TD\nA([Start])")

        @Expect(result.supported, true)
        @Expect(result.svg.contains("rx=\"27.000000\""), true)
    }

    @TestCase
    func rendersOfficialFlowchartSvgGroupsAndDataIds() {
        let result = MermaidRenderer().renderSvg(
            "flowchart TD\nA[Start] -->|go| B[Done]\nA e1@--> B",
            options: MermaidRenderOptions(idPrefix: "my-svg")
        )
        @Expect(result.supported, true)
        let svg = result.svg
        @Expect(svg.contains("<g class=\"root\"><g class=\"clusters\"/><g class=\"edgePaths\">"), true)
        @Expect(svg.contains("</g><g class=\"edgeLabels\">"), true)
        @Expect(svg.contains("</g><g class=\"nodes\">"), true)
        @Expect(svg.contains("<svg id=\"my-svg\""), true)
        @Expect(svg.contains("#my-svg .nodeLabel,#my-svg .edgeLabel{"), true)
        @Expect(svg.contains("id=\"my-svg-L_A_B_0\""), true)
        @Expect(svg.contains("data-id=\"L_A_B_0\""), true)
        @Expect(svg.contains("id=\"my-svg-e1\""), true)
        @Expect(svg.contains("data-id=\"e1\""), true)
        @Expect(svg.contains("data-edge=\"true\" data-et=\"edge\""), true)
        @Expect(svg.contains("data-look=\"classic\""), true)
        @Expect(svg.contains("id=\"my-svg-flowchart-A-0\" data-id=\"A\" transform=\"translate("), true)
        @Expect(svg.contains("class=\"edgeLabel\" transform=\"translate("), true)
        @Expect(svg.contains("<text class=\"nodeLabel\" x=\"0\""), true)
        @Expect(svg.contains("<text class=\"edgeLabel\" x=\"0\" y=\"5\" text-anchor=\"middle\""), true)
        @Expect(svg.contains(">Start</text>"), true)
        @Expect(svg.contains("class=\"edgeLabel\""), true)
        @Expect(svg.contains(">go</text>"), true)
        @Expect(svg.contains("labelBkg"), false)
        @Expect(svg.contains("edge-label-bg"), false)
    }

    @TestCase
    func rendersClassDefAndStyleSubsetIntoSvg() {
        let source = """
flowchart TD
A[Start]:::hot --> B[Done]
classDef hot fill:#f9f,stroke:#333,color:#111
style B fill:#bbf,stroke:#00f,color:#fff"""
        let result = MermaidRenderer().renderSvg(source)
        @Expect(result.supported, true)
        let svg = result.svg
        @Expect(svg.contains("fill=\"#f9f\""), true)
        @Expect(svg.contains("stroke=\"#333\""), true)
        @Expect(svg.contains("fill=\"#bbf\""), true)
        @Expect(svg.contains("stroke=\"#00f\""), true)
        @Expect(svg.contains("fill=\"#fff\""), true)
        @Expect(svg.contains(">Done</text>"), true)
    }

    @TestCase
    func rendersSubgraphAsClusterFromParsedMembership() {
        let result = MermaidRenderer().renderSvg("""
flowchart TB
subgraph A [Outer]
  subgraph B [Inner]
    c[Child]
  end
  a[Start] --> c
end
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("class=\"clusters mmd-subgraphs\""), true)
        @Expect(result.svg.contains("class=\"cluster\" id=\"mmd-A\" data-id=\"A\""), true)
        @Expect(result.svg.contains("class=\"cluster\" id=\"mmd-B\" data-id=\"B\""), true)
        @Expect(result.svg.contains(">Outer</text>"), true)
        @Expect(result.svg.contains(">Inner</text>"), true)
    }

    @TestCase
    func rendersDatabaseShapeAndBidirectionalEdges() {
        let source = "flowchart LR\nDB[(Database)] <--> API[Service]"
        let result = MermaidRenderer().renderSvg(source)
        @Expect(result.supported, true)
        @Expect(result.svg.contains("Database"), true)
        @Expect(result.svg.contains("data-id=\"L_DB_API_0\""), true)
        @Expect(result.svg.contains("<path d=\"M "), true)
        @Expect(result.svg.count("marker-start=\"url(#mmd_flowchart-v2-pointStart)\""), 1)
        @Expect(result.svg.count("marker-end=\"url(#mmd_flowchart-v2-pointEnd)\""), 1)
    }

    @TestCase
    func flowchartPointMarkersOffsetRenderedPathEndpointsLikeOfficialRenderer() {
        let source = "flowchart LR\nA[Write Markdown] --> B[markit-cli render]"
        let renderer = MermaidRenderer()
        let parsed = renderer.parseFlowchart(source)
        @Expect(parsed.diagnostics.isEmpty(), true)
        let layout = FlowchartLayout().layout(parsed.diagram)
        let result = renderer.renderFlowchartSvg(parsed)
        @Expect(result.supported, true)

        let path = attributeValueForId(result.svg, "mmd-L_A_B_0", "d")
        let expectedSuffix = StringBuilder()
        expectedSuffix.append(" L ")
        expectedSuffix.append(layout.edges[0].x2 - 4.0)
        expectedSuffix.append(" ")
        expectedSuffix.append(layout.edges[0].y2)
        @Expect(path.endsWith(expectedSuffix.toString()), true)
    }

    @TestCase
    func rendersChainedAndMultipleTargetEdges() {
        let result = MermaidRenderer().renderSvg("flowchart TD\nA-->B-->C\nA --> D & E")
        @Expect(result.supported, true)
        @Expect(result.svg.count("class=\"mmd-edge flowchart-link"), 4)
        @Expect(result.svg.contains("edge-thickness-normal"), true)
        @Expect(result.svg.contains("edge-pattern-solid"), true)
        @Expect(result.svg.contains(">E</text>"), true)
    }

    @TestCase
    func rendersNodeDataMultilineLabelsAsHtmlBreaks() {
        let result = MermaidRenderer().renderSvg("""
flowchart TB
A@{
  label: "This is a
    multiline string"
}
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("This is a<tspan x=\"0\" dy=\"24.000000\">multiline string</tspan>"), true)
    }

    @TestCase
    func rendersFlowchartLabelsAsPureSvgTextForTypstPdf() {
        let result = MermaidRenderer().renderSvg("""
flowchart TD
A[Start] -->|go| B@{
  label: "Done
    today"
}
""")
        @Expect(result.supported, true)
        let svg = result.svg
        @Expect(svg.contains("<text class=\"nodeLabel\" x=\"0\""), true)
        @Expect(svg.contains("<text class=\"edgeLabel\" x=\"0\" y=\"5\" text-anchor=\"middle\""), true)
        @Expect(svg.contains(">Start</text>"), true)
        @Expect(svg.contains(">go</text>"), true)
        @Expect(svg.contains("Done<tspan x=\"0\" dy=\"24.000000\">today</tspan>"), true)
        @Expect(svg.contains("<foreignObject"), false)
        @Expect(svg.contains("labelBkg"), false)
        @Expect(svg.contains("edge-label-bg"), false)
    }

    @TestCase
    func rendersUpstreamMarkdownStringLabelsWithoutBacktickDelimiters() {
        let result = MermaidRenderer().renderSvg("""
flowchart TD
A["`The cat in **the** hat`"] -- "`The *bat* in the chat`" --> B["The dog"]
C@{ label: "`Node **data** label`" }
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("The cat in **the** hat"), true)
        @Expect(result.svg.contains("The *bat* in the chat"), true)
        @Expect(result.svg.contains("Node **data** label"), true)
        @Expect(result.svg.contains("`The cat"), false)
    }

    @TestCase
    func rendersUpstreamMarkdownStringSubgraphTitlesWithoutBacktickDelimiters() {
        let result = MermaidRenderer().renderSvg("""
flowchart LR
subgraph "`**Two**`"
  c("`The **cat** in the hat`") -- "`1o **ipa**`" --> d("The dog in the hog")
end
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains(">**Two**</text>"), true)
        @Expect(result.svg.contains("The **cat** in the hat"), true)
        @Expect(result.svg.contains("1o **ipa**"), true)
        @Expect(result.svg.contains("`**Two**`"), false)
    }

    @TestCase
    func migratesUpstreamSelfLoopRenderingAsOneSvgPath() {
        let result = MermaidRenderer().renderSvg("""
flowchart TD
A[Christmas] -->|Get money| B(Go shopping)
C --> C""")
        @Expect(result.supported, true)
        @Expect(result.svg.count("class=\"mmd-edge flowchart-link"), 2)
        @Expect(result.svg.contains("cyclic-special"), false)
        @Expect(result.svg.contains("data-id=\"L_C_C_0\""), true)
        @Expect(result.svg.contains("L_C_C_0\" class=\"mmd-edge flowchart-link"), true)
        @Expect(result.svg.contains(" L "), true)
    }

    @TestCase
    func parsedFlowchartCanRenderMultipleThemesWithoutReparse() {
        let renderer = MermaidRenderer()
        let parsed = renderer.parseFlowchart("flowchart TD\nA[Start] --> B[Done]")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let light = renderer.renderFlowchartSvg(parsed, options: MermaidRenderOptions(theme: MermaidTheme.Default, idPrefix: "parsed-light"))
        let dark = renderer.renderFlowchartSvg(parsed, options: MermaidRenderOptions(theme: MermaidTheme.Dark, idPrefix: "parsed-dark"))
        @Expect(light.supported, true)
        @Expect(dark.supported, true)
        @Expect(light.svg.contains("id=\"parsed-light_flowchart-v2-pointEnd\""), true)
        @Expect(dark.svg.contains("id=\"parsed-dark_flowchart-v2-pointEnd\""), true)
    }

    private func diagramKindName(kind: DiagramKind): String {
        match (kind) {
            case DiagramKind.Sequence => return "sequence"
            case DiagramKind.Flowchart => return "flowchart"
            case DiagramKind.Mindmap => return "mindmap"
            case DiagramKind.Class => return "class"
            case DiagramKind.Er => return "er"
            case DiagramKind.Pie => return "pie"
            case DiagramKind.State => return "state"
            case _ => return "unsupported"
        }
    }

    private func attributeValueForId(svg: String, id: String, attribute: String): String {
        let idNeedle = "id=\"" + id + "\""
        let idPosition = svg.indexOf(idNeedle).getOrThrow()
        var elementStart = idPosition
        while (elementStart > 0 && svg[elementStart] != b'<') {
            elementStart--
        }
        let elementEnd = svg.indexOf(b'>', idPosition).getOrThrow()
        let attrNeedle = attribute + "=\""
        let attrPosition = svg.indexOf(attrNeedle, elementStart).getOrThrow()
        if (attrPosition >= elementEnd) {
            return ""
        }
        let valueStart = attrPosition + attrNeedle.size
        let valueEnd = svg.indexOf(b'"', valueStart).getOrThrow()
        return svg[valueStart..valueEnd]
    }

}
