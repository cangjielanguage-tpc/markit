package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.block.*
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.*
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.*
import markit.core.source.{SourceBuffer, SourceLine, SourceSpan}

private class BridgePayload <: IncrementalStatePayload {
    public func fingerprint(): String { return "bridge-v1" }
    public func clonePayload(): IncrementalStatePayload { return BridgePayload() }
}
private class BridgeParentNode <: Node {
    public BridgeParentNode(id: Int64, span: SourceSpan, public let saved: ?ParseSessionCheckpoint,
        public let syntax: ?IncrementalCheckpoint) { super("BridgeParent", id: id, sourceSpan: span) }
}
private class BridgeParentCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "bridge-parent-v1" } }
    public func accepts(node: Node): Bool { return node is BridgeParentNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        let parent = (node as BridgeParentNode).getOrThrow()
        return BridgeParentNode(parent.id, parent.sourceSpan, parent.saved, parent.syntax)
    }
}
private func bridgeCodec(): NodeCodec { let codec = task06Codec(); codec.register(BridgeParentCodec()); return codec }
private func bridgeValue(effect: OwnedSemanticEffect): String { return (effect.payload as StringEffectPayload).getOrThrow().value }

// A fixed three-child test block owns no parent-level contribution. Its middle
// child's localized rollback is performed before parse; the other two owners
// must survive the outer DocumentEditingSession's publication machinery.
private class BridgeBlockFacet <: BlockEditingFacet {
    public var syntaxCalls: Int64 = 0
    public prop owner: String { get() { return "bridge-block" } }
    public prop grammarVersion: String { get() { return "bridge-v1" } }
    public prop preservesUntouchedChildEffects: Bool { get() { return true } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion, BridgePayload(), syntaxContext: "bridge"))
    }
    public func restore(context: IncrementalParserContext, checkpoint: IncrementalCheckpoint): Bool {
        return checkpoint.documentId == context.documentId && checkpoint.owner == owner && checkpoint.payload is BridgePayload
    }
    public func rollbackEffects(context: IncrementalParserContext, checkpoint: IncrementalCheckpoint): Bool {
        // Localized child rollback is in parseUnit; no parent-wide revoke.
        return restore(context, checkpoint)
    }
    public func syntaxEquivalent(previous: IncrementalCheckpoint, current: IncrementalCheckpoint): Bool {
        return previous.owner == current.owner && previous.syntaxContext == current.syntaxContext &&
            previous.payload.fingerprint() == current.payload.fingerprint()
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func syntaxReadKeys(_: RawSyntaxNode): ?Array<String> { return Some(Array<String>()) }
    public func owns(node: RawSyntaxNode): Bool {
        if (let payload: TypedSyntaxPayload <- node.payload) { return payload.materializeShallow() is BridgeParentNode }
        return false
    }
    public func recover(context: BlockEditingContext, node: RawSyntaxNode, _: Int64, _: Int64): ?BlockRecoveryUnit {
        let parent = ((node.payload as TypedSyntaxPayload).getOrThrow().materializeShallow() as BridgeParentNode).getOrThrow()
        if (parent.saved.isNone() || parent.syntax.isNone()) { return None }
        let kernel = BlockParsingKernel(context.session, ContinuationBlockDispatchTable(), BlockDispatchTable(), ArrayList<ParagraphBlockParser>())
        return Some(BlockRecoveryUnit(owner, node.identity.nodeId, node.startAnchor, node.endAnchor,
            parent.saved.getOrThrow(), kernel.checkpoint(), parent.syntax.getOrThrow(),
            expectedExit: parent.syntax, expectedKernel: Some(kernel.checkpoint())))
    }
    public func parseUnit(context: BlockEditingContext, unit: BlockRecoveryUnit, _: BlockParsingKernel): BlockUnitParseResult {
        syntaxCalls += 1
        let parent = context.previous.getOrThrow().raw(unit.nodeId).getOrThrow()
        let old = parent.childAt(1)
        let start = context.resolve(old.startAnchor).getOrThrow()
        let end = context.resolve(old.endAnchor).getOrThrow()
        let text = context.source.sliceBytes(start, end)
        context.effects.revokeOriginalOwner(old.identity.nodeId)
        context.effects.add(OwnedSemanticEffect(old.identity.nodeId, "middle", StringEffectPayload(text), 3))
        let replacement = RawSyntaxNode(old.identity, context.sourceVersion,
            SourceAnchor(context.source.identity, start, affinity: AnchorAffinity.Before),
            SourceAnchor(context.source.identity, end, affinity: AnchorAffinity.After), PersistentTextPayload(text))
        let textPatch = LogicalTextSplice(old.identity.nodeId, 1, 2, text[1..2])
        return BlockUnitParseResult(Node("unpublished-bridge-placeholder"), checkpoint(context).getOrThrow(),
            rawSplice: Some(BlockRawChildrenEdit([PersistentNodeBundle(replacement)], [textPatch], parent.identity.nodeId, 1, 1)))
    }
}
private class BridgeLeaf <: LeafBlockParser {
    public BridgeLeaf(private let facet: BridgeBlockFacet) {}
    public prop name: String { get() { return "bridge-three-child" } }
    public prop ownerPlugin: String { get() { return facet.owner } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [] } }
    public prop acceptsAnyNonBlank: Bool { get() { return true } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public func tryParse(session: ParseSession, line: String): ?Node {
        if (line.size != 9) { return None }
        var saved: ?ParseSessionCheckpoint = None; var entry: ?IncrementalCheckpoint = None
        if (let Some(context) <- session.editingContext) { saved = Some(session.checkpoint()); entry = facet.checkpoint(context) }
        let parent = session.attachNode(BridgeParentNode(session.allocateNodeId(), session.currentLineSpan(), saved, entry))
        for (i in 0..3) {
            let base = session.currentLineSpan()
            let span = SourceSpan(base.startByte + i * 3, base.startByte + i * 3 + 3, base.startRune + i * 3, base.startRune + i * 3 + 3)
            let child = session.createTextNode(line[i * 3..i * 3 + 3], span)
            parent.addChild(child)
            if (let Some(borrowed) <- session.editingContext) {
                let context = (borrowed as BlockEditingContext).getOrThrow()
                let key = if (i == 0) { "left" } else if (i == 1) { "middle" } else { "right" }
                context.effects.add(OwnedSemanticEffect(child.id, key, StringEffectPayload(child.content), i * 3))
            }
        }
        return Some(parent)
    }
}
private class BridgeChangingInline <: InlineParser {
    private let original = Task06InlineGrammar()
    private let changed = Task06InlineGrammar()
    public var drift: Bool = false
    public prop name: String { get() { return "bridge-inline-identity" } }
    public prop ownerPlugin: String { get() { return original.owner } }
    public prop priority: Int64 { get() { return 10 } }
    public prop startBytes: Array<Byte> { get() { return original.startBytes } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(if (drift) { changed } else { original }) } }
    public func tryParse(session: ParseSession, input: String, start: Int64, end: Int64, span: SourceSpan): ?InlineParseResult {
        return original.tryParse(session, input, start, end, span)
    }
}
private class BridgePlugin <: Plugin {
    public let facet = BridgeBlockFacet()
    public let inline = BridgeChangingInline()
    public prop name: String { get() { return "bridge-block" } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(BridgeLeaf(facet)); registrar.registerInlineParser(inline)
    }
}

private class BridgeFactoryWitness { public var created: Int64 = 0; public var calls: Int64 = 0 }
private class BridgeLegacyState <: SessionState {
    public func reset(): Unit {}
    public func snapshot(): SessionStateSnapshot { return SessionStateSnapshot("bridge-state") }
}
private class BridgeFlagsOnly <: IncrementalParserFacet {
    public prop owner: String { get() { return "bridge-flags-only" } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion, BridgePayload()))
    }
    public func restore(context: IncrementalParserContext, checkpoint: IncrementalCheckpoint): Bool { return checkpoint.documentId == context.documentId }
    public func rollbackEffects(context: IncrementalParserContext, _: IncrementalCheckpoint): Bool { return context.revokeOwnerEffects(owner) }
    public func syntaxEquivalent(previous: IncrementalCheckpoint, current: IncrementalCheckpoint): Bool { return previous.payload.fingerprint() == current.payload.fingerprint() }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
}
private class BridgeFlagsParser <: InlineParser {
    private let facet = BridgeFlagsOnly()
    public BridgeFlagsParser(private let witness: BridgeFactoryWitness) {}
    public prop name: String { get() { return "flags-without-execution" } }
    public prop ownerPlugin: String { get() { return facet.owner } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [64] } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public func tryParse(_: ParseSession, _: String, _: Int64, _: Int64, _: SourceSpan): ?InlineParseResult { witness.calls += 1; return None }
}
private class BridgeFlagsPlugin <: Plugin {
    public BridgeFlagsPlugin(public let witness: BridgeFactoryWitness) {}
    public prop name: String { get() { return "bridge-flags-only" } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(BridgeFlagsParser(witness))
        registrar.registerState(SessionStateKey<BridgeLegacyState>("bridge-flags-only", "bridge-state"), { => witness.created += 1; BridgeLegacyState() })
    }
}
private class BridgeLegacyParagraph <: ParagraphBlockParser {
    public prop name: String { get() { return "bridge-legacy-paragraph" } }
    public prop ownerPlugin: String { get() { return "bridge-after-rejection" } }
    public func canStart(_: ParseSession, line: String): Bool { return !line.isEmpty() }
    public func normalizeLine(_: ParseSession, line: String): String { return line }
    public func finalize(session: ParseSession, lines: ArrayList<SourceLine>, span: SourceSpan,
        _: ParagraphTermination): Node {
        var text = ""
        for (index in 0..lines.size) {
            if (index > 0) { text += "\n" }
            text += lines[index].text
        }
        return session.attachNode(TextNode(session.allocateNodeId(), span, text))
    }
}
private class BridgeLegacyParagraphPlugin <: Plugin {
    public prop name: String { get() { return "bridge-after-rejection" } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerParagraphBlockParser(BridgeLegacyParagraph())
    }
}

@Test
@Tag[InlineEditing, Task06InlineBridge]
class Task06InlineBridgeTests {
    @TestCase
    func strictRejectsGenericFlagsBeforeConstructionWithoutFreezingAndCompatPublishesFreshLegacy() {
        let witness = BridgeFactoryWitness()
        let app = Markit(useStandard: false).use(BridgeFlagsPlugin(witness))
        var rejected = false
        try { app.createEditingSession("bridge-reject", "@body;", task06Codec(), policy: EditingPolicy.Strict) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(witness.created, 0)
        @Expect(witness.calls, 0)
        app.use(BridgeLegacyParagraphPlugin())
        let session = app.createEditingSession("bridge-compat", "abc", task06Codec())
        let old = session.snapshot()
        @Expect(old.fallbackScope, EditingFallbackScope.Session)
        @Expect(old.legacySnapshot.getOrThrow().root.children[0].literal, "abc")
        session.applyEdits(0, [EditingTextEdit(EditingRange(1, 2), "Z")])
        @Expect(session.versions.sourceVersion, 1)
        @Expect(session.versions.parseVersion, 0)
        @Expect(session.flush().committed, true)
        let current = session.snapshot()
        @Expect(current.legacySnapshot.getOrThrow().root.children[0].literal, "aZc")
        @Expect(app.parse("aZc").snapshot.root.children[0].literal, current.legacySnapshot.getOrThrow().root.children[0].literal)
        @Expect(old.legacySnapshot.getOrThrow().root.children[0].literal, "abc")
        @Expect(witness.created > 0, true)
        old.release(); current.release(); session.close()
    }

    @TestCase
    func rawChildSplicePreservesSiblingEffectsAndPublishesSmallLogicalPatchWithSameIdNewEffect() {
        let plugin = BridgePlugin()
        let session = Markit(useStandard: false).use(plugin).createEditingSession("bridge-splice", "abcDEFghi\n", bridgeCodec(), policy: EditingPolicy.Strict)
        let old = session.snapshot(); let oldParent = old.tree.raw(1).getOrThrow()
        let middle = oldParent.childAt(1).identity.nodeId
        session.applyEdits(0, [EditingTextEdit(EditingRange(4, 5), "x")])
        let result = session.flush()
        @Expect(result.committed, true)
        @Expect(result.syntaxUnitsParsed, 1)
        let current = session.snapshot(); let parent = current.tree.raw(1).getOrThrow()
        @Expect(refEq(parent.childAt(0), oldParent.childAt(0)), true)
        @Expect(refEq(parent.childAt(2), oldParent.childAt(2)), true)
        @Expect(parent.childAt(1).identity.nodeId, middle)
        @Expect(bridgeValue(current.effects.winner("left").getOrThrow()), "abc")
        @Expect(bridgeValue(current.effects.winner("right").getOrThrow()), "ghi")
        @Expect(bridgeValue(current.effects.winner("middle").getOrThrow()), "DxF")
        @Expect(bridgeValue(old.effects.winner("middle").getOrThrow()), "DEF")
        @Expect(current.patches.size, 1)
        @Expect(current.patches[0].parentId, 1)
        @Expect(current.patches[0].textSplices.size, 1)
        let patch = current.patches[0].textSplices[0]
        @Expect(patch.nodeId, middle); @Expect(patch.startByte, 1); @Expect(patch.endByte, 2); @Expect(patch.inserted, "x")
        @Expect((parent.childAt(1).payload as PersistentTextPayload).getOrThrow().materialize(), "DxF")
        @Expect((oldParent.childAt(1).payload as PersistentTextPayload).getOrThrow().materialize(), "DEF")
        let fresh = Markit(useStandard: false).use(BridgePlugin()).parse("abcDxFghi\n").snapshot
        @Expect(fresh.root.children[0].children[1].literal,
            (parent.childAt(1).payload as PersistentTextPayload).getOrThrow().materialize())
        old.release(); current.release(); session.close()
    }

    @TestCase
    func actualInlineFacetIdentityDriftRejectsPublicationWithoutLosingAcknowledgedSource() {
        let plugin = BridgePlugin()
        let session = Markit(useStandard: false).use(plugin).createEditingSession("bridge-identity", "abcDEFghi\n", bridgeCodec(), policy: EditingPolicy.Strict)
        session.applyEdits(0, [EditingTextEdit(EditingRange(4, 5), "x")])
        plugin.inline.drift = true
        let refused = session.flush()
        @Expect(refused.committed, false)
        @Expect(session.versions.sourceVersion, 1); @Expect(session.versions.parseVersion, 0)
        @Expect(session.source.current.sliceBytes(0, session.source.current.byteLength), "abcDxFghi\n")
        @Expect(plugin.facet.syntaxCalls, 0)
        let unchanged = session.snapshot()
        @Expect(bridgeValue(unchanged.effects.winner("middle").getOrThrow()), "DEF")
        @Expect(unchanged.patches.size, 0)
        plugin.inline.drift = false
        @Expect(session.flush().committed, true)
        @Expect(session.versions.parseVersion, 1)
        unchanged.release(); session.close()
    }
}
