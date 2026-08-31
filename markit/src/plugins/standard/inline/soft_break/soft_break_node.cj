package markit.plugins.standard.inline.soft_break

import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class SoftBreakNode <: Node {
    public init(
        id: Int64,
        sourceSpan: SourceSpan
    ) {
        super("SoftBreak", id: id, sourceSpan: sourceSpan, literal: "\n")
    }

    public override prop name: String {
        get() {
            return "SoftBreakNode"
        }
    }
}
