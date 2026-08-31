package markit.plugins.gfm.block.math_block

import std.collection.ArrayList
import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult}
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.SourceLine
import markit.plugins.gfm.block.BlockLineUtils

public class MathBlockParser <: ContinuationBlockParser {
    public prop name: String {
        get() {
            return "MathBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "MathBlockPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 90
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'$']
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (let Some(indent) <- openingIndent(session, line)) {
            return Some(BlockFrame(MathBlockState(
                indent,
                SourceLine(line, session.currentLineSpan(), terminated: session.currentSourceLine().terminated)
            )))
        }
        return None
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as MathBlockState).getOrThrow()
        if (isClosingLine(line, state.indentLevel)) {
            state.close(session.currentSourceLine())
            return Closed
        }

        state.addContentLine(SourceLine(
            BlockLineUtils.removeLeadingIndent(line, state.indentLevel),
            session.currentLineSpan(),
            terminated: session.currentSourceLine().terminated
        ))
        return Open
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as MathBlockState).getOrThrow()
        if (!state.closed) {
            return fallbackParagraph(session, state)
        }

        let contentLines = ArrayList<String>()
        for (line in state.contentLines) {
            contentLines.add(line.text)
        }
        return session.attachNode(MathBlockNode(
            session.allocateNodeId(),
            state.sourceSpan,
            String.join(contentLines.toArray(), delimiter: "\n"),
            state.indentLevel
        ))
    }

    private func openingIndent(session: ParseSession, line: String): ?Int64 {
        let indent = BlockLineUtils.indentationWidth(line)
        if (indent > 4 && !session.allowDeepIndentedBlockStart()) {
            return None
        }
        let trimmed = line.trimAscii()
        if (trimmed == "$$") {
            return Some(indent)
        }
        return None
    }

    private func isClosingLine(line: String, openingIndent: Int64): Bool {
        let indent = BlockLineUtils.indentationWidth(line)
        if (indent > openingIndent) {
            return false
        }
        return line.trimAscii().startsWith("$$")
    }

    private func fallbackParagraph(session: ParseSession, state: MathBlockState): Node {
        let lines = ArrayList<SourceLine>()
        lines.add(state.openingLine)
        for (line in state.contentLines) {
            lines.add(SourceLine(
                BlockLineUtils.removeLeadingIndent(line.text, 0),
                line.span,
                terminated: line.terminated
            ))
        }
        return session.createParagraphNode(lines, state.sourceSpan, ParagraphTermination.EndOfInput)
    }

}
