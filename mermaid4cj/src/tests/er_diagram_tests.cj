package mermaid4cj.tests

import std.fs.{Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.{ErCardinality, ErDirection, MermaidHtmlOptions, MermaidRenderOptions, MermaidRenderer}

@Test
@Tag[Mermaid4cj]
class MermaidErDiagramTests {
    @TestCase
    func migratesUpstreamDocsOrderExampleRelations() {
        let parsed = MermaidRenderer().parseErDiagram("""
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE-ITEM : contains
    CUSTOMER }|..|{ DELIVERY-ADDRESS : uses
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.entities.size, 4)
        @Expect(parsed.diagram.relationships.size, 3)
        @Expect(parsed.diagram.relationships[0].source, "CUSTOMER")
        @Expect(parsed.diagram.relationships[0].target, "ORDER")
        @Expect(cardinalityName(parsed.diagram.relationships[0].sourceCardinality), "ExactlyOne")
        @Expect(cardinalityName(parsed.diagram.relationships[0].targetCardinality), "ZeroOrMore")
        @Expect(parsed.diagram.relationships[0].identifying, true)
        @Expect(parsed.diagram.relationships[2].identifying, false)
        @Expect(parsed.diagram.relationships[2].label, "uses")
    }

    @TestCase
    func migratesUpstreamEntityAttributesKeysCommentsAndAliases() {
        let parsed = MermaidRenderer().parseErDiagram("""
erDiagram
    p[Person] {
        string driversLicense PK "The license #"
        string? middleName
        string phone UK
    }
    a["Customer Account"] {
        string email
    }
    p ||--o| a : has
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.entities.size, 2)
        @Expect(parsed.diagram.entities[0].id, "p")
        @Expect(parsed.diagram.entities[0].label, "Person")
        @Expect(parsed.diagram.entities[1].label, "Customer Account")
        @Expect(parsed.diagram.entities[0].attributes.size, 3)
        @Expect(parsed.diagram.entities[0].attributes[0].attributeType, "string")
        @Expect(parsed.diagram.entities[0].attributes[0].name, "driversLicense")
        @Expect(parsed.diagram.entities[0].attributes[0].key, "PK")
        @Expect(parsed.diagram.entities[0].attributes[0].comment, "The license #")
        @Expect(parsed.diagram.entities[0].attributes[1].attributeType, "string?")
        @Expect(cardinalityName(parsed.diagram.relationships[0].targetCardinality), "ZeroOrOne")
    }

    @TestCase
    func migratesUpstreamAliasCardinalityAndDirection() {
        let parsed = MermaidRenderer().parseErDiagram("""
erDiagram
    direction LR
    CAR 1 to zero or more NAMED-DRIVER : allows
    PERSON many(0) optionally to 0+ NAMED-DRIVER : is
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(directionName(parsed.diagram.direction), "LR")
        @Expect(parsed.diagram.relationships.size, 2)
        @Expect(cardinalityName(parsed.diagram.relationships[0].sourceCardinality), "ExactlyOne")
        @Expect(cardinalityName(parsed.diagram.relationships[0].targetCardinality), "ZeroOrMore")
        @Expect(parsed.diagram.relationships[0].identifying, true)
        @Expect(cardinalityName(parsed.diagram.relationships[1].sourceCardinality), "ZeroOrMore")
        @Expect(cardinalityName(parsed.diagram.relationships[1].targetCardinality), "ZeroOrMore")
        @Expect(parsed.diagram.relationships[1].identifying, false)
    }

    @TestCase
    func rendersDedicatedErSvgAndMarkitInterfaces() {
        let source = """
erDiagram
direction LR
CUSTOMER ||--o{ ORDER : places
ORDER {
  int orderNumber PK
  string deliveryAddress
}
CUSTOMER {
  string name
  string custNumber UK
}
"""
        let result = MermaidRenderer().renderSvg(source, options: MermaidRenderOptions(idPrefix: "er1", classPrefix: "mk"))
        @Expect(result.supported, true)
        @Expect(result.svg.count("class=\"mk-er mermaid4cj-er\""), 1)
        @Expect(result.svg.count("class=\"er-entity-box\""), 2)
        @Expect(result.svg.count("class=\"er-attribute-key\""), 2)
        @Expect(result.svg.count("marker-start=\"url(#er1-er-onlyOneStart)\""), 1)
        @Expect(result.svg.count("marker-end=\"url(#er1-er-zeroOrMoreEnd)\""), 1)
        @Expect(result.svg.count("markerUnits=\"userSpaceOnUse\""), 8)
        @Expect(result.svg.count(".marker{fill:none!important;stroke:"), 1)
        @Expect(result.svg.count("stroke-width=\"1\""), 12)
        @Expect(result.svg.count("stroke-width=\"1.4\""), 0)
        @Expect(result.svg.count("stroke-width=\"1.5\""), 0)
        @Expect(result.svg.count("<circle cx=\"45.5\" cy=\"18\" r=\"6\""), 1)
        @Expect(result.svg.count("<circle cx=\"11\" cy=\"18\" r=\"6\""), 1)
        @Expect(result.svg.count("M0,18 Q 18,0 36,18 Q 18,36 0,18 M42,9 L42,27"), 1)
        @Expect(result.svg.count("<text class=\"er-relationship-label\""), 1)
        @Expect(result.svg.count(">places</text>"), 1)
        @Expect(result.svg.count("class=\"er-relationship-label-bg\""), 0)

        let html = MermaidRenderer().renderMarkitHtml(source, options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "er-html"))
        @Expect(html.supported, true)
        @Expect(html.html.count("er-html-light") > 0, true)
        @Expect(html.html.count("er-html-dark") > 0, true)

        let path = Path("build/mermaid4cj-er-test.svg")
        let fileResult = MermaidRenderer().renderSvgFile(source, path, options: MermaidRenderOptions(idPrefix: "er-file"))
        @Expect(fileResult.supported, true)
        @Expect(exists(path), true)
        remove(path)
    }

    @TestCase
    func reportsMalformedErAttributesClearly() {
        let result = MermaidRenderer().renderSvg("""
erDiagram
PERSON {
  string
}
""")
        @Expect(result.supported, false)
        @Expect(result.diagnostics[0].contains("malformed erDiagram attribute"), true)
    }

    @TestCase
    func rendersHorizontalEntitiesWithOfficialDefaultNodeSpacing() {
        let result = MermaidRenderer().renderSvg("""
erDiagram
direction LR
A ||--|| B : owns
""", options: MermaidRenderOptions(idPrefix: "er-spacing"))

        @Expect(result.supported, true)
        @Expect(result.svg.count("<rect class=\"er-entity-box\" x=\"38.000000\""), 1)
        @Expect(result.svg.count("<rect class=\"er-entity-box\" x=\"346.000000\""), 1)
    }

    @TestCase
    func rendersManyCardinalityEndpointAtEntityBoundaryLikeOfficialNeo() {
        let result = MermaidRenderer().renderSvg("""
erDiagram
direction LR
A ||--|{ B : owns
""", options: MermaidRenderOptions(idPrefix: "er-boundary"))

        @Expect(result.supported, true)
        @Expect(result.svg.count("d=\"M 206.000000 60.000000 L 346.000000 60.000000\""), 1)
        @Expect(result.svg.count("marker-end=\"url(#er-boundary-er-oneOrMoreEnd)\""), 1)
        @Expect(result.svg.count("d=\"M 206.000000 60.000000 L 328.000000 60.000000\""), 0)
    }
}

private func cardinalityName(value: ErCardinality): String {
    match (value) {
        case ErCardinality.ZeroOrOne => return "ZeroOrOne"
        case ErCardinality.ExactlyOne => return "ExactlyOne"
        case ErCardinality.ZeroOrMore => return "ZeroOrMore"
        case ErCardinality.OneOrMore => return "OneOrMore"
    }
}

private func directionName(value: ErDirection): String {
    match (value) {
        case ErDirection.TB => return "TB"
        case ErDirection.BT => return "BT"
        case ErDirection.LR => return "LR"
        case ErDirection.RL => return "RL"
    }
}
