package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexHtml, KatexFont]
class KatexHtmlFontBuilderMigrationTests {
    @TestCase
    func migratedKatexHtmlFontMathbbShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\mathbb{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontMathrmShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\mathrm{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontMathcalShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\mathcal{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontMathfrakShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\mathfrak{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\text{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextitShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textit{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontNestedTextitShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\text{\\textit{R}}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextupShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textup{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextupInsideTextitShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textit{\\textup{R}}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextitInsideTextupShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textup{\\textit{R}}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextWithNestedTextitShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\text{R\\textit{S}T}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextbfShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textbf{R }"])
    }

    @TestCase
    func migratedKatexHtmlFontTextmdShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textmd{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextmdInsideTextbfShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textbf{\\textmd{R}}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextbfInsideTextmdShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textmd{\\textbf{R}}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextsfShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textsf{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextsfNestedStylesShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textsf{\\textit{R}G\\textbf{B}}"])
    }

    @TestCase
    func migratedKatexHtmlFontTextttShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\texttt{R}"])
    }

    @TestCase
    func migratedKatexHtmlFontColorThenMathbbShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\textcolor{blue}{\\mathbb R}"])
    }

    @TestCase
    func migratedKatexHtmlFontMathbbThenColorShouldRender() {
        // Source: test/katex-spec.ts / describe("An HTML font tree-builder")
        assertRendersAll(["\\mathbb{\\textcolor{blue}{R}}"])
    }
}
