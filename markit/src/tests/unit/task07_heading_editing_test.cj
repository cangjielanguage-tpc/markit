package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.{Node, NodeCodec, DocumentNode, TextNode, TypedNodeCodec, RawSyntaxNode}
import markit.core.source.{SourceSpan, SourceBuffer}
import markit.core.editing.{OwnedSemanticEffect, SourceAnchor, SourceVersionIdentity, EditingPolicy, EditingTextEdit, EditingRange}
import markit.core.session.OwnedEffectStore
import markit.plugins.standard.block.heading.*

private class HeadingTestBaseCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "heading-test.base" } }
    public func accepts(node: Node): Bool { return node is DocumentNode || node is TextNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        if (node is DocumentNode) { return DocumentNode(SourceBuffer()) }
        let text = (node as TextNode).getOrThrow()
        return TextNode(text.id, text.sourceSpan, text.content)
    }
}
private func headingTestCodec(): NodeCodec {
    let codec = NodeCodec(); codec.register(HeadingTestBaseCodec()); registerHeadingEditingCodecs(codec); return codec
}

@Test
@Tag[HeadingEditing, StandardEditing]
class Task07HeadingEditingTests {
    @TestCase
    func realAtxSessionRenamesAndInsertsDuplicateWithoutParsingUnchangedHeadings() {
        let markit = Markit(HeadingPlugin(numberingConfig: HeadingNumberingConfig(enabled: true)))
        let editing = markit.createEditingSession("real-headings", "# same\n# other\n# same\n", headingTestCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot()
        let originalIndex = headingIndexFor(before.effects).getOrThrow()
        @Expect(originalIndex.size, 3)
        let indexOwner = before.effects.winner("standard.heading.index").getOrThrow().ownerId
        let beforeRoot = (before.tree.root as RawSyntaxNode).getOrThrow()
        let first = beforeRoot.childAt(0); let tail = beforeRoot.childAt(2)
        let tailText = tail.childAt(0)
        editing.applyEdits(0, [EditingTextEdit(EditingRange(9, 14), "same")])
        let renamed = editing.flush()
        @Expect(renamed.committed, true)
        @Expect(renamed.syntaxUnitsParsed, 1)
        let after = editing.snapshot()
        @Expect(after.effects.winner("standard.heading.index").getOrThrow().ownerId, indexOwner)
        @Expect(headingIndexFor(after.effects).getOrThrow().at(2).getOrThrow().slugAllocation.uniqueSlug, "same-3")
        @Expect(originalIndex.at(2).getOrThrow().slugAllocation.uniqueSlug, "same-2")
        let afterRoot = (after.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(refEq(first, afterRoot.childAt(0)), true)
        @Expect(tail.identity.nodeId, afterRoot.childAt(2).identity.nodeId)
        @Expect(refEq(tailText, afterRoot.childAt(2).childAt(0)), true)
        let legacy = after.tree.materializeLegacy()
        @Expect(legacy.children[1].slug, "same-2")
        @Expect(legacy.children[2].slug, "same-3")
        @Expect(legacy.children[2].string("number"), Some("3"))
        @Expect(legacy.toHtml(), markit.parse("# same\n# same\n# same\n").html())
        @Expect(before.tree.materializeLegacy().children[2].slug, "same-2")
        // Split one proven physical-line unit to insert another heading.
        editing.applyEdits(1, [EditingTextEdit(EditingRange(7, 7), "# same\n")])
        let inserted = editing.flush()
        @Expect(inserted.committed, true)
        @Expect(inserted.syntaxUnitsParsed, 1)
        let latest = editing.snapshot()
        @Expect(headingIndexFor(latest.effects).getOrThrow().size, 4)
        @Expect(headingIndexFor(before.effects).getOrThrow().size, 3)
        let latestRoot = latest.tree.materializeLegacy()
        @Expect(latestRoot.children.size, 4)
        @Expect(latestRoot.children[3].slug, "same-4")
        @Expect(latestRoot.children[3].string("number"), Some("4"))
        @Expect(latestRoot.toHtml(), markit.parse("# same\n# same\n# same\n# same\n").html())
        before.release(); after.release(); latest.release(); editing.close()
    }

    @TestCase
    func atxMatcherPreservesLegacyGrammarAndUnicodeOffsets() {
        let found = matchAtxHeading("  ### 中文😀 ###  ", closableEnabled: true).getOrThrow()
        @Expect(found.startByte, 2)
        @Expect(found.textStartByte, 6)
        @Expect(found.text, "中文😀")
        @Expect(found.level, 3)
        @Expect(found.closable, true)
        @Expect(matchAtxHeading("####### nope").isNone(), true)
        @Expect(matchAtxHeading("#no space").isNone(), true)
        @Expect(matchAtxHeading("    # indented").isNone(), true)
        @Expect(matchAtxHeading("# ").isNone(), true)
        @Expect(matchAtxHeading("# title #").getOrThrow().text, "title #")
    }

    @TestCase
    func completeStateCodecRestoresSlugCountersAndHiddenSection() {
        let numbers = HeadingNumberingConfig(enabled: true)
        let closable = HeadingClosableConfig(enabled: true)
        let state = HeadingSessionState(numberingConfig: numbers, closableConfig: closable)
        @Expect(state.uniqueSlug("same"), "same")
        @Expect(state.assignNumber(1), "1")
        let hidden = HeadingNode(1, SourceSpan.empty(), "secret", 2)
        hidden.setBool("closable", true)
        @Expect(state.acceptTopLevelNode(hidden), false)
        let saved = state.snapshot()
        state.uniqueSlug("same"); state.assignNumber(2)
        state.reset()
        @Expect(state.restoreSnapshot(saved), true)
        @Expect(state.uniqueSlug("same"), "same-2")
        @Expect(state.assignNumber(2), "1.1")
        @Expect(state.acceptTopLevelNode(Node("Paragraph")), false)
        @Expect(state.acceptTopLevelNode(HeadingNode(2, SourceSpan.empty(), "visible", 1)), true)
        let foreign = HeadingSessionState()
        @Expect(foreign.restoreSnapshot(saved), false)
        // The captured arrays remain detached after the live state changes.
        @Expect(state.restoreSnapshot(saved), true)
        @Expect(state.uniqueSlug("same"), "same-2")
    }

    @TestCase
    func typedCodecRetainsConstructorFieldsRawSpellingAndMetadata() {
        let node = HeadingNode(42, SourceSpan(2, 11, 2, 7), "中文", 3, slug: "custom")
        node.setRawContent("### 中文")
        node.setString("number", "2.3.1"); node.setBool("closable", true)
        let codec = NodeCodec(); registerHeadingEditingCodecs(codec)
        let cloned = (codec.clone(node) as HeadingNode).getOrThrow()
        @Expect(cloned.id, 42)
        @Expect(cloned.content, "中文")
        @Expect(cloned.rawContent(), "### 中文")
        @Expect(cloned.slug, "custom")
        @Expect(cloned.string("number"), Some("2.3.1"))
        @Expect(cloned.bool("closable"), Some(true))
        @Expect(refEq(node, cloned), false)
        @Expect(codec.supports(Node("Heading")), false)
    }

    @TestCase
    func orderedSlugBucketRenameAndRevocationPreserveOlderIndex() {
        let first = HeadingContribution(1, 10, "same", 1, false)
        let middle = HeadingContribution(2, 20, "other", 1, false)
        let last = HeadingContribution(3, 30, "same", 1, false)
        let a = HeadingOrderedIndex().change(None, Some(first)).index
        let b = a.change(None, Some(middle)).index
        let original = b.change(None, Some(last)).index
        @Expect(original.at(2).getOrThrow().slugAllocation.uniqueSlug, "same-2")
        let renamed = HeadingContribution(2, 20, "same", 1, false)
        let change = original.change(Some(middle), Some(renamed))
        @Expect(change.index.at(1).getOrThrow().slugAllocation.uniqueSlug, "same-2")
        @Expect(change.index.at(2).getOrThrow().slugAllocation.uniqueSlug, "same-3")
        @Expect(original.at(1).getOrThrow().slugAllocation.uniqueSlug, "other")
        @Expect(original.at(2).getOrThrow().slugAllocation.uniqueSlug, "same-2")
        let removed = change.index.change(Some(first), None).index
        @Expect(removed.at(0).getOrThrow().slugAllocation.uniqueSlug, "same")
        @Expect(removed.at(1).getOrThrow().slugAllocation.uniqueSlug, "same-2")
        @Expect(removed.size, 2)
    }

    @TestCase
    func numberingAndVisibilityPropagateOnlyThroughHeadingSuccessors() {
        let first = HeadingContribution(1, 10, "one", 1, false)
        let hidden = HeadingContribution(2, 20, "secret", 2, true)
        let nested = HeadingContribution(3, 30, "inside", 3, false)
        let next = HeadingContribution(4, 40, "next", 1, false)
        var index = HeadingOrderedIndex(numbering: HeadingNumberingConfig(enabled: true), closable: HeadingClosableConfig(enabled: true))
        for (entry in [first, hidden, nested, next]) { index = index.change(None, Some(entry)).index }
        @Expect(index.at(0).getOrThrow().number, "1")
        @Expect(index.at(1).getOrThrow().number, "1.1")
        @Expect(index.at(1).getOrThrow().visible, false)
        @Expect(index.at(2).getOrThrow().visible, false)
        @Expect(index.at(3).getOrThrow().visible, true)
        @Expect(index.at(3).getOrThrow().number, "2")
        let open = HeadingContribution(2, 20, "secret", 2, false)
        let edited = index.change(Some(hidden), Some(open)).index
        @Expect(edited.at(1).getOrThrow().visible, true)
        @Expect(edited.at(2).getOrThrow().visible, true)
        @Expect(index.at(2).getOrThrow().visible, false)
        let rename = edited.change(Some(open), Some(HeadingContribution(2, 20, "renamed", 2, false)))
        @Expect(rename.changed.size, 1)
    }

    @TestCase
    func contributionOwnershipCanBeRevokedWithoutMutatingPublishedSnapshot() {
        let store = OwnedEffectStore(); let transaction = store.beginTransaction()
        let value = HeadingContribution(7, 10, "same", 1, true,
            anchor: Some(SourceAnchor(SourceVersionIdentity("heading", 0), 10)))
        transaction.add(OwnedSemanticEffect(7, headingContributionKey(7), value, 10))
        transaction.commit()
        let before = store.snapshot()
        let removal = store.beginTransaction(); removal.revokeOwner(7); removal.commit()
        @Expect(store.winner(headingContributionKey(7)).isNone(), true)
        let preserved = (before.winner(headingContributionKey(7)).getOrThrow().payload as HeadingContribution).getOrThrow()
        @Expect(preserved.text, "same")
        @Expect(preserved.closable, true)
        @Expect(preserved.anchor.getOrThrow().byteOffset, 10)
    }
}
