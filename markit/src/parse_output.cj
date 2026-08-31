package markit

import std.io.OutputStream
import seajson.JsonWriter
import markit.core.document.DocumentSnapshot
import markit.core.incremental.IncrementalUpdate
import markit.core.nodes.Node
import markit.core.render.RenderRegistry
import markit.core.session.SessionSymbolTableStore

public class ParseOutput {
    public let snapshot: DocumentSnapshot
    public let finalUpdate: IncrementalUpdate
    private let tables: SessionSymbolTableStore
    private let renderRegistry: RenderRegistry

    public init(
        snapshot: DocumentSnapshot,
        finalUpdate: IncrementalUpdate,
        symbolTables: SessionSymbolTableStore,
        renderRegistry: RenderRegistry
    ) {
        this.snapshot = snapshot
        this.finalUpdate = finalUpdate
        this.tables = symbolTables
        this.renderRegistry = renderRegistry
    }

    public func html(): String {
        return renderRegistry.renderHtml(snapshot.root)
    }

    public func markdown(): String {
        return renderRegistry.renderMarkdown(snapshot.root)
    }

    public func typst(): String {
        return renderRegistry.renderTypst(snapshot.root)
    }

    public func json(): String {
        return snapshot.root.toJson()
    }

    public func toHtml(): String {
        return html()
    }

    public func toMarkdown(): String {
        return markdown()
    }

    public func toTypst(): String {
        return typst()
    }

    public func toJson(): String {
        return json()
    }

    public func toString(): String {
        return snapshot.root.toString()
    }

    public func write(out: OutputStream): Unit {
        snapshot.root.write(out)
    }

    public func writeHtml(out: OutputStream): Unit {
        renderRegistry.writeHtml(snapshot.root, out)
    }

    public func writeMarkdown(out: OutputStream): Unit {
        renderRegistry.writeMarkdown(snapshot.root, out)
    }

    public func writeTypst(out: OutputStream): Unit {
        renderRegistry.writeTypst(snapshot.root, out)
    }

    public func writeJson(out: OutputStream): Unit {
        snapshot.root.writeJson(out)
    }

    public func writeJson(w: JsonWriter): JsonWriter {
        return snapshot.root.writeJson(w)
    }

    public func dump(path: String, filename!: String = "output.txt"): Unit {
        snapshot.root.dump(path, filename: filename)
    }

    public func dumpHtml(path: String, filename!: String = "output.html"): Unit {
        snapshot.root.dumpHtml(path, filename: filename)
    }

    public func dumpMarkdown(path: String, filename!: String = "output.md"): Unit {
        snapshot.root.dumpMarkdown(path, filename: filename)
    }

    public func dumpTypst(path: String, filename!: String = "output.typ"): Unit {
        snapshot.root.dumpTypst(path, filename: filename)
    }

    public func dumpJson(path: String, filename!: String = "output.json"): Unit {
        snapshot.root.dumpJson(path, filename: filename)
    }

    public func root(): Node {
        return snapshot.root
    }

    public func symbolTables(): SessionSymbolTableStore {
        return tables
    }
}
