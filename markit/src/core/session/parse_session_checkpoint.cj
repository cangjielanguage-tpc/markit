package markit.core.session

import markit.core.source.{LineIndexSnapshot, SourceLine, SourceSpan}
import markit.core.nodes.Node
import markit.core.editing.IncrementalParserContext
import std.collection.ArrayList

// The engine's state/effect transaction participates without a session -> block
// dependency. Its unpublished roots must be journalled by this scope.
// complete(true) publishes only prepared local roots. If it throws, the scope
// must remain rollback-capable; complete(false) must release its staged work.
public interface ParseSessionTransactionScope {
    func complete(commit: Bool): Unit
}

public interface ParseSessionTransactionParticipant {
    func beginSessionScope(): ParseSessionTransactionScope
}

// Block frames belong to the block kernel and are composed with this envelope.
// The scope token prevents applying one live session's allocator/state to another.
public class ParseSessionCheckpoint {
    public prop nextNodeId: Int64 { get() { return syntax.nextNodeId } }
    public prop syntaxFingerprint: String { get() { return syntax.fingerprint } }
    internal ParseSessionCheckpoint(internal let scope: ParseSession, internal let syntax: ParseSessionSyntaxCheckpoint, internal let symbols: SessionSymbolTableCheckpoint) {}
}

internal class ParseSessionSyntaxCheckpoint {

    internal ParseSessionSyntaxCheckpoint(internal let activeLine: ?SourceLine, internal let paragraphSpan: ?SourceSpan, internal let pending: Array<SourceLine>,
        internal let nextNodeId: Int64, internal let depth: Int64, internal let indentedStarts: Bool, internal let finalized: Bool,
        internal let patches: SessionPatchSnapshot, internal let patchQueue: SessionPatchQueue, internal let lines: LineIndexSnapshot,
        internal let root: Node, internal let rootChildCount: Int64, internal let editingContext: ?IncrementalParserContext) {}

    internal prop fingerprint: String {
        get() {
            var result = "depth:${depth};indented:${indentedStarts};final:${finalized};"
            if (let Some(line) <- activeLine) {
                result += "active:${line.span.startByte}:${line.span.endByte}:${line.span.startRune}:${line.span.endRune}:${line.terminated}:${line.text.size}:${line.text};"
            } else { result += "active:none;" }
            if (let Some(span) <- paragraphSpan) {
                result += "paragraph:${span.startByte}:${span.endByte}:${span.startRune}:${span.endRune};"
            } else { result += "paragraph:none;" }
            for (line in pending) {
                result += "pending:${line.span.startByte}:${line.span.endByte}:${line.span.startRune}:${line.span.endRune}:${line.terminated}:${line.text.size}:${line.text};"
            }
            return result
        }
    }

    internal func remapLines(mapper: (SourceLine, Bool) -> SourceLine): ParseSessionSyntaxCheckpoint {
        func mapped(line: SourceLine, pending: Bool): SourceLine {
            let result = mapper(line, pending)
            let span = result.span
            if (span.startByte < 0 || span.endByte < span.startByte ||
                span.startRune < 0 || span.endRune < span.startRune) {
                throw IllegalArgumentException("Checkpoint line mapper returned an invalid span")
            }
            if (pending && (result.text != line.text || result.terminated != line.terminated)) {
                throw IllegalArgumentException("Changed pending paragraph requires a wider provider recovery window")
            }
            return result
        }
        let mappedActive: ?SourceLine = if (let Some(line) <- activeLine) {
            Some(mapped(line, false))
        } else { Option<SourceLine>.None }
        let mappedPending = ArrayList<SourceLine>()
        var mappedParagraph: ?SourceSpan = None
        for (line in pending) {
            let result = mapped(line, true)
            mappedPending.add(result)
            mappedParagraph = match (mappedParagraph) {
                case Some(span) => Some(span.merge(result.span))
                case None => Some(result.span)
            }
        }
        return ParseSessionSyntaxCheckpoint(mappedActive, mappedParagraph, mappedPending.toArray(),
            nextNodeId, depth, indentedStarts, finalized, patches, patchQueue, lines,
            root, rootChildCount, editingContext)
    }
}
