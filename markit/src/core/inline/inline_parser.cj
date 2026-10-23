package markit.core.inline

import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.core.editing.{IncrementalParserFacet, ParserIsolationProof}

public interface InlineParser {
    prop name: String
    prop ownerPlugin: String
    prop priority: Int64
    prop startBytes: Array<Byte>

    // Missing read evidence/restore/effect support never silently becomes safe.
    prop supportsIncremental: Bool { get() { return false } }
    prop incrementalFacet: ?IncrementalParserFacet { get() { return None } }
    prop incrementalIsolation: ?ParserIsolationProof { get() { return None } }

    func tryParse(
        session: ParseSession,
        input: String,
        startByte: Int64,
        endByte: Int64,
        baseSpan: SourceSpan
    ): ?InlineParseResult
}
