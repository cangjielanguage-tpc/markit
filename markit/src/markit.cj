package markit

import markit.bundles.StandardMarkdownBundle
import markit.config.HtmlConfig as GlobalHtmlConfig
import markit.core.block.{BlockDispatchTable, BlockTreeBuilder, BlockParsingKernel, BlockEditingFacet, ContinuationBlockDispatchTable, ParagraphBlockParser}
import markit.core.inline.{InlineParserEngine, InlineParser, InlineEditingFacet}
import markit.core.document.DocumentSnapshot
import markit.core.incremental.{IncrementalSession, IncrementalUpdate, DocumentEditingSession}
import markit.core.nodes.{Node, NodeCodec}
import markit.core.plugin.{Bundle, EditingCapabilityPlan, NodeBatchProcessor, NodeEmissionFilter, Plugin, PluginRegistry}
import markit.core.editing.{EditingPolicy, EditableSourceVersion}
import markit.core.session.{ParagraphTermination, ParseOptions, ParseSession, SessionSymbolTableStore}
import markit.core.source.{SourceBuffer, SourceLine, SourceSpan, EditableRopeStore}
import std.collection.ArrayList
import std.io.InputStream

private func executableInlineFacet(parser: InlineParser): ?InlineEditingFacet {
    if (!parser.supportsIncremental) { return None }
    if (let Some(declared) <- parser.incrementalFacet) {
        if (let Some(facet) <- (declared as InlineEditingFacet)) {
            if (!facet.owner.isEmpty() && facet.owner == parser.ownerPlugin && !facet.grammarVersion.isEmpty() &&
                facet.hasStateCodec && facet.hasEffectRollback && facet.hasReadEvidence && facet.hasNodeCodec &&
                (facet as Object).isSome()) { return Some(facet) }
        }
    }
    return None
}

private func inlineExecutionMatches(parsers: Array<InlineParser>, facets: Array<InlineEditingFacet>,
    grammars: Array<String>): Bool {
    if (parsers.size != facets.size || facets.size != grammars.size) { return false }
    for (i in 0..parsers.size) {
        let current = executableInlineFacet(parsers[i])
        if (current.isNone()) { return false }
        let actual = current.getOrThrow()
        if (!refEq((actual as Object).getOrThrow(), (facets[i] as Object).getOrThrow()) ||
            actual.grammarVersion != grammars[i]) { return false }
    }
    return true
}

public class Markit {
    private var registry: PluginRegistry
    private var pendingDefaultStandardBundle: Bool = false
    private var runtimePlan: ?MarkitRuntimePlan = None

    public Markit(useStandard!: Bool = true) {
        registry = PluginRegistry()
        if (useStandard) {
            pendingDefaultStandardBundle = true
        }
    }

    public init(bundle: Bundle) {
        registry = PluginRegistry()
        registry.register(bundle)
    }

    public init(plugin: Plugin) {
        registry = PluginRegistry()
        registry.register(plugin)
    }

    public static func empty(): Markit {
        return Markit(useStandard: false)
    }

    public func use(plugin: Plugin): Markit {
        ensureDefaultBundleRegistered()
        registry.register(plugin)
        runtimePlan = None
        return this
    }

    public func use(bundle: Bundle): Markit {
        if (pendingDefaultStandardBundle && bundle.includesStandardMarkdown) {
            pendingDefaultStandardBundle = false
        } else {
            ensureDefaultBundleRegistered()
        }
        registry.register(bundle)
        runtimePlan = None
        return this
    }

    public func createSession(options!: ParseOptions = ParseOptions()): IncrementalSession {
        let plan = ensureRuntimePlan()
        let parseSession = createParserSession(plan, options, SourceBuffer(retentionMode: options.sourceRetentionMode))
        let incrementalSession = IncrementalSession(
            parseSession,
            plan.continuationDispatchTable,
            plan.blockDispatchTable,
            plan.paragraphBlockParsers,
            plan.nodeEmissionFilters,
            registry.createRenderRegistry(htmlConfig: GlobalHtmlConfig.snapshot())
        )
        for (processor in plan.postFinalizeProcessors) {
            incrementalSession.addPostFinalizeHook(processor)
        }
        for (processor in plan.sessionFinalizeProcessors) {
            incrementalSession.addSessionFinalizeHook(processor)
        }
        return incrementalSession
    }

    private func createParserSession(plan: MarkitRuntimePlan, options: ParseOptions,
        source: SourceBuffer, editing!: Bool = false): ParseSession {
        let parseSession = ParseSession(source, options, registry.createSymbolTables(checkpointEnabled: editing))
        parseSession.setInlineParser({
            session: ParseSession,
            text: String,
            span: SourceSpan =>
            plan.inlineParserEngine.parse(session, text, span)
        })
        parseSession.setInlineRangeParser({
            session: ParseSession,
            text: String,
            startByte: Int64,
            endByte: Int64,
            span: SourceSpan =>
            plan.inlineParserEngine.parseRange(session, text, startByte, endByte, span)
        })
        parseSession.setDetachedBlockParser({ lines: ArrayList<SourceLine> =>
            var nodes = BlockTreeBuilder.parseLines(
                parseSession,
                plan.continuationDispatchTable,
                plan.blockDispatchTable,
                plan.paragraphBlockParsers,
                lines
            )
            for (processor in plan.nodeBatchProcessors) {
                nodes = processor.process(parseSession, nodes)
            }
            nodes
        }, sandboxedStates: editing)
        parseSession.setRegisteredBlockStartDetector({
            session: ParseSession,
            line: String =>
            for (parser in plan.continuationDispatchTable.candidatesFor(line)) {
                if (parser.tryStart(session, line).isSome()) {
                    return true
                }
            }
            return false
        }, sandboxed: editing)
        parseSession.setParagraphNodeFactory({
            lines: ArrayList<SourceLine>,
            sourceSpan: SourceSpan,
            termination: ParagraphTermination =>
            if (plan.paragraphBlockParsers.isEmpty()) {
                let parts = ArrayList<String>()
                for (line in lines) {
                    parts.add(line.text)
                }
                parseSession.createNodeWithSpan(
                    "Paragraph",
                    sourceSpan,
                    literal: String.join(parts.toArray(), delimiter: "\n")
                )
            } else {
                plan.paragraphBlockParsers[0].finalize(parseSession, lines, sourceSpan, termination)
            }
        })
        return parseSession
    }

    public func createEditingSession(documentId: String, text: String, codec: NodeCodec,
        policy!: EditingPolicy = EditingPolicy.Compat): DocumentEditingSession {
        let candidateRegistry = if (pendingDefaultStandardBundle) {
            let candidate = PluginRegistry(); candidate.register(StandardMarkdownBundle()); candidate
        } else { registry }
        let capability = candidateRegistry.createEditingPlan(policy: policy, freezeOnAccepted: false)
        capability.requireAccepted()
        let providers = ArrayList<BlockEditingFacet>()
        var executable = capability.fullyIncrementalReady
        for (entry in capability.parsers) {
            let requiresBlock = entry.registration.category != "inline"
            if (let Some(facet) <- entry.registration.facet) {
                if (let Some(block) <- (facet as BlockEditingFacet)) {
                    if (block.grammarVersion.isEmpty()) { executable = false }
                    var seen = false
                    let identity = block as Object
                    if (identity.isNone()) { executable = false }
                    for (provider in providers) {
                        let previous = provider as Object
                        if (identity.isSome() && previous.isSome() && refEq(identity.getOrThrow(), previous.getOrThrow())) { seen = true }
                    }
                    if (!seen) { providers.add(block) }
                } else if (requiresBlock) { executable = false }
            } else if (requiresBlock) { executable = false }
        }
        // The generic capability inventory cannot establish an executable
        // inline protocol. Inspect actual registrations without freezing or
        // creating a source/session, then freeze their object identities.
        let inlineParsers = candidateRegistry.inlineParsersForEditing()
        let inlineFacets = ArrayList<InlineEditingFacet>()
        let inlineGrammars = ArrayList<String>()
        for (parser in inlineParsers) {
            if (let Some(facet) <- executableInlineFacet(parser)) {
                inlineFacets.add(facet); inlineGrammars.add(facet.grammarVersion)
            } else { executable = false }
        }
        let frozenInlineFacets = inlineFacets.toArray()
        let frozenInlineGrammars = inlineGrammars.toArray()
        if (executable && !inlineExecutionMatches(inlineParsers, frozenInlineFacets, frozenInlineGrammars)) { executable = false }
        if (!executable && policy == EditingPolicy.Strict) {
            throw IllegalArgumentException("Strict editing requires executable block and inline recovery facets")
        }
        if (pendingDefaultStandardBundle) { registry = candidateRegistry; pendingDefaultStandardBundle = false }
        let plan = ensureRuntimePlan()
        let source = EditableRopeStore(documentId, text: text)
        let parser = createParserSession(plan, ParseOptions(emitHtmlFragments: false, emitPreview: false),
            SourceBuffer(editableSource: Some(source.current)), editing: executable)
        let fallback: ?(EditableSourceVersion) -> DocumentSnapshot = if (executable) { None } else {
            Some({ version: EditableSourceVersion => this.parse(version.sliceBytes(0, version.byteLength)).snapshot })
        }
        let validateExecution: ?() -> Unit = if (executable) {
            Some({ =>
                if (!inlineExecutionMatches(inlineParsers, frozenInlineFacets, frozenInlineGrammars)) {
                    throw IllegalArgumentException("Editing inline execution identity changed")
                }
            })
        } else { Option<() -> Unit>.None }
        return DocumentEditingSession(source, parser,
            { session: ParseSession => BlockParsingKernel(session, plan.continuationDispatchTable,
                plan.blockDispatchTable, plan.paragraphBlockParsers, trimNormalizedSpan: false) },
            providers.toArray(), codec, fallbackParser: fallback, validateExecution: validateExecution)
    }

    // Editing records are opt-in. Batch parse, append and ensureRuntimePlan do
    // not call this API or inspect parser editing providers.
    public func createEditingPlan(policy!: EditingPolicy = EditingPolicy.Compat,
        grammarVersion!: String = "1", configurationVersion!: String = "unspecified"): EditingCapabilityPlan {
        if (pendingDefaultStandardBundle) {
            // A rejected strict request must not publish the lazy default bundle
            // or change later .use(StandardMarkdownBundle(...)) replacement.
            let candidate = PluginRegistry()
            candidate.register(StandardMarkdownBundle())
            let plan = candidate.createEditingPlan(policy: policy, grammarVersion: grammarVersion,
                configurationVersion: configurationVersion)
            if (plan.accepted) {
                registry = candidate
                pendingDefaultStandardBundle = false
            }
            return plan
        }
        return registry.createEditingPlan(policy: policy, grammarVersion: grammarVersion,
            configurationVersion: configurationVersion)
    }

    public func getEditingPlan(policy!: EditingPolicy = EditingPolicy.Compat,
        grammarVersion!: String = "1", configurationVersion!: String = "unspecified"): EditingCapabilityPlan {
        return createEditingPlan(policy: policy, grammarVersion: grammarVersion,
            configurationVersion: configurationVersion)
    }

    public func parse(markdown: String): ParseOutput {
        let session = createSession(options: batchParseOptions())
        session.feed(markdown)
        let finalUpdate = session.finalize()
        return ParseOutput(session.snapshot(), finalUpdate, session.symbolTables(), session.renderer())
    }

    public func parse(input: InputStream): ParseOutput {
        let session = createSession(options: batchParseOptions())
        var buffer = Array<Byte>(8192, repeat: 0)

        while (true) {
            let readLen = input.read(buffer)
            if (readLen == 0) {
                break
            }
            session.feedBytes(buffer.slice(0, readLen))
        }

        let finalUpdate = session.finalize()
        return ParseOutput(session.snapshot(), finalUpdate, session.symbolTables(), session.renderer())
    }

    public func renderHtml(markdown: String): String {
        let session = createSession(options: batchParseOptions())
        session.feed(markdown)
        session.finalize()
        return session.toHtml()
    }

    public func parseWithCallbacks(markdown: String, callbacks: ParseCallbacks): ParseOutput {
        let session = createSession()
        let update = session.feed(markdown)
        dispatchUpdate(callbacks, update)

        let finalUpdate = session.finalize()
        dispatchUpdate(callbacks, finalUpdate)
        let snapshot = session.snapshot()
        callbacks.onFinalize(snapshot)
        return ParseOutput(snapshot, finalUpdate, session.symbolTables(), session.renderer())
    }

    public func parseWithCallbacks(input: InputStream, callbacks: ParseCallbacks): ParseOutput {
        let session = createSession()
        var buffer = Array<Byte>(8192, repeat: 0)

        while (true) {
            let readLen = input.read(buffer)
            if (readLen == 0) {
                break
            }
            let update = session.feedBytes(buffer.slice(0, readLen))
            dispatchUpdate(callbacks, update)
        }

        let finalUpdate = session.finalize()
        dispatchUpdate(callbacks, finalUpdate)
        let snapshot = session.snapshot()
        callbacks.onFinalize(snapshot)
        return ParseOutput(snapshot, finalUpdate, session.symbolTables(), session.renderer())
    }

    private func dispatchUpdate(callbacks: ParseCallbacks, update: IncrementalUpdate): Unit {
        callbacks.onUpdate(update)
        for (node in update.sealedBlocks) {
            callbacks.onBlockSealed(node)
        }
        for (fragment in update.emittedHtmlFragments) {
            callbacks.onHtmlFragment(fragment)
        }
        for (patch in update.astPatches) {
            callbacks.onAstPatch(patch)
        }
        callbacks.onTailChanged(update.pendingTailState)
    }

    private func ensureDefaultBundleRegistered(): Unit {
        if (!pendingDefaultStandardBundle) {
            return
        }
        registry.register(StandardMarkdownBundle())
        pendingDefaultStandardBundle = false
    }

    private func batchParseOptions(): ParseOptions {
        return ParseOptions(emitHtmlFragments: false, emitPreview: false)
    }

    private func ensureRuntimePlan(): MarkitRuntimePlan {
        match (runtimePlan) {
            case Some(plan) => return plan
            case None =>
                ensureDefaultBundleRegistered()
                let plan = MarkitRuntimePlan(
                    registry.createContinuationBlockDispatchTable(),
                    registry.createBlockDispatchTable(),
                    InlineParserEngine(registry.createInlineDispatchTable()),
                    registry.getParagraphBlockParsers(),
                    registry.getNodeBatchProcessors(),
                    registry.getNodeEmissionFilters(),
                    registry.getSessionFinalizeProcessors(),
                    registry.getPostFinalizeProcessors()
                )
                runtimePlan = Some(plan)
                return plan
        }
    }
}

class MarkitRuntimePlan {
    let continuationDispatchTable: ContinuationBlockDispatchTable
    let blockDispatchTable: BlockDispatchTable
    let inlineParserEngine: InlineParserEngine
    let paragraphBlockParsers: ArrayList<ParagraphBlockParser>
    let nodeBatchProcessors: ArrayList<NodeBatchProcessor>
    let nodeEmissionFilters: ArrayList<NodeEmissionFilter>
    let sessionFinalizeProcessors: ArrayList<(ParseSession) -> Unit>
    let postFinalizeProcessors: ArrayList<(Node, SessionSymbolTableStore) -> Unit>

    MarkitRuntimePlan(
        continuationDispatchTable: ContinuationBlockDispatchTable,
        blockDispatchTable: BlockDispatchTable,
        inlineParserEngine: InlineParserEngine,
        paragraphBlockParsers: ArrayList<ParagraphBlockParser>,
        nodeBatchProcessors: ArrayList<NodeBatchProcessor>,
        nodeEmissionFilters: ArrayList<NodeEmissionFilter>,
        sessionFinalizeProcessors: ArrayList<(ParseSession) -> Unit>,
        postFinalizeProcessors: ArrayList<(Node, SessionSymbolTableStore) -> Unit>
    ) {
        this.continuationDispatchTable = continuationDispatchTable
        this.blockDispatchTable = blockDispatchTable
        this.inlineParserEngine = inlineParserEngine
        this.paragraphBlockParsers = paragraphBlockParsers
        this.nodeBatchProcessors = nodeBatchProcessors
        this.nodeEmissionFilters = nodeEmissionFilters
        this.sessionFinalizeProcessors = sessionFinalizeProcessors
        this.postFinalizeProcessors = postFinalizeProcessors
    }
}
