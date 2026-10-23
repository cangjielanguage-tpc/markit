package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.block.{BlockEditingContext, BlockRawChildrenEdit}
import markit.core.document.PersistentDocumentVersion
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.*
import markit.core.render.RenderRegistry
import markit.core.session.*
import markit.core.source.{EditableRopeStore, SourceBuffer, SourceSpan}
import markit.plugins.standard.inline.reference_link.*
import markit.plugins.standard.inline.link.{LinkNode, LinkHtmlRenderer}
import markit.plugins.standard.inline.image.{ImageNode, ImageHtmlRenderer}

private class ReferenceTestBaseCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "reference-test-base" } }
    public func accepts(node: Node): Bool { return node is DocumentNode || node is TextNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        if (node is DocumentNode) { return DocumentNode(SourceBuffer()) }
        let text = (node as TextNode).getOrThrow()
        return TextNode(text.id, text.sourceSpan, text.content)
    }
}

// Source never changes in these focused semantic-replay cases. The identity
// literal decoder is only fixture plumbing; the grammar under test is real.
private class ReferenceTestLiteral <: InlineLiteralFacet {
    public prop grammarVersion: String { get() { return "reference-test-identity" } }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow {
        return Some(InlineRecoveryWindow(context.change.startByte, context.change.oldEndByte,
            context.change.newEndByte, "unchanged-source semantic replay", grammarVersion))
    }
    public func decode(view: InlineTextView, a: Int64, b: Int64): String { return view.sliceBytes(a, b) }
    public func payload(view: InlineTextView, a: Int64, b: Int64, _: BlockEditingContext): ?PersistentTextPayload {
        return Some(PersistentTextPayload.withRawSpelling(decode(view, a, b), view.sliceBytes(a, b)))
    }
    public func projectRaw(_: InlineTextView, _: SourceAnchor, _: BlockEditingContext): ?Int64 { return None }
    public func splice(_: PersistentTextPayload, _: InlineRecoveryContext): ?InlineLiteralSplice { return None }
}

private func referenceApplyChildren(tree: PersistentDocumentVersion, edit: BlockRawChildrenEdit,
    version: Int64): PersistentDocumentVersion {
    var next = tree.splicingBundles(edit.parentId, edit.start, edit.deleteCount, edit.inserted, version)
    for (following in edit.following) { next = referenceApplyChildren(next, following, version) }
    return next
}

private class ReferenceReplayFixture {
    public let source: EditableRopeStore
    public let session: ParseSession
    public let effects = OwnedEffectStore()
    public let codec = NodeCodec()
    public let engine: InlineEditingSession
    public var snapshot: InlineEditingSnapshot
    public var tree: PersistentDocumentVersion
    public ReferenceReplayFixture(text: String, children!: Bool = false) {
        source = EditableRopeStore("reference-replay", text: text)
        session = ParseSession(SourceBuffer(editableSource: Some(source.current)), ParseOptions(),
            SessionSymbolTableStore(checkpointEnabled: true))
        session.symbolTables.register(ReferenceLinkPlugin.stateKey, { => ReferenceLinkRegistry() })
        codec.register(ReferenceTestBaseCodec()); registerReferenceEditingCodecs(codec)
        let dispatch = InlineDispatchTable(); let reference = ReferenceLinkParser()
        dispatch.register(reference); dispatch.register(ImageReferenceParser())
        if (children) {
            let childCodec = codec
            reference.configureEditingChildren({ => InlineEditingSession(dispatch, childCodec, ReferenceTestLiteral()) })
        }
        let legacy = InlineParserEngine(dispatch)
        session.setInlineParser({ active: ParseSession, body: String, span: SourceSpan => legacy.parse(active, body, span) })
        engine = InlineEditingSession(dispatch, codec, ReferenceTestLiteral())
        let tx = effects.beginTransaction()
        let context = BlockEditingContext(session, source.current, Option<PersistentDocumentVersion>.None, tx)
        session.editingContext = Some(context)
        session.root.sourceSpan = SourceSpan(0, source.current.byteLength, 0, source.current.runeLength)
        let owner = PersistentNodeCapture(codec).capture(session.root, source.current.identity).root
        snapshot = engine.parseInitial(context, RopeInlineTextView(source.current, 0, source.current.byteLength), owner)
        tree = PersistentDocumentVersion(PersistentNodeBundle(snapshot.root), source: Some(source))
        tx.commit()
    }
    public func changeDefinition(owner: Int64, label: String, url: ?String, order: Int64,
        commit!: Bool = true): InlineEditingSnapshot {
        let tx = effects.beginTransaction()
        let context = BlockEditingContext(session, source.current, Some(tree), tx)
        session.editingContext = Some(context)
        tx.revokeOwner(owner)
        if (let Some(value) <- url) { tx.add(OwnedSemanticEffect(owner, referenceSemanticKey(label), LinkDefinition(value, "title"), order)) }
        tx.refreshOwner(snapshot.semanticOwnerId, [referenceSemanticKey(label)])
        let next = engine.replaySemantic(snapshot, context,
            RopeInlineTextView(source.current, 0, source.current.byteLength), [referenceSemanticKey(label)])
        if (commit) {
            if (!refEq(next, snapshot)) {
                let edit = next.childrenEdit
                tree = referenceApplyChildren(tree, edit, source.current.identity.version)
            }
            snapshot = next; tx.commit()
        } else { tx.cancel() }
        return next
    }
    public func html(): String {
        let render = RenderRegistry()
        render.registerHtmlRenderer("Link", LinkHtmlRenderer()); render.registerHtmlRenderer("Image", ImageHtmlRenderer())
        return render.renderHtml(tree.materializeLegacy())
    }
}

@Test
@Tag[Task07ReferenceEditing]
class Task07ReferenceEditingTests {
    @TestCase
    func duplicateCandidateDeletionRestoresNextWinnerAndOldSnapshot() {
        let registry = ReferenceLinkRegistry()
        registry.addCandidate(1, "R", "/first", "a", 0)
        registry.addCandidate(2, "r", "/second", "b", 10)
        let saved = registry.snapshot()
        registry.revokeCandidate(1)
        @Expect(registry.getDefinition("R").getOrThrow().url, "/second")
        @Expect(registry.restoreSnapshot(saved), true)
        @Expect(registry.getDefinition("r").getOrThrow().url, "/first")
        @Expect(registry.candidateCount(), 2)
    }

    @TestCase
    func actualPositiveNegativeReadersReplayFullCollapsedShortcutAndImage() {
        let fixture = ReferenceReplayFixture("[x][r] [keep][other] [r][] [r] ![x][r] [z][other]")
        let old = fixture.tree
        let unrelatedReader = fixture.snapshot.root.childAt(2)
        @Expect(fixture.snapshot.readsSemantic(referenceSemanticKey("r")), true)
        @Expect(fixture.snapshot.readsSemantic(referenceSemanticKey("never")), false)
        fixture.changeDefinition(900, "r", Some("/first"), 0)
        let expected = "<a href=\"/first\" title=\"title\">x</a> [keep][other] <a href=\"/first\" title=\"title\">r</a> <a href=\"/first\" title=\"title\">r</a> <img src=\"/first\" alt=\"x\" title=\"title\" /> [z][other]"
        @Expect(fixture.html(), expected)
        @Expect(refEq(fixture.snapshot.root.childAt(2), unrelatedReader), true)
        @Expect(old.materializeLegacy().children[0] is TextNode, true)
        let untouched = fixture.tree.raw(fixture.snapshot.root.childAt(fixture.snapshot.root.childCount - 1).identity.nodeId).getOrThrow()
        fixture.changeDefinition(901, "unused", Some("/unused"), 0)
        @Expect(refEq(fixture.snapshot.root.childAt(fixture.snapshot.root.childCount - 1), untouched), true)
        fixture.changeDefinition(902, "r", Some("/second"), 10)
        fixture.changeDefinition(900, "r", Option<String>.None, 0)
        @Expect(fixture.html().contains("/second"), true)
        fixture.changeDefinition(902, "r", Option<String>.None, 10)
        @Expect(fixture.html(), "[x][r] [keep][other] [r][] [r] ![x][r] [z][other]")
        @Expect(fixture.tree.materializeLegacy().children[0].string("refLabel"), Some("r"))
        let nested = ReferenceReplayFixture("[![i][img]][r]", children: true)
        nested.changeDefinition(910, "r", Some("/outer"), 0)
        let beforeNested = nested.tree
        nested.changeDefinition(911, "img", Some("/inner"), 0)
        @Expect(nested.html(), "<a href=\"/outer\" title=\"title\"><img src=\"/inner\" alt=\"i\" title=\"title\" /></a>")
        @Expect(beforeNested.materializeLegacy().children[0].children[0] is TextNode, true)
        nested.changeDefinition(911, "img", Option<String>.None, 0)
        @Expect(nested.html(), "<a href=\"/outer\" title=\"title\">![i][img]</a>")
        let selective = ReferenceReplayFixture("[x][r] [y][s] [z][r]")
        selective.changeDefinition(920, "r", Some("/r"), 0)
        var hasS = false
        for (read in selective.effects.readDependencies(selective.snapshot.semanticOwnerId)) {
            if (read.key == referenceSemanticKey("s")) { hasS = true }
        }
        @Expect(hasS, true)
        selective.changeDefinition(921, "s", Some("/s"), 0)
        let keptS = selective.snapshot.root.childAt(2)
        selective.changeDefinition(920, "r", Option<String>.None, 0)
        @Expect(selective.html(), "[x][r] <a href=\"/s\" title=\"title\">y</a> [z][r]")
        @Expect(refEq(selective.snapshot.root.childAt(2), keptS), true)
        var hasR = false
        for (read in selective.effects.readDependencies(selective.snapshot.semanticOwnerId)) {
            if (read.key == referenceSemanticKey("r")) { hasR = true }
        }
        @Expect(hasR, true)
    }

    @TestCase
    func cancelSemanticCandidateLeavesOldTypedTreeAndEffectsUntouched() {
        let fixture = ReferenceReplayFixture("[x][r]")
        fixture.changeDefinition(900, "r", Some("/kept"), 0)
        let before = fixture.tree
        let staged = fixture.changeDefinition(900, "r", Some("/discarded"), 0, commit: false)
        @Expect(refEq(staged, fixture.snapshot), false)
        @Expect(refEq(before, fixture.tree), true)
        @Expect(fixture.html().contains("/kept"), true)
        @Expect((fixture.effects.winner(referenceSemanticKey("r")).getOrThrow().payload as LinkDefinition).getOrThrow().url, "/kept")
        let reentrant = fixture.effects.beginTransaction()
        let prepared = reentrant.prepare()
        let version = fixture.effects.version
        var rejected = false
        try {
            reentrant.reorderKey(referenceSemanticKey("r"), { effect: OwnedSemanticEffect =>
                reentrant.installPrepared(prepared); effect.order
            })
        } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(fixture.effects.version, version)
        @Expect((fixture.effects.winner(referenceSemanticKey("r")).getOrThrow().payload as LinkDefinition).getOrThrow().url, "/kept")
        reentrant.cancel()
        let scoped = fixture.effects.beginTransaction()
        let scope = scoped.beginScope()
        scoped.refreshOwner(fixture.snapshot.semanticOwnerId, [referenceSemanticKey("r")])
        scope.complete(false)
        scoped.commit()
        @Expect(fixture.effects.readDependencies(fixture.snapshot.semanticOwnerId).size, 1)
    }

    @TestCase
    func legacyTypedRendererAndCollapsedUnicodeSpansKeepProvenance() {
        let result = Markit().parse("[中文][] ![中文][]\n\n[中文]: /u \"t\"\n")
        let paragraph = result.root().children[0]
        let link = (paragraph.children[0] as LinkNode).getOrThrow()
        let image = (paragraph.children[2] as ImageNode).getOrThrow()
        @Expect(link.sourceSpan.endByte, 10)
        @Expect(link.sourceSpan.endRune, 6)
        @Expect(image.sourceSpan.startRune, 7)
        @Expect(image.sourceSpan.endRune, 14)
        @Expect(link.string("refLabel"), Some("中文"))
        @Expect(link.string("refForm"), Some("collapsed"))
        @Expect(image.string("refRaw"), Some("![中文][]"))
        @Expect(result.html().contains("href=\"/u\""), true)
        @Expect(Markit().parse("[**a**]").html(), "<p>[<strong>a</strong>]</p>")
    }

    @TestCase
    func largePrefixInsertionRebasesOnlyEditedKeyWithoutChangingOldWinnerSnapshot() {
        let source = EditableRopeStore("reference-order", text: "prefix\n[r]: /early\n[r]: /late\n")
        let session = ParseSession(SourceBuffer(editableSource: Some(source.current)), ParseOptions(),
            SessionSymbolTableStore(checkpointEnabled: true))
        session.symbolTables.register(ReferenceLinkPlugin.stateKey, { => ReferenceLinkRegistry() })
        let effects = OwnedEffectStore(); let tx = effects.beginTransaction()
        let context = BlockEditingContext(session, source.current, Option<PersistentDocumentVersion>.None, tx)
        session.editingContext = Some(context)
        let parser = LinkDefinitionParser()
        let initialLines = context.lines(0, source.current.byteLength)
        session.beginLine(initialLines[1]); let first = parser.tryParse(session, initialLines[1].text).getOrThrow()
        session.beginLine(initialLines[2]); let last = parser.tryParse(session, initialLines[2].text).getOrThrow()
        session.root.addChild(first); session.root.addChild(last)
        session.root.sourceSpan = SourceSpan(0, source.current.byteLength, 0, source.current.runeLength)
        let codec = NodeCodec(); codec.register(ReferenceTestBaseCodec()); registerReferenceEditingCodecs(codec)
        let oldTree = PersistentDocumentVersion(PersistentNodeCapture(codec).capture(session.root, source.current.identity), source: Some(source))
        tx.read(referenceSemanticKey("r"), 700); tx.commit()
        let before = effects.snapshot()
        let oldRead = effects.readDependencies(700)[0].winnerToken
        source.applyEdits(0, [EditingTextEdit(EditingRange(0, 0), String.fromUtf8(Array<Byte>(256, repeat: b'q')))])
        session.source.bindEditableSource(source.current)
        let changed = effects.beginTransaction()
        let current = BlockEditingContext(session, source.current, Some(oldTree), changed,
            resolve: Some({ anchor: SourceAnchor => source.resolve(anchor, source.current.identity.version) }))
        session.editingContext = Some(current)
        changed.revokeOwner(first.id)
        let newLine = current.lines(0, source.current.byteLength)[1]
        session.beginLine(newLine)
        let replacement = parser.tryParse(session, newLine.text).getOrThrow()
        @Expect(replacement.sourceSpan.startByte > last.sourceSpan.startByte, true)
        @Expect((changed.read(referenceSemanticKey("r"), 701).getOrThrow().payload as LinkDefinition).getOrThrow().url, "/early")
        changed.commit()
        let fresh = Markit().parse(source.current.sliceBytes(0, source.current.byteLength) + "\n[x][r]")
        let visible = fresh.root().children[fresh.root().children.size - 1].children[0]
        @Expect((visible as LinkNode).getOrThrow().url, (effects.winner(referenceSemanticKey("r")).getOrThrow().payload as LinkDefinition).getOrThrow().url)
        @Expect((before.winner(referenceSemanticKey("r")).getOrThrow().payload as LinkDefinition).getOrThrow().url, "/early")
        @Expect(oldTree.materializeLegacy().children[1].sourceSpan.startByte, last.sourceSpan.startByte)
        let remove = effects.beginTransaction(); remove.revokeOwner(replacement.id)
        @Expect((remove.read(referenceSemanticKey("r"), 702).getOrThrow().payload as LinkDefinition).getOrThrow().url, "/late")
        remove.commit()
        @Expect(effects.readDependencies(700)[0].winnerToken, oldRead)
        @Expect((before.winner(referenceSemanticKey("r")).getOrThrow().payload as LinkDefinition).getOrThrow().url, "/early")
    }
}
