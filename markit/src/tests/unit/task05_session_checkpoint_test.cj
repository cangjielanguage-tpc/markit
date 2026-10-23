package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.nodes.Node
import markit.core.source.{SourceBuffer, SourceLine, SourceSpan}
import markit.core.session.{ParseOptions, ParseSession, SessionState, SessionStatePayload,
    SessionStateSnapshot, RestorableSessionStateSnapshot, SessionSymbolTableStore,
    ParseSessionTransactionParticipant, ParseSessionTransactionScope}
import markit.core.editing.{IncrementalParserContext, IncrementalStatePayload}

private class CheckpointCounterPayload <: SessionStatePayload {
    public let value: Int64
    public init(value: Int64) { this.value = value }
    public prop fingerprint: String { get() { return "value:${value}" } }
    public func detachedCopy(): SessionStatePayload { return CheckpointCounterPayload(value) }
}

private class CheckpointRestoreControl {
    public var refuse: Bool = false
    public var snapshots: Int64 = 0
}
private class CheckpointProbeControl {
    public var invoked: Bool = false
    public var trace: String = ""
}

private class CheckpointCounterState <: SessionState {
    public var value: Int64 = 0
    private let control: CheckpointRestoreControl
    private let stateName: String
    public init(control!: CheckpointRestoreControl = CheckpointRestoreControl(), name!: String = "checkpoint.counter") {
        this.control = control
        this.stateName = name
    }
    public func reset(): Unit { value = 0 }
    public func snapshot(): SessionStateSnapshot {
        control.snapshots += 1
        return RestorableSessionStateSnapshot(stateName, 0, "root", CheckpointCounterPayload(value))
    }
    public prop supportsStateRestore: Bool { get() { return true } }
    public func restoreSnapshot(snapshot: SessionStateSnapshot): Bool {
        if (control.refuse || snapshot.dynamicName != stateName || snapshot.sourceVersion != 0 ||
            snapshot.contextFingerprint != "root") { return false }
        if (let Some(payload) <- snapshot.payloadCopy()) {
            if (let counter: CheckpointCounterPayload <- payload) { value = counter.value; return true }
        }
        return false
    }
}

private class CheckpointLegacyState <: SessionState {
    public func reset(): Unit {}
    public func snapshot(): SessionStateSnapshot { return SessionStateSnapshot("checkpoint.legacy") }
}

private class CheckpointContextPayload <: IncrementalStatePayload {
    public let value: Int64
    public init(value: Int64) { this.value = value }
    public func fingerprint(): String { return "context:${value}" }
    public func clonePayload(): IncrementalStatePayload { return CheckpointContextPayload(value) }
}

private class CheckpointContextScope <: ParseSessionTransactionScope {
    private let context: CheckpointEditingContext
    private let value: Int64
    public init(context: CheckpointEditingContext) { this.context = context; value = context.value }
    public func complete(commit: Bool): Unit {
        if (commit && context.rejectCommit) { throw IllegalArgumentException("injected scope commit refusal") }
        if (!commit) { context.value = value }
    }
}

private class CheckpointEditingContext <: IncrementalParserContext & ParseSessionTransactionParticipant {
    public var value: Int64 = 1
    public var rejectCommit: Bool = false
    public prop documentId: String { get() { return "checkpoint" } }
    public prop sourceVersion: Int64 { get() { return 0 } }
    public func readState(_: String): ?IncrementalStatePayload { return Some(CheckpointContextPayload(value)) }
    public func writeState(_: String, payload: IncrementalStatePayload): Bool {
        if (let counter: CheckpointContextPayload <- payload) { value = counter.value; return true }
        return false
    }
    public func revokeOwnerEffects(_: String): Bool { value += 1; return true }
    public func beginSessionScope(): ParseSessionTransactionScope { return CheckpointContextScope(this) }
}

private func checkpointLine(text: String, start: Int64): SourceLine {
    return SourceLine(text, SourceSpan(start, start + text.size, start, start + text.size), terminated: true)
}

private func checkpointSession(control!: CheckpointRestoreControl = CheckpointRestoreControl()): ParseSession {
    let symbols = SessionSymbolTableStore(checkpointEnabled: true)
    symbols.registerErased("checkpoint.counter", { => CheckpointCounterState(control: control) })
    return ParseSession(SourceBuffer(), ParseOptions(), symbols)
}

private func checkpointCounter(session: ParseSession): CheckpointCounterState {
    return (session.symbolTables.get("checkpoint.counter").getOrThrow() as CheckpointCounterState).getOrThrow()
}

@Test
@Tag[BlockEditing, SessionCheckpoint]
class Task05SessionCheckpointTests {
    @TestCase
    func editingCheckpointAndWorkspaceReleaseDoNotPinOrMutateTheInitialLegacyGraph() {
        let session = checkpointSession()
        session.source.append("source")
        session.beginLine(checkpointLine("outer", 0))
        session.addPendingParagraphLine(session.currentSourceLine())
        session.root.setString("root-field", "preserved")
        let oldRoot = session.root
        oldRoot.addChild(session.createNode("Initial"))
        checkpointCounter(session).value = 7
        let currentContext = CheckpointEditingContext()
        session.editingContext = Some(currentContext)
        let saved = session.checkpoint()
        session.parserAttempt<Node>({ =>
            session.editingContext = None
            Option<Node>.None
        })
        @Expect(refEq((session.editingContext.getOrThrow() as CheckpointEditingContext).getOrThrow(), currentContext), true)
        // Capturing an editing checkpoint did not change the live working root.
        @Expect(refEq(session.root, oldRoot), true)
        @Expect(oldRoot.children.size, 1)
        let late = session.createNode("Later")
        oldRoot.addChild(late)
        session.patches.replace(late)
        let oldQueue = session.patches
        checkpointCounter(session).value = 99
        let highWater = session.nextNodeId
        session.releaseEditingWorkspace()
        @Expect(refEq(session.root, oldRoot), false)
        @Expect(session.root.children.isEmpty(), true)
        @Expect(session.root.string("root-field"), Some("preserved"))
        @Expect(session.nextNodeId, highWater)
        @Expect(checkpointCounter(session).value, 99)
        @Expect(session.pendingParagraphLines.size, 1)
        @Expect(session.currentSourceLine().text, "outer")
        @Expect(session.source.byteSize, 6)
        @Expect(oldRoot.children.size, 2)
        @Expect(session.restoreCheckpoint(saved), true)
        @Expect(session.editingContext.isNone(), true)
        @Expect(refEq(session.root, oldRoot), false)
        @Expect(session.root.children.isEmpty(), true)
        @Expect(session.root.string("root-field"), Some("preserved"))
        @Expect(session.nextNodeId, saved.nextNodeId)
        @Expect(checkpointCounter(session).value, 7)
        @Expect(session.patches.isEmpty(), true)
        // The checkpoint keeps its own queue snapshot, not a mutable wrapper
        // that later grows to reference the remainder of the initial graph.
        @Expect(oldQueue.drainReplaceNodes()[0].id, late.id)
        @Expect(oldRoot.children.size, 2)
        session.editingContext = Some(currentContext)
        @Expect(session.restoreEditingCheckpoint(saved), true)
        @Expect(refEq((session.editingContext.getOrThrow() as CheckpointEditingContext).getOrThrow(), currentContext), true)
        let legacy = ParseSession(SourceBuffer(), ParseOptions(), SessionSymbolTableStore())
        legacy.root.addChild(Node("Legacy", id: 200))
        var rejected = false
        try { legacy.releaseEditingWorkspace() } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(legacy.root.children.size, 1)
    }

    @TestCase
    func editingRestoreRemapsActiveAndPendingGeometryWithoutChangingSavedCheckpoint() {
        let session = checkpointSession()
        let first = checkpointLine("left", 10)
        let second = checkpointLine("right", 20)
        session.addPendingParagraphLine(first)
        session.addPendingParagraphLine(second)
        session.beginLine(checkpointLine("active", 30))
        checkpointCounter(session).value = 7
        let saved = session.checkpoint()
        checkpointCounter(session).value = 99
        session.clearPendingParagraph()
        session.beginLine(checkpointLine("live", 100))
        let calls = CheckpointProbeControl()
        @Expect(session.restoreEditingCheckpoint(saved, remapLine: Some({ line: SourceLine, pending: Bool =>
            calls.trace += if (pending) { "pending;" } else { "active;" }
            let text = if (pending) { line.text } else { "fresh" }
            let span = SourceSpan(line.span.startByte + 8, line.span.startByte + 8 + text.size,
                line.span.startRune + 4, line.span.startRune + 4 + text.size)
            SourceLine(text, span, terminated: line.terminated)
        })), true)
        @Expect(calls.trace, "active;pending;pending;")
        @Expect(session.currentSourceLine().text, "fresh")
        @Expect(session.currentLineSpan().startByte, 38)
        @Expect(session.currentLineSpan().startRune, 34)
        @Expect(session.pendingParagraphLines.size, 2)
        @Expect(session.pendingParagraphLines[0].text, "left")
        @Expect(session.pendingParagraphLines[1].text, "right")
        @Expect(session.pendingParagraphSourceSpan().startByte, 18)
        @Expect(session.pendingParagraphSourceSpan().endByte, 33)
        @Expect(session.pendingParagraphSourceSpan().startRune, 14)
        @Expect(session.pendingParagraphSourceSpan().endRune, 29)
        @Expect(checkpointCounter(session).value, 7)
        // A remapped restoration never mutates the reusable source checkpoint.
        @Expect(session.restoreEditingCheckpoint(saved), true)
        @Expect(session.currentSourceLine().text, "active")
        @Expect(session.currentLineSpan().startByte, 30)
        @Expect(session.pendingParagraphSourceSpan().startByte, 10)
        @Expect(session.pendingParagraphSourceSpan().endByte, 25)
    }

    @TestCase
    func mapperFailureChangedPendingAndInvalidSpanCannotPartiallyRestoreLiveSession() {
        let session = checkpointSession()
        session.beginLine(checkpointLine("old", 0))
        session.addPendingParagraphLine(checkpointLine("first", 10))
        session.addPendingParagraphLine(checkpointLine("second", 20))
        checkpointCounter(session).value = 3
        let saved = session.checkpoint()
        session.clearPendingParagraph()
        let live = checkpointLine("live", 100)
        session.beginLine(live)
        session.addPendingParagraphLine(live)
        session.recordSourceLine(live)
        checkpointCounter(session).value = 9
        session.setNextNodeIdForEditing(100)
        let liveNode = session.createNode("Live")
        session.root.addChild(liveNode)
        session.patches.replace(liveNode)
        session.finalized = true
        session.setTopLevelIndentedBlockStartsAllowed(true)
        let liveRoot = session.root
        let liveState = checkpointCounter(session)
        let liveId = session.nextNodeId
        let liveFingerprint = session.checkpoint().syntaxFingerprint
        let calls = CheckpointProbeControl()
        var rejected = false
        try {
            session.restoreEditingCheckpoint(saved, remapLine: Some({ line: SourceLine, pending: Bool =>
                calls.trace += if (pending) { "pending;" } else { "active;" }
                if (pending && line.span.startByte == 20) { throw IllegalArgumentException("injected mapping failure") }
                SourceLine(line.text, SourceSpan(line.span.startByte + 5, line.span.endByte + 5,
                    line.span.startRune + 5, line.span.endRune + 5), terminated: line.terminated)
            }))
        } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(calls.trace, "active;pending;pending;")
        @Expect(session.checkpoint().syntaxFingerprint, liveFingerprint)
        @Expect(refEq(session.root, liveRoot), true)
        @Expect(refEq(checkpointCounter(session), liveState), true)
        @Expect(checkpointCounter(session).value, 9)
        @Expect(session.nextNodeId, liveId)
        @Expect(session.root.children.size, 1)
        @Expect(session.lineIndex.lineAt(0).text, "live")
        rejected = false
        try {
            session.restoreEditingCheckpoint(saved, remapLine: Some({ line: SourceLine, pending: Bool =>
                SourceLine(if (pending) { "changed" } else { line.text }, line.span, terminated: line.terminated)
            }))
        } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try {
            session.restoreEditingCheckpoint(saved, remapLine: Some({ line: SourceLine, _: Bool =>
                SourceLine(line.text, SourceSpan(-1, 1, 0, 1), terminated: line.terminated)
            }))
        } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(session.checkpoint().syntaxFingerprint, liveFingerprint)
        @Expect(refEq(session.root, liveRoot), true)
        @Expect(refEq(checkpointCounter(session), liveState), true)
        @Expect(checkpointCounter(session).value, 9)
        @Expect(session.nextNodeId, liveId)
        @Expect(session.patches.drainReplaceNodes()[0].id, liveNode.id)
    }

    @TestCase
    func realCandidateFailureRollsBackBeforeNextCandidateAndOnlyClonesTouchedStates() {
        let control = CheckpointRestoreControl()
        let unread = CheckpointRestoreControl()
        let session = checkpointSession(control: control)
        session.symbolTables.registerErased("checkpoint.unread", { =>
            CheckpointCounterState(control: unread, name: "checkpoint.unread")
        })
        session.beginLine(checkpointLine("outer", 0))
        session.addPendingParagraphLine(session.currentSourceLine())
        let oldRoot = session.root
        oldRoot.addChild(session.createNode("Existing"))
        let beforeId = session.nextNodeId
        let context = CheckpointEditingContext()
        session.editingContext = Some(context)
        let calls = CheckpointProbeControl()
        let declined = session.parserAttempt<Node>({ =>
            calls.trace += "failed;"
            checkpointCounter(session).value = 100
            context.value = 99
            let node = session.createNode("Declined")
            session.root.addChild(node)
            session.patches.replace(node)
            session.clearPendingParagraph()
            Option<Node>.None
        })
        @Expect(declined.isNone(), true)
        @Expect(session.nextNodeId, beforeId)
        @Expect(checkpointCounter(session).value, 0)
        @Expect(context.value, 1)
        @Expect(session.pendingParagraphLines.size, 1)
        @Expect(session.patches.isEmpty(), true)
        @Expect(refEq(session.root, oldRoot), true)
        @Expect(session.root.children.size, 1)
        let accepted = session.parserAttempt<Node>({ =>
            calls.trace += "accepted;"
            @Expect(checkpointCounter(session).value, 0)
            checkpointCounter(session).value = 1
            context.value = 7
            let node = session.createNode("Accepted")
            session.patches.replace(node)
            Some(node)
        }).getOrThrow()
        @Expect(calls.trace, "failed;accepted;")
        @Expect(accepted.id, beforeId)
        @Expect(session.nextNodeId, beforeId + 1)
        @Expect(checkpointCounter(session).value, 1)
        @Expect(context.value, 7)
        @Expect(refEq(session.root, oldRoot), true)
        @Expect(session.root.children.size, 1)
        @Expect(control.snapshots, 2)
        @Expect(unread.snapshots, 0)
        var thrown = false
        try {
            session.parserAttempt<Node>({ =>
                checkpointCounter(session).value = 500
                context.value = 500
                session.patches.remove(session.createNode("Thrown"))
                throw IllegalArgumentException("candidate failure")
            })
        } catch (_: IllegalArgumentException) { thrown = true }
        @Expect(thrown, true)
        @Expect(session.nextNodeId, beforeId + 1)
        @Expect(checkpointCounter(session).value, 1)
        @Expect(context.value, 7)
        @Expect(session.patches.drainRemoveNodes().isEmpty(), true)
        @Expect(session.patches.drainReplaceNodes()[0].id, accepted.id)
    }

    @TestCase
    func legacyScratchCursorRefusesAForwardRestoreWhoseChildrenWereRemoved() {
        let session = checkpointSession()
        session.beginLine(checkpointLine("old", 0))
        session.root.addChild(session.createNode("First"))
        let early = session.checkpoint()
        session.root.addChild(session.createNode("Second"))
        checkpointCounter(session).value = 2
        let later = session.checkpoint()
        @Expect(session.restoreCheckpoint(early), true)
        @Expect(session.root.children.size, 1)
        @Expect(session.restoreCheckpoint(later), false)
        @Expect(session.root.children.size, 1)
        @Expect(checkpointCounter(session).value, 0)
    }

    @TestCase
    func editingRecoveryPointsNeverTruncateEarlierOrLaterPublishedSiblings() {
        let session = checkpointSession()
        session.beginLine(checkpointLine("old", 0))
        let published = session.root
        let left = session.createNode("Left")
        left.setString("kept", "metadata")
        left.setRawContent("left raw")
        published.addChild(left)
        let early = session.checkpoint()
        published.addChild(session.createNode("Middle"))
        let later = session.checkpoint()
        published.addChild(session.createNode("Right"))
        let rollback = session.checkpoint()
        @Expect(session.restoreEditingCheckpoint(early), true)
        @Expect(refEq(session.root, published), false)
        @Expect(session.root.children.isEmpty(), true)
        @Expect(published.children.size, 3)
        session.root.addChild(session.createNode("Temporary"))
        @Expect(session.restoreEditingCheckpoint(later), true)
        @Expect(session.root.children.isEmpty(), true)
        @Expect(published.children.size, 3)
        @Expect(left.string("kept"), Some("metadata"))
        @Expect(left.rawContent(), "left raw")
        @Expect(session.restoreCheckpoint(rollback), true)
        @Expect(refEq(session.root, published), true)
        @Expect(session.root.children.size, 3)
        @Expect(session.root.children[0].id, left.id)
        @Expect(checkpointSession().restoreEditingCheckpoint(early), false)
    }

    @TestCase
    func nestedParticipantCommitFailureAlsoDiscardsSuccessfulParserResults() {
        let session = checkpointSession()
        session.beginLine(checkpointLine("outer", 0))
        session.addPendingParagraphLine(session.currentSourceLine())
        let context = CheckpointEditingContext()
        context.rejectCommit = true
        session.editingContext = Some(context)
        let saved = session.checkpoint()
        session.setDetachedBlockParser({ _: ArrayList<SourceLine> =>
            checkpointCounter(session).value = 100
            context.value = 99
            session.beginLine(checkpointLine("inner", 20))
            let node = session.createNode("Nested")
            session.patches.replace(node)
            session.root.addChild(node)
            ArrayList<Node>()
        }, sandboxedStates: true)
        var rejected = false
        try { session.parseDetachedLines(ArrayList<SourceLine>()) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(context.value, 1)
        @Expect(checkpointCounter(session).value, 0)
        @Expect(session.nextNodeId, saved.nextNodeId)
        @Expect(session.checkpoint().syntaxFingerprint, saved.syntaxFingerprint)
        @Expect(session.patches.isEmpty(), true)
        @Expect(session.root.children.isEmpty(), true)
    }

    @TestCase
    func transactionParticipantRollsBackProbeEffectsAndCommitsOnlySuccessfulNestedEffects() {
        let session = checkpointSession()
        session.beginLine(checkpointLine("outer", 0))
        let context = CheckpointEditingContext()
        session.editingContext = Some(context)
        @Expect(session.sandboxProbe({ =>
            session.editingContext.getOrThrow().writeState("key", CheckpointContextPayload(9))
            session.editingContext.getOrThrow().revokeOwnerEffects("owner")
            true
        }), true)
        @Expect(context.value, 1)
        session.setDetachedBlockParser({ _: ArrayList<SourceLine> =>
            session.editingContext.getOrThrow().writeState("key", CheckpointContextPayload(7))
            ArrayList<Node>()
        }, sandboxedStates: true)
        session.parseDetachedLines(ArrayList<SourceLine>())
        @Expect(context.value, 7)
        session.setDetachedBlockParser({ _: ArrayList<SourceLine> =>
            session.editingContext.getOrThrow().writeState("key", CheckpointContextPayload(10))
            throw IllegalArgumentException("effect failure")
        }, sandboxedStates: true)
        try { session.parseDetachedLines(ArrayList<SourceLine>()) } catch (_: IllegalArgumentException) {}
        @Expect(context.value, 7)
    }

    @TestCase
    func completeCheckpointRestoresPendingActiveAllocatorAndPersistentLineRoots() {
        let session = checkpointSession()
        let outer = checkpointLine("outer", 10)
        session.beginLine(outer)
        session.recordSourceLine(outer)
        session.addPendingParagraphLine(outer)
        checkpointCounter(session).value = 7
        let queued = session.createNode("Test", literal: "queued")
        session.patches.replace(queued)
        let first = session.checkpoint()
        let later = checkpointLine("later", 20)
        session.beginLine(later)
        session.recordSourceLine(later)
        session.addPendingParagraphLine(later)
        checkpointCounter(session).value = 99
        session.allocateNodeId()
        session.finalized = true
        session.setTopLevelIndentedBlockStartsAllowed(true)
        session.patches.drainReplaceNodes()
        let second = session.checkpoint()
        @Expect(session.restoreCheckpoint(first), true)
        @Expect(session.currentSourceLine().text, "outer")
        @Expect(session.pendingParagraphLines.size, 1)
        @Expect(session.pendingParagraphSourceSpan().startByte, 10)
        @Expect(session.lineIndex.size, 1)
        @Expect(session.lineIndex.lineAt(0).text, "outer")
        @Expect(session.nextNodeId, first.nextNodeId)
        @Expect(checkpointCounter(session).value, 7)
        @Expect(session.finalized, false)
        @Expect(session.allowDeepIndentedBlockStart(), false)
        @Expect(session.patches.drainReplaceNodes()[0].id, queued.id)
        // A checkpoint remains valid after restoring an older root, including
        // its later line index and a drained patch queue.
        @Expect(session.restoreCheckpoint(second), true)
        @Expect(session.lineIndex.size, 2)
        @Expect(session.lineIndex.lineAt(1).text, "later")
        @Expect(checkpointCounter(session).value, 99)
        @Expect(session.finalized, true)
        @Expect(session.restoreCheckpoint(first), true)
        @Expect(session.checkpoint().syntaxFingerprint, first.syntaxFingerprint)
    }

    @TestCase
    func repeatedSuccessfulAndFailedProbesDoNotPublishStateIdsPatchesOrRootAppends() {
        let session = checkpointSession()
        let outer = checkpointLine("outer", 0)
        session.beginLine(outer)
        session.addPendingParagraphLine(outer)
        checkpointCounter(session).value = 4
        let oldRoot = session.root
        let oldChild = session.createNode("Existing", literal: "kept")
        oldChild.setString("field", "original")
        oldChild.setInt("field", 11)
        oldChild.setBool("field", true)
        oldChild.setRawContent("original raw")
        oldRoot.addChild(oldChild)
        session.patches.replace(oldChild)
        let originalState = checkpointCounter(session)
        let beforeId = session.nextNodeId
        for (outcome in [false, true, false]) {
            @Expect(session.sandboxProbe({ =>
                @Expect(session.pendingParagraphLines.size, 1)
                @Expect(refEq(session.root, oldRoot), false)
                @Expect(session.root.children.isEmpty(), true)
                @Expect(session.patches.isEmpty(), true)
                session.root.setString("field", "temporary")
                session.root.setInt("field", 22)
                session.root.setBool("field", false)
                session.root.setRawContent("temporary raw")
                checkpointCounter(session).value = 100
                session.clearPendingParagraph()
                session.beginLine(checkpointLine("probe", 30))
                let node = session.createNode("Probe")
                session.root.addChild(node)
                session.patches.replace(node)
                session.recordSourceLine(checkpointLine("probe", 30))
                outcome
            }), outcome)
            @Expect(session.nextNodeId, beforeId)
            @Expect(refEq(session.root, oldRoot), true)
            @Expect(session.root.children.size, 1)
            @Expect(refEq(session.root.children[0], oldChild), true)
            @Expect(oldChild.string("field"), Some("original"))
            @Expect(oldChild.int("field"), Some(11))
            @Expect(oldChild.bool("field"), Some(true))
            @Expect(oldChild.sourceSpan.startByte, 0)
            @Expect(oldChild.sourceSpan.endByte, 5)
            @Expect(oldChild.rawContent(), "original raw")
            @Expect(session.patches.drainReplaceNodes()[0].id, oldChild.id)
            session.patches.replace(oldChild)
            @Expect(session.lineIndex.size, 0)
            @Expect(session.pendingParagraphLines.size, 1)
            @Expect(session.currentSourceLine().text, "outer")
            @Expect(checkpointCounter(session).value, 4)
            @Expect(refEq(checkpointCounter(session), originalState), true)
        }
        var thrown = false
        try {
            session.sandboxProbe({ =>
                checkpointCounter(session).value = 200
                session.allocateNodeId()
                throw IllegalArgumentException("injected probe failure")
            })
        } catch (_: IllegalArgumentException) { thrown = true }
        @Expect(thrown, true)
        @Expect(session.nextNodeId, beforeId)
        @Expect(checkpointCounter(session).value, 4)
    }

    @TestCase
    func sandboxedRegisteredDetectorRestoresBothAcceptedAndDeclinedProbes() {
        let session = checkpointSession()
        session.beginLine(checkpointLine("outer", 0))
        session.setRegisteredBlockStartDetector({ probe: ParseSession, text: String =>
            @Expect(probe.allowDeepIndentedBlockStart(), true)
            checkpointCounter(probe).value += 1
            probe.patches.remove(probe.createNode("Probe"))
            text == "yes"
        }, sandboxed: true)
        @Expect(session.startsRegisteredBlock("no"), false)
        @Expect(session.startsRegisteredBlock("yes"), true)
        @Expect(session.nextNodeId, 1)
        @Expect(checkpointCounter(session).value, 0)
        @Expect(session.patches.isEmpty(), true)
        @Expect(session.allowDeepIndentedBlockStart(), false)
    }

    @TestCase
    func nestedSuccessRestoresOuterSyntaxAndKeepsOwnedResults() {
        let session = checkpointSession()
        let outer = checkpointLine("outer", 0)
        session.beginLine(outer)
        session.addPendingParagraphLine(outer)
        session.setDetachedBlockParser({ lines: ArrayList<SourceLine> =>
            @Expect(session.pendingParagraphLines.isEmpty(), true)
            @Expect(session.allowDeepIndentedBlockStart(), true)
            session.beginLine(lines[0])
            session.addPendingParagraphLine(lines[0])
            checkpointCounter(session).value = 8
            let node = session.createNode("Nested")
            session.patches.replace(node)
            let result = ArrayList<Node>()
            result.add(node)
            result
        }, sandboxedStates: true)
        let lines = ArrayList<SourceLine>()
        lines.add(checkpointLine("inner", 20))
        let result = session.parseDetachedLines(lines)
        @Expect(result.size, 1)
        @Expect(result[0].id, 1)
        @Expect(session.nextNodeId, 2)
        @Expect(checkpointCounter(session).value, 8)
        @Expect(session.currentSourceLine().text, "outer")
        @Expect(session.pendingParagraphLines.size, 1)
        @Expect(session.pendingParagraphLines[0].text, "outer")
        @Expect(session.allowDeepIndentedBlockStart(), false)
        @Expect(session.patches.drainReplaceNodes()[0].id, 1)
    }

    @TestCase
    func nestedExceptionRestoresOuterStatePatchesAndAllocator() {
        let session = checkpointSession()
        session.beginLine(checkpointLine("outer", 0))
        session.addPendingParagraphLine(session.currentSourceLine())
        checkpointCounter(session).value = 3
        let before = session.checkpoint()
        session.setDetachedBlockParser({ _: ArrayList<SourceLine> =>
            checkpointCounter(session).value = 9
            session.beginLine(checkpointLine("inner", 20))
            session.addPendingParagraphLine(session.currentSourceLine())
            session.recordSourceLine(session.currentSourceLine())
            let node = session.createNode("Nested")
            session.root.addChild(node)
            session.patches.replace(node)
            throw IllegalArgumentException("injected nested failure")
        }, sandboxedStates: true)
        var thrown = false
        try { session.parseDetachedLines(ArrayList<SourceLine>()) }
        catch (_: IllegalArgumentException) { thrown = true }
        @Expect(thrown, true)
        @Expect(session.checkpoint().syntaxFingerprint, before.syntaxFingerprint)
        @Expect(checkpointCounter(session).value, 3)
        @Expect(session.nextNodeId, before.nextNodeId)
        @Expect(session.root.children.isEmpty(), true)
        @Expect(session.lineIndex.size, 0)
        @Expect(session.patches.isEmpty(), true)
        @Expect(session.allowDeepIndentedBlockStart(), false)
    }

    @TestCase
    func nonRestorableStateRefusesBeforeExecutingProbeAndLegacyNestedStillRestoresSyntax() {
        @Expect(SessionSymbolTableStore().supportsCheckpoint, false)
        let symbols = SessionSymbolTableStore(checkpointEnabled: true)
        symbols.registerErased("checkpoint.legacy", { => CheckpointLegacyState() })
        let session = ParseSession(SourceBuffer(), ParseOptions(), symbols)
        session.beginLine(checkpointLine("outer", 0))
        session.addPendingParagraphLine(session.currentSourceLine())
        let probeControl = CheckpointProbeControl()
        var rejected = false
        try { session.sandboxProbe({ => probeControl.invoked = true; true }) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(probeControl.invoked, false)
        @Expect(session.supportsCompleteCheckpoint, false)
        // A legacy third-party detector can inspect the existing root and is
        // called in the same order. Empty working roots require explicit opt-in.
        session.root.addChild(Node("Existing", id: 200))
        session.setRegisteredBlockStartDetector({ candidate: ParseSession, text: String =>
            probeControl.trace += text
            candidate.root.children.size == 1
        })
        @Expect(session.startsRegisteredBlock("a"), true)
        @Expect(session.startsRegisteredBlock("b"), true)
        @Expect(probeControl.trace, "ab")
        session.setDetachedBlockParser({ _: ArrayList<SourceLine> =>
            session.beginLine(checkpointLine("inner", 10))
            session.allocateNodeId()
            throw IllegalArgumentException("legacy nested failure")
        })
        try { session.parseDetachedLines(ArrayList<SourceLine>()) } catch (_: IllegalArgumentException) {}
        @Expect(session.currentSourceLine().text, "outer")
        @Expect(session.pendingParagraphLines.size, 1)
        @Expect(session.nextNodeId, 1)
        @Expect(session.allowDeepIndentedBlockStart(), false)
        session.setDetachedBlockParser({ _: ArrayList<SourceLine> =>
            @Expect(session.currentSourceLine().text, "outer")
            @Expect(session.pendingParagraphLines.size, 1)
            @Expect(session.pendingParagraphLines[0].text, "outer")
            @Expect(session.allowDeepIndentedBlockStart(), true)
            let inner = checkpointLine("inner", 10)
            session.beginLine(inner)
            session.addPendingParagraphLine(inner)
            session.allocateNodeId()
            ArrayList<Node>()
        })
        session.parseDetachedLines(ArrayList<SourceLine>())
        @Expect(session.currentSourceLine().text, "inner")
        @Expect(session.pendingParagraphLines.size, 2)
        @Expect(session.pendingParagraphLines[0].text, "outer")
        @Expect(session.pendingParagraphLines[1].text, "inner")
        @Expect(session.nextNodeId, 2)
        @Expect(session.allowDeepIndentedBlockStart(), false)
    }

    @TestCase
    func providerRefusalAndForeignCheckpointCannotPartiallyRestoreLiveSession() {
        let control = CheckpointRestoreControl()
        let session = checkpointSession(control: control)
        session.beginLine(checkpointLine("first", 0))
        let saved = session.checkpoint()
        session.beginLine(checkpointLine("second", 10))
        checkpointCounter(session).value = 6
        let liveState = checkpointCounter(session)
        control.refuse = true
        @Expect(session.restoreCheckpoint(saved), false)
        @Expect(refEq(liveState, checkpointCounter(session)), true)
        @Expect(checkpointCounter(session).value, 6)
        @Expect(session.currentSourceLine().text, "second")
        @Expect(checkpointSession().restoreCheckpoint(saved), false)
        session.setNextNodeIdForEditing(500)
        @Expect(session.allocateNodeId(), 500)
        var rejected = false
        try { session.setNextNodeIdForEditing(2) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
    }
}
