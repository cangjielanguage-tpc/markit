package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.block.{BlockEditingContext, BlockRawChildrenEdit}
import markit.core.document.PersistentDocumentVersion
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.*
import markit.core.session.*
import markit.core.source.{EditableRopeStore, SourceBuffer, SourceSpan}

// This fixture's wrapper is ^body!. Body parsing is the existing concrete
// Task06InlineGrammar; neither legacy nor editing has another body grammar.
private func recursiveClose(read: (Int64) -> ?Byte, start: Int64): ?Int64 {
    let first = read(start)
    if (first.isNone() || first.getOrThrow() != 94) { return None }
    var cursor = start + 1
    while (let Some(byte) <- read(cursor)) { if (byte == 33) { return Some(cursor) }; cursor += 1 }
    return None
}
private func recursiveRunes(input: String, start: Int64, end: Int64): Int64 {
    var count: Int64 = 0
    for (i in start..end) { if (input[i] < 128 || input[i] >= 192) { count += 1 } }
    return count
}
private class RecursiveBoxNode <: Node {
    public RecursiveBoxNode(id: Int64, span: SourceSpan) { super("RecursiveBox", id: id, sourceSpan: span, literal: "box") }
}
private class RecursiveBoxCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "task06-recursive-box" } }
    public func accepts(node: Node): Bool { return node is RecursiveBoxNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node { return RecursiveBoxNode(node.id, node.sourceSpan) }
}
private class RecursivePayload <: IncrementalStatePayload {
    public func fingerprint(): String { return "recursive-stateless-v1" }
    public func clonePayload(): IncrementalStatePayload { return RecursivePayload() }
}
private class RecursiveBodyView <: InlineTextView {
    private let base: InlineTextWindow
    public RecursiveBodyView(view: InlineTextView, begin: Int64, end: Int64, private let identity: String) {
        base = InlineTextWindow(view, begin, end)
    }
    public prop source: SourceVersionIdentity { get() { return base.source } }
    public prop mappingIdentity: String { get() { return identity } }
    public prop byteLength: Int64 { get() { return base.byteLength } }
    public func readByte(at: Int64): Byte { return base.readByte(at) }
    public func sliceBytes(start: Int64, end: Int64): String { return base.sliceBytes(start, end) }
    public func runeOffsetAtByte(at: Int64): Int64 { return base.runeOffsetAtByte(at) }
    public func mapByte(at: Int64, affinity: AnchorAffinity): ?SourceAnchor { return base.mapByte(at, affinity) }
}
private class RecursiveProjection <: InlineNestedProjection {
    public RecursiveProjection(private let tokenStart: Int64, private let bodyStart: Int64,
        private let bodyEnd: Int64, private let identity: String) {}
    public func rebase(child: InlineTextView, current: InlineTextView,
        block: BlockEditingContext): ?InlineNestedProjectionResult {
        let literal = Task06LiteralFacet()
        let a = literal.projectRaw(current, child.mapByte(0, AnchorAffinity.After).getOrThrow(), block)
        let b = literal.projectRaw(current, child.mapByte(child.byteLength, AnchorAffinity.Before).getOrThrow(), block)
        if (a.isNone() || b.isNone()) { return None }
        let begin = a.getOrThrow(); let end = b.getOrThrow()
        if (begin <= 0 || end >= current.byteLength || end - begin != child.byteLength ||
            current.readByte(begin - 1) != 94 || current.readByte(end) != 33) { return None }
        let next = RecursiveProjection(begin - 1, begin, end, identity)
        return Some(InlineNestedProjectionResult(RecursiveBodyView(current, begin, end, identity),
            InlineEditChange(0, 0, 0), next))
    }
    public func project(previous: InlineTextView, current: InlineTextView,
        change: InlineEditChange): ?InlineNestedProjectionResult {
        if (change.startByte < bodyStart || change.oldEndByte > bodyEnd ||
            previous.readByte(tokenStart) != 94 || previous.readByte(bodyEnd) != 33) { return None }
        let end = bodyEnd + change.newEndByte - change.oldEndByte
        if (end >= current.byteLength || current.readByte(tokenStart) != 94 || current.readByte(end) != 33) { return None }
        for (i in change.startByte..change.newEndByte) { if (current.readByte(i) == 33) { return None } }
        let view = RecursiveBodyView(current, bodyStart, end, identity)
        let next = RecursiveProjection(tokenStart, bodyStart, end, identity)
        return Some(InlineNestedProjectionResult(view,
            InlineEditChange(change.startByte - bodyStart, change.oldEndByte - bodyStart, change.newEndByte - bodyStart), next))
    }
}
private class RecursiveGrammar <: InlineParser & InlineEditingFacet {
    private let child: InlineEditingSession
    private let legacy: InlineParserEngine
    private let codec: NodeCodec
    public var editingCalls: Int64 = 0
    public RecursiveGrammar(inner: Task06InlineGrammar, codec: NodeCodec) {
        let dispatch = InlineDispatchTable(); dispatch.register(inner)
        this.codec = codec; child = InlineEditingSession(dispatch, codec, Task06LiteralFacet()); legacy = InlineParserEngine(dispatch)
    }
    public prop name: String { get() { return "task06-recursive" } }
    public prop ownerPlugin: String { get() { return "task06-recursive" } }
    public prop owner: String { get() { return ownerPlugin } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [94] } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(this) } }
    public prop grammarVersion: String { get() { return "recursive-wrapper-v1" } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion, RecursivePayload(), syntaxContext: grammarVersion))
    }
    public func restore(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return saved.documentId == context.documentId && saved.owner == owner && saved.syntaxContext == grammarVersion && saved.payload is RecursivePayload
    }
    public func rollbackEffects(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return restore(context, saved) && context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(previous: IncrementalCheckpoint, current: IncrementalCheckpoint): Bool {
        return previous.owner == current.owner && previous.syntaxContext == current.syntaxContext
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func leftContext(_: InlineAttemptContext, _: Int64): String { return "recursive-wrapper-v1" }
    public func rightContext(_: InlineAttemptContext, _: Int64): String { return "recursive-wrapper-v1" }
    public func tryParse(session: ParseSession, input: String, start: Int64, end: Int64, span: SourceSpan): ?InlineParseResult {
        let close = recursiveClose({ at: Int64 => if (at < end) { Some(input[at]) } else { Option<Byte>.None } }, start)
        if (close.isNone()) { return None }
        let finish = close.getOrThrow() + 1
        let runes = recursiveRunes(input, start, finish)
        let token = session.attachNode(RecursiveBoxNode(session.allocateNodeId(), SourceSpan(span.startByte,
            span.startByte + finish - start, span.startRune, span.startRune + runes)))
        let bodySpan = SourceSpan(span.startByte + 1, span.startByte + finish - start - 1,
            span.startRune + 1, span.startRune + runes - 1)
        for (node in legacy.parseRange(session, input, start + 1, finish - 1, bodySpan)) { token.addChild(node) }
        return Some(InlineParseResult(token, finish - start, runes))
    }
    public func parseAttempt(context: InlineAttemptContext, start: Int64): ?InlineParseResult {
        editingCalls += 1
        let close = recursiveClose({ at: Int64 => context.readByteOrEnd(at) }, start)
        if (close.isNone()) { return None }
        let end = close.getOrThrow() + 1
        let a = context.block.resolve(context.view.mapByte(start, AnchorAffinity.After).getOrThrow()).getOrThrow()
        let b = context.block.resolve(context.view.mapByte(end, AnchorAffinity.Before).getOrThrow()).getOrThrow()
        let first = context.block.source.coordinateAtByte(a).getOrThrow(); let last = context.block.source.coordinateAtByte(b).getOrThrow()
        let token = context.block.session.attachNode(RecursiveBoxNode(context.block.session.allocateNodeId(),
            SourceSpan(a, b, first.runeOffset, last.runeOffset)))
        let raw = PersistentNodeCapture(codec).capture(token, context.view.source).root
        let identity = "recursive-body:${token.id}"
        let body = RecursiveBodyView(context.view, start + 1, end - 1, identity)
        let snapshot = child.parseInitial(context.block, body, raw)
        let nested = InlineNestedOwner(child, snapshot, RecursiveProjection(start, start + 1, end - 1, identity))
        return Some(EditingInlineParseResult(token, end - start, last.runeOffset - first.runeOffset,
            Some(PersistentNodeBundle(snapshot.root)), Some(nested)))
    }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow {
        var start = context.change.startByte; var oldEnd = context.change.oldEndByte
        for (attempt in context.attempts) {
            if (attempt.readStart < start) { start = attempt.readStart }
            if (attempt.readEnd > oldEnd) { oldEnd = attempt.readEnd }
        }
        let delta = context.change.newEndByte - context.change.oldEndByte
        var newEnd = oldEnd + delta
        if (start < context.current.byteLength && context.current.readByte(start) == 94) {
            let close = recursiveClose({ at: Int64 =>
                if (at < context.current.byteLength) { Some(context.current.readByte(at)) } else { Option<Byte>.None }
            }, start)
            newEnd = if (let Some(end) <- close) { end + 1 } else { context.current.byteLength }
            if (newEnd - delta > oldEnd) { oldEnd = newEnd - delta }
        }
        return Some(InlineRecoveryWindow(start, oldEnd, newEnd, "wrapper read boundary", grammarVersion))
    }
}
private func recursiveVisible(node: Node): String {
    var text = "${node.name}:${node.literal}:${node.rawContent()}:${node.sourceSpan.startByte}:${node.sourceSpan.endByte}:${node.sourceSpan.startRune}:${node.sourceSpan.endRune}"
    for (child in node.children) { text += "[" + recursiveVisible(child) + "]" }
    return text
}
private class RecursiveFixture {
    public let source: EditableRopeStore
    public let session: ParseSession
    public let effects: OwnedEffectStore
    public let inner: Task06InlineGrammar
    public let outer: RecursiveGrammar
    public let engine: InlineEditingSession
    public var snapshot: InlineEditingSnapshot
    public var tree: PersistentDocumentVersion
    public var lastSpliceCount: Int64 = 0
    public RecursiveFixture(text: String, value!: ?String = None) {
        let store = EditableRopeStore("recursive", text: text)
        let parsing = ParseSession(SourceBuffer(editableSource: Some(store.current)), ParseOptions(), SessionSymbolTableStore(checkpointEnabled: true))
        let nodes = task06Codec(); nodes.register(RecursiveBoxCodec())
        let semantic = OwnedEffectStore(); let innerParser = Task06InlineGrammar()
        let provider = RecursiveGrammar(innerParser, nodes); let dispatch = InlineDispatchTable(); dispatch.register(provider)
        let execution = InlineEditingSession(dispatch, nodes, Task06LiteralFacet())
        let tx = semantic.beginTransaction()
        if (let Some(present) <- value) { tx.add(OwnedSemanticEffect(900, "key", StringEffectPayload(present), 0)) }
        let context = BlockEditingContext(parsing, store.current, None, tx,
            resolve: Some({ anchor: SourceAnchor => store.resolve(anchor, store.current.identity.version) }))
        parsing.editingContext = Some(context)
        parsing.root.sourceSpan = SourceSpan(0, store.current.byteLength, 0, store.current.runeLength)
        let initial = execution.parseInitial(context, RopeInlineTextView(store.current, 0, store.current.byteLength),
            PersistentNodeCapture(nodes).capture(parsing.root, store.current.identity).root)
        let version = PersistentDocumentVersion(PersistentNodeBundle(initial.root), source: Some(store))
        tx.commit()
        source = store; session = parsing; effects = semantic; inner = innerParser
        outer = provider; engine = execution; snapshot = initial; tree = version
    }
    public func edit(start: Int64, end: Int64, text: String): Unit {
        source.applyEdits(source.current.identity.version, [EditingTextEdit(EditingRange(start, end), text)])
        session.source.bindEditableSource(source.current)
        let tx = effects.beginTransaction()
        let context = BlockEditingContext(session, source.current, Some(tree), tx,
            resolve: Some({ anchor: SourceAnchor => source.resolve(anchor, source.current.identity.version) }))
        session.editingContext = Some(context)
        let next = engine.prepare(snapshot, context, RopeInlineTextView(source.current, 0, source.current.byteLength),
            InlineEditChange(start, end, start + text.size))
        install(next); tx.commit()
    }
    private func install(next: InlineEditingSnapshot): Unit {
        let pending = ArrayList<BlockRawChildrenEdit>(); pending.add(next.childrenEdit)
        var staged = tree; var count: Int64 = 0
        while (!pending.isEmpty()) {
            let change = pending.remove(at: pending.size - 1)
            staged = staged.splicingBundles(change.parentId, change.start, change.deleteCount, change.inserted, source.current.identity.version)
            let following = change.following; var i = following.size
            while (i > 0) { i -= 1; pending.add(following[i]) }
            count += 1
        }
        tree = staged; snapshot = next; lastSpliceCount = count
    }
    public func replayValue(value: ?String): Unit {
        let tx = effects.beginTransaction()
        tx.revokeOwner(900)
        if (let Some(present) <- value) { tx.add(OwnedSemanticEffect(900, "key", StringEffectPayload(present), 0)) }
        let context = BlockEditingContext(session, source.current, Some(tree), tx,
            resolve: Some({ anchor: SourceAnchor => source.resolve(anchor, source.current.identity.version) }))
        session.editingContext = Some(context)
        install(engine.replaySemantic(snapshot, context,
            RopeInlineTextView(source.current, 0, source.current.byteLength), ["key"]))
        tx.commit()
    }
}

@Test
@Tag[InlineEditing, InlineRecursiveOwner]
class Task06RecursiveInlineTests {
    @TestCase
    func twoChildEditsReuseWrapperAndUntouchedSiblingOwnerWhileOldSnapshotsStayReadable() {
        let fixture = RecursiveFixture("^@left; @right;! tail")
        let oldTree = fixture.tree; let oldVisible = recursiveVisible(oldTree.materializeLegacy())
        let box = fixture.snapshot.root.childAt(0)
        let right = box.childAt(2)
        let tx = fixture.effects.beginTransaction()
        tx.add(OwnedSemanticEffect(right.identity.nodeId, "nested-right", StringEffectPayload("retained"), 0)); tx.commit()
        let calls = fixture.outer.editingCalls; let innerCalls = fixture.inner.editingCalls
        fixture.edit(3, 4, "EE")
        @Expect(fixture.outer.editingCalls, calls)
        @Expect(fixture.inner.editingCalls, innerCalls + 1)
        @Expect(fixture.snapshot.root.childAt(0).identity.nodeId, box.identity.nodeId)
        @Expect(refEq(fixture.snapshot.root.childAt(0).childAt(2), right), true)
        @Expect(fixture.snapshot.root.childAt(0).childAt(2).startAnchor.source.version, right.startAnchor.source.version)
        @Expect(fixture.effects.winner("nested-right").isSome(), true)
        @Expect(recursiveVisible(fixture.tree.materializeLegacy()),
            recursiveVisible(RecursiveFixture("^@lEEft; @right;! tail").tree.materializeLegacy()))
        fixture.edit(5, 5, "X")
        @Expect(fixture.outer.editingCalls, calls)
        @Expect(fixture.inner.editingCalls, innerCalls + 2)
        @Expect(refEq(fixture.snapshot.root.childAt(0).childAt(2), right), true)
        @Expect(fixture.effects.winner("nested-right").isSome(), true)
        @Expect(recursiveVisible(fixture.tree.materializeLegacy()),
            recursiveVisible(RecursiveFixture("^@lEEXft; @right;! tail").tree.materializeLegacy()))
        let tailEnd = fixture.source.current.byteLength
        fixture.edit(tailEnd - 1, tailEnd, "L")
        @Expect(fixture.outer.editingCalls, calls)
        @Expect(fixture.inner.editingCalls, innerCalls + 2)
        fixture.edit(3, 4, "Q")
        @Expect(fixture.outer.editingCalls, calls)
        @Expect(fixture.inner.editingCalls, innerCalls + 3)
        @Expect(refEq(fixture.snapshot.root.childAt(0).childAt(2), right), true)
        @Expect(fixture.effects.winner("nested-right").isSome(), true)
        @Expect(fixture.tree.resolveAtVersion(right.startAnchor, 2), Some(10))
        @Expect(fixture.tree.resolveAtVersion(right.startAnchor, -1).isNone(), true)
        @Expect(fixture.tree.resolveAtVersion(right.startAnchor, fixture.tree.version + 1).isNone(), true)
        @Expect(recursiveVisible(fixture.tree.materializeLegacy()),
            recursiveVisible(RecursiveFixture("^@lQEXft; @right;! taiL").tree.materializeLegacy()))
        @Expect(recursiveVisible(oldTree.materializeLegacy()), oldVisible)

        // Two independent nested owners read the same missing key. Replaying
        // that key must publish both child edits without reparsing wrappers.
        let semantic = RecursiveFixture("^@?key; @keep;! ^@?key; @other;!")
        let missingTree = semantic.tree; let missingVisible = recursiveVisible(missingTree.materializeLegacy())
        let firstBox = semantic.snapshot.root.childAt(0); let secondBox = semantic.snapshot.root.childAt(2)
        let keep = firstBox.childAt(firstBox.childCount - 1)
        let other = secondBox.childAt(secondBox.childCount - 1)
        let ownerEffects = semantic.effects.beginTransaction()
        ownerEffects.add(OwnedSemanticEffect(keep.identity.nodeId, "keep-owner", StringEffectPayload("keep"), 0))
        ownerEffects.add(OwnedSemanticEffect(other.identity.nodeId, "other-owner", StringEffectPayload("other"), 0))
        ownerEffects.commit()
        let parentCalls = semantic.outer.editingCalls; let childCalls = semantic.inner.editingCalls
        semantic.replayValue(Some("present"))
        @Expect(semantic.source.current.identity.version, 0)
        @Expect(semantic.outer.editingCalls, parentCalls)
        @Expect(semantic.inner.editingCalls, childCalls + 2)
        @Expect(semantic.lastSpliceCount, 2)
        @Expect(semantic.snapshot.root.childAt(0).identity.nodeId, firstBox.identity.nodeId)
        @Expect(semantic.snapshot.root.childAt(2).identity.nodeId, secondBox.identity.nodeId)
        @Expect(refEq(semantic.snapshot.root.childAt(0).childAt(2), keep), true)
        @Expect(refEq(semantic.snapshot.root.childAt(2).childAt(2), other), true)
        @Expect(recursiveVisible(semantic.tree.materializeLegacy()),
            recursiveVisible(RecursiveFixture("^@?key; @keep;! ^@?key; @other;!", value: Some("present")).tree.materializeLegacy()))
        semantic.replayValue(None)
        @Expect(semantic.outer.editingCalls, parentCalls)
        @Expect(semantic.inner.editingCalls, childCalls + 4)
        @Expect(semantic.lastSpliceCount, 2)
        let restoredFirst = semantic.snapshot.root.childAt(0); let restoredSecond = semantic.snapshot.root.childAt(2)
        @Expect(refEq(restoredFirst.childAt(restoredFirst.childCount - 1), keep), true)
        @Expect(refEq(restoredSecond.childAt(restoredSecond.childCount - 1), other), true)
        @Expect(semantic.effects.winner("keep-owner").isSome(), true)
        @Expect(semantic.effects.winner("other-owner").isSome(), true)
        @Expect(recursiveVisible(semantic.tree.materializeLegacy()), missingVisible)
        @Expect(recursiveVisible(missingTree.materializeLegacy()), missingVisible)

        // A source edit outside this owner leaves its immutable child view at
        // the old epoch. Key replay must use the provider's current projection.
        let crossed = RecursiveFixture("^@?key; @keep;! tail")
        let crossedOld = crossed.tree; let crossedOldVisible = recursiveVisible(crossedOld.materializeLegacy())
        let crossedBox = crossed.snapshot.root.childAt(0)
        let crossedKeep = crossedBox.childAt(crossedBox.childCount - 1)
        let crossedEffects = crossed.effects.beginTransaction()
        crossedEffects.add(OwnedSemanticEffect(crossedKeep.identity.nodeId, "crossed-keep", StringEffectPayload("keep"), 0))
        crossedEffects.commit()
        let crossedParentCalls = crossed.outer.editingCalls; let crossedChildCalls = crossed.inner.editingCalls
        let end = crossed.source.current.byteLength
        crossed.edit(end - 1, end, "L")
        @Expect(crossed.outer.editingCalls, crossedParentCalls)
        crossed.replayValue(Some("cross-epoch"))
        @Expect(crossed.source.current.identity.version, 1)
        @Expect(crossed.outer.editingCalls, crossedParentCalls)
        @Expect(crossed.inner.editingCalls, crossedChildCalls + 1)
        @Expect(crossed.snapshot.root.childAt(0).identity.nodeId, crossedBox.identity.nodeId)
        @Expect(refEq(crossed.snapshot.root.childAt(0).childAt(2), crossedKeep), true)
        @Expect(crossed.effects.winner("crossed-keep").isSome(), true)
        @Expect(recursiveVisible(crossed.tree.materializeLegacy()),
            recursiveVisible(RecursiveFixture("^@?key; @keep;! taiL", value: Some("cross-epoch")).tree.materializeLegacy()))
        crossed.replayValue(None)
        @Expect(crossed.outer.editingCalls, crossedParentCalls)
        @Expect(crossed.inner.editingCalls, crossedChildCalls + 2)
        @Expect(recursiveVisible(crossed.tree.materializeLegacy()),
            recursiveVisible(RecursiveFixture("^@?key; @keep;! taiL").tree.materializeLegacy()))
        @Expect(recursiveVisible(crossedOld.materializeLegacy()), crossedOldVisible)
    }
}
