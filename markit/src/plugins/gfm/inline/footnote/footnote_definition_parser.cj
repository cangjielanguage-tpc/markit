package markit.plugins.gfm.inline.footnote

import std.collection.ArrayList
import markit.core.block.{BlockFrame, BlockState, ContinuationBlockParser, ContinueResult}
import markit.core.inline.InlineUtils
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.{SourceLine, SourceSpan}
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockParsingUtils

public class FootnoteDefinitionParser <: ContinuationBlockParser {
    public prop name: String {
        get() {
            return "FootnoteDefinitionParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 40
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'[']
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (let Some(info) <- parseMarker(line)) {
            let state = FootnoteDefinitionState(
                info.id,
                info.content,
                info.contentStartByte,
                info.contentStartRune,
                SourceLine(line, session.currentLineSpan(), terminated: session.currentSourceLine().terminated)
            )
            return Some(BlockFrame(state))
        }
        return None
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as FootnoteDefinitionState).getOrThrow()
        let trimmed = line.trimAscii()
        if (trimmed.isEmpty()) {
            state.addLine(SourceLine(line, session.currentLineSpan(), terminated: session.currentSourceLine().terminated))
            return Open
        }
        if (indentOf(line) >= 4) {
            state.addLine(SourceLine(
                removeLeadingIndent(line, 4),
                session.currentLineSpan(),
                terminated: session.currentSourceLine().terminated
            ))
            return Open
        }
        return ClosedAndReprocess
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as FootnoteDefinitionState).getOrThrow()
        let content = state.content()
        let registry = session.symbolTables.get(FootnotePlugin.stateKey)
        let added = registry.addDefinition(state.footnoteId, content)
        let number = match (registry.getDefinition(state.footnoteId)) {
            case Some(definition) => definition.number
            case None => 0
        }
        let node = session.attachNode(FootnoteDefinitionNode(
            session.allocateNodeId(),
            state.sourceSpan,
            state.footnoteId,
            content,
            number,
            state.rawContent()
        ))
        node.setBool("duplicateDefinition", !added)
        if (added && !content.isEmpty()) {
            session.appendInlineChildren(
                node,
                content,
                SourceSpan(
                    state.contentStartSpan.startByte,
                    state.contentStartSpan.startByte + content.size,
                    state.contentStartSpan.startRune,
                    state.contentStartSpan.startRune + countRunes(content)
                )
            )
        }
        return node
    }

    private func parseMarker(line: String): ?FootnoteDefinitionStart {
        if (line.size < 5 || line[0] != b'[' || line[1] != b'^') {
            return None
        }
        var cursor: Int64 = 2
        while (cursor < line.size && line[cursor] != b']') {
            if (line[cursor] == b' ' || line[cursor] == b'\t' || line[cursor] == b'\n' || line[cursor] == b'\r') {
                return None
            }
            cursor += 1
        }
        if (cursor >= line.size || line[cursor] != b']' || cursor == 2) {
            return None
        }
        cursor += 1
        if (cursor >= line.size || line[cursor] != b':') {
            return None
        }
        cursor += 1
        while (cursor < line.size && (line[cursor] == b' ' || line[cursor] == b'\t')) {
            cursor += 1
        }
        return Some(FootnoteDefinitionStart(
            line[2..cursorOfClose(line)],
            if (cursor < line.size) { line[cursor..] } else { "" },
            cursor,
            countRunes(line[0..cursor])
        ))
    }

    private func cursorOfClose(line: String): Int64 {
        var cursor: Int64 = 2
        while (cursor < line.size && line[cursor] != b']') {
            cursor += 1
        }
        return cursor
    }

    private func indentOf(line: String): Int64 {
        return FencedCodeBlockParsingUtils.indentationWidth(line)
    }

    private func removeLeadingIndent(line: String, indent: Int64): String {
        return FencedCodeBlockParsingUtils.removeLeadingIndent(line, indent)
    }

    private func countRunes(text: String): Int64 {
        return InlineUtils.countRunes(text)
    }
}

private class FootnoteDefinitionStart {
    public let id: String
    public let content: String
    public let contentStartByte: Int64
    public let contentStartRune: Int64

    public init(id: String, content: String, contentStartByte: Int64, contentStartRune: Int64) {
        this.id = id
        this.content = content
        this.contentStartByte = contentStartByte
        this.contentStartRune = contentStartRune
    }
}

private class FootnoteDefinitionState <: BlockState {
    public let footnoteId: String
    public let contentStartSpan: SourceSpan
    public var sourceSpan: SourceSpan
    private let lines = ArrayList<SourceLine>()
    private let firstLine: SourceLine

    public init(
        footnoteId: String,
        firstContent: String,
        contentStartByte: Int64,
        contentStartRune: Int64,
        firstLine: SourceLine
    ) {
        this.footnoteId = footnoteId
        this.firstLine = firstLine
        this.sourceSpan = firstLine.span
        this.contentStartSpan = SourceSpan(
            firstLine.span.startByte + contentStartByte,
            firstLine.span.endByte,
            firstLine.span.startRune + contentStartRune,
            firstLine.span.endRune
        )
        lines.add(SourceLine(firstContent, contentStartSpan, terminated: firstLine.terminated))
    }

    public func addLine(line: SourceLine): Unit {
        sourceSpan = sourceSpan.merge(line.span)
        lines.add(line)
    }

    public func content(): String {
        let sb = StringBuilder()
        for (i in 0..lines.size) {
            if (i > 0) {
                sb.append("\n")
            }
            sb.append(lines[i].text.trimAscii())
        }
        return sb.toString().trimAscii()
    }

    public func rawContent(): String {
        let sb = StringBuilder()
        sb.append(firstLine.text)
        if (firstLine.terminated) {
            sb.append("\n")
        }
        for (i in 1..lines.size) {
            sb.append(lines[i].text)
            if (lines[i].terminated) {
                sb.append("\n")
            }
        }
        return sb.toString()
    }
}
