package markit.dsl

import std.collection.ArrayList
import std.fs.{Directory, File, OpenMode, Path, exists}
import std.io.OutputStream
import seajson.JsonWriter
import markit.core.document.DocumentSnapshot
import markit.core.nodes.{DocumentNode, Node}

public class DslDocument {
    private let blockSpecs = ArrayList<BlockSpec>()
    public let options: DslOptions

    public init(options!: DslOptions = DslOptions()) {
        this.options = options
    }

    public init(blocks: Array<BlockSpec>, options!: DslOptions = DslOptions()) {
        this.options = options
        for (block in blocks) {
            blockSpecs.add(block)
        }
    }

    public func withBlock(block: BlockSpec): DslDocument {
        let copied = DslDocument(options: options)
        for (existing in blockSpecs) {
            copied.blockSpecs.add(existing)
        }
        copied.blockSpecs.add(block)
        return copied
    }

    public func withBlocks(blocks: Array<BlockSpec>): DslDocument {
        let copied = DslDocument(options: options)
        for (existing in blockSpecs) {
            copied.blockSpecs.add(existing)
        }
        for (block in blocks) {
            copied.blockSpecs.add(block)
        }
        return copied
    }

    public func root(): DocumentNode {
        let ctx = DslBuildContext(options: options)
        let root = ctx.createRoot()
        for (spec in blockSpecs) {
            root.addChild(DslMaterializer.block(ctx, spec))
        }
        if (!root.children.isEmpty()) {
            root.sourceSpan = ctx.spanForChildren(root.children, root.sourceSpan)
        }
        return root
    }

    public func snapshot(): DocumentSnapshot {
        return DocumentSnapshot(root())
    }

    public func toNode(): Node {
        return root()
    }

    public func toString(): String {
        return root().toString()
    }

    public func toHtml(): String {
        return root().toHtml()
    }

    public func html(): String {
        return toHtml()
    }

    public func toMarkdown(): String {
        return root().toMarkdown()
    }

    public func markdown(): String {
        return toMarkdown()
    }

    public func toTypst(): String {
        return root().toTypst()
    }

    public func typst(): String {
        return toTypst()
    }

    public func toJson(): String {
        return root().toJson()
    }

    public func json(): String {
        return toJson()
    }

    public func write(out: OutputStream): Unit {
        root().write(out)
    }

    public func writeHtml(out: OutputStream): Unit {
        root().writeHtml(out)
    }

    public func writeMarkdown(out: OutputStream): Unit {
        root().writeMarkdown(out)
    }

    public func writeTypst(out: OutputStream): Unit {
        root().writeTypst(out)
    }

    public func writeJson(out: OutputStream): Unit {
        root().writeJson(out)
    }

    public func writeJson(w: JsonWriter): JsonWriter {
        return root().writeJson(w)
    }

    public func dump(path: String, filename!: String = "output.txt"): Unit {
        writeToFile(path, filename, { out: OutputStream => write(out) })
    }

    public func dumpHtml(path: String, filename!: String = "output.html"): Unit {
        writeToFile(path, filename, { out: OutputStream => writeHtml(out) })
    }

    public func dumpMarkdown(path: String, filename!: String = "output.md"): Unit {
        writeToFile(path, filename, { out: OutputStream => writeMarkdown(out) })
    }

    public func dumpTypst(path: String, filename!: String = "output.typ"): Unit {
        writeToFile(path, filename, { out: OutputStream => writeTypst(out) })
    }

    public func dumpJson(path: String, filename!: String = "output.json"): Unit {
        writeToFile(path, filename, { out: OutputStream => writeJson(out) })
    }

    private func writeToFile(path: String, filename: String, writer: (OutputStream) -> Unit): Unit {
        let dir = Path(path)
        if (!exists(dir)) {
            Directory.create(dir, recursive: true)
        }
        try (file = File(dir.join(filename), OpenMode.Write)) {
            writer(file)
        }
    }
}
