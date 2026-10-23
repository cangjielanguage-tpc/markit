package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.core.editing.{EditingVersionState, ParserIsolationProof, EditingRange, EditingCoordinate,
    SourceVersionIdentity, SourceAnchor, AnchorAffinity, IncrementalStatePayload, IncrementalCheckpoint,
    IncrementalReadDependency, LogicalTextSplice}

private class ValueCheckpointPayload <: IncrementalStatePayload {
    public ValueCheckpointPayload(public var value: Int64) {}
    public func clonePayload(): IncrementalStatePayload { return ValueCheckpointPayload(value) }
    public func fingerprint(): String { return value.toString() }
}

@Test
@Tag[EditingContracts]
class EditingValueContractTests {
    @TestCase
    func acknowledgedSourceSurvivesCancellationAndStaleCommits() {
        let versions = EditingVersionState("document")
        @Expect(versions.acceptSource(0), 1)
        versions.cancelComputation()
        @Expect(versions.sourceVersion, 1)
        @Expect(versions.parseVersion, 0)
        @Expect(versions.renderVersion, 0)
        @Expect(versions.commitParse(0), false)
        @Expect(versions.commitRender(1), false)
        @Expect(versions.commitParse(1), true)
        @Expect(versions.commitRender(1), true)
        @Expect(versions.acceptSource(1), 2)
        @Expect(versions.commitParse(1), false)
        @Expect(versions.commitRender(1), false)
        @Expect(versions.parseVersion, 1)
        @Expect(versions.renderVersion, 1)
    }

    @TestCase
    func staleAcceptanceRejectsWithoutChangingAnyClock() {
        let versions = EditingVersionState("document", initialVersion: 3)
        var rejected = false
        try { versions.acceptSource(2) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        @Expect(versions.sourceVersion, 3)
        @Expect(versions.parseVersion, 3)
        @Expect(versions.renderVersion, 3)
    }

    @TestCase
    func localFallbackProofRequiresAllBoundariesAndEvidence() {
        @Expect(ParserIsolationProof().verified, false)
        @Expect(ParserIsolationProof(syntaxBoundary: true, stateBoundary: true,
            semanticBoundary: true).verified, false)
        @Expect(ParserIsolationProof(syntaxBoundary: true, stateBoundary: true,
            evidence: "bounded source and state").verified, false)
        @Expect(ParserIsolationProof(syntaxBoundary: true, stateBoundary: true,
            semanticBoundary: true, evidence: "owner-isolated transaction").verified, true)
    }

    @TestCase
    func sourceContractUsesExplicitCoordinateAndVersion() {
        let range = EditingRange(1, 3, coordinate: EditingCoordinate.Utf16)
        @Expect(range.start, 1)
        @Expect(range.end, 3)
        let anchor = SourceAnchor(SourceVersionIdentity("document", 7), 4,
            affinity: AnchorAffinity.Before)
        @Expect(anchor.source.documentId, "document")
        @Expect(anchor.source.version, 7)
        @Expect(anchor.byteOffset, 4)
        var rejected = false
        try { EditingRange(3, 1) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        let splice = LogicalTextSplice(8, 0, 4, "甲😀")
        @Expect(splice.nodeId, 8)
        @Expect(splice.startByte, 0)
        @Expect(splice.endByte, 4)
        @Expect(splice.inserted, "甲😀")
        rejected = false
        try { LogicalTextSplice(-1, 0, 0, "") } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try { LogicalTextSplice(8, -1, 0, "") } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
        rejected = false
        try { LogicalTextSplice(8, 3, 1, "") } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
    }

    @TestCase
    func checkpointCloneAndNegativeReadRemainExplicit() {
        let live = ValueCheckpointPayload(4)
        let frozen = live.clonePayload()
        let checkpoint = IncrementalCheckpoint("document", "parser", 2, frozen, syntaxContext: "nested")
        live.value = 9
        @Expect(checkpoint.payload.fingerprint(), "4")
        let supplied = (frozen as ValueCheckpointPayload).getOrThrow()
        supplied.value = 11
        let exposed = (checkpoint.payload as ValueCheckpointPayload).getOrThrow()
        exposed.value = 17
        @Expect(checkpoint.payload.fingerprint(), "4")
        @Expect(checkpoint.documentId, "document")
        @Expect(checkpoint.sourceVersion, 2)
        @Expect(checkpoint.syntaxContext, "nested")
        let missing = IncrementalReadDependency("parser", "definition:absent", false, 2)
        @Expect(missing.found, false)
        @Expect(missing.key, "definition:absent")
        @Expect(missing.version, 2)
    }
}
