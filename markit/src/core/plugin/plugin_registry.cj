package markit.core.plugin

import std.collection.ArrayList
import markit.core.block.{BlockDispatchTable, ContinuationBlockDispatchTable, ContinuationBlockParser, LeafBlockParser, ParagraphBlockParser}
import markit.core.inline.{InlineDispatchTable, InlineParser}
import markit.core.nodes.Node
import markit.core.render.{HtmlConfig, HtmlRendererRegistration, MarkdownRendererRegistration, RenderRegistry, TypstRendererRegistration}
import markit.core.session.{ParseSession, SessionSymbolTableStore}

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

    public func register(plugin: Plugin): Unit {
        if (frozen) {
            throw IllegalArgumentException("Cannot register plugin after registry freeze: ${plugin.name}")
        }
        let registrar = PluginRegistrar()
        plugin.register(registrar)
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
    }

    public func freeze(): Unit {
        frozen = true
    }

    public func createSymbolTables(): SessionSymbolTableStore {
        freeze()
        let store = SessionSymbolTableStore()
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
