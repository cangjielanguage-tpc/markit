package markit.core.inline

import std.collection.ArrayList
import std.collection.HashSet
import std.sort.sort
import markit.core.block.{BlockEditingContext, BlockRawChildrenEdit}
import markit.core.editing.*
import markit.core.nodes.*

// This is staged provider state. Its immutable pointers can be stored in a
// Restorable state payload; only Task05's common publication gate installs it.
private class InlineSnapshotBrand {}

internal class InlineNestedOwners {
    public InlineNestedOwners(public let value: ?InlineNestedOwner, public let even: ?InlineNestedOwners,
        public let odd: ?InlineNestedOwners) {}
    public static func get(root: ?InlineNestedOwners, id: Int64): ?InlineNestedOwner {
        if (root.isNone()) { return None }; let node = root.getOrThrow()
        if (id == 0) { return node.value }
        return get(if (id % 2 == 0) { node.even } else { node.odd }, id / 2)
    }
    public static func changed(root: ?InlineNestedOwners, id: Int64, value: ?InlineNestedOwner): ?InlineNestedOwners {
        var entry = root.flatMap({ node => node.value })
        var even = root.flatMap({ node => node.even }); var odd = root.flatMap({ node => node.odd })
        if (id == 0) { entry = value }
        else if (id % 2 == 0) { even = changed(even, id / 2, value) }
        else { odd = changed(odd, id / 2, value) }
        if (entry.isNone() && even.isNone() && odd.isNone()) { return None }
        return Some(InlineNestedOwners(entry, even, odd))
    }
}

// Persistent provenance set keyed by immutable node ID. Each update copies at
// most the ID bit width; old snapshots never share a mutable collection.
internal class InlineLiteralOrigins {
    public InlineLiteralOrigins(public let marked: Bool, public let even: ?InlineLiteralOrigins,
        public let odd: ?InlineLiteralOrigins) {}
    public static func contains(root: ?InlineLiteralOrigins, id: Int64): Bool {
        if (root.isNone()) { return false }; let node = root.getOrThrow()
        if (id == 0) { return node.marked }
        return contains(if (id % 2 == 0) { node.even } else { node.odd }, id / 2)
    }
    public static func changed(root: ?InlineLiteralOrigins, id: Int64, present: Bool): ?InlineLiteralOrigins {
        let marked = root.map({ node => node.marked }) ?? false
        var even = root.flatMap({ node => node.even }); var odd = root.flatMap({ node => node.odd })
        var next = marked
        if (id == 0) { next = present }
        else if (id % 2 == 0) { even = changed(even, id / 2, present) }
        else { odd = changed(odd, id / 2, present) }
        if (!next && even.isNone() && odd.isNone()) { return None }
        return Some(InlineLiteralOrigins(next, even, odd))
    }
}

public class InlineEditingSnapshot {
    private let changedKeys: Array<String>
    internal let nestedReads: ?InlineNestedReadKeys
    public prop readChanges: Array<String> { get() { return changedKeys.clone() } }
    internal func readsSemantic(key: String): Bool {
        return attempts.hasReadingKey(key) || InlineNestedReadKeys.get(nestedReads, key).isSome()
    }
    internal func semanticKeys(): Array<String> {
        let seen = HashSet<String>(); let result = ArrayList<String>()
        for (record in attempts.records()) {
            for (read in record.dependencies) { if (seen.add(read.key)) { result.add(read.key) } }
        }
        let nested = ArrayList<String>(); InlineNestedReadKeys.keys(nestedReads, nested)
        for (key in nested) { if (seen.add(key)) { result.add(key) } }
        return result.toArray()
    }
    public prop textPatches: Array<LogicalTextSplice> { get() { return childrenEdit.textSplices } }
    internal InlineEditingSnapshot(nestedReads: ?InlineNestedReadKeys, readChanges: Array<String>,
        private let brand: Object, internal let literalOrigins: ?InlineLiteralOrigins,
        internal let nestedOwners: ?InlineNestedOwners,
        public let view: InlineTextView, public let root: RawSyntaxNode,
        public let attempts: InlineAttemptIndex, public let nextAttemptOwner: Int64,
        public let childrenEdit: BlockRawChildrenEdit, public let semanticOwnerId: Int64) {
        this.nestedReads = nestedReads; this.changedKeys = readChanges.clone()
    }
    internal func belongsTo(expected: Object): Bool { return refEq(brand, expected) }
}

private class InlineWindowOutput {
    public let bundles = ArrayList<PersistentNodeBundle>()
    public let attempts = ArrayList<InlineAttemptRecord>()
    public var nextOwner: Int64
    public var literalOrigins: ?InlineLiteralOrigins = None
    public var nestedOwners: ?InlineNestedOwners = None
    public var nestedReads: ?InlineNestedReadKeys = None
    public let readChanges = ArrayList<String>()
    private let changedKeys = HashSet<String>()
    public func changedRead(key: String): Unit { if (changedKeys.add(key)) { readChanges.add(key) } }
    public InlineWindowOutput(startOwner: Int64) { nextOwner = startOwner }
}

private class InlineCandidateBoundary {
    public var left: String = ""
    public var right: String = ""
}

private func requireInlineExecution(parser: InlineParser): InlineEditingFacet {
    if (!parser.supportsIncremental) { throw IllegalArgumentException("Inline parser has no editing declaration") }
    let facet = (parser.incrementalFacet.getOrThrow() as InlineEditingFacet).getOrThrow()
    if (!facet.hasStateCodec || !facet.hasEffectRollback || !facet.hasReadEvidence || !facet.hasNodeCodec) {
        throw IllegalArgumentException("Incomplete inline execution facet")
    }
    return facet
}

public class InlineEditingSession {
    private let snapshotBrand = InlineSnapshotBrand()
    private let parsers: Array<InlineParser>
    private let facets: Array<InlineEditingFacet>
    private let grammarVersions: Array<String>
    private let literalVersion: String
    public InlineEditingSession(private let dispatch: InlineDispatchTable, private let codec: NodeCodec,
        private let literal: InlineLiteralFacet) {
        let registered = dispatch.registeredParsers()
        this.parsers = registered
        let frozen = Array<InlineEditingFacet>(registered.size, { i => requireInlineExecution(registered[i]) })
        this.facets = frozen
        this.grammarVersions = Array<String>(registered.size, { i => frozen[i].grammarVersion })
        this.literalVersion = literal.grammarVersion
    }

    private func validateGrammar(): Unit {
        if (literal.grammarVersion != literalVersion) { throw IllegalArgumentException("Inline literal grammar changed") }
        for (i in 0..parsers.size) {
            let current = requireInlineExecution(parsers[i])
            if (!refEq((current as Object).getOrThrow(), (facets[i] as Object).getOrThrow()) ||
                current.grammarVersion != grammarVersions[i]) {
                throw IllegalArgumentException("Inline execution identity changed")
            }
        }
    }
    private func requireContext(block: BlockEditingContext, view: InlineTextView): Unit {
        let borrowed = block.session.editingContext.getOrThrow()
        if (!refEq((borrowed as Object).getOrThrow(), block) ||
            block.documentId != view.source.documentId || block.sourceVersion != view.source.version) {
            throw IllegalArgumentException("Inline work requires the current editing transaction")
        }
    }

    private func requireSnapshot(previous: InlineEditingSnapshot): Unit {
        if (!previous.belongsTo(snapshotBrand)) { throw IllegalArgumentException("Foreign inline editing snapshot") }
    }

    private func parserIdentity(parser: InlineParser): Int64 {
        for (i in 0..parsers.size) {
            if (refEq((parser as Object).getOrThrow(), (parsers[i] as Object).getOrThrow())) { return i }
        }
        throw IllegalArgumentException("Unregistered inline candidate")
    }

    private func anchor(block: BlockEditingContext, view: InlineTextView, at: Int64, affinity: AnchorAffinity): SourceAnchor {
        let mapped = view.mapByte(at, affinity).getOrThrow()
        let offset = block.resolve(mapped).getOrThrow()
        return SourceAnchor(block.source.identity, offset, affinity: affinity)
    }

    private func appendLiteral(block: BlockEditingContext, view: InlineTextView, start: Int64, end: Int64,
        output: InlineWindowOutput): Unit {
        if (start == end) { return }
        let text = literal.payload(view, start, end, block)
        if (text.isNone()) { throw IllegalArgumentException("Inline literal has no raw spelling proof") }
        let raw = RawSyntaxNode(SyntaxNodeIdentity(block.documentId, block.session.allocateNodeId()), block.sourceVersion,
            anchor(block, view, start, AnchorAffinity.Before), anchor(block, view, end, AnchorAffinity.After),
            text.getOrThrow())
        output.bundles.add(PersistentNodeBundle(raw))
        output.literalOrigins = InlineLiteralOrigins.changed(output.literalOrigins, raw.identity.nodeId, true)
    }

    private func parseWindow(block: BlockEditingContext, view: InlineTextView, start: Int64, end: Int64,
        semanticOwner: Int64, nextOwner: Int64): InlineWindowOutput {
        let output = InlineWindowOutput(nextOwner)
        view.runeOffsetAtByte(start)
        view.runeOffsetAtByte(end)
        var cursor = start
        var literalStart = start
        while (cursor < end) {
            var accepted = false
            for (parser in dispatch.candidatesFor(view.readByte(cursor))) {
                let candidateAt = cursor
                let id = parserIdentity(parser)
                let context = InlineAttemptContext(view, candidateAt, block, output.nextOwner, semanticOwner)
                output.nextOwner += 1
                let facet = facets[id]
                let boundary = InlineCandidateBoundary()
                let parsed = block.session.parserAttempt({ =>
                    boundary.left = facet.leftContext(context, candidateAt)
                    let result = facet.parseAttempt(context, candidateAt)
                    let exit = if (let Some(value) <- result) { candidateAt + value.consumedBytes } else { candidateAt }
                    boundary.right = facet.rightContext(context, exit)
                    return result
                })
                let evidence = context.evidence()
                for (read in evidence.dependencies) { output.changedRead(read.key) }
                let consumed = if (let Some(result) <- parsed) { result.consumedBytes } else { 0 }
                if (consumed < 0 || cursor + consumed > end || (parsed.isSome() && consumed == 0)) {
                    throw IllegalArgumentException("Inline candidate escaped its proven recovery window")
                }
                if (parsed.isNone()) { context.retainFailedReads() }
                output.attempts.add(InlineAttemptRecord(context.owner, id, parser.ownerPlugin, grammarVersions[id],
                    view.mappingIdentity, view.source, cursor, cursor + consumed, evidence.readStart, evidence.readEnd,
                    parsed.isSome(), leftContext: boundary.left, rightContext: boundary.right,
                    dependencies: evidence.dependencies, dependsOnLength: evidence.dependsOnLength,
                    nodeId: if (let Some(result) <- parsed) { result.node.id } else { -1 }))
                if (let Some(result) <- parsed) {
                    appendLiteral(block, view, literalStart, cursor, output)
                    let previous: ?PersistentSyntaxVersion = block.previous.map({ value => (value as PersistentSyntaxVersion).getOrThrow() })
                    let bundle = if (let Some(raw) <- result.rawReplacement) { raw }
                        else { PersistentNodeCapture(codec).capture(result.node, block.source.identity, existing: previous) }
                    if (bundle.root.identity.nodeId != result.node.id || bundle.root.identity.documentId != block.documentId) {
                        throw IllegalArgumentException("Invalid inline raw handoff identity")
                    }
                    if (let Some(nested) <- result.nested) {
                        if (!refEq(nested.snapshot.root, bundle.root) ||
                            nested.snapshot.view.source.documentId != view.source.documentId ||
                            nested.snapshot.view.source.version != view.source.version) {
                            throw IllegalArgumentException("Invalid recursive inline owner handoff")
                        }
                        output.nestedOwners = InlineNestedOwners.changed(output.nestedOwners, result.node.id, Some(nested))
                        for (key in nested.snapshot.semanticKeys()) {
                            output.nestedReads = InlineNestedReadKeys.changed(output.nestedReads, key, result.node.id, true)
                            output.changedRead(key)
                        }
                    }
                    output.bundles.add(bundle)
                    cursor += consumed; literalStart = cursor; accepted = true; break
                }
            }
            if (!accepted) {
                // UTF-8 width is structural source decoding, not grammar.
                let byte = view.readByte(cursor)
                let width: Int64 = if (byte < 0x80) { 1 } else if ((byte & 0xE0) == 0xC0) { 2 }
                    else if ((byte & 0xF0) == 0xE0) { 3 } else { 4 }
                cursor += width
                view.runeOffsetAtByte(cursor) // rejects malformed/partial scalar boundaries
            }
        }
        appendLiteral(block, view, literalStart, end, output)
        return output
    }

    public func parseInitial(block: BlockEditingContext, view: InlineTextView, owner: RawSyntaxNode,
        semanticOwnerId!: Int64 = -1): InlineEditingSnapshot {
        requireContext(block, view)
        if (semanticOwnerId < -1) { throw IllegalArgumentException("Invalid inline semantic owner") }
        let semanticOwner = if (semanticOwnerId < 0) { owner.identity.nodeId } else { semanticOwnerId }
        return block.session.parserAttempt({ => Some(parseInitialCore(block, view, owner, semanticOwner)) }).getOrThrow()
    }
    private func parseInitialCore(block: BlockEditingContext, view: InlineTextView, owner: RawSyntaxNode,
        semanticOwner: Int64): InlineEditingSnapshot {
        validateGrammar()
        let output = parseWindow(block, view, 0, view.byteLength, semanticOwner, 0)
        let bundles = output.bundles.toArray()
        let raw = Array<RawSyntaxNode>(bundles.size, { i => bundles[i].root })
        let root = owner.splicingChildren(0, owner.childCount, raw, block.sourceVersion, { a => block.resolve(a) })
        validateGrammar()
        return InlineEditingSnapshot(output.nestedReads, output.readChanges.toArray(), snapshotBrand, output.literalOrigins,
            output.nestedOwners, view, root, InlineAttemptIndex(view.source, view.mappingIdentity, records: output.attempts.toArray()),
            output.nextOwner, BlockRawChildrenEdit(bundles, [], owner.identity.nodeId, 0, owner.childCount), semanticOwner)
    }

    public func prepare(previous: InlineEditingSnapshot, block: BlockEditingContext, view: InlineTextView,
        change: InlineEditChange): InlineEditingSnapshot {
        requireSnapshot(previous)
        requireContext(block, view)
        validateGrammar()
        return block.session.parserAttempt({ => Some(prepareCore(previous, block, view, change, [])) }).getOrThrow()
    }

    public func replaySemantic(previous: InlineEditingSnapshot, block: BlockEditingContext, view: InlineTextView,
        changedKeys: Array<String>): InlineEditingSnapshot {
        requireSnapshot(previous)
        requireContext(block, view)
        validateGrammar()
        let readers = ArrayList<InlineAttemptRecord>()
        let seenOwners = HashSet<Int64>()
        for (key in changedKeys) {
            for (record in previous.attempts.readingKey(key)) {
                if (seenOwners.add(record.owner)) { readers.add(record) }
            }
        }
        let ordered = readers.toArray()
        sort(ordered, lessThan: { a: InlineAttemptRecord, b: InlineAttemptRecord => a.startByte > b.startByte })
        return block.session.parserAttempt({ =>
            var staged = previous
            let edits = ArrayList<BlockRawChildrenEdit>()
            let changes = ArrayList<String>(); let changed = HashSet<String>()
            // Disjoint readers stay disjoint. A provider's genuine expanded
            // read closure may already consume another selected attempt; in
            // that case its old owner is absent and is not parsed twice.
            for (record in ordered) {
                var actual: ?InlineAttemptRecord = None
                for (candidate in staged.attempts.query(record.startByte, record.endByte)) {
                    if (candidate.owner == record.owner) { actual = Some(candidate); break }
                }
                if (let Some(selected) <- actual) {
                    staged = prepareCore(staged, block, view,
                        InlineEditChange(selected.startByte, selected.startByte, selected.startByte), [selected])
                    edits.add(staged.childrenEdit)
                    for (key in staged.readChanges) { if (changed.add(key)) { changes.add(key) } }
                }
            }
            if (!edits.isEmpty()) {
                let first = edits[0]; let following = ArrayList<BlockRawChildrenEdit>()
                for (edit in first.following) { following.add(edit) }
                for (i in 1..edits.size) { following.add(edits[i]) }
                let batch = BlockRawChildrenEdit(first.inserted, first.textSplices, first.parentId, first.start,
                    first.deleteCount, following: following.toArray())
                staged = InlineEditingSnapshot(staged.nestedReads, changes.toArray(), snapshotBrand, staged.literalOrigins,
                    staged.nestedOwners, view, staged.root, staged.attempts, staged.nextAttemptOwner, batch, staged.semanticOwnerId)
            }
            return Some(replayNested(staged, block, view, changedKeys,
                initialEdit: if (refEq(staged, previous)) { Option<BlockRawChildrenEdit>.None } else { Some(staged.childrenEdit) }))
        }).getOrThrow()
    }

    private func prepareCore(previous: InlineEditingSnapshot, block: BlockEditingContext, view: InlineTextView,
        change: InlineEditChange, semanticReaders: Array<InlineAttemptRecord>): InlineEditingSnapshot {
        validateGrammar()
        if (previous.view.source.documentId != view.source.documentId || block.documentId != view.source.documentId ||
            block.sourceVersion != view.source.version || view.source.version < previous.view.source.version ||
            previous.view.mappingIdentity != view.mappingIdentity ||
            view.byteLength - previous.view.byteLength != change.newEndByte - change.oldEndByte) {
            throw IllegalArgumentException("Unproved inline source/view transition")
        }
        if (semanticReaders.isEmpty()) {
            if (let Some(nested) <- prepareNested(previous, block, view, change)) { return nested }
        }
        let touched = ArrayList<InlineAttemptRecord>()
        let seenOwners = HashSet<Int64>()
        for (record in previous.attempts.query(change.startByte, change.oldEndByte)) {
            if (seenOwners.add(record.owner)) { touched.add(record) }
        }
        if (view.byteLength != previous.view.byteLength) {
            for (record in previous.attempts.lengthReaders()) {
                if (seenOwners.add(record.owner)) { touched.add(record) }
            }
        }
        for (record in semanticReaders) {
            if (seenOwners.add(record.owner)) { touched.add(record) }
        }
        var begin = change.startByte
        var oldEnd = change.oldEndByte
        var newEnd = change.newEndByte
        let delta = change.newEndByte - change.oldEndByte
        while (true) {
            let beforeBegin = begin; let beforeEnd = oldEnd; let beforeNewEnd = newEnd
            for (record in touched) {
            if (record.startByte < begin) { begin = record.startByte }
            if (record.readStart < begin) { begin = record.readStart }
            if (record.endByte > oldEnd) { oldEnd = record.endByte }
            if (record.readEnd > oldEnd) { oldEnd = record.readEnd }
            }
            let recovery = InlineRecoveryContext(touched.toArray(), previous.view, view, change)
            let proof = literal.recoverWindow(recovery).getOrThrow()
            if (proof.startByte < begin) { begin = proof.startByte }
            if (proof.oldEndByte > oldEnd) { oldEnd = proof.oldEndByte }
            if (proof.newEndByte > newEnd) { newEnd = proof.newEndByte }
            for (facet in facets) {
            let window = facet.recoverWindow(recovery).getOrThrow()
            if (window.startByte < begin) { begin = window.startByte }
            if (window.oldEndByte > oldEnd) { oldEnd = window.oldEndByte }
            if (window.newEndByte > newEnd) { newEnd = window.newEndByte }
            }
            if (newEnd - delta > oldEnd) { oldEnd = newEnd - delta }
            newEnd = oldEnd + delta
            if (begin > change.startByte || oldEnd > previous.view.byteLength || newEnd > view.byteLength) {
                throw IllegalArgumentException("Inline provider returned an invalid recovery proof")
            }
            var added = false
            for (record in previous.attempts.query(begin, oldEnd)) {
                // Actual edits use the closed query above. Merely touching an
                // expanded proof's unchanged endpoint is not a new edit.
                if (record.readStart < oldEnd && record.readEnd > begin && seenOwners.add(record.owner)) {
                    touched.add(record); added = true
                }
            }
            if (!added && begin == beforeBegin && oldEnd == beforeEnd && newEnd == beforeNewEnd) { break }
        }
        let recovery = InlineRecoveryContext(touched.toArray(), previous.view, view, change)
        if (begin > change.startByte || oldEnd < change.oldEndByte || newEnd < change.newEndByte ||
            oldEnd > previous.view.byteLength || newEnd > view.byteLength || newEnd - oldEnd != delta) {
            throw IllegalArgumentException("Inline provider returned an invalid recovery proof")
        }
        var hasNewCandidate = false
        var at = begin
        while (at < newEnd) {
            if (!dispatch.candidatesFor(view.readByte(at)).isEmpty()) { hasNewCandidate = true; break }
            at += 1
        }
        if (literal.offsetsFollowLiteral(previous.view) && semanticReaders.isEmpty() && touched.isEmpty() && !hasNewCandidate && previous.root.childCount == 1) {
            let node = previous.root.childAt(0)
            if (InlineLiteralOrigins.contains(previous.literalOrigins, node.identity.nodeId)) {
            if (let payload: PersistentTextPayload <- node.payload) {
                if (payload.rawSpellingFollowsText) {
                if (let Some(splice) <- literal.splice(payload, recovery)) {
                    if (splice.startByte == change.startByte && splice.endByte == change.oldEndByte &&
                        splice.inserted == view.sliceBytes(change.startByte, change.newEndByte)) {
                    let updated = payload.splice(splice.startByte, splice.endByte, splice.inserted)
                    let replacement = RawSyntaxNode(node.identity, block.sourceVersion,
                        anchor(block, view, 0, AnchorAffinity.Before), anchor(block, view, view.byteLength, AnchorAffinity.After), updated)
                    let bundle = PersistentNodeBundle(replacement)
                    let root = previous.root.withChildMapped(0, replacement, block.sourceVersion, { a => block.resolve(a) })
                    let index = previous.attempts.splice(change.startByte, change.oldEndByte, change.newEndByte, [], view.source)
                    validateGrammar()
                    return InlineEditingSnapshot(previous.nestedReads, [], snapshotBrand, previous.literalOrigins, previous.nestedOwners, view, root, index, previous.nextAttemptOwner,
                        BlockRawChildrenEdit([bundle], [LogicalTextSplice(node.identity.nodeId, splice.startByte, splice.endByte, splice.inserted)],
                            previous.root.identity.nodeId, 0, 1), previous.semanticOwnerId)
                }
                }
                }
            }
            }
        }
        return rebuildWindow(previous, block, view, begin, oldEnd, newEnd, change)
    }

    private func prepareNested(previous: InlineEditingSnapshot, block: BlockEditingContext, view: InlineTextView,
        change: InlineEditChange): ?InlineEditingSnapshot {
        let touched = previous.attempts.query(change.startByte, change.oldEndByte)
        if (touched.size != 1) { return None }
        let record = touched[0]
        if (!record.succeeded || record.nodeId < 0 || change.startByte <= record.startByte || change.oldEndByte >= record.endByte) { return None }
        let holder = InlineNestedOwners.get(previous.nestedOwners, record.nodeId)
        if (holder.isNone()) { return None }
        if (view.byteLength != previous.view.byteLength) {
            for (reader in previous.attempts.lengthReaders()) { if (reader.owner != record.owner) { return None } }
        }
        let child = holder.getOrThrow()
        var projection = child.projection
        if (child.snapshot.view.source.version != previous.view.source.version) {
            let rebased = projection.rebase(child.snapshot.view, previous.view, block).getOrThrow()
            if (rebased.view.byteLength != child.snapshot.view.byteLength ||
                rebased.view.mappingIdentity != child.snapshot.view.mappingIdentity) {
                throw IllegalArgumentException("Changed recursive geometry during rebase")
            }
            projection = rebased.projection
        }
        let proof = projection.project(previous.view, view, change)
        if (proof.isNone()) { return None }
        let projected = proof.getOrThrow()
        let position = previous.root.childPosition(record.nodeId)
        if (!refEq(previous.root.childAt(position), child.snapshot.root)) { throw IllegalArgumentException("Stale recursive inline raw owner") }
        let next = child.engine.prepare(child.snapshot, block, projected.view, projected.change)
        if (next.root.identity.documentId != child.snapshot.root.identity.documentId ||
            next.root.identity.nodeId != child.snapshot.root.identity.nodeId) { throw IllegalArgumentException("Recursive owner identity changed") }
        let delta = view.byteLength - previous.view.byteLength
        let replacement = InlineAttemptRecord(record.owner, record.parserIdentity, record.parserOwner, record.grammarVersion,
            record.mappingIdentity, view.source, record.startByte, record.endByte + delta, record.readStart, record.readEnd + delta,
            true, leftContext: record.leftContext, rightContext: record.rightContext, nestedOwner: record.nestedOwner,
            dependencies: record.dependencies, nodeId: record.nodeId, dependsOnLength: record.dependsOnLength)
        let index = if (view.source.version == previous.view.source.version) {
            previous.attempts.replacingOwners([record.owner], [replacement])
        } else { previous.attempts.splice(change.startByte, change.oldEndByte, change.newEndByte, [replacement], view.source) }
        let root = previous.root.withChildMapped(position, next.root, block.sourceVersion, { a => block.resolve(a) })
        let owners = InlineNestedOwners.changed(previous.nestedOwners, record.nodeId,
            Some(InlineNestedOwner(child.engine, next, projected.projection)))
        var reads = previous.nestedReads
        for (key in next.readChanges) { reads = InlineNestedReadKeys.changed(reads, key, record.nodeId, next.readsSemantic(key)) }
        validateGrammar()
        return Some(InlineEditingSnapshot(reads, next.readChanges, snapshotBrand, previous.literalOrigins, owners, view, root, index,
            previous.nextAttemptOwner, next.childrenEdit, previous.semanticOwnerId))
    }

    private func replayNested(previous: InlineEditingSnapshot, block: BlockEditingContext, view: InlineTextView,
        keys: Array<String>, initialEdit!: ?BlockRawChildrenEdit = None): InlineEditingSnapshot {
        let selected = ArrayList<Int64>(); let seen = HashSet<Int64>()
        for (key in keys) {
            let owners = ArrayList<Int64>()
            InlineNestedReadKeys.ownerIds(InlineNestedReadKeys.get(previous.nestedReads, key), owners)
            for (owner in owners) { if (seen.add(owner)) { selected.add(owner) } }
        }
        if (selected.isEmpty()) { return previous }
        var root = previous.root; var holders = previous.nestedOwners; var reads = previous.nestedReads
        let changes = ArrayList<String>(); let changed = HashSet<String>()
        if (initialEdit.isSome()) { for (key in previous.readChanges) { if (changed.add(key)) { changes.add(key) } } }
        let edits = ArrayList<BlockRawChildrenEdit>()
        if (let Some(edit) <- initialEdit) { edits.add(edit) }
        for (id in selected) {
            if (let Some(child) <- InlineNestedOwners.get(holders, id)) {
                var childView = child.snapshot.view; var projection = child.projection
                if (childView.source.version != block.sourceVersion) {
                    let rebased = projection.rebase(childView, view, block).getOrThrow()
                    if (rebased.view.byteLength != childView.byteLength ||
                        rebased.view.mappingIdentity != childView.mappingIdentity) {
                        throw IllegalArgumentException("Changed recursive geometry during semantic rebase")
                    }
                    childView = rebased.view; projection = rebased.projection
                }
                let next = child.engine.replaySemantic(child.snapshot, block, childView, keys)
                if (refEq(next, child.snapshot)) { continue }
                root = root.withChildMapped(root.childPosition(id), next.root, block.sourceVersion, { a => block.resolve(a) })
                holders = InlineNestedOwners.changed(holders, id, Some(InlineNestedOwner(child.engine, next, projection)))
                for (key in next.readChanges) {
                    reads = InlineNestedReadKeys.changed(reads, key, id, next.readsSemantic(key))
                    if (changed.add(key)) { changes.add(key) }
                }
                edits.add(next.childrenEdit)
            }
        }
        if (edits.isEmpty()) { return previous }
        let first = edits[0]; let following = ArrayList<BlockRawChildrenEdit>()
        for (edit in first.following) { following.add(edit) }
        for (i in 1..edits.size) { following.add(edits[i]) }
        let batch = BlockRawChildrenEdit(first.inserted, first.textSplices, first.parentId, first.start, first.deleteCount,
            following: following.toArray())
        return InlineEditingSnapshot(reads, changes.toArray(), snapshotBrand, previous.literalOrigins, holders, view, root, previous.attempts,
            previous.nextAttemptOwner, batch, previous.semanticOwnerId)
    }

    private func appendMerged(output: InlineWindowOutput, bundle: PersistentNodeBundle,
        block: BlockEditingContext, isLiteral!: Bool): Unit {
        if (isLiteral && !output.bundles.isEmpty()) {
            let last = output.bundles[output.bundles.size - 1]
            if (InlineLiteralOrigins.contains(output.literalOrigins, last.root.identity.nodeId)) {
            if (let a: PersistentTextPayload <- last.root.payload) {
                if (let b: PersistentTextPayload <- bundle.root.payload) {
                    let merged = RawSyntaxNode(last.root.identity, block.sourceVersion, last.root.startAnchor,
                        bundle.root.endAnchor, a.concatenatedSpelling(b))
                    output.bundles[output.bundles.size - 1] = PersistentNodeBundle(merged)
                    return
                }
            }
            }
        }
        output.bundles.add(bundle)
        if (isLiteral) { output.literalOrigins = InlineLiteralOrigins.changed(output.literalOrigins, bundle.root.identity.nodeId, true) }
    }

    private func revokeChanged(block: BlockEditingContext, node: RawSyntaxNode): Unit {
        block.effects.revokeOwner(node.identity.nodeId)
        for (i in 0..node.childCount) { revokeChanged(block, node.childAt(i)) }
    }

    private func rebuildWindow(previous: InlineEditingSnapshot, block: BlockEditingContext, view: InlineTextView,
        syntaxBegin: Int64, syntaxOldEnd: Int64, syntaxNewEnd: Int64, change: InlineEditChange): InlineEditingSnapshot {
        var begin = syntaxBegin; var oldEnd = syntaxOldEnd; var newEnd = syntaxNewEnd
        // Re-decoding a logical literal is not a second source edit. Expand
        // only its materialization unit, after syntax/read closure is stable.
        let firstA = block.resolve(previous.view.mapByte(begin, AnchorAffinity.Before).getOrThrow()).getOrThrow()
        let firstB = block.resolve(previous.view.mapByte(oldEnd, AnchorAffinity.After).getOrThrow()).getOrThrow()
        for (node in previous.root.overlappingChildren(firstA, firstB, { key => block.resolve(key) })) {
            if (InlineLiteralOrigins.contains(previous.literalOrigins, node.identity.nodeId) &&
                (!literal.offsetsFollowLiteral(previous.view) ||
                !(node.payload as PersistentTextPayload).getOrThrow().rawSpellingFollowsText)) {
                let left = literal.projectRaw(previous.view, node.startAnchor, block).getOrThrow()
                let right = literal.projectRaw(previous.view, node.endAnchor, block).getOrThrow()
                if (right > syntaxBegin && left < syntaxOldEnd || syntaxBegin == syntaxOldEnd && left <= syntaxBegin && right >= syntaxBegin) {
                    if (left < begin) { begin = left }; if (right > oldEnd) { oldEnd = right }
                }
            }
        }
        newEnd = oldEnd + change.newEndByte - change.oldEndByte
        let a = block.resolve(previous.view.mapByte(begin, AnchorAffinity.Before).getOrThrow()).getOrThrow()
        let b = block.resolve(previous.view.mapByte(oldEnd, AnchorAffinity.After).getOrThrow()).getOrThrow()
        let selected = ArrayList<RawSyntaxNode>()
        for (node in previous.root.overlappingChildren(a, b, { key => block.resolve(key) })) {
            let left = literal.projectRaw(previous.view, node.startAnchor, block).getOrThrow()
            let right = literal.projectRaw(previous.view, node.endAnchor, block).getOrThrow()
            if (right > begin && left < oldEnd || begin == oldEnd && left <= begin && right >= begin) { selected.add(node) }
        }
        let affected = selected.toArray()
        let first = if (affected.isEmpty()) { 0 } else { previous.root.childPosition(affected[0].identity.nodeId) }
        if (affected.isEmpty() && previous.root.childCount != 0) { throw IllegalArgumentException("Unproved inline insertion position") }
        let replacement = InlineWindowOutput(previous.nextAttemptOwner)
        replacement.literalOrigins = previous.literalOrigins
        replacement.nestedOwners = previous.nestedOwners
        replacement.nestedReads = previous.nestedReads
        for (node in affected) {
            replacement.literalOrigins = InlineLiteralOrigins.changed(replacement.literalOrigins, node.identity.nodeId, false)
            replacement.nestedOwners = InlineNestedOwners.changed(replacement.nestedOwners, node.identity.nodeId, None)
            if (let Some(child) <- InlineNestedOwners.get(previous.nestedOwners, node.identity.nodeId)) {
                for (key in child.snapshot.semanticKeys()) {
                    replacement.nestedReads = InlineNestedReadKeys.changed(replacement.nestedReads, key, node.identity.nodeId, false)
                    replacement.changedRead(key)
                }
            }
        }
        var prefixOwner: Int64 = -1
        if (!affected.isEmpty()) {
            let node = affected[0]
            let nodeStart = literal.projectRaw(previous.view, node.startAnchor, block).getOrThrow()
            if (nodeStart < begin) {
                if (!literal.offsetsFollowLiteral(previous.view) || !InlineLiteralOrigins.contains(previous.literalOrigins, node.identity.nodeId)) {
                    throw IllegalArgumentException("Unproved literal prefix coordinates")
                }
                let text = (node.payload as PersistentTextPayload).getOrThrow()
                let raw = RawSyntaxNode(node.identity, block.sourceVersion,
                    anchor(block, view, nodeStart, AnchorAffinity.Before), anchor(block, view, begin, AnchorAffinity.After),
                    text.sliced(0, begin - nodeStart))
                appendMerged(replacement, PersistentNodeBundle(raw), block, isLiteral: true); prefixOwner = node.identity.nodeId
            }
        }
        for (node in affected) { revokeChanged(block, node) }
        let parsed = parseWindow(block, view, begin, newEnd, previous.semanticOwnerId, previous.nextAttemptOwner)
        for (bundle in parsed.bundles) {
            appendMerged(replacement, bundle, block, isLiteral: InlineLiteralOrigins.contains(parsed.literalOrigins, bundle.root.identity.nodeId))
            replacement.nestedOwners = InlineNestedOwners.changed(replacement.nestedOwners, bundle.root.identity.nodeId,
                InlineNestedOwners.get(parsed.nestedOwners, bundle.root.identity.nodeId))
            if (let Some(child) <- InlineNestedOwners.get(parsed.nestedOwners, bundle.root.identity.nodeId)) {
                for (key in child.snapshot.semanticKeys()) {
                    replacement.nestedReads = InlineNestedReadKeys.changed(replacement.nestedReads, key, bundle.root.identity.nodeId, true)
                    replacement.changedRead(key)
                }
            }
        }
        if (!affected.isEmpty()) {
            let node = affected[affected.size - 1]
            let nodeEnd = literal.projectRaw(previous.view, node.endAnchor, block).getOrThrow()
            if (nodeEnd > oldEnd) {
                if (!literal.offsetsFollowLiteral(previous.view) || !InlineLiteralOrigins.contains(previous.literalOrigins, node.identity.nodeId)) {
                    throw IllegalArgumentException("Unproved literal suffix coordinates")
                }
                let text = (node.payload as PersistentTextPayload).getOrThrow()
                let nodeStart = literal.projectRaw(previous.view, node.startAnchor, block).getOrThrow()
                let id = if (node.identity.nodeId == prefixOwner) { block.session.allocateNodeId() } else { node.identity.nodeId }
                let tail = text.sliced(oldEnd - nodeStart, text.byteLength)
                let raw = RawSyntaxNode(SyntaxNodeIdentity(block.documentId, id), block.sourceVersion,
                    anchor(block, view, newEnd, AnchorAffinity.Before),
                    anchor(block, view, nodeEnd + newEnd - oldEnd, AnchorAffinity.After), tail)
                appendMerged(replacement, PersistentNodeBundle(raw), block, isLiteral: true)
            }
        }
        var spliceStart = first; var deleteCount = affected.size
        if (replacement.bundles.isEmpty() && first > 0 && first + affected.size < previous.root.childCount) {
            let left = previous.root.childAt(first - 1); let right = previous.root.childAt(first + affected.size)
            if (InlineLiteralOrigins.contains(previous.literalOrigins, left.identity.nodeId) &&
                InlineLiteralOrigins.contains(previous.literalOrigins, right.identity.nodeId)) {
                let a = (left.payload as PersistentTextPayload).getOrThrow()
                let b = (right.payload as PersistentTextPayload).getOrThrow()
                replacement.bundles.add(PersistentNodeBundle(RawSyntaxNode(left.identity, block.sourceVersion,
                    left.startAnchor, right.endAnchor, a.concatenatedSpelling(b))))
                replacement.literalOrigins = InlineLiteralOrigins.changed(replacement.literalOrigins, left.identity.nodeId, true)
                replacement.literalOrigins = InlineLiteralOrigins.changed(replacement.literalOrigins, right.identity.nodeId, false)
                revokeChanged(block, right)
                spliceStart -= 1; deleteCount += 2
            }
        }
        if (!replacement.bundles.isEmpty()) {
            let firstBundle = replacement.bundles[0]
            if (spliceStart == first && first > 0 && InlineLiteralOrigins.contains(replacement.literalOrigins, firstBundle.root.identity.nodeId)) {
                let neighbor = previous.root.childAt(first - 1)
                if (InlineLiteralOrigins.contains(previous.literalOrigins, neighbor.identity.nodeId)) {
                    let a = (neighbor.payload as PersistentTextPayload).getOrThrow()
                    let b = (firstBundle.root.payload as PersistentTextPayload).getOrThrow()
                    replacement.bundles[0] = PersistentNodeBundle(RawSyntaxNode(neighbor.identity, block.sourceVersion,
                        neighbor.startAnchor, firstBundle.root.endAnchor, a.concatenatedSpelling(b)))
                    replacement.literalOrigins = InlineLiteralOrigins.changed(replacement.literalOrigins, firstBundle.root.identity.nodeId, false)
                    replacement.literalOrigins = InlineLiteralOrigins.changed(replacement.literalOrigins, neighbor.identity.nodeId, true)
                    spliceStart -= 1; deleteCount += 1
                }
            }
            let lastBundle = replacement.bundles[replacement.bundles.size - 1]
            let after = first + affected.size
            if (spliceStart + deleteCount == after && after < previous.root.childCount && InlineLiteralOrigins.contains(replacement.literalOrigins, lastBundle.root.identity.nodeId)) {
                let neighbor = previous.root.childAt(after)
                if (InlineLiteralOrigins.contains(previous.literalOrigins, neighbor.identity.nodeId)) {
                    appendMerged(replacement, PersistentNodeBundle(neighbor), block, isLiteral: true)
                    replacement.literalOrigins = InlineLiteralOrigins.changed(replacement.literalOrigins, neighbor.identity.nodeId, false)
                    revokeChanged(block, neighbor)
                    deleteCount += 1
                }
            }
        }
        let bundles = replacement.bundles.toArray()
        let nodes = Array<RawSyntaxNode>(bundles.size, { i => bundles[i].root })
        let root = previous.root.splicingChildren(spliceStart, deleteCount, nodes, block.sourceVersion, { key => block.resolve(key) })
        // Remove actually retried openers. The actual source edit then shifts
        // the unaffected suffix lazily, preserving its original evidence birth.
        let old = previous.attempts.query(begin, oldEnd)
        let retried = ArrayList<Int64>()
        for (record in old) {
            if (record.startByte >= begin && record.startByte < oldEnd) {
                retried.add(record.owner)
                for (read in record.dependencies) { replacement.changedRead(read.key) }
            }
        }
        for (key in parsed.readChanges) { replacement.changedRead(key) }
        var index: InlineAttemptIndex
        if (view.source.version == previous.view.source.version) {
            index = previous.attempts.replacingOwners(retried.toArray(), parsed.attempts.toArray())
        } else {
            index = previous.attempts.replacingOwners(retried.toArray(), []).splice(change.startByte, change.oldEndByte,
                change.newEndByte, parsed.attempts.toArray(), view.source)
        }
        validateGrammar()
        return InlineEditingSnapshot(replacement.nestedReads, replacement.readChanges.toArray(), snapshotBrand, replacement.literalOrigins,
            replacement.nestedOwners, view, root, index, parsed.nextOwner,
            BlockRawChildrenEdit(bundles, [], previous.root.identity.nodeId, spliceStart, deleteCount), previous.semanticOwnerId)
    }
}
