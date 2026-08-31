package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexMacro]
class KatexNewcommandMacroTests {
    @TestCase
    func migratedKatexNewcommandShouldDefineSimpleMacros() {
        // Source: test/katex-spec.ts / describe("A macro expander") / "\\newcommand defines new macros".
        assertRendersAll([
            "\\newcommand\\foo{x^2}\\foo+\\foo",
            "\\newcommand{\\foo}{x^2}\\foo+\\foo"
        ])
    }

    @TestCase
    func migratedKatexNewcommandShouldAcceptArgumentCount() {
        // Source: test/katex-spec.ts / "\\newcommand accepts number of arguments".
        assertTypstEquals("\\newcommand\\sq[1]{#1^2}\\sq{x}+\\sq y", "$x^2 + y^2$")
        assertTypstEquals("\\newcommand\\sq[10]{#1^2}\\sq 0", "$0^2$")
    }

    @TestCase
    func migratedKatexRenewcommandShouldRedefineExistingUserMacro() {
        // Source: test/katex-spec.ts / "\\renewcommand redefines macros".
        assertTypstEquals("\\newcommand{\\foo}{x}\\foo\\renewcommand{\\foo}{y}\\foo", "$x y$")
    }

    @TestCase
    func migratedKatexProvidecommandShouldNotRedefineExistingMacro() {
        // Source: test/katex-spec.ts / "\\providecommand defines but does not redefine macros".
        assertTypstEquals("\\providecommand{\\foo}{x}\\foo\\providecommand{\\foo}{y}\\foo", "$x x$")
        assertTypstEquals("\\providecommand{\\foo}{x}\\foo\\renewcommand{\\foo}{y}\\foo", "$x y$")
    }

    @TestCase
    func migratedKatexNewcommandShouldRejectInvalidDefinitions() {
        // Source: test/katex-spec.ts / newcommand and renewcommand error cases.
        assertErrorsAll([
            "\\newcommand\\lambda{x^2}",
            "\\newcommand{\\foo}{1}\\newcommand{\\foo}{2}",
            "\\renewcommand\\foo{x^2}",
            "\\newcommand\\foo[x]{}",
            "\\newcommand\\foo[1.5]{}"
        ])
    }
}
