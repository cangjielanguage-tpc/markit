package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[MathTex, MathTexHtml, KatexMigration, KatexStructure, KatexAccent, KatexArrow]
class KatexStretchyArrowStructureTests {
    @TestCase
    func migratedKatexOverAndUnderArrowAccentsShouldUseStretchySvg() {
        // Sources:
        // - KaTeX src/functions/accent.ts stretchy accent names.
        // - KaTeX src/functions/accentunder.ts under-accent names.
        assertHtmlContains("\\overleftarrow{AB}", "class=\"mord accent katex-over-accent katex-cmd-overleftarrow\"")
        assertHtmlContains("\\overleftarrow{AB}", "class=\"hide-tail\" style=\"height:0.522em;min-width:0.888em;\"")
        assertHtmlContains("\\overleftarrow{AB}", "preserveAspectRatio=\"xMinYMin slice\"")
        assertHtmlContains("\\overleftrightarrow{AB}", "class=\"stretchy\" style=\"height:0.522em;min-width:0.888em;\"")
        assertHtmlContains("\\overleftrightarrow{AB}", "class=\"halfarrow-left\" style=\"height:0.522em;\"")
        assertHtmlContains("\\overleftrightarrow{AB}", "class=\"halfarrow-right\" style=\"height:0.522em;\"")
        assertHtmlContains("\\underleftarrow{AB}", "class=\"mord accent katex-under-accent katex-cmd-underleftarrow\"")
        assertHtmlContains("\\underleftrightarrow{AB}", "class=\"stretchy\" style=\"height:0.522em;min-width:0.888em;\"")
        assertMathMlContains("\\overleftarrow{AB}", "<mo stretchy=\"true\">←</mo>")
        assertMathMlContains("\\underleftrightarrow{AB}", "<mo stretchy=\"true\">↔</mo>")
    }

    @TestCase
    func migratedKatexXArrowShouldPreserveAboveAndBelowArguments() {
        // Source: KaTeX src/functions/arrow.ts xArrow builder.
        assertHtmlContains("\\xrightarrow{x}", "class=\"mrel x-arrow katex-x-arrow katex-cmd-xrightarrow\"")
        assertHtmlContains("\\xrightarrow{x}", "class=\"sizing reset-size6 size3 mtight x-arrow-pad\"")
        assertHtmlContains("\\xrightarrow{x}", "class=\"hide-tail\" style=\"height:0.522em;min-width:1.469em;\"")
        assertHtmlContains("\\xleftarrow{x}", "preserveAspectRatio=\"xMinYMin slice\"")
        assertHtmlContains("\\xleftrightarrow{x}", "class=\"stretchy\" style=\"height:0.522em;min-width:1.75em;\"")
        assertHtmlContains("\\xlongequal{x}", "class=\"hide-tail\" style=\"height:0.334em;min-width:0.888em;\"")
        assertHtmlContains("\\xrightarrow[under]{over}", "<span class=\"katex-symbol mord mathnormal mtight\">o</span>")
        assertHtmlContains("\\xrightarrow[under]{over}", "<span class=\"katex-symbol mord mathnormal mtight\">u</span>")
        assertMathMlContains("\\xrightarrow{x}", "<mover><mo stretchy=\"true\" minsize=\"3.0em\">→</mo><mpadded width=\"+0.6em\" lspace=\"0.3em\">")
        assertMathMlContains("\\xrightarrow[under]{over}", "<munderover><mo stretchy=\"true\" minsize=\"3.0em\">→</mo>")
    }

    @TestCase
    func migratedKatexExtendedXArrowsShouldUseKaTeXStretchyContainers() {
        // Source: KaTeX src/functions/arrow.ts xArrow names and src/stretchy.ts path metadata.
        let arrows = [
            "\\xhookleftarrow{abc}",
            "\\xhookrightarrow{abc}",
            "\\xmapsto{abc}",
            "\\xtwoheadleftarrow{abc}",
            "\\xtwoheadrightarrow{abc}",
            "\\xrightleftharpoons{abc}",
            "\\xleftrightharpoons{abc}",
            "\\xtofrom{abc}",
            "\\xrightleftarrows{abc}",
            "\\xrightequilibrium{abc}",
            "\\xleftequilibrium{abc}"
        ]
        assertRendersAll(arrows)
        assertHtmlContains("\\xhookleftarrow{abc}", "class=\"stretchy\" style=\"height:0.522em;min-width:1.08em;\"")
        assertHtmlContains("\\xmapsto{abc}", "class=\"stretchy\" style=\"height:0.522em;min-width:1.5em;\"")
        assertHtmlContains("\\xrightleftharpoons{abc}", "class=\"stretchy\" style=\"height:0.716em;min-width:1.75em;\"")
        assertHtmlContains("\\xrightleftarrows{abc}", "class=\"stretchy\" style=\"height:0.901em;min-width:1.75em;\"")
        assertMathMlContains("\\xhookrightarrow{abc}", "<mo stretchy=\"true\" minsize=\"3.0em\">↪</mo>")
        assertMathMlContains("\\xmapsto{abc}", "<mo stretchy=\"true\" minsize=\"3.0em\">↦</mo>")
    }

    @TestCase
    func migratedKatexDoubleXArrowsShouldUseDoubleArrowMetrics() {
        // Source: KaTeX src/stretchy.ts xLeftarrow/xRightarrow/xLeftrightarrow metrics.
        assertHtmlContains("\\xLeftarrow{abc}", "class=\"hide-tail\" style=\"height:0.56em;min-width:1.526em;\"")
        assertHtmlContains("\\xRightarrow{abc}", "class=\"hide-tail\" style=\"height:0.56em;min-width:1.526em;\"")
        assertHtmlContains("\\xLeftrightarrow{abc}", "class=\"stretchy\" style=\"height:0.56em;min-width:1.75em;\"")
        assertMathMlContains("\\xLeftrightarrow{abc}", "<mo stretchy=\"true\" minsize=\"3.0em\">⇔</mo>")
    }

    @TestCase
    func migratedKatexHookAndMapstoXArrowsShouldKeepTwoPartSvgShape() {
        // Source: KaTeX src/stretchy.ts xhookleftarrow/xhookrightarrow/xmapsto entries.
        assertHtmlContains("\\xhookleftarrow{abc}", "class=\"halfarrow-left\" style=\"height:0.522em;\"")
        assertHtmlContains("\\xhookrightarrow{abc}", "class=\"halfarrow-right\" style=\"height:0.522em;\"")
        assertHtmlContains("\\xmapsto{abc}", "viewBox=\"0 0 400000 522\" preserveAspectRatio=\"xMinYMin slice\"")
    }

    @TestCase
    func migratedKatexHarpoonXArrowsShouldKeepTallStretchyMetrics() {
        // Source: KaTeX src/stretchy.ts xrightleftharpoons/xleftrightharpoons metrics.
        assertHtmlContains("\\xrightleftharpoons{abc}", "class=\"stretchy\" style=\"height:0.716em;min-width:1.75em;\"")
        assertHtmlContains("\\xleftrightharpoons{abc}", "class=\"stretchy\" style=\"height:0.716em;min-width:1.75em;\"")
        assertHtmlContains("\\xrightleftharpoons{abc}", "class=\"halfarrow-left\" style=\"height:0.716em;\"")
        assertHtmlContains("\\xrightleftharpoons{abc}", "class=\"halfarrow-right\" style=\"height:0.716em;\"")
        assertHtmlContains("\\xrightleftharpoons{abc}", "M7 435c-4 4-6.3 8.7-7 14")
        assertHtmlContains("\\xrightleftharpoons{abc}", "m100 194v40h399900v-40z")
        assertHtmlContains("\\xrightleftharpoons{abc}", "height:1.3131em;vertical-align:-0.108em;")
        assertHtmlContains("\\xrightleftharpoons{abc}", "style=\"height:1.2051em;\"")
        assertHtmlContains("\\xrightleftharpoons{abc}", "style=\"top:-3.435em;\"")
        assertHtmlContains("\\xrightleftharpoons{abc}", "style=\"top:-2.608em;\"")
        assertMathMlContains("\\xrightleftharpoons{abc}", "<mo stretchy=\"true\" minsize=\"3.0em\">⇌</mo>")
    }

    @TestCase
    func migratedKatexTwoheadAndToFromXArrowsShouldUseSpecificMetrics() {
        // Source: KaTeX src/stretchy.ts xtwohead*/xtofrom/xrightleftarrows metrics.
        assertHtmlContains("\\xtwoheadleftarrow{abc}", "class=\"hide-tail\" style=\"height:0.334em;min-width:1.469em;\"")
        assertHtmlContains("\\xtwoheadrightarrow{abc}", "class=\"hide-tail\" style=\"height:0.334em;min-width:1.469em;\"")
        assertHtmlContains("\\xtofrom{abc}", "class=\"stretchy\" style=\"height:0.528em;min-width:1.75em;\"")
        assertHtmlContains("\\xrightleftarrows{abc}", "class=\"stretchy\" style=\"height:0.901em;min-width:1.75em;\"")
        assertHtmlContains("\\xtofrom{abc}", "M0 147h400000v40H0")
        assertHtmlContains("\\xtofrom{abc}", "M400000 167c-70.7-42-118-97.7-142-167")
        assertHtmlContains("\\xrightleftarrows{abc}", "M400000 620h-399890")
        assertHtmlContains("\\xrightleftarrows{abc}", "M0 241v40h399891")
        assertHtmlContains("\\xtwoheadrightarrow{abc}", "M400000 167c-68-40-115.7-95.7-143-167")
        assertHtmlContains("\\xtofrom{abc}", "height:1.1251em;vertical-align:-0.014em;")
        assertHtmlContains("\\xtofrom{abc}", "style=\"top:-3.325em;\"")
        assertHtmlContains("\\xtofrom{abc}", "style=\"top:-2.686em;\"")
        assertHtmlContains("\\xrightleftarrows{abc}", "height:1.4981em;vertical-align:-0.2005em;")
        assertHtmlContains("\\xrightleftarrows{abc}", "style=\"height:1.2976em;\"")
        assertHtmlContains("\\xrightleftarrows{abc}", "style=\"top:-3.7125em;\"")
        assertHtmlContains("\\xrightleftarrows{abc}", "style=\"top:-2.7005em;\"")
    }

    @TestCase
    func migratedKatexHorizontalBracketsAndGroupsShouldUseTwoPartStretchySvg() {
        // Source: KaTeX src/functions/horizBrace.ts and src/stretchy.ts over/under bracket/group/line segment builders.
        assertHtmlContains("\\overbracket{AB}", "class=\"mord accent katex-over-accent katex-cmd-overbracket\"")
        assertHtmlContains("\\overbracket{AB}", "class=\"stretchy\" style=\"height:0.44em;min-width:1.6em;\"")
        assertHtmlContains("\\underbracket{AB}", "class=\"mord accent katex-under-accent katex-cmd-underbracket\"")
        assertHtmlContains("\\underbracket{AB}", "class=\"stretchy\" style=\"height:0.41em;min-width:1.6em;\"")
        assertHtmlContains("\\overgroup{AB}", "class=\"stretchy\" style=\"height:0.342em;min-width:0.888em;\"")
        assertHtmlContains("\\overlinesegment{AB}", "class=\"stretchy\" style=\"height:0.522em;min-width:0.888em;\"")
        assertHtmlContains("\\overbracket{AB}^{n}", "class=\"minner mover\"")
        assertHtmlContains("\\underbracket{AB}_{n}", "class=\"minner munder\"")
        assertMathMlContains("\\overgroup{AB}", "<mo stretchy=\"true\">⏠</mo>")
        assertMathMlContains("\\undergroup{AB}", "<mo stretchy=\"true\">⏡</mo>")
    }

    @TestCase
    func migratedKatexHorizontalBracketScriptsShouldUseMoverAndMunder() {
        // Source: KaTeX src/functions/horizBrace.ts overbracket/underbracket script builders.
        assertHtmlContains("\\overbracket{AB}^{n}", "class=\"minner mover\"")
        assertHtmlContains("\\underbracket{AB}_{n}", "class=\"minner munder\"")
    }

    @TestCase
    func migratedKatexHorizontalGroupAndLineSegmentShouldUseSvgPairs() {
        // Source: KaTeX src/stretchy.ts overgroup/undergroup/overlinesegment/underlinesegment entries.
        assertHtmlContains("\\overgroup{AB}", "viewBox=\"0 0 400000 342\"")
        assertHtmlContains("\\undergroup{AB}", "viewBox=\"0 0 400000 342\"")
        assertHtmlContains("\\overlinesegment{AB}", "viewBox=\"0 0 400000 522\"")
        assertHtmlContains("\\underlinesegment{AB}", "viewBox=\"0 0 400000 522\"")
    }
}
