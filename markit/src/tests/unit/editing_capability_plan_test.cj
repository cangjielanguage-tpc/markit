package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult, LeafBlockParser, ParagraphBlockParser}
import markit.core.editing.{EditingFallbackScope, EditingPolicy, EditingVersionState, IncrementalCheckpoint, IncrementalParserContext, IncrementalParserFacet, IncrementalReadDependency, IncrementalStatePayload, ParserIsolationProof}
import markit.core.nodes.Node
import markit.core.plugin.{EditingCapabilityPlan, Plugin, PluginRegistrar}
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SourceSpan}

private class RuntimeCapabilityProbe {
    var declarations: Int64 = 0
    var providerCalls: Int64 = 0
    var callbacks: Int64 = 0
}

private class RuntimeCapabilityPayload <: IncrementalStatePayload {
    private let value: String
    public init(value: String) { this.value = value }
    public func clonePayload(): IncrementalStatePayload { return RuntimeCapabilityPayload(value) }
    public func fingerprint(): String { return value }
}

private class RuntimeCapabilityContext <: IncrementalParserContext {
    private let id: String
    private var state: ?IncrementalStatePayload = None
    public var revocations: Int64 = 0
    public init(id: String) { this.id = id }
    public prop documentId: String { get() { return id } }
    public prop sourceVersion: Int64 { get() { return 3 } }
    public func readState(_: String): ?IncrementalStatePayload { return state }
    public func writeState(_: String, payload: IncrementalStatePayload): Bool {
        state = Some(payload.clonePayload())
        return true
    }
    public func revokeOwnerEffects(_: String): Bool { revocations += 1; return true }
}

private class RuntimeCapabilityFacet <: IncrementalParserFacet {
    private let probe: RuntimeCapabilityProbe
    private let stateCodec: Bool
    private let effects: Bool
    private let reads: Bool
    private let nodes: Bool
    private let facetOwner: String
    public init(probe: RuntimeCapabilityProbe, stateCodec!: Bool = true,
        effects!: Bool = true, reads!: Bool = true, nodes!: Bool = true,
        owner!: String = "RuntimeCapabilityPlugin") {
        this.probe = probe
        this.stateCodec = stateCodec
        this.effects = effects
        this.reads = reads
        this.nodes = nodes
        this.facetOwner = owner
    }
    public prop owner: String { get() { return facetOwner } }
    public prop hasStateCodec: Bool { get() { return stateCodec } }
    public prop hasEffectRollback: Bool { get() { return effects } }
    public prop hasReadEvidence: Bool { get() { return reads } }
    public prop hasNodeCodec: Bool { get() { return nodes } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        probe.providerCalls += 1
        if (!stateCodec) { return None }
        let payload: IncrementalStatePayload = match (context.readState(owner)) {
            case Some(existing) => existing.clonePayload()
            case None => RuntimeCapabilityPayload("initial")
        }
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion, payload,
            syntaxContext: context.documentId))
    }
    public func restore(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        probe.providerCalls += 1
        if (!stateCodec || saved.documentId != context.documentId || saved.owner != owner || saved.sourceVersion != context.sourceVersion ||
            saved.syntaxContext != context.documentId) { return false }
        return context.writeState(owner, saved.payload.clonePayload())
    }
    public func rollbackEffects(context: IncrementalParserContext, saved: IncrementalCheckpoint): Bool {
        probe.providerCalls += 1
        if (!effects || saved.documentId != context.documentId || saved.owner != owner || saved.sourceVersion != context.sourceVersion) { return false }
        return context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(previous: IncrementalCheckpoint, current: IncrementalCheckpoint): Bool {
        probe.providerCalls += 1
        return previous.documentId == current.documentId && previous.owner == current.owner && previous.syntaxContext == current.syntaxContext &&
            previous.payload.fingerprint() == current.payload.fingerprint()
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> {
        probe.providerCalls += 1
        // This fixture reads no external semantic keys; an explicit empty set
        // is distinct from a missing provider capability.
        return ArrayList<IncrementalReadDependency>()
    }
}

private class RuntimeCapabilityLeaf <: LeafBlockParser {
    private let parserName: String
    private let parserPriority: Int64
    private let enabled: Bool
    private let provider: ?IncrementalParserFacet
    private let proof: ?ParserIsolationProof
    private let probe: RuntimeCapabilityProbe
    private let anyNonBlank: Bool
    public init(parserName: String, probe: RuntimeCapabilityProbe, priority!: Int64 = 10,
        enabled!: Bool = false, provider!: ?IncrementalParserFacet = None,
        proof!: ?ParserIsolationProof = None, anyNonBlank!: Bool = false) {
        this.parserName = parserName
        this.probe = probe
        this.parserPriority = priority
        this.enabled = enabled
        this.provider = provider
        this.proof = proof
        this.anyNonBlank = anyNonBlank
    }
    public prop name: String { get() { return parserName } }
    public prop ownerPlugin: String { get() { return "RuntimeCapabilityPlugin" } }
    public prop priority: Int64 { get() { return parserPriority } }
    public prop startBytes: Array<Byte> { get() { return if (anyNonBlank) { [] } else { [b'~'] } } }
    public prop acceptsAnyNonBlank: Bool { get() { return anyNonBlank } }
    public prop supportsIncremental: Bool { get() { probe.declarations += 1; return enabled } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return provider } }
    public prop incrementalIsolation: ?ParserIsolationProof { get() { return proof } }
    public func tryParse(session: ParseSession, line: String): ?Node {
        if (!line.startsWith("~")) { return None }
        return Some(session.createTextNode(parserName + ":" + line[1..], session.currentLineSpan()))
    }
}

private class RuntimeCapabilityContinuation <: ContinuationBlockParser {
    public prop name: String { get() { return "continuation" } }
    public prop ownerPlugin: String { get() { return "RuntimeCapabilityPlugin" } }
    public prop priority: Int64 { get() { return 100 } }
    public prop startBytes: Array<Byte> { get() { return [b'!'] } }
    public func tryStart(_: ParseSession, _: String): ?BlockFrame { return None }
    public func continueBlock(_: ParseSession, _: BlockFrame, _: String): ContinueResult { return ContinueResult.Closed }
    public func finalize(session: ParseSession, _: BlockFrame): Node { return session.createNode("Paragraph") }
}

private class RuntimeCapabilityParagraph <: ParagraphBlockParser {
    private let provider: ?IncrementalParserFacet
    public init(provider!: ?IncrementalParserFacet = None) { this.provider = provider }
    public prop name: String { get() { return "paragraph" } }
    public prop ownerPlugin: String { get() { return "RuntimeCapabilityPlugin" } }
    public prop supportsIncremental: Bool { get() { return provider.isSome() } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return provider } }
    public func canStart(_: ParseSession, _: String): Bool { return true }
    public func normalizeLine(_: ParseSession, line: String): String { return line }
    public func finalize(session: ParseSession, _: ArrayList<SourceLine>, span: SourceSpan,
        _: ParagraphTermination): Node { return session.createNodeWithSpan("Paragraph", span) }
}

private class RuntimeCapabilityPlugin <: Plugin {
    private let parsers: Array<LeafBlockParser>
    private let phaseCase: String
    private let categories: Bool
    private let opaque: Bool
    private let pluginVersion: String
    private let probe: RuntimeCapabilityProbe
    private let paragraphProvider: ?IncrementalParserFacet
    public init(parsers: Array<LeafBlockParser>, probe: RuntimeCapabilityProbe,
        phaseCase!: String = "", categories!: Bool = false, opaque!: Bool = false,
        version!: String = "1", paragraphProvider!: ?IncrementalParserFacet = None) {
        this.parsers = parsers
        this.probe = probe
        this.phaseCase = phaseCase
        this.categories = categories
        this.opaque = opaque
        this.pluginVersion = version
        this.paragraphProvider = paragraphProvider
    }
    public prop name: String { get() { return "RuntimeCapabilityPlugin" } }
    public prop version: String { get() { return pluginVersion } }
    public func register(registrar: PluginRegistrar): Unit {
        for (parser in parsers) { registrar.registerLeafBlockParser(parser) }
        if (categories || paragraphProvider.isSome()) {
            registrar.registerParagraphBlockParser(RuntimeCapabilityParagraph(provider: paragraphProvider))
        }
        if (categories) {
            registrar.registerContinuationBlockParser(RuntimeCapabilityContinuation())
        }
        if (phaseCase == "ordered") {
            registrar.registerEditingPhase("render", name, dependencies: ["semantic"])
            registrar.registerEditingPhase("syntax", name)
            registrar.registerEditingPhase("semantic", name, dependencies: ["syntax"])
        } else if (phaseCase == "cycle") {
            registrar.registerEditingPhase("a", name, dependencies: ["b"])
            registrar.registerEditingPhase("b", name, dependencies: ["a"])
        } else if (phaseCase == "missing") {
            registrar.registerEditingPhase("a", name, dependencies: ["absent"])
        }
        if (opaque) {
            registrar.registerSessionFinalizeProcessor({ _ => probe.callbacks += 1 })
        }
    }
}

@Test
@Tag[EditingContracts]
class EditingCapabilityPlanTests {
    @TestCase
    func realMixedParserCapabilitiesUseProofOrSessionFallback() {
        let probe = RuntimeCapabilityProbe()
        let proof = ParserIsolationProof(syntaxBoundary: true, stateBoundary: true,
            semanticBoundary: true, evidence: "test-owned independent unit")
        let parser = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("ready", probe, enabled: true, provider: Some(RuntimeCapabilityFacet(probe))),
            RuntimeCapabilityLeaf("legacy-isolated", probe, proof: Some(proof)),
            RuntimeCapabilityLeaf("legacy-unknown", probe)
        ], probe))
        let plan = parser.createEditingPlan()
        @Expect(plan.accepted, true)
        @Expect(plan.parsers.size, 3)
        @Expect(plan.parsers[0].incrementalReady, true)
        @Expect(plan.parsers[0].fallback == EditingFallbackScope.NoFallback, true)
        @Expect(plan.parsers[1].fallback == EditingFallbackScope.IsolatedUnit, true)
        @Expect(plan.parsers[1].isolationEvidence, "test-owned independent unit")
        @Expect(plan.parsers[2].fallback == EditingFallbackScope.Session, true)
        @Expect(plan.diagnostics[0].owner, "RuntimeCapabilityPlugin")
        @Expect(plan.fallback == EditingFallbackScope.Session, true)
        @Expect(plan.fullyIncrementalReady, false)
        @Expect(probe.providerCalls, 0)
        let provider = RuntimeCapabilityFacet(probe)
        let firstDocument = RuntimeCapabilityContext("first-document")
        let secondDocument = RuntimeCapabilityContext("second-document")
        let saved = provider.checkpoint(firstDocument).getOrThrow()
        // Same owner/version is insufficient across document boundaries.
        @Expect(provider.restore(secondDocument, saved), false)
        @Expect(provider.rollbackEffects(secondDocument, saved), false)
        @Expect(secondDocument.readState(provider.owner).isNone(), true)
        @Expect(secondDocument.revocations, 0)
        @Expect(provider.restore(firstDocument, saved), true)
        @Expect(firstDocument.readState(provider.owner).getOrThrow().fingerprint(), "initial")
        @Expect(provider.rollbackEffects(firstDocument, saved), true)
        @Expect(firstDocument.revocations, 1)
        let callsBeforePlanning = probe.providerCalls
        let complete = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("ready", probe, enabled: true, provider: Some(provider))
        ], probe, paragraphProvider: Some(provider))).createEditingPlan(
            policy: EditingPolicy.Strict, configurationVersion: "explicit-test-configuration")
        @Expect(complete.accepted, true)
        @Expect(complete.fullyIncrementalReady, true)
        @Expect(complete.fallback == EditingFallbackScope.NoFallback, true)
        @Expect(complete.cacheable, true)
        @Expect(complete.parsers.size, 2)
        @Expect(probe.providerCalls, callsBeforePlanning)
    }

    @TestCase
    func everyRequiredFacetFlagAndProviderAreChecked() {
        let probe = RuntimeCapabilityProbe()
        let parser = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("flag-only", probe, enabled: true),
            RuntimeCapabilityLeaf("state", probe, enabled: true, provider: Some(RuntimeCapabilityFacet(probe, stateCodec: false))),
            RuntimeCapabilityLeaf("effects", probe, enabled: true, provider: Some(RuntimeCapabilityFacet(probe, effects: false))),
            RuntimeCapabilityLeaf("reads", probe, enabled: true, provider: Some(RuntimeCapabilityFacet(probe, reads: false))),
            RuntimeCapabilityLeaf("nodes", probe, enabled: true, provider: Some(RuntimeCapabilityFacet(probe, nodes: false))),
            RuntimeCapabilityLeaf("foreign-owner", probe, enabled: true, provider: Some(RuntimeCapabilityFacet(probe, owner: "DifferentPlugin")))
        ], probe))
        let plan = parser.createEditingPlan()
        for (entry in plan.parsers) {
            @Expect(entry.incrementalReady, false)
            @Expect(entry.fallback == EditingFallbackScope.Session, true)
            @Expect(entry.missingFacets.size > 0, true)
        }
        @Expect(plan.diagnostics.size, 6)
        @Expect(plan.parsers[5].missingFacets[0], "facet-owner-mismatch")
    }

    @TestCase
    func strictRejectsBeforeProviderSessionOrRegistrationMutation() {
        let probe = RuntimeCapabilityProbe()
        let parser = Markit(RuntimeCapabilityPlugin([RuntimeCapabilityLeaf("legacy", probe)], probe))
        let versions = EditingVersionState("document")
        let plan = parser.createEditingPlan(policy: EditingPolicy.Strict)
        @Expect(plan.accepted, false)
        @Expect(plan.parsers[0].fallback == EditingFallbackScope.Rejected, true)
        @Expect(versions.sourceVersion, 0)
        @Expect(versions.parseVersion, 0)
        @Expect(versions.renderVersion, 0)
        @Expect(probe.providerCalls, 0)
        @Expect(probe.callbacks, 0)
        // A rejected plan must not freeze the registry as an incidental effect.
        parser.use(RuntimeCapabilityPlugin([], probe, version: "2"))
        @Expect(parser.parse("~body").html(), "legacy:body")
        let pending = Markit()
        @Expect(pending.createEditingPlan(policy: EditingPolicy.Strict).accepted, false)
        pending.use(StandardMarkdownBundle(blockAutoAnchor: false))
        let fresh = Markit().use(StandardMarkdownBundle(blockAutoAnchor: false))
        @Expect(pending.parse("# title\n\nbody").html(), fresh.parse("# title\n\nbody").html())
        @Expect(pending.createEditingPlan().parsers.size, fresh.createEditingPlan().parsers.size)
    }

    @TestCase
    func categoryPriorityAndRegistrationTiesMatchActualDispatch() {
        let probe = RuntimeCapabilityProbe()
        let parser = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("first", probe),
            RuntimeCapabilityLeaf("second", probe),
            RuntimeCapabilityLeaf("earlier-priority", probe, priority: 1)
        ], probe, categories: true))
        let plan = parser.createEditingPlan()
        @Expect(plan.parsers[0].registration.category, "continuation")
        @Expect(plan.parsers[1].registration.parserName, "earlier-priority")
        @Expect(plan.parsers[2].registration.parserName, "first")
        @Expect(plan.parsers[3].registration.parserName, "second")
        @Expect(plan.parsers[4].registration.category, "paragraph")
        @Expect(parser.parse("~body").html(), "earlier-priority:body")
        let acrossPlugins = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("registered-first", probe)
        ], probe)).use(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("registered-second", probe)
        ], probe))
        let tiedPlan = acrossPlugins.createEditingPlan()
        @Expect(tiedPlan.parsers[0].registration.parserName, "registered-first")
        @Expect(tiedPlan.parsers[1].registration.parserName, "registered-second")
        @Expect(acrossPlugins.parse("~body").html(), "registered-first:body")
    }

    @TestCase
    func capabilityDisplayNeverReplacesBucketBeforeAnyDispatch() {
        let probe = RuntimeCapabilityProbe()
        let parser = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("any", probe, priority: 1, anyNonBlank: true),
            RuntimeCapabilityLeaf("bucket", probe, priority: 10)
        ], probe))
        let plan = parser.createEditingPlan()
        @Expect(plan.parsers[0].registration.parserName, "any")
        // Actual legacy dispatch chooses the explicit bucket before the generic
        // nonblank group. Reading an inventory must not change that behavior.
        @Expect(parser.parse("~body").html(), "bucket:body")
    }

    @TestCase
    func phaseDagIsStableAndRejectsMissingOrCyclicDependencies() {
        let probe = RuntimeCapabilityProbe()
        let ordered = Markit(RuntimeCapabilityPlugin([], probe, phaseCase: "ordered")).createEditingPlan()
        @Expect(ordered.accepted, true)
        @Expect(ordered.phases[0].id, "syntax")
        @Expect(ordered.phases[1].id, "semantic")
        @Expect(ordered.phases[2].id, "render")
        let cyclic = Markit(RuntimeCapabilityPlugin([], probe, phaseCase: "cycle")).createEditingPlan()
        @Expect(cyclic.accepted, false)
        @Expect(hasDiagnostic(cyclic, "phase-cycle"), true)
        let missing = Markit(RuntimeCapabilityPlugin([], probe, phaseCase: "missing")).createEditingPlan()
        @Expect(missing.accepted, false)
        @Expect(hasDiagnostic(missing, "phase-dependency-missing"), true)
    }

    @TestCase
    func fingerprintIncludesConfigurationVersionAndOrderWithoutProviderExecution() {
        let probe = RuntimeCapabilityProbe()
        let parser = Markit(RuntimeCapabilityPlugin([RuntimeCapabilityLeaf("one", probe)], probe))
        let initial = parser.createEditingPlan(configurationVersion: "theme-a")
        let same = parser.getEditingPlan(configurationVersion: "theme-a")
        let changed = parser.getEditingPlan(configurationVersion: "theme-b")
        @Expect(initial.fingerprint, same.fingerprint)
        @Expect(initial.fingerprint != changed.fingerprint, true)
        @Expect(initial.cacheable, true)
        @Expect(parser.createEditingPlan().cacheable, false)
        @Expect(parser.createEditingPlan(configurationVersion: "").cacheable, false)
        let versioned = Markit(RuntimeCapabilityPlugin([RuntimeCapabilityLeaf("one", probe)], probe,
            version: "2")).createEditingPlan(configurationVersion: "theme-a")
        @Expect(initial.fingerprint != versioned.fingerprint, true)
        let withoutAnchors = Markit(StandardMarkdownBundle(blockAutoAnchor: false)).createEditingPlan()
        let withAnchors = Markit(StandardMarkdownBundle(blockAutoAnchor: true)).createEditingPlan()
        // Existing Plugin only publishes name/version, not private configuration.
        // Unknown config is never a complete cache identity, even if canonical
        // known metadata is equal for these semantically different bundles.
        @Expect(withoutAnchors.cacheable, false)
        @Expect(withAnchors.cacheable, false)
        let explicitOff = Markit(StandardMarkdownBundle(blockAutoAnchor: false)).createEditingPlan(
            configurationVersion: "blockAutoAnchor=false")
        let explicitOn = Markit(StandardMarkdownBundle(blockAutoAnchor: true)).createEditingPlan(
            configurationVersion: "blockAutoAnchor=true")
        @Expect(explicitOff.fingerprint != explicitOn.fingerprint, true)
        @Expect(explicitOff.cacheable, true)
        @Expect(explicitOn.cacheable, true)
        @Expect(probe.providerCalls, 0)
    }

    @TestCase
    func batchAndAppendNeverReadEditingDeclarations() {
        let probe = RuntimeCapabilityProbe()
        let parser = Markit(RuntimeCapabilityPlugin([RuntimeCapabilityLeaf("legacy", probe)], probe))
        @Expect(parser.parse("~first").html(), "legacy:first")
        let session = parser.createSession()
        session.feed("~second")
        session.finalize()
        @Expect(session.toHtml(), "legacy:second")
        @Expect(probe.declarations, 0)
        parser.createEditingPlan()
        @Expect(probe.declarations, 1)
    }

    @TestCase
    func anonymousDerivedHooksCannotBeBlessedByPhaseMetadata() {
        let probe = RuntimeCapabilityProbe()
        let parser = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("ready", probe, enabled: true, provider: Some(RuntimeCapabilityFacet(probe)))
        ], probe, phaseCase: "ordered", opaque: true))
        let strict = parser.createEditingPlan(policy: EditingPolicy.Strict)
        @Expect(strict.accepted, false)
        @Expect(hasDiagnostic(strict, "derived-provider-missing"), true)
        @Expect(strict.fallback == EditingFallbackScope.Rejected, true)
        let compat = parser.createEditingPlan()
        @Expect(compat.accepted, true)
        @Expect(compat.fullyIncrementalReady, false)
        @Expect(compat.fallback == EditingFallbackScope.Session, true)
        @Expect(probe.callbacks, 0)
    }

    @TestCase
    func emptyAndLeafOnlyPlansReflectReachableParserInventory() {
        let emptyParser = Markit.empty()
        let emptyPlan = emptyParser.createEditingPlan(policy: EditingPolicy.Strict)
        @Expect(emptyPlan.accepted, true)
        @Expect(emptyPlan.fullyIncrementalReady, true)
        @Expect(emptyPlan.parsers.size, 0)
        @Expect(emptyPlan.fallback == EditingFallbackScope.NoFallback, true)
        let emptyCompat = emptyParser.createEditingPlan()
        @Expect(emptyCompat.accepted, true)
        @Expect(emptyCompat.fallback == EditingFallbackScope.NoFallback, true)
        // Both existing engines require a registered paragraph parser to begin
        // an ordinary paragraph. The generic factory alone does not activate it.
        // Preserve this legacy output and compare to a fresh identical setup.
        let emptyActual = emptyParser.parse("ordinary text")
        let emptyFresh = Markit.empty().parse("ordinary text")
        @Expect(emptyActual.root().children.size, emptyFresh.root().children.size)
        @Expect(emptyActual.root().children.size, 0)
        @Expect(emptyActual.html(), emptyFresh.html())
        @Expect(emptyActual.html(), "")
        @Expect(emptyActual.finalUpdate.bytesCommitted, emptyFresh.finalUpdate.bytesCommitted)
        let probe = RuntimeCapabilityProbe()
        let leafOnly = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("ready", probe, enabled: true, provider: Some(RuntimeCapabilityFacet(probe)))
        ], probe))
        let plan = leafOnly.createEditingPlan(policy: EditingPolicy.Strict)
        @Expect(plan.accepted, true)
        @Expect(plan.fullyIncrementalReady, true)
        @Expect(plan.parsers.size, 1)
        @Expect(plan.parsers[0].incrementalReady, true)
        @Expect(plan.fallback == EditingFallbackScope.NoFallback, true)
        let leafActual = leafOnly.parse("ordinary text")
        let freshProbe = RuntimeCapabilityProbe()
        let leafFresh = Markit(RuntimeCapabilityPlugin([
            RuntimeCapabilityLeaf("ready", freshProbe, enabled: true,
                provider: Some(RuntimeCapabilityFacet(freshProbe)))
        ], freshProbe)).parse("ordinary text")
        @Expect(leafActual.root().children.size, leafFresh.root().children.size)
        @Expect(leafActual.root().children.size, 0)
        @Expect(leafActual.html(), leafFresh.html())
        @Expect(leafActual.html(), "")
        @Expect(leafActual.finalUpdate.bytesCommitted, leafFresh.finalUpdate.bytesCommitted)
        @Expect(probe.providerCalls, 0)
    }

    private func hasDiagnostic(plan: EditingCapabilityPlan, code: String): Bool {
        for (diagnostic in plan.diagnostics) {
            if (diagnostic.code == code) { return true }
        }
        return false
    }
}
