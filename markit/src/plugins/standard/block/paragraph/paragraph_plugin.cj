package markit.plugins.standard.block.paragraph

import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.plugins.standard.inline.soft_break.{SoftBreakHtmlRenderer, SoftBreakMarkdownRenderer, SoftBreakParser, SoftBreakTypstRenderer}
import markit.core.nodes.NodeCodec
import markit.plugins.standard.editing.StandardInlinePlan

public class ParagraphPlugin <: Plugin {
    public ParagraphPlugin(private let editingPlan!: ?StandardInlinePlan = None,
        private let softBreakParser!: SoftBreakParser = SoftBreakParser()) {}
    public prop name: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0-scaffold"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        let factory = { =>
            if (let Some(plan) <- editingPlan) { return plan }
            let codec = NodeCodec(); registerParagraphEditingCodecs(codec)
            return StandardInlinePlan(registrar.inlineParsers.toArray(), codec)
        }
        let boundary = { => ParagraphBlockBoundary(registrar.leafBlockParsers.toArray(), registrar.continuationBlockParsers.toArray()) }
        registrar.registerParagraphBlockParser(ParagraphBlockParserImpl(planFactory: Some(factory), boundaryFactory: Some(boundary)))
        registrar.registerInlineParser(softBreakParser)
        registrar.registerHtmlRenderer("Paragraph", ParagraphHtmlRenderer())
        registrar.registerMarkdownRenderer("Paragraph", ParagraphMarkdownRenderer())
        registrar.registerTypstRenderer("Paragraph", ParagraphTypstRenderer())
        registrar.registerHtmlRenderer("SoftBreak", SoftBreakHtmlRenderer())
        registrar.registerMarkdownRenderer("SoftBreak", SoftBreakMarkdownRenderer())
        registrar.registerTypstRenderer("SoftBreak", SoftBreakTypstRenderer())
    }
}
