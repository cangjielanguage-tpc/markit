package markit.tests.unit.source

import std.unittest.*
import std.unittest.testmacro.*
import markit.core.editing.*
import markit.core.source.*

@Test
class EditableSourceMapTests {
    @TestCase
    func retainedRangesRemovePrefixesAndIndentWithoutSyntaxKnowledge() {
        let source = EditableRopeVersion("raw", "> A\r\n>   B\r\n")
        let builder = MappedTextBuilder()
        builder.appendSource(source, 2, 3)
        builder.appendSynthetic("\n")
        builder.appendSource(source, 9, 10)
        let mapped = builder.build()
        @Expect(mapped.text, "A\nB")
        @Expect(mapped.sourceMap.mapByte(0, AnchorAffinity.After).getOrThrow().byteOffset, 2)
        @Expect(mapped.sourceMap.mapByte(1, AnchorAffinity.Before).getOrThrow().byteOffset, 3)
        @Expect(mapped.sourceMap.mapByte(1, AnchorAffinity.After).isNone(), true)
        @Expect(mapped.sourceMap.mapByte(2, AnchorAffinity.Before).isNone(), true)
        @Expect(mapped.sourceMap.mapByte(2, AnchorAffinity.After).getOrThrow().byteOffset, 9)
        @Expect(mapped.sourceMap.segments(0, 3)[1].synthetic, true)
    }

    @TestCase
    func normalizedCrLfAndJoinedLinesKeepExactRawEndpoints() {
        let source = EditableRopeVersion("raw", "> A\r\n>   B\r\n", version: 7)
        let builder = MappedTextBuilder()
        builder.appendNormalized(source, 2, 5)
        builder.appendNormalized(source, 9, 12)
        let mapped = builder.build()
        @Expect(mapped.text, "A\nB\n")
        @Expect(mapped.sourceMap.mapByte(2, AnchorAffinity.Before).getOrThrow().byteOffset, 5)
        @Expect(mapped.sourceMap.mapByte(2, AnchorAffinity.After).getOrThrow().byteOffset, 9)
        let pieces = mapped.sourceMap.segments(1, 3)
        @Expect(pieces.size, 2)
        @Expect(pieces[0].viewStart, 1)
        @Expect(pieces[0].rawStart, 3)
        @Expect(pieces[0].rawEnd, 5)
        @Expect(pieces[1].rawStart, 9)
        @Expect(pieces[1].source.version, 7)
    }

    @TestCase
    func compositionPreservesDisjointOriginsAndBoundaryAffinity() {
        let source = EditableRopeVersion("raw", "> A\r\n>   B\r\n")
        let parentBuilder = MappedTextBuilder()
        parentBuilder.appendNormalized(source, 2, 5)
        parentBuilder.appendNormalized(source, 9, 12)
        let parent = parentBuilder.build()
        let intermediate = EditableRopeVersion("intermediate", parent.text)
        let childBuilder = MappedTextBuilder()
        childBuilder.appendSource(intermediate, 0, 1)
        childBuilder.appendSource(intermediate, 2, 3)
        let child = childBuilder.build()
        let composed = child.sourceMap.compose(parent.sourceMap)
        @Expect(child.text, "AB")
        @Expect(composed.mapByte(1, AnchorAffinity.Before).getOrThrow().byteOffset, 3)
        @Expect(composed.mapByte(1, AnchorAffinity.After).getOrThrow().byteOffset, 9)
        @Expect(composed.mapByte(1, AnchorAffinity.After).getOrThrow().source.documentId, "raw")
        let pieces = composed.segments(0, 2)
        @Expect(pieces.size, 2)
        @Expect(pieces[0].rawStart, 2)
        @Expect(pieces[0].rawEnd, 3)
        @Expect(pieces[1].rawStart, 9)
        @Expect(pieces[1].rawEnd, 10)
        let onlySecond = MappedTextBuilder()
        onlySecond.appendSource(intermediate, 2, 3)
        let secondMap = onlySecond.build().sourceMap.compose(parent.sourceMap)
        @Expect(secondMap.mapByte(0, AnchorAffinity.Before).getOrThrow().byteOffset, 9)
        @Expect(secondMap.mapByte(0, AnchorAffinity.Before).getOrThrow().affinity == AnchorAffinity.Before, true)
    }

    @TestCase
    func lengthChangingTransformsNeverInventInteriorAnchorOrEnclosingSpan() {
        let identity = SourceVersionIdentity("raw", 0)
        let parent = SegmentSourceMap([
            SourceMappingSegment(0, 1, 2, 3, identity),
            SourceMappingSegment(1, 3, 9, 11, identity)
        ])
        let intermediate = EditableRopeVersion("intermediate", "abc")
        let builder = MappedTextBuilder()
        builder.appendTransformed("XY", intermediate, 0, 3)
        let map = builder.build().sourceMap.compose(parent)
        @Expect(map.mapByte(0, AnchorAffinity.After).getOrThrow().byteOffset, 2)
        @Expect(map.mapByte(1, AnchorAffinity.After).isNone(), true)
        @Expect(map.mapByte(2, AnchorAffinity.Before).getOrThrow().byteOffset, 11)
        let pieces = map.segments(0, 2)
        @Expect(pieces.size, 2)
        @Expect(pieces[0].rawStart, 2)
        @Expect(pieces[0].rawEnd, 3)
        @Expect(pieces[1].rawStart, 9)
        @Expect(pieces[1].rawEnd, 11)
    }

    @TestCase
    func localQueriesAndBuilderSnapshotsOwnTheirMappingArrays() {
        let identity = SourceVersionIdentity("raw", 0)
        let input = [SourceMappingSegment(0, 6, 10, 16, identity)]
        let map = SegmentSourceMap(input)
        input[0] = SourceMappingSegment(0, 6, 30, 36, identity)
        let pieces = map.segments(2, 4)
        @Expect(pieces.size, 1)
        @Expect(pieces[0].rawStart, 12)
        @Expect(pieces[0].rawEnd, 14)
        pieces[0] = SourceMappingSegment(2, 4, 40, 42, identity)
        @Expect(map.mapByte(3, AnchorAffinity.After).getOrThrow().byteOffset, 13)
        @Expect(map.segments(3, 3).isEmpty(), true)
        @Expect(map.mapByte(7, AnchorAffinity.After).isNone(), true)
        let builder = MappedTextBuilder()
        builder.appendSynthetic("one")
        let first = builder.build()
        builder.appendSynthetic("two")
        @Expect(first.text, "one")
        @Expect(first.sourceMap.segments(0, 6).size, 1)
        @Expect(builder.build().text, "onetwo")
    }
}
