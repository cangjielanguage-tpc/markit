package markit.plugins.standard.inline.soft_break

import std.collection.ArrayList
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.{Node, NodeCodec, TypedNodeCodec}
import markit.core.source.SourceSpan

private class SoftBreakSyntax <: IncrementalStatePayload {
    public func clonePayload(): IncrementalStatePayload { return SoftBreakSyntax() }
    public func fingerprint(): String { return "standard.soft-break.v1" }
}

public class SoftBreakEditingFacet <: InlineEditingFacet {
    public prop owner: String { get() { return "ParagraphPlugin" } }
    public prop grammarVersion: String { get() { return "standard.soft-break.v1" } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion,
            SoftBreakSyntax(), syntaxContext: grammarVersion))
    }
    public func restore(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return saved.documentId == context.documentId && saved.owner == owner &&
            saved.syntaxContext == grammarVersion && saved.payload is SoftBreakSyntax
    }
    public func rollbackEffects(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return restore(context, saved) && context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(a: IncrementalCheckpoint, b: IncrementalCheckpoint): Bool {
        return a.owner == owner && b.owner == owner && a.syntaxContext == grammarVersion && b.syntaxContext == grammarVersion
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func leftContext(_: InlineAttemptContext, _: Int64): String { return grammarVersion }
    public func rightContext(_: InlineAttemptContext, _: Int64): String { return grammarVersion }
    public func parseAttempt(context: InlineAttemptContext, startByte: Int64): ?InlineParseResult {
        if (!matchesSoftBreak({ at: Int64 => context.readByteOrEnd(at) }, startByte)) { return None }
        // The legacy inline engine suppresses every escaped opener, including
        // newline. Observe the same real parity dependency in editing mode.
        var cursor = startByte; var slashes: Int64 = 0
        while (cursor > 0) {
            cursor -= 1
            if (context.readByteOrEnd(cursor) != Some(b'\\')) { break }
            slashes += 1
        }
        if (slashes % 2 == 1) { return None }
        let a = context.block.resolve(context.view.mapByte(startByte, AnchorAffinity.Before).getOrThrow()).getOrThrow()
        let b = context.block.resolve(context.view.mapByte(startByte + 1, AnchorAffinity.After).getOrThrow()).getOrThrow()
        let source = context.block.source
        let span = SourceSpan(a, b, source.coordinateAtByte(a).getOrThrow().runeOffset,
            source.coordinateAtByte(b).getOrThrow().runeOffset)
        let node = context.block.session.attachNode(SoftBreakNode(context.block.session.allocateNodeId(), span))
        return Some(InlineParseResult(node, 1, 1))
    }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow {
        var start = context.change.startByte; var oldEnd = context.change.oldEndByte
        var newEnd = context.change.newEndByte
        for (attempt in context.attempts) {
            if (attempt.startByte < start) { start = attempt.startByte }
            if (attempt.endByte > oldEnd) { oldEnd = attempt.endByte }
        }
        newEnd = oldEnd + context.change.newEndByte - context.change.oldEndByte
        return Some(InlineRecoveryWindow(start, oldEnd, newEnd, "single newline token", grammarVersion))
    }
}

public class SoftBreakNodeCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "standard.soft-break" } }
    public func accepts(node: Node): Bool { return node is SoftBreakNode }
    public func createShallow(node: Node): Node { return SoftBreakNode(node.id, node.sourceSpan) }
}
public func registerSoftBreakEditingCodecs(codec: NodeCodec): Unit { codec.register(SoftBreakNodeCodec()) }
