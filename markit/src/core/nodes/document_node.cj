package markit.core.nodes

import markit.core.source.SourceBuffer

public class DocumentNode <: Node {
    public DocumentNode(source: SourceBuffer) {
        super("Document")
        attachSource(source)
    }

    public override prop name: String {
        get() {
            return "DocumentNode"
        }
    }

    public override func rawContent(): String {
        if (let Some(raw) <- overriddenRawContent()) { return raw }
        if (let Some(source) <- source()) {
            return source.toDebugString()
        }
        return super.rawContent()
    }
}
