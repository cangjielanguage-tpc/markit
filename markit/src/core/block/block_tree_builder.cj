package markit.core.block

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.SourceLine

public class BlockTreeBuilder {
    public static func parseLines(
        session: ParseSession,
        continuationBlockDispatchTable: ContinuationBlockDispatchTable,
        blockDispatchTable: BlockDispatchTable,
        paragraphBlockParsers: ArrayList<ParagraphBlockParser>,
        lines: ArrayList<SourceLine>
    ): ArrayList<Node> {
        let sealed = ArrayList<Node>()
        var openBlockParser: ?ContinuationBlockParser = None
        var openBlockFrame: ?BlockFrame = None

        func flushParagraph(termination: ParagraphTermination): Unit {
            if (session.pendingParagraphLines.isEmpty()) {
                return
            }

            if (!paragraphBlockParsers.isEmpty()) {
                sealed.add(
                    paragraphBlockParsers[0].finalize(
                        session,
                        session.pendingParagraphLines,
                        session.pendingParagraphSourceSpan(),
                        termination
                    )
                )
            }
            session.clearPendingParagraph()
        }

        func appendParagraph(line: SourceLine): Unit {
            session.addPendingParagraphLine(line)
        }

        func processLine(line: String): Unit {
            if (let Some(parser) <- openBlockParser) {
                if (let Some(frame) <- openBlockFrame) {
                    match (parser.continueBlock(session, frame, line)) {
                        case Open =>
                            return
                        case Closed =>
                            sealed.add(parser.finalize(session, frame))
                            openBlockParser = None
                            openBlockFrame = None
                            return
                        case ClosedAndReprocess =>
                            sealed.add(parser.finalize(session, frame))
                            openBlockParser = None
                            openBlockFrame = None
                            processLine(line)
                            return
                    }
                }
            }

            let maybeHead = firstNonSpaceByte(line)
            if (maybeHead.isNone()) {
                flushParagraph(BlankLine)
                return
            }

            for (parser in continuationBlockDispatchTable.candidatesForFirstNonSpace(maybeHead)) {
                if (let Some(frame) <- parser.tryStart(session, line)) {
                    flushParagraph(BlockBoundary)
                    openBlockParser = Some(parser)
                    openBlockFrame = Some(frame)
                    return
                }
            }

            for (parser in blockDispatchTable.candidatesForFirstNonSpace(maybeHead)) {
                if (let Some(node) <- parser.tryParse(session, line)) {
                    flushParagraph(BlockBoundary)
                    sealed.add(node)
                    return
                }
            }

            if (!paragraphBlockParsers.isEmpty() && paragraphBlockParsers[0].canStart(session, line)) {
                let normalized = paragraphBlockParsers[0].normalizeLine(session, line)
                let trimByteDelta = line.size - normalized.size
                appendParagraph(SourceLine(
                    normalized,
                    session.currentLineSpan().slice(
                        trimByteDelta,
                        session.currentLineSpan().endByte - session.currentLineSpan().startByte,
                        trimByteDelta,
                        session.currentLineSpan().endRune - session.currentLineSpan().startRune
                    ),
                    terminated: session.currentSourceLine().terminated
                ))
            }
        }

        for (line in lines) {
            session.beginLine(line)
            processLine(line.text)
        }

        if (let Some(parser) <- openBlockParser) {
            if (let Some(frame) <- openBlockFrame) {
                sealed.add(parser.finalize(session, frame))
            }
        }
        if (!session.pendingParagraphLines.isEmpty()) {
            let last = session.pendingParagraphLines[session.pendingParagraphLines.size - 1]
            flushParagraph(if (last.terminated) { EndOfInputWithNewline } else { EndOfInput })
        }
        return sealed
    }

    private static func firstNonSpaceByte(line: String): ?Byte {
        var index: Int64 = 0
        while (index < line.size && (line[index] == b' ' || line[index] == b'\t')) {
            index += 1
        }
        if (index >= line.size) {
            return None
        }
        return Some(line[index])
    }
}
