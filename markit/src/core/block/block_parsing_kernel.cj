package markit.core.block

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.SourceLine

public interface RestorableBlockState <: BlockState {
    func copyBlockState(): BlockState
    prop blockStateFingerprint: String
}

public class BlockKernelCheckpoint {
    internal let parser: ?ContinuationBlockParser
    internal let state: ?BlockState
    private let parserIdentity: ?Object
    private let grammarIdentity: String
    public let fingerprint: String
    public prop hasOpenFrame: Bool { get() { return parser.isSome() } }
    internal BlockKernelCheckpoint(parser: ?ContinuationBlockParser, state: ?BlockState, fingerprint: String) {
        this.parser = parser; this.state = state; this.fingerprint = fingerprint
        this.parserIdentity = if (let Some(value) <- parser) { value as Object } else { None }
        this.grammarIdentity = if (let Some(value) <- parser) {
            if (let Some(facet) <- value.incrementalFacet) {
                if (let Some(block) <- (facet as BlockEditingFacet)) { block.owner + ":" + block.grammarVersion }
                else { value.ownerPlugin + ":" + value.name }
            } else { value.ownerPlugin + ":" + value.name }
        } else { "closed" }
    }
    public func syntaxEquivalent(other: BlockKernelCheckpoint): Bool {
        if (grammarIdentity != other.grammarIdentity || fingerprint != other.fingerprint) { return false }
        if (parser.isNone() || other.parser.isNone()) { return parser.isNone() && other.parser.isNone() }
        if (parserIdentity.isNone() || other.parserIdentity.isNone()) { return false }
        return refEq(parserIdentity.getOrThrow(), other.parserIdentity.getOrThrow())
    }
    public func copyFrameState(): ?BlockState {
        if (let Some(value) <- state) {
            if (let Some(restorable) <- (value as RestorableBlockState)) { return Some(restorable.copyBlockState()) }
        }
        return None
    }
    public func withFrameState(value: RestorableBlockState): BlockKernelCheckpoint {
        return BlockKernelCheckpoint(parser, Some(value.copyBlockState()), value.blockStateFingerprint)
    }
}

// Append, detached parsing and editing recovery share this grammar dispatcher.
public class BlockParsingKernel {
    private let session: ParseSession
    private let continuations: ContinuationBlockDispatchTable
    private let leaves: BlockDispatchTable
    private let paragraphs: ArrayList<ParagraphBlockParser>
    private let trimNormalizedSpan: Bool
    private var sink: ?(Node) -> Unit = None
    private var openParser: ?ContinuationBlockParser = None
    private var openFrame: ?BlockFrame = None

    public BlockParsingKernel(session: ParseSession, continuations: ContinuationBlockDispatchTable,
        leaves: BlockDispatchTable, paragraphs: ArrayList<ParagraphBlockParser>,
        trimNormalizedSpan!: Bool = true) {
        this.session = session; this.continuations = continuations
        this.leaves = leaves; this.paragraphs = paragraphs
        this.trimNormalizedSpan = trimNormalizedSpan
    }
    public prop activeParser: ?ContinuationBlockParser { get() { return openParser } }
    public prop activeFrame: ?BlockFrame { get() { return openFrame } }
    public func checkpoint(): BlockKernelCheckpoint {
        if (let Some(frame) <- openFrame) {
            if (let Some(state) <- (frame.state as RestorableBlockState)) {
                return BlockKernelCheckpoint(openParser, Some(state.copyBlockState()), state.blockStateFingerprint)
            }
            throw IllegalArgumentException("Continuation frame has no state codec")
        }
        return BlockKernelCheckpoint(None, None, "closed")
    }
    public func restore(checkpoint: BlockKernelCheckpoint): Unit {
        var frame: ?BlockFrame = None
        if (let Some(value) <- checkpoint.state) {
            if (let Some(state) <- (value as RestorableBlockState)) {
                frame = Some(BlockFrame(state.copyBlockState()))
            } else { throw IllegalArgumentException("Checkpoint frame has no state codec") }
        }
        openParser = checkpoint.parser; openFrame = frame
    }
    public func setEmissionSink(emit: (Node) -> Unit): Unit { sink = Some(emit) }
    public func clearEmissionSink(): Unit { sink = None }
    private func append(node: Node): Unit { sink.getOrThrow()(node) }
    public func feed(line: SourceLine): Unit {
        session.beginLine(line)
        process(line.text)
    }
    public func finish(): Unit {
        if (let Some(parser) <- openParser) {
            if (let Some(frame) <- openFrame) { append(parser.finalize(session, frame)) }
            openParser = None; openFrame = None
        }
        if (!session.pendingParagraphLines.isEmpty()) {
            let last = session.pendingParagraphLines[session.pendingParagraphLines.size - 1]
            flush(if (last.terminated) { EndOfInputWithNewline } else { EndOfInput })
        }
    }
    private func flush(termination: ParagraphTermination): Unit {
        if (session.pendingParagraphLines.isEmpty()) { return }
        if (!paragraphs.isEmpty()) {
            let node = paragraphs[0].finalize(session, session.pendingParagraphLines,
                session.pendingParagraphSourceSpan(), termination)
            session.clearPendingParagraph()
            append(node)
            return
        }
        session.clearPendingParagraph()
    }
    private func process(line: String): Unit {
        if (let Some(parser) <- openParser) {
            if (let Some(frame) <- openFrame) {
                match (parser.continueBlock(session, frame, line)) {
                    case Open => return
                    case Closed =>
                        append(parser.finalize(session, frame)); openParser = None; openFrame = None; return
                    case ClosedAndReprocess =>
                        append(parser.finalize(session, frame)); openParser = None; openFrame = None
                        process(line); return
                }
            }
        }
        var at: Int64 = 0
        while (at < line.size && (line[at] == b' ' || line[at] == b'\t')) { at += 1 }
        let head: ?Byte = if (at < line.size) { Some(line[at]) } else { None }
        if (head.isNone()) { flush(BlankLine); return }
        for (parser in continuations.candidatesForFirstNonSpace(head)) {
            let started = if (session.editingContext.isSome()) { session.parserAttempt({ => parser.tryStart(session, line) }) }
                else { parser.tryStart(session, line) }
            if (let Some(frame) <- started) {
                flush(BlockBoundary); openParser = Some(parser); openFrame = Some(frame); return
            }
        }
        for (parser in leaves.candidatesForFirstNonSpace(head)) {
            let parsed = if (session.editingContext.isSome()) { session.parserAttempt({ => parser.tryParse(session, line) }) }
                else { parser.tryParse(session, line) }
            if (let Some(node) <- parsed) {
                flush(BlockBoundary); append(node); return
            }
        }
        if (paragraphs.isEmpty()) { return }
        let canStart = if (session.editingContext.isSome()) {
            session.parserAttempt({ =>
                if (paragraphs[0].canStart(session, line)) { Some(true) } else { Option<Bool>.None }
            }).isSome()
        } else { paragraphs[0].canStart(session, line) }
        if (canStart) {
            let normalized = paragraphs[0].normalizeLine(session, line)
            let delta = if (trimNormalizedSpan) { line.size - normalized.size } else { 0 }
            let span = session.currentLineSpan()
            session.addPendingParagraphLine(SourceLine(normalized,
                span.slice(delta, span.endByte - span.startByte, delta, span.endRune - span.startRune),
                terminated: session.currentSourceLine().terminated))
        }
    }
}
