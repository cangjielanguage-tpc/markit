package markit.plugins.standard.block.blockquote

import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult}
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.SyntheticSourceBuilder

public class BlockquoteParser <: ContinuationBlockParser {
    public prop name: String {
        get() {
            return "BlockquoteParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "BlockquotePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 70
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'>']
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (let Some(stripped) <- stripMarker(line)) {
            let state = BlockquoteState(session.currentLineSpan())
            state.addLine(stripped, session.currentSourceLine())
            return Some(BlockFrame(state))
        }
        return None
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as BlockquoteState).getOrThrow()
        if (let Some(stripped) <- stripMarker(line)) {
            state.addLine(stripped, session.currentSourceLine())
            return Open
        }

        if (!line.trimAscii().isEmpty() && !startsOuterBlock(line)) {
            state.addLine(line, session.currentSourceLine())
            return Open
        }

        return ClosedAndReprocess
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as BlockquoteState).getOrThrow()
        let node = session.attachNode(BlockquoteNode(
            session.allocateNodeId(),
            state.sourceSpan
        ))
        let synthetic = SyntheticSourceBuilder.build(state.lines, preserveTrailingNewline: false)
        for (child in session.parseDetachedLines(synthetic.lines)) {
            child.attachSource(synthetic.source)
            freezeSyntheticRawContent(child)
            node.addChild(child)
        }
        return node
    }

    private func freezeSyntheticRawContent(node: Node): Unit {
        node.setRawContent(node.rawContent())
        for (child in node.children) {
            freezeSyntheticRawContent(child)
        }
    }

    private func stripMarker(line: String): ?String {
        let indent = leadingQuoteIndent(line)
        if (indent < 0) {
            return None
        }

        let markerIndex = Int64(indent)
        if (markerIndex >= line.size || line[markerIndex] != b'>') {
            return None
        }

        var start = markerIndex + 1
        if (start < line.size && line[start] == b' ') {
            start += 1
        }
        if (start >= line.size) {
            return Some("")
        }
        return Some(line[start..])
    }

    private func leadingQuoteIndent(line: String): Int64 {
        var index: Int64 = 0
        var indent: Int64 = 0
        while (index < line.size && (line[index] == b' ' || line[index] == b'\t')) {
            if (line[index] == b' ') {
                indent += 1
            } else {
                indent += 4
            }
            if (indent > 3) {
                return -1
            }
            index += 1
        }
        return index
    }

    private func startsOuterBlock(line: String): Bool {
        let trimmed = line.trimAscii()
        if (trimmed.isEmpty()) {
            return false
        }

        let first = trimmed[0]
        if (first == b'#' || first == b'>') {
            return true
        }

        if (first == b'-' || first == b'*' || first == b'+' || (first >= b'0' && first <= b'9')) {
            return true
        }

        if (first == b'`' || first == b'~') {
            return true
        }

        if (first == b'_') {
            return true
        }

        return false
    }
}
