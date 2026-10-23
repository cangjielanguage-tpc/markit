package markit.core.plugin

import std.collection.ArrayList
import markit.core.editing.{EditingFallbackScope, EditingPolicy, IncrementalParserFacet, ParserIsolationProof}

// This plan is built only by an explicit editing API. It validates declarations;
// it neither probes grammar nor invokes a provider checkpoint/restore operation.
public class EditingParserRegistration {
    public EditingParserRegistration(public let owner: String, public let parserName: String, public let category: String, public let priority: Int64,
        public let registrationOrder: Int64, public let enabled: Bool, public let facet: ?IncrementalParserFacet,
        public let isolation: ?ParserIsolationProof) {}
}

public class EditingPhaseRegistration {
    public let id: String
    public let owner: String
    private let dependencyIds: Array<String>
    public prop dependencies: Array<String> {
        get() {
            let copied = ArrayList<String>()
            for (dependency in dependencyIds) { copied.add(dependency) }
            return copied.toArray()
        }
    }

    public EditingPhaseRegistration(id: String, owner: String, dependencies!: Array<String> = [], public let version!: String = "1") {
        this.id = id
        this.owner = owner

        let copied = ArrayList<String>()
        for (dependency in dependencies) { copied.add(dependency) }
        this.dependencyIds = copied.toArray()
    }
}

public class EditingCapabilityDiagnostic {
    public EditingCapabilityDiagnostic(public let owner: String, public let parserName: String, public let category: String,
        public let code: String, public let reason: String, public let fallback: EditingFallbackScope) {}
}

public class EditingParserCapability {
    public let registration: EditingParserRegistration
    public let incrementalReady: Bool
    public let missingFacets: Array<String>
    public let fallback: EditingFallbackScope
    public let isolationEvidence: String

    public EditingParserCapability(registration: EditingParserRegistration, policy: EditingPolicy) {
        this.registration = registration

        let missing = ArrayList<String>()
        if (!registration.enabled) { missing.add("opt-in") }
        if (registration.owner.isEmpty()) { missing.add("owner") }
        if (registration.parserName.isEmpty()) { missing.add("parser-name") }
        if (let Some(provider) <- registration.facet) {
            if (provider.owner.isEmpty()) { missing.add("facet-owner") }
            if (provider.owner != registration.owner) { missing.add("facet-owner-mismatch") }
            if (!provider.hasStateCodec) { missing.add("state-codec") }
            if (!provider.hasEffectRollback) { missing.add("effect-rollback") }
            if (!provider.hasReadEvidence) { missing.add("read-evidence") }
            if (!provider.hasNodeCodec) { missing.add("node-codec") }
        } else {
            missing.add("provider")
        }
        this.missingFacets = missing.toArray()
        this.incrementalReady = missing.isEmpty()
        var evidence = ""
        if (let Some(proof) <- registration.isolation) {
            if (proof.verified) { evidence = proof.evidence }
        }
        this.isolationEvidence = evidence
        if (incrementalReady) {
            this.fallback = EditingFallbackScope.NoFallback
        } else {
            match (policy) {
                case Strict => this.fallback = EditingFallbackScope.Rejected
                case Compat =>
                    this.fallback = if (!evidence.isEmpty()) {
                        EditingFallbackScope.IsolatedUnit
                    } else {
                        EditingFallbackScope.Session
                    }
            }
        }
    }
}

public class EditingCapabilityPlan {
    public let policy: EditingPolicy
    // Capability inventory in stable display order, NOT an executable candidate
    // sequence. Real parsing must reuse the existing start-byte dispatch tables
    // (including bucket-before-any-nonblank semantics) and paragraph fallback.
    public let parsers: Array<EditingParserCapability>
    public let phases: Array<EditingPhaseRegistration>
    public let diagnostics: Array<EditingCapabilityDiagnostic>
    public let fingerprint: String
    public let accepted: Bool
    // accepted means the selected policy can handle this configuration. It
    // does not imply local execution: Compat may require a whole-session rebuild.
    public let fallback: EditingFallbackScope
    public let fullyIncrementalReady: Bool
    // Only a caller-declared complete configuration identity permits caching
    // this capability plan; this is not a syntax/result cache authorization.
    public let cacheable: Bool

    public EditingCapabilityPlan(registrations: ArrayList<EditingParserRegistration>,
        phaseRegistrations: ArrayList<EditingPhaseRegistration>,
        configurationIdentity: ArrayList<String>, policy: EditingPolicy,
        opaqueDerivedStages!: Int64 = 0, identityComplete!: Bool = false) {
        this.policy = policy

        let capabilities = ArrayList<EditingParserCapability>()
        let messages = ArrayList<EditingCapabilityDiagnostic>()
        var canAccept = true
        var effectiveFallback = EditingFallbackScope.NoFallback
        let identity = ArrayList<String>()
        appendIdentity(identity, "markit-editing-plan-v1")
        match (policy) {
            case Compat => appendIdentity(identity, "compat")
            case Strict => appendIdentity(identity, "strict")
        }
        appendIdentity(identity, configurationIdentity.size.toString())
        for (component in configurationIdentity) { appendIdentity(identity, component) }
        appendIdentity(identity, registrations.size.toString())
        for (registration in registrations) {
            let capability = EditingParserCapability(registration, policy)
            capabilities.add(capability)
            if (capability.fallback == EditingFallbackScope.Rejected) {
                effectiveFallback = EditingFallbackScope.Rejected
            } else if (capability.fallback == EditingFallbackScope.Session &&
                effectiveFallback != EditingFallbackScope.Rejected) {
                effectiveFallback = EditingFallbackScope.Session
            } else if (capability.fallback == EditingFallbackScope.IsolatedUnit &&
                effectiveFallback == EditingFallbackScope.NoFallback) {
                effectiveFallback = EditingFallbackScope.IsolatedUnit
            }
            appendIdentity(identity, registration.category)
            appendIdentity(identity, registration.owner)
            appendIdentity(identity, registration.parserName)
            appendIdentity(identity, registration.priority.toString())
            appendIdentity(identity, registration.registrationOrder.toString())
            appendIdentity(identity, registration.enabled.toString())
            appendIdentity(identity, String.join(capability.missingFacets, delimiter: ","))
            appendIdentity(identity, capability.isolationEvidence)
            if (let Some(provider) <- registration.facet) {
                appendIdentity(identity, "provider")
                appendIdentity(identity, provider.owner)
            } else {
                appendIdentity(identity, "no-provider")
            }
            if (!capability.incrementalReady) {
                let reason = "Missing capabilities: " + String.join(capability.missingFacets, delimiter: ",")
                messages.add(EditingCapabilityDiagnostic(registration.owner, registration.parserName,
                    registration.category, "parser-capability-missing", reason, capability.fallback))
                match (policy) {
                    case Strict => canAccept = false
                    case Compat => ()
                }
            }
        }
        if (opaqueDerivedStages > 0) {
            let scope = match (policy) {
                case Strict => EditingFallbackScope.Rejected
                case Compat => EditingFallbackScope.Session
            }
            messages.add(EditingCapabilityDiagnostic("registry", "legacy-derived-stages", "phase",
                "derived-provider-missing", "${opaqueDerivedStages} legacy derived stages have no editing provider", scope))
            effectiveFallback = scope
            match (policy) {
                case Strict => canAccept = false
                case Compat => ()
            }
        }
        appendIdentity(identity, opaqueDerivedStages.toString())
        let ordered = compilePhases(phaseRegistrations, messages)
        if (ordered.size != phaseRegistrations.size) { canAccept = false }
        // Preserve declarations, including malformed graphs, in the identity.
        appendIdentity(identity, phaseRegistrations.size.toString())
        for (phase in phaseRegistrations) {
            appendIdentity(identity, phase.id)
            appendIdentity(identity, phase.owner)
            appendIdentity(identity, phase.version)
            appendIdentity(identity, phase.dependencies.size.toString())
            for (dependency in phase.dependencies) { appendIdentity(identity, dependency) }
        }
        this.parsers = capabilities.toArray()
        this.phases = ordered.toArray()
        this.diagnostics = messages.toArray()
        this.fingerprint = String.join(identity.toArray(), delimiter: "")
        this.accepted = canAccept
        this.fallback = if (canAccept) { effectiveFallback } else { EditingFallbackScope.Rejected }
        this.fullyIncrementalReady = canAccept && this.fallback == EditingFallbackScope.NoFallback
        this.cacheable = canAccept && identityComplete
    }

    public func requireAccepted(): Unit {
        if (!accepted) {
            throw IllegalArgumentException("Editing plan rejected; inspect capability diagnostics before creating an editing session")
        }
    }

    private static func appendIdentity(parts: ArrayList<String>, value: String): Unit {
        // Length prefixing is collision-free for this canonical representation;
        // this is a cache identity, not a cryptographic authenticity claim.
        parts.add("${value.size}:${value}")
    }

    private static func compilePhases(registrations: ArrayList<EditingPhaseRegistration>,
        messages: ArrayList<EditingCapabilityDiagnostic>): ArrayList<EditingPhaseRegistration> {
        let ordered = ArrayList<EditingPhaseRegistration>()
        var invalid = false
        for (index in 0..registrations.size) {
            let phase = registrations[index]
            if (phase.id.isEmpty() || phase.owner.isEmpty() || phase.version.isEmpty()) {
                messages.add(EditingCapabilityDiagnostic(phase.owner, phase.id, "phase",
                    "phase-identity-missing", "Phase id, owner and version must be explicit", EditingFallbackScope.Rejected))
                invalid = true
            }
            for (previous in 0..index) {
                if (registrations[previous].id == phase.id) {
                    messages.add(EditingCapabilityDiagnostic(phase.owner, phase.id, "phase",
                        "phase-duplicate", "Duplicate phase id: ${phase.id}", EditingFallbackScope.Rejected))
                    invalid = true
                }
            }
            for (dependency in phase.dependencies) {
                var found = false
                for (candidate in registrations) {
                    if (candidate.id == dependency) { found = true; break }
                }
                if (!found) {
                    messages.add(EditingCapabilityDiagnostic(phase.owner, phase.id, "phase",
                        "phase-dependency-missing", "Missing phase dependency: ${dependency}", EditingFallbackScope.Rejected))
                    invalid = true
                }
            }
        }
        if (invalid) { return ordered }
        while (ordered.size < registrations.size) {
            var progressed = false
            // Pick one earliest ready registration, then restart. This keeps
            // registration order stable even when a later declaration unlocks.
            for (phase in registrations) {
                var alreadyAdded = false
                for (done in ordered) { if (done.id == phase.id) { alreadyAdded = true; break } }
                if (alreadyAdded) { continue }
                var ready = true
                for (dependency in phase.dependencies) {
                    var complete = false
                    for (done in ordered) { if (done.id == dependency) { complete = true; break } }
                    if (!complete) { ready = false; break }
                }
                if (ready) { ordered.add(phase); progressed = true; break }
            }
            if (!progressed) {
                messages.add(EditingCapabilityDiagnostic("registry", "phase-dag", "phase",
                    "phase-cycle", "Editing phase dependency graph contains a cycle", EditingFallbackScope.Rejected))
                return ordered
            }
        }
        return ordered
    }
}
