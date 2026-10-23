package markit.plugins.standard.pilot

import markit.Markit
import markit.core.editing.EditingPolicy
import markit.core.incremental.{DocumentEditingSession, EditingDocumentSnapshot}
import markit.core.nodes.NodeCodec
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.plugins.standard.block.paragraph.*
import markit.plugins.standard.block.heading.*
import markit.plugins.standard.block.blockquote.*
import markit.plugins.standard.inline.soft_break.SoftBreakParser
import markit.plugins.standard.inline.reference_link.*
import markit.plugins.standard.inline.link.{LinkHtmlRenderer, LinkMarkdownRenderer, LinkTypstRenderer}
import markit.plugins.standard.inline.image.{ImageHtmlRenderer, ImageMarkdownRenderer, ImageTypstRenderer}
import markit.plugins.standard.editing.StandardInlinePlan

// The vertical slice registers real typed renderers without enabling unrelated
// inline grammars before their own adapter task has been verified.
private class PilotReferenceRenderers <: Plugin {
    public prop name: String { get() { return "StandardPilotReferenceRenderers" } }
    public prop version: String { get() { return "1" } }
    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerHtmlRenderer("Link", LinkHtmlRenderer())
        registrar.registerMarkdownRenderer("Link", LinkMarkdownRenderer())
        registrar.registerTypstRenderer("Link", LinkTypstRenderer())
        registrar.registerHtmlRenderer("Image", ImageHtmlRenderer())
        registrar.registerMarkdownRenderer("Image", ImageMarkdownRenderer())
        registrar.registerTypstRenderer("Image", ImageTypstRenderer())
    }
}
private class PilotConfiguration {
    public PilotConfiguration(public let app: Markit, public let codec: NodeCodec) {}
}
private func pilotConfiguration(numbering: Bool, closable: Bool): PilotConfiguration {
    let codec = NodeCodec()
    registerParagraphEditingCodecs(codec); registerHeadingEditingCodecs(codec)
    registerBlockquoteEditingCodecs(codec); registerReferenceEditingCodecs(codec)
    let reference = ReferenceLinkParser(); let image = ImageReferenceParser(); let softBreak = SoftBreakParser()
    let plan = StandardInlinePlan([reference, image, softBreak], codec)
    let app = Markit.empty().use(ParagraphPlugin(editingPlan: Some(plan), softBreakParser: softBreak))
        .use(HeadingPlugin(numberingConfig: HeadingNumberingConfig(enabled: numbering),
            closableConfig: HeadingClosableConfig(enabled: closable)))
        .use(ReferenceLinkPlugin(reference, image)).use(BlockquotePlugin()).use(PilotReferenceRenderers())
    return PilotConfiguration(app, codec)
}

public class StandardEditingPilot {
    public static func createSession(uri: String, text: String, numbering!: Bool = false,
        closable!: Bool = false): DocumentEditingSession {
        let configuration = pilotConfiguration(numbering, closable)
        return configuration.app.createEditingSession(uri, text, configuration.codec, policy: EditingPolicy.Strict)
    }
    // Explicit initial/fresh output only. Hot edits use renderChanges below.
    public static func render(snapshot: EditingDocumentSnapshot): String { return renderStandardPilotSnapshot(snapshot) }
    public static func renderChanges(snapshot: EditingDocumentSnapshot, previous!: ?EditingDocumentSnapshot = None): String {
        return renderStandardPilotChanges(snapshot, previous: previous)
    }
    public static func fresh(text: String, numbering!: Bool = false, closable!: Bool = false): String {
        return pilotConfiguration(numbering, closable).app.parse(text).html()
    }
}
