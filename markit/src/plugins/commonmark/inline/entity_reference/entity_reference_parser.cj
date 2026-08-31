package markit.plugins.commonmark.inline.entity_reference

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class EntityReferenceParser <: InlineParser {
    public prop name: String {
        get() {
            return "EntityReferenceParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "EntityReferencePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 1500
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'&']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 4 || input[startByte] != b'&') {
            return None
        }

        var end: Int64 = startByte + 1
        while (end < endByte && input[end] != b';' && end - startByte <= 32) {
            end += 1
        }
        if (end >= endByte || input[end] != b';' || end == startByte + 1 || end - startByte > 32) {
            return None
        }

        let content = input[startByte + 1..end]
        let entityType = classify(content)
        if (entityType.isNone()) {
            return None
        }

        let raw = input[startByte..end + 1]
        let rawRunes = InlineUtils.countRunes(input, startByte, end + 1)
        let node = session.attachNode(EntityReferenceNode(
            session.allocateNodeId(),
            InlineUtils.spanWithRunes(baseSpan, 0, raw.size, 0, rawRunes),
            entityType.getOrThrow(),
            content,
            raw
        ))
        return Some(InlineParseResult(node, raw.size, rawRunes))
    }

    private func classify(content: String): ?EntityType {
        if (isNamedEntity(content)) {
            return Some(Named)
        }
        if (content.size >= 2 && content[0] == b'#') {
            if (isDecimal(content[1..])) {
                return Some(Decimal)
            }
            if (content.size >= 3 && (content[1] == b'x' || content[1] == b'X') && isHex(content[2..])) {
                return Some(Hexadecimal)
            }
        }
        return None
    }

    private func isNamedEntity(value: String): Bool {
        return value == "amp" || value == "lt" || value == "gt" || value == "quot" ||
            value == "apos" || value == "nbsp" || value == "copy" || value == "reg" ||
            value == "trade" || value == "hellip" || value == "mdash" || value == "ndash" ||
            value == "lsquo" || value == "rsquo" || value == "ldquo" || value == "rdquo" ||
            value == "bull" || value == "middot" || value == "iexcl" || value == "cent" ||
            value == "pound" || value == "curren" || value == "yen" || value == "brvbar" ||
            value == "sect" || value == "uml" || value == "ordf" || value == "laquo" ||
            value == "not" || value == "shy" || value == "macr" || value == "deg" ||
            value == "plusmn" || value == "sup2" || value == "sup3" || value == "acute" ||
            value == "micro" || value == "para" || value == "cedil" || value == "sup1" ||
            value == "ordm" || value == "raquo" || value == "frac14" || value == "frac12" ||
            value == "frac34" || value == "iquest"
    }

    private func isDecimal(value: String): Bool {
        if (value.isEmpty()) {
            return false
        }
        for (byte in value) {
            if (byte < b'0' || byte > b'9') {
                return false
            }
        }
        return true
    }

    private func isHex(value: String): Bool {
        if (value.isEmpty()) {
            return false
        }
        for (byte in value) {
            if (!((byte >= b'0' && byte <= b'9') ||
                (byte >= b'a' && byte <= b'f') ||
                (byte >= b'A' && byte <= b'F'))) {
                return false
            }
        }
        return true
    }
}
