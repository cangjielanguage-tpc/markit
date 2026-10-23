package markit.plugins.standard.block.blockquote

import markit.core.source.{SourceLine, SourceSpan, EditableRopeVersion}

// One matcher serves continuation parsing and mapped editing recovery.
public func blockquoteContentStart(line: String): ?Int64 {
    return matchBlockquoteContentStart(line.size, { index: Int64 => line[index] })
}

public func blockquoteSourceContentStart(source: EditableRopeVersion, start: Int64, end: Int64): ?Int64 {
    return matchBlockquoteContentStart(end - start, { index: Int64 => source.readByte(start + index) })
}

private func matchBlockquoteContentStart(size: Int64, read: (Int64) -> Byte): ?Int64 {
    var index: Int64 = 0
    var indent: Int64 = 0
    while (index < size && (read(index) == b' ' || read(index) == b'\t')) {
        indent += if (read(index) == b' ') { 1 } else { 4 }
        if (indent > 3) { return None }
        index += 1
    }
    if (index >= size || read(index) != b'>') { return None }
    index += 1
    if (index < size && read(index) == b' ') { index += 1 }
    return Some(index)
}

public func blockquoteStartsOuterBlock(line: String): Bool {
    let trimmed = line.trimAscii()
    if (trimmed.isEmpty()) { return false }
    let first = trimmed[0]
    return blockquoteOuterStartByte(first)
}

private func blockquoteOuterStartByte(first: Byte): Bool {
    return first == b'#' || first == b'>' || first == b'-' || first == b'*' || first == b'+' ||
        (first >= b'0' && first <= b'9') || first == b'`' || first == b'~' || first == b'_'
}

public func blockquoteSourceContinues(source: EditableRopeVersion, start: Int64, end: Int64): Bool {
    if (blockquoteSourceContentStart(source, start, end).isSome()) { return true }
    var first = start
    while (first < end && source.readByte(first).isAsciiWhiteSpace()) { first += 1 }
    return first < end && !blockquoteOuterStartByte(source.readByte(first))
}

public func blockquoteContinues(line: String): Bool {
    return blockquoteContentStart(line).isSome() || (!line.trimAscii().isEmpty() && !blockquoteStartsOuterBlock(line))
}

public func blockquoteMappedLine(line: SourceLine): SourceLine {
    let start = blockquoteContentStart(line.text) ?? 0
    // A marker consists entirely of ASCII, so its byte and rune widths agree.
    return SourceLine(if (start < line.text.size) { line.text[start..] } else { "" },
        SourceSpan(line.span.startByte + start, line.span.endByte,
            line.span.startRune + start, line.span.endRune), terminated: line.terminated)
}
