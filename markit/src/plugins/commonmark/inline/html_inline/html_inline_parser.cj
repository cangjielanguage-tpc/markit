package markit.plugins.commonmark.inline.html_inline

import std.collection.HashMap
import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.plugins.commonmark.{HtmlAttributeUtils, asciiLower}

public class HTMLInlineParser <: InlineParser {
    public prop name: String {
        get() {
            return "HTMLInlineParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "HTMLInlinePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 800
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'<']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 3 || input[startByte] != b'<') {
            return None
        }

        let close = findTagEnd(input, startByte, endByte)
        if (close < 0) {
            return None
        }

        let content = input[startByte + 1..close]
        let tagInfo = parseTag(content)
        if (tagInfo.isNone()) {
            return None
        }
        let info = tagInfo.getOrThrow()
        if (!isSafeInlineTag(info.tagName)) {
            return None
        }

        let raw = input[startByte..close + 1]
        let rawRunes = InlineUtils.countRunes(input, startByte, close + 1)
        let tagType = if (info.isClosing) {
            ClosingTag
        } else if (info.isSelfClosing || isImplicitSelfClosing(info.tagName)) {
            SelfClosing
        } else {
            OpeningTag
        }
        let node = session.attachNode(HTMLInlineNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, raw.size, 0, rawRunes),
            info.tagName,
            tagType,
            raw,
            isContentProtected: isContentProtectedTag(info.tagName),
            attributes: info.attributes,
            attributesStr: info.attributesStr
        ))
        return Some(InlineParseResult(node, raw.size, rawRunes))
    }

    private func findTagEnd(input: String, startByte: Int64, endByte: Int64): Int64 {
        var cursor: Int64 = startByte + 1
        while (cursor < endByte) {
            if (input[cursor] == b'"' || input[cursor] == b'\'') {
                let quoteByte = input[cursor]
                cursor += 1
                while (cursor < endByte && input[cursor] != quoteByte) {
                    cursor += 1
                }
            } else if (input[cursor] == b'>') {
                return cursor
            }
            cursor += 1
        }
        return -1
    }

    private func parseTag(content: String): ?ParsedInlineTag {
        if (content.isEmpty()) {
            return None
        }
        var cursor: Int64 = 0
        var isClosing = false
        if (content[0] == b'/') {
            isClosing = true
            cursor = 1
        }
        if (cursor >= content.size || isSpace(content[cursor])) {
            return None
        }
        let tagStart = cursor
        while (cursor < content.size && isTagNameByte(content[cursor])) {
            cursor += 1
        }
        if (cursor == tagStart) {
            return None
        }
        let tagName = asciiLower(content[tagStart..cursor])
        while (cursor < content.size && isSpace(content[cursor])) {
            cursor += 1
        }
        var isSelfClosing = false
        var attrEnd = content.size
        if (attrEnd > cursor && content[attrEnd - 1] == b'/') {
            isSelfClosing = true
            attrEnd -= 1
        }
        let attributesStr = if (attrEnd > cursor) { content[cursor..attrEnd].trimAscii() } else { "" }
        return Some(ParsedInlineTag(
            tagName,
            isClosing,
            isSelfClosing,
            HtmlAttributeUtils.parse(attributesStr),
            attributesStr
        ))
    }

    public static func isSafeInlineTag(tagName: String): Bool {
        return tagName == "span" || tagName == "em" || tagName == "strong" || tagName == "a" ||
            tagName == "kbd" || tagName == "samp" || tagName == "var" || tagName == "mark" ||
            tagName == "small" || tagName == "sub" || tagName == "sup" || tagName == "ins" ||
            tagName == "del" || tagName == "abbr" || tagName == "cite" || tagName == "dfn" ||
            tagName == "time" || tagName == "data" || tagName == "q" || tagName == "b" ||
            tagName == "i" || tagName == "u" || tagName == "s" || tagName == "bdi" ||
            tagName == "bdo" || tagName == "ruby" || tagName == "rt" || tagName == "rp" ||
            tagName == "wbr" || tagName == "picture" || tagName == "font" || tagName == "center" ||
            tagName == "big" || tagName == "tt" || tagName == "strike" || tagName == "br" ||
            tagName == "code" || tagName == "img"
    }

    public static func isContentProtectedTag(tagName: String): Bool {
        return tagName == "code"
    }

    private func isImplicitSelfClosing(tagName: String): Bool {
        return tagName == "br" || tagName == "wbr" || tagName == "img"
    }

    private func isSpace(byte: Byte): Bool {
        return byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r'
    }

    private func isTagNameByte(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') ||
            (byte >= b'A' && byte <= b'Z') ||
            (byte >= b'0' && byte <= b'9') ||
            byte == b'-'
    }
}

private class ParsedInlineTag {
    public let tagName: String
    public let isClosing: Bool
    public let isSelfClosing: Bool
    public let attributes: HashMap<String, String>
    public let attributesStr: String

    public init(
        tagName: String,
        isClosing: Bool,
        isSelfClosing: Bool,
        attributes: HashMap<String, String>,
        attributesStr: String
    ) {
        this.tagName = tagName
        this.isClosing = isClosing
        this.isSelfClosing = isSelfClosing
        this.attributes = attributes
        this.attributesStr = attributesStr
    }
}
