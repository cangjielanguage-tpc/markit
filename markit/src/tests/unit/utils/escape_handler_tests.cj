package markit.tests.unit.utils

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.utils.EscapeHandler
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

@Test
class EscapeHandlerTests {
    @TestCase
    func recognizesLegacyEscapableAsciiPunctuation() {
        @Expect(EscapeHandler.isEscapable(r'\\'), true)
        @Expect(EscapeHandler.isEscapable(r'`'), true)
        @Expect(EscapeHandler.isEscapable(r'*'), true)
        @Expect(EscapeHandler.isEscapable(r'_'), true)
        @Expect(EscapeHandler.isEscapable(r'['), true)
        @Expect(EscapeHandler.isEscapable(r']'), true)
        @Expect(EscapeHandler.isEscapable(r'#'), true)
        @Expect(EscapeHandler.isEscapable(r'|'), true)
        @Expect(EscapeHandler.isEscapable(r'$'), true)

        @Expect(EscapeHandler.isEscapable(r'a'), false)
        @Expect(EscapeHandler.isEscapable(r'1'), false)
        @Expect(EscapeHandler.isEscapable(r'中'), false)
    }

    @TestCase
    func processEscapesPreservesUnicodeAndInvalidEscapesExactly() {
        @Expect(EscapeHandler.processEscapes("\\*粗体\\* and \\[link\\]"), "*粗体* and [link]")
        @Expect(EscapeHandler.processEscapes("\\a 中文 🚀 \\\\"), "\\a 中文 🚀 \\")
        @Expect(EscapeHandler.processEscapes("\\中 and \\🚀"), "\\中 and \\🚀")
        @Expect(EscapeHandler.unescapeText("This is \\*not\\* bold"), "This is *not* bold")
        @Expect(EscapeHandler.escapeSpecialChars("*中_[x](y)!"), "\\*中\\_\\[x\\]\\(y\\)\\!")
        @Expect(EscapeHandler.getEscapeLength("\\*normal\\a", 0), 2)
        @Expect(EscapeHandler.getEscapeLength("\\*normal\\a", 2), 0)
        @Expect(EscapeHandler.getEscapeLength("\\*normal\\a", 8), 1)
        @Expect(EscapeHandler.getEscapeLength("\\", 0), 1)
        @Expect(EscapeHandler.getEscapeLength("\\中", 0), 1)
    }

    @TestCase
    func escapedInlineSyntaxRendersAsLiteralTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "\\# heading\n\\*italic\\* \\[link\\](url) \\`code\\`\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p># heading\n*italic* [link](url) `code`</p>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectNoNode(result.root, "Heading1Node")
                AstTestKit.expectNoNode(result.root, "LinkNode")
                AstTestKit.expectNoNode(result.root, "InlineCodeNode")
                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                AstTestKit.child(paragraph, 1, "SoftBreakNode")
                AstTestKit.expectNoNode(result.root, "ItalicNode")
                AstTestKit.expectSpan(paragraph, 0, 44, 0, 44)
            }
        )
    }
}
