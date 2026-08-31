package markit.plugins.standard.block.list

import std.collection.ArrayList
import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult}
import markit.core.nodes.Node
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockParsingUtils
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SourceSpan}
import markit.utils.TextRenderUtils

public class ListBlockParser <: ContinuationBlockParser {
    public prop name: String {
        get() {
            return "ListBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ListPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 80
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [
                b'-', b'*', b'+',
                b'0', b'1', b'2', b'3', b'4',
                b'5', b'6', b'7', b'8', b'9'
            ]
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (let Some(marker) <- parseMarker(line)) {
            let state = ListBlockState(marker, session.currentLineSpan())
            state.addItem(marker, session.currentSourceLine())
            return Some(BlockFrame(state))
        }
        return None
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as ListBlockState).getOrThrow()
        let lineSpan = session.currentLineSpan()

        if (line.trimAscii().isEmpty()) {
            state.addPendingBlankLine(session.currentSourceLine())
            return Open
        }

        if (let Some(marker) <- parseMarker(line)) {
            if (isSiblingItem(state, marker)) {
                flushPendingBlankLines(state)
                state.sourceSpan = state.sourceSpan.merge(lineSpan)
                state.addItem(marker, session.currentSourceLine())
                return Open
            }

            if (marker.indent > state.baseIndent) {
                flushPendingBlankLines(state)
                state.sourceSpan = state.sourceSpan.merge(lineSpan)
                state.addContinuationLine(session.currentSourceLine())
                return Open
            }

            return ClosedAndReprocess
        }

        if (indentOf(line) > state.baseIndent) {
            flushPendingBlankLines(state)
            state.sourceSpan = state.sourceSpan.merge(lineSpan)
            state.addContinuationLine(session.currentSourceLine())
            return Open
        }

        return ClosedAndReprocess
    }

    private func flushPendingBlankLines(state: ListBlockState): Unit {
        if (state.pendingBlankLines.isEmpty()) {
            return
        }

        state.tight = false
        for (blank in state.pendingBlankLines) {
            state.sourceSpan = state.sourceSpan.merge(blank.span)
            state.addContinuationLine(blank)
        }
        state.clearPendingBlankLines()
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as ListBlockState).getOrThrow()
        flushPendingBlankLines(state)
        let node = if (state.ordered) {
            session.attachNode(OrderedListNode(
                session.allocateNodeId(),
                state.sourceSpan,
                state.tight,
                state.baseIndent,
                state.startNumber,
                state.delimiter
            ))
        } else {
            session.attachNode(UnorderedListNode(
                session.allocateNodeId(),
                state.sourceSpan,
                state.tight,
                state.baseIndent
            ))
        }

        let itemRawContents = ArrayList<String>()
        for (i in 0..state.items.size) {
            let item = state.items[i]
            let itemContent = item.leadingContent.trimAscii()
            let itemNode = if (state.ordered) {
                session.attachNode(OrderedListItemNode(
                    session.allocateNodeId(),
                    item.sourceSpan,
                    itemContent,
                    item.indent,
                    item.number,
                    item.delimiter
                ))
            } else {
                session.attachNode(UnorderedListItemNode(
                    session.allocateNodeId(),
                    item.sourceSpan,
                    itemContent,
                    item.indent,
                    item.marker
                ))
            }
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

    private func buildItemChildren(
        session: ParseSession,
        state: ListBlockState,
        item: ListItemData,
        itemNode: Node
    ): Unit {
        let leadText = item.leadingContent.trimAscii()
        let paragraphLines = ArrayList<SourceLine>()
        var paragraphSpan: ?SourceSpan = None

        if (!leadText.isEmpty()) {
            paragraphLines.add(SourceLine(leadText, item.firstLineContentSpan, terminated: item.firstLineTerminated))
            paragraphSpan = Some(item.firstLineContentSpan)
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

            if (startsDetachedBlock(session, state, line.text)) {
                detachedMode = true
                detachedLines.add(line)
                continue
            }

            if (!paragraphLines.isEmpty()) {
                let trimmedLine = trimmedSourceLine(line)
                paragraphLines.add(trimmedLine)
                paragraphSpan = match (paragraphSpan) {
                    case Some(span) => Some(span.merge(trimmedLine.span))
                    case None => Some(trimmedLine.span)
                }
            } else {
                detachedMode = true
                detachedLines.add(line)
            }
        }

        if (!paragraphLines.isEmpty() && detachedLines.isEmpty() && paragraphLines.size == 1) {
            addSingleLineItemChildren(session, paragraphLines[0], itemNode)
        } else if (!paragraphLines.isEmpty()) {
            let normalized = ArrayList<SourceLine>()
            for (i in 0..paragraphLines.size) {
                let line = paragraphLines[i]
                normalized.add(SourceLine(
                    line.text,
                    line.span,
                    terminated: i < paragraphLines.size - 1
                ))
            }
            let termination = if (detachedLines.isEmpty()) {
                EndOfInput
            } else {
                BlockBoundary
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

    private func addSingleLineItemChildren(session: ParseSession, line: SourceLine, itemNode: Node): Unit {
        let inlineChildren = session.parseInline(line.text, line.span)
        if (inlineChildren.isEmpty()) {
            return
        }

        if (inlineChildren.size == 1 && inlineChildren[0].kind == "Text") {
            itemNode.addChild(inlineChildren[0])
            return
        }

        let paragraph = session.attachNode(ParagraphNode(
            session.allocateNodeId(),
            line.span,
            line.text
        ))
        for (child in inlineChildren) {
            paragraph.addChild(child)
        }
        itemNode.addChild(paragraph)
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
            let indent = indentOf(line.text)
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
                    removeLeadingIndent(line.text, indentToRemove),
                    line.span,
                    terminated: line.terminated
                ))
            }
        }
        return normalized
    }

    private func startsDetachedBlock(session: ParseSession, state: ListBlockState, line: String): Bool {
        if (line.trimAscii().isEmpty()) {
            return true
        }

        if (let Some(marker) <- parseMarker(line)) {
            return marker.indent > state.baseIndent
        }

        return startsNestedFence(line) ||
            startsNestedHeading(line) ||
            startsNestedDivider(line) ||
            session.startsRegisteredBlock(line)
    }

    private func isSiblingItem(state: ListBlockState, marker: ListMarker): Bool {
        if (marker.ordered != state.ordered) {
            return false
        }
        if (marker.indent != state.baseIndent) {
            return false
        }
        if (state.ordered) {
            return marker.delimiter == state.delimiter
        }
        return true
    }

    private func parseMarker(line: String): ?ListMarker {
        let indent = indentOf(line)
        if (indent >= line.size) {
            return None
        }

        let first = line[indent]
        if (first == b'-' || first == b'*' || first == b'+') {
            let after = indent + 1
            if (after < line.size && line[after] != b' ' && line[after] != b'\t') {
                return None
            }
            if (first != b'+' && isDividerLike(line[indent..])) {
                return None
            }
            let content = contentAfterMarker(line, after)
            return Some(ListMarker(
                false,
                first,
                first,
                0,
                indent,
                content.text,
                content.startByte,
                content.endByte,
                content.startRune,
                content.endRune
            ))
        }

        if (first < b'0' || first > b'9') {
            return None
        }

        var index = indent
        var number: Int64 = 0
        while (index < line.size && line[index] >= b'0' && line[index] <= b'9') {
            number = number * 10 + (Int64(line[index]) - Int64(b'0'))
            index += 1
        }

        if (index >= line.size || (line[index] != b'.' && line[index] != b')')) {
            return None
        }

        let delimiter = line[index]
        index += 1
        if (index < line.size && line[index] != b' ' && line[index] != b'\t') {
            return None
        }

        let content = contentAfterMarker(line, index)
        return Some(ListMarker(
            true,
            delimiter,
            delimiter,
            number,
            indent,
            content.text,
            content.startByte,
            content.endByte,
            content.startRune,
            content.endRune
        ))
    }

    private func contentAfterMarker(line: String, markerEnd: Int64): ListMarkerContent {
        var start = markerEnd
        while (start < line.size && (line[start] == b' ' || line[start] == b'\t')) {
            start += 1
        }

        var end = line.size
        while (end > start && (line[end - 1] == b' ' || line[end - 1] == b'\t')) {
            end -= 1
        }

        let text = if (start < end) { line[start..end] } else { "" }
        let startRune = countRunes(line[0..start])
        let endRune = startRune + countRunes(text)
        return ListMarkerContent(text, start, end, startRune, endRune)
    }

    private func indentOf(line: String): Int64 {
        return FencedCodeBlockParsingUtils.indentationWidth(line)
    }

    private func removeLeadingIndent(line: String, indent: Int64): String {
        return FencedCodeBlockParsingUtils.removeLeadingIndent(line, indent)
    }

    private func startsNestedFence(line: String): Bool {
        return FencedCodeBlockParsingUtils.detectOpeningFence(line).isSome()
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
        return isDividerLike(trimmed)
    }

    private func isDividerLike(text: String): Bool {
        let trimmed = text.trimAscii()
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

    private func buildItemRawContent(item: ListItemData, isLast: Bool): String {
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

    private func renderItemOpeningLine(item: ListItemData): String {
        let indent = TextRenderUtils.indentSpaces(item.indent)
        if (item.number > 0) {
            return indent + item.number.toString() + String.fromUtf8([item.delimiter]) + " " + item.leadingContent
        }
        return indent + String.fromUtf8([item.marker]) + " " + item.leadingContent
    }

    private func trimmedSourceLine(line: SourceLine): SourceLine {
        var start: Int64 = 0
        var end = line.text.size
        while (start < end && (line.text[start] == b' ' || line.text[start] == b'\t')) {
            start += 1
        }
        while (end > start && (line.text[end - 1] == b' ' || line.text[end - 1] == b'\t')) {
            end -= 1
        }

        let text = if (start < end) { line.text[start..end] } else { "" }
        let startRune = countRunes(line.text[0..start])
        let textRunes = countRunes(text)
        return SourceLine(
            text,
            SourceSpan(
                line.span.startByte + start,
                line.span.startByte + end,
                line.span.startRune + startRune,
                line.span.startRune + startRune + textRunes
            ),
            terminated: line.terminated
        )
    }

    private func countRunes(text: String): Int64 {
        var count: Int64 = 0
        for (_ in text.runes()) {
            count += 1
        }
        return count
    }
}

private class ListMarkerContent {
    public let text: String
    public let startByte: Int64
    public let endByte: Int64
    public let startRune: Int64
    public let endRune: Int64

    public init(
        text: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ) {
        this.text = text
        this.startByte = startByte
        this.endByte = endByte
        this.startRune = startRune
        this.endRune = endRune
    }
}
