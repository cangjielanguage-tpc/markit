package markit.plugins.standard.block.paragraph

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SourceSpan}

public class ParagraphChildrenBuilder {
    public static func appendChildren(
        session: ParseSession,
        node: Node,
        lines: ArrayList<SourceLine>,
        termination: ParagraphTermination,
        content!: ?String = None
    ): Unit {
        if (lines.isEmpty()) {
            return
        }

        let inline = paragraphInlineContent(lines, termination, content)
        if (inline.text.isEmpty()) {
            return
        }

        session.appendInlineChildren(
            node,
            inline.text,
            SourceSpan(
                lines[0].span.startByte,
                lines[0].span.startByte + inline.text.size,
                lines[0].span.startRune,
                lines[0].span.startRune + inline.runeCount
            )
        )
    }

    public static func paragraphContent(lines: ArrayList<SourceLine>): String {
        if (lines.isEmpty()) {
            return ""
        }
        if (lines.size == 1) {
            return lines[0].text
        }

        var byteSize: Int64 = lines.size - 1
        for (line in lines) {
            byteSize += line.text.size
        }

        let sb = StringBuilder(if (byteSize > 0) { byteSize } else { 1 })
        for (i in 0..lines.size) {
            if (i > 0) {
                sb.append("\n")
            }
            sb.append(lines[i].text)
        }
        return sb.toString()
    }

    public static func hasTerminalSoftBreak(node: Node): Bool {
        if (node.children.isEmpty()) {
            return false
        }
        return node.children[node.children.size - 1].kind == "SoftBreak"
    }

    public static func shouldAppendTerminalSoftBreak(
        line: SourceLine,
        termination: ParagraphTermination
    ): Bool {
        if (!line.terminated) {
            return false
        }
        match (termination) {
            case BlankLine => return true
            case EndOfInputWithNewline => return true
            case _ => return false
        }
    }

    private static func paragraphInlineContent(
        lines: ArrayList<SourceLine>,
        termination: ParagraphTermination,
        content: ?String
    ): ParagraphInlineContent {
        let appendTerminal = shouldAppendTerminalSoftBreak(lines[lines.size - 1], termination)
        var runeCount: Int64 = 0
        for (line in lines) {
            runeCount += line.span.endRune - line.span.startRune
        }
        runeCount += lines.size - 1
        if (appendTerminal) {
            runeCount += 1
        }

        if (!appendTerminal && let Some(text) <- content) {
            return ParagraphInlineContent(text, runeCount)
        }

        var byteSize: Int64 = lines.size - 1
        for (line in lines) {
            byteSize += line.text.size
        }
        if (appendTerminal) {
            byteSize += 1
        }

        let sb = StringBuilder(if (byteSize > 0) { byteSize } else { 1 })
        for (i in 0..lines.size) {
            let line = lines[i]
            sb.append(line.text)
            if (i < lines.size - 1 || (i == lines.size - 1 && appendTerminal)) {
                sb.append("\n")
            }
        }
        return ParagraphInlineContent(sb.toString(), runeCount)
    }
}

class ParagraphInlineContent {
    public let text: String
    public let runeCount: Int64

    public init(text: String, runeCount: Int64) {
        this.text = text
        this.runeCount = runeCount
    }
}
