package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*
import mathtex.MathRenderer

@Test
@Tag[MathTex, MathTexKaTeXMigration, MathTexSymbols]
class KatexSymbolTableExtendedMigrationTests {
    @TestCase
    func amsRelationSymbolsFromKatexSymbolTableShouldRender() {
        let formulas = [
            "A \\lnsim B",
            "A \\lnapprox B",
            "A \\precnsim B",
            "A \\precnapprox B",
            "A \\nsim B",
            "A \\gnsim B",
            "A \\gnapprox B",
            "A \\succnsim B",
            "A \\succnapprox B",
            "A \\backsim B",
            "A \\backsimeq B",
            "A \\precsim B",
            "A \\precapprox B",
            "A \\thicksim B",
            "A \\thickapprox B",
            "A \\succsim B",
            "A \\succapprox B",
            "A \\eqsim B",
            "A \\subsetneqq B",
            "A \\supsetneqq B"
        ]
        assertRendersAll(formulas)
        assertHtmlContains("A \\lnsim B", "⋦")
        assertHtmlContains("A \\lnapprox B", "⪉")
        assertHtmlContains("A \\precnsim B", "⋨")
        assertHtmlContains("A \\precnapprox B", "⪹")
        assertHtmlContains("A \\nsim B", "≁")
        assertHtmlContains("A \\gnsim B", "⋧")
        assertHtmlContains("A \\gnapprox B", "⪊")
        assertHtmlContains("A \\succnsim B", "⋩")
        assertHtmlContains("A \\succnapprox B", "⪺")
        assertHtmlContains("A \\backsim B", "∽")
        assertHtmlContains("A \\backsimeq B", "⋍")
        assertHtmlContains("A \\precsim B", "≾")
        assertHtmlContains("A \\precapprox B", "⪷")
        assertHtmlContains("A \\thicksim B", "∼")
        assertHtmlContains("A \\thickapprox B", "≈")
        assertHtmlContains("A \\succsim B", "≿")
        assertHtmlContains("A \\succapprox B", "⪸")
        assertHtmlContains("A \\eqsim B", "≂")
        assertHtmlContains("A \\subsetneqq B", "⫋")
        assertHtmlContains("A \\supsetneqq B", "⫌")
        assertMathMlContains("A \\precsim B", "<mo>≾</mo>")
        assertMathMlContains("A \\subsetneqq B", "<mo>⫋</mo>")
    }

    @TestCase
    func amsBinaryOperatorSymbolsFromKatexSymbolTableShouldRender() {
        let formulas = [
            "A \\doublebarwedge B",
            "A \\divideontimes B",
            "A \\ltimes B",
            "A \\rtimes B",
            "A \\leftthreetimes B",
            "A \\rightthreetimes B",
            "A \\curlywedge B",
            "A \\curlyvee B",
            "A \\intercal B",
            "A \\doublecap B",
            "A \\doublecup B",
            "A \\boxtimes B",
            "A \\barwedge B",
            "A \\veebar B"
        ]
        assertRendersAll(formulas)
        assertHtmlContains("A \\doublebarwedge B", "⩞")
        assertHtmlContains("A \\divideontimes B", "⋇")
        assertHtmlContains("A \\ltimes B", "⋉")
        assertHtmlContains("A \\rtimes B", "⋊")
        assertHtmlContains("A \\leftthreetimes B", "⋋")
        assertHtmlContains("A \\rightthreetimes B", "⋌")
        assertHtmlContains("A \\curlywedge B", "⋏")
        assertHtmlContains("A \\curlyvee B", "⋎")
        assertHtmlContains("A \\intercal B", "⊺")
        assertHtmlContains("A \\doublecap B", "⋒")
        assertHtmlContains("A \\doublecup B", "⋓")
        assertHtmlContains("A \\boxtimes B", "⊠")
        assertHtmlContains("A \\barwedge B", "⊼")
        assertHtmlContains("A \\veebar B", "⊻")
        assertMathMlContains("A \\boxtimes B", "<mo>⊠</mo>")
        assertMathMlContains("A \\curlywedge B", "<mo>⋏</mo>")
    }

    @TestCase
    func extendedSymbolCommandsShouldBeReportedAsSupported() {
        let renderer = MathRenderer()
        @Expect(renderer.supportsCommand("\\precsim"), true)
        @Expect(renderer.supportsCommand("\\subsetneqq"), true)
        @Expect(renderer.supportsCommand("\\boxtimes"), true)
        @Expect(renderer.supportsCommand("\\curlywedge"), true)
    }
}
