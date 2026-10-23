package markit.plugins.standard.block.paragraph

import std.collection.ArrayList
import markit.core.block.*
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.*
import markit.core.source.SourceSpan
import markit.plugins.standard.editing.*

class ParagraphShellPayload <: SyntaxNodePayload {
    public prop codecId: String { get() { return "standard.paragraph.inline-owner" } }
    public func clonePayload(): SyntaxNodePayload { return this }
}
class ParagraphSyntaxState <: IncrementalStatePayload {
    public ParagraphSyntaxState(public let editStart!: Int64 = -1, public let editEnd!: Int64 = -1) {}
    public func clonePayload(): IncrementalStatePayload { return this }
    public func fingerprint(): String { return "standard.paragraph.v1" }
}

// Used by a mapped block provider after it has proved its prefixes unchanged.
// The old view already contains that provider's physical mapping. Only the
// actual inserted/deleted bytes are exported or counted on the ordinary path.
public func tryParseMappedParagraphUnit(context: BlockEditingContext, childRaw: RawSyntaxNode,
    editStart: Int64, editEnd: Int64): ?BlockUnitParseResult {
    let optional = childRaw.payload as ParagraphPayload
    if (optional.isNone()) { return None }; let old = optional.getOrThrow()
    if (!old.boundary.proves(context, old.view, editStart)) { return None }
    let startAnchor = SourceAnchor(context.source.identity, editStart, affinity: AnchorAffinity.Before)
    let endAnchor = SourceAnchor(context.source.identity, editEnd, affinity: AnchorAffinity.After)
    let a = old.plan.literal.projectRaw(old.view, startAnchor, context)
    let b = old.plan.literal.projectRaw(old.view, endAnchor, context)
    if (a.isNone() || b.isNone()) { return None }
    let start = a.getOrThrow(); let end = b.getOrThrow()
    if (start < 0 || end < start || end > old.contentEnd) { return None }
    let inserted = RopeInlineTextView(context.source, editStart, editEnd)
    // Newlines change block/normalization boundaries and belong to the real
    // enclosing grammar, rather than this literal-coordinate proof.
    for (i in 0..inserted.byteLength) { if (inserted.readByte(i) == b'\n' || inserted.readByte(i) == b'\r') { return None } }
    for (i in start..end) { if (old.view.readByte(i) == b'\n') { return None } }
    let mapped = old.view.mapped.spliceBytes(start, end, [inserted], context.source.identity, old.view.mappingIdentity)
    let escapes = old.view.escapeCount - paragraphEscapeCount(old.view, start, end) +
        paragraphEscapeCount(inserted, 0, inserted.byteLength)
    let view = StandardParagraphInlineView(mapped, escapes, normalizedRaw: old.view.normalizedRaw)
    context.enterOwner(childRaw.identity.nodeId, "ParagraphPlugin")
    let snapshot = old.engine.prepare(old.snapshot, context, view, InlineEditChange(start, end, start + inserted.byteLength))
    let rawStart = context.resolve(childRaw.startAnchor).getOrThrow()
    let rawEnd = context.resolve(childRaw.endAnchor).getOrThrow()
    let span = SourceSpan(rawStart, rawEnd, context.source.coordinateAtByte(rawStart).getOrThrow().runeOffset,
        context.source.coordinateAtByte(rawEnd).getOrThrow().runeOffset)
    let payload = old.updated(view, context.source, snapshot, span, old.contentEnd + inserted.byteLength - (end - start))
    let exit = ParagraphEditingFacet().checkpoint(context).getOrThrow()
    return Some(BlockUnitParseResult(Node("paragraph-payload-update"), exit,
        rawSplice: Some(snapshot.childrenEdit), payloadUpdates: [BlockPayloadUpdate(payload, childRaw.identity.nodeId)]))
}

public class ParagraphEditingFacet <: BlockEditingFacet {
    public prop owner: String { get() { return "ParagraphPlugin" } }
    public prop grammarVersion: String { get() { return "standard.paragraph.v1" } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public prop preservesUntouchedChildEffects: Bool { get() { return true } }
    public prop preservesUnchangedSemanticReads: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion,
            ParagraphSyntaxState(), syntaxContext: grammarVersion))
    }
    public func restore(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return saved.documentId == context.documentId && saved.owner == owner && saved.payload is ParagraphSyntaxState &&
            saved.syntaxContext == grammarVersion
    }
    public func rollbackEffects(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool { return restore(context, saved) }
    public func syntaxEquivalent(a: IncrementalCheckpoint, b: IncrementalCheckpoint): Bool {
        return a.owner == owner && b.owner == owner && a.syntaxContext == grammarVersion && b.syntaxContext == grammarVersion
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func syntaxReadKeys(_: RawSyntaxNode): ?Array<String> { return Some([]) }
    public func owns(node: RawSyntaxNode): Bool { return node.payload is ParagraphPayload }
    public func restoreSession(_: BlockEditingContext, _: BlockRecoveryUnit): Bool {
        // Normal inline edits use the saved immutable child snapshot plus the
        // current transaction state, and never restore/copy old SourceLines.
        return true
    }
    public func recover(context: BlockEditingContext, node: RawSyntaxNode, start: Int64, end: Int64): ?BlockRecoveryUnit {
        if (let Some(mapped) <- recoverStandardMappedAncestor(context, node, start, end)) { return Some(mapped) }
        let payload = (node.payload as ParagraphPayload).getOrThrow()
        let syntax = IncrementalCheckpoint(context.documentId, owner, context.sourceVersion,
            ParagraphSyntaxState(editStart: start, editEnd: end), syntaxContext: grammarVersion)
        return Some(BlockRecoveryUnit(owner, node.identity.nodeId, node.startAnchor, node.endAnchor,
            payload.recovery.session, payload.recovery.kernel, syntax,
            expectedExit: Some(payload.recovery.expectedExit), expectedKernel: Some(payload.recovery.expectedKernel)))
    }
    public func parseUnit(context: BlockEditingContext, unit: BlockRecoveryUnit, kernel: BlockParsingKernel): BlockUnitParseResult {
        let state = (unit.syntax.payload as ParagraphSyntaxState).getOrThrow()
        let node = context.previous.getOrThrow().raw(unit.nodeId).getOrThrow()
        if (let Some(result) <- tryParseMappedParagraphUnit(context, node, state.editStart, state.editEnd)) { return result }
        let previous = (node.payload as ParagraphPayload).getOrThrow()
        if (!context.session.restoreEditingCheckpoint(previous.recovery.session,
            remapLine: Some({ line, pending => context.remapRawLine(line, previous.recovery.syntax.sourceVersion, pending) }))) {
            throw IllegalArgumentException("Paragraph structural recovery checkpoint unavailable")
        }
        let parsed = ArrayList<Node>(); kernel.setEmissionSink({ value: Node => parsed.add(value) })
        let start = context.resolve(unit.start).getOrThrow(); let end = context.resolve(unit.end).getOrThrow()
        if (start < end) { for (line in context.lines(start, end)) { kernel.feed(line) } }
        kernel.finish()
        let tree = context.previous.getOrThrow(); let parent = tree.parentOf(unit.nodeId).getOrThrow().syntax
        return BlockUnitParseResult(Node("paragraph-structural-splice"), checkpoint(context).getOrThrow(),
            splice: Some(BlockChildrenEdit(parent.identity.nodeId, parent.childPosition(unit.nodeId), 1, parsed.toArray())))
    }
    public func replaySemantic(context: BlockEditingContext, node: RawSyntaxNode): Unit {}
    public func replaySemanticResult(context: BlockEditingContext, node: RawSyntaxNode): ?BlockUnitParseResult {
        let old = (node.payload as ParagraphPayload).getOrThrow()
        let view = StandardParagraphInlineView(old.view.mapped.spliceBytes(0, 0, [], context.source.identity,
            old.view.mappingIdentity), old.view.escapeCount, normalizedRaw: old.view.normalizedRaw)
        context.enterOwner(node.identity.nodeId, owner)
        let snapshot = old.engine.replaySemantic(old.snapshot, context, view, context.invalidatedKeys)
        let start = context.resolve(node.startAnchor).getOrThrow(); let end = context.resolve(node.endAnchor).getOrThrow()
        let span = SourceSpan(start, end, context.source.coordinateAtByte(start).getOrThrow().runeOffset,
            context.source.coordinateAtByte(end).getOrThrow().runeOffset)
        let payload = old.updated(view, context.source, snapshot, span, old.contentEnd)
        return Some(BlockUnitParseResult(Node("paragraph-semantic-update"), checkpoint(context).getOrThrow(),
            rawSplice: Some(snapshot.childrenEdit), payloadUpdates: [BlockPayloadUpdate(payload, node.identity.nodeId)]))
    }
}
