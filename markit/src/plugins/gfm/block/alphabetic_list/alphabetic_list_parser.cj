package markit.plugins.gfm.block.alphabetic_list

import std.collection.ArrayList
import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult}
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SourceSpan}
import markit.plugins.gfm.block.BlockLineUtils
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockParsingUtils
import markit.utils.TextRenderUtils

public class AlphabeticListParser <: ContinuationBlockParser {
    public prop name: String {
        get() {
            return "AlphabeticListParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "AlphabeticListPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 85
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [
                b'a', b'b', b'c', b'd', b'e', b'f', b'g', b'h', b'i', b'j', b'k', b'l', b'm',
                b'n', b'o', b'p', b'q', b'r', b's', b't', b'u', b'v', b'w', b'x', b'y', b'z',
                b'A', b'B', b'C', b'D', b'E', b'F', b'G', b'H', b'I', b'J', b'K', b'L', b'M',
                b'N', b'O', b'P', b'Q', b'R', b'S', b'T', b'U', b'V', b'W', b'X', b'Y', b'Z'
            ]
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (let Some(marker) <- parseMarker(line)) {
            let state = AlphabeticListBlockState(marker, session.currentLineSpan())
            state.addItem(marker, session.currentSourceLine())
            return Some(BlockFrame(state))
        }
        return None
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as AlphabeticListBlockState).getOrThrow()
        let lineSpan = session.currentLineSpan()

        if (line.trimAscii().isEmpty()) {
            state.tight = false
            state.sourceSpan = state.sourceSpan.merge(lineSpan)
            state.addContinuationLine(session.currentSourceLine())
            return Open
        }

        if (let Some(marker) <- parseMarker(line)) {
            if (marker.indent == state.baseIndent &&
                marker.delimiter == state.delimiter &&
                marker.isUpperCase == state.isUpperCase &&
                marker.letter == state.expectedLetter) {
                state.sourceSpan = state.sourceSpan.merge(lineSpan)
                state.addItem(marker, session.currentSourceLine())
                return Open
            }
            if (marker.indent > state.baseIndent) {
                state.sourceSpan = state.sourceSpan.merge(lineSpan)
                state.addContinuationLine(session.currentSourceLine())
                return Open
            }
            return ClosedAndReprocess
        }

        if (BlockLineUtils.indentationWidth(line) > state.baseIndent) {
            state.sourceSpan = state.sourceSpan.merge(lineSpan)
            state.addContinuationLine(session.currentSourceLine())
            return Open
        }

        return ClosedAndReprocess
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as AlphabeticListBlockState).getOrThrow()
        let node = session.attachNode(AlphabeticListNode(
            session.allocateNodeId(),
            state.sourceSpan,
            state.tight,
            state.baseIndent,
            state.startLetter,
            state.isUpperCase,
            state.delimiter
        ))

        let itemRawContents = ArrayList<String>()
        for (i in 0..state.items.size) {
            let item = state.items[i]
            let itemContent = item.leadingContent.trimAscii()
            let itemNode = session.attachNode(AlphabeticListItemNode(
                session.allocateNodeId(),
                item.sourceSpan,
                itemContent,
                item.indent,
                item.letter,
                item.delimiter
            ))
            buildItemChildren(session, state, item, itemNode)
            let itemRaw = buildItemRawContent(item, i == state.items.size - 1)
            itemNode.setRawContent(itemRaw)
            itemRawContents.add(itemRaw)
            node.addChild(itemNode)
        }

        if (!itemRawContents.isEmpty()) {
            node.setRawContent(String.join(itemRawContents.toArray(), delimiter: ""))
        }
        return node
    }

    private func parseMarker(line: String): ?AlphabeticListMarker {
        let indent = BlockLineUtils.indentationWidth(line)
        if (indent >= line.size) {
            return None
        }
        let letter = line[indent]
        if (!BlockLineUtils.isAsciiLetter(letter)) {
            return None
        }
        let delimiterIndex = indent + 1
        if (delimiterIndex >= line.size || (line[delimiterIndex] != b'.' && line[delimiterIndex] != b')')) {
            return None
        }
        let after = delimiterIndex + 1
        if (after < line.size && line[after] != b' ' && line[after] != b'\t') {
            return None
        }
        var contentStart = after
        while (contentStart < line.size && (line[contentStart] == b' ' || line[contentStart] == b'\t')) {
            contentStart += 1
        }
        let content = if (contentStart < line.size) { line[contentStart..] } else { "" }
        return Some(AlphabeticListMarker(
            letter,
            BlockLineUtils.isAsciiUpper(letter),
            line[delimiterIndex],
            indent,
            content
        ))
    }

    private func buildItemChildren(
        session: ParseSession,
        state: AlphabeticListBlockState,
        item: AlphabeticListItemData,
        itemNode: Node
    ): Unit {
        let leadText = item.leadingContent.trimAscii()
        let paragraphLines = ArrayList<SourceLine>()
        var paragraphSpan: ?SourceSpan = None

        if (!leadText.isEmpty()) {
            paragraphLines.add(SourceLine(leadText, item.firstLineSpan))
            paragraphSpan = Some(item.firstLineSpan)
        }

        let detachedLines = ArrayList<SourceLine>()
        var detachedMode = false

        for (line in item.continuationLines) {
            let trimmed = line.text.trimAscii()
            if (detachedMode) {
                detachedLines.add(line)
                continue
            }
            if (trimmed.isEmpty()) {
                detachedMode = true
                detachedLines.add(line)
                continue
            }
            if (startsDetachedBlock(state, line.text)) {
                detachedMode = true
                detachedLines.add(line)
                continue
            }
            if (!paragraphLines.isEmpty()) {
                paragraphLines.add(SourceLine(trimmed, line.span, terminated: line.terminated))
                paragraphSpan = match (paragraphSpan) {
                    case Some(span) => Some(span.merge(line.span))
                    case None => Some(line.span)
                }
            } else {
                detachedMode = true
                detachedLines.add(line)
            }
        }

        if (!paragraphLines.isEmpty() && detachedLines.isEmpty() && paragraphLines.size == 1) {
            session.appendInlineChildren(itemNode, paragraphLines[0].text, paragraphLines[0].span)
        } else if (!paragraphLines.isEmpty()) {
            let normalized = ArrayList<SourceLine>()
            for (i in 0..paragraphLines.size) {
                let line = paragraphLines[i]
                normalized.add(SourceLine(line.text, line.span, terminated: i < paragraphLines.size - 1))
            }
            let termination = if (detachedLines.isEmpty()) {
                ParagraphTermination.EndOfInput
            } else {
                ParagraphTermination.BlockBoundary
            }
            itemNode.addChild(
                session.createParagraphNode(normalized, paragraphSpan ?? item.firstLineSpan, termination)
            )
        }

        let normalizedDetachedLines = normalizeDetachedLines(detachedLines)
        if (!normalizedDetachedLines.isEmpty()) {
            for (child in session.parseDetachedLines(normalizedDetachedLines)) {
                itemNode.addChild(child)
            }
        }
    }

    private func startsDetachedBlock(state: AlphabeticListBlockState, line: String): Bool {
        if (line.trimAscii().isEmpty()) {
            return true
        }
        if (let Some(marker) <- parseMarker(line)) {
            return marker.indent > state.baseIndent
        }
        return FencedCodeBlockParsingUtils.detectOpeningFence(line).isSome() ||
            startsNestedHeading(line) ||
            startsNestedDivider(line)
    }

    private func startsNestedHeading(line: String): Bool {
        let trimmed = line.trimAscii()
        if (trimmed.isEmpty() || trimmed[0] != b'#') {
            return false
        }
        var index: Int64 = 0
        while (index < trimmed.size && trimmed[index] == b'#') {
            index += 1
        }
        return index >= 1 && index <= 6 && (index >= trimmed.size || trimmed[index] == b' ' || trimmed[index] == b'\t')
    }

    private func startsNestedDivider(line: String): Bool {
        let trimmed = line.trimAscii()
        if (trimmed.isEmpty()) {
            return false
        }
        let marker = trimmed[0]
        if (marker != b'-' && marker != b'*' && marker != b'_') {
            return false
        }
        var count: Int64 = 0
        for (byte in trimmed) {
            if (byte == marker) {
                count += 1
            } else if (byte != b' ' && byte != b'\t') {
                return false
            }
        }
        return count >= 3
    }

    private func normalizeDetachedLines(lines: ArrayList<SourceLine>): ArrayList<SourceLine> {
        let normalized = ArrayList<SourceLine>()
        if (lines.isEmpty()) {
            return normalized
        }
        var minIndent: ?Int64 = None
        for (line in lines) {
            if (line.text.trimAscii().isEmpty()) {
                continue
            }
            let indent = BlockLineUtils.indentationWidth(line.text)
            minIndent = match (minIndent) {
                case Some(current) => Some(if (indent < current) { indent } else { current })
                case None => Some(indent)
            }
        }
        let indentToRemove = minIndent ?? 0
        for (line in lines) {
            if (line.text.trimAscii().isEmpty()) {
                normalized.add(SourceLine("", line.span, terminated: line.terminated))
            } else {
                normalized.add(SourceLine(
                    BlockLineUtils.removeLeadingIndent(line.text, indentToRemove),
                    line.span,
                    terminated: line.terminated
                ))
            }
        }
        return normalized
    }

    private func buildItemRawContent(item: AlphabeticListItemData, isLast: Bool): String {
        let sb = StringBuilder()
        sb.append(renderItemOpeningLine(item))
        for (line in item.continuationLines) {
            sb.append("\n")
            sb.append(line.text)
        }
        if (!isLast || item.endsWithTerminator()) {
            sb.append("\n")
        }
        return sb.toString()
    }

    private func renderItemOpeningLine(item: AlphabeticListItemData): String {
        let indent = TextRenderUtils.indentSpaces(item.indent)
        return indent + String.fromUtf8([item.letter]) + String.fromUtf8([item.delimiter]) + " " + item.leadingContent
    }
}
