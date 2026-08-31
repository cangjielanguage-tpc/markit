package markit.tests.unit.plugins.commonmark

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func commonMark(): Markit {
    return Markit(CommonMarkBundle())
}

@Test
class ToTypstCommonMarkTests {
    @TestCase
    func htmlInlineFallsBackToRawAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            commonMark,
            "before <span>ok</span> after\n",
            "before [#raw(\"<span>ok</span>\")] after\n\n"
        )
    }

    @TestCase
    func htmlBlockFallsBackToRawBlockAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            commonMark,
            "<div>ok</div>\n",
            "``````\n<div>ok</div>\n\n``````\n\n"
        )
    }

    @TestCase
    func entityReferenceTypstUsesDecodedBasicCharacterAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMark,
            "&lt;\n",
            { result: ParseModeResult =>
                @Expect(result.typst, "\\<\n\n")
            }
        )
    }
}
