package markit.core.block

import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.editing.{IncrementalParserFacet, ParserIsolationProof}

public interface LeafBlockParser {
    prop name: String
    prop ownerPlugin: String
    prop priority: Int64
    prop startBytes: Array<Byte>
    prop acceptsAnyNonBlank: Bool

    // Legacy parsers remain usable without implementing any editing methods.
    // A declaration alone does not supply checkpoint/rollback/codec behavior.
    prop supportsIncremental: Bool { get() { return false } }
    prop incrementalFacet: ?IncrementalParserFacet { get() { return None } }
    prop incrementalIsolation: ?ParserIsolationProof { get() { return None } }

    func tryParse(session: ParseSession, line: String): ?Node
}
