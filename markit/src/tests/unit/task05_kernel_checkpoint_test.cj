package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.block.*
import markit.core.editing.*
import markit.core.nodes.Node
import markit.core.session.*
import markit.core.source.*

// This grammar belongs only to the directed kernel test. The product kernel
// knows none of these delimiters, node kinds or termination spellings.
private class KernelTestTrace {
    public let events = ArrayList<String>()
    public var boxObserved: Bool = false
}

private class KernelTestFrameState <: RestorableBlockState {
    public let nodeId: Int64
    public var content: String
    public var span: SourceSpan
    public init(nodeId: Int64, content: String, span: SourceSpan) {
        this.nodeId = nodeId; this.content = content; this.span = span
    }
    public func copyBlockState(): BlockState { return KernelTestFrameState(nodeId, content, span) }
    public prop blockStateFingerprint: String {
        get() { return "${nodeId}:${span.startByte}:${span.endByte}:${content}" }
    }
}

private class KernelTestContinuation <: ContinuationBlockParser {
    private let trace: KernelTestTrace
    public init(trace: KernelTestTrace) { this.trace = trace }
    public prop name: String { get() { return "kernel-test-container" } }
    public prop ownerPlugin: String { get() { return "kernel-test" } }
    public prop priority: Int64 { get() { return 0 } }
    public prop startBytes: Array<Byte> { get() { return [b'('] } }
    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (line != "(") { return None }
        return Some(BlockFrame(KernelTestFrameState(session.allocateNodeId(), "", session.currentLineSpan())))
    }
    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as KernelTestFrameState).getOrThrow()
        if (line.startsWith("!")) { return ClosedAndReprocess }
        state.span = state.span.merge(session.currentLineSpan())
        if (line == ")") { return Closed }
        state.content += if (state.content.isEmpty()) { line } else { "|" + line }
        return Open
    }
    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as KernelTestFrameState).getOrThrow()
        trace.events.add("finalize:${state.content}")
        return session.attachNode(Node("KernelBox", id: state.nodeId, sourceSpan: state.span, literal: state.content))
    }
}

private class KernelTestLeaf <: LeafBlockParser {
    private let trace: KernelTestTrace
    public init(trace: KernelTestTrace) { this.trace = trace }
    public prop name: String { get() { return "kernel-test-leaf" } }
    public prop ownerPlugin: String { get() { return "kernel-test" } }
    public prop priority: Int64 { get() { return 0 } }
    public prop startBytes: Array<Byte> { get() { return [b'!'] } }
    public prop acceptsAnyNonBlank: Bool { get() { return false } }
    public func tryParse(session: ParseSession, line: String): ?Node {
        if (!line.startsWith("!")) { return None }
        trace.events.add("leaf:${line}:${trace.boxObserved}")
        return Some(session.createNode("KernelLeaf", literal: line))
    }
}

private class KernelTestParagraph <: ParagraphBlockParser {
    public prop name: String { get() { return "kernel-test-paragraph" } }
    public prop ownerPlugin: String { get() { return "kernel-test" } }
    public func canStart(_: ParseSession, _: String): Bool { return true }
    public func normalizeLine(_: ParseSession, line: String): String { return line }
    public func finalize(session: ParseSession, lines: ArrayList<SourceLine>, sourceSpan: SourceSpan,
        termination: ParagraphTermination): Node {
        let parts = ArrayList<String>()
        for (line in lines) { parts.add(line.text) }
        let ending = match (termination) {
            case BlankLine => "blank"
            case BlockBoundary => "boundary"
            case EndOfInput => "eof"
            case EndOfInputWithNewline => "eof-newline"
        }
        return session.createNodeWithSpan("KernelParagraph", sourceSpan,
            literal: String.join(parts.toArray(), delimiter: "|"), info: ending)
    }
}

private class KernelTestRig {
    public let session: ParseSession
    public let kernel: BlockParsingKernel
    public let output: ArrayList<Node>
    public let trace: KernelTestTrace
    public init(input: String, editableSource!: ?EditableSourceVersion = None) {
        let source = SourceBuffer(retentionMode: SourceRetentionMode.Full, editableSource: editableSource)
        if (editableSource.isNone()) { source.append(input) }
        let parserSession = ParseSession(source, ParseOptions(), SessionSymbolTableStore(checkpointEnabled: true))
        parserSession.lineIndex.enablePersistent()
        if (let Some(view) <- editableSource) { parserSession.lineIndex.bindEditableSource(view) }
        let events = KernelTestTrace()
        let emitted = ArrayList<Node>()
        let continuations = ContinuationBlockDispatchTable()
        continuations.register(KernelTestContinuation(events))
        let leaves = BlockDispatchTable()
        leaves.register(KernelTestLeaf(events))
        let paragraphs = ArrayList<ParagraphBlockParser>()
        paragraphs.add(KernelTestParagraph())
        let parserKernel = BlockParsingKernel(parserSession, continuations, leaves, paragraphs)
        parserKernel.setEmissionSink({ node: Node =>
            emitted.add(node)
            events.events.add("emit:${node.kind}")
            if (node.kind == "KernelBox") { events.boxObserved = true }
        })
        session = parserSession; kernel = parserKernel; output = emitted; trace = events
    }
    public func feed(text: String, start: Int64, terminated!: Bool = true): Unit {
        let line = SourceLine(text, SourceSpan(start, start + text.size, start, start + text.size), terminated: terminated)
        session.recordSourceLine(line)
        kernel.feed(line)
    }
}

// Provider-owned frame geometry is explicitly mapped through raw source
// anchors. Core does not guess which fields in an opaque frame are positions.
private func kernelMappedSpan(store: EditableRopeStore, origin: SourceVersionIdentity, span: SourceSpan): SourceSpan {
    let target = store.current
    let start = store.resolve(SourceAnchor(origin, span.startByte, affinity: AnchorAffinity.Before), target.identity.version).getOrThrow()
    let end = store.resolve(SourceAnchor(origin, span.endByte, affinity: AnchorAffinity.After), target.identity.version).getOrThrow()
    return SourceSpan(start, end, target.coordinateAtByte(start).getOrThrow().runeOffset,
        target.coordinateAtByte(end).getOrThrow().runeOffset)
}

@Test
@Tag[BlockEditing, KernelCheckpoint]
class Task05KernelCheckpointTests {
    @TestCase
    func crossVersionOpenFrameMapsProviderGeometryBeforeResumingAtNewSource() {
        let text = "prefix\n(\nkept\nfinal\n)\n"
        let source = EditableRopeStore("kernel-geometry", text: text)
        let old = source.snapshot
        let rig = KernelTestRig(text, editableSource: Some(old))
        rig.kernel.feed(rig.session.lineIndex.lineAt(1))
        rig.kernel.feed(rig.session.lineIndex.lineAt(2))
        let syntax = rig.session.checkpoint()
        let frame = rig.kernel.checkpoint()
        @Expect(frame.hasOpenFrame, true)
        let oldFrame = (frame.copyFrameState().getOrThrow() as KernelTestFrameState).getOrThrow()
        @Expect(oldFrame.span.startByte, 7)
        @Expect(oldFrame.span.startRune, 7)
        // Nine UTF-8 bytes and three runes replace six ASCII bytes/runes, so
        // source byte and raw-rune deltas differ (+3 and -3 respectively).
        source.applyEdits(0, [EditingTextEdit(EditingRange(0, 6), "\u{5BBD}\u{524D}\u{7F00}")])
        rig.session.source.bindEditableSource(source.current)
        @Expect(rig.session.restoreEditingCheckpoint(syntax, remapLine: Some({ line: SourceLine, _: Bool =>
            let mapped = kernelMappedSpan(source, old.identity, line.span)
            SourceLine(source.current.sliceBytes(mapped.startByte, mapped.endByte), mapped, terminated: line.terminated)
        })), true)
        rig.session.lineIndex.bindEditableSource(source.current)
        let mappedFrame = (frame.copyFrameState().getOrThrow() as KernelTestFrameState).getOrThrow()
        mappedFrame.span = kernelMappedSpan(source, old.identity, mappedFrame.span)
        @Expect(mappedFrame.span.startByte, 10)
        @Expect(mappedFrame.span.startRune, 4)
        @Expect(mappedFrame.span.endByte, 16)
        @Expect(mappedFrame.span.endRune, 10)
        rig.kernel.restore(frame.withFrameState(mappedFrame))
        @Expect(rig.session.currentSourceLine().text, "kept")
        @Expect(rig.session.currentLineSpan().startByte, 12)
        @Expect(rig.session.currentLineSpan().startRune, 6)
        @Expect(rig.session.lineIndex.lineAt(1).span.startByte, 10)
        rig.kernel.feed(rig.session.lineIndex.lineAt(3))
        rig.kernel.feed(rig.session.lineIndex.lineAt(4))
        rig.kernel.finish()
        let fresh = KernelTestRig("", editableSource: Some(source.current))
        for (line in 1..5) { fresh.kernel.feed(fresh.session.lineIndex.lineAt(line)) }
        fresh.kernel.finish()
        @Expect(rig.output.size, 1)
        @Expect(rig.output[0].literal, fresh.output[0].literal)
        @Expect(rig.output[0].literal, "kept|final")
        @Expect(rig.output[0].id, fresh.output[0].id)
        @Expect(rig.output[0].sourceSpan.startByte, fresh.output[0].sourceSpan.startByte)
        @Expect(rig.output[0].sourceSpan.endByte, fresh.output[0].sourceSpan.endByte)
        @Expect(rig.output[0].sourceSpan.startRune, fresh.output[0].sourceSpan.startRune)
        @Expect(rig.output[0].sourceSpan.endRune, fresh.output[0].sourceSpan.endRune)
        @Expect(rig.output[0].sourceSpan.endByte, 24)
        @Expect(rig.output[0].sourceSpan.endRune, 18)
        // A detached checkpoint still owns the old geometry after remapping.
        @Expect((frame.copyFrameState().getOrThrow() as KernelTestFrameState).getOrThrow().span.startByte, 7)
    }

    @TestCase
    func openFrameAndSessionCheckpointRestoreMutableStateWithoutAliasing() {
        let rig = KernelTestRig("(\nkept\nfinal\n)\n")
        rig.feed("(", 0)
        rig.feed("kept", 2)
        let syntax = rig.session.checkpoint()
        let frame = rig.kernel.checkpoint()
        let fingerprint = frame.fingerprint
        rig.feed("discard", 7)
        rig.feed(")", 15)
        @Expect(rig.output[0].literal, "kept|discard")
        rig.session.allocateNodeId()
        @Expect(rig.session.restoreCheckpoint(syntax), true)
        rig.kernel.restore(frame)
        rig.output.clear()
        @Expect(rig.session.currentSourceLine().text, "kept")
        @Expect(rig.session.lineIndex.size, 2)
        @Expect(rig.session.nextNodeId, syntax.nextNodeId)
        @Expect(rig.kernel.checkpoint().fingerprint, fingerprint)
        rig.feed("final", 7)
        rig.feed(")", 13)
        rig.kernel.finish()
        let fresh = KernelTestRig("(\nkept\nfinal\n)\n")
        fresh.feed("(", 0); fresh.feed("kept", 2); fresh.feed("final", 7); fresh.feed(")", 13)
        fresh.kernel.finish()
        @Expect(rig.output.size, fresh.output.size)
        @Expect(rig.output[0].literal, fresh.output[0].literal)
        @Expect(rig.output[0].id, fresh.output[0].id)
        @Expect(rig.output[0].sourceSpan.startByte, fresh.output[0].sourceSpan.startByte)
        @Expect(rig.output[0].sourceSpan.endByte, fresh.output[0].sourceSpan.endByte)
        @Expect(rig.session.nextNodeId, fresh.session.nextNodeId)
        // Restoring the same checkpoint again proves the live resumed frame
        // did not mutate the captured provider-state copy.
        @Expect(rig.session.restoreCheckpoint(syntax), true)
        rig.kernel.restore(frame)
        @Expect(rig.kernel.checkpoint().fingerprint, fingerprint)
        @Expect((rig.kernel.activeFrame.getOrThrow().state as KernelTestFrameState).getOrThrow().content, "kept")
    }

    @TestCase
    func closedAndReprocessEmitsBeforeParsingTheSameLineAsALeaf() {
        let rig = KernelTestRig("(\nbody\n!tail\n")
        rig.feed("(", 0); rig.feed("body", 2); rig.feed("!tail", 7)
        rig.kernel.finish()
        @Expect(rig.output.size, 2)
        @Expect(rig.output[0].kind, "KernelBox")
        @Expect(rig.output[0].literal, "body")
        @Expect(rig.output[0].sourceSpan.endByte, 6)
        @Expect(rig.output[1].kind, "KernelLeaf")
        @Expect(rig.output[1].sourceSpan.startByte, 7)
        @Expect(rig.trace.events.size, 4)
        @Expect(rig.trace.events[0], "finalize:body")
        @Expect(rig.trace.events[1], "emit:KernelBox")
        @Expect(rig.trace.events[2], "leaf:!tail:true")
        @Expect(rig.trace.events[3], "emit:KernelLeaf")
        @Expect(rig.kernel.activeFrame.isNone(), true)
    }

    @TestCase
    func pendingParagraphRecoveryAbsorbsEarlierLinesAndMatchesFreshAtEof() {
        let rig = KernelTestRig("first\nsecond")
        rig.feed("first", 0)
        let syntax = rig.session.checkpoint()
        let frame = rig.kernel.checkpoint()
        rig.feed("discard", 6)
        rig.feed("", 14)
        @Expect(rig.output[0].info, "blank")
        @Expect(rig.session.restoreCheckpoint(syntax), true)
        rig.kernel.restore(frame)
        rig.output.clear()
        @Expect(rig.session.pendingParagraphLines.size, 1)
        @Expect(rig.session.pendingParagraphSourceSpan().startByte, 0)
        rig.feed("second", 6, terminated: false)
        rig.kernel.finish()
        let fresh = KernelTestRig("first\nsecond")
        fresh.feed("first", 0); fresh.feed("second", 6, terminated: false); fresh.kernel.finish()
        @Expect(rig.output.size, 1)
        @Expect(rig.output[0].literal, "first|second")
        @Expect(rig.output[0].literal, fresh.output[0].literal)
        @Expect(rig.output[0].info, "eof")
        @Expect(rig.output[0].id, fresh.output[0].id)
        @Expect(rig.output[0].sourceSpan.startByte, 0)
        @Expect(rig.output[0].sourceSpan.endByte, 12)
        @Expect(rig.session.pendingParagraphLines.isEmpty(), true)
    }

    @TestCase
    func finishSealsAnOpenFrameAndPreservesParagraphNewlineTermination() {
        let open = KernelTestRig("(\nopen")
        open.feed("(", 0); open.feed("open", 2, terminated: false)
        @Expect(open.output.size, 0)
        open.kernel.finish()
        @Expect(open.output.size, 1)
        @Expect(open.output[0].kind, "KernelBox")
        @Expect(open.output[0].literal, "open")
        @Expect(open.output[0].sourceSpan.endByte, 6)
        @Expect(open.kernel.activeFrame.isNone(), true)
        open.kernel.finish()
        @Expect(open.output.size, 1)
        let paragraph = KernelTestRig("last\n")
        paragraph.feed("last", 0)
        paragraph.kernel.finish()
        @Expect(paragraph.output.size, 1)
        @Expect(paragraph.output[0].info, "eof-newline")
        @Expect(paragraph.output[0].literal, "last")
        @Expect(paragraph.session.pendingParagraphLines.isEmpty(), true)
    }
}
