package markit.core.render

import markit.core.nodes.Node

public interface MarkdownRenderer {
    prop ownerPlugin: String
    func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit
}

public class MarkdownRendererRegistration {
    public let kind: String
    public let renderer: MarkdownRenderer

    public init(kind: String, renderer: MarkdownRenderer) {
        this.kind = kind
        this.renderer = renderer
    }
}
