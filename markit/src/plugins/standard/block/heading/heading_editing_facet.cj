package markit.plugins.standard.block.heading

import std.collection.ArrayList
import markit.core.block.*
import markit.core.editing.*
import markit.core.nodes.{Node, RawSyntaxNode, TypedSyntaxPayload}
import markit.core.session.ParseSession
import markit.plugins.standard.editing.recoverStandardMappedAncestor

public class HeadingSyntaxState <: IncrementalStatePayload {
    public func clonePayload(): IncrementalStatePayload { return HeadingSyntaxState() }
    public func fingerprint(): String { return "standard.atx-heading.v1" }
}

public class HeadingContribution <: OwnedEffectPayload {
    public HeadingContribution(public let ownerId: Int64, public let order: Int64,
        public let text: String, public let level: Int64, public let closable: Bool,
        public let anchor!: ?SourceAnchor = None) {
        if (ownerId < 0 || order < 0 || level < 1 || level > 6) {
            throw IllegalArgumentException("Invalid heading contribution")
        }
    }
    public func cloneEffectPayload(): OwnedEffectPayload {
        return HeadingContribution(ownerId, order, text, level, closable, anchor: anchor)
    }
}

public func headingContributionKey(id: Int64): String { return "standard.heading.syntax:${id}" }

public class HeadingEditingFacet <: BlockEditingFacet {
    public prop owner: String { get() { return "HeadingPlugin" } }
    public prop grammarVersion: String { get() { return "atx-v1" } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion,
            HeadingSyntaxState(), syntaxContext: grammarVersion))
    }
    public func restore(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return saved.documentId == context.documentId && saved.owner == owner &&
            saved.syntaxContext == grammarVersion && saved.payload is HeadingSyntaxState &&
            context.writeState(owner, saved.payload)
    }
    public func rollbackEffects(context: IncrementalParserContext, _: IncrementalCheckpoint): Bool {
        return context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(previous: IncrementalCheckpoint, current: IncrementalCheckpoint): Bool {
        return previous.owner == owner && current.owner == owner &&
            previous.syntaxContext == current.syntaxContext && previous.payload.fingerprint() == current.payload.fingerprint()
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func syntaxReadKeys(_: RawSyntaxNode): ?Array<String> { return Some([]) }
    public func restoreSession(context: BlockEditingContext, unit: BlockRecoveryUnit): Bool {
        return restoreHeadingAwareSession(context, unit)
    }
    public func owns(node: RawSyntaxNode): Bool {
        if (let typed: TypedSyntaxPayload <- node.payload) { return typed.materializeShallow() is HeadingNode }
        return false
    }
    public func recover(context: BlockEditingContext, node: RawSyntaxNode, editStart: Int64, editEnd: Int64): ?BlockRecoveryUnit {
        if (let Some(mapped) <- recoverStandardMappedAncestor(context, node, editStart, editEnd)) { return Some(mapped) }
        let heading = ((node.payload as TypedSyntaxPayload).getOrThrow().materializeShallow() as EditingHeadingNode).getOrThrow()
        let saved = heading.blockRecovery.getOrThrow()
        let currentStart = context.resolve(node.startAnchor).getOrThrow()
        let coordinate = context.source.coordinateAtByte(currentStart).getOrThrow()
        let line = context.source.lineAt(coordinate.line).getOrThrow()
        // Legacy Heading spans omit indentation; grammar recovery owns the
        // complete physical line, including its up-to-three-space prefix.
        let start = SourceAnchor(context.source.identity, line.startByte, affinity: AnchorAffinity.Before)
        return Some(BlockRecoveryUnit(owner, node.identity.nodeId, start, node.endAnchor,
            saved.session, saved.kernel, saved.syntax, expectedExit: Some(saved.expectedExit), expectedKernel: Some(saved.expectedKernel)))
    }
    public func parseUnit(context: BlockEditingContext, unit: BlockRecoveryUnit, kernel: BlockParsingKernel): BlockUnitParseResult {
        let start = context.resolve(unit.start).getOrThrow(); let end = context.resolve(unit.end).getOrThrow()
        let state = context.session.symbolTables.get(HeadingPlugin.stateKey)
        let oldRaw = context.previous.getOrThrow().raw(unit.nodeId).getOrThrow()
        let old = ((oldRaw.payload as TypedSyntaxPayload).getOrThrow().materializeShallow() as HeadingNode).getOrThrow()
        state.beginOrderedChange(HeadingContribution(old.id, start, old.content, old.level,
            old.bool("closable") ?? false, anchor: Some(oldRaw.startAnchor)))
        let parsed = ArrayList<Node>()
        kernel.setEmissionSink({ node: Node => parsed.add(node) })
        for (line in context.lines(start, end)) { kernel.feed(line) }
        kernel.finish()
        let finalState = context.session.symbolTables.get(HeadingPlugin.stateKey)
        finalState.finishOrderedChange({ anchor: SourceAnchor => context.resolve(anchor) })
        finalState.publishOrderedIndex(context)
        let updates = takeHeadingPayloadUpdates(context, excludedId: unit.nodeId)
        let exit = checkpoint(context).getOrThrow()
        let tree = context.previous.getOrThrow()
        let parent = tree.parentOf(unit.nodeId).getOrThrow().syntax
        return BlockUnitParseResult(Node("heading-splice-placeholder"), exit, payloadUpdates: updates,
            splice: Some(BlockChildrenEdit(parent.identity.nodeId, parent.childPosition(unit.nodeId), 1, parsed.toArray())))
    }
    public func replaySemantic(context: BlockEditingContext, node: RawSyntaxNode): Unit {
        let heading = ((node.payload as TypedSyntaxPayload).getOrThrow().materializeShallow() as HeadingNode).getOrThrow()
        let order = context.resolve(node.startAnchor).getOrThrow()
        contribute(context, heading, order)
    }
    public func contribute(context: BlockEditingContext, heading: HeadingNode, order: Int64): Unit {
        let value = HeadingContribution(heading.id, order, heading.content, heading.level, heading.bool("closable") ?? false,
            anchor: Some(SourceAnchor(context.source.identity, order)))
        let state = context.session.symbolTables.get(HeadingPlugin.stateKey)
        if (state.contributionsDeferred) { return }
        let projection = state.acceptContribution(value, { anchor: SourceAnchor => context.resolve(anchor) },
            collect: context.previous.isSome())
        projection.applyTo(heading, includeNumberInHtml: state.includeNumberInHtml())
        state.publishOrderedIndex(context)
        context.effects.add(OwnedSemanticEffect(heading.id, headingContributionKey(heading.id),
            value, order))
    }
}

public func closedHeadingKernel(session: ParseSession): BlockParsingKernel {
    return BlockParsingKernel(session, ContinuationBlockDispatchTable(), BlockDispatchTable(), ArrayList<ParagraphBlockParser>())
}
