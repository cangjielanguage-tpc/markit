package markit.plugins.standard.block.paragraph

import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.plugins.standard.inline.soft_break.{SoftBreakHtmlRenderer, SoftBreakMarkdownRenderer, SoftBreakParser, SoftBreakTypstRenderer}

public class ParagraphPlugin <: Plugin {
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
        registrar.registerParagraphBlockParser(ParagraphBlockParserImpl())
        registrar.registerInlineParser(SoftBreakParser())
        registrar.registerHtmlRenderer("Paragraph", ParagraphHtmlRenderer())
        registrar.registerMarkdownRenderer("Paragraph", ParagraphMarkdownRenderer())
        registrar.registerTypstRenderer("Paragraph", ParagraphTypstRenderer())
        registrar.registerHtmlRenderer("SoftBreak", SoftBreakHtmlRenderer())
        registrar.registerMarkdownRenderer("SoftBreak", SoftBreakMarkdownRenderer())
        registrar.registerTypstRenderer("SoftBreak", SoftBreakTypstRenderer())
    }
}
