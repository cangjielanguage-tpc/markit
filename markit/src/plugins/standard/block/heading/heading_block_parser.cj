package markit.plugins.standard.block.heading

import markit.core.block.LeafBlockParser
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class HeadingBlockParser <: LeafBlockParser {
    private let closableConfig: HeadingClosableConfig

    public init(closableConfig!: HeadingClosableConfig = HeadingClosableConfig()) {
        this.closableConfig = closableConfig
    }

    public prop name: String {
        get() {
            return "HeadingBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "HeadingPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 100
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'#']
        }
    }

    public prop acceptsAnyNonBlank: Bool {
        get() {
            return false
        }
    }

    public func tryParse(session: ParseSession, line: String): ?Node {
        var index: Int64 = 0
        var indentWidth: Int64 = 0
        while (index < line.size && (line[index] == b' ' || line[index] == b'\t')) {
            indentWidth += if (line[index] == b'\t') { 4 } else { 1 }
            if (indentWidth > 3) {
                return None
            }
            index += 1
        }

        if (index >= line.size) {
            return None
        }

        let startByte = index
        let working = line[startByte..]
        if (working.isEmpty() || working[0] != b'#') {
            return None
        }

        var level: Int64 = 0
        while (level < working.size && working[level] == b'#') {
            level += 1
        }
        if (level < 1 || level > 6) {
            return None
        }
        if (level < working.size && working[level] != b' ' && working[level] != b'\t') {
            return None
        }

        var textStart = level
        while (textStart < working.size && (working[textStart] == b' ' || working[textStart] == b'\t')) {
            textStart += 1
        }
        if (textStart >= working.size) {
            return None
        }

        var textEnd = working.size
        while (textEnd > textStart && (working[textEnd - 1] == b' ' || working[textEnd - 1] == b'\t')) {
            textEnd -= 1
        }
        var text = working[textStart..textEnd]
        if (text.isEmpty()) {
            return None
        }

        let isClosable = closableConfig.enabled && HeadingMarkerUtils.isClosableContent(text, level)
        if (isClosable) {
            text = HeadingMarkerUtils.trimClosableSuffix(text, level)
        }

        let state = session.symbolTables.get(HeadingPlugin.stateKey)
        let slugAllocation = state.allocateSlug(text)
        let headingSpan = lineSubSpan(session.currentLineSpan(), line, startByte, line.size)
        let textSpan = lineSubSpan(session.currentLineSpan(), line, startByte + textStart, startByte + textStart + text.size)
        let node = session.attachNode(HeadingNode(
            session.allocateNodeId(),
            headingSpan,
            text,
            level,
            slug: slugAllocation.uniqueSlug
        ))
        node.setString("baseSlug", slugAllocation.baseSlug)
        node.setInt("slugOccurrence", slugAllocation.occurrence)
        if (!slugAllocation.typstLabel.isEmpty()) {
            node.setString("typstLabel", slugAllocation.typstLabel)
        }
        session.appendInlineChildren(node, text, textSpan)

        let number = state.assignNumber(level)
        if (!number.isEmpty()) {
            node.setString("number", number)
            node.setBool("numberInHtml", state.includeNumberInHtml())
        }
        if (isClosable) {
            node.setBool("closable", true)
        }
        return Some(node)
    }

    private func lineSubSpan(
        baseSpan: SourceSpan,
        line: String,
        startByte: Int64,
        endByte: Int64
    ): SourceSpan {
        let prefix = if (startByte > 0) { line[0..startByte] } else { "" }
        let text = if (endByte > startByte) { line[startByte..endByte] } else { "" }
        let startRuneDelta = countRunes(prefix)
        let endRuneDelta = startRuneDelta + countRunes(text)
        return baseSpan.slice(startByte, endByte, startRuneDelta, endRuneDelta)
    }

    private func countRunes(text: String): Int64 {
        var count: Int64 = 0
        for (_ in text.runes()) {
            count += 1
        }
        return count
    }
}
