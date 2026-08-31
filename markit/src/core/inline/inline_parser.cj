package markit.core.inline

import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public interface InlineParser {
    prop name: String
    prop ownerPlugin: String
    prop priority: Int64
    prop startBytes: Array<Byte>

    func tryParse(
        session: ParseSession,
        input: String,
        startByte: Int64,
        endByte: Int64,
        baseSpan: SourceSpan
    ): ?InlineParseResult
}
