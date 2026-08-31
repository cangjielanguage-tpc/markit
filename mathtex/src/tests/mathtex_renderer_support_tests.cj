package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*
import mathtex.MathRenderer

@Test
@Tag[MathTex, MathTexIntegration]
class MathtexRendererSupportTests {
    @TestCase
    func supportsCommandShouldAcceptLeadingBackslash() {
        let renderer = MathRenderer()
        @Expect(renderer.supportsCommand("\\frac"), true)
        @Expect(renderer.supportsCommand("\\sqrt"), true)
        @Expect(renderer.supportsCommand("\\textcolor"), true)
        @Expect(renderer.supportsCommand("\\lVert"), true)
    }

    @TestCase
    func supportsCommandShouldAcceptBareCommandName() {
        let renderer = MathRenderer()
        @Expect(renderer.supportsCommand("operatorname"), true)
        @Expect(renderer.supportsCommand("tag"), true)
        @Expect(renderer.supportsCommand("url"), true)
        @Expect(renderer.supportsCommand("newcommand"), true)
        @Expect(renderer.supportsCommand("renewcommand"), true)
        @Expect(renderer.supportsCommand("providecommand"), true)
    }

    @TestCase
    func supportsCommandShouldRejectUnknownCommandName() {
        let renderer = MathRenderer()
        @Expect(renderer.supportsCommand("\\definitelyNotKatex"), false)
        @Expect(renderer.supportsCommand("definitelyNotKatex"), false)
    }
}
