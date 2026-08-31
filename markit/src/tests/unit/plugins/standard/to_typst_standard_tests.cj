package markit.tests.unit.plugins.standard

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

@Test
class ToTypstStandardTests {
    @TestCase
    func inlineFormattingMatchesLegacyTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            { => Markit() },
            "**bold** *italic* `code`\n",
            "*bold* _italic_ #markit-inline-code(\"code\")\\u{2060}\n\n"
        )
    }

    @TestCase
    func inlineCodeWithCommentPrefixMatchesLegacyTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            { => Markit() },
            "`//`\n",
            "#markit-inline-code(\"//\")\\u{2060}\n\n"
        )
    }

    @TestCase
    func linkImageBlockquoteBreaksAndHeadingAnchorsMatchLegacyTypstAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            { => Markit() },
            "# Section\n\n[site](https://example.com) ![logo](logo.png)\n\n> line 1  \n> line 2\n",
            "= Section <section>\n\n#link(\"https://example.com\")[site] #image(\"logo.png\", alt: \"logo\")\n\n#quote(block: true)[\nline 1#linebreak()line 2\n]\n\n"
        )
    }
}
