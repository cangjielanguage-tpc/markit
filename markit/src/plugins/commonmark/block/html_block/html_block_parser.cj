package markit.plugins.commonmark.block.html_block

import std.collection.{ArrayList, HashMap}
import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult}
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.SourceLine
import markit.plugins.commonmark.{HtmlAttributeUtils, asciiLower}

public class HTMLBlockParser <: ContinuationBlockParser {
    private let config: HtmlBlockConfig

    public init(config!: HtmlBlockConfig = HtmlBlockConfig()) {
        this.config = config
    }

    public prop name: String {
        get() {
            return "HTMLBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "HTMLBlockPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 300
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'<']
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        let trimmed = line.trimAsciiStart()
        if (!trimmed.startsWith("<")) {
            return None
        }

        let info = parseStart(trimmed)
        if (info.isNone()) {
            return None
        }
        let start = info.getOrThrow()
        let nestingDepth = initialNestingDepth(start, trimmed)
        let closed = if (start.blockType == SafeBlockTag) {
            nestingDepth <= 0
        } else {
            start.endMarker.isEmpty() || trimmed.contains(start.endMarker)
        }
        return Some(BlockFrame(HTMLBlockState(
            SourceLine(line, session.currentLineSpan(), terminated: session.currentSourceLine().terminated),
            start.blockType,
            start.tagName,
            start.isSelfClosing,
            start.isContentProtected,
            start.attributes,
            start.endMarker,
            closed,
            nestingDepth: nestingDepth
        )))
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as HTMLBlockState).getOrThrow()
        if (state.closed) {
            return ClosedAndReprocess
        }
        state.add(SourceLine(line, session.currentLineSpan(), terminated: session.currentSourceLine().terminated))
        if (state.blockType == SafeBlockTag && !state.endMarker.isEmpty()) {
            state.nestingDepth += tagNestingDelta(line, state.tagName)
            if (state.nestingDepth <= 0) {
                state.closed = true
                return Closed
            }
            return Open
        }
        if (!state.endMarker.isEmpty() && line.contains(state.endMarker)) {
            state.closed = true
            return Closed
        }
        return Open
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as HTMLBlockState).getOrThrow()
        let raw = joinRaw(state.lines)
        let node = session.attachNode(HTMLBlockNode(
            session.allocateNodeId(),
            state.sourceSpan,
            raw,
            state.blockType,
            tagName: state.tagName,
            isSelfClosing: state.isSelfClosing,
            isContentProtected: state.isContentProtected,
            attributes: state.attributes
        ))
        if (config.enableInlineMarkdownParsing && !state.isContentProtected && state.blockType == SafeBlockTag && !state.isSelfClosing) {
            appendInnerMarkdown(session, node, state)
        }
        return node
    }

    private func parseStart(line: String): ?HTMLBlockStartInfo {
        if (line.startsWith("<!--")) {
            return Some(HTMLBlockStartInfo(Comment, "", false, true, HashMap<String, String>(), "-->"))
        }
        if (line.startsWith("<?")) {
            return Some(HTMLBlockStartInfo(Processing, "", false, true, HashMap<String, String>(), "?>"))
        }
        if (line.startsWith("<![CDATA[")) {
            return Some(HTMLBlockStartInfo(CDATA, "", false, true, HashMap<String, String>(), "]]>"))
        }
        if (line.startsWith("<!")) {
            return Some(HTMLBlockStartInfo(Declaration, "", false, true, HashMap<String, String>(), ">"))
        }

        let tag = parseOpeningTag(line)
        if (tag.isNone()) {
            return None
        }
        let parsed = tag.getOrThrow()
        if (!isSafeBlockTag(parsed.tagName) || isUnsafeTag(parsed.tagName)) {
            return None
        }
        let endMarker = if (parsed.isSelfClosing) { "" } else { "</" + parsed.tagName + ">" }
        return Some(HTMLBlockStartInfo(
            SafeBlockTag,
            parsed.tagName,
            parsed.isSelfClosing,
            isContentProtectedTag(parsed.tagName),
            parsed.attributes,
            endMarker
        ))
    }

    private func parseOpeningTag(line: String): ?ParsedBlockTag {
        if (line.isEmpty() || line[0] != b'<' || (line.size > 1 && (line[1] == b'/' || line[1] == b'!' || line[1] == b'?'))) {
            return None
        }
        var cursor: Int64 = 1
        let tagStart = cursor
        while (cursor < line.size && isTagNameByte(line[cursor])) {
            cursor += 1
        }
        if (cursor == tagStart) {
            return None
        }
        let tagName = asciiLower(line[tagStart..cursor])
        let tagEnd = findTagEnd(line, cursor)
        if (tagEnd < 0) {
            return None
        }
        var attrEnd = tagEnd
        var isSelfClosing = false
        if (attrEnd > cursor && line[attrEnd - 1] == b'/') {
            isSelfClosing = true
            attrEnd -= 1
        }
        let attrs = if (attrEnd > cursor) { line[cursor..attrEnd].trimAscii() } else { "" }
        return Some(ParsedBlockTag(tagName, isSelfClosing, HtmlAttributeUtils.parse(attrs), tagEnd + 1))
    }

    private func findTagEnd(line: String, start: Int64): Int64 {
        var cursor = start
        while (cursor < line.size) {
            if (line[cursor] == b'"' || line[cursor] == b'\'') {
                let quoteByte = line[cursor]
                cursor += 1
                while (cursor < line.size && line[cursor] != quoteByte) {
                    cursor += 1
                }
            } else if (line[cursor] == b'>') {
                return cursor
            }
            cursor += 1
        }
        return -1
    }

    private func appendInnerMarkdown(session: ParseSession, node: Node, state: HTMLBlockState): Unit {
        if (state.lines.isEmpty()) {
            return
        }
        let inner = extractInnerLines(state)
        if (inner.isEmpty()) {
            return
        }
        for (child in session.parseDetachedLines(inner)) {
            node.addChild(child)
        }
    }

    private func extractInnerLines(state: HTMLBlockState): ArrayList<SourceLine> {
        let result = ArrayList<SourceLine>()
        if (state.lines.isEmpty()) {
            return result
        }
        for (i in 0..state.lines.size) {
            let line = state.lines[i]
            var text = line.text
            var byteStartDelta: Int64 = 0
            var runeStartDelta: Int64 = 0
            if (i == 0) {
                let end = findTagEnd(text, 0)
                if (end >= 0) {
                    byteStartDelta = end + 1
                    runeStartDelta = countRunes(text[0..end + 1])
                    text = text[end + 1..]
                }
            }
            if (i == state.lines.size - 1 && !state.tagName.isEmpty()) {
                let close = asciiLower(text).lastIndexOf("</" + state.tagName + ">")
                if (close.isSome()) {
                    text = text[0..close.getOrThrow()]
                }
            }
            let beforeTrimSize = text.size
            text = text.trimAsciiStart()
            if (!text.isEmpty()) {
                let leadingTrim = beforeTrimSize - text.size
                result.add(SourceLine(
                    text,
                    line.span.slice(
                        byteStartDelta + leadingTrim,
                        byteStartDelta + leadingTrim + text.size,
                        runeStartDelta + leadingTrim,
                        runeStartDelta + leadingTrim + countRunes(text)
                    ),
                    terminated: line.terminated
                ))
            }
        }
        return withoutTerminalTermination(result)
    }

    private func withoutTerminalTermination(lines: ArrayList<SourceLine>): ArrayList<SourceLine> {
        if (lines.isEmpty()) {
            return lines
        }
        let result = ArrayList<SourceLine>()
        for (i in 0..lines.size) {
            let line = lines[i]
            result.add(SourceLine(
                line.text,
                line.span,
                terminated: if (i == lines.size - 1) { false } else { line.terminated }
            ))
        }
        return result
    }

    private func joinRaw(lines: ArrayList<SourceLine>): String {
        let raw = StringBuilder()
        for (line in lines) {
            raw.append(line.text)
            if (line.terminated) {
                raw.append("\n")
            }
        }
        return raw.toString()
    }

    private func initialNestingDepth(start: HTMLBlockStartInfo, line: String): Int64 {
        if (!(start.blockType == SafeBlockTag) || start.tagName.isEmpty() || start.isSelfClosing) {
            return 0
        }
        return tagNestingDelta(line, start.tagName)
    }

    private func tagNestingDelta(line: String, tagName: String): Int64 {
        if (tagName.isEmpty()) {
            return 0
        }
        let lower = asciiLower(line)
        var cursor: Int64 = 0
        var delta: Int64 = 0
        while (cursor < lower.size) {
            if (lower[cursor] != b'<') {
                cursor += 1
                continue
            }
            if (cursor + 1 >= lower.size) {
                break
            }
            let next = lower[cursor + 1]
            if (next == b'!' || next == b'?') {
                cursor += 1
                continue
            }

            var closing = false
            var nameStart = cursor + 1
            if (next == b'/') {
                closing = true
                nameStart = cursor + 2
            }
            if (!matchesTagName(lower, tagName, nameStart)) {
                cursor += 1
                continue
            }
            let nameEnd = nameStart + tagName.size
            if (!isTagBoundary(lower, nameEnd)) {
                cursor += 1
                continue
            }
            let tagEnd = findTagEnd(lower, nameEnd)
            if (tagEnd < 0) {
                cursor += 1
                continue
            }

            if (closing) {
                delta -= 1
            } else if (!isSelfClosingAt(lower, tagEnd)) {
                delta += 1
            }
            cursor = tagEnd + 1
        }
        return delta
    }

    private func matchesTagName(line: String, tagName: String, start: Int64): Bool {
        if (start < 0 || start + tagName.size > line.size) {
            return false
        }
        for (i in 0..tagName.size) {
            if (line[start + i] != tagName[i]) {
                return false
            }
        }
        return true
    }

    private func isTagBoundary(line: String, pos: Int64): Bool {
        if (pos >= line.size) {
            return false
        }
        let byte = line[pos]
        return byte == b'>' || byte == b'/' || isAsciiWhitespace(byte)
    }

    private func isSelfClosingAt(line: String, tagEnd: Int64): Bool {
        var cursor = tagEnd - 1
        while (cursor >= 0 && isAsciiWhitespace(line[cursor])) {
            cursor -= 1
        }
        return cursor >= 0 && line[cursor] == b'/'
    }

    private func isAsciiWhitespace(byte: Byte): Bool {
        return byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r'
    }

    private func isSafeBlockTag(tagName: String): Bool {
        return tagName == "div" || tagName == "p" || tagName == "section" || tagName == "article" ||
            tagName == "aside" || tagName == "header" || tagName == "footer" || tagName == "nav" ||
            tagName == "main" || tagName == "figure" || tagName == "figcaption" ||
            tagName == "blockquote" || tagName == "pre" || tagName == "hr" ||
            tagName == "h1" || tagName == "h2" || tagName == "h3" || tagName == "h4" ||
            tagName == "h5" || tagName == "h6" || tagName == "ul" || tagName == "ol" ||
            tagName == "li" || tagName == "dl" || tagName == "dt" || tagName == "dd" ||
            tagName == "details" || tagName == "summary" || tagName == "dialog" || tagName == "hgroup" ||
            tagName == "table" || tagName == "thead" || tagName == "tbody" || tagName == "tfoot" ||
            tagName == "tr" || tagName == "th" || tagName == "td" || tagName == "caption" ||
            tagName == "colgroup" || tagName == "col" || tagName == "fieldset" || tagName == "legend" ||
            tagName == "address" || tagName == "center" || tagName == "dir" || tagName == "menu"
    }

    private func isUnsafeTag(tagName: String): Bool {
        return tagName == "script" || tagName == "style" || tagName == "noscript" ||
            tagName == "object" || tagName == "embed" || tagName == "applet" || tagName == "iframe"
    }

    private func isContentProtectedTag(tagName: String): Bool {
        return tagName == "pre" || tagName == "script" || tagName == "style" || tagName == "textarea"
    }

    private func isTagNameByte(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') ||
            (byte >= b'A' && byte <= b'Z') ||
            (byte >= b'0' && byte <= b'9') ||
            byte == b'-' ||
            byte == b'_'
    }

    private func countRunes(text: String): Int64 {
        var count: Int64 = 0
        for (_ in text.runes()) {
            count += 1
        }
        return count
    }
}

private class HTMLBlockStartInfo {
    public let blockType: HTMLBlockType
    public let tagName: String
    public let isSelfClosing: Bool
    public let isContentProtected: Bool
    public let attributes: HashMap<String, String>
    public let endMarker: String

    public init(
        blockType: HTMLBlockType,
        tagName: String,
        isSelfClosing: Bool,
        isContentProtected: Bool,
        attributes: HashMap<String, String>,
        endMarker: String
    ) {
        this.blockType = blockType
        this.tagName = tagName
        this.isSelfClosing = isSelfClosing
        this.isContentProtected = isContentProtected
        this.attributes = attributes
        this.endMarker = endMarker
    }
}

private class ParsedBlockTag {
    public let tagName: String
    public let isSelfClosing: Bool
    public let attributes: HashMap<String, String>
    public let endPos: Int64

    public init(tagName: String, isSelfClosing: Bool, attributes: HashMap<String, String>, endPos: Int64) {
        this.tagName = tagName
        this.isSelfClosing = isSelfClosing
        this.attributes = attributes
        this.endPos = endPos
    }
}
