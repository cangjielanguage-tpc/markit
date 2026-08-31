package markit.plugins.standard.inline.hard_break

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class HardBreakParser <: InlineParser {
    public prop name: String {
        get() {
            return "HardBreakParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "HardBreakPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 5
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'\\', b' ']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (startByte >= endByte) {
            return None
        }

        if (input[startByte] == b'\\' && endByte - startByte >= 2) {
            var end: Int64 = startByte + 1
            while (end < endByte && input[end] == b' ') {
                end += 1
            }
            if (end >= endByte || input[end] != b'\n') {
                return None
            }

            let consumed = end + 1 - startByte
            let node = session.attachNode(HardBreakNode(
                session.allocateNodeId(),
                InlineUtils.spanWithRunes(baseSpan, 0, consumed, 0, consumed),
                BreakType.Backslash
            ))
            return Some(InlineParseResult(node, consumed, consumed))
        }

        if (input[startByte] == b' ') {
            var spaceCount: Int64 = 0
            while (startByte + spaceCount < endByte && input[startByte + spaceCount] == b' ') {
                spaceCount += 1
            }
            if (spaceCount == 2 && startByte + spaceCount < endByte && input[startByte + spaceCount] == b'\n') {
                let consumed = spaceCount + 1
                let node = session.attachNode(HardBreakNode(
                    session.allocateNodeId(),
                    InlineUtils.spanWithRunes(baseSpan, 0, consumed, 0, consumed),
                    BreakType.TwoSpaces
                ))
                return Some(InlineParseResult(node, consumed, consumed))
            }
        }

        return None
    }
}
