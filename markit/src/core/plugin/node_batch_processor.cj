package markit.core.plugin

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.ParseSession

public interface NodeBatchProcessor {
    prop ownerPlugin: String
    func process(session: ParseSession, nodes: ArrayList<Node>): ArrayList<Node>
}
