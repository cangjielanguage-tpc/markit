package markit.plugins.standard.block.blockquote

import std.collection.ArrayList
import markit.core.block.*
import markit.core.editing.*
import markit.core.nodes.{Node, RawSyntaxNode, TypedSyntaxPayload}
import markit.core.source.{SourceLine, EditableRopeVersion}
import markit.plugins.standard.block.paragraph.{tryParseMappedParagraphUnit, withMappedParagraphRaw, EditingParagraphNode}
import markit.plugins.standard.editing.{recoverStandardMappedAncestor, StandardBlockRecoveryCarrier, StandardBlockRecovery}
import markit.plugins.standard.block.heading.{parseMappedHeadingContributions, rebaseHeadingContributions,
    revokeHeadingContributions, takeHeadingPayloadUpdates, restoreHeadingAwareSession}

// The plan is immutable provider evidence, tied to the current source epoch.
// It carries child positions instead of a copy of the container's text/tree.
public class BlockquoteSyntaxState <: IncrementalStatePayload {
    public BlockquoteSyntaxState(public let childStart!: Int64 = -1, public let childCount!: Int64 = 0,
        public let windowStart!: Int64 = 0, public let windowEnd!: Int64 = 0,
        public let parentId!: Int64 = -1, public let quoteDepth!: Int64 = 1,
        public let fullStart!: Int64 = -1, public let editStart!: Int64 = 0, public let editEnd!: Int64 = 0) {}
    public func clonePayload(): IncrementalStatePayload {
        return BlockquoteSyntaxState(childStart: childStart, childCount: childCount,
            windowStart: windowStart, windowEnd: windowEnd, parentId: parentId, quoteDepth: quoteDepth,
            fullStart: fullStart, editStart: editStart, editEnd: editEnd)
    }
    public func fingerprint(): String { return "standard.blockquote.closed.v1" }
}

public class BlockquoteEditingFacet <: BlockEditingFacet {
    public prop owner: String { get() { return "BlockquotePlugin" } }
    public prop grammarVersion: String { get() { return "blockquote-v1" } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public prop preservesUntouchedChildEffects: Bool { get() { return true } }
    public func restoreSession(context: BlockEditingContext, unit: BlockRecoveryUnit): Bool {
        return restoreHeadingAwareSession(context, unit)
    }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion,
            BlockquoteSyntaxState(), syntaxContext: grammarVersion))
    }
    public func restore(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        return saved.documentId == context.documentId && saved.owner == owner &&
            saved.syntaxContext == grammarVersion && saved.payload is BlockquoteSyntaxState && context.writeState(owner, saved.payload)
    }
    public func rollbackEffects(context: IncrementalParserContext, _: IncrementalCheckpoint): Bool {
        return context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(a: IncrementalCheckpoint, b: IncrementalCheckpoint): Bool {
        return a.owner == owner && b.owner == owner && a.syntaxContext == b.syntaxContext &&
            a.payload.fingerprint() == b.payload.fingerprint()
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func owns(node: RawSyntaxNode): Bool {
        if (let typed: TypedSyntaxPayload <- node.payload) { return typed.materializeShallow() is EditingBlockquoteNode }
        return false
    }
    public func recover(context: BlockEditingContext, node: RawSyntaxNode, editStart: Int64, editEnd: Int64): ?BlockRecoveryUnit {
        if (let Some(mapped) <- recoverStandardMappedAncestor(context, node, editStart, editEnd)) { return Some(mapped) }
        let quotedNode = ((node.payload as TypedSyntaxPayload).getOrThrow().materializeShallow() as EditingBlockquoteNode).getOrThrow()
        let expected = quotedNode.blockRecovery.getOrThrow()
        var saved = expected
        let quoteStart = context.resolve(node.startAnchor).getOrThrow()
        let quoteEnd = context.resolve(node.endAnchor).getOrThrow()
        let startLine = context.source.coordinateAtByte(quoteStart).getOrThrow().line
        var physicalStart = context.source.byteAtLineColumn(startLine, 0).getOrThrow()
        var physicalEnd = quoteEnd
        var plan = childPlan(context, node, editStart, editEnd, 1)
        if (plan.childStart < 0) {
            let lines = context.lines(physicalStart, quoteEnd)
            var escaped = lines.isEmpty() || blockquoteContentStart(lines[0].text).isNone()
            for (line in lines) { if (!blockquoteContinues(line.text)) { escaped = true; break } }
            if (escaped) {
                let parent = context.previous.getOrThrow().parentOf(node.identity.nodeId).getOrThrow().syntax
                var first = parent.childPosition(node.identity.nodeId)
                // An opening-marker removal can merge the old preceding
                // paragraph. Its own provider checkpoint is the real entry.
                if (first > 0 && (lines.isEmpty() || blockquoteContentStart(lines[0].text).isNone())) {
                    let preceding = parent.childAt(first - 1)
                    if (let Some(recovery) <- quotePrecedingRecovery(preceding)) {
                        saved = recovery; first -= 1
                        let a = context.resolve(preceding.startAnchor).getOrThrow()
                        physicalStart = context.source.byteAtLineColumn(context.source.coordinateAtByte(a).getOrThrow().line, 0).getOrThrow()
                    }
                }
                physicalEnd = context.source.byteLength
                plan = BlockquoteSyntaxState(childStart: -2, fullStart: first)
            }
        }
        let syntax = IncrementalCheckpoint(context.documentId, owner, saved.syntax.sourceVersion, plan, syntaxContext: grammarVersion)
        return Some(BlockRecoveryUnit(owner, node.identity.nodeId,
            SourceAnchor(context.source.identity, physicalStart, affinity: AnchorAffinity.Before),
            SourceAnchor(context.source.identity, physicalEnd, affinity: AnchorAffinity.After),
            saved.session, saved.kernel, syntax, expectedExit: Some(expected.expectedExit),
            expectedKernel: Some(expected.expectedKernel), provider: Some(this)))
    }
    private func childPlan(context: BlockEditingContext, node: RawSyntaxNode,
        editStart: Int64, editEnd: Int64, depth: Int64): BlockquoteSyntaxState {
        let quoteEnd = context.resolve(node.endAnchor).getOrThrow()
        var plan = BlockquoteSyntaxState()
        // A child owns its complete physical lines. Blank separators are part
        // of the selected window; the following sibling is never parsed.
        for (i in 0..node.childCount) {
            let child = node.childAt(i)
            let a = context.resolve(child.startAnchor).getOrThrow()
            let b = context.resolve(child.endAnchor).getOrThrow()
            if (editStart < a || editEnd > b) { continue }
            let lineNumber = context.source.coordinateAtByte(a).getOrThrow().line
            let first = context.source.byteAtLineColumn(lineNumber, 0).getOrThrow()
            let last = if (i + 1 < node.childCount) {
                let nextStart = context.resolve(node.childAt(i + 1).startAnchor).getOrThrow()
                context.source.byteAtLineColumn(context.source.coordinateAtByte(nextStart).getOrThrow().line, 0).getOrThrow()
            } else { quoteEnd }
            // Descend before reading text: a small edit in a nested quote
            // must not materialize that quote's untouched child lines.
            if (owns(child)) {
                let nested = childPlan(context, child, editStart, editEnd, depth + 1)
                if (nested.childStart >= 0) { return nested }
            }
            // A removed marker/blank changes ownership and must return to the
            // outer grammar. This is a syntax boundary, not a byte budget.
            if (quoteSourceWindowIntact(context, first, last, depth)) {
                plan = BlockquoteSyntaxState(childStart: i, childCount: 1, windowStart: first, windowEnd: last,
                    parentId: node.identity.nodeId, quoteDepth: depth, editStart: editStart, editEnd: editEnd)
            }
            break
        }
        return plan
    }
    public func parseUnit(context: BlockEditingContext, unit: BlockRecoveryUnit, kernel: BlockParsingKernel): BlockUnitParseResult {
        let tree = context.previous.getOrThrow()
        let quotedNode = tree.raw(unit.nodeId).getOrThrow()
        let plan = (unit.syntax.payload as BlockquoteSyntaxState).getOrThrow()
        if (plan.childStart >= 0) {
            let parent = tree.raw(plan.parentId).getOrThrow()
            if (plan.childCount == 1) {
                if (let Some(local) <- tryParseMappedParagraphUnit(context, parent.childAt(plan.childStart), plan.editStart, plan.editEnd)) {
                    let updates = ArrayList<BlockPayloadUpdate>()
                    for (update in local.payloadUpdates) { updates.add(update) }
                    for (update in blockquoteAncestorRawUpdates(context, plan.parentId, plan.editStart, plan.editEnd)) { updates.add(update) }
                    return BlockUnitParseResult(local.replacement, checkpoint(context).getOrThrow(),
                        converged: local.converged, reason: local.reason, splice: local.splice,
                        rawReplacement: local.rawReplacement, rawSplice: local.rawSplice, payloadUpdates: updates.toArray())
                }
            }
            let lines = ArrayList<SourceLine>()
            for (line in context.lines(plan.windowStart, plan.windowEnd)) {
                var mapped = line
                for (_ in 0..plan.quoteDepth) { mapped = blockquoteMappedLine(mapped) }
                lines.add(mapped)
            }
            let input = blockquoteChildLines(lines)
            for (i in 0..plan.childCount) {
                let removed = parent.childAt(plan.childStart + i)
                revokeHeadingContributions(context, removed)
                revoke(context, removed)
            }
            let children = parseMappedHeadingContributions(context.session, {
                => withMappedParagraphRaw(context, { => context.session.parseDetachedLines(input) })
            })
            for (child in children) { freezeMappedBlockquoteRaw(child, input, context.sourceVersion, context.documentId) }
            rebaseHeadingContributions(context.session, children.toArray())
            // The replacement field is ignored for a splice; avoid projecting
            // untouched children into mutable Nodes merely to satisfy it.
            let shallow = (quotedNode.payload as TypedSyntaxPayload).getOrThrow().materializeShallow()
            let updates = ArrayList<BlockPayloadUpdate>()
            for (update in takeHeadingPayloadUpdates(context)) { updates.add(update) }
            for (update in blockquoteAncestorRawUpdates(context, plan.parentId, plan.editStart, plan.editEnd, rebuild: true)) { updates.add(update) }
            return BlockUnitParseResult(shallow, checkpoint(context).getOrThrow(),
                reason: "mapped quote child window", splice: Some(BlockChildrenEdit(plan.parentId,
                    plan.childStart, plan.childCount, children.toArray())), payloadUpdates: updates.toArray())
        }
        let parent = tree.parentOf(unit.nodeId).getOrThrow().syntax
        let first = if (plan.fullStart >= 0) { plan.fullStart } else { parent.childPosition(unit.nodeId) }
        let count = if (plan.fullStart >= 0) { parent.childCount - first } else { 1 }
        for (i in 0..count) {
            let removed = parent.childAt(first + i)
            revokeHeadingContributions(context, removed)
            revoke(context, removed)
        }
        let output = ArrayList<Node>()
        kernel.setEmissionSink({ node: Node => output.add(node) })
        let start = context.resolve(unit.start).getOrThrow(); let end = context.resolve(unit.end).getOrThrow()
        for (line in context.lines(start, end)) { kernel.feed(line) }
        kernel.finish()
        if (output.size == 1 && count == 1) { return BlockUnitParseResult(output[0], checkpoint(context).getOrThrow(),
            reason: "quote marker or child boundary changed", payloadUpdates: takeHeadingPayloadUpdates(context)) }
        return BlockUnitParseResult((quotedNode.payload as TypedSyntaxPayload).getOrThrow().materializeShallow(), checkpoint(context).getOrThrow(),
            reason: "quote marker or child boundary changed", splice: Some(BlockChildrenEdit(parent.identity.nodeId,
                first, count, output.toArray())), payloadUpdates: takeHeadingPayloadUpdates(context))
    }
    private func revoke(context: BlockEditingContext, node: RawSyntaxNode): Unit {
        context.effects.revokeOwner(node.identity.nodeId)
        for (i in 0..node.childCount) { revoke(context, node.childAt(i)) }
    }
}

private func quotePrecedingRecovery(node: RawSyntaxNode): ?StandardBlockRecovery {
    let payload = node.payload
    if (let carrier: StandardBlockRecoveryCarrier <- payload) { return carrier.blockRecovery }
    if (let typed: TypedSyntaxPayload <- payload) {
        if (let carrier: StandardBlockRecoveryCarrier <- typed.materializeShallow()) { return carrier.blockRecovery }
    }
    return None
}

// Inspect only line prefixes in the immutable rope. lineAt/context.lines would
// export a whole giant physical line before Paragraph's local inline splice.
private func quoteSourceWindowIntact(context: BlockEditingContext, start: Int64, end: Int64, depth: Int64): Bool {
    let source = (context.source as EditableRopeVersion).getOrThrow()
    var index = source.coordinateAtByte(start).getOrThrow().line
    while (index < source.lineCount) {
        let lineStart = source.byteAtLineColumn(index, 0).getOrThrow()
        if (lineStart >= end) { break }
        let next = if (index + 1 < source.lineCount) { source.byteAtLineColumn(index + 1, 0).getOrThrow() } else { source.byteLength }
        var finish = next
        if (finish > lineStart && source.readByte(finish - 1) == b'\n') { finish -= 1 }
        if (finish > lineStart && source.readByte(finish - 1) == b'\r') { finish -= 1 }
        var first = lineStart
        for (_ in 0..depth) {
            if (!blockquoteSourceContinues(source, first, finish)) { return false }
            first += blockquoteSourceContentStart(source, first, finish) ?? 0
        }
        index += 1
    }
    return true
}

public func blockquoteChildLines(lines: ArrayList<SourceLine>): ArrayList<SourceLine> {
    let output = ArrayList<SourceLine>()
    for (i in 0..lines.size) {
        let line = lines[i]
        output.add(SourceLine(line.text, line.span, terminated: i + 1 < lines.size))
    }
    return output
}

// Freeze only source-derived spellings. Inner quotes and mapped inline nodes
// already own an exact spelling and must keep their additional prefix removal.
public func freezeMappedBlockquoteRaw(node: Node, lines: ArrayList<SourceLine>, version: Int64, documentId: String): Unit {
    if (let paragraph: EditingParagraphNode <- node) {
        paragraph.rawFollowsMappedView = true
        return
    }
    if (!(node is EditingBlockquoteNode) && node.rawContentIsSourceDerived(SourceVersionIdentity(documentId, version))) {
        let span = node.sourceSpan
        var low: Int64 = 0; var high = lines.size
        while (low < high) {
            let mid = low + (high - low) / 2
            if (lines[mid].span.endByte < span.startByte) { low = mid + 1 } else { high = mid }
        }
        let text = StringBuilder()
        var index = low
        while (index < lines.size && lines[index].span.startByte <= span.endByte) {
            let line = lines[index]
            let first = if (span.startByte > line.span.startByte) { span.startByte - line.span.startByte } else { 0 }
            let last = if (span.endByte < line.span.endByte) { span.endByte - line.span.startByte } else { line.text.size }
            if (index > low) { text.append("\n") }
            if (last > first) { text.append(line.text[first..last]) }
            index += 1
        }
        node.setRawContent(text.toString())
    }
    for (child in node.children) { freezeMappedBlockquoteRaw(child, lines, version, documentId) }
}
