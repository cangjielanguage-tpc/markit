package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import seajson.JsonWriter
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.core.nodes.{Node, TextNode}
import markit.core.source.SourceSpan
import markit.plugins.toc.Toc
import markit.tests.utils.{EditingLegacyFixture, EditingLegacyInvariants, EditingLegacyNoticePlugin, ParseModeFixture, ParseModeResult, ParseModeTestKit}

private func recordLegacyResult(fixture: String, config: String, source: String, result: ParseModeResult): Unit {
    let w = JsonWriter()
    w.beginObject().name("fixture").value(fixture).name("config").value(config)
    w.name("mode").value(result.mode).name("source").value(source)
    w.name("html").value(result.html).name("markdown").value(result.markdown)
    w.name("typst").value(result.typst).name("astJson").value(result.json).name("tree").value(result.tree)
    w.name("emittedHtml").value(result.emittedHtml).name("updateCount").value(result.updateCount)
    w.name("sealedBlocks").value(result.sealedBlockCount).name("astPatches").value(result.astPatchCount)
    w.name("duplicateIds").beginArray()
    for (id in EditingLegacyInvariants.duplicateIds(result.root)) { w.value(id) }
    w.endArray().name("coordinateErrors").beginArray()
    for (failure in EditingLegacyInvariants.invalidCoordinates(result.root, source)) { w.value(failure) }
    w.endArray().endObject()
    println("EDITING_LEGACY_RESULT " + w.close())
}

@Test
@Tag[EditingOracle]
class EditingLegacyBaselineTests {
    @TestCase
    func recordsAllThirtyBuiltinPluginFixturesAcrossFourModes() {
        let fixtures = EditingLegacyFixture.builtinInventory()
        @Expect(fixtures.size, 30)
        for (fixture in fixtures) {
            let results = ParseModeTestKit.collect({ => fixture.createMarkit() }, fixture.markdown)
            @Expect(results.size, 4)
            for (result in results) {
                @Expect(result.finalUpdate.isFinal, true)
                @Expect(result.root.kind, "Document")
                recordLegacyResult(fixture.plugin, fixture.bundle, fixture.markdown, result)
                if (fixture.plugin == "TocPlugin") {
                    @Expect(Toc.parse(result.root).items.size, 1)
                }
            }
        }
    }

    @TestCase
    func unicodeCrLfPendingReprocessAndForwardReferenceBaseline() {
        let fixtures = [
            ParseModeFixture.withStringChunks("甲😀\r\n\r\n正文", ["甲", "😀", "\r", "\n", "\r", "\n", "正", "文"]),
            ParseModeFixture.withStringChunks("pending\n# heading\n", ["pending", "\n", "# heading", "\n"]),
            ParseModeFixture.withStringChunks("> quote\n# after\n", ["> quote", "\n", "# after\n"]),
            ParseModeFixture.withStringChunks("[name][id]\n\n[id]: /target", ["[name]", "[id]\n", "\n[id]: ", "/target"])
        ]
        var index: Int64 = 0
        for (fixture in fixtures) {
            for (result in ParseModeTestKit.collect({ => Markit() }, fixture)) {
                @Expect(result.finalUpdate.isFinal, true)
                recordLegacyResult("edge-${index}", "Standard.default/rune-single-byte", fixture.markdown, result)
            }
            index += 1
        }
    }

    @TestCase
    func frozenThirdPartyExtensionParsesAndAppendsWithoutEditDeclarations() {
        let source = "~note 甲😀\r\n!note second"
        for (result in ParseModeTestKit.collect({ => Markit().use(EditingLegacyNoticePlugin()) }, source)) {
            @Expect(result.html, "甲😀second")
            @Expect(result.root.children.size, 2)
            @Expect(result.root.children[0].literal, "甲😀")
            @Expect(result.root.children[1].literal, "second")
            recordLegacyResult("third-party-legacy-two-parsers", "Standard+LegacyNotice/1.0.0", source, result)
        }
    }

    @TestCase
    func duplicateIdsInProtectedInlineHtmlAreObservedRatherThanIgnored() {
        let source = "before <code>protected</code> after\n"
        for (result in ParseModeTestKit.collect({ => Markit(CommonMarkBundle()) }, source)) {
            recordLegacyResult("known-protected-html-duplicate-id", "CommonMark.default", source, result)
            @Expect(EditingLegacyInvariants.duplicateIds(result.root).size > 0, true)
        }
    }

    @TestCase
    func correctedQuoteMappingRemainsPreciseAndSyntheticCorruptionIsDetected() {
        let source = "prefix\n\n> 甲😀\n"
        for (result in ParseModeTestKit.collect({ => Markit() }, source)) {
            let quoteNode = result.root.children[1]
            let text = quoteNode.children[0].children[0]
            @Expect(text.literal, "甲😀")
            @Expect(text.sourceSpan.startByte, 10)
            @Expect(text.sourceSpan.endByte, 17)
            @Expect(text.sourceSpan.startRune, 10)
            @Expect(text.sourceSpan.endRune, 12)
            @Expect(text.rawContent(), "甲😀")
            @Expect(EditingLegacyInvariants.literalSliceMatches(text, source), true)
            recordLegacyResult("corrected-quote-map", "Standard.default", source, result)
        }
        let corrupt = Node("Document", id: 0)
        corrupt.addChild(TextNode(1, SourceSpan(1, 3, 0, 2), "bc"))
        @Expect(EditingLegacyInvariants.invalidCoordinates(corrupt, "abcd").size, 1)
        corrupt.addChild(TextNode(1, SourceSpan(0, 1, 0, 1), "a"))
        @Expect(EditingLegacyInvariants.duplicateIds(corrupt).size, 1)
        // Both axes are individually valid, but point at the wrong source text.
        let misplaced = TextNode(2, SourceSpan(0, 2, 0, 2), "bc")
        @Expect(EditingLegacyInvariants.invalidCoordinates(misplaced, "abcd").size, 0)
        @Expect(EditingLegacyInvariants.literalSliceMatches(misplaced, "abcd"), false)
    }
}
