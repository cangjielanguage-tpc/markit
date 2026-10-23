package markit.tests.unit

import std.collection.{ArrayList, HashMap}
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.block.*
import markit.core.document.*
import markit.core.editing.*
import markit.core.incremental.*
import markit.core.nodes.*
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.render.{HtmlRenderer, HtmlWriter, RenderRegistry}
import markit.core.session.*
import markit.core.source.{SourceBuffer, SourceLine, SourceSpan}

// This deliberately tiny grammar exists only in tests. Core scheduling knows
// neither its delimiters nor the concrete node types below.
private class EnginePayload <: IncrementalStatePayload {
    private let value: String
    public init(value!: String = "test-syntax") { this.value = value }
    public func clonePayload(): IncrementalStatePayload { return EnginePayload(value: value) }
    public func fingerprint(): String { return value }
}
private class EngineNode <: Node {
    public let saved: ?ParseSessionCheckpoint
    public let checkpoint: ?IncrementalCheckpoint
    public let exitCheckpoint: ?IncrementalCheckpoint
    public let syntaxDependent: Bool
    public let facetTag: String
    public init(id: Int64, span: SourceSpan, text: String, saved: ?ParseSessionCheckpoint,
        checkpoint: ?IncrementalCheckpoint, exitCheckpoint!: ?IncrementalCheckpoint = None, syntaxDependent!: Bool = false, facetTag!: String = "") {
        super("EngineUnit", id: id, sourceSpan: span, literal: text)
        this.saved = saved; this.checkpoint = checkpoint
        this.exitCheckpoint = exitCheckpoint; this.syntaxDependent = syntaxDependent; this.facetTag = facetTag
    }
}
private class EngineCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "engine-test" } }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func accepts(node: Node): Bool { return (node is DocumentNode) || (node is EngineNode) }
    public func createShallow(node: Node): Node {
        if (let unit: EngineNode <- node) {
            return EngineNode(unit.id, unit.sourceSpan, unit.literal, unit.saved, unit.checkpoint, exitCheckpoint: unit.exitCheckpoint, syntaxDependent: unit.syntaxDependent, facetTag: unit.facetTag)
        }
        return DocumentNode(SourceBuffer())
    }
}
private func engineCodec(): NodeCodec { let codec = NodeCodec(); codec.register(EngineCodec()); return codec }

private class EngineFrame <: BlockState {
    public let start: SourceSpan
    public let saved: ?ParseSessionCheckpoint
    public let checkpoint: ?IncrementalCheckpoint
    public let lines = ArrayList<SourceLine>()
    public var finish: SourceSpan
    public init(start: SourceSpan, saved: ?ParseSessionCheckpoint, checkpoint: ?IncrementalCheckpoint) {
        this.start = start; this.finish = start; this.saved = saved; this.checkpoint = checkpoint
    }
}

private class EngineFacet <: BlockEditingFacet {
    public let tag: String
    public init(tag!: String = "") { this.tag = tag }
    public var stateful: Bool = false
    public var expansions: Int64 = 0
    // Container payloads retain their original recovery checkpoint after a
    // child-only path copy, so this fixture keeps the conservative epoch pin.
    public var rawBirthOnly: Bool = false
    public var syntaxCalls: Int64 = 0
    public var semanticCalls: Int64 = 0
    public var fail: Bool = false
    public var duringParse: ?() -> Unit = None
    public prop owner: String { get() { return "EngineTest" } }
    public prop grammarVersion: String { get() { return "1" } }
    public prop retainsOnlyRawBirthEpochs: Bool { get() { return rawBirthOnly } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion, EnginePayload(value: if (stateful) { "entry" } else { "test-syntax" }), syntaxContext: "unit"))
    }
    public func exitFor(context: IncrementalParserContext, line: String): IncrementalCheckpoint {
        let value = if (!stateful) { "test-syntax" } else if (line.startsWith("state:")) { line[6..] } else { "exit" }
        return IncrementalCheckpoint(context.documentId, owner, context.sourceVersion, EnginePayload(value: value), syntaxContext: "unit")
    }
    public func syntaxReadKeys(node: RawSyntaxNode): ?Array<String> {
        let unit = ((node.payload as TypedSyntaxPayload).getOrThrow().materializeShallow() as EngineNode).getOrThrow()
        return Some(if (unit.syntaxDependent) { ["key"] } else { Array<String>() })
    }
    public func restore(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return saved.documentId == context.documentId && saved.owner == owner && context.writeState(owner, saved.payload.clonePayload())
    }
    public func rollbackEffects(context: IncrementalParserContext, _: IncrementalCheckpoint): Bool {
        return context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(previous: IncrementalCheckpoint, current: IncrementalCheckpoint): Bool {
        return previous.syntaxContext == current.syntaxContext && previous.payload.fingerprint() == current.payload.fingerprint()
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func owns(node: RawSyntaxNode): Bool {
        if (let typed: TypedSyntaxPayload <- node.payload) {
            if (let unit: EngineNode <- typed.materializeShallow()) { return unit.facetTag == tag }
        }
        return false
    }
    public func recover(context: BlockEditingContext, node: RawSyntaxNode, _: Int64, _: Int64): ?BlockRecoveryUnit {
        let typed = (node.payload as TypedSyntaxPayload).getOrThrow()
        let unit = (typed.materializeShallow() as EngineNode).getOrThrow()
        if (unit.saved.isNone() || unit.checkpoint.isNone()) { return None }
        let emptyKernel = BlockParsingKernel(context.session, ContinuationBlockDispatchTable(), BlockDispatchTable(), ArrayList<ParagraphBlockParser>())
        return Some(BlockRecoveryUnit(owner, node.identity.nodeId, node.startAnchor, node.endAnchor,
            unit.saved.getOrThrow(), emptyKernel.checkpoint(), unit.checkpoint.getOrThrow(),
            expectedExit: unit.exitCheckpoint, expectedKernel: Some(emptyKernel.checkpoint())))
    }
    public func recoverGap(context: BlockEditingContext, _: Int64, _: Int64): ?BlockRecoveryUnit {
        let root = (context.previous.getOrThrow().root as RawSyntaxNode).getOrThrow()
        if (root.childCount != 0) { return None }
        let emptyKernel = BlockParsingKernel(context.session, ContinuationBlockDispatchTable(), BlockDispatchTable(), ArrayList<ParagraphBlockParser>())
        let current = checkpoint(context).getOrThrow()
        let entry = IncrementalCheckpoint(context.documentId, owner, context.baseSourceVersion, current.payload, syntaxContext: current.syntaxContext)
        return Some(BlockRecoveryUnit(owner, root.identity.nodeId, root.startAnchor, root.endAnchor,
            context.recoveryCheckpoint.getOrThrow(), emptyKernel.checkpoint(), entry,
            expectedExit: Some(entry), expectedKernel: Some(emptyKernel.checkpoint()), provider: Some(this)))
    }
    public func expandRecovery(context: BlockEditingContext, unit: BlockRecoveryUnit, _: String): ?BlockRecoveryUnit {
        expansions += 1
        if (let Some(parent) <- context.previous.getOrThrow().parentOf(unit.nodeId)) {
            if (owns(parent.syntax)) { return recover(context, parent.syntax, 0, 0) }
        }
        return None
    }
    public func parseUnit(context: BlockEditingContext, unit: BlockRecoveryUnit, kernel: BlockParsingKernel): BlockUnitParseResult {
        syntaxCalls += 1
        if (let Some(callback) <- duringParse) { callback() }
        if (fail) { throw IllegalArgumentException("injected parse failure") }
        let start = context.previous.getOrThrow().resolve(unit.start).getOrThrow()
        let end = context.previous.getOrThrow().resolve(unit.end).getOrThrow()
        let parsed = ArrayList<Node>()
        kernel.setEmissionSink({ node: Node => parsed.add(node) })
        for (line in context.lines(start, end)) { kernel.feed(line) }
        kernel.finish()
        let previousRoot = (context.previous.getOrThrow().root as RawSyntaxNode).getOrThrow()
        if (unit.nodeId == previousRoot.identity.nodeId && previousRoot.childCount == 0) {
            let root = DocumentNode(context.session.source)
            let a = context.source.coordinateAtByte(start).getOrThrow(); let b = context.source.coordinateAtByte(end).getOrThrow()
            root.sourceSpan = SourceSpan(start, end, a.runeOffset, b.runeOffset)
            for (node in parsed) { root.addChild(node) }
            return BlockUnitParseResult(root, exitFor(context, ""))
        }
        let exit = if (parsed.size == 1) { (parsed[0] as EngineNode).getOrThrow().exitCheckpoint.getOrThrow() } else { exitFor(context, "") }
        if (parsed.size == 1) { return BlockUnitParseResult(parsed[0], exit) }
        let tree = context.previous.getOrThrow()
        let parent = tree.parentOf(unit.nodeId).getOrThrow().syntax
        return BlockUnitParseResult(tree.materializeLegacy(nodeId: Some(unit.nodeId)), exit,
            splice: Some(BlockChildrenEdit(parent.identity.nodeId, parent.childPosition(unit.nodeId), 1, parsed.toArray())))
    }
    public func replaySemantic(context: BlockEditingContext, node: RawSyntaxNode): Unit {
        semanticCalls += 1
        let unit = ((node.payload as TypedSyntaxPayload).getOrThrow().materializeShallow() as EngineNode).getOrThrow()
        semantic(context, node.identity.nodeId, unit.literal, node.startAnchor.byteOffset)
    }
    public func semantic(context: BlockEditingContext, id: Int64, line: String, order: Int64): Unit {
        if (line.startsWith("=")) {
            context.effects.add(OwnedSemanticEffect(id, "key", StringEffectPayload(line[1..]), order))
        } else if (line.startsWith("?")) {
            let read = context.effects.read("key", id)
            let value = if (let Some(effect) <- read) { (effect.payload as StringEffectPayload).getOrThrow().value } else { "missing" }
            context.effects.add(OwnedSemanticEffect(id, "seen:${id}", StringEffectPayload(value), order))
        }
    }
}

private class EngineLeaf <: LeafBlockParser {
    private let facet: EngineFacet
    public init(facet: EngineFacet) { this.facet = facet }
    public prop name: String { get() { return "test-body" } }
    public prop ownerPlugin: String { get() { return facet.owner } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [] } }
    public prop acceptsAnyNonBlank: Bool { get() { return true } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public func tryParse(session: ParseSession, line: String): ?Node {
        var saved: ?ParseSessionCheckpoint = None
        var checkpoint: ?IncrementalCheckpoint = None
        if (let Some(context) <- session.editingContext) { saved = Some(session.checkpoint()); checkpoint = facet.checkpoint(context) }
        var exit: ?IncrementalCheckpoint = None
        if (let Some(context) <- session.editingContext) { exit = Some(facet.exitFor(context, line)) }
        let node = EngineNode(session.allocateNodeId(), session.currentLineSpan(), line, saved, checkpoint,
            exitCheckpoint: exit, syntaxDependent: line.startsWith("!"), facetTag: facet.tag)
        session.attachNode(node)
        if (let Some(value) <- session.editingContext) {
            let context = (value as BlockEditingContext).getOrThrow()
            if (context.readState("candidate-leak").isSome()) { throw IllegalArgumentException("candidate state leaked") }
            if (line.startsWith("!")) {
                let effect = context.effects.read("key", node.id)
                let selected = if (let Some(found) <- effect) { (found.payload as StringEffectPayload).getOrThrow().value } else { "missing" }
                node.literal = "chosen:" + selected
            }
            facet.semantic(context, node.id, line, node.sourceSpan.startByte)
        }
        return Some(node)
    }
}

private class EngineContainer <: ContinuationBlockParser {
    private let facet: EngineFacet
    public init(facet: EngineFacet) { this.facet = facet }
    public prop name: String { get() { return "test-container" } }
    public prop ownerPlugin: String { get() { return facet.owner } }
    public prop priority: Int64 { get() { return 0 } }
    public prop startBytes: Array<Byte> { get() { return [b'['] } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (line != "[") { return None }
        var saved: ?ParseSessionCheckpoint = None
        var checkpoint: ?IncrementalCheckpoint = None
        if (let Some(context) <- session.editingContext) { saved = Some(session.checkpoint()); checkpoint = facet.checkpoint(context) }
        return Some(BlockFrame(EngineFrame(session.currentLineSpan(), saved, checkpoint)))
    }
    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as EngineFrame).getOrThrow(); state.finish = session.currentLineSpan()
        if (line == "]") { return Closed }
        state.lines.add(session.currentSourceLine()); return Open
    }
    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as EngineFrame).getOrThrow()
        var exit: ?IncrementalCheckpoint = None
        if (let Some(context) <- session.editingContext) { exit = Some(facet.exitFor(context, "container")) }
        let node = EngineNode(session.allocateNodeId(), state.start.merge(state.finish), "container", state.saved, state.checkpoint, exitCheckpoint: exit, facetTag: facet.tag)
        for (child in session.parseDetachedLines(state.lines)) { node.addChild(child) }
        return session.attachNode(node)
    }
}
private class EnginePlugin <: Plugin {
    public let facet = EngineFacet()
    public prop name: String { get() { return facet.owner } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(EngineLeaf(facet)); registrar.registerContinuationBlockParser(EngineContainer(facet))
    }
}

private func engineEdit(start: Int64, end: Int64, text: String): Array<EditingTextEdit> {
    return [EditingTextEdit(EditingRange(start, end), text)]
}

private class LegacyEngineNode <: Node {
    public let extra: String
    public let linked: ?Node
    public init(id: Int64, span: SourceSpan, text: String, linked: ?Node) {
        super("LegacyEngine", id: id, sourceSpan: span, literal: text)
        this.extra = "typed:" + text; this.linked = linked
    }
}
private class LegacyEngineLeaf <: LeafBlockParser {
    public prop name: String { get() { return "legacy-custom" } }
    public prop ownerPlugin: String { get() { return "LegacyEngine" } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [] } }
    public prop acceptsAnyNonBlank: Bool { get() { return true } }
    public func tryParse(session: ParseSession, line: String): ?Node {
        let linked: ?Node = if (session.root.children.isEmpty()) { None } else { Some(session.root.children[0]) }
        return Some(session.attachNode(LegacyEngineNode(session.allocateNodeId(), session.currentLineSpan(), line, linked)))
    }
}
private class LegacyEngineRenderer <: HtmlRenderer {
    public prop ownerPlugin: String { get() { return "LegacyEngine" } }
    public func writeHtml(node: Node, out: HtmlWriter, _: RenderRegistry): Unit {
        out.text((node as LegacyEngineNode).getOrThrow().extra)
    }
}
private class LegacyEnginePlugin <: Plugin {
    public prop name: String { get() { return "LegacyEngine" } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(LegacyEngineLeaf())
        registrar.registerHtmlRenderer("LegacyEngine", LegacyEngineRenderer())
    }
}

private class ReprocessState <: BlockState {}
private class ReprocessStart <: ContinuationBlockParser {
    public prop name: String { get() { return "reprocess" } }
    public prop ownerPlugin: String { get() { return "Reprocess" } }
    public prop priority: Int64 { get() { return 0 } }
    public prop startBytes: Array<Byte> { get() { return [b'@'] } }
    public func tryStart(_: ParseSession, line: String): ?BlockFrame {
        return if (line == "@") { Some(BlockFrame(ReprocessState())) } else { None }
    }
    public func continueBlock(_: ParseSession, _: BlockFrame, _: String): ContinueResult { return ClosedAndReprocess }
    public func finalize(session: ParseSession, _: BlockFrame): Node { return session.createNode("first") }
}
private class ReprocessLeaf <: LeafBlockParser {
    public prop name: String { get() { return "after-reprocess" } }
    public prop ownerPlugin: String { get() { return "Reprocess" } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [] } }
    public prop acceptsAnyNonBlank: Bool { get() { return true } }
    public func tryParse(session: ParseSession, _: String): ?Node {
        return Some(session.createNode("after", literal: "seen:${session.root.children.size}"))
    }
}
private class ReprocessPlugin <: Plugin {
    public prop name: String { get() { return "Reprocess" } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(ReprocessStart()); registrar.registerLeafBlockParser(ReprocessLeaf())
    }
}

private class RejectingEngineLeaf <: LeafBlockParser {
    private let facet: EngineFacet
    public init(facet: EngineFacet) { this.facet = facet }
    public prop name: String { get() { return "rejected-candidate" } }
    public prop ownerPlugin: String { get() { return facet.owner } }
    public prop priority: Int64 { get() { return 0 } }
    public prop startBytes: Array<Byte> { get() { return [] } }
    public prop acceptsAnyNonBlank: Bool { get() { return true } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public func tryParse(session: ParseSession, _: String): ?Node {
        let node = session.createNode("rejected")
        session.root.addChild(node); session.patches.replace(node); session.addPendingParagraphLine(session.currentSourceLine())
        let context = (session.editingContext.getOrThrow() as BlockEditingContext).getOrThrow()
        context.writeState("candidate-leak", EnginePayload())
        context.effects.add(OwnedSemanticEffect(node.id, "candidate-leak", StringEffectPayload("bad"), 0))
        return None
    }
}
private class RejectingEnginePlugin <: Plugin {
    public let facet = EngineFacet()
    public prop name: String { get() { return facet.owner } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(RejectingEngineLeaf(facet)); registrar.registerLeafBlockParser(EngineLeaf(facet))
    }
}

private class BodyOnlyEngineLeaf <: LeafBlockParser {
    private let facet: EngineFacet
    private let delegate: EngineLeaf
    public init(facet: EngineFacet) { this.facet = facet; this.delegate = EngineLeaf(facet) }
    public prop name: String { get() { return "body-only" } }
    public prop ownerPlugin: String { get() { return facet.owner } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [b'b'] } }
    public prop acceptsAnyNonBlank: Bool { get() { return false } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public func tryParse(session: ParseSession, line: String): ?Node { return delegate.tryParse(session, line) }
}
private class RejectingEngineParagraph <: ParagraphBlockParser {
    private let facet: EngineFacet
    public init(facet: EngineFacet) { this.facet = facet }
    public prop name: String { get() { return "rejected-paragraph" } }
    public prop ownerPlugin: String { get() { return facet.owner } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public func canStart(session: ParseSession, _: String): Bool {
        let node = session.createNode("rejected-paragraph")
        session.root.addChild(node); session.patches.replace(node); session.addPendingParagraphLine(session.currentSourceLine())
        let context = (session.editingContext.getOrThrow() as BlockEditingContext).getOrThrow()
        context.writeState("candidate-leak", EnginePayload())
        context.effects.add(OwnedSemanticEffect(node.id, "candidate-leak", StringEffectPayload("bad"), 0))
        return false
    }
    public func normalizeLine(_: ParseSession, line: String): String { return line }
    public func finalize(_: ParseSession, _: ArrayList<SourceLine>, _: SourceSpan, _: ParagraphTermination): Node {
        throw IllegalArgumentException("Rejected paragraph left pending lines")
    }
}
private class RejectingParagraphPlugin <: Plugin {
    private let facet = EngineFacet()
    public prop name: String { get() { return facet.owner } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(BodyOnlyEngineLeaf(facet)); registrar.registerParagraphBlockParser(RejectingEngineParagraph(facet))
    }
}

private class TaggedEngineLeaf <: LeafBlockParser {
    private let facet: EngineFacet
    private let head: Byte
    private let delegate: EngineLeaf
    public init(facet: EngineFacet, head: Byte) { this.facet = facet; this.head = head; this.delegate = EngineLeaf(facet) }
    public prop name: String { get() { return "tagged:" + facet.tag } }
    public prop ownerPlugin: String { get() { return facet.owner } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [head] } }
    public prop acceptsAnyNonBlank: Bool { get() { return false } }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public func tryParse(session: ParseSession, line: String): ?Node { return delegate.tryParse(session, line) }
}
private class MultipleFacetEnginePlugin <: Plugin {
    public let first = EngineFacet(tag: "first")
    public let second = EngineFacet(tag: "second")
    public prop name: String { get() { return "EngineTest" } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(TaggedEngineLeaf(first, b'a'))
        registrar.registerLeafBlockParser(TaggedEngineLeaf(second, b'b'))
    }
}

@Test @Tag[BlockEditing]
class Task05EngineTests {
    @TestCase
    func nestedReplacementSharesOtherRawUnits(): Unit {
        let plugin = EnginePlugin(); let markit = Markit(plugin)
        let editing = markit.createEditingSession("nested", "left\n[\none\ntwo\n]\nright", engineCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let root = (before.tree.root as RawSyntaxNode).getOrThrow()
        let container = root.childAt(1); let unchanged = container.childAt(1)
        editing.applyEdits(0, engineEdit(7, 10, "ONE"))
        let update = editing.flush(); @Expect(update.committed, true); @Expect(update.syntaxUnitsParsed, 1)
        let after = editing.snapshot(); let next = (after.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(refEq(root.childAt(0), next.childAt(0)), true)
        @Expect(refEq(root.childAt(2), next.childAt(2)), true)
        @Expect(refEq(unchanged, next.childAt(1).childAt(1)), true)
        @Expect(container.childAt(0).identity.nodeId != next.childAt(1).childAt(0).identity.nodeId, true)
        @Expect(before.tree.materializeLegacy().rawContent(), "left\n[\none\ntwo\n]\nright")
        @Expect(after.tree.materializeLegacy().rawContent(), "left\n[\nONE\ntwo\n]\nright")
        let fresh = Markit(EnginePlugin()).createEditingSession("fresh-nested", "left\n[\nONE\ntwo\n]\nright", engineCodec(), policy: EditingPolicy.Strict)
        let oracle = fresh.snapshot()
        @Expect(after.tree.materializeLegacy().toString(), oracle.tree.materializeLegacy().toString())
        @Expect(after.tree.materializeLegacy().toJson(), oracle.tree.materializeLegacy().toJson())
        @Expect(after.tree.materializeLegacy().sourceSpan.endByte, oracle.tree.materializeLegacy().sourceSpan.endByte)
        oracle.release(); fresh.close()
        before.release(); after.release(); editing.close()
    }

    @TestCase
    func semanticReadersReplayWithoutParsingPlainBodies(): Unit {
        let plugin = EnginePlugin(); let editing = Markit(plugin).createEditingSession("semantic", "=old\nplain\n?key", engineCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let reader = (before.tree.root as RawSyntaxNode).getOrThrow().childAt(2).identity.nodeId
        editing.applyEdits(0, engineEdit(1, 4, "new"))
        let update = editing.flush(); @Expect(update.committed, true)
        @Expect(update.syntaxUnitsParsed, 1); @Expect(update.semanticOwnersReplayed, 1)
        let after = editing.snapshot()
        @Expect((after.effects.winner("seen:${reader}").getOrThrow().payload as StringEffectPayload).getOrThrow().value, "new")
        before.release(); after.release(); editing.close()
    }

    @TestCase
    func cancelledV2CannotPublishOverAcknowledgedV3(): Unit {
        let plugin = EnginePlugin(); let editing = Markit(plugin).createEditingSession("versions", "one\ntwo", engineCodec(), policy: EditingPolicy.Strict)
        editing.applyEdits(0, engineEdit(0, 3, "ONE"))
        plugin.facet.duringParse = Some({ => editing.applyEdits(1, engineEdit(4, 7, "TWO")); editing.cancelComputation() })
        let cancelled = editing.flush(); @Expect(cancelled.committed, false)
        @Expect(editing.versions.sourceVersion, 2); @Expect(editing.versions.parseVersion, 0)
        @Expect(editing.source.current.sliceBytes(0, 7), "ONE\nTWO")
        plugin.facet.duringParse = None
        let committed = editing.flush(); @Expect(committed.committed, true); @Expect(editing.versions.parseVersion, 2)
        let after = editing.snapshot(); @Expect(after.tree.materializeLegacy().rawContent(), "ONE\nTWO")
        after.release(); editing.close()
    }

    @TestCase
    func parseFailureLeavesPublishedTreeAndCanRetry(): Unit {
        let plugin = EnginePlugin(); let editing = Markit(plugin).createEditingSession("failure", "one\ntwo", engineCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot()
        editing.applyEdits(0, engineEdit(0, 3, "ONE")); plugin.facet.fail = true
        @Expect(editing.flush().committed, false)
        let failed = editing.snapshot(); @Expect(refEq(before.tree, failed.tree), true)
        plugin.facet.fail = false; @Expect(editing.flush().committed, true)
        before.release(); failed.release(); editing.close()
    }

    @TestCase
    func nestedSiblingInsertionAndDeletionUseSplice(): Unit {
        let editing = Markit(EnginePlugin()).createEditingSession("splice", "left\n[\none\ntwo\n]\nright", engineCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let oldRoot = (before.tree.root as RawSyntaxNode).getOrThrow()
        let unchanged = oldRoot.childAt(1).childAt(1)
        editing.applyEdits(0, engineEdit(7, 10, "ONE\nnew"))
        @Expect(editing.flush().committed, true)
        let inserted = editing.snapshot(); let root = (inserted.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(root.childAt(1).childCount, 3)
        @Expect(refEq(unchanged, root.childAt(1).childAt(2)), true)
        @Expect(refEq(oldRoot.childAt(2), root.childAt(2)), true)
        editing.applyEdits(1, engineEdit(11, 14, ""))
        @Expect(editing.flush().committed, true)
        let deleted = editing.snapshot(); let next = (deleted.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(next.childAt(1).childCount, 2)
        @Expect(refEq(unchanged, next.childAt(1).childAt(1)), true)
        let fresh = Markit(EnginePlugin()).createEditingSession("fresh-splice", "left\n[\nONE\n\ntwo\n]\nright", engineCodec(), policy: EditingPolicy.Strict)
        let oracle = fresh.snapshot()
        @Expect(deleted.tree.materializeLegacy().toString(), oracle.tree.materializeLegacy().toString())
        @Expect(deleted.tree.materializeLegacy().toJson(), oracle.tree.materializeLegacy().toJson())
        @Expect(deleted.tree.materializeLegacy().rawContent(), oracle.tree.materializeLegacy().rawContent())
        before.release(); inserted.release(); deleted.release(); oracle.release(); editing.close(); fresh.close()
    }

    @TestCase
    func batchedAncestorAndChildRecoveryMatchesFresh(): Unit {
        let editing = Markit(EnginePlugin()).createEditingSession("batch", "left\n[\none\ntwo\n]\nright", engineCodec(), policy: EditingPolicy.Strict)
        editing.applyEdits(0, [EditingTextEdit(EditingRange(7, 10), "ONE"), EditingTextEdit(EditingRange(15, 16), "]")])
        let result = editing.flush(); @Expect(result.committed, true); @Expect(result.syntaxUnitsParsed, 1)
        let actual = editing.snapshot()
        let fresh = Markit(EnginePlugin()).createEditingSession("fresh-batch", "left\n[\nONE\ntwo\n]\nright", engineCodec(), policy: EditingPolicy.Strict)
        let oracle = fresh.snapshot()
        @Expect(actual.tree.materializeLegacy().toString(), oracle.tree.materializeLegacy().toString())
        actual.release(); oracle.release(); editing.close(); fresh.close()
    }

    @TestCase
    func unknownExternalTypedGraphUsesCompleteSessionFallback(): Unit {
        let markit = Markit(LegacyEnginePlugin())
        let editing = markit.createEditingSession("external", "一\r\n二", NodeCodec())
        let before = editing.snapshot(); @Expect(before.fallbackScope, EditingFallbackScope.Session)
        let old = before.legacySnapshot.getOrThrow().root
        let oldSecond = (old.children[1] as LegacyEngineNode).getOrThrow()
        @Expect(oldSecond.extra, "typed:二"); @Expect(refEq(oldSecond.linked.getOrThrow(), old.children[0]), true)
        editing.applyEdits(0, engineEdit(5, 8, "贰\r\n三")); @Expect(editing.flush().committed, true)
        let after = editing.snapshot(); let current = after.legacySnapshot.getOrThrow().root
        let third = (current.children[2] as LegacyEngineNode).getOrThrow()
        @Expect(third.extra, "typed:三"); @Expect(refEq(third.linked.getOrThrow(), current.children[0]), true)
        @Expect(refEq(old.children[0], current.children[0]), false)
        @Expect(oldSecond.extra, "typed:二")
        let fresh = Markit(LegacyEnginePlugin()).parse("一\r\n贰\r\n三")
        @Expect(current.toHtml(), fresh.snapshot.root.toHtml())
        @Expect(current.toString(), fresh.snapshot.root.toString())
        @Expect(after.legacySnapshot.getOrThrow().lineIndex.size, fresh.snapshot.lineIndex.size)
        @Expect(after.legacySnapshot.getOrThrow().lineAt(1).text, fresh.snapshot.lineAt(1).text)
        @Expect(after.legacySnapshot.getOrThrow().lineAt(1).span.startByte, fresh.snapshot.lineAt(1).span.startByte)
        @Expect(after.legacySnapshot.getOrThrow().lineAt(1).span.startRune, fresh.snapshot.lineAt(1).span.startRune)
        before.release(); after.release(); editing.close()
    }

    @TestCase
    func legacyClosedAndReprocessPublishesBeforeNextParser(): Unit {
        let parsed = Markit(ReprocessPlugin()).parse("@\nbody\n")
        @Expect(parsed.snapshot.root.children.size, 2)
        @Expect(parsed.snapshot.root.children[1].literal, "seen:1")
    }

    @TestCase
    func rejectedCandidateDoesNotLeakIdsPendingEffectsOrPatches(): Unit {
        let editing = Markit(RejectingEnginePlugin()).createEditingSession("candidate", "one", engineCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let first = (before.tree.root as RawSyntaxNode).getOrThrow().childAt(0)
        @Expect(first.identity.nodeId, 1); @Expect(before.effects.winner("candidate-leak").isNone(), true)
        editing.applyEdits(0, engineEdit(0, 3, "two")); @Expect(editing.flush().committed, true)
        let after = editing.snapshot(); let root = (after.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(root.childCount, 1); @Expect(root.childAt(0).identity.nodeId, 2)
        @Expect(after.effects.winner("candidate-leak").isNone(), true); @Expect(after.patches.size, 1)
        before.release(); after.release(); editing.close()
    }

    @TestCase
    func opaqueCheckpointEpochRemainsPinnedUntilSessionClose(): Unit {
        let plugin = EnginePlugin(); plugin.facet.rawBirthOnly = false
        let editing = Markit(plugin).createEditingSession("opaque-epoch", "one", engineCodec(), policy: EditingPolicy.Strict)
        let oldAnchor = SourceAnchor(editing.source.current.identity, 1)
        editing.applyEdits(0, engineEdit(0, 3, "ONE")); @Expect(editing.flush().committed, true)
        let current = editing.snapshot(); @Expect(current.tree.earliestAnchorVersion, 1)
        @Expect(editing.source.oldestAvailableVersion, 0)
        @Expect(editing.source.resolve(oldAnchor, 1).isSome(), true)
        current.release(); editing.close()
        @Expect(editing.source.oldestAvailableVersion, 1)
        @Expect(editing.source.resolve(oldAnchor, 1).isNone(), true)
    }

    @TestCase
    func actualGrammarReaderReparsesButUnrelatedBodyDoesNot(): Unit {
        let editing = Markit(EnginePlugin()).createEditingSession("grammar-read", "=old\nplain\n!key", engineCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let plain = (before.tree.root as RawSyntaxNode).getOrThrow().childAt(1)
        editing.applyEdits(0, engineEdit(1, 4, "new"))
        let result = editing.flush(); @Expect(result.committed, true); @Expect(result.syntaxUnitsParsed >= 2, true)
        let after = editing.snapshot(); let root = (after.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(refEq(plain, root.childAt(1)), true)
        @Expect((after.tree.materializeLegacy().children[2] as EngineNode).getOrThrow().literal, "chosen:new")
        before.release(); after.release(); editing.close()
    }

    @TestCase
    func distinctEntryAndExitStateConvergesAndChangedExitExpands(): Unit {
        let plugin = EnginePlugin(); plugin.facet.stateful = true
        let editing = Markit(plugin).createEditingSession("state-exit", "left\n[\nstate:exit\nother\n]\nright", engineCodec(), policy: EditingPolicy.Strict)
        editing.applyEdits(0, engineEdit(7, 17, "state:exit")); @Expect(editing.flush().committed, true)
        @Expect(plugin.facet.expansions, 0)
        editing.applyEdits(1, engineEdit(7, 17, "state:changed"))
        let expanded = editing.flush(); @Expect(expanded.committed, true); @Expect(plugin.facet.expansions, 1)
        @Expect(expanded.syntaxUnitsParsed, 2)
        let actual = editing.snapshot()
        let freshPlugin = EnginePlugin(); freshPlugin.facet.stateful = true
        let fresh = Markit(freshPlugin).createEditingSession("fresh-state-exit", "left\n[\nstate:changed\nother\n]\nright", engineCodec(), policy: EditingPolicy.Strict)
        let oracle = fresh.snapshot(); @Expect(actual.tree.materializeLegacy().toString(), oracle.tree.materializeLegacy().toString())
        actual.release(); oracle.release(); editing.close(); fresh.close()
    }

    @TestCase
    func falseParagraphCandidateHasTheSameRollbackGuarantee(): Unit {
        let editing = Markit(RejectingParagraphPlugin()).createEditingSession("paragraph-probe", "skip\nbody", engineCodec(), policy: EditingPolicy.Strict)
        let snapshot = editing.snapshot(); let root = (snapshot.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(root.childCount, 1); @Expect(root.childAt(0).identity.nodeId, 1)
        @Expect(snapshot.effects.winner("candidate-leak").isNone(), true)
        snapshot.release(); editing.close()
    }

    @TestCase
    func separateFacetsWithOnePluginOwnerKeepTheirExecutionIdentity(): Unit {
        let plugin = MultipleFacetEnginePlugin()
        let editing = Markit(plugin).createEditingSession("multiple-facets", "aaa\nbbb", engineCodec(), policy: EditingPolicy.Strict)
        editing.applyEdits(0, engineEdit(4, 7, "bBB")); @Expect(editing.flush().committed, true)
        @Expect(plugin.first.syntaxCalls, 0); @Expect(plugin.second.syntaxCalls, 1)
        let snapshot = editing.snapshot()
        @Expect((snapshot.tree.materializeLegacy().children[1] as EngineNode).getOrThrow().facetTag, "second")
        snapshot.release(); editing.close()
    }

    @TestCase
    func snapshotReleaseCanRetryAfterLeaseHookFailure(): Unit {
        let fail = [true]
        let retention = SourceVersionRetention("retry-release", onRelease: { _: SourceVersionIdentity =>
            if (fail[0]) { throw IllegalArgumentException("injected lease release failure") }
        })
        let raw = PersistentNodeCapture(engineCodec()).capture(DocumentNode(SourceBuffer()), SourceVersionIdentity("retry-release", 0))
        let snapshot = EditingDocumentSnapshot(PersistentDocumentVersion(raw), OwnedEffectStore().snapshot(), [], retention.retain(0))
        var rejected = false
        try { snapshot.release() } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true); @Expect(retention.retainCount(0), 1)
        fail[0] = false
        snapshot.release(); snapshot.release()
        @Expect(retention.retainCount(0), 0)
    }

    @TestCase
    func emptyDocumentFirstEditUsesProviderGapRecovery(): Unit {
        let editing = Markit(EnginePlugin()).createEditingSession("empty-document", "", engineCodec(), policy: EditingPolicy.Strict)
        editing.applyEdits(0, engineEdit(0, 0, "first"))
        let result = editing.flush(); @Expect(result.committed, true); @Expect(result.syntaxUnitsParsed, 1)
        let snapshot = editing.snapshot(); let root = (snapshot.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(root.childCount, 1); @Expect(root.childAt(0).identity.nodeId, 1)
        @Expect(snapshot.tree.materializeLegacy().rawContent(), "first")
        snapshot.release(); editing.close()
    }
}
