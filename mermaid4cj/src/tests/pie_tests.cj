package mermaid4cj.tests

import std.fs.{Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.{MermaidHtmlOptions, MermaidRenderOptions, MermaidRenderer}

@Test
@Tag[Mermaid4cj]
class MermaidPieTests {
    @TestCase
    func migratesUpstreamPieTitleShowDataAndValues() {
        let parsed = MermaidRenderer().parsePie("""
pie showData
    title Key elements in Product X
    "Calcium" : 42.96
    "Potassium" : 50.05
    "Magnesium" : 10.01
    "Iron" : 5
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.showData, true)
        @Expect(parsed.diagram.title.getOrThrow(), "Key elements in Product X")
        @Expect(parsed.diagram.slices.size, 4)
        @Expect(parsed.diagram.slices[0].label, "Calcium")
        @Expect(parsed.diagram.slices[0].value, 42.96)
    }

    @TestCase
    func rendersDedicatedPieSvgHtmlAndFile() {
        let source = """
pie title Pets adopted by volunteers
    "Dogs" : 386
    "Cats" : 85
    "Rats" : 15
"""
        let result = MermaidRenderer().renderSvg(source, options: MermaidRenderOptions(idPrefix: "pie1", classPrefix: "mk"))
        @Expect(result.supported, true)
        @Expect(result.svg.contains("class=\"mk-pie mermaid4cj-pie\""), true)
        @Expect(result.svg.contains("data-percent"), true)
        @Expect(result.svg.contains("Pets adopted by volunteers"), true)

        let html = MermaidRenderer().renderMarkitHtml(source, options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "pie-html"))
        @Expect(html.supported, true)
        @Expect(html.html.contains("pie-html-light"), true)
        @Expect(html.html.contains("pie-html-dark"), true)

        let path = Path("build/mermaid4cj-pie-test.svg")
        let fileResult = MermaidRenderer().renderSvgFile(source, path)
        @Expect(fileResult.supported, true)
        @Expect(exists(path), true)
        remove(path)
    }

    @TestCase
    func migratesUpstreamPieZeroDuplicatesAndDecimals() {
        let parsed = MermaidRenderer().parsePie("""
pie
    "Zero" : 0
    "Precise" : 3.14159
    "Precise" : 99
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.slices.size, 2)
        @Expect(parsed.diagram.slices[0].label, "Zero")
        @Expect(parsed.diagram.slices[0].value, 0.0)
        @Expect(parsed.diagram.slices[1].value > 3.14158, true)
        @Expect(parsed.diagram.slices[1].value < 3.14160, true)
    }

    @TestCase
    func rejectsNegativeAndNonNumericPieDataLikeUpstream() {
        let negative = MermaidRenderer().renderSvg("pie\n\"Bad\" : -1")
        @Expect(negative.supported, false)
        @Expect(negative.diagnostics[0].contains("non-negative"), true)

        let invalid = MermaidRenderer().renderSvg("pie\n\"Bad\" : nope")
        @Expect(invalid.supported, false)
        @Expect(invalid.diagnostics[0].contains("invalid pie slice value"), true)

        let empty = MermaidRenderer().renderSvg("pie title Empty")
        @Expect(empty.supported, true)
        @Expect(empty.svg.contains("Empty"), true)
    }
}
