package markit.plugins.standard.block.paragraph

import std.collection.ArrayList
import markit.core.block.ParagraphBlockParser
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SourceSpan}

public class ParagraphBlockParserImpl <: ParagraphBlockParser {
    public prop name: String {
        get() {
            return "ParagraphBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public func canStart(_: ParseSession, line: String): Bool {
        return !line.trimAscii().isEmpty()
    }

    public func normalizeLine(_: ParseSession, line: String): String {
        return line.trimAsciiStart()
    }

    public func finalize(
        session: ParseSession,
        lines: ArrayList<SourceLine>,
        sourceSpan: SourceSpan,
        termination: ParagraphTermination
    ): Node {
        let text = ParagraphChildrenBuilder.paragraphContent(lines)
        let node = session.attachNode(ParagraphNode(
            session.allocateNodeId(),
            sourceSpan,
            text
        ))
        ParagraphChildrenBuilder.appendChildren(session, node, lines, termination, content: text)
        return node
    }
}
