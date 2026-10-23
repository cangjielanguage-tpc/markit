package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.core.block.*
import markit.core.editing.*
import markit.core.incremental.DocumentEditingSession
import markit.core.nodes.*
import markit.core.session.*
import markit.core.source.*

private class PrepareHookPayload <: SessionStatePayload {
    public prop fingerprint: String { get() { return "prepare:0" } }
    public func detachedCopy(): SessionStatePayload { return PrepareHookPayload() }
}

// The hook is armed only after the editor constructor has completed. The
// mutable control object avoids capturing a mutable local in a callback.
private class PrepareHookControl {
    public let mode: String
    public var editor: ?DocumentEditingSession = None
    public var armed: Bool = false
    public var invocations: Int64 = 0
    public var reentryRejected: Bool = false
    public var reentryReason: String = ""
    public init(mode: String) { this.mode = mode }
    public func invoke(): Unit {
        if (!armed) { return }
        armed = false
        invocations += 1
        let active = editor.getOrThrow()
        if (mode == "reenter") {
            try { active.flush() }
            catch (error: IllegalArgumentException) {
                reentryRejected = true
                reentryReason = error.message
            }
        } else if (mode == "throw") {
            throw IllegalArgumentException("injected preparation snapshot failure")
        } else if (mode == "cancel") { active.cancelComputation() }
    }
}

private class PrepareHookState <: SessionState {
    private let control: PrepareHookControl
    public init(control: PrepareHookControl) { this.control = control }
    public func reset(): Unit {}
    public prop supportsStateRestore: Bool { get() { return true } }
    public func snapshot(): SessionStateSnapshot {
        control.invoke()
        return RestorableSessionStateSnapshot("prepare.hook", 0, "prepare-root", PrepareHookPayload())
    }
    public func restoreSnapshot(snapshot: SessionStateSnapshot): Bool {
        if (snapshot.dynamicName != "prepare.hook" || snapshot.contextFingerprint != "prepare-root") { return false }
        if (let Some(payload) <- snapshot.payloadCopy()) { return (payload as PrepareHookPayload).isSome() }
        return false
    }
}

private class PrepareDocumentCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "prepare-document-only" } }
    public func accepts(node: Node): Bool { return (node as DocumentNode).isSome() }
    public func createShallow(_: Node): Node { return DocumentNode(SourceBuffer()) }
    public func rawContentFollowsSource(_: Node): Bool { return true }
}

private func prepareEditor(control: PrepareHookControl): DocumentEditingSession {
    let source = EditableRopeStore("prepare-gate", text: "a")
    let symbols = SessionSymbolTableStore(checkpointEnabled: true)
    symbols.registerErased("prepare.hook", { => PrepareHookState(control) })
    let parser = ParseSession(SourceBuffer(editableSource: Some(source.current)), ParseOptions(), symbols)
    let codec = NodeCodec()
    codec.register(PrepareDocumentCodec())
    let editor = DocumentEditingSession(source, parser, { session: ParseSession =>
        BlockParsingKernel(session, ContinuationBlockDispatchTable(), BlockDispatchTable(), ArrayList<ParagraphBlockParser>())
    }, [], codec)
    control.editor = Some(editor)
    editor.applyEdits(0, [EditingTextEdit(EditingRange(1, 1), "b")])
    control.armed = true
    return editor
}

@Test
@Tag[BlockEditing, PreparationGate]
class Task05EnginePreparationTests {
    @TestCase
    func checkpointSnapshotCallbackCannotReenterFlushBeforeBusyGate() {
        let control = PrepareHookControl("reenter")
        let editor = prepareEditor(control)
        let result = editor.flush()
        @Expect(control.invocations, 1)
        @Expect(control.reentryRejected, true)
        @Expect(control.reentryReason, "Editing computation is already active")
        @Expect(result.committed, false)
        @Expect(editor.versions.sourceVersion, 1)
        @Expect(editor.versions.parseVersion, 0)
        @Expect(editor.source.current.sliceBytes(0, 2), "ab")
        // This fixture intentionally has no recovery providers. The outer
        // flush can fail recovery, but the busy flag must have been cleared.
        let retry = editor.flush()
        @Expect(retry.reason.contains("already active"), false)
        editor.close()
    }

    @TestCase
    func throwingPreparationSnapshotHookClearsBusyWithoutUndoingAcceptedInput() {
        let control = PrepareHookControl("throw")
        let editor = prepareEditor(control)
        var rejected = false
        try { editor.flush() }
        catch (error: IllegalArgumentException) {
            rejected = error.message == "injected preparation snapshot failure"
        }
        @Expect(rejected, true)
        @Expect(control.invocations, 1)
        @Expect(editor.versions.sourceVersion, 1)
        @Expect(editor.versions.parseVersion, 0)
        @Expect(editor.source.current.sliceBytes(0, 2), "ab")
        let retry = editor.flush()
        @Expect(retry.reason.contains("already active"), false)
        let snapshot = editor.snapshot()
        @Expect(snapshot.tree.version, 0)
        @Expect(snapshot.patches.size, 0)
        snapshot.release()
        editor.close()
    }

    @TestCase
    func cancellationInsidePreparationSnapshotRejectsCapturedEpochBeforePublication() {
        let control = PrepareHookControl("cancel")
        let editor = prepareEditor(control)
        let result = editor.flush()
        @Expect(control.invocations, 1)
        @Expect(result.committed, false)
        @Expect(result.reason.contains("Cancelled or stale editing computation"), true)
        @Expect(result.sourceVersion, 1)
        @Expect(result.parseVersion, 0)
        @Expect(editor.source.current.sliceBytes(0, 2), "ab")
        let snapshot = editor.snapshot()
        @Expect(snapshot.tree.version, 0)
        @Expect(snapshot.patches.size, 0)
        snapshot.release()
        editor.close()
    }
}
