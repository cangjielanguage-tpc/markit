package markit.plugins.standard.block.heading

import markit.core.block.LeafBlockParser
import markit.core.nodes.Node
import markit.core.session.{ParseSession, ParseSessionCheckpoint}
import markit.core.source.SourceSpan
import markit.core.block.BlockEditingContext
import markit.core.editing.{IncrementalParserFacet, IncrementalCheckpoint, ParserIsolationProof}
import markit.plugins.standard.editing.{StandardBlockRecovery, standardLeafSessionCheckpoint}

public class HeadingBlockParser <: LeafBlockParser {
    private let facet = HeadingEditingFacet()
    public HeadingBlockParser(private let closableConfig!: HeadingClosableConfig = HeadingClosableConfig()) {}

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

    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public prop incrementalIsolation: ?ParserIsolationProof {
        get() { return Some(ParserIsolationProof(syntaxBoundary: true, stateBoundary: true,
            semanticBoundary: true, evidence: "ATX single-line matcher; detached state codec; owner-keyed contributions")) }
    }

    public func tryParse(session: ParseSession, line: String): ?Node {
        let matched = matchAtxHeading(line, closableEnabled: closableConfig.enabled)
        if (matched.isNone()) { return None }
        let found = matched.getOrThrow()
        let startByte = found.startByte
        let textStart = found.textStartByte - startByte
        let text = found.text
        let level = found.level
        let isClosable = found.closable
        let editing = session.editingContext
        let saved: ?ParseSessionCheckpoint = if (editing.isSome()) { Some(standardLeafSessionCheckpoint(session)) }
            else { Option<ParseSessionCheckpoint>.None }
        let entry: ?IncrementalCheckpoint = if (let Some(context) <- editing) { facet.checkpoint(context) }
            else { Option<IncrementalCheckpoint>.None }
        let state = session.symbolTables.get(HeadingPlugin.stateKey)
        let slugAllocation = if (editing.isSome()) { HeadingSlugAllocation("", "", 0, "") } else { state.allocateSlug(text) }
        let headingSpan = lineSubSpan(session.currentLineSpan(), line, startByte, line.size)
        let textSpan = lineSubSpan(session.currentLineSpan(), line, startByte + textStart, startByte + textStart + text.size)
        let id = session.allocateNodeId()
        let node = session.attachNode(if (editing.isSome()) {
            let closed = closedHeadingKernel(session).checkpoint()
            EditingHeadingNode(id, headingSpan, text, level,
                StandardBlockRecovery(saved.getOrThrow(), entry.getOrThrow(), closed, entry.getOrThrow(), closed))
        } else { HeadingNode(id, headingSpan, text, level, slug: slugAllocation.uniqueSlug) })
        node.setString("baseSlug", slugAllocation.baseSlug)
        node.setInt("slugOccurrence", slugAllocation.occurrence)
        if (!slugAllocation.typstLabel.isEmpty()) {
            node.setString("typstLabel", slugAllocation.typstLabel)
        }
        session.appendInlineChildren(node, text, textSpan)

        let number = if (editing.isSome()) { "" } else { state.assignNumber(level) }
        if (!number.isEmpty()) {
            node.setString("number", number)
            node.setBool("numberInHtml", state.includeNumberInHtml())
        }
        if (isClosable) {
            node.setBool("closable", true)
        }
        if (let Some(context) <- editing) {
            facet.contribute((context as BlockEditingContext).getOrThrow(), (node as HeadingNode).getOrThrow(), headingSpan.startByte)
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
