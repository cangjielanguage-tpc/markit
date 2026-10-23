package markit.plugins.standard.block.heading

import std.collection.ArrayList
import markit.core.block.{BlockEditingContext, BlockRecoveryUnit, BlockPayloadUpdate}
import markit.core.editing.SourceAnchor
import markit.core.nodes.{Node, RawSyntaxNode, TypedSyntaxPayload, NodeCodec}
import markit.core.session.ParseSession
import markit.core.source.SourceLine

private func headingState(session: ParseSession): ?HeadingSessionState {
    if (let Some(state) <- session.symbolTables.get(HeadingPlugin.stateKey.dynamicName)) { return state as HeadingSessionState }
    return None
}

// Container providers call this around their existing detached grammar entry,
// then rebase only the newly parsed child graph after restoring physical spans.
public func parseMappedHeadingContributions(session: ParseSession, parse: () -> ArrayList<Node>): ArrayList<Node> {
    if (session.editingContext.isNone() || headingState(session).isNone()) { return parse() }
    headingState(session).getOrThrow().deferContributions()
    try { return parse() }
    finally { headingState(session).getOrThrow().resumeContributions() }
}

public func rebaseHeadingContributions(session: ParseSession, nodes: Array<Node>): Unit {
    if (session.editingContext.isNone() || headingState(session).isNone()) { return }
    if (headingState(session).getOrThrow().contributionsDeferred) { return }
    let context = (session.editingContext.getOrThrow() as BlockEditingContext).getOrThrow()
    let facet = HeadingEditingFacet()
    for (node in nodes) { rebaseHeadingNode(context, node, facet) }
}
private func rebaseHeadingNode(context: BlockEditingContext, node: Node, facet: HeadingEditingFacet): Unit {
    if (let heading: HeadingNode <- node) { facet.contribute(context, heading, heading.sourceSpan.startByte) }
    for (child in node.children) { rebaseHeadingNode(context, child, facet) }
}

public func revokeHeadingContributions(context: BlockEditingContext, node: RawSyntaxNode): Unit {
    if (let Some(state) <- headingState(context.session)) {
        if (let typed: TypedSyntaxPayload <- node.payload) {
            if (typed.materializeShallow() is HeadingNode) {
                state.revokeContribution(node.identity.nodeId, { anchor: SourceAnchor => context.resolve(anchor) })
                state.publishOrderedIndex(context)
            }
        }
        for (i in 0..node.childCount) { revokeHeadingContributions(context, node.childAt(i)) }
    }
}

public func takeHeadingPayloadUpdates(context: BlockEditingContext, excludedId!: Int64 = -1): Array<BlockPayloadUpdate> {
    let result = ArrayList<BlockPayloadUpdate>()
    if (headingState(context.session).isNone() || context.previous.isNone()) { return result.toArray() }
    let state = headingState(context.session).getOrThrow()
    let codec = NodeCodec(); registerHeadingEditingCodecs(codec)
    for (value in state.takeOrderedUpdates()) {
        let id = value.contribution.ownerId
        if (id == excludedId) { continue }
        if (let Some(raw) <- context.previous.getOrThrow().raw(id)) {
            let payload = (raw.payload as TypedSyntaxPayload).getOrThrow()
            let heading = (payload.materializeShallow() as HeadingNode).getOrThrow()
            value.applyTo(heading, includeNumberInHtml: state.includeNumberInHtml())
            result.add(BlockPayloadUpdate(TypedSyntaxPayload(codec, heading, references: payload.references(),
                sourceDerivedRaw: payload.sourceDerivedRaw), id))
        }
    }
    return result.toArray()
}

public func restoreHeadingAwareSession(context: BlockEditingContext, unit: BlockRecoveryUnit): Bool {
    if (unit.mappingVersion >= 0) { return false }
    let ordered = headingState(context.session).map({ state: HeadingSessionState => state.orderedIndex })
    let ownerId = if (let Some(state) <- headingState(context.session)) { state.orderedEffectOwner } else { -1 }
    let restored = context.session.restoreEditingCheckpoint(unit.session,
        remapLine: Some({ line: SourceLine, pending: Bool => context.remapRawLine(line, unit.syntax.sourceVersion, pending) }))
    if (restored) {
        if (let Some(index) <- ordered) { headingState(context.session).getOrThrow().retainOrderedIndex(index, ownerId: ownerId) }
    }
    return restored
}
