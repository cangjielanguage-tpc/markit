package markit.plugins.commonmark.block.setext_heading

import std.collection.ArrayList
import markit.core.block.LeafBlockParser
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.{SourceLine, SourceSpan}
import markit.plugins.standard.block.heading.{HeadingNode, HeadingPlugin}

public class SetextHeadingParser <: LeafBlockParser {
    public prop name: String {
        get() {
            return "SetextHeadingParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "SetextHeadingPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 50
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'=', b'-']
        }
    }

    public prop acceptsAnyNonBlank: Bool {
        get() {
            return false
        }
    }

    public func tryParse(session: ParseSession, line: String): ?Node {
        let level = markerLevel(line)
        if (level == 0 || session.pendingParagraphLines.isEmpty()) {
            return None
        }

        let lines = ArrayList<SourceLine>()
        for (pendingLine in session.pendingParagraphLines) {
            lines.add(pendingLine)
        }
        let content = paragraphContent(lines)
        if (content.trimAscii().isEmpty()) {
            return None
        }

        let sourceSpan = session.pendingParagraphSourceSpan().merge(session.currentLineSpan())
        let state = session.symbolTables.get(HeadingPlugin.stateKey)
        let heading = session.attachNode(HeadingNode(
            session.allocateNodeId(),
            sourceSpan,
            content.trimAscii(),
            level,
            slug: state.uniqueSlug(content.trimAscii())
        ))
        appendInlineChildren(session, heading, lines)

        let number = state.assignNumber(level)
        if (!number.isEmpty()) {
            heading.setString("number", number)
            heading.setBool("numberInHtml", state.includeNumberInHtml())
        }

        heading.setRawContent(rawContent(lines, session.currentSourceLine()))
        session.clearPendingParagraph()
        return Some(heading)
    }

    private func markerLevel(line: String): Int64 {
        let trimmed = line.trimAscii()
        if (trimmed.size < 3) {
            return 0
        }
        let marker = trimmed[0]
        if (marker != b'=' && marker != b'-') {
            return 0
        }
        for (byte in trimmed) {
            if (byte != marker) {
                return 0
            }
        }
        return if (marker == b'=') { 1 } else { 2 }
    }

    private func paragraphContent(lines: ArrayList<SourceLine>): String {
        let sb = StringBuilder()
        for (i in 0..lines.size) {
            if (i > 0) {
                sb.append("\n")
            }
            sb.append(lines[i].text)
        }
        return sb.toString()
    }

    private func appendInlineChildren(session: ParseSession, heading: Node, lines: ArrayList<SourceLine>): Unit {
        for (i in 0..lines.size) {
            let line = lines[i]
            let content = if (i == lines.size - 1) { line.text.trimAsciiEnd() } else { line.text }
            if (!content.isEmpty()) {
                session.appendInlineChildren(
                    heading,
                    content,
                    SourceSpan(
                        line.span.startByte,
                        line.span.startByte + content.size,
                        line.span.startRune,
                        line.span.startRune + countRunes(content)
                    )
                )
            }
            if (i < lines.size - 1) {
                heading.addChild(session.createTextNode("\n", SourceSpan(
                    line.span.endByte,
                    line.span.endByte,
                    line.span.endRune,
                    line.span.endRune
                )))
            }
        }
    }

    private func rawContent(lines: ArrayList<SourceLine>, markerLine: SourceLine): String {
        let raw = StringBuilder()
        for (line in lines) {
            raw.append(line.text)
            if (line.terminated) {
                raw.append("\n")
            }
        }
        raw.append(markerLine.text)
        if (markerLine.terminated) {
            raw.append("\n")
        }
        return raw.toString()
    }

    private func countRunes(text: String): Int64 {
        var count: Int64 = 0
        for (_ in text.runes()) {
            count += 1
        }
        return count
    }
}
