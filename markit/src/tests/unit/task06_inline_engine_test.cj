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

private class Task06ReadTrap <: InlineTextView {
    public var reads: Int64 = 0
    public Task06ReadTrap(private let base: InlineTextView) {}
    public prop source: SourceVersionIdentity { get() { return base.source } }
    public prop mappingIdentity: String { get() { return base.mappingIdentity } }
    public prop byteLength: Int64 { get() { return base.byteLength } }
    public func readByte(at: Int64): Byte {
        reads += 1
        if (reads > 128) { throw IllegalArgumentException("Unrelated inline source scan") }
        return base.readByte(at)
    }
    public func sliceBytes(start: Int64, end: Int64): String {
        if (end - start > 128) { throw IllegalArgumentException("Whole inline source materialization") }
        return base.sliceBytes(start, end)
    }
    public func runeOffsetAtByte(at: Int64): Int64 { return base.runeOffsetAtByte(at) }
    public func mapByte(at: Int64, affinity: AnchorAffinity): ?SourceAnchor { return base.mapByte(at, affinity) }
}

private class Task06ExpandedLiteralFacet <: InlineLiteralFacet {
    private let identity = Task06LiteralFacet()
    public prop grammarVersion: String { get() { return "expanded-literal-v1" } }
    public func offsetsFollowLiteral(_: InlineTextView): Bool { return true }
    public func decode(view: InlineTextView, start: Int64, end: Int64): String { return identity.decode(view, start, end) }
    public func payload(view: InlineTextView, start: Int64, end: Int64, block: BlockEditingContext): ?PersistentTextPayload {
        return identity.payload(view, start, end, block)
    }
    public func projectRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64 {
        return identity.projectRaw(view, anchor, context)
    }
    public func splice(_: PersistentTextPayload, _: InlineRecoveryContext): ?InlineLiteralSplice { return None }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow {
        let start = if (context.change.startByte > 5) { 5 } else { context.change.startByte }
        return Some(InlineRecoveryWindow(start, context.change.oldEndByte, context.change.newEndByte,
            "provider widened into an older failed read", grammarVersion))
    }
}

private class Task06UppercaseLiteralFacet <: InlineLiteralFacet {
    private let identity = Task06LiteralFacet()
    public prop grammarVersion: String { get() { return "uppercase-literal-v1" } }
    public func offsetsFollowLiteral(_: InlineTextView): Bool { return true }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow { return identity.recoverWindow(context) }
    public func projectRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64 {
        return identity.projectRaw(view, anchor, context)
    }
    public func decode(view: InlineTextView, start: Int64, end: Int64): String {
        return String.fromUtf8(Array<Byte>(end - start, { i =>
            let byte = view.readByte(start + i)
            if (byte >= 97 && byte <= 122) { byte - 32 } else { byte }
        }))
    }
    public func payload(view: InlineTextView, start: Int64, end: Int64, _: BlockEditingContext): ?PersistentTextPayload {
        return Some(PersistentTextPayload.withRawSpelling(decode(view, start, end), view.sliceBytes(start, end)))
    }
    public func splice(_: PersistentTextPayload, context: InlineRecoveryContext): ?InlineLiteralSplice {
        return Some(InlineLiteralSplice(context.change.startByte, context.change.oldEndByte,
            decode(context.current, context.change.startByte, context.change.newEndByte)))
    }
}

private class Task06UnknownRawLiteralFacet <: InlineLiteralFacet {
    private let identity = Task06LiteralFacet()
    public prop grammarVersion: String { get() { return "unknown-raw-literal-v1" } }
    public func decode(view: InlineTextView, start: Int64, end: Int64): String { return identity.decode(view, start, end) }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow { return identity.recoverWindow(context) }
    public func projectRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64 {
        return identity.projectRaw(view, anchor, context)
    }
    public func splice(_: PersistentTextPayload, _: InlineRecoveryContext): ?InlineLiteralSplice { return None }
}

private func task06Visible(node: Node): String {
    var result = "${node.name}|${node.literal}|${node.rawContent()}|${node.sourceSpan.startByte}:${node.sourceSpan.endByte}:${node.sourceSpan.startRune}:${node.sourceSpan.endRune}"
    if (let typed: Task06InlineNode <- node) { result += "|" + typed.label }
    for (child in node.children) { result += "[" + task06Visible(child) + "]" }
    return result
}

private class Task06EngineFixture {
    public let source: EditableRopeStore
    public let session: ParseSession
    public let effects: OwnedEffectStore
    public let grammar: Task06InlineGrammar
    public let dispatch: InlineDispatchTable
    public let codec: NodeCodec
    public let engine: InlineEditingSession
    public let literalFacet: InlineLiteralFacet
    public var snapshot: InlineEditingSnapshot
    public var tree: PersistentDocumentVersion
    public var lastTrap: ?Task06ReadTrap = None
    public Task06EngineFixture(text: String, returnsText!: Bool = false, failProbe!: Bool = false,
        literalFacet!: ?InlineLiteralFacet = None, value!: ?String = None) {
        let store = EditableRopeStore("inline-main", text: text)
        let parsing = ParseSession(SourceBuffer(editableSource: Some(store.current)), ParseOptions(),
            SessionSymbolTableStore(checkpointEnabled: true))
        let semantic = OwnedEffectStore()
        let provider = Task06InlineGrammar(returnsText: returnsText)
        provider.failProbe = failProbe
        let table = InlineDispatchTable(); table.register(provider)
        let nodes = task06Codec()
        let literals = literalFacet ?? Task06LiteralFacet()
        let execution = InlineEditingSession(table, nodes, literals)
        let tx = semantic.beginTransaction()
        if (let Some(present) <- value) { tx.add(OwnedSemanticEffect(900, "key", StringEffectPayload(present), 0)) }
        let context = BlockEditingContext(parsing, store.current, Option<PersistentDocumentVersion>.None, tx,
            resolve: Some({ anchor: SourceAnchor => store.resolve(anchor, store.current.identity.version) }))
        parsing.editingContext = Some(context)
        parsing.root.sourceSpan = SourceSpan(0, store.current.byteLength, 0, store.current.runeLength)
        let owner = PersistentNodeCapture(nodes).capture(parsing.root, store.current.identity).root
        let initial = execution.parseInitial(context, RopeInlineTextView(store.current, 0, store.current.byteLength), owner)
        let version = PersistentDocumentVersion(PersistentNodeBundle(initial.root), source: Some(store))
        tx.commit()
        this.source = store; this.session = parsing; this.effects = semantic; this.grammar = provider
        this.dispatch = table; this.codec = nodes; this.engine = execution; this.snapshot = initial; this.tree = version
        this.literalFacet = literals
    }
    public func openContext(): BlockEditingContext {
        let context = BlockEditingContext(session, source.current, Some(tree), effects.beginTransaction(),
            resolve: Some({ anchor: SourceAnchor => source.resolve(anchor, source.current.identity.version) }))
        session.editingContext = Some(context)
        return context
    }
    public func edit(start: Int64, end: Int64, inserted: String, trap!: Bool = false): Unit {
        source.applyEdits(source.current.identity.version, [EditingTextEdit(EditingRange(start, end), inserted)])
        session.source.bindEditableSource(source.current)
        let context = openContext()
        let rawView = RopeInlineTextView(source.current, 0, source.current.byteLength)
        var view: InlineTextView = rawView
        if (trap) { let guarded = Task06ReadTrap(rawView); lastTrap = Some(guarded); view = guarded }
        let next = engine.prepare(snapshot, context, view, InlineEditChange(start, end, start + inserted.size))
        let edit = next.childrenEdit
        tree = tree.splicingBundles(edit.parentId, edit.start, edit.deleteCount, edit.inserted, source.current.identity.version)
        snapshot = next
        context.effects.commit()
    }
    public func visible(): String { return task06Visible(tree.materializeLegacy()) }
    public func replayValue(value: ?String): Unit {
        let context = openContext()
        context.effects.revokeOwner(900)
        if (let Some(present) <- value) { context.effects.add(OwnedSemanticEffect(900, "key", StringEffectPayload(present), 0)) }
        let next = engine.replaySemantic(snapshot, context,
            RopeInlineTextView(source.current, 0, source.current.byteLength), ["key"])
        let edit = next.childrenEdit
        tree = tree.splicingBundles(edit.parentId, edit.start, edit.deleteCount, edit.inserted, source.current.identity.version)
        snapshot = next; context.effects.commit()
    }
    public func freshVisible(returnsText!: Bool = false, value!: ?String = None): String {
        return Task06EngineFixture(source.current.sliceBytes(0, source.current.byteLength), returnsText: returnsText,
            literalFacet: Some(literalFacet), value: value).visible()
    }
}

@Test
@Tag[InlineEditing]
class Task06InlineEngineTests {
    @TestCase
    func semanticMissingPresentRemovedReplaysInSameSourceEpoch() {
        let fixture = Task06EngineFixture("@?key;")
        @Expect(fixture.snapshot.attempts.records()[0].succeeded, false)
        fixture.replayValue(Some("resolved"))
        @Expect(fixture.source.current.identity.version, 0)
        @Expect(fixture.snapshot.attempts.records()[0].succeeded, true)
        @Expect(fixture.tree.materializeLegacy().children[0].literal, "resolved")
        @Expect(fixture.visible(), fixture.freshVisible(value: Some("resolved")))
        let tokenId = fixture.snapshot.root.childAt(0).identity.nodeId
        let tx = fixture.effects.beginTransaction()
        tx.add(OwnedSemanticEffect(tokenId, "task06-semantic-token", StringEffectPayload("owned"), 0)); tx.commit()
        fixture.replayValue(Option<String>.None)
        @Expect(fixture.snapshot.attempts.records()[0].succeeded, false)
        @Expect(fixture.effects.winner("task06-semantic-token").isNone(), true)
        @Expect(fixture.visible(), fixture.freshVisible())
    }

    @TestCase
    func expandedProviderWindowPullsOutsideFailedOpenerIntoRetryClosure() {
        let fixture = Task06EngineFixture("@?key; padding tail", literalFacet: Some(Task06ExpandedLiteralFacet()))
        let before = fixture.grammar.editingCalls
        let owner = fixture.snapshot.attempts.records()[0].owner
        fixture.edit(18, 19, "L")
        @Expect(fixture.grammar.editingCalls > before, true)
        @Expect(fixture.snapshot.attempts.size, 1)
        @Expect(fixture.snapshot.attempts.records()[0].startByte, 0)
        @Expect(fixture.snapshot.attempts.records()[0].owner != owner, true)
        @Expect(fixture.visible(), fixture.freshVisible())
    }
    @TestCase
    func decodedLiteralKeepsRawSpellingAndExpandsUnsafeSliceCoordinates() {
        let raw = String.fromUtf8([97, 92, 42, 98])
        let fixture = Task06EngineFixture(raw, literalFacet: Some(Task06EscapedLiteralFacet()))
        let oldTree = fixture.tree
        let old = oldTree.materializeLegacy().children[0]
        @Expect(old.literal, "a*b")
        @Expect(old.rawContent(), raw)
        @Expect(old.sourceSpan.startByte, 0)
        @Expect(old.sourceSpan.endByte, 4)
        fixture.edit(3, 4, "c")
        let next = fixture.tree.materializeLegacy().children[0]
        @Expect(next.literal, "a*c")
        @Expect(next.rawContent(), String.fromUtf8([97, 92, 42, 99]))
        @Expect(next.sourceSpan.startByte, 0)
        @Expect(next.sourceSpan.endByte, 4)
        @Expect(fixture.visible(), fixture.freshVisible())
        @Expect(oldTree.materializeLegacy().children[0].rawContent(), raw)
        fixture.edit(1, 2, "")
        @Expect(fixture.tree.materializeLegacy().children[0].literal, "a*c")
        @Expect(fixture.tree.materializeLegacy().children[0].rawContent(), "a*c")
        @Expect(fixture.visible(), fixture.freshVisible())
        let uppercase = Task06EngineFixture("abc", literalFacet: Some(Task06UppercaseLiteralFacet()))
        uppercase.edit(1, 2, "d")
        let upper = uppercase.tree.materializeLegacy().children[0]
        @Expect(upper.literal, "ADC")
        @Expect(upper.rawContent(), "adc")
        @Expect(uppercase.visible(), uppercase.freshVisible())
        let initiallyEqual = Task06EngineFixture("123", literalFacet: Some(Task06UppercaseLiteralFacet()))
        initiallyEqual.edit(1, 2, "d")
        @Expect(initiallyEqual.tree.materializeLegacy().children[0].literal, "1D3")
        @Expect(initiallyEqual.tree.materializeLegacy().children[0].rawContent(), "1d3")
        @Expect(initiallyEqual.visible(), initiallyEqual.freshVisible())
        var rejected = false
        try { PersistentTextPayload.withRawSpelling("*", String.fromUtf8([92, 42])).splice(0, 1, "x") }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try { Task06EngineFixture("abc", literalFacet: Some(Task06UnknownRawLiteralFacet())) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        let local = Task06EngineFixture(String.fromUtf8([97, 92, 42]) + " @x; b @y; c",
            literalFacet: Some(Task06EscapedLiteralFacet()))
        let firstToken = local.snapshot.root.childAt(1); let secondToken = local.snapshot.root.childAt(3)
        let calls = local.grammar.editingCalls
        local.edit(0, 1, "z")
        @Expect(refEq(local.snapshot.root.childAt(1), firstToken), true)
        @Expect(refEq(local.snapshot.root.childAt(3), secondToken), true)
        @Expect(local.grammar.editingCalls, calls)
        @Expect(local.visible(), local.freshVisible())
    }

    @TestCase
    func lengthOnlyFailureAndEscapeRemovalRetryThenRevokeOldSuccess() {
        let length = Task06EngineFixture("$")
        @Expect(length.snapshot.attempts.records()[0].dependsOnLength, true)
        @Expect(length.snapshot.attempts.records()[0].succeeded, false)
        length.edit(1, 1, "ab")
        @Expect(length.snapshot.attempts.records()[0].succeeded, true)
        @Expect(length.visible(), length.freshVisible())
        let escaped = Task06EngineFixture(String.fromUtf8([92, 64, 120, 59]))
        escaped.edit(0, 1, "")
        @Expect(escaped.snapshot.attempts.records()[0].succeeded, true)
        @Expect(escaped.visible(), escaped.freshVisible())
        let removedId = escaped.snapshot.root.childAt(0).identity.nodeId
        let tx = escaped.effects.beginTransaction()
        tx.add(OwnedSemanticEffect(removedId, "task06-old-success", StringEffectPayload("owned"), 0)); tx.commit()
        escaped.edit(0, 1, "")
        @Expect(escaped.effects.winner("task06-old-success").isNone(), true)
        @Expect(escaped.visible(), escaped.freshVisible())
    }
    @TestCase
    func foreignSnapshotRejectsBeforeParserScopeOrAllocatorIncludingEmptyReplay() {
        let fixture = Task06EngineFixture("@x;")
        let foreignEngine = InlineEditingSession(fixture.dispatch, fixture.codec, Task06LiteralFacet())
        let context = fixture.openContext()
        let view = RopeInlineTextView(fixture.source.current, 0, fixture.source.current.byteLength)
        let before = fixture.session.allocateNodeId(); let calls = fixture.grammar.editingCalls
        var rejected = false
        try { foreignEngine.prepare(fixture.snapshot, context, view, InlineEditChange(0, 0, 0)) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try { foreignEngine.replaySemantic(fixture.snapshot, context, view, []) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(fixture.grammar.editingCalls, calls)
        @Expect(fixture.session.allocateNodeId(), before + 1)
        context.effects.cancel()
    }

    @TestCase
    func failedFarCloserRetriesSharedGrammarAndFailedProbeDoesNotLeak() {
        let fixture = Task06EngineFixture("left @open", failProbe: true)
        @Expect(fixture.snapshot.attempts.size, 1)
        @Expect(fixture.snapshot.attempts.records()[0].succeeded, false)
        @Expect(fixture.effects.winner("task06-failed-probe").isNone(), true)
        @Expect(fixture.session.root.children.size, 0)
        fixture.edit(10, 10, "; tail")
        @Expect(fixture.visible(), fixture.freshVisible())
        @Expect(fixture.snapshot.attempts.records()[0].succeeded, true)
        fixture.edit(5, 6, "")
        @Expect(fixture.visible(), fixture.freshVisible())
    }

    @TestCase
    func successfulParserTextKeepsTypedMetadataAndSeparateLogicalNodes() {
        let fixture = Task06EngineFixture("aa @token; zz", returnsText: true)
        fixture.edit(1, 2, "b")
        @Expect(fixture.visible(), fixture.freshVisible(returnsText: true))
        let legacy = fixture.tree.materializeLegacy()
        @Expect(legacy.children.size, 3)
        @Expect(legacy.children[1].string("task06-label"), Some("token"))
        @Expect(legacy.children[1].int("task06-marker"), Some(31))
        @Expect(legacy.children[1].bool("task06-parser-success"), Some(true))
    }

    @TestCase
    func giantSingleLogicalTextEditUsesBoundedViewAndTextSplice() {
        let original = String.fromUtf8(Array<Byte>(1024 * 512, repeat: 97))
        let fixture = Task06EngineFixture(original)
        let id = fixture.snapshot.root.childAt(0).identity.nodeId
        let calls = fixture.grammar.editingCalls
        fixture.edit(262144, 262145, "z", trap: true)
        @Expect(fixture.grammar.editingCalls, calls)
        @Expect(fixture.lastTrap.getOrThrow().reads < 128, true)
        @Expect(fixture.snapshot.root.childCount, 1)
        @Expect(fixture.snapshot.root.childAt(0).identity.nodeId, id)
        @Expect(fixture.snapshot.textPatches.size, 1)
        @Expect(fixture.snapshot.textPatches[0].inserted, "z")
        let payload = (fixture.snapshot.root.childAt(0).payload as PersistentTextPayload).getOrThrow()
        @Expect(payload.materialize(), original[0..262144] + "z" + original[262145..original.size])
    }
}
