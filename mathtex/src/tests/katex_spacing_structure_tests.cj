package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexStructure, KatexHtml, KatexSpacing]
class KatexSpacingStructureTests {
    @TestCase
    func migratedKatexQuadShouldRenderOneEmMspace() {
        // Source: src/functions/symbolsSpacing.ts spacing builders.
        assertHtmlContains("x \\quad y", "class=\"mspace\" style=\"margin-right:1em;\"></span>")
    }

    @TestCase
    func migratedKatexQquadShouldRenderTwoEmMspace() {
        // Source: src/functions/symbolsSpacing.ts spacing builders.
        assertHtmlContains("x \\qquad y", "class=\"mspace\" style=\"margin-right:2em;\"></span>")
    }

    @TestCase
    func migratedKatexCdotsShouldRenderCenteredEllipsisSymbol() {
        // Source: src/symbols.js math main symbols.
        assertHtmlContains("x + \\cdots + 1", "<span class=\"katex-symbol mord\">⋯</span>")
        assertMathMlContains("x + \\cdots + 1", "<mi>⋯</mi>")
    }

    @TestCase
    func migratedKatexPairSpacingShouldRespectNeighborAtomFamilies() {
        // Source: KaTeX spacing table behavior for bin/rel around open, close, punct, and operators.
        assertHtmlContains("(x)+y", "<span class=\"katex-symbol mclose\">)</span><span class=\"mspace\" style=\"margin-right:0.2222em;\"></span><span class=\"katex-symbol mbin\">+</span>")
        assertHtmlContains("x+(y)", "<span class=\"katex-symbol mbin\">+</span><span class=\"mspace\" style=\"margin-right:0.2222em;\"></span>")
        assertHtmlContains("(+x)", "<span class=\"katex-symbol mopen\">(</span><span class=\"katex-symbol mbin\">+</span>")
        assertHtmlContains("x, y", "<span class=\"katex-symbol mpunct\">,</span><span class=\"katex-symbol mord mathnormal\">y</span>")
        assertHtmlContains("\\sin x", "<span class=\"katex-symbol mop\">sin</span><span class=\"mspace\" style=\"margin-right:0.1667em;\"></span><span class=\"katex-symbol mord mathnormal\">x</span>")
    }

    @TestCase
    func migratedKatexBinSpacingShouldNotDuplicateAroundOpenAtoms() {
        // Source: KaTeX spacing table for bin atoms around mopen/mclose.
        assertHtmlContains("(+x)", "<span class=\"katex-symbol mopen\">(</span><span class=\"katex-symbol mbin\">+</span>")
        assertHtmlContains("x+(y)", "<span class=\"katex-symbol mbin\">+</span><span class=\"mspace\" style=\"margin-right:0.2222em;\"></span>")
    }

    @TestCase
    func migratedKatexRelationSpacingShouldStayAroundRelations() {
        // Source: KaTeX spacing table for relation atoms.
        assertHtmlContains("a=b", "<span class=\"mspace\" style=\"margin-right:0.2778em;\"></span><span class=\"katex-symbol mrel\">=</span><span class=\"mspace\" style=\"margin-right:0.2778em;\"></span>")
        assertHtmlContains("a\\le b", "<span class=\"katex-symbol mrel\">≤</span><span class=\"mspace\" style=\"margin-right:0.2778em;\"></span>")
    }

    @TestCase
    func migratedKatexPunctuationShouldNotAddMathbinSpacing() {
        // Source: KaTeX punctuation atom behavior.
        assertHtmlContains("x, y", "<span class=\"katex-symbol mpunct\">,</span><span class=\"katex-symbol mord mathnormal\">y</span>")
        assertHtmlContains("x,+y", "<span class=\"katex-symbol mpunct\">,</span><span class=\"katex-symbol mbin\">+</span>")
    }

    @TestCase
    func migratedKatexOperatorSpacingShouldStayThinBeforeArguments() {
        // Source: KaTeX operator spacing for named operators.
        assertHtmlContains("\\log n", "<span class=\"katex-symbol mop\">log</span><span class=\"mspace\" style=\"margin-right:0.1667em;\"></span><span class=\"katex-symbol mord mathnormal\">n</span>")
        assertHtmlContains("\\sin(x)", "<span class=\"katex-symbol mop\">sin</span><span class=\"katex-symbol mopen\">(</span>")
    }
}
