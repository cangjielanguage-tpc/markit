package markit.core.inline

import std.collection.ArrayList
import markit.core.block.BlockEditingContext
import markit.core.editing.*
import markit.core.nodes.PersistentTextPayload

// View offsets are logical UTF-8 offsets. Providers own delimiter, escape and
// boundary semantics; the scheduler never recognizes a grammar marker.
public class InlineEditChange {
    public InlineEditChange(public let startByte: Int64, public let oldEndByte: Int64, public let newEndByte: Int64) {
        if (startByte < 0 || oldEndByte < startByte || newEndByte < startByte) {
            throw IllegalArgumentException("Invalid inline edit window")
        }
    }
}

public class InlineRecoveryWindow {
    public InlineRecoveryWindow(public let startByte: Int64, public let oldEndByte: Int64,
        public let newEndByte: Int64, public let reason: String, public let contextFingerprint: String) {
        if (startByte < 0 || oldEndByte < startByte || newEndByte < startByte || reason.isEmpty()) {
            throw IllegalArgumentException("Invalid inline recovery proof")
        }
    }
}

public class InlineAttemptEvidence {
    private let reads: Array<IncrementalReadDependency>
    public prop dependencies: Array<IncrementalReadDependency> { get() { return reads.clone() } }
    public InlineAttemptEvidence(dependencies: Array<IncrementalReadDependency>,
        public let readStart: Int64, public let readEnd: Int64, public let dependsOnLength!: Bool = false) {
        this.reads = dependencies.clone()
    }
}

// These measurements are correctness evidence, not a runtime counter facility.
// A None result keeps its observed reads even when the candidate's session and
// owned writes are rolled back by ParseSession.parserAttempt.
private class InlineObservedView <: InlineTextView {
    private let underlying: InlineTextView
    public var readStart: Int64
    public var readEnd: Int64
    public var dependsOnLength: Bool = false
    public InlineObservedView(view: InlineTextView, start: Int64) {
        underlying = view; readStart = start; readEnd = start
    }
    public prop source: SourceVersionIdentity { get() { return underlying.source } }
    public prop mappingIdentity: String { get() { return underlying.mappingIdentity } }
    public prop byteLength: Int64 {
        get() {
            // Length is metadata, not a fabricated read of every character.
            // The index wakes these readers only when owner length changes.
            dependsOnLength = true
            return underlying.byteLength
        }
    }
    private func observe(start: Int64, end: Int64): Unit {
        if (start < 0 || end < start || end > underlying.byteLength) { throw IllegalArgumentException("Inline read out of range") }
        if (start < readStart) { readStart = start }
        if (end > readEnd) { readEnd = end }
    }
    public func readByte(offset: Int64): Byte { observe(offset, offset + 1); return underlying.readByte(offset) }
    public func readByteOrEnd(offset: Int64): ?Byte {
        if (offset == underlying.byteLength) { observe(offset, offset); return None }
        return Some(readByte(offset))
    }
    public func sliceBytes(start: Int64, end: Int64): String { observe(start, end); return underlying.sliceBytes(start, end) }
    public func runeOffsetAtByte(offset: Int64): Int64 { observe(offset, offset); return underlying.runeOffsetAtByte(offset) }
    public func mapByte(offset: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        observe(offset, offset); return underlying.mapByte(offset, affinity)
    }
}

public class InlineAttemptContext {
    private let observed: InlineObservedView
    private let semanticReads = ArrayList<IncrementalReadDependency>()
    public prop view: InlineTextView { get() { return observed } }
    public prop endByte: Int64 { get() { return observed.byteLength } }
    public InlineAttemptContext(view: InlineTextView, startByte: Int64, public let block: BlockEditingContext,
        public let owner: Int64, public let semanticOwner: Int64) {
        if (owner < 0 || semanticOwner < 0 || startByte < 0 || startByte > view.byteLength ||
            block.documentId != view.source.documentId || block.sourceVersion != view.source.version) {
            throw IllegalArgumentException("Foreign inline attempt context")
        }
        this.observed = InlineObservedView(view, startByte)
    }
    public func readSemantic(key: String): ?OwnedSemanticEffect {
        let value = block.effects.read(key, semanticOwner)
        // version stamps when this actual positive/negative observation was
        // made; winning-contribution invalidation remains the effect store's job.
        semanticReads.add(IncrementalReadDependency(owner.toString(), key, value.isSome(), view.source.version))
        return value
    }
    public func evidence(): InlineAttemptEvidence {
        return InlineAttemptEvidence(semanticReads.toArray(), observed.readStart, observed.readEnd,
            dependsOnLength: observed.dependsOnLength)
    }
    public func readByteOrEnd(offset: Int64): ?Byte { return observed.readByteOrEnd(offset) }
    public func retainFailedReads(): Unit {
        // Call after the failed candidate sandbox is gone: its state/writes
        // stay rolled back, but a missing key must still wake this attempt.
        for (read in semanticReads) { block.effects.read(read.key, semanticOwner) }
    }
}

public class InlineRecoveryContext {
    private let touched: Array<InlineAttemptRecord>
    public prop attempts: Array<InlineAttemptRecord> { get() { return touched.clone() } }
    public InlineRecoveryContext(attempts: Array<InlineAttemptRecord>, public let previous: InlineTextView,
        public let current: InlineTextView, public let change: InlineEditChange) {
        if (previous.source.documentId != current.source.documentId || current.source.version < previous.source.version ||
            change.oldEndByte > previous.byteLength || change.newEndByte > current.byteLength) {
            throw IllegalArgumentException("Invalid inline source transition")
        }
        this.touched = attempts.clone()
    }
}

public interface InlineEditingFacet <: IncrementalParserFacet {
    prop grammarVersion: String
    // Query context.endByte explicitly when grammar depends on owner length;
    // byte-oriented grammars can stop with readByteOrEnd without a global read.
    func parseAttempt(context: InlineAttemptContext, startByte: Int64): ?InlineParseResult
    // None is an unproved boundary, never an empty successful proof.
    func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow
    func leftContext(context: InlineAttemptContext, startByte: Int64): String
    func rightContext(context: InlineAttemptContext, endByte: Int64): String
}

public class InlineLiteralSplice {
    public InlineLiteralSplice(public let startByte: Int64, public let endByte: Int64, public let inserted: String) {
        if (startByte < 0 || endByte < startByte) { throw IllegalArgumentException("Invalid logical text splice") }
    }
}

public interface InlineLiteralFacet {
    prop grammarVersion: String
    func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow
    func decode(view: InlineTextView, startByte: Int64, endByte: Int64): String
    // The provider owns raw spelling for mapped/synthetic/decoded views.
    // Unknown providers cannot silently label logical view bytes as source raw.
    func payload(view: InlineTextView, startByte: Int64, endByte: Int64,
        block: BlockEditingContext): ?PersistentTextPayload { return None }
    // An explicit provider proof, never inferred from one equal-length sample.
    func offsetsFollowLiteral(view: InlineTextView): Bool { return false }
    // Raw-source coordinates are not logical view coordinates. The provider
    // owns this inverse projection, including gaps and mapped segments.
    func projectRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64
    // Literal and raw offsets can differ (e.g. escaping). Only the provider
    // can prove a local splice in the existing single logical Text payload.
    func splice(previous: PersistentTextPayload, context: InlineRecoveryContext): ?InlineLiteralSplice
}

// A provider proves that this edit changes only a recursive child's syntax.
// Parent typed fields, delimiters and external read dependencies must remain
// equivalent. None asks the ordinary recovery scheduler to retry the parent.
public interface InlineNestedProjection {
    func project(previous: InlineTextView, current: InlineTextView,
        change: InlineEditChange): ?InlineNestedProjectionResult
    // Re-project an unchanged child's immutable view after edits outside that
    // owner. The provider preserves local geometry and mapping identity.
    func rebase(child: InlineTextView, current: InlineTextView,
        block: BlockEditingContext): ?InlineNestedProjectionResult { return None }
}
public class InlineNestedProjectionResult {
    public InlineNestedProjectionResult(public let view: InlineTextView, public let change: InlineEditChange,
        public let projection: InlineNestedProjection) {}
}
public class InlineNestedOwner {
    public InlineNestedOwner(public let engine: InlineEditingSession, public let snapshot: InlineEditingSnapshot,
        public let projection: InlineNestedProjection) {}
}
