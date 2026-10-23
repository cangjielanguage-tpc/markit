package markit.plugins.standard.inline.reference_link

import markit.core.nodes.{Node, NodeCodec, TypedNodeCodec}
import markit.plugins.standard.inline.link.LinkNode
import markit.plugins.standard.inline.image.ImageNode

private class ReferenceDefinitionCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "standard.reference-definition.v1" } }
    public func accepts(node: Node): Bool { return node is ReferenceDefinitionNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        let value = (node as ReferenceDefinitionNode).getOrThrow()
        return ReferenceDefinitionNode(value.id, value.sourceSpan, value.label, value.url, value.title,
            recovery: value.blockRecovery)
    }
}
private class ReferenceLinkCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "standard.reference-link-view.v1" } }
    public func accepts(node: Node): Bool { return node is LinkNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        let value = (node as LinkNode).getOrThrow()
        return LinkNode(value.id, value.sourceSpan, value.content, value.url, value.title)
    }
}
private class ReferenceImageCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "standard.reference-image-view.v1" } }
    public func accepts(node: Node): Bool { return node is ImageNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        let value = (node as ImageNode).getOrThrow()
        return ImageNode(value.id, value.sourceSpan, value.alt, value.src, value.title)
    }
}
public func registerReferenceEditingCodecs(codec: NodeCodec): Unit {
    codec.register(ReferenceDefinitionCodec()); codec.register(ReferenceLinkCodec()); codec.register(ReferenceImageCodec())
}
