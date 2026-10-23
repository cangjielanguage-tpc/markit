package markit.plugins.standard.inline.reference_link

// Both parser paths use this reader-based matcher. EOF is an observed read,
// rather than a request to materialize the containing paragraph.
public class ReferenceSyntax {
    public ReferenceSyntax(public let text: String, public let label: String, public let form: String,
        public let raw: String, public let textStart: Int64, public let textEnd: Int64,
        public let endByte: Int64, public let image: Bool) {}
}

private func referenceClosingBracket(read: (Int64) -> ?Byte, start: Int64): Int64 {
    var cursor = start; var depth: Int64 = 0
    while (let Some(byte) <- read(cursor)) {
        if (byte == b'\\') {
            if (read(cursor + 1).isSome()) { cursor += 2; continue }
        }
        if (byte == b'[') { depth += 1 }
        if (byte == b']') {
            if (depth == 0) { return cursor }
            depth -= 1
        }
        cursor += 1
    }
    return -1
}

public func matchReferenceSyntax(read: (Int64) -> ?Byte, slice: (Int64, Int64) -> String,
    start: Int64, image: Bool): ?ReferenceSyntax {
    var opening = start
    if (image) {
        if (read(start) != Some(b'!')) { return None }
        opening += 1
    }
    if (read(opening) != Some(b'[')) { return None }
    let textStart = opening + 1
    let textEnd = referenceClosingBracket(read, textStart)
    if (textEnd < 0) { return None }
    let text = slice(textStart, textEnd)
    var label = text; var form = "shortcut"; var end = textEnd + 1
    if (read(end) == Some(b'[')) {
        let refEnd = referenceClosingBracket(read, end + 1)
        if (refEnd < 0) { return None }
        let explicit = slice(end + 1, refEnd)
        if (explicit.isEmpty()) { form = "collapsed" } else { label = explicit; form = "full" }
        end = refEnd + 1
    } else if (text.isEmpty()) { return None }
    return Some(ReferenceSyntax(text, label, form, slice(start, end), textStart, textEnd, end, image))
}

public func referenceSemanticKey(label: String): String {
    return "ReferenceLink.definition:" + normalizeReferenceLabel(label)
}

// Preserve the existing grammar's ASCII case normalization. Whitespace and
// Unicode case folding are intentionally not new syntax in this migration.
public func normalizeReferenceLabel(label: String): String {
    var hasUpper = false
    for (rune in label.runes()) { if (rune.isAsciiUpperCase()) { hasUpper = true; break } }
    if (!hasUpper) { return label }
    let result = StringBuilder(label.size)
    for (rune in label.runes()) {
        result.append(if (rune.isAsciiUpperCase()) { rune.toAsciiLowerCase() } else { rune })
    }
    return result.toString()
}
