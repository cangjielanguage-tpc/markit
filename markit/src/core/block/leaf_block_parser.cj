package markit.core.block

import markit.core.nodes.Node
import markit.core.session.ParseSession

public interface LeafBlockParser {
    prop name: String
    prop ownerPlugin: String
    prop priority: Int64
    prop startBytes: Array<Byte>
    prop acceptsAnyNonBlank: Bool

    func tryParse(session: ParseSession, line: String): ?Node
}
