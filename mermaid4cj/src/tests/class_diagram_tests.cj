package mermaid4cj.tests

import std.fs.{Path, exists, remove}
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.{ClassDef, MermaidHtmlOptions, MermaidRenderOptions, MermaidRenderer, MermaidTextMeasurer}

class WideClassTextMeasurer <: MermaidTextMeasurer {
    public init() {}

    public func measureText(text: String): Float64 {
        if (text.contains("+login(password: String) : bool")) {
            return 280.0
        }
        return Float64(text.size) * 8.0
    }

    public func countLines(text: String): Int64 {
        return 1
    }
}

@Test
@Tag[Mermaid4cj]
class MermaidClassDiagramTests {
    @TestCase
    func migratesUpstreamDocsAnimalExampleCoreSemantics() {
        let parsed = MermaidRenderer().parseClassDiagram("""
classDiagram
    note "From Duck till Zebra"
    Animal <|-- Duck
    note for Duck "can fly<br>can swim<br>can dive<br>can help in debugging"
    Animal <|-- Fish
    Animal <|-- Zebra
    Animal : +int age
    Animal : +String gender
    Animal: +isMammal()
    Animal: +mate()
    class Duck{
        +String beakColor
        +swim()
        +quack()
    }
    class Fish{
        -int sizeInFeet
        -canEat()
    }
    class Zebra{
        +bool is_wild
        +run()
    }
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.classes.size, 4)
        @Expect(parsed.diagram.relations.size, 3)
        @Expect(parsed.diagram.notes.size, 2)
        let animal = findClassIndex(parsed.diagram.classes, "Animal")
        let duck = findClassIndex(parsed.diagram.classes, "Duck")
        @Expect(animal >= 0, true)
        @Expect(duck >= 0, true)
        @Expect(parsed.diagram.classes[animal].members.size, 4)
        @Expect(parsed.diagram.classes[duck].members.size, 3)
        @Expect(parsed.diagram.classes[duck].members[1].isMethod, true)
        @Expect(parsed.diagram.relations[0].source, "Animal")
        @Expect(parsed.diagram.relations[0].target, "Duck")
        @Expect(parsed.diagram.relations[0].token, "<|--")
    }

    @TestCase
    func migratesClassLabelsBackticksAndRelationLabels() {
        let parsed = MermaidRenderer().parseClassDiagram("""
classDiagram
    class Animal["Animal with a label"]
    class `Car Class`
    Animal --> `Car Class` : owns
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let animal = findClassIndex(parsed.diagram.classes, "Animal")
        let car = findClassIndex(parsed.diagram.classes, "Car Class")
        @Expect(parsed.diagram.classes[animal].label, "Animal with a label")
        @Expect(car >= 0, true)
        @Expect(parsed.diagram.relations[0].target, "Car Class")
        @Expect(parsed.diagram.relations[0].label, "owns")
        @Expect(parsed.diagram.relations[0].endMarker, "association")
    }

    @TestCase
    func migratesGenericMembersAnnotationsAndReturnTypes() {
        let parsed = MermaidRenderer().parseClassDiagram("""
classDiagram
class Square~Shape~{
    <<interface>>
    int id
    List~int~ position
    setPoints(List~int~ points)
    getPoints() List~int~
}
Square : -List~string~ messages
Square : +getDistanceMatrix() List~List~int~~
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let square = parsed.diagram.classes[findClassIndex(parsed.diagram.classes, "Square")]
        @Expect(square.genericType.getOrThrow(), "Shape")
        @Expect(square.annotation.getOrThrow(), "interface")
        @Expect(square.members.size, 6)
        @Expect(square.members[3].text, "getPoints() : List~int~")
        @Expect(square.members[5].text, "+getDistanceMatrix() : List~List~int~~")
    }

    @TestCase
    func migratesNamespacesFromUpstreamSpec() {
        let parsed = MermaidRenderer().parseClassDiagram("""
classDiagram
namespace Company.Project {
  class User {
    +login(username: String, password: String)
    +logout()
  }
}
namespace Company.Project.Module {
  class Admin {
    +addUser(user: User)
    +removeUser(user: User)
  }
}
Admin --> User : manages
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.namespaces.size >= 3, true)
        let user = parsed.diagram.classes[findClassIndex(parsed.diagram.classes, "User")]
        let admin = parsed.diagram.classes[findClassIndex(parsed.diagram.classes, "Admin")]
        @Expect(user.namespaceId.getOrThrow(), "Company.Project")
        @Expect(admin.namespaceId.getOrThrow(), "Company.Project.Module")
        @Expect(parsed.diagram.relations[0].label, "manages")
    }

    @TestCase
    func rendersDedicatedClassSvgAndMarkitInterfaces() {
        let source = """
classDiagram
class BankAccount{
    +String owner
    +BigDecimal balance
    +deposit(amount)
    +withdrawal(amount) bool
}
Customer --> BankAccount : owns
"""
        let result = MermaidRenderer().renderSvg(source, options: MermaidRenderOptions(idPrefix: "cls1", classPrefix: "mk"))
        @Expect(result.supported, true)
        @Expect(result.svg.contains("id=\"cls1\""), true)
        @Expect(result.svg.contains("class=\"mk-class mermaid4cj-class\""), true)
        @Expect(result.svg.contains("class-box"), true)
        @Expect(result.svg.contains("class-divider"), true)
        @Expect(result.svg.contains("width=\"184\""), false)
        @Expect(result.svg.contains("marker-end=\"url(#cls1-class-association)\""), true)
        @Expect(result.svg.contains("<text class=\"class-relation-label\""), true)
        @Expect(result.svg.contains(">owns</text>"), true)
        @Expect(result.svg.contains("class-relation-label-bg"), false)
        @Expect(result.svg.contains("paint-order:stroke"), false)
        @Expect(result.svg.contains("stroke-width:5"), false)
        @Expect(result.svg.contains("+withdrawal(amount) : bool"), true)

        let html = MermaidRenderer().renderMarkitHtml(source, options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "class-html"))
        @Expect(html.supported, true)
        @Expect(html.html.contains("class-html-light"), true)
        @Expect(html.html.contains("class-html-dark"), true)

        let path = Path("build/mermaid4cj-class-test.svg")
        let fileResult = MermaidRenderer().renderSvgFile(source, path, options: MermaidRenderOptions(idPrefix: "class-file"))
        @Expect(fileResult.supported, true)
        @Expect(exists(path), true)
        remove(path)
    }

    @TestCase
    func classBoxWidthUsesConfiguredTextMeasurer() {
        let result = MermaidRenderer().renderSvg("""
classDiagram
class User {
  +String name
  +login(password: String) bool
}
""", options: MermaidRenderOptions(idPrefix: "cls-measure", textMeasurer: WideClassTextMeasurer()))
        @Expect(result.supported, true)
        @Expect(result.svg.contains("width=\"308"), true)
        @Expect(result.svg.contains("+login(password: String) : bool"), true)
    }

    @TestCase
    func reportsUnsupportedClassStatementsClearly() {
        let result = MermaidRenderer().renderSvg("""
classDiagram
style Animal fill:#fff
""")
        @Expect(result.supported, false)
        @Expect(result.diagnostics[0].contains("unsupported classDiagram statement"), true)
    }
}

private func findClassIndex(classes: ArrayList<ClassDef>, id: String): Int64 {
    for (i in 0..classes.size) {
        if (classes[i].id == id) {
            return i
        }
    }
    return -1
}
