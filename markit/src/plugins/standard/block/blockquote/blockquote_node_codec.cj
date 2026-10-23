package markit.plugins.standard.block.blockquote

import markit.core.nodes.{Node, NodeCodec, TypedNodeCodec}

public class BlockquoteNodeCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "standard.blockquote.v1" } }
    public func accepts(node: Node): Bool { return node is BlockquoteNode }
    public func rawContentFollowsSource(node: Node): Bool { return !(node is EditingBlockquoteNode) }
    public func createShallow(node: Node): Node {
        if (let quotedNode: EditingBlockquoteNode <- node) {
            return EditingBlockquoteNode(quotedNode.id, quotedNode.sourceSpan, quotedNode.blockRecovery.getOrThrow(), quotedNode.editingProvider,
                quotedNode.rawView, quotedNode.parentQuoteDepth)
        }
        return BlockquoteNode(node.id, node.sourceSpan)
    }
}

public func registerBlockquoteEditingCodecs(codec: NodeCodec): Unit { codec.register(BlockquoteNodeCodec()) }
