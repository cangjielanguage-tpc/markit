package markit.plugins.standard.inline.reference_link

import markit.core.inline.InlineUtils
import markit.core.plugin.{NodeEmissionFilter, Plugin, PluginRegistrar}
import markit.core.nodes.{Node, TextNode}
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.core.session.{ParseSession, SessionStateKey}
import markit.plugins.standard.inline.image.ImageNode
import markit.plugins.standard.inline.link.LinkNode

public class ReferenceLinkPlugin <: Plugin {
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
        registrar.registerInlineParser(ReferenceLinkParser())
        registrar.registerInlineParser(ImageReferenceParser())
        registrar.registerNodeEmissionFilter(LinkDefinitionEmissionFilter())
        registrar.registerHtmlRenderer("LinkDefinition", LinkDefinitionHtmlRenderer())
        registrar.registerMarkdownRenderer("LinkDefinition", LinkDefinitionMarkdownRenderer())
        registrar.registerTypstRenderer("LinkDefinition", LinkDefinitionTypstRenderer())
        registrar.registerSessionFinalizeProcessor(resolveForwardReferences)
    }

    private static func resolveForwardReferences(session: ParseSession): Unit {
        let state = session.symbolTables.get(ReferenceLinkPlugin.stateKey.dynamicName)
        if (state.isNone()) {
            return
        }
        if (let registry: ReferenceLinkRegistry <- state.getOrThrow()) {
            walkAndResolve(session.root, registry, session)
        }
    }

    private static func walkAndResolve(node: Node, registry: ReferenceLinkRegistry, session: ParseSession): Bool {
        var changed = false
        var index: Int64 = 0
        while (index < node.children.size) {
            let child = node.children[index]
            var resolvedChild = child
            if (let link: LinkNode <- child) {
                let label = link.string("refLabel")
                if (label.isSome()) {
                    let def = registry.getDefinition(label.getOrThrow())
                    if (def.isSome()) {
                        link.url = def.getOrThrow().url
                        link.title = InlineUtils.processEscapes(def.getOrThrow().title)
                        link.removeString("refLabel")
                        changed = true
                    } else {
                        resolvedChild = unresolvedReferenceText(link, node)
                        node.children[index] = resolvedChild
                        changed = true
                    }
                }
            } else if (let image: ImageNode <- child) {
                let label = image.string("refLabel")
                if (label.isSome()) {
                    let def = registry.getDefinition(label.getOrThrow())
                    if (def.isSome()) {
                        image.src = def.getOrThrow().url
                        image.title = InlineUtils.processEscapes(def.getOrThrow().title)
                        image.removeString("refLabel")
                        changed = true
                    } else {
                        resolvedChild = unresolvedReferenceText(image, node)
                        node.children[index] = resolvedChild
                        changed = true
                    }
                }
            }
            if (walkAndResolve(resolvedChild, registry, session)) {
                changed = true
            }
            index += 1
        }
        if (changed) {
            if (let Some(target) <- patchTarget(node)) {
                session.patches.replace(target)
            }
        }
        return changed
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
