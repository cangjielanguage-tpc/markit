package markit.plugins.gfm.block.table

import markit.core.nodes.Node
import markit.core.plugin.NodeEmissionFilter
import markit.core.session.ParseSession

public class TableThreeLineDividerEmissionFilter <: NodeEmissionFilter {
    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public func accept(_: ParseSession, node: Node): Bool {
        return node.string("render") != Some("false")
    }
}
