package markit.plugins.gfm.inline.footnote

import markit.core.nodes.Node
import markit.core.plugin.NodeEmissionFilter
import markit.core.session.ParseSession

public class FootnoteDefinitionEmissionFilter <: NodeEmissionFilter {
    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public func accept(_: ParseSession, node: Node): Bool {
        if (node.kind != "FootnoteDefinition") {
            return true
        }
        if (let Some(duplicate) <- node.bool("duplicateDefinition")) {
            return !duplicate
        }
        return true
    }
}
