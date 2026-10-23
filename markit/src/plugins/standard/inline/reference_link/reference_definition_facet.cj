package markit.plugins.standard.inline.reference_link

import std.collection.ArrayList
import markit.core.block.*
import markit.core.editing.*
import markit.core.nodes.{Node, RawSyntaxNode, MaterializableNodePayload}
import markit.plugins.standard.editing.recoverStandardMappedAncestor

private class ReferenceDefinitionState <: IncrementalStatePayload {
    public func clonePayload(): IncrementalStatePayload { return ReferenceDefinitionState() }
    public func fingerprint(): String { return "reference-definition-v1" }
}

public class ReferenceDefinitionFacet <: BlockEditingFacet {
    public prop owner: String { get() { return "ReferenceLinkPlugin" } }
    public prop grammarVersion: String { get() { return "reference-definition-v1" } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion,
            ReferenceDefinitionState(), syntaxContext: grammarVersion))
    }
    public func restore(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return saved.documentId == context.documentId && saved.owner == owner && saved.sourceVersion <= context.sourceVersion &&
            saved.syntaxContext == grammarVersion && (saved.payload is ReferenceDefinitionState)
    }
    public func rollbackEffects(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return restore(context, saved) && context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(a: IncrementalCheckpoint, b: IncrementalCheckpoint): Bool {
        return a.documentId == b.documentId && a.owner == owner && b.owner == owner &&
            a.syntaxContext == grammarVersion && b.syntaxContext == grammarVersion &&
            (a.payload is ReferenceDefinitionState) && (b.payload is ReferenceDefinitionState)
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func syntaxReadKeys(_: RawSyntaxNode): ?Array<String> { return Some([]) }
    public func owns(node: RawSyntaxNode): Bool {
        if (let typed: MaterializableNodePayload <- node.payload) { return typed.materializeShallow() is ReferenceDefinitionNode }
        return false
    }
    public func recover(context: BlockEditingContext, node: RawSyntaxNode, editStart: Int64, editEnd: Int64): ?BlockRecoveryUnit {
        if (let Some(mapped) <- recoverStandardMappedAncestor(context, node, editStart, editEnd)) { return Some(mapped) }
        if (let typed: MaterializableNodePayload <- node.payload) {
            if (let definition: ReferenceDefinitionNode <- typed.materializeShallow()) {
                if (let Some(recovery) <- definition.blockRecovery) { return Some(recovery.unit(owner, node)) }
            }
        }
        return None
    }
    public func parseUnit(context: BlockEditingContext, unit: BlockRecoveryUnit, kernel: BlockParsingKernel): BlockUnitParseResult {
        let start = context.resolve(unit.start).getOrThrow(); let end = context.resolve(unit.end).getOrThrow()
        let parsed = ArrayList<Node>()
        kernel.setEmissionSink({ node: Node => parsed.add(node) })
        if (start < end) { for (line in context.lines(start, end)) { kernel.feed(line) } }
        kernel.finish()
        let exit = checkpoint(context).getOrThrow()
        if (parsed.size == 1) { return BlockUnitParseResult(parsed[0], exit) }
        let tree = context.previous.getOrThrow()
        let parent = tree.parentOf(unit.nodeId).getOrThrow().syntax
        return BlockUnitParseResult(tree.materializeLegacy(nodeId: Some(unit.nodeId)), exit,
            splice: Some(BlockChildrenEdit(parent.identity.nodeId, parent.childPosition(unit.nodeId), 1, parsed.toArray())))
    }
    public func contribute(context: BlockEditingContext, node: ReferenceDefinitionNode): Unit {
        let key = referenceSemanticKey(node.label)
        if (context.previous.isSome()) {
            context.effects.reorderKey(key, { effect: OwnedSemanticEffect =>
                if (let definition: LinkDefinition <- effect.payload) {
                    if (let Some(anchor) <- definition.anchor) { context.resolve(anchor).getOrThrow() } else { effect.order }
                } else { effect.order }
            })
        }
        context.effects.add(OwnedSemanticEffect(node.id, referenceSemanticKey(node.label),
            LinkDefinition(node.url, node.title, anchor: Some(SourceAnchor(context.source.identity,
                node.sourceSpan.startByte, affinity: AnchorAffinity.After))), node.sourceSpan.startByte))
    }
    public func replaySemantic(context: BlockEditingContext, node: RawSyntaxNode): Unit {
        let value = ((node.payload as MaterializableNodePayload).getOrThrow().materializeShallow() as ReferenceDefinitionNode).getOrThrow()
        let span = context.resolve(node.startAnchor).getOrThrow()
        context.effects.add(OwnedSemanticEffect(value.id, referenceSemanticKey(value.label),
            LinkDefinition(value.url, value.title, anchor: Some(SourceAnchor(context.source.identity, span,
                affinity: AnchorAffinity.After))), span))
    }
}

