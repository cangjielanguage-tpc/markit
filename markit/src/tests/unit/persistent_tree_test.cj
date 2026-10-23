package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.document.*
import markit.core.editing.*
import markit.core.nodes.*
import markit.core.source.{SourceBuffer, SourceRetentionMode, SourceSpan, EditableRopeStore}
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.inline.link.LinkNode

private class TreeTestPayload <: SyntaxNodePayload {
    public var value: String
    public init(value: String) { this.value = value }
    public prop codecId: String { get() { return "tree-test" } }
    public func clonePayload(): SyntaxNodePayload { return TreeTestPayload(value) }
}

private class TreeReferenceNode <: Node {
    public let references = ArrayList<Node>()
    public init(id: Int64) { super("TestReferences", id: id) }
}
private class TreeHandoffParagraph <: ParagraphNode {
    public TreeHandoffParagraph(public let deferred: TreeHandoffPayload) {
        super(deferred.nodeId, deferred.span, "")
    }
}
private class TreeHandoffPayload <: MaterializableNodePayload {
    private let prototype: ParagraphNode
    private let bundles: Array<PersistentNodeBundle>
    public prop codecId: String { get() { return "tree-handoff" } }
    public prop nodeId: Int64 { get() { return prototype.id } }
    public prop span: SourceSpan { get() { return prototype.sourceSpan } }
    public TreeHandoffPayload(base: ParagraphNode, children: Array<PersistentNodeBundle>, public let text: String) {
        let frozen = ParagraphNode(base.id, base.sourceSpan, "")
        base.copyBaseTo(frozen); prototype = frozen; bundles = children.clone()
    }
    public func clonePayload(): SyntaxNodePayload { return this }
    public func references(): Array<Int64> { return [] }
    public func originalSpan(): ?SourceSpan { return Some(span) }
    public func captureChildren(): ?Array<PersistentNodeBundle> { return Some(bundles.clone()) }
    public func restore(_: Node, references: Array<Node>): Unit {
        if (!references.isEmpty()) { throw IllegalArgumentException("Unexpected handoff references") }
    }
    public func materializeShallow(): Node {
        let node = ParagraphNode(nodeId, span, text)
        prototype.copyBaseTo(node); node.literal = text; node.setRawContent(text); return node
    }
    public func withText(next: String): TreeHandoffPayload { return TreeHandoffPayload(prototype, bundles, next) }
}

private class TreeTestCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "persistent-test" } }
    public func accepts(node: Node): Bool {
        return (node is DocumentNode) || (node is TextNode) || (node is HeadingNode) ||
            (node is ParagraphNode) || (node is LinkNode) || (node is TreeReferenceNode)
    }
    public func createShallow(node: Node): Node {
        if (let typed: DocumentNode <- node) { return DocumentNode(SourceBuffer()) }
        if (let typed: TextNode <- node) { return TextNode(typed.id, typed.sourceSpan, typed.content) }
        if (let typed: HeadingNode <- node) { return HeadingNode(typed.id, typed.sourceSpan, typed.content, typed.level, slug: typed.slug) }
        if (let typed: ParagraphNode <- node) { return ParagraphNode(typed.id, typed.sourceSpan, typed.content) }
        if (let typed: LinkNode <- node) { return LinkNode(typed.id, typed.sourceSpan, typed.content, typed.url, typed.title) }
        if (let typed: TreeReferenceNode <- node) { return TreeReferenceNode(typed.id) }
        throw IllegalArgumentException("Unsupported test codec")
    }
    public func capturePayload(node: Node, _: SourceVersionIdentity): ?SyntaxNodePayload {
        if (let deferredNode: TreeHandoffParagraph <- node) { return Some(deferredNode.deferred) }; return None
    }
    public func additionalReferences(node: Node): Array<Node> {
        if (let typed: TreeReferenceNode <- node) { return typed.references.toArray() }; return []
    }
    public func restoreReferences(target: Node, references: Array<Node>): Unit {
        if (let typed: TreeReferenceNode <- target) { for (reference in references) { typed.references.add(reference) } }
        else if (!references.isEmpty()) { throw IllegalArgumentException("Unexpected test references") }
    }
}

private func treeCodec(): NodeCodec { let codec = NodeCodec(); codec.register(TreeTestCodec()); return codec }
private func treeRaw(id: Int64, children!: Array<RawSyntaxNode> = [], documentId!: String = "tree",
    start!: Int64 = 0, end!: Int64 = 0): RawSyntaxNode {
    let source = SourceVersionIdentity(documentId, 0)
    return RawSyntaxNode(SyntaxNodeIdentity(documentId, id), 0, SourceAnchor(source, start), SourceAnchor(source, end),
        TreeTestPayload(id.toString()), children: children)
}

// A deliberately minimal ASCII contract fake. Actual rope integration belongs
// to Task05; these tests must not be mistaken for source implementation tests.
private class TreeSourceVersion <: EditableSourceVersion {
    private let sourceIdentity: SourceVersionIdentity
    private let text: String
    public init(documentId: String, version: Int64, text: String) { this.sourceIdentity = SourceVersionIdentity(documentId, version); this.text = text }
    public prop identity: SourceVersionIdentity { get() { return sourceIdentity } }
    public prop byteLength: Int64 { get() { return text.size } }
    public prop runeLength: Int64 { get() { return text.size } }
    public prop utf16Length: Int64 { get() { return text.size } }
    public prop lineCount: Int64 { get() { return 1 } }
    public func sliceBytes(start: Int64, end: Int64): String { return text[start..end] }
    public func coordinateAtByte(offset: Int64): ?SourceCoordinate {
        if (offset < 0 || offset > text.size) { return None }; return Some(SourceCoordinate(offset, offset, offset, 0, offset))
    }
    public func byteAtCoordinate(offset: Int64, coordinate: EditingCoordinate): ?Int64 { return if (offset >= 0 && offset <= text.size) { Some(offset) } else { None } }
    public func byteAtLineColumn(line: Int64, column: Int64): ?Int64 { return if (line == 0) { byteAtCoordinate(column, EditingCoordinate.Utf8Byte) } else { None } }
    public func lineAt(index: Int64): ?EditingSourceLine { return if (index == 0) { Some(EditingSourceLine(0, 0, text, "")) } else { None } }
}
private class TreeSourceStore <: EditableSourceStore {
    private var view: EditableSourceVersion
    private var prefix: Int64 = 0
    public init(documentId!: String = "tree") { this.view = TreeSourceVersion(documentId, 0, "abcd") }
    public prop current: EditableSourceVersion { get() { return view } }
    public func advance(): Unit { prefix = 3; view = TreeSourceVersion(view.identity.documentId, 1, "xyzabcd") }
    public func applyEdits(expectedVersion: Int64, edits: Array<EditingTextEdit>): EditableSourceVersion { throw IllegalArgumentException("Fake does not edit") }
    public func resolve(anchor: SourceAnchor, targetVersion: Int64): ?Int64 {
        if (anchor.source.documentId != view.identity.documentId || targetVersion > view.identity.version) { return None }
        return Some(anchor.byteOffset + if (targetVersion == 1 && anchor.source.version == 0) { prefix } else { 0 })
    }
}
private class CountingTreeSource <: EditableSourceStore {
    public let actual: EditableRopeStore
    public var resolveCalls: Int64 = 0
    public init(text: String) { this.actual = EditableRopeStore("tree", text: text) }
    public prop current: EditableSourceVersion { get() { return actual.current } }
    public func applyEdits(expectedVersion: Int64, edits: Array<EditingTextEdit>): EditableSourceVersion { return actual.applyEdits(expectedVersion, edits) }
    public func resolve(anchor: SourceAnchor, targetVersion: Int64): ?Int64 { resolveCalls += 1; return actual.resolve(anchor, targetVersion) }
}

@Test
@Tag[PersistentTree]
class PersistentTreeTests {
    @TestCase
    func payloadPreviewAndTwoEditsPreserveHandedChildrenAuxiliaryBindingsAndMetadata() {
        let codec = treeCodec(); let source = EditableRopeStore("tree", text: "abcd")
        let reference = TreeReferenceNode(2)
        let auxiliary = ParagraphNode(10, SourceSpan.empty(), "aux")
        auxiliary.setString("label", "old-aux"); auxiliary.setInt("rank", 7); auxiliary.setBool("enabled", true)
        reference.references.add(auxiliary)
        let child = PersistentNodeCapture(codec).capture(reference, source.current.identity)
        let base = ParagraphNode(1, SourceSpan(0, 4, 0, 4), "abcd")
        base.setString("label", "parent"); base.setInt("rank", 9); base.setBool("enabled", true)
        let payload = TreeHandoffPayload(base, [child], "abcd")
        let root = DocumentNode(SourceBuffer()); root.addChild(TreeHandoffParagraph(payload))
        let initial = PersistentDocumentVersion(PersistentNodeCapture(codec).capture(root, source.current.identity), source: Some(source))
        @Expect(refEq(initial.raw(2).getOrThrow(), child.root), true)
        @Expect(refEq(initial.raw(10).getOrThrow(), child.auxiliaryRecords()[0]), true)
        let store = PersistentDocumentStore(initial)
        source.applyEdits(0, [EditingTextEdit(EditingRange(1, 2), "B")])
        let first = store.beginPreparedTransaction(0)
        first.replacePayload(1, payload.withText("aBcd"), 1)
        let preview = first.preview(1)
        @Expect(preview.materializeLegacy().children[0].literal, "aBcd")
        @Expect(store.snapshot.version, 0)
        first.replacePayload(1, payload.withText("aBcd"), 1) // preview did not seal
        first.commit(1)
        source.applyEdits(1, [EditingTextEdit(EditingRange(2, 3), "C")])
        let second = store.beginPreparedTransaction(1)
        second.replacePayload(1, payload.withText("aBCd"), 2); second.commit(2)
        @Expect(refEq(store.snapshot.raw(2).getOrThrow(), child.root), true)
        @Expect(refEq(store.snapshot.raw(10).getOrThrow(), initial.raw(10).getOrThrow()), true)
        let exported = store.snapshot.materializeLegacy()
        @Expect(exported.children[0].literal, "aBCd")
        @Expect(exported.children[0].string("label"), Some("parent"))
        @Expect(exported.children[0].int("rank"), Some(9)); @Expect(exported.children[0].bool("enabled"), Some(true))
        let target = (exported.children[0].children[0] as TreeReferenceNode).getOrThrow().references[0]
        @Expect(target.string("label"), Some("old-aux")); @Expect(target.int("rank"), Some(7))
        @Expect(target.bool("enabled"), Some(true))
        @Expect(initial.materializeLegacy().children[0].literal, "abcd")
        @Expect(preview.materializeLegacy().children[0].literal, "aBcd")
    }
    @TestCase
    func middleReplacementSharesRawRecordsAndKeepsVersionPaths() {
        let left = treeRaw(1); let middle = treeRaw(2, children: [treeRaw(4)]); let right = treeRaw(3)
        let original = PersistentDocumentVersion(PersistentNodeBundle(treeRaw(0, children: [left, middle, right])))
        let store = PersistentDocumentStore(original)
        let transaction = store.beginTransaction(0)
        transaction.replace(2, treeRaw(2, children: [treeRaw(5)]))
        transaction.commit(1)
        let next = store.snapshot
        @Expect(refEq(next.raw(1).getOrThrow(), original.raw(1).getOrThrow()), true)
        @Expect(refEq(next.raw(3).getOrThrow(), original.raw(3).getOrThrow()), true)
        @Expect(refEq(next.raw(0).getOrThrow(), original.raw(0).getOrThrow()), false)
        @Expect(original.find(4).isSome(), true); @Expect(next.find(4).isNone(), true)
        @Expect(next.find(5).isSome(), true); @Expect(original.find(5).isNone(), true)
        @Expect(original.view(4).getOrThrow().parent().getOrThrow().syntax.identity.nodeId, 2)
        @Expect(next.pathTo(5).size, 3); @Expect(next.pathTo(5)[0], 0)
        @Expect(original.version, 0); @Expect(next.version, 1)
    }

    @TestCase
    func detachedTypedViewsPreserveRealRenderersAndAllMetadata() {
        let parsed = Markit().parse("# title\n\n[label](target \"caption\")")
        let root = parsed.root()
        root.children[0].setString("same", "s"); root.children[0].setInt("same", 9); root.children[0].setBool("same", true)
        root.children[0].setRawContent("# original spelling")
        let before = root.toHtml(); let json = root.toJson()
        let codec = treeCodec()
        let original = PersistentDocumentVersion(PersistentNodeCapture(codec).capture(root, SourceVersionIdentity("tree", 0)))
        let oldExport = original.materializeLegacy()
        @Expect(oldExport.toHtml(), before); @Expect(oldExport.toJson(), json)
        @Expect(oldExport.children[0] is HeadingNode, true)
        @Expect(oldExport.children[1].children[0] is LinkNode, true)
        oldExport.children[0].setString("same", "mutated")
        oldExport.children[0].setInt("same", 99); oldExport.children[0].setBool("same", false)
        oldExport.children[0].setRawContent("changed")
        let again = original.materializeLegacy()
        @Expect(again.children[0].string("same"), Some("s")); @Expect(again.children[0].int("same"), Some(9))
        @Expect(again.children[0].bool("same"), Some(true)); @Expect(again.children[0].rawContent(), "# original spelling")
        if (let Some(parent) <- again.children[0].parent) { @Expect(refEq(parent, again), true) } else { @Assert(false) }
        let replacement = HeadingNode(root.children[0].id, root.children[0].sourceSpan, "new", 1)
        let captured = PersistentNodeCapture(codec).capture(replacement, SourceVersionIdentity("tree", 1))
        let next = original.replacing(replacement.id, captured.root, 1)
        @Expect(refEq(original.raw(root.children[1].id).getOrThrow(), next.raw(root.children[1].id).getOrThrow()), true)
        @Expect(original.materializeLegacy().toHtml(), before)
        @Expect(next.materializeLegacy().children[0].literal, "new")
    }

    @TestCase
    func duplicateIdsCancelAndStaleTransactionsNeverPublish() {
        let original = PersistentDocumentVersion(PersistentNodeBundle(treeRaw(0, children: [treeRaw(1), treeRaw(2)])))
        let store = PersistentDocumentStore(original)
        let bad = store.beginTransaction(0)
        var rejected = false
        try { bad.replace(1, treeRaw(2)) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true); @Expect(refEq(store.snapshot, original), true)
        bad.cancel()
        let cancelled = store.beginTransaction(0); cancelled.replace(1, treeRaw(3)); cancelled.cancel()
        @Expect(store.snapshot.find(3).isNone(), true)
        let first = store.beginTransaction(0); let stale = store.beginTransaction(0)
        first.replace(1, treeRaw(3)); first.commit(1)
        rejected = false
        try { stale.commit(1) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true); @Expect(store.snapshot.find(3).isSome(), true)
        rejected = false
        try { PersistentDocumentVersion(PersistentNodeBundle(treeRaw(0, children: [treeRaw(1), treeRaw(1)]))) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
    }

    @TestCase
    func auxiliaryDescendantReplacementKeepsDocumentRootAndChecksDuplicates() {
        let document = treeRaw(0)
        let auxiliary = treeRaw(10, children: [treeRaw(11)])
        let original = PersistentDocumentVersion(PersistentNodeBundle(document, records: [auxiliary]))
        let next = original.replacing(11, treeRaw(12), 1)
        @Expect(next.root.identity.nodeId, 0); @Expect(refEq(next.raw(0).getOrThrow(), document), true)
        @Expect(next.raw(10).getOrThrow().childAt(0).identity.nodeId, 12)
        @Expect(original.raw(10).getOrThrow().childAt(0).identity.nodeId, 11)
        var rejected = false
        try { PersistentDocumentVersion(PersistentNodeBundle(document, records: [treeRaw(0)])) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try { PersistentDocumentVersion(PersistentNodeBundle(document, records: [treeRaw(0, documentId: "other")])) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
    }

    @TestCase
    func codecAdditionalReferencesPreserveAliasesAndDoNotLeakMutableArrays() {
        let root = TreeReferenceNode(0)
        let auxiliary = TreeReferenceNode(10)
        let text = TextNode(11, SourceSpan.empty(), "hidden")
        auxiliary.addChild(text); root.references.add(auxiliary); auxiliary.references.add(text)
        let version = PersistentDocumentVersion(PersistentNodeCapture(treeCodec()).capture(root, SourceVersionIdentity("tree", 0)))
        if (let copy: TreeReferenceNode <- version.materializeLegacy()) {
            if (let ref: TreeReferenceNode <- copy.references[0]) {
                @Expect(refEq(ref.references[0], ref.children[0]), true)
                @Expect(ref.children[0].parent.isSome(), true)
                ref.references.clear(); ref.children[0].setString("leak", "bad")
            } else { @Assert(false) }
        } else { @Assert(false) }
        if (let copy: TreeReferenceNode <- version.materializeLegacy()) {
            if (let ref: TreeReferenceNode <- copy.references[0]) { @Expect(ref.references.size, 1); @Expect(ref.children[0].string("leak").isNone(), true) }
        }
    }

    @TestCase
    func rawArraysPayloadsAndOriginalAppendSourceAreIsolated() {
        let payload = TreeTestPayload("original")
        let source = SourceVersionIdentity("tree", 0)
        let children = [treeRaw(1)]
        let root = RawSyntaxNode(SyntaxNodeIdentity("tree", 0), 0, SourceAnchor(source, 0), SourceAnchor(source, 0), payload, children: children)
        children[0] = treeRaw(2); payload.value = "changed"
        let returned = root.children(); returned[0] = treeRaw(3)
        @Expect(root.childAt(0).identity.nodeId, 1)
        if (let copy: TreeTestPayload <- root.payload) { @Expect(copy.value, "original"); copy.value = "leak" }
        if (let copy: TreeTestPayload <- root.payload) { @Expect(copy.value, "original") }
        let buffer = SourceBuffer(retentionMode: SourceRetentionMode.Full); buffer.append("old")
        let document = DocumentNode(buffer); document.addChild(TextNode(1, SourceSpan(0, 3, 0, 3), "old"))
        let version = PersistentDocumentVersion(PersistentNodeCapture(treeCodec()).capture(document, source))
        buffer.append(" later")
        @Expect(version.materializeLegacy().rawContent(), "old")
    }

    @TestCase
    func boundedLogicalTextSpliceReusesUntouchedSegmentsAndLegacyShape() {
        let large = String.fromUtf8(Array<UInt8>(1024 * 512, { _ => UInt8(97) }))
        let payload = PersistentTextPayload(large)
        let before = payload.segments(0, payload.byteLength)
        let next = payload.splice(262144, 262145, "<&😀字>")
        let after = next.segments(0, next.byteLength)
        @Expect(refEq(before[0], after[0]), true)
        @Expect(refEq(before[before.size - 1], after[after.size - 1]), true)
        @Expect(before.size, 512)
        for (segment in after) { @Expect(segment.text.size <= 1024, true) }
        @Expect(next.materialize(), large[0..262144] + "<&😀字>" + large[262145..large.size])
        @Expect(payload.materialize(), large)
        let prefix = payload.sliced(0, 262144)
        let suffix = payload.sliced(262144, payload.byteLength)
        let combined = prefix.concatenated(suffix)
        @Expect(combined.materialize(), large)
        let combinedSegments = combined.segments(0, combined.byteLength)
        @Expect(refEq(before[0], combinedSegments[0]), true)
        @Expect(refEq(before[before.size - 1], combinedSegments[combinedSegments.size - 1]), true)
        @Expect(payload.materialize(), large)
        let legacy = next.materializeNode(9, SourceSpan.empty())
        @Expect(legacy.children.size, 0); @Expect(legacy is TextNode, true)
        @Expect(legacy.content, next.materialize()); @Expect(legacy.toJson().contains("TextNode"), true)
        let unicode = PersistentTextPayload("<&😀字>")
        @Expect(unicode.splice(2, 6, "好").materialize(), "<&好字>")
        var rejected = false
        try { unicode.splice(3, 4, "x") } catch (_: Exception) { rejected = true }
        @Expect(rejected, true); @Expect(unicode.materialize(), "<&😀字>")
    }

    @TestCase
    func lazyAnchorsResolveWithoutRewritingRawOffsetsAndRejectCrossDocumentSource() {
        let source = TreeSourceStore()
        let original = PersistentDocumentVersion(PersistentNodeBundle(treeRaw(0, children: [treeRaw(1, start: 1, end: 3)], start: 0, end: 4)), source: Some(source))
        source.advance()
        let next = original.atVersion(1)
        @Expect(refEq(original.raw(1).getOrThrow(), next.raw(1).getOrThrow()), true)
        @Expect(next.raw(1).getOrThrow().startAnchor.byteOffset, 1)
        @Expect(next.view(1).getOrThrow().sourceSpan().getOrThrow().startByte, 4)
        @Expect(original.resolve(original.raw(1).getOrThrow().startAnchor), Some(1))
        @Expect(next.nodesInByteRange(4, 5).size, 2)
        var rejected = false
        try { PersistentDocumentVersion(PersistentNodeBundle(treeRaw(0)), source: Some(TreeSourceStore(documentId: "other"))) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
    }

    @TestCase
    func capturedLogicalTextEditsThroughDocumentKeepMetadataRawAndSingleNode() {
        let root = DocumentNode(SourceBuffer())
        let text = TextNode(1, SourceSpan(0, 7, 0, 4), "a😀bc")
        text.setString("s", "kept"); text.setInt("i", 12); text.setBool("b", true)
        root.addChild(text)
        let original = PersistentDocumentVersion(PersistentNodeCapture(treeCodec()).capture(root, SourceVersionIdentity("tree", 0)))
        let record = original.raw(1).getOrThrow()
        if (let payload: PersistentTextPayload <- record.payload) {
            let joined = payload.sliced(0, 1).concatenated(payload.sliced(1, payload.byteLength))
            let preserved = joined.materializeNode(1, text.sourceSpan)
            @Expect(preserved.literal, text.literal)
            @Expect(preserved.string("s"), Some("kept")); @Expect(preserved.int("i"), Some(12))
            @Expect(preserved.bool("b"), Some(true))
            var rejected = false
            try { joined.materializeNode(999, text.sourceSpan) } catch (_: IllegalArgumentException) { rejected = true }
            @Expect(rejected, true)
            rejected = false
            try { joined.concatenated(PersistentTextPayload.fromNode(TextNode(2, SourceSpan.empty(), "x"))) }
            catch (_: IllegalArgumentException) { rejected = true }
            @Expect(rejected, true)
            let spelled = TextNode(3, SourceSpan.empty(), "ab"); spelled.setRawContent("*ab*")
            let rawPayload = PersistentTextPayload.fromNode(spelled)
            rejected = false
            try { rawPayload.sliced(0, 1) } catch (_: IllegalArgumentException) { rejected = true }
            @Expect(rejected, true)
            @Expect(rawPayload.sliced(0, 2).materializeNode(3, SourceSpan.empty()).rawContent(), "*ab*")
            let changed = record.withPayload(payload.splice(1, 5, "好"), 1)
            let store = PersistentDocumentStore(original)
            let edit = store.beginTransaction(0); edit.replace(1, changed); edit.commit(1)
            let legacy = store.snapshot.materializeLegacy()
            @Expect(legacy.children.size, 1); @Expect(legacy.children[0].children.size, 0)
            @Expect(legacy.children[0].id, 1); @Expect(legacy.children[0].literal, "a好bc")
            @Expect(legacy.children[0].rawContent(), "a好bc")
            @Expect(legacy.children[0].string("s"), Some("kept")); @Expect(legacy.children[0].int("i"), Some(12))
            @Expect(legacy.children[0].bool("b"), Some(true))
            @Expect(original.materializeLegacy().children[0].literal, "a😀bc")
            @Expect(original.materializeLegacy().children[0].rawContent(), "a😀bc")
        } else { @Assert(false) }
    }

    @TestCase
    func realSourceMixedBirthSummariesKeepRangeQueriesLocal() {
        let source = CountingTreeSource(String.fromUtf8(Array<Byte>(256, repeat: 97)))
        let original = SourceVersionIdentity("tree", 0)
        let children = Array<RawSyntaxNode>(256, { i =>
            RawSyntaxNode(SyntaxNodeIdentity("tree", i + 1), 0,
                SourceAnchor(original, i, affinity: AnchorAffinity.Before), SourceAnchor(original, i + 1, affinity: AnchorAffinity.After), TreeTestPayload("a"))
        })
        var version = PersistentDocumentVersion(PersistentNodeBundle(treeRaw(0, children: children, end: 256)), source: Some(source))
        let untouched = version.raw(256).getOrThrow()
        for (step in 0..128) {
            let point = step * 2
            source.applyEdits(step, [EditingTextEdit(EditingRange(point, point + 1), "b")])
            let identity = source.current.identity
            let changed = RawSyntaxNode(SyntaxNodeIdentity("tree", point + 1), identity.version,
                SourceAnchor(identity, point, affinity: AnchorAffinity.Before), SourceAnchor(identity, point + 1, affinity: AnchorAffinity.After), TreeTestPayload("b"))
            version = version.replacing(point + 1, changed, identity.version)
        }
        // Range queries preserve the legacy inclusive intersection rule.
        // An old After endpoint at a later replacement's start follows that
        // replacement to its new end, so node252 also touches query253.
        let expectedIds = [Int64(0), 252, 253, 254, 255]
        let expectedStarts = [Int64(1), 251, 252, 253, 254]
        let expectedEnds = [Int64(256), 253, 253, 255, 255]
        let referenceIds = ArrayList<Int64>()
        for (id in 0..257) {
            let node = version.raw(id).getOrThrow()
            let start = version.resolve(node.startAnchor).getOrThrow()
            let end = version.resolve(node.endAnchor).getOrThrow()
            if (start <= 254 && end >= 253) { referenceIds.add(id) }
        }
        @Expect(referenceIds.size, expectedIds.size)
        for (i in 0..expectedIds.size) {
            @Expect(referenceIds[i], expectedIds[i])
            let node = version.raw(expectedIds[i]).getOrThrow()
            @Expect(version.resolve(node.startAnchor), Some(expectedStarts[i]))
            @Expect(version.resolve(node.endAnchor), Some(expectedEnds[i]))
        }
        source.resolveCalls = 0
        let result = version.nodesInByteRange(253, 254)
        @Expect(result.size, referenceIds.size)
        if (result.size == referenceIds.size) {
            for (i in 0..result.size) { @Expect(result[i].identity.nodeId, referenceIds[i]) }
        }
        @Expect(source.resolveCalls < 100, true)
        @Expect(refEq(untouched, version.raw(256).getOrThrow()), true)
        @Expect(untouched.startAnchor.source.version, 0)
    }

    @TestCase
    func coincidentBeforeAfterBoundsRemainSafeAfterRealInsertion() {
        let source = CountingTreeSource("")
        let identity = source.current.identity
        let before = SourceAnchor(identity, 0, affinity: AnchorAffinity.Before)
        let after = SourceAnchor(identity, 0, affinity: AnchorAffinity.After)
        let later = RawSyntaxNode(SyntaxNodeIdentity("tree", 1), 0, after, after, TreeTestPayload("after"))
        let earlier = RawSyntaxNode(SyntaxNodeIdentity("tree", 2), 0, before, before, TreeTestPayload("before"))
        let root = RawSyntaxNode(SyntaxNodeIdentity("tree", 0), 0, before, after, TreeTestPayload("root"), children: [later, earlier])
        let original = PersistentDocumentVersion(PersistentNodeBundle(root), source: Some(source))
        source.applyEdits(0, [EditingTextEdit(EditingRange(0, 0), "x")])
        let next = original.atVersion(1)
        let found = next.nodesInByteRange(0, 0)
        @Expect(found.size, 2)
        @Expect(found[1].identity.nodeId, 2)
    }
}
