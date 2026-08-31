package markit.core.plugin

import std.collection.ArrayList
import markit.core.block.{ContinuationBlockParser, LeafBlockParser, ParagraphBlockParser}
import markit.core.inline.InlineParser
import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlRendererRegistration, MarkdownRenderer, MarkdownRendererRegistration, TypstRenderer, TypstRendererRegistration}
import markit.core.session.{ParseSession, SessionState, SessionStateKey, SessionSymbolTableStore}

public class SessionStateRegistration {
    public let dynamicName: String
    private let factory: () -> SessionState

    public init(dynamicName: String, factory: () -> SessionState) {
        this.dynamicName = dynamicName
        this.factory = factory
    }

    public func create(): SessionState {
        return factory()
    }
}

public class PluginRegistrar {
    public let stateRegistrations = ArrayList<SessionStateRegistration>()
    public let leafBlockParsers = ArrayList<LeafBlockParser>()
    public let continuationBlockParsers = ArrayList<ContinuationBlockParser>()
    public let paragraphBlockParsers = ArrayList<ParagraphBlockParser>()
    public let inlineParsers = ArrayList<InlineParser>()
    public let nodeBatchProcessors = ArrayList<NodeBatchProcessor>()
    public let nodeEmissionFilters = ArrayList<NodeEmissionFilter>()
    public let htmlRenderers = ArrayList<HtmlRendererRegistration>()
    public let markdownRenderers = ArrayList<MarkdownRendererRegistration>()
    public let typstRenderers = ArrayList<TypstRendererRegistration>()
    public let sessionFinalizeProcessors = ArrayList<(ParseSession) -> Unit>()
    public let postFinalizeProcessors = ArrayList<(Node, SessionSymbolTableStore) -> Unit>()

    public func registerState<T>(
        key: SessionStateKey<T>,
        factory: () -> T
    ): Unit where T <: SessionState {
        stateRegistrations.add(SessionStateRegistration(key.dynamicName, { => factory() }))
    }

    public func registerLeafBlockParser(parser: LeafBlockParser): Unit {
        leafBlockParsers.add(parser)
    }

    public func registerContinuationBlockParser(parser: ContinuationBlockParser): Unit {
        continuationBlockParsers.add(parser)
    }

    public func registerParagraphBlockParser(parser: ParagraphBlockParser): Unit {
        paragraphBlockParsers.add(parser)
    }

    public func registerInlineParser(parser: InlineParser): Unit {
        inlineParsers.add(parser)
    }

    public func registerNodeBatchProcessor(processor: NodeBatchProcessor): Unit {
        nodeBatchProcessors.add(processor)
    }

    public func registerNodeEmissionFilter(filter: NodeEmissionFilter): Unit {
        nodeEmissionFilters.add(filter)
    }

    public func registerHtmlRenderer(kind: String, renderer: HtmlRenderer): Unit {
        htmlRenderers.add(HtmlRendererRegistration(kind, renderer))
    }

    public func registerMarkdownRenderer(kind: String, renderer: MarkdownRenderer): Unit {
        markdownRenderers.add(MarkdownRendererRegistration(kind, renderer))
    }

    public func registerTypstRenderer(kind: String, renderer: TypstRenderer): Unit {
        typstRenderers.add(TypstRendererRegistration(kind, renderer))
    }

    public func registerSessionFinalizeProcessor(processor: (ParseSession) -> Unit): Unit {
        sessionFinalizeProcessors.add(processor)
    }

    public func registerPostFinalizeProcessor(processor: (Node, SessionSymbolTableStore) -> Unit): Unit {
        postFinalizeProcessors.add(processor)
    }
}
