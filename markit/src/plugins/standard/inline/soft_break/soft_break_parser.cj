package markit.plugins.standard.inline.soft_break

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class SoftBreakParser <: InlineParser {
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
        if (startByte >= endByte || input[startByte] != b'\n') {
            return None
        }

        let node = session.attachNode(SoftBreakNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, 1, 0, 1)
        ))
        return Some(InlineParseResult(node, 1, 1))
    }
}
