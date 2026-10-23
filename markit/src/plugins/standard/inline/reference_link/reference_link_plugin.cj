package markit.plugins.standard.inline.reference_link

import markit.core.inline.InlineUtils
import markit.core.plugin.{NodeEmissionFilter, Plugin, PluginRegistrar}
import markit.core.nodes.{Node, TextNode}
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.core.session.{ParseSession, SessionStateKey}
import markit.plugins.standard.inline.image.ImageNode
import markit.plugins.standard.inline.link.LinkNode

public class ReferenceLinkPlugin <: Plugin {
    private let referenceParser: ReferenceLinkParser
    private let imageParser: ImageReferenceParser
    public init() { referenceParser = ReferenceLinkParser(); imageParser = ImageReferenceParser() }
    public init(referenceParser: ReferenceLinkParser, imageParser: ImageReferenceParser) {
        this.referenceParser = referenceParser; this.imageParser = imageParser
    }
    public static let stateKey = SessionStateKey<ReferenceLinkRegistry>("ReferenceLinkPlugin", "registry")

    public prop name: String {
        get() {
            return "ReferenceLinkPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerState(ReferenceLinkPlugin.stateKey, { => ReferenceLinkRegistry() })
        registrar.registerLeafBlockParser(LinkDefinitionParser())
        registrar.registerInlineParser(referenceParser)
        registrar.registerInlineParser(imageParser)
        registrar.registerNodeEmissionFilter(LinkDefinitionEmissionFilter())
        registrar.registerHtmlRenderer("LinkDefinition", LinkDefinitionHtmlRenderer())
        registrar.registerMarkdownRenderer("LinkDefinition", LinkDefinitionMarkdownRenderer())
        registrar.registerTypstRenderer("LinkDefinition", LinkDefinitionTypstRenderer())
        registrar.registerSessionFinalizeProcessor(resolveForwardReferences)
        registrar.registerEditingPhase("standard.reference.definitions", name, version: "1")
        registrar.registerEditingPhase("standard.reference.views", name,
            dependencies: ["standard.reference.definitions"], version: "1")
    }

    private static func resolveForwardReferences(session: ParseSession): Unit {
        let state = session.symbolTables.get(ReferenceLinkPlugin.stateKey.dynamicName)
        if (state.isNone()) {
            return
        }
        if (let registry: ReferenceLinkRegistry <- state.getOrThrow()) {
            // The parser already owns the complete reference index. Finalize
            // never searches unrelated subtrees or removes the original label.
            for (node in registry.getUnresolvedRefs()) { resolveIndexed(node, registry, session) }
            for (node in registry.getUnresolvedImages()) { resolveIndexed(node, registry, session) }
        }
    }

    private static func resolveIndexed(node: Node, registry: ReferenceLinkRegistry, session: ParseSession): Unit {
        let label = node.string("refLabel")
        if (label.isNone()) { return }
        let def = registry.getDefinition(label.getOrThrow())
        if (let Some(value) <- def) {
            if (let link: LinkNode <- node) { link.url = value.url; link.title = InlineUtils.processEscapes(value.title) }
            if (let image: ImageNode <- node) { image.src = value.url; image.title = InlineUtils.processEscapes(value.title) }
        } else if (let Some(parent) <- node.parent) {
            var index: Int64 = 0
            while (index < parent.children.size) {
                if (refEq(parent.children[index], node)) {
                    let text = unresolvedReferenceText(node, parent)
                    session.attachNode(text)
                    parent.children[index] = text
                    break
                }
                index += 1
            }
        }
        if (let Some(target) <- patchTarget(node)) { session.patches.replace(target) }
    }

    private static func patchTarget(node: Node): ?Node {
        if (node.kind == "Document") {
            return None
        }
        var target = node
        while (let Some(parent) <- target.parent) {
            if (parent.kind == "Document") {
                return Some(target)
            }
            target = parent
        }
        return Some(target)
    }

    private static func unresolvedReferenceText(node: Node, parent: Node): TextNode {
        let text = TextNode(
            node.id,
            node.sourceSpan,
            InlineUtils.processEscapes(node.rawContent())
        )
        text.parent = Some(parent)
        for (key in ["refLabel", "refForm", "refRaw", "refText"]) {
            if (let Some(value) <- node.string(key)) { text.setString(key, value) }
        }
        text.setBool("refImage", node.bool("refImage") ?? false)
        return text
    }
}

private class LinkDefinitionEmissionFilter <: NodeEmissionFilter {
    public prop ownerPlugin: String {
        get() {
            return "ReferenceLinkPlugin"
        }
    }

    public func accept(session: ParseSession, node: Node): Bool {
        return node.kind != "LinkDefinition"
    }
}

private class LinkDefinitionHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ReferenceLinkPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
    }
}

private class LinkDefinitionMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ReferenceLinkPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
    }
}

private class LinkDefinitionTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "ReferenceLinkPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
    }
}
