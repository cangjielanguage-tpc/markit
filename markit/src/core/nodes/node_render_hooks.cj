package markit.core.nodes

import std.io.OutputStream

public interface NodeRenderHooks {
    func toHtml(node: Node): String
    func toMarkdown(node: Node): String
    func toTypst(node: Node): String
    func writeHtml(node: Node, out: OutputStream): Unit
    func writeMarkdown(node: Node, out: OutputStream): Unit
    func writeTypst(node: Node, out: OutputStream): Unit
}
