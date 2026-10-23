package markit.plugins.standard.block.paragraph

import std.collection.ArrayList
import markit.core.block.ParagraphBlockParser
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SourceSpan}
import markit.core.block.BlockEditingContext
import markit.core.editing.*
import markit.core.nodes.RawSyntaxNode
import markit.plugins.standard.editing.*

public class ParagraphBlockParserImpl <: ParagraphBlockParser {
    private let facet = ParagraphEditingFacet()
    public ParagraphBlockParserImpl(private let planFactory!: ?() -> StandardInlinePlan = None,
        private let boundaryFactory!: ?() -> ParagraphBlockBoundary = None) {}
    public prop supportsIncremental: Bool { get() { return planFactory.isSome() } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return if (planFactory.isSome()) { Some(facet) } else { None } } }
    public prop incrementalIsolation: ?ParserIsolationProof {
        get() { return if (planFactory.isSome()) {
            Some(ParserIsolationProof(syntaxBoundary: true, stateBoundary: true, semanticBoundary: true,
                evidence: "provider-mapped paragraph view; immutable child snapshots and owner-keyed reads"))
        } else { None } }
    }
    public prop name: String {
        get() {
            return "ParagraphBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "ParagraphPlugin"
        }
    }

    public func canStart(_: ParseSession, line: String): Bool {
        return !line.trimAscii().isEmpty()
    }

    public func normalizeLine(_: ParseSession, line: String): String {
        return line.trimAsciiStart()
    }

    public func finalize(
        session: ParseSession,
        lines: ArrayList<SourceLine>,
        sourceSpan: SourceSpan,
        termination: ParagraphTermination
    ): Node {
        if (let Some(editing) <- session.editingContext) {
            let context = (editing as BlockEditingContext).getOrThrow()
            let plan = planFactory.getOrThrow()()
            let id = session.allocateNodeId()
            let view = paragraphEditingView(context, lines, termination, id)
            let saved = standardLeafSessionCheckpoint(session)
            let entry = facet.checkpoint(context).getOrThrow()
            let closed = standardClosedKernelCheckpoint(session)
            let engine = plan.create()
            let recovery = StandardBlockRecovery(saved, entry, closed, entry, closed)
            let boundary = if (let Some(factory) <- boundaryFactory) { factory() } else { ParagraphBlockBoundary([], []) }
            let node = session.attachNode(EditingParagraphNode(id, sourceSpan, view, context.source, plan, engine, recovery, boundary))
            node.rawFollowsMappedView = view.normalizedRaw
            let terminal = !lines.isEmpty() && ParagraphChildrenBuilder.shouldAppendTerminalSoftBreak(lines[lines.size - 1], termination)
            node.contentEnd = view.byteLength - if (terminal) { 1 } else { 0 }
            let owner = RawSyntaxNode(SyntaxNodeIdentity(context.documentId, id), context.sourceVersion,
                SourceAnchor(context.source.identity, sourceSpan.startByte, affinity: AnchorAffinity.Before),
                SourceAnchor(context.source.identity, sourceSpan.endByte, affinity: AnchorAffinity.After), ParagraphShellPayload())
            node.initialSnapshot = Some(engine.parseInitial(context, view, owner))
            return node
        }
        let text = ParagraphChildrenBuilder.paragraphContent(lines)
        let node = session.attachNode(ParagraphNode(
            session.allocateNodeId(),
            sourceSpan,
            text
        ))
        ParagraphChildrenBuilder.appendChildren(session, node, lines, termination, content: text)
        return node
    }
}
