package markit.plugins.gfm.block.table

import std.collection.ArrayList
import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult}
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.{SourceLine, SourceSpan}
import markit.plugins.gfm.block.BlockLineUtils

public class TableParser <: ContinuationBlockParser {
    public prop name: String {
        get() {
            return "TableParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "TablePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 40
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'|', b'-', b':']
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (session.pendingParagraphLines.size != 1) {
            return None
        }

        let alignments = TableParsingUtils.parseAlignmentRow(line)
        if (alignments.isEmpty()) {
            return None
        }

        let headerLine = session.pendingParagraphLines[0]
        if (!TableParsingUtils.isTableRow(headerLine.text)) {
            return None
        }

        let headerCells = TableParsingUtils.parseRow(headerLine.text)
        if (headerCells.size != alignments.size) {
            return None
        }

        session.clearPendingParagraph()
        return Some(BlockFrame(TableState(
            headerLine,
            session.currentSourceLine(),
            alignments
        )))
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as TableState).getOrThrow()
        if (line.trimAscii().isEmpty() || !TableParsingUtils.isTableRow(line)) {
            return ClosedAndReprocess
        }
        state.addBodyLine(session.currentSourceLine())
        return Open
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as TableState).getOrThrow()
        let table = session.attachNode(TableNode(
            session.allocateNodeId(),
            state.sourceSpan,
            state.alignments,
            state.alignments.size
        ))

        let header = buildRow(session, state.headerLine, state.alignments, true)
        table.addChild(header)
        for (line in state.bodyLines) {
            table.addChild(buildRow(session, line, state.alignments, false))
        }
        table.setRawContent(buildRawContent(state))
        return table
    }

    private func buildRow(
        session: ParseSession,
        line: SourceLine,
        alignments: ArrayList<TableAlignment>,
        isHeader: Bool
    ): TableRowNode {
        let row = session.attachNode(TableRowNode(
            session.allocateNodeId(),
            line.span,
            isHeader
        ))
        row.setRawContent(line.text)

        let cells = TableParsingUtils.parseRow(line.text)
        for (i in 0..alignments.size) {
            let content = if (i < cells.size) { cells[i].trimAscii() } else { "" }
            let cell = session.attachNode(TableCellNode(
                session.allocateNodeId(),
                line.span,
                content,
                alignments[i],
                isHeader
            ))
            cell.setRawContent(content)
            if (!content.isEmpty()) {
                session.appendInlineChildren(cell, content, cellSpan(line, content))
            }
            row.addChild(cell)
        }
        return row
    }

    private func cellSpan(line: SourceLine, content: String): SourceSpan {
        if (let Some(index) <- line.text.indexOf(content)) {
            return BlockLineUtils.lineSubSpan(line.span, line.text, index, index + content.size)
        }
        return line.span
    }

    private func buildRawContent(state: TableState): String {
        let sb = StringBuilder()
        appendLine(sb, state.headerLine)
        appendLine(sb, state.alignmentLine)
        for (line in state.bodyLines) {
            appendLine(sb, line)
        }
        return sb.toString()
    }

    private func appendLine(sb: StringBuilder, line: SourceLine): Unit {
        sb.append(line.text)
        if (line.terminated) {
            sb.append("\n")
        }
    }
}
