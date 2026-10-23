package markit.plugins.standard.block.heading

import markit.core.nodes.{Node, NodeCodec, TypedNodeCodec}

public class HeadingNodeCodec <: TypedNodeCodec {
    public prop codecName: String { get() { return "standard.heading.v1" } }
    public func accepts(node: Node): Bool { return node is HeadingNode }
    public func rawContentFollowsSource(_: Node): Bool { return true }
    public func createShallow(node: Node): Node {
        let heading = (node as HeadingNode).getOrThrow()
        if (let editing: EditingHeadingNode <- node) {
            return EditingHeadingNode(heading.id, heading.sourceSpan, heading.content, heading.level,
                editing.blockRecovery.getOrThrow(), slug: heading.slug, visible: editing.visible)
        }
        return HeadingNode(heading.id, heading.sourceSpan, heading.content, heading.level, slug: heading.slug)
    }
}

public func registerHeadingEditingCodecs(codec: NodeCodec): Unit { codec.register(HeadingNodeCodec()) }
