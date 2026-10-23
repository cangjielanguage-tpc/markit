package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.core.block.*
import markit.core.document.*
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.*
import markit.core.session.*
import markit.core.source.{EditableRopeStore, SourceBuffer, SourceSpan}
import markit.plugins.standard.editing.*
import markit.plugins.standard.inline.soft_break.SoftBreakParser

private class Task07InlineWindowGuard <: InlineTextView {
    public var reads: Int64 = 0
    public Task07InlineWindowGuard(private let base: InlineTextView) {}
    public prop source: SourceVersionIdentity { get() { return base.source } }
    public prop mappingIdentity: String { get() { return base.mappingIdentity } }
    public prop byteLength: Int64 { get() { return base.byteLength } }
    public func readByte(at: Int64): Byte {
        reads += 1
        if (reads > 64) { throw IllegalArgumentException("Unrelated paragraph byte scan") }
        return base.readByte(at)
    }
    public func sliceBytes(start: Int64, end: Int64): String {
        if (end - start > 64) { throw IllegalArgumentException("Unrelated paragraph String export") }
        return base.sliceBytes(start, end)
    }
    public func runeOffsetAtByte(at: Int64): Int64 { return base.runeOffsetAtByte(at) }
    public func mapByte(at: Int64, affinity: AnchorAffinity): ?SourceAnchor { return base.mapByte(at, affinity) }
}

private func task07ParagraphView(store: EditableRopeStore, escapes: Int64): StandardParagraphInlineView {
    let rope = RopeInlineTextView(store.current, 0, store.current.byteLength)
    return StandardParagraphInlineView(MappedInlineTextView([rope], store.current.identity, "task07-paragraph"), escapes)
}

@Test
@Tag[StandardInlinePlan]
class Task07InlinePlanTests {
    @TestCase
    func longSingleTextEditUsesOnlyLocalWindowsAndKeepsOldPayload() {
        let text = InlineUtils.repeat("abcdefgh", 32768)
        let store = EditableRopeStore("task07-long-inline", text: text)
        let session = ParseSession(SourceBuffer(editableSource: Some(store.current)), ParseOptions(),
            SessionSymbolTableStore(checkpointEnabled: true))
        let effects = OwnedEffectStore(); let codec = task06Codec()
        let plan = StandardInlinePlan([SoftBreakParser()], codec); let engine = plan.create()
        let first = BlockEditingContext(session, store.current, Option<PersistentDocumentVersion>.None,
            effects.beginTransaction(), resolve: Some({ anchor: SourceAnchor => store.resolve(anchor, store.current.identity.version) }))
        session.editingContext = Some(first)
        session.root.sourceSpan = SourceSpan(0, text.size, 0, text.size)
        let owner = PersistentNodeCapture(codec).capture(session.root, store.current.identity).root
        let old = engine.parseInitial(first, task07ParagraphView(store, 0), owner)
        let oldTree = PersistentDocumentVersion(PersistentNodeBundle(old.root), source: Some(store))
        first.effects.commit()
        let at: Int64 = 131072
        store.applyEdits(0, [EditingTextEdit(EditingRange(at, at + 1), "😀")])
        session.source.bindEditableSource(store.current)
        let nextContext = BlockEditingContext(session, store.current, Some(oldTree), effects.beginTransaction(),
            resolve: Some({ anchor: SourceAnchor => store.resolve(anchor, store.current.identity.version) }))
        session.editingContext = Some(nextContext)
        let guard = Task07InlineWindowGuard(RopeInlineTextView(store.current, 0, store.current.byteLength))
        let mapped = MappedInlineTextView([guard], store.current.identity, "task07-paragraph")
        let next = engine.prepare(old, nextContext, StandardParagraphInlineView(mapped, 0), InlineEditChange(at, at + 1, at + 4))
        @Expect(next.root.childCount, 1)
        @Expect(next.root.childAt(0).identity.nodeId, old.root.childAt(0).identity.nodeId)
        @Expect(next.textPatches.size, 1)
        @Expect(guard.reads <= 64, true)
        let payload = (next.root.childAt(0).payload as PersistentTextPayload).getOrThrow()
        @Expect(PersistentInlineLiteralWindow(payload, at, at + 4).sliceBytes(), "😀")
        @Expect(payload.rawSpellingFollowsText, true)
        let oldPayload = (old.root.childAt(0).payload as PersistentTextPayload).getOrThrow()
        @Expect(PersistentInlineLiteralWindow(oldPayload, at, at + 1).sliceBytes(), "a")
        @Expect(store.current.coordinateAtByte(at + 4).getOrThrow().utf16Offset, at + 2)
        nextContext.effects.cancel()
    }

    @TestCase
    func escapedLiteralKeepsPhysicalRawAndOldDecodedText() {
        let raw = "a\\*b"
        let store = EditableRopeStore("task07-escaped-inline", text: raw)
        let session = ParseSession(SourceBuffer(editableSource: Some(store.current)), ParseOptions(),
            SessionSymbolTableStore(checkpointEnabled: true))
        let effects = OwnedEffectStore(); let codec = task06Codec()
        let plan = StandardInlinePlan([SoftBreakParser()], codec); let engine = plan.create()
        let first = BlockEditingContext(session, store.current, Option<PersistentDocumentVersion>.None,
            effects.beginTransaction(), resolve: Some({ anchor: SourceAnchor => store.resolve(anchor, store.current.identity.version) }))
        session.editingContext = Some(first)
        session.root.sourceSpan = SourceSpan(0, raw.size, 0, raw.size)
        let old = engine.parseInitial(first, task07ParagraphView(store, 1), PersistentNodeCapture(codec).capture(session.root, store.current.identity).root)
        let oldTree = PersistentDocumentVersion(PersistentNodeBundle(old.root), source: Some(store))
        first.effects.commit()
        @Expect(oldTree.materializeLegacy().children[0].literal, "a*b")
        @Expect(oldTree.materializeLegacy().children[0].rawContent(), raw)
        store.applyEdits(0, [EditingTextEdit(EditingRange(3, 4), "😀")])
        session.source.bindEditableSource(store.current)
        let nextContext = BlockEditingContext(session, store.current, Some(oldTree), effects.beginTransaction(),
            resolve: Some({ anchor: SourceAnchor => store.resolve(anchor, store.current.identity.version) }))
        session.editingContext = Some(nextContext)
        let next = engine.prepare(old, nextContext, task07ParagraphView(store, 1), InlineEditChange(3, 4, 7))
        let node = (next.root.childAt(0).payload as PersistentTextPayload).getOrThrow().materializeNode(1, SourceSpan(0, 7, 0, 4))
        @Expect(node.literal, "a*😀")
        @Expect(node.rawContent(), "a\\*😀")
        @Expect(oldTree.materializeLegacy().children[0].literal, "a*b")
        @Expect(oldTree.materializeLegacy().children[0].rawContent(), raw)
        @Expect(plan.literal.offsetsFollowLiteral(task07ParagraphView(store, 1)), false)
        @Expect(plan.literal.payload(RopeInlineTextView(store.current, 0, 7), 0, 7, nextContext).isNone(), true)
        nextContext.effects.cancel()
    }

    @TestCase
    func escapedNewlineReadIsRetriedWhenItsBackslashIsRemoved() {
        let raw = "a\\\nx"
        let store = EditableRopeStore("task07-newline-inline", text: raw)
        let session = ParseSession(SourceBuffer(editableSource: Some(store.current)), ParseOptions(),
            SessionSymbolTableStore(checkpointEnabled: true))
        let effects = OwnedEffectStore(); let codec = task06Codec()
        let engine = StandardInlinePlan([SoftBreakParser()], codec).create()
        let first = BlockEditingContext(session, store.current, Option<PersistentDocumentVersion>.None,
            effects.beginTransaction(), resolve: Some({ anchor: SourceAnchor => store.resolve(anchor, store.current.identity.version) }))
        session.editingContext = Some(first)
        session.root.sourceSpan = SourceSpan(0, raw.size, 0, raw.size)
        let old = engine.parseInitial(first, task07ParagraphView(store, 1), PersistentNodeCapture(codec).capture(session.root, store.current.identity).root)
        let tree = PersistentDocumentVersion(PersistentNodeBundle(old.root), source: Some(store))
        first.effects.commit()
        @Expect(old.root.childCount, 1)
        @Expect(old.attempts.records()[0].succeeded, false)
        @Expect(old.attempts.records()[0].readStart, 0)
        store.applyEdits(0, [EditingTextEdit(EditingRange(1, 2), "")])
        session.source.bindEditableSource(store.current)
        let nextContext = BlockEditingContext(session, store.current, Some(tree), effects.beginTransaction(),
            resolve: Some({ anchor: SourceAnchor => store.resolve(anchor, store.current.identity.version) }))
        session.editingContext = Some(nextContext)
        let next = engine.prepare(old, nextContext, task07ParagraphView(store, 0), InlineEditChange(1, 2, 1))
        @Expect(next.root.childCount, 3)
        @Expect(next.attempts.records()[0].succeeded, true)
        @Expect(tree.materializeLegacy().children[0].literal, raw)
        nextContext.effects.cancel()
    }
}
