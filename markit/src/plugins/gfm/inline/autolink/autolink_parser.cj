package markit.plugins.gfm.inline.autolink

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class AutolinkParser <: InlineParser {
    public prop name: String {
        get() {
            return "AutolinkParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "AutolinkPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 750
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [
                b'h', b'f',
                b'a', b'b', b'c', b'd', b'e', b'g', b'i', b'j', b'k', b'l', b'm',
                b'n', b'o', b'p', b'q', b'r', b's', b't', b'u', b'v', b'w', b'x',
                b'y', b'z',
                b'A', b'B', b'C', b'D', b'E', b'F', b'G', b'H', b'I', b'J', b'K',
                b'L', b'M', b'N', b'O', b'P', b'Q', b'R', b'S', b'T', b'U', b'V',
                b'W', b'X', b'Y', b'Z',
                b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9'
            ]
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (let Some(result) <- tryParseUrl(session, input, startByte, endByte, baseSpan)) {
            return Some(result)
        }
        return tryParseEmail(session, input, startByte, endByte, baseSpan)
    }

    private func tryParseUrl(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        let protocolLen = if (hasPrefix(input, startByte, endByte, "http://")) {
            7
        } else if (hasPrefix(input, startByte, endByte, "https://")) {
            8
        } else if (hasPrefix(input, startByte, endByte, "ftp://")) {
            6
        } else {
            return None
        }

        var end = startByte + protocolLen
        while (end < endByte && isValidUrlByte(input[end])) {
            end += 1
        }
        if (end <= startByte + protocolLen) {
            return None
        }
        while (end > startByte + protocolLen && isTrailingPunctuation(input[end - 1])) {
            end -= 1
        }
        if (end <= startByte + protocolLen) {
            return None
        }

        let url = input[startByte..end]
        return Some(makeNode(session, baseSpan, Url, url, url, url))
    }

    private func tryParseEmail(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        var atPos: Int64 = -1
        var cursor: Int64 = startByte
        while (cursor < endByte && !isEmailBoundary(input[cursor])) {
            if (input[cursor] == b'@') {
                atPos = cursor
                break
            }
            if (!isValidEmailLocalByte(input[cursor])) {
                return None
            }
            cursor += 1
        }

        if (atPos <= startByte) {
            return None
        }

        var domainEnd = atPos + 1
        var hasDot = false
        var previousDot = false
        while (domainEnd < endByte && isValidEmailDomainByte(input[domainEnd])) {
            if (input[domainEnd] == b'.') {
                if (domainEnd == atPos + 1 || previousDot) {
                    return None
                }
                hasDot = true
                previousDot = true
            } else {
                previousDot = false
            }
            domainEnd += 1
        }

        while (domainEnd > atPos + 1 && isTrailingPunctuation(input[domainEnd - 1])) {
            domainEnd -= 1
        }
        if (!hasDot || domainEnd <= atPos + 1 || input[domainEnd - 1] == b'.') {
            return None
        }

        let email = input[startByte..domainEnd]
        return Some(makeNode(session, baseSpan, Email, "mailto:" + email, email, email))
    }

    private func hasPrefix(input: String, startByte: Int64, endByte: Int64, prefix: String): Bool {
        if (endByte - startByte < prefix.size) {
            return false
        }
        var index: Int64 = 0
        while (index < prefix.size) {
            if (input[startByte + index] != prefix[index]) {
                return false
            }
            index += 1
        }
        return true
    }

    private func makeNode(
        session: ParseSession,
        baseSpan: SourceSpan,
        autolinkType: AutolinkType,
        url: String,
        displayText: String,
        raw: String
    ): InlineParseResult {
        let node = session.attachNode(AutolinkNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, raw.size, 0, InlineUtils.countRunes(raw)),
            autolinkType,
            url,
            displayText,
            raw
        ))
        return InlineParseResult(node, raw.size, InlineUtils.countRunes(raw))
    }

    private func isValidUrlByte(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') ||
            (byte >= b'A' && byte <= b'Z') ||
            (byte >= b'0' && byte <= b'9') ||
            byte == b'-' || byte == b'.' || byte == b'_' || byte == b'~' ||
            byte == b':' || byte == b'/' || byte == b'?' || byte == b'#' ||
            byte == b'[' || byte == b']' || byte == b'@' || byte == b'!' ||
            byte == b'$' || byte == b'&' || byte == b'\'' || byte == b'(' ||
            byte == b')' || byte == b'*' || byte == b'+' || byte == b',' ||
            byte == b';' || byte == b'=' || byte == b'%'
    }

    private func isValidEmailLocalByte(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') ||
            (byte >= b'A' && byte <= b'Z') ||
            (byte >= b'0' && byte <= b'9') ||
            byte == b'.' || byte == b'-' || byte == b'_' || byte == b'+'
    }

    private func isValidEmailDomainByte(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') ||
            (byte >= b'A' && byte <= b'Z') ||
            (byte >= b'0' && byte <= b'9') ||
            byte == b'.' || byte == b'-'
    }

    private func isTrailingPunctuation(byte: Byte): Bool {
        return byte == b'.' || byte == b',' || byte == b';' || byte == b':' ||
            byte == b'!' || byte == b'?' || byte == b')' || byte == b']' ||
            byte == b'}' || byte == b'\''
    }

    private func isEmailBoundary(byte: Byte): Bool {
        return byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r' ||
            byte == b'<' || byte == b'>' || byte == b'(' || byte == b')'
    }
}
