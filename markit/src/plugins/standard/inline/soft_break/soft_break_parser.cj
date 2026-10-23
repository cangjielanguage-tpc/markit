package markit.plugins.standard.inline.soft_break

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.core.editing.*

public func matchesSoftBreak(read: (Int64) -> ?Byte, at: Int64): Bool {
    return read(at) == Some(b'\n')
}

public class SoftBreakParser <: InlineParser {
    private let facet = SoftBreakEditingFacet()
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public prop name: String {
        get() {
            return "SoftBreakParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 10
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'\n']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (!matchesSoftBreak({ at: Int64 => if (at < endByte) { Some(input[at]) } else { Option<Byte>.None } }, startByte)) {
            return None
        }

        let node = session.attachNode(SoftBreakNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, 1, 0, 1)
        ))
        return Some(InlineParseResult(node, 1, 1))
    }
}
