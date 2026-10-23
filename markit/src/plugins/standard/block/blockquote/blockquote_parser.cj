package markit.plugins.standard.block.blockquote

import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult, BlockEditingContext}
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.{SyntheticSourceBuilder, SyntheticSourceParseInput}
import markit.core.editing.{IncrementalParserFacet, ParserIsolationProof}
import markit.plugins.standard.editing.{StandardBlockRecovery, standardClosedKernelCheckpoint}
import markit.plugins.standard.block.heading.{parseMappedHeadingContributions, rebaseHeadingContributions}
import markit.plugins.standard.block.paragraph.withMappedParagraphRaw

public class BlockquoteParser <: ContinuationBlockParser {
    private let facet = BlockquoteEditingFacet()
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(facet) } }
    public prop incrementalIsolation: ?ParserIsolationProof {
        get() { return Some(ParserIsolationProof(syntaxBoundary: true, stateBoundary: true,
            semanticBoundary: true, evidence: "Shared quote matcher; mapped child recovery; owner-scoped effects")) }
    }
    public prop name: String {
        get() {
            return "BlockquoteParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "BlockquotePlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 70
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'>']
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (let Some(start) <- blockquoteContentStart(line)) {
            let state = BlockquoteState(session.currentLineSpan())
            if (let Some(context) <- session.editingContext) {
                let syntax = facet.checkpoint(context).getOrThrow()
                let closed = standardClosedKernelCheckpoint(session)
                state.recovery = Some(StandardBlockRecovery(session.checkpoint(), syntax, closed, syntax, closed))
            }
            state.addLine(if (start < line.size) { line[start..] } else { "" }, session.currentSourceLine())
            return Some(BlockFrame(state))
        }
        return None
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as BlockquoteState).getOrThrow()
        if (let Some(start) <- blockquoteContentStart(line)) {
            state.addLine(if (start < line.size) { line[start..] } else { "" }, session.currentSourceLine())
            return Open
        }

        if (blockquoteContinues(line)) {
            state.addLine(line, session.currentSourceLine())
            return Open
        }

        return ClosedAndReprocess
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as BlockquoteState).getOrThrow()
        let id = session.allocateNodeId()
        let node = session.attachNode(if (let Some(recovery) <- state.recovery) {
            let context = (session.editingContext.getOrThrow() as BlockEditingContext).getOrThrow()
            let parentDepth = blockquoteParentDepth(context, state.sourceSpan.startByte)
            // Continuation starts are tested before the kernel flushes a
            // preceding paragraph. Capture the closed entry after that flush,
            // before parsing quote children, so recovery cannot replay it.
            EditingBlockquoteNode(id, state.sourceSpan, StandardBlockRecovery(session.checkpoint(),
                recovery.syntax, recovery.kernel, recovery.expectedExit, recovery.expectedKernel), facet,
                blockquoteRawView(context, state.sourceSpan.startByte, state.sourceSpan.endByte, parentDepth, id), parentDepth)
        } else { BlockquoteNode(id, state.sourceSpan) })
        if (let Some(context) <- session.editingContext) {
            let lines = blockquoteChildLines(state.lines)
            let mappedContext = (context as BlockEditingContext).getOrThrow()
            let children = parseMappedHeadingContributions(session, {
                => withMappedParagraphRaw(mappedContext, { => session.parseDetachedLines(lines) })
            })
            for (child in children) {
                freezeMappedBlockquoteRaw(child, lines, context.sourceVersion, context.documentId)
                node.addChild(child)
            }
            rebaseHeadingContributions(session, children.toArray())
            return node
        }
        let synthetic = SyntheticSourceBuilder.build(state.lines, preserveTrailingNewline: false)
        for (child in session.parseDetachedLines(synthetic.lines)) {
            child.attachSource(synthetic.source)
            freezeSyntheticRawContent(child)
            restoreSourceSpans(child, synthetic)
            node.addChild(child)
        }
        return node
    }

    private func restoreSourceSpans(node: Node, source: SyntheticSourceParseInput): Unit {
        node.sourceSpan = source.mapSpan(node.sourceSpan)
        for (child in node.children) {
            restoreSourceSpans(child, source)
        }
    }

    private func freezeSyntheticRawContent(node: Node): Unit {
        node.setRawContent(node.rawContent())
        for (child in node.children) {
            freezeSyntheticRawContent(child)
        }
    }

}
