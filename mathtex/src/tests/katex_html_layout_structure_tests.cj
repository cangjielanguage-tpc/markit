package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexHtml, KatexLayout]
class KatexHtmlLayoutStructureTests {
    @TestCase
    func migratedKatexFractionShouldExposeMfracVlistAndRuleClasses() {
        // Source: src/functions/genfrac.ts HTML builder structure.
        let tex = "\\frac{a}{b}"
        assertHtmlContains(tex, "class=\"mord katex-frac-wrap\"")
        assertHtmlContains(tex, "class=\"mfrac katex-frac\"")
        assertHtmlContains(tex, "class=\"vlist-t vlist-t2\"")
        assertHtmlContains(tex, "class=\"vlist-r\"")
        assertHtmlContains(tex, "class=\"vlist\"")
        assertHtmlContains(tex, "class=\"frac-line katex-frac-line\"")
        assertHtmlContains(tex, "class=\"vlist-s\">&#8203;</span>")
    }

    @TestCase
    func migratedKatexScriptsShouldExposeMsupsubVlistAndTightSizingClasses() {
        // Source: src/functions/supsub.ts HTML builder structure.
        let tex = "x_i^2"
        assertHtmlContains(tex, "class=\"mord katex-scripts\"")
        assertHtmlContains(tex, "class=\"msupsub katex-msupsub\"")
        assertHtmlContains(tex, "class=\"vlist-t\"")
        assertHtmlContains(tex, "class=\"sizing reset-size6 size3 mtight katex-script katex-sub\"")
        assertHtmlContains(tex, "class=\"sizing reset-size6 size3 mtight katex-script katex-sup\"")
    }

    @TestCase
    func migratedKatexSqrtShouldExposeMordSqrtAndCopyableRadical() {
        // Source: src/functions/sqrt.ts HTML builder.
        let tex = "\\sqrt{x}"
        assertHtmlContains(tex, "class=\"mord sqrt katex-sqrt\"")
        assertHtmlContains(tex, "class=\"svg-align\" style=\"top:-3em;\"")
        assertHtmlContains(tex, "class=\"hide-tail\" style=\"min-width:0.853em;height:1.08em;display:inline-block;\"")
        assertHtmlContains(tex, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400em\" height=\"1.08em\"")
    }
}
