package markit.core.inline

import markit.core.nodes.Node

public class InlineParseResult {
    public let node: Node
    public let consumedBytes: Int64
    public let consumedRunes: Int64

    public init(node: Node, consumedBytes: Int64, consumedRunes: Int64) {
        this.node = node
        this.consumedBytes = consumedBytes
        this.consumedRunes = consumedRunes
    }
}
