package markit.core.block

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SourceSpan}

public interface ParagraphBlockParser {
    prop name: String
    prop ownerPlugin: String

    func canStart(session: ParseSession, line: String): Bool
    func normalizeLine(session: ParseSession, line: String): String
    func finalize(
        session: ParseSession,
        lines: ArrayList<SourceLine>,
        sourceSpan: SourceSpan,
        termination: ParagraphTermination
    ): Node
}
