package markit.core.incremental

import markit.core.nodes.Node
import markit.core.source.SourceSpan

public enum AstPatchKind {
    | InsertNode
    | ReplaceNode
    | UpdateNode
    | UpdateNodeMeta
    | RemoveNode
}

public class AstPatch {
    public let kind: AstPatchKind
    public let parentNodeId: Int64
    public let nodeId: Int64
    public let sourceSpan: SourceSpan
    public let node: ?Node
    public let html: String
    public let markdown: String
    public let typst: String

    public init(
        kind: AstPatchKind,
        nodeId: Int64,
        sourceSpan: SourceSpan,
        parentNodeId!: Int64 = 0,
        node!: ?Node = None,
        html!: String = "",
        markdown!: String = "",
        typst!: String = ""
    ) {
        this.kind = kind
        this.parentNodeId = parentNodeId
        this.nodeId = nodeId
        this.sourceSpan = sourceSpan
        this.node = node
        this.html = html
        this.markdown = markdown
        this.typst = typst
    }
}
