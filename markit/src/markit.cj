package markit

import markit.bundles.StandardMarkdownBundle
import markit.config.HtmlConfig as GlobalHtmlConfig
import markit.core.block.{BlockDispatchTable, BlockTreeBuilder, ContinuationBlockDispatchTable, ParagraphBlockParser}
import markit.core.inline.InlineParserEngine
import markit.core.incremental.{IncrementalSession, IncrementalUpdate}
import markit.core.nodes.Node
import markit.core.plugin.{Bundle, NodeBatchProcessor, NodeEmissionFilter, Plugin, PluginRegistry}
import markit.core.session.{ParagraphTermination, ParseOptions, ParseSession, SessionSymbolTableStore}
import markit.core.source.{SourceBuffer, SourceLine, SourceSpan}
import std.collection.ArrayList
import std.io.InputStream

public class Markit {
    private let registry: PluginRegistry
    private var pendingDefaultStandardBundle: Bool = false
    private var runtimePlan: ?MarkitRuntimePlan = None

    public init(useStandard!: Bool = true) {
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
        let parseSession = ParseSession(
            SourceBuffer(retentionMode: options.sourceRetentionMode),
            options,
            registry.createSymbolTables()
        )
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
        })
        parseSession.setRegisteredBlockStartDetector({
            session: ParseSession,
            line: String =>
            for (parser in plan.continuationDispatchTable.candidatesFor(line)) {
                if (parser.tryStart(session, line).isSome()) {
                    return true
                }
            }
            return false
        })
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

    init(
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
