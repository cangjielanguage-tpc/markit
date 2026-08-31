package markit.plugins.commonmark.inline.commonmark_autolink

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class CommonMarkAutolinkParser <: InlineParser {
    public prop name: String {
        get() {
            return "CommonMarkAutolinkParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "CommonMarkAutolinkPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 700
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'<']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 4 || input[startByte] != b'<') {
            return None
        }

        var end: Int64 = startByte + 1
        while (end < endByte && input[end] != b'>') {
            let byte = input[end]
            if (byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r' || byte == b'<') {
                return None
            }
            end += 1
        }
        if (end >= endByte || input[end] != b'>') {
            return None
        }

        let content = input[startByte + 1..end]
        let parsed = parseContent(content)
        if (parsed.isNone()) {
            return None
        }

        let info = parsed.getOrThrow()
        let raw = input[startByte..end + 1]
        let rawRunes = InlineUtils.countRunes(input, startByte, end + 1)
        let node = session.attachNode(CommonMarkAutolinkNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, raw.size, 0, rawRunes),
            info.autolinkType,
            info.url,
            info.displayText,
            raw
        ))
        return Some(InlineParseResult(node, raw.size, rawRunes))
    }

    private func parseContent(content: String): ?AutolinkInfo {
        if (isUri(content)) {
            return Some(AutolinkInfo(Url, content, content))
        }
        if (isEmail(content)) {
            return Some(AutolinkInfo(Email, "mailto:" + content, content))
        }
        return None
    }

    private func isUri(content: String): Bool {
        let colon = content.indexOf(b':')
        if (colon.isNone()) {
            return false
        }
        let colonPos = colon.getOrThrow()
        if (colonPos < 2 || colonPos > 32 || colonPos >= content.size - 1) {
            return false
        }
        let first = content[0]
        if (!isAsciiAlpha(first)) {
            return false
        }
        for (byte in content[1..colonPos]) {
            if (!(isAsciiAlpha(byte) || isAsciiDigit(byte) || byte == b'+' || byte == b'.' || byte == b'-')) {
                return false
            }
        }
        return true
    }

    private func isEmail(content: String): Bool {
        let at = content.indexOf(b'@')
        if (at.isNone()) {
            return false
        }
        let atPos = at.getOrThrow()
        if (atPos <= 0 || atPos >= content.size - 1) {
            return false
        }
        return isEmailLocal(content[0..atPos]) && isEmailDomain(content[atPos + 1..])
    }

    private func isEmailLocal(local: String): Bool {
        if (local.isEmpty()) {
            return false
        }
        for (byte in local) {
            if (!(isAsciiAlpha(byte) || isAsciiDigit(byte) ||
                byte == b'.' || byte == b'-' || byte == b'_' || byte == b'+' ||
                byte == b'!' || byte == b'#' || byte == b'$' || byte == b'%' ||
                byte == b'&' || byte == b'\'' || byte == b'*' || byte == b'/' ||
                byte == b'=' || byte == b'?' || byte == b'^' || byte == b'`' ||
                byte == b'{' || byte == b'|' || byte == b'}' || byte == b'~')) {
                return false
            }
        }
        return true
    }

    private func isEmailDomain(domain: String): Bool {
        if (domain.size < 3) {
            return false
        }
        var hasDot = false
        var previousDot = false
        for (i in 0..domain.size) {
            let byte = domain[i]
            if (byte == b'.') {
                if (i == 0 || i == domain.size - 1 || previousDot) {
                    return false
                }
                hasDot = true
                previousDot = true
                continue
            }
            previousDot = false
            if (!(isAsciiAlpha(byte) || isAsciiDigit(byte) || byte == b'-')) {
                return false
            }
        }
        return hasDot
    }

    private func isAsciiAlpha(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') || (byte >= b'A' && byte <= b'Z')
    }

    private func isAsciiDigit(byte: Byte): Bool {
        return byte >= b'0' && byte <= b'9'
    }
}

private class AutolinkInfo {
    public let autolinkType: AutolinkType
    public let url: String
    public let displayText: String

    public init(autolinkType: AutolinkType, url: String, displayText: String) {
        this.autolinkType = autolinkType
        this.url = url
        this.displayText = displayText
    }
}
