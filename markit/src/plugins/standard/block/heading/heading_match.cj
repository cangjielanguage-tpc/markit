package markit.plugins.standard.block.heading

// Both legacy parsing and editing recovery use this exact ATX matcher.
public class HeadingMatch {
    public HeadingMatch(public let startByte: Int64, public let textStartByte: Int64,
        public let text: String, public let level: Int64, public let closable: Bool) {}
}

public func matchAtxHeading(line: String, closableEnabled!: Bool = false): ?HeadingMatch {
    var index: Int64 = 0
    var indentWidth: Int64 = 0
    while (index < line.size && (line[index] == b' ' || line[index] == b'\t')) {
        indentWidth += if (line[index] == b'\t') { 4 } else { 1 }
        if (indentWidth > 3) { return None }
        index += 1
    }
    if (index >= line.size || line[index] != b'#') { return None }
    let start = index
    while (index < line.size && line[index] == b'#') { index += 1 }
    let level = index - start
    if (level < 1 || level > 6) { return None }
    if (index < line.size && line[index] != b' ' && line[index] != b'\t') { return None }
    while (index < line.size && (line[index] == b' ' || line[index] == b'\t')) { index += 1 }
    let textStart = index
    var end = line.size
    while (end > textStart && (line[end - 1] == b' ' || line[end - 1] == b'\t')) { end -= 1 }
    if (end <= textStart) { return None }
    var text = line[textStart..end]
    let closable = closableEnabled && HeadingMarkerUtils.isClosableContent(text, level)
    if (closable) { text = HeadingMarkerUtils.trimClosableSuffix(text, level) }
    return Some(HeadingMatch(start, textStart, text, level, closable))
}
