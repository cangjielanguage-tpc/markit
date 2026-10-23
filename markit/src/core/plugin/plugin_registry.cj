package markit.core.plugin

import std.collection.ArrayList
import markit.core.block.{BlockDispatchTable, ContinuationBlockDispatchTable, ContinuationBlockParser, LeafBlockParser, ParagraphBlockParser}
import markit.core.inline.{InlineDispatchTable, InlineParser}
import markit.core.nodes.Node
import markit.core.render.{HtmlConfig, HtmlRendererRegistration, MarkdownRendererRegistration, RenderRegistry, TypstRendererRegistration}
import markit.core.session.{ParseSession, SessionSymbolTableStore}
import markit.core.editing.EditingPolicy

public class PluginRegistry {
    private let stateRegistrations = ArrayList<SessionStateRegistration>()
    private let leafBlockParsers = ArrayList<LeafBlockParser>()
    private let continuationBlockParsers = ArrayList<ContinuationBlockParser>()
    private let paragraphBlockParsers = ArrayList<ParagraphBlockParser>()
    private let inlineParsers = ArrayList<InlineParser>()
    private let nodeBatchProcessors = ArrayList<NodeBatchProcessor>()
    private let nodeEmissionFilters = ArrayList<NodeEmissionFilter>()
    private let htmlRenderers = ArrayList<HtmlRendererRegistration>()
    private let markdownRenderers = ArrayList<MarkdownRendererRegistration>()
    private let typstRenderers = ArrayList<TypstRendererRegistration>()
    private let sessionFinalizeProcessors = ArrayList<(ParseSession) -> Unit>()
    private let postFinalizeProcessors = ArrayList<(Node, SessionSymbolTableStore) -> Unit>()
    private var frozen: Bool = false
    private let registeredPlugins = ArrayList<Plugin>()
    private let registeredBundles = ArrayList<Bundle>()
    private var editingPhases: ?ArrayList<EditingPhaseRegistration> = None

    public func register(plugin: Plugin): Unit {
        if (frozen) {
            throw IllegalArgumentException("Cannot register plugin after registry freeze: ${plugin.name}")
        }
        let registrar = PluginRegistrar()
        plugin.register(registrar)
        registeredPlugins.add(plugin)
        if (let Some(phases) <- registrar.getEditingPhases()) {
            if (editingPhases.isNone()) { editingPhases = Some(ArrayList<EditingPhaseRegistration>()) }
            for (phase in phases) { editingPhases.getOrThrow().add(phase) }
        }
        for (registration in registrar.stateRegistrations) {
            stateRegistrations.add(registration)
        }
        for (parser in registrar.leafBlockParsers) {
            leafBlockParsers.add(parser)
        }
        for (parser in registrar.continuationBlockParsers) {
            continuationBlockParsers.add(parser)
        }
        for (parser in registrar.paragraphBlockParsers) {
            paragraphBlockParsers.add(parser)
        }
        for (parser in registrar.inlineParsers) {
            inlineParsers.add(parser)
        }
        for (processor in registrar.nodeBatchProcessors) {
            nodeBatchProcessors.add(processor)
        }
        for (filter in registrar.nodeEmissionFilters) {
            nodeEmissionFilters.add(filter)
        }
        for (renderer in registrar.htmlRenderers) {
            htmlRenderers.add(renderer)
        }
        for (renderer in registrar.markdownRenderers) {
            markdownRenderers.add(renderer)
        }
        for (renderer in registrar.typstRenderers) {
            typstRenderers.add(renderer)
        }
        for (processor in registrar.sessionFinalizeProcessors) {
            sessionFinalizeProcessors.add(processor)
        }
        for (processor in registrar.postFinalizeProcessors) {
            postFinalizeProcessors.add(processor)
        }
    }

    public func register(bundle: Bundle): Unit {
        for (plugin in bundle.plugins) {
            register(plugin)
        }
        // Empty bundles retain the legacy no-op behavior after freeze.
        if (!frozen) { registeredBundles.add(bundle) }
    }

    public func freeze(): Unit {
        frozen = true
    }

    public func createEditingPlan(policy!: EditingPolicy = EditingPolicy.Compat,
        grammarVersion!: String = "1", configurationVersion!: String = "unspecified",
        freezeOnAccepted!: Bool = true): EditingCapabilityPlan {
        let registrations = ArrayList<EditingParserRegistration>()
        // Inventory groups mirror pipeline categories; their priority order is
        // display-only. Execution still uses existing dispatch buckets (a leaf
        // start-byte bucket precedes any-nonblank candidates, not a global sort).
        let continuation = ArrayList<EditingParserRegistration>()
        for (index in 0..continuationBlockParsers.size) {
            let parser = continuationBlockParsers[index]
            insertEditingParser(continuation, EditingParserRegistration(parser.ownerPlugin,
                parser.name, "continuation", parser.priority, index, parser.supportsIncremental,
                parser.incrementalFacet, parser.incrementalIsolation))
        }
        for (entry in continuation) { registrations.add(entry) }
        let leaf = ArrayList<EditingParserRegistration>()
        for (index in 0..leafBlockParsers.size) {
            let parser = leafBlockParsers[index]
            insertEditingParser(leaf, EditingParserRegistration(parser.ownerPlugin,
                parser.name, "leaf", parser.priority, index, parser.supportsIncremental,
                parser.incrementalFacet, parser.incrementalIsolation))
        }
        for (entry in leaf) { registrations.add(entry) }
        for (index in 0..paragraphBlockParsers.size) {
            let parser = paragraphBlockParsers[index]
            registrations.add(EditingParserRegistration(parser.ownerPlugin, parser.name,
                "paragraph", 0, index, parser.supportsIncremental,
                parser.incrementalFacet, parser.incrementalIsolation))
        }
        let inline = ArrayList<EditingParserRegistration>()
        for (index in 0..inlineParsers.size) {
            let parser = inlineParsers[index]
            insertEditingParser(inline, EditingParserRegistration(parser.ownerPlugin,
                parser.name, "inline", parser.priority, index, parser.supportsIncremental,
                parser.incrementalFacet, parser.incrementalIsolation))
        }
        for (entry in inline) { registrations.add(entry) }
        let identity = ArrayList<String>()
        identity.add(grammarVersion)
        identity.add(configurationVersion)
        var completeIdentity = !grammarVersion.isEmpty() && !configurationVersion.isEmpty() &&
            configurationVersion != "unspecified"
        for (bundle in registeredBundles) {
            identity.add("bundle")
            identity.add(bundle.name)
            identity.add(bundle.version)
            if (bundle.name.isEmpty() || bundle.version.isEmpty()) { completeIdentity = false }
        }
        for (plugin in registeredPlugins) {
            identity.add("plugin")
            identity.add(plugin.name)
            identity.add(plugin.version)
            if (plugin.name.isEmpty() || plugin.version.isEmpty()) { completeIdentity = false }
        }
        let phases = ArrayList<EditingPhaseRegistration>()
        if (let Some(registered) <- editingPhases) {
            for (phase in registered) { phases.add(phase) }
        }
        let opaqueStages = nodeBatchProcessors.size + nodeEmissionFilters.size +
            sessionFinalizeProcessors.size + postFinalizeProcessors.size
        let plan = EditingCapabilityPlan(registrations, phases, identity, policy,
            opaqueDerivedStages: opaqueStages, identityComplete: completeIdentity)
        // Rejected strict/invalid plans do not even freeze registration state.
        // No source, session, ID allocator, provider or patch transaction exists.
        // Execution preflight may inspect the declarations before publishing
        // a registry; a later missing executable facet must remain atomic.
        if (plan.accepted && freezeOnAccepted) { freeze() }
        return plan
    }

    private func insertEditingParser(entries: ArrayList<EditingParserRegistration>,
        entry: EditingParserRegistration): Unit {
        entries.add(entry)
        var index = entries.size - 1
        while (index > 0 && entries[index].priority < entries[index - 1].priority) {
            let previous = entries[index - 1]
            entries[index - 1] = entries[index]
            entries[index] = previous
            index -= 1
        }
    }

    public func createSymbolTables(checkpointEnabled!: Bool = false): SessionSymbolTableStore {
        freeze()
        let store = SessionSymbolTableStore(checkpointEnabled: checkpointEnabled)
        for (registration in stateRegistrations) {
            store.registerErased(registration.dynamicName, { => registration.create() })
        }
        return store
    }

    public func getLeafBlockParsers(): ArrayList<LeafBlockParser> {
        freeze()
        return leafBlockParsers
    }

    public func createBlockDispatchTable(): BlockDispatchTable {
        freeze()
        let table = BlockDispatchTable()
        for (parser in leafBlockParsers) {
            table.register(parser)
        }
        return table
    }

    public func createContinuationBlockDispatchTable(): ContinuationBlockDispatchTable {
        freeze()
        let table = ContinuationBlockDispatchTable()
        for (parser in continuationBlockParsers) {
            table.register(parser)
        }
        return table
    }

    public func getParagraphBlockParsers(): ArrayList<ParagraphBlockParser> {
        freeze()
        return paragraphBlockParsers
    }

    // Execution preflight must inspect the registered instances without
    // freezing the registry before a Strict editing request can be accepted.
    public func inlineParsersForEditing(): Array<InlineParser> {
        return inlineParsers.toArray()
    }

    public func createInlineDispatchTable(): InlineDispatchTable {
        freeze()
        let table = InlineDispatchTable()
        for (parser in inlineParsers) {
            table.register(parser)
        }
        return table
    }

    public func getNodeBatchProcessors(): ArrayList<NodeBatchProcessor> {
        freeze()
        return nodeBatchProcessors
    }

    public func getNodeEmissionFilters(): ArrayList<NodeEmissionFilter> {
        freeze()
        return nodeEmissionFilters
    }

    public func getPostFinalizeProcessors(): ArrayList<(Node, SessionSymbolTableStore) -> Unit> {
        freeze()
        return postFinalizeProcessors
    }

    public func getSessionFinalizeProcessors(): ArrayList<(ParseSession) -> Unit> {
        freeze()
        return sessionFinalizeProcessors
    }

    public func createRenderRegistry(htmlConfig!: HtmlConfig = HtmlConfig()): RenderRegistry {
        freeze()
        let registry = RenderRegistry(htmlConfig: htmlConfig)
        for (registration in htmlRenderers) {
            registry.registerHtmlRenderer(registration.kind, registration.renderer)
        }
        for (registration in markdownRenderers) {
            registry.registerMarkdownRenderer(registration.kind, registration.renderer)
        }
        for (registration in typstRenderers) {
            registry.registerTypstRenderer(registration.kind, registration.renderer)
        }
        return registry
    }
}
