package markit.plugins.standard.inline.link

import std.collection.ArrayList
import markit.core.nodes.Node

public class LinkRenderUtils {
    public static func extractText(node: Node): String {
        let parts = ArrayList<String>()
        extractText(node, parts)
        return String.join(parts.toArray())
    }

    private static func extractText(node: Node, parts: ArrayList<String>): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        if (node.kind == "Text" || node.kind == "InlineCode") {
            parts.add(node.literal)
            return
        }
        if (node.children.isEmpty() && !node.literal.isEmpty()) {
            parts.add(node.literal)
            return
        }
        for (child in node.children) {
            extractText(child, parts)
        }
    }
}
