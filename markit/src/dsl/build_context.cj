package markit.dsl

import std.collection.{ArrayList, HashMap}
import markit.bundles.GFMBundle
import markit.config.HtmlConfig as GlobalHtmlConfig
import markit.core.nodes.{DocumentNode, Node}
import markit.core.plugin.PluginRegistry
import markit.core.render.RenderRegistry
import markit.core.source.{SourceBuffer, SourceRetentionMode, SourceSpan}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.standard.block.heading.{HeadingClosableConfig, HeadingSessionState}
import markit.plugins.toc.TocPlugin

public class DslBuildContext {
    private var nextNodeId: Int64 = 1
    private var nextByteOffset: Int64 = 0
    private var nextRuneOffset: Int64 = 0
    private var nextFootnoteNumber: Int64 = 1
    private let footnoteNumbers = HashMap<String, Int64>()
    private let headingState: HeadingSessionState
    public let options: DslOptions
    public let renderer: RenderRegistry
    public let source: SourceBuffer

    public init(options!: DslOptions = DslOptions()) {
        this.options = options
        this.headingState = HeadingSessionState(
            numberingConfig: options.headingNumberingConfig,
            closableConfig: HeadingClosableConfig(),
            slugConfig: options.headingSlugConfig
        )
        this.renderer = createRenderer(options)
        this.source = SourceBuffer(retentionMode: SourceRetentionMode.None)
    }

    public func createRoot(): DocumentNode {
        let root = DocumentNode(source)
        root.attachRenderHooks(renderer)
        return root
    }

    public func allocateNodeId(): Int64 {
        let id = nextNodeId
        nextNodeId += 1
        return id
    }

    public func allocateSpan(text: String): SourceSpan {
        let startByte = nextByteOffset
        let startRune = nextRuneOffset
        nextByteOffset += text.size
        nextRuneOffset += countRunes(text)
        return SourceSpan(startByte, nextByteOffset, startRune, nextRuneOffset)
    }

    public func emptySpan(): SourceSpan {
        return SourceSpan(nextByteOffset, nextByteOffset, nextRuneOffset, nextRuneOffset)
    }

    public func spanForChildren(children: ArrayList<Node>, fallback: SourceSpan): SourceSpan {
        if (children.isEmpty()) {
            return fallback
        }

        var span = children[0].sourceSpan
        for (i in 1..children.size) {
            span = span.merge(children[i].sourceSpan)
        }
        return span
    }

    public func headingSlug(content: String): HeadingSlugData {
        let allocation = headingState.allocateSlug(content)
        return HeadingSlugData(
            allocation.baseSlug,
            allocation.uniqueSlug,
            allocation.occurrence,
            allocation.typstLabel
        )
    }

    public func headingNumber(level: Int64): String {
        return headingState.assignNumber(level)
    }

    public func footnoteNumber(id: String): Int64 {
        if (let Some(existing) <- footnoteNumbers.get(id)) {
            return existing
        }
        let number = nextFootnoteNumber
        nextFootnoteNumber += 1
        footnoteNumbers[id] = number
        return number
    }

    private static func createRenderer(options: DslOptions): RenderRegistry {
        let registry = PluginRegistry()
        registry.register(GFMBundle(
            headingNumberingConfig: options.headingNumberingConfig,
            headingSlugConfig: options.headingSlugConfig,
            linkConfig: options.linkConfig
        ))
        if (options.includeI18n) {
            registry.register(I18nPlugin())
        }
        if (options.includeToc) {
            registry.register(TocPlugin())
        }
        return registry.createRenderRegistry(htmlConfig: GlobalHtmlConfig.snapshot())
    }

    private static func countRunes(text: String): Int64 {
        var count: Int64 = 0
        for (_ in text.runes()) {
            count += 1
        }
        return count
    }
}

public class HeadingSlugData {
    public let baseSlug: String
    public let uniqueSlug: String
    public let occurrence: Int64
    public let typstLabel: String

    public init(baseSlug: String, uniqueSlug: String, occurrence: Int64, typstLabel: String) {
        this.baseSlug = baseSlug
        this.uniqueSlug = uniqueSlug
        this.occurrence = occurrence
        this.typstLabel = typstLabel
    }
}
