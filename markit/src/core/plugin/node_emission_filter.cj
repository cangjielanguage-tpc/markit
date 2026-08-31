package markit.core.plugin

import markit.core.nodes.Node
import markit.core.session.ParseSession

public interface NodeEmissionFilter {
    prop ownerPlugin: String
    func accept(session: ParseSession, node: Node): Bool
}
