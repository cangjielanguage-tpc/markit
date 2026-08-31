package markit.plugins.anchor

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, RenderRegistry}

public class AnchorRenderUtils {
    public static func htmlAttributes(node: Node, registry: RenderRegistry): String {
        if (let Some(id) <- node.string("anchor.id")) {
            let escaped = HtmlEscaper.escape(id)
            return " id=\"${escaped}\" data-anchor-id=\"${escaped}\"${htmlSourceAttributes(node)} class=\"markit-anchor-target${registry.htmlClassSuffix(node)}\""
        }
        return registry.htmlClassAttribute(node)
    }

    public static func htmlClassAttribute(baseClass: String, node: Node, registry: RenderRegistry): String {
        let anchorClass = if (node.string("anchor.id").isSome()) { " markit-anchor-target" } else { "" }
        if (baseClass.isEmpty() && anchorClass.isEmpty()) {
            return registry.htmlClassAttribute(node)
        }
        let idAttr = if (let Some(id) <- node.string("anchor.id")) {
            let escaped = HtmlEscaper.escape(id)
            " id=\"${escaped}\" data-anchor-id=\"${escaped}\"${htmlSourceAttributes(node)}"
        } else {
            ""
        }
        return "${idAttr} class=\"${HtmlEscaper.escape(baseClass)}${anchorClass}${registry.htmlClassSuffix(node)}\""
    }

    public static func htmlSourceAttributes(node: Node): String {
        let startByte = node.int("anchor.sourceStartByte") ?? node.sourceSpan.startByte
        let endByte = node.int("anchor.sourceEndByte") ?? node.sourceSpan.endByte
        if (endByte <= startByte) {
            return ""
        }
        return " data-source-start-byte=\"${startByte}\" data-source-end-byte=\"${endByte}\""
    }

    public static func markdownLabel(node: Node): String {
        // Auto anchors are website metadata and should not leak into normalized Markdown.
        if (node.string("anchor.auto").isSome()) {
            return ""
        }
        if (let Some(id) <- node.string("anchor.id")) {
            return " {#${id}}"
        }
        return ""
    }

    public static func typstLabel(node: Node): String {
        if (let Some(id) <- node.string("anchor.id")) {
            return " <${id}>"
        }
        return ""
    }
}
