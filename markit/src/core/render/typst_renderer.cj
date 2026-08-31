package markit.core.render

import markit.core.nodes.Node

public interface TypstRenderer {
    prop ownerPlugin: String
    func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit
}

public class TypstRendererRegistration {
    public let kind: String
    public let renderer: TypstRenderer

    public init(kind: String, renderer: TypstRenderer) {
        this.kind = kind
        this.renderer = renderer
    }
}
