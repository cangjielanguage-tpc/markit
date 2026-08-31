package mermaid4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.MermaidRenderer

@Test
@Tag[Mermaid4cj]
class MermaidGenericDiagramTests {
    @TestCase
    func rendersMindmapBasicTree() {
        let result = MermaidRenderer().renderSvg("""
mindmap
  root((Docs))
    API
    CLI
      PDF
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("mermaid4cj-mindmap"), true)
        @Expect(result.svg.contains("Docs"), true)
        @Expect(result.svg.contains("API"), true)
        @Expect(result.svg.contains("PDF"), true)
        @Expect(result.svg.contains("edgePaths"), true)
    }

    @TestCase
    func rendersClassDiagramBasicRelations() {
        let result = MermaidRenderer().renderSvg("""
classDiagram
class Animal
class Dog
Animal <|-- Dog
Dog --> Food : eats
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("mermaid4cj-class"), true)
        @Expect(result.svg.contains("Animal"), true)
        @Expect(result.svg.contains("Dog"), true)
        @Expect(result.svg.contains("eats"), true)
    }

    @TestCase
    func rendersErDiagramBasicRelations() {
        let result = MermaidRenderer().renderSvg("""
erDiagram
CUSTOMER ||--o{ ORDER : places
ORDER ||--|{ LINE_ITEM : contains
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("mermaid4cj-er"), true)
        @Expect(result.svg.contains("CUSTOMER"), true)
        @Expect(result.svg.contains("ORDER"), true)
        @Expect(result.svg.contains("places"), true)
    }

    @TestCase
    func rendersPieChartBasicRows() {
        let result = MermaidRenderer().renderSvg("""
pie title Pets
"Cats" : 40
"Dogs" : 35
"Birds" : 25
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("mermaid4cj-pie"), true)
        @Expect(result.svg.contains("Pets"), true)
        @Expect(result.svg.contains("Cats"), true)
        @Expect(result.svg.contains("pie-slice"), true)
    }

    @TestCase
    func markitHtmlSupportsGenericDiagramDualTheme() {
        let result = MermaidRenderer().renderMarkitHtml("""
pie title Usage
"Read" : 70
"Write" : 30
""")
        @Expect(result.supported, true)
        @Expect(result.html.contains("data-mermaid4cj-theme=\"dual\""), true)
        @Expect(result.html.contains("mmd-light"), true)
        @Expect(result.html.contains("mmd-dark"), true)
        @Expect(result.html.contains("Usage"), true)
    }

    @TestCase
    func rendersGanttBasicTimeline() {
        let result = MermaidRenderer().renderSvg("""
gantt
title Release Plan
dateFormat  YYYY-MM-DD
section Build
Design      :done, des1, 2026-01-01, 2026-01-03
Implement   :active, impl1, after des1, 3d
section Ship
Publish     :crit, pub1, after impl1, 1d
""")
        @Expect(result.supported, true)
        @Expect(result.svg.contains("mermaid4cj-gantt"), true)
        @Expect(result.svg.contains("Release Plan"), true)
        @Expect(result.svg.contains("Build"), true)
        @Expect(result.svg.contains("Implement"), true)
        @Expect(result.svg.contains("data-id=\"impl1\""), true)
        @Expect(result.svg.contains("gantt-task-active"), true)
        @Expect(result.svg.contains("gantt-task-crit"), true)
    }

    @TestCase
    func unsupportedDiagramKindsReturnExplicitError() {
        let result = MermaidRenderer().renderSvg("journey\nsection A\nTask: 5: Me")
        @Expect(result.supported, false)
        @Expect(result.diagnostics[0], "Unsupported Mermaid diagram kind")
        @Expect(result.svg.contains("Unsupported Mermaid diagram"), true)
        @Expect(result.svg.contains("not currently supported by mermaid4cj"), true)
    }

    @TestCase
    func stateDiagramV2IsSupportedByDedicatedRenderer() {
        let renderer = MermaidRenderer()
        let state = renderer.renderSvg("stateDiagram-v2\n[*] --> Still")

        @Expect(state.supported, true)
        @Expect(state.svg.contains("mermaid4cj-state"), true)
        @Expect(state.svg.contains("Still"), true)
    }
}
