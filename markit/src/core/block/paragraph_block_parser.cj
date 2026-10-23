package markit.core.block

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SourceSpan}
import markit.core.editing.{IncrementalParserFacet, ParserIsolationProof}

public interface ParagraphBlockParser {
    prop name: String
    prop ownerPlugin: String

    // Opt-in belongs to each parser; a plugin may register mixed capabilities.
    prop supportsIncremental: Bool { get() { return false } }
    prop incrementalFacet: ?IncrementalParserFacet { get() { return None } }
    prop incrementalIsolation: ?ParserIsolationProof { get() { return None } }

    func canStart(session: ParseSession, line: String): Bool
    func normalizeLine(session: ParseSession, line: String): String
    func finalize(
        session: ParseSession,
        lines: ArrayList<SourceLine>,
        sourceSpan: SourceSpan,
        termination: ParagraphTermination
    ): Node
}
