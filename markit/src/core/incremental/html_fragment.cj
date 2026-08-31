package markit.core.incremental

import markit.core.source.SourceSpan

public class HtmlFragment {
    public let nodeId: Int64
    public let sourceSpan: SourceSpan
    public let html: String
    public let stable: Bool

    public init(
        nodeId: Int64,
        sourceSpan: SourceSpan,
        html: String,
        stable: Bool
    ) {
        this.nodeId = nodeId
        this.sourceSpan = sourceSpan
        this.html = html
        this.stable = stable
    }
}
