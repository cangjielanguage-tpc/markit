package markit_kit.processors

import markit.Markit
import markit.core.nodes.{Node, DocumentNode}
import markit.core.incremental.{IncrementalUpdate, AstPatchKind}
import markit.core.session.ParseOptions
import std.collection.{ArrayList, HashMap, HashSet}
import std.env.{getStdIn, getStdOut}
import seajson.buildJsonObject

/**
 * Single append parser, not independent Markdown slices. Only sealed blocks are
 * published. A later definition can revise an already published ancestor.
 * Each frame waits for its consumer: there can be at most one unacknowledged
 * batch. Byte budgets bound input work, not an indivisible huge block's render.
 */
class PreviewStream {
    public static func parse(parser: Markit, content: String, shell: String,
        rewrite: (String) -> String, emit!: ?(String) -> Unit = None): DocumentNode {
        let session = parser.createSession(options: ParseOptions(emitHtmlFragments: false, emitPreview: false))
        let owners = HashMap<Int64, Node>()
        send(ArrayList<PreviewOperation>(), 0, content.size, emit, shell: shell)
        let bytes = content.toArray()
        var consumed: Int64 = 0
        var budget: Int64 = 4096
        while (consumed < bytes.size) {
            let end = min(bytes.size, consumed + budget)
            let update = session.feedBytes(bytes.slice(consumed, end - consumed))
            consumed = end
            let operations = operationsFor(update, owners, rewrite)
            send(operations, consumed, bytes.size, emit)
            budget = 16384
        }
        // Final hooks may group/rewrite root nodes without patch events. The
        // ordinary completed HTML file is the authoritative final reconciliation.
        session.finalize()
        return (session.snapshot().root as DocumentNode).getOrThrow()
    }

    private static func index(node: Node, owner: Node, owners: HashMap<Int64, Node>): Unit {
        owners[node.id] = owner
        for (child in node.children) { index(child, owner, owners) }
    }

    private static func operationsFor(update: IncrementalUpdate, owners: HashMap<Int64, Node>,
        rewrite: (String) -> String): ArrayList<PreviewOperation> {
        let operations = ArrayList<PreviewOperation>()
        let emitted = HashSet<Int64>()
        for (node in update.sealedBlocks) {
            index(node, node, owners)
            operations.add(PreviewOperation(node.id, "append", rewrite(node.toHtml())))
            emitted.add(node.id)
        }
        // Patch ids may refer to inline children. Rerender their top-level owner
        // rather than inventing HTML element ids or reparsing a source slice.
        for (patch in update.astPatches) {
            if (let Some(owner) <- owners.get(patch.nodeId)) {
                if (!emitted.contains(owner.id)) {
                    match (patch.kind) {
                        case RemoveNode =>
                            if (patch.nodeId == owner.id) {
                                operations.add(PreviewOperation(owner.id, "remove", ""))
                            } else {
                                operations.add(PreviewOperation(owner.id, "replace", rewrite(owner.toHtml())))
                            }
                        case _ => operations.add(PreviewOperation(owner.id, "replace", rewrite(owner.toHtml())))
                    }
                    emitted.add(owner.id)
                    index(owner, owner, owners)
                }
            }
        }
        return operations
    }

    private static func send(operations: ArrayList<PreviewOperation>, consumed: Int64,
        total: Int64, emit: ?(String) -> Unit, shell!: String = ""): Unit {
        let frame = buildJsonObject({ w =>
            w.name("type").value("preview")
            w.name("consumedBytes").value(consumed)
            w.name("totalBytes").value(total)
            if (!shell.isEmpty()) { w.name("shell").value(shell) }
            w.name("operations").beginArray()
            for (operation in operations) {
                w.beginObject().name("id").value(operation.id)
                    .name("kind").value(operation.kind).name("html").value(operation.html).endObject()
            }
            w.endArray()
        })
        if (let Some(sink) <- emit) { sink(frame); return }
        let output = getStdOut()
        // Leading newline separates the protocol from CLI progress messages.
        output.write("\nMARKIT_PREVIEW\t${frame}\n")
        output.flush()
        if ((getStdIn().readln() ?? "") != "ack") {
            throw IllegalArgumentException("Preview stream cancelled: acknowledgement input closed")
        }
    }
}

private class PreviewOperation {
    public let id: Int64
    public let kind: String
    public let html: String
    public init(id: Int64, kind: String, html: String) {
        this.id = id
        this.kind = kind
        this.html = html
    }
}
