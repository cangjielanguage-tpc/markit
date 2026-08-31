package markit.plugins.standard.block.heading

import markit.core.nodes.Node
import markit.core.plugin.NodeEmissionFilter
import markit.core.session.ParseSession

public class HeadingNodeEmissionFilter <: NodeEmissionFilter {
    public prop ownerPlugin: String {
        get() {
            return "HeadingPlugin"
        }
    }

    public func accept(session: ParseSession, node: Node): Bool {
        let state = session.symbolTables.get(HeadingPlugin.stateKey)
        return state.acceptTopLevelNode(node)
    }
}
