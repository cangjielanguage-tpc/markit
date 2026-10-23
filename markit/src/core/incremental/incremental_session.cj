package markit.core.incremental

import std.collection.ArrayList
import std.io.OutputStream
import seajson.JsonWriter
import markit.core.block.{BlockDispatchTable, BlockParsingKernel, ContinuationBlockDispatchTable, ParagraphBlockParser}
import markit.core.document.DocumentSnapshot
import markit.core.nodes.Node
import markit.core.plugin.NodeEmissionFilter
import markit.core.render.RenderRegistry
import markit.core.session.{ParagraphTermination, ParseSession, SessionSymbolTableStore}
import markit.core.source.{LineScanner, SourceLine, Utf8StreamDecoder}

public class IncrementalSession {
    private let session: ParseSession
    private let continuationDispatchTable: ContinuationBlockDispatchTable
    private let blockDispatchTable: BlockDispatchTable
    private let paragraphBlockParsers: ArrayList<ParagraphBlockParser>
    private let nodeEmissionFilters: ArrayList<NodeEmissionFilter>
    private let renderRegistry: RenderRegistry
    private let lineScanner = LineScanner()
    private let utf8Decoder = Utf8StreamDecoder()
    private let kernel: BlockParsingKernel
    private let sessionFinalizeHooks = ArrayList<(ParseSession) -> Unit>()
    private let postFinalizeHooks = ArrayList<(Node, SessionSymbolTableStore) -> Unit>()

    public IncrementalSession(
        session: ParseSession,
        continuationDispatchTable: ContinuationBlockDispatchTable,
        blockDispatchTable: BlockDispatchTable,
        paragraphBlockParsers: ArrayList<ParagraphBlockParser>,
        nodeEmissionFilters: ArrayList<NodeEmissionFilter>,
        renderRegistry: RenderRegistry
    ) {
        this.session = session
        this.continuationDispatchTable = continuationDispatchTable
        this.blockDispatchTable = blockDispatchTable
        this.paragraphBlockParsers = paragraphBlockParsers
        this.nodeEmissionFilters = nodeEmissionFilters
        this.renderRegistry = renderRegistry
        this.kernel = BlockParsingKernel(session, continuationDispatchTable, blockDispatchTable, paragraphBlockParsers, trimNormalizedSpan: false)
        this.session.root.attachRenderHooks(renderRegistry)
    }

    public func feed(chunk: String): IncrementalUpdate {
        if (session.finalized) {
            throw IllegalArgumentException("Cannot feed after finalize")
        }
        let accepted = session.source.append(chunk)
        return processLines(lineScanner.feed(chunk), accepted)
    }

    public func feedBytes(chunk: Array<Byte>): IncrementalUpdate {
        if (session.finalized) {
            throw IllegalArgumentException("Cannot feed after finalize")
        }
        let decoded = utf8Decoder.feed(chunk)
        let accepted = session.source.appendBytes(chunk)
        return processLines(lineScanner.feed(decoded), accepted)
    }

    public func finalize(): IncrementalUpdate {
        let sealed = ArrayList<Node>()
        let fragments = ArrayList<HtmlFragment>()
        kernel.setEmissionSink({ node: Node => emit(node, sealed, fragments) })
        try {
            utf8Decoder.finalize()
            if (let Some(line) <- lineScanner.finalize()) { processSourceLine(line, sealed, fragments) }
            kernel.finish()
        } finally { kernel.clearEmissionSink() }
        for (hook in sessionFinalizeHooks) {
            hook(session)
        }
        for (hook in postFinalizeHooks) {
            hook(session.root, session.symbolTables)
        }
        session.finalized = true
        session.source.releaseRetainedSource()
        return IncrementalUpdate(
            sealedBlocks: sealed,
            emittedHtmlFragments: fragments,
            astPatches: drainAstPatches(),
            pendingTailState: currentPendingTailState(),
            bytesCommitted: session.source.byteSize,
            isFinal: true
        )
    }

    public func snapshot(): DocumentSnapshot {
        return DocumentSnapshot(session.root, lineIndex: session.lineIndex)
    }

    public func symbolTables(): SessionSymbolTableStore {
        return session.symbolTables
    }

    public func renderer(): RenderRegistry {
        return renderRegistry
    }

    public func addPostFinalizeHook(hook: (Node, SessionSymbolTableStore) -> Unit): Unit {
        postFinalizeHooks.add(hook)
    }

    public func addSessionFinalizeHook(hook: (ParseSession) -> Unit): Unit {
        sessionFinalizeHooks.add(hook)
    }

    public func toString(): String {
        return session.root.toString()
    }

    public func toJson(): String {
        return session.root.toJson()
    }

    public func toHtml(): String {
        return session.root.toHtml()
    }

    public func toMarkdown(): String {
        return session.root.toMarkdown()
    }

    public func toTypst(): String {
        return session.root.toTypst()
    }

    public func write(out: OutputStream): Unit {
        session.root.write(out)
    }

    public func writeHtml(out: OutputStream): Unit {
        session.root.writeHtml(out)
    }

    public func writeMarkdown(out: OutputStream): Unit {
        session.root.writeMarkdown(out)
    }

    public func writeTypst(out: OutputStream): Unit {
        session.root.writeTypst(out)
    }

    public func writeJson(out: OutputStream): Unit {
        session.root.writeJson(out)
    }

    public func writeJson(w: JsonWriter): JsonWriter {
        return session.root.writeJson(w)
    }

    public func dump(path: String, filename!: String = "output.txt"): Unit {
        session.root.dump(path, filename: filename)
    }

    public func dumpHtml(path: String, filename!: String = "output.html"): Unit {
        session.root.dumpHtml(path, filename: filename)
    }

    public func dumpMarkdown(path: String, filename!: String = "output.md"): Unit {
        session.root.dumpMarkdown(path, filename: filename)
    }

    public func dumpTypst(path: String, filename!: String = "output.typ"): Unit {
        session.root.dumpTypst(path, filename: filename)
    }

    public func dumpJson(path: String, filename!: String = "output.json"): Unit {
        session.root.dumpJson(path, filename: filename)
    }

    private func processLines(lines: ArrayList<SourceLine>, bytesAccepted: Int64): IncrementalUpdate {
        let sealed = ArrayList<Node>()
        let fragments = ArrayList<HtmlFragment>()
        kernel.setEmissionSink({ node: Node => emit(node, sealed, fragments) })
        try {
            for (line in lines) { processSourceLine(line, sealed, fragments) }
        } finally { kernel.clearEmissionSink() }

        return IncrementalUpdate(
            sealedBlocks: sealed,
            emittedHtmlFragments: fragments,
            astPatches: drainAstPatches(),
            pendingTailState: currentPendingTailState(),
            bytesAccepted: bytesAccepted
        )
    }

    private func processSourceLine(
        line: SourceLine,
        sealed: ArrayList<Node>,
        fragments: ArrayList<HtmlFragment>
    ): Unit {
        session.recordSourceLine(line)
        kernel.feed(line)
    }

    private func emit(
        node: Node,
        sealed: ArrayList<Node>,
        fragments: ArrayList<HtmlFragment>
    ): Unit {
        for (filter in nodeEmissionFilters) {
            if (!filter.accept(session, node)) {
                return
            }
        }
        session.root.addChild(node)
        if (session.root.children.size == 1) {
            session.root.sourceSpan = node.sourceSpan
        } else {
            session.root.sourceSpan = session.root.sourceSpan.merge(node.sourceSpan)
        }
        sealed.add(node)
        if (session.options.emitHtmlFragments) {
            fragments.add(HtmlFragment(
                node.id,
                node.sourceSpan,
                renderRegistry.renderHtml(node),
                true
            ))
        }
    }

    private func drainAstPatches(): ArrayList<AstPatch> {
        let patches = ArrayList<AstPatch>()
        for (node in session.patches.drainReplaceNodes()) {
            patches.add(AstPatch(
                ReplaceNode,
                node.id,
                node.sourceSpan,
                node: Some(node),
                html: renderRegistry.renderHtml(node),
                markdown: renderRegistry.renderMarkdown(node),
                typst: renderRegistry.renderTypst(node)
            ))
        }
        for (node in session.patches.drainRemoveNodes()) {
            patches.add(AstPatch(
                RemoveNode,
                node.id,
                node.sourceSpan
            ))
        }
        return patches
    }

    private func currentPendingTailState(): PendingTailState {
        if (let Some(parser) <- kernel.activeParser) {
            let span = session.currentLineSpan()
            return PendingTailState(
                summary: "open block: ${parser.name}",
                openBlockKind: parser.name,
                startByteOffset: span.startByte,
                endByteOffset: span.endByte,
                startRuneOffset: span.startRune,
                endRuneOffset: span.endRune,
                previewText: if (session.options.emitPreview) { session.currentSourceLine().text } else { "" }
            )
        }

        if (!session.pendingParagraphLines.isEmpty()) {
            let span = session.pendingParagraphSourceSpan()
            return PendingTailState(
                summary: "pending paragraph",
                openBlockKind: "Paragraph",
                pendingParagraphLineCount: session.pendingParagraphLines.size,
                startByteOffset: span.startByte,
                endByteOffset: span.endByte,
                startRuneOffset: span.startRune,
                endRuneOffset: span.endRune,
                previewText: if (session.options.emitPreview) { pendingParagraphPreview() } else { "" }
            )
        }

        return PendingTailState()
    }

    private func pendingParagraphPreview(): String {
        let sb = StringBuilder()
        for (i in 0..session.pendingParagraphLines.size) {
            if (i > 0) {
                sb.append("\n")
            }
            sb.append(session.pendingParagraphLines[i].text)
        }
        return sb.toString()
    }

}
