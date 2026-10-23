package markit.core.inline

import markit.core.nodes.Node
import markit.core.nodes.PersistentNodeBundle

public open class InlineParseResult {
    public let node: Node
    public let consumedBytes: Int64
    public let consumedRunes: Int64

    public open prop rawReplacement: ?PersistentNodeBundle { get() { return None } }
    public open prop nested: ?InlineNestedOwner { get() { return None } }

    public InlineParseResult(node: Node, consumedBytes: Int64, consumedRunes: Int64) {
        this.node = node
        this.consumedBytes = consumedBytes
        this.consumedRunes = consumedRunes
    }
}

// The batch result retains its original three stored fields. Only an explicit
// editing result allocates the raw/recursive handoff references.
public class EditingInlineParseResult <: InlineParseResult {
    public EditingInlineParseResult(node: Node, consumedBytes: Int64, consumedRunes: Int64,
        private let raw: ?PersistentNodeBundle, private let recursive: ?InlineNestedOwner) {
        super(node, consumedBytes, consumedRunes)
    }
    public override prop rawReplacement: ?PersistentNodeBundle { get() { return raw } }
    public override prop nested: ?InlineNestedOwner { get() { return recursive } }
}
