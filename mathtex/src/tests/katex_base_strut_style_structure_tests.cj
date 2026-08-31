package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexHtml, KatexStyle, KatexLayout]
class KatexBaseStrutStyleStructureTests {
    @TestCase
    func migratedKatexInlineAtomsShouldUseBaseAndStrutRuns() {
        // Source: KaTeX renderToString("x+y=2") HTML builder output.
        let tex = "x+y=2"
        assertHtmlContains(tex, "<span class=\"base\"><span class=\"strut\" style=\"height:0.6667em;vertical-align:-0.0833em;\"></span>")
        assertHtmlContains(tex, "<span class=\"base\"><span class=\"strut\" style=\"height:0.625em;vertical-align:-0.1944em;\"></span>")
        assertHtmlContains(tex, "<span class=\"base\"><span class=\"strut\" style=\"height:0.6444em;\"></span>")
    }

    @TestCase
    func migratedKatexDisplaystyleFractionShouldUseDisplayMetrics() {
        // Source: KaTeX renderToString("\\displaystyle{\\frac{a}{b}}+x") genfrac builder output.
        let tex = "\\displaystyle{\\frac{a}{b}}+x"
        assertHtmlContains(tex, "<span class=\"base\"><span class=\"strut\" style=\"height:1.7936em;vertical-align:-0.686em;\"></span>")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:1.1076em;\"")
        assertHtmlContains(tex, "<span style=\"top:-2.314em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"mord\">")
        assertHtmlContains(tex, "<span style=\"top:-3.677em;\"><span class=\"pstrut\" style=\"height:3em;\"></span><span class=\"mord\">")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:0.686em;\"")
    }

    @TestCase
    func migratedKatexScriptFractionShouldUseTightScriptMetrics() {
        // Source: KaTeX renderToString("x^{\\frac{a}{b}}") genfrac builder output in scriptstyle.
        let tex = "x^{\\frac{a}{b}}"
        assertHtmlContains(tex, "class=\"frac-line katex-frac-line mtight\" style=\"border-bottom-width:0.049em;\"")
        assertHtmlContains(tex, "class=\"sizing reset-size3 size1 mtight katex-frac-den\"")
        assertHtmlContains(tex, "class=\"sizing reset-size3 size1 mtight katex-frac-num\"")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:0.6915em;\"")
        assertHtmlContains(tex, "class=\"vlist\" style=\"height:0.344em;\"")
    }
}
