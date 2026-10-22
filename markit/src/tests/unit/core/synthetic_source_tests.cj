package markit.tests.unit.core

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.source.{SourceLine, SourceSpan, SyntheticSourceBuilder}

@Test
class SyntheticSourceTests {
    @TestCase
    func restoresPerLineByteAndRuneOriginsAfterPrefixRemoval() {
        let lines = ArrayList<SourceLine>()
        // Different stripped prefixes, a CRLF gap, and multi-byte characters.
        lines.add(SourceLine("甲😀", SourceSpan(20, 29, 10, 14), terminated: true))
        lines.add(SourceLine("English", SourceSpan(31, 43, 15, 27)))
        let synthetic = SyntheticSourceBuilder.build(lines)
        let first = synthetic.mapSpan(SourceSpan(0, 7, 0, 2))
        @Expect(first.startByte, 22)
        @Expect(first.endByte, 29)
        @Expect(first.startRune, 12)
        @Expect(first.endRune, 14)
        let second = synthetic.mapSpan(SourceSpan(8, 15, 3, 10))
        @Expect(second.startByte, 36)
        @Expect(second.endByte, 43)
        @Expect(second.startRune, 20)
        @Expect(second.endRune, 27)
        let both = synthetic.mapSpan(SourceSpan(3, 15, 1, 10))
        @Expect(both.startByte, 25)
        @Expect(both.endByte, 43)
        @Expect(both.startRune, 13)
        @Expect(both.endRune, 27)
    }

    @TestCase
    func generatedPaddingForPartialTabNeverMapsBeforeOriginalLine() {
        let lines = ArrayList<SourceLine>()
        // Original "\tHello" becomes "  Hello" after removing two columns.
        lines.add(SourceLine("  Hello", SourceSpan(20, 26, 10, 16)))
        let synthetic = SyntheticSourceBuilder.build(lines)
        let paragraph = synthetic.mapSpan(SourceSpan(0, 7, 0, 7))
        @Expect(paragraph.startByte, 20)
        @Expect(paragraph.endByte, 26)
        @Expect(paragraph.startRune, 10)
        @Expect(paragraph.endRune, 16)
        let text = synthetic.mapSpan(SourceSpan(2, 7, 2, 7))
        @Expect(text.startByte, 21)
        @Expect(text.startRune, 11)
    }

}
