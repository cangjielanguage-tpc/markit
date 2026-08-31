package mermaid4cj.tests

import std.fs.{Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.{MermaidHtmlOptions, MermaidRenderOptions, MermaidRenderer, StateDirection}

@Test
@Tag[Mermaid4cj]
class MermaidStateDiagramTests {
    @TestCase
    func parsesStateDiagramV2StartEndTransitionsLabelsAndDirection() {
        let parsed = MermaidRenderer().parseStateDiagram("""
stateDiagram-v2
direction LR
[*] --> Still
Still --> Moving : accelerate
Moving --> [*] : stop
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(directionName(parsed.diagram.direction), "LR")
        @Expect(parsed.diagram.nodes.size, 3)
        @Expect(parsed.diagram.transitions.size, 3)
        @Expect(parsed.diagram.transitions[1].source, "Still")
        @Expect(parsed.diagram.transitions[1].label, "accelerate")
    }

    @TestCase
    func parsesCompositeStateBoundary() {
        let parsed = MermaidRenderer().parseStateDiagram("""
stateDiagram-v2
state Running {
  [*] --> Warmup
  Warmup --> Hot
}
Running --> Done
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.nodes.size >= 4, true)
        @Expect(parsed.diagram.transitions.size, 3)
    }

    @TestCase
    func rendersDedicatedStateSvgHtmlAndFile() {
        let source = """
stateDiagram-v2
direction LR
[*] --> Still
Still --> Moving : accelerate
Moving --> [*] : stop
"""
        let result = MermaidRenderer().renderSvg(source, options: MermaidRenderOptions(idPrefix: "state1", classPrefix: "mk"))
        @Expect(result.supported, true)
        @Expect(result.svg.contains("class=\"mk-state mermaid4cj-state\""), true)
        @Expect(result.svg.contains("marker-end=\"url(#state1-state-arrow)\""), true)
        @Expect(result.svg.contains("accelerate"), true)

        let html = MermaidRenderer().renderMarkitHtml(source, options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "state-html"))
        @Expect(html.supported, true)
        @Expect(html.html.contains("state-html-light"), true)
        @Expect(html.html.contains("state-html-dark"), true)

        let path = Path("build/mermaid4cj-state-test.svg")
        let fileResult = MermaidRenderer().renderSvgFile(source, path)
        @Expect(fileResult.supported, true)
        @Expect(exists(path), true)
        remove(path)
    }

    @TestCase
    func verticalStateTransitionsStopAtNodeBoundariesAndUseLabelBackgrounds() {
        let result = MermaidRenderer().renderSvg("""
stateDiagram-v2
[*] --> Draft
Draft --> Built : render
Built --> Preview : serve
Preview --> Published : deploy
""", options: MermaidRenderOptions(idPrefix: "state-vertical"))
        @Expect(result.supported, true)
        let svg = result.svg

        @Expect(svg.count("<path class=\"state-transition\" d=\"M 255.000000 75.000000 L 255.000000 174.000000\""), 1)
        @Expect(svg.count("<path class=\"state-transition\" d=\"M 255.000000 220.000000 L 255.000000 306.000000\""), 1)
        @Expect(svg.count("<rect class=\"state-edge-label-bg\""), 3)
        @Expect(svg.count("<rect class=\"state-edge-label-bg\" x=\"228.000000\" y=\"254.000000\" width=\"54.000000\" height=\"18\" rx=\"3\"/>"), 1)
    }

    @TestCase
    func horizontalStateTransitionsKeepLabelsAboveEdgesWithoutBackgrounds() {
        let result = MermaidRenderer().renderSvg("""
stateDiagram-v2
direction LR
Draft --> Built : render
""", options: MermaidRenderOptions(idPrefix: "state-horizontal"))
        @Expect(result.supported, true)
        let svg = result.svg

        @Expect(svg.count("<rect class=\"state-edge-label-bg\""), 0)
        @Expect(svg.count("<text class=\"state-edge-label\" x=\"215.000000\" y=\"105.000000\" text-anchor=\"middle\">render</text>"), 1)
    }

    @TestCase
    func reportsUnsupportedStateChoiceAndNotesClearly() {
        let choice = MermaidRenderer().renderSvg("stateDiagram-v2\nchoice c")
        @Expect(choice.supported, false)
        @Expect(choice.diagnostics[0].contains("choice/fork/join"), true)

        let note = MermaidRenderer().renderSvg("stateDiagram-v2\nnote right of A: hi")
        @Expect(note.supported, false)
        @Expect(note.diagnostics[0].contains("notes are not yet supported"), true)
    }
}

private func directionName(value: StateDirection): String {
    match (value) {
        case StateDirection.TB => return "TB"
        case StateDirection.BT => return "BT"
        case StateDirection.LR => return "LR"
        case StateDirection.RL => return "RL"
    }
}
