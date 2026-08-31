package markit.core.nodes

import std.collection.ArrayList
import std.collection.HashMap
import std.fs.{Directory, File, OpenMode, Path, exists}
import std.io.OutputStream
import seajson.JsonWriter
import markit.core.source.SourceBuffer
import markit.core.source.SourceSpan

public open class Node {
    public let id: Int64
    public let kind: String
    public var sourceSpan: SourceSpan
    public var literal: String
    public var level: Int64
    public var slug: String
    public var info: String
    public var parent: ?Node = None
    public let children = ArrayList<Node>()
    private let stringMeta = HashMap<String, String>()
    private let intMeta = HashMap<String, Int64>()
    private let boolMeta = HashMap<String, Bool>()
    private var sourceBuffer: ?SourceBuffer = None
    private var rawContentOverride: ?String = None
    private var renderHooks: ?NodeRenderHooks = None

    public init(
        kind: String,
        id!: Int64 = 0,
        sourceSpan!: SourceSpan = SourceSpan.empty(),
        literal!: String = "",
        level!: Int64 = 0,
        slug!: String = "",
        info!: String = ""
    ) {
        this.id = id
        this.kind = kind
        this.sourceSpan = sourceSpan
        this.literal = literal
        this.level = level
        this.slug = slug
        this.info = info
    }

    public func addChild(child: Node): Unit {
        child.parent = Some(this)
        if (let Some(source) <- sourceBuffer) {
            child.attachSource(source)
        }
        if (let Some(hooks) <- renderHooks) {
            child.attachRenderHooks(hooks)
        }
        children.add(child)
    }

    public func insertChild(index: Int64, child: Node): Bool {
        if (index < 0 || index > children.size) {
            return false
        }
        child.parent = Some(this)
        if (let Some(source) <- sourceBuffer) {
            child.attachSource(source)
        }
        if (let Some(hooks) <- renderHooks) {
            child.attachRenderHooks(hooks)
        }
        children.add(child, at: index)
        return true
    }

    public func replaceChild(oldChild: Node, newChild: Node): Bool {
        var index: Int64 = 0
        while (index < children.size) {
            if (refEq(children[index], oldChild)) {
                children[index] = newChild
                oldChild.parent = None
                newChild.parent = Some(this)
                if (let Some(source) <- sourceBuffer) {
                    newChild.attachSource(source)
                }
                if (let Some(hooks) <- renderHooks) {
                    newChild.attachRenderHooks(hooks)
                }
                return true
            }
            index += 1
        }
        return false
    }

    public func removeChild(child: Node): Bool {
        var index: Int64 = 0
        while (index < children.size) {
            if (refEq(children[index], child)) {
                children.remove(at: index)
                child.parent = None
                return true
            }
            index += 1
        }
        return false
    }

    public open prop name: String {
        get() {
            return kind + "Node"
        }
    }

    public operator func ==(right: Node): Bool {
        return name == right.name &&
            sourceSpan.startByte == right.sourceSpan.startByte &&
            sourceSpan.endByte == right.sourceSpan.endByte &&
            sourceSpan.startRune == right.sourceSpan.startRune &&
            sourceSpan.endRune == right.sourceSpan.endRune &&
            literal == right.literal &&
            level == right.level &&
            slug == right.slug &&
            info == right.info
    }

    public func attachSource(source: SourceBuffer): Unit {
        sourceBuffer = Some(source)
        for (child in children) {
            child.attachSource(source)
        }
    }

    public func attachRenderHooks(hooks: NodeRenderHooks): Unit {
        renderHooks = Some(hooks)
        for (child in children) {
            child.attachRenderHooks(hooks)
        }
    }

    public func setRawContent(rawContent: String): Unit {
        rawContentOverride = Some(rawContent)
    }

    protected func source(): ?SourceBuffer {
        return sourceBuffer
    }

    public func setString(key: String, value: String): Unit {
        stringMeta[key] = value
    }

    public func string(key: String): ?String {
        return stringMeta.get(key)
    }

    public func removeString(key: String): Unit {
        stringMeta.remove(key)
    }

    public func setInt(key: String, value: Int64): Unit {
        intMeta[key] = value
    }

    public func int(key: String): ?Int64 {
        return intMeta.get(key)
    }

    public func setBool(key: String, value: Bool): Unit {
        boolMeta[key] = value
    }

    public func bool(key: String): ?Bool {
        return boolMeta.get(key)
    }

    public open func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} (${rawContent()})")
        for (child in children) {
            let childStr = child.toString()
            for (line in childStr.split('\n')) {
                sb.append("\n  ")
                sb.append(line)
            }
        }
        return sb.toString()
    }

    public open func toJson(): String {
        let w = JsonWriter(initialCapacity: estimateJsonCapacity())
        writeJson(w)
        return w.close()
    }

    public open func toHtml(): String {
        if (let Some(hooks) <- resolvedRenderHooks()) {
            return hooks.toHtml(this)
        }
        return fallbackText()
    }

    public open func toMarkdown(): String {
        if (let Some(hooks) <- resolvedRenderHooks()) {
            return hooks.toMarkdown(this)
        }
        return fallbackText()
    }

    public open func toTypst(): String {
        if (let Some(hooks) <- resolvedRenderHooks()) {
            return hooks.toTypst(this)
        }
        return fallbackText()
    }

    public open func write(out: OutputStream): Unit {
        writeString(out, toString())
    }

    public open func writeHtml(out: OutputStream): Unit {
        if (let Some(hooks) <- resolvedRenderHooks()) {
            hooks.writeHtml(this, out)
            return
        }
        writeString(out, fallbackText())
    }

    public open func writeMarkdown(out: OutputStream): Unit {
        if (let Some(hooks) <- resolvedRenderHooks()) {
            hooks.writeMarkdown(this, out)
            return
        }
        writeString(out, fallbackText())
    }

    public open func writeTypst(out: OutputStream): Unit {
        if (let Some(hooks) <- resolvedRenderHooks()) {
            hooks.writeTypst(this, out)
            return
        }
        writeString(out, fallbackText())
    }

    public open func writeJson(out: OutputStream): Unit {
        let w = JsonWriter(initialCapacity: estimateJsonCapacity())
        writeJson(w)
        writeString(out, w.close())
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

    public open func writeJson(w: JsonWriter): JsonWriter {
        w.beginObject()
        writeObject(w)
        w.endObject()
        return w
    }

    protected open func writeObject(w: JsonWriter): JsonWriter {
        w.name("type").value(name)
        w.name("startOffset").value(startOffset())
        w.name("endOffset").value(endOffset())
        w.name("startByteOffset").value(sourceSpan.startByte)
        w.name("endByteOffset").value(sourceSpan.endByte)
        if (shouldWriteRawContent()) {
            w.name("rawContent").value(rawContent())
        }
        writeJsonFields(w)
        w.name("children").beginArray()
        for (child in children) {
            child.writeJson(w)
        }
        w.endArray()

        let keys = metaKeys()
        if (!keys.isEmpty()) {
            w.name("meta").beginObject()
            for (key in keys) {
                if (let Some(value) <- stringMeta.get(key)) {
                    w.name(key).value(value)
                    continue
                }
                if (let Some(value) <- intMeta.get(key)) {
                    w.name(key).value(value)
                    continue
                }
                if (let Some(value) <- boolMeta.get(key)) {
                    w.name(key).value(value)
                }
            }
            w.endObject()
        }
        return w
    }

    protected open func writeJsonFields(w: JsonWriter): JsonWriter {
        return w
    }

    public open func rawContent(): String {
        if (let Some(rawContent) <- rawContentOverride) {
            return rawContent
        }
        if (let Some(source) <- sourceBuffer) {
            if (source.hasRetainedSource()) {
                try {
                    return source.slice(sourceSpan.startByte, sourceSpan.endByte)
                } catch (e: Exception) {
                    if (kind == "Text" || kind == "SoftBreak") {
                        return literal
                    }
                    throw IllegalArgumentException(
                        "Invalid rawContent slice for ${kind} span bytes ${sourceSpan.startByte}..${sourceSpan.endByte}, runes ${sourceSpan.startRune}..${sourceSpan.endRune}: ${e.toString()}"
                    )
                }
            }
        }
        return literal
    }

    public func startOffset(): Int64 {
        return sourceSpan.startRune
    }

    public func endOffset(): Int64 {
        return sourceSpan.endRune
    }

    public open func stableHash(): Int64 {
        var h: Int64 = 17
        h = mixString(h, kind)
        h = mixString(h, literal)
        h = mixInt(h, level)
        h = mixString(h, slug)
        h = mixString(h, info)
        h = mixInt(h, sourceSpan.startByte)
        h = mixInt(h, sourceSpan.endByte)
        h = mixInt(h, sourceSpan.startRune)
        h = mixInt(h, sourceSpan.endRune)
        let keys = metaKeys()
        for (key in keys) {
            h = mixString(h, key)
            if (let Some(value) <- stringMeta.get(key)) {
                h = mixString(h, value)
                continue
            }
            if (let Some(value) <- intMeta.get(key)) {
                h = mixInt(h, value)
                continue
            }
            if (let Some(value) <- boolMeta.get(key)) {
                h = mixInt(h, if (value) { 1 } else { 0 })
            }
        }
        for (child in children) {
            h = mixInt(h, child.stableHash())
        }
        return h
    }

    private func metaKeys(): ArrayList<String> {
        let keys = ArrayList<String>()
        for ((key, _) in stringMeta) {
            keys.add(key)
        }
        for ((key, _) in intMeta) {
            if (!keys.contains(key)) {
                keys.add(key)
            }
        }
        for ((key, _) in boolMeta) {
            if (!keys.contains(key)) {
                keys.add(key)
            }
        }

        sortStrings(keys)
        return keys
    }

    private func sortStrings(values: ArrayList<String>): Unit {
        if (values.size < 2) {
            return
        }

        for (i in 0..values.size - 1) {
            for (j in i + 1..values.size) {
                if (values[j] < values[i]) {
                    let temp = values[i]
                    values[i] = values[j]
                    values[j] = temp
                }
            }
        }
    }

    private func resolvedRenderHooks(): ?NodeRenderHooks {
        if (let Some(hooks) <- renderHooks) {
            return Some(hooks)
        }
        if (let Some(parentNode) <- parent) {
            return parentNode.resolvedRenderHooks()
        }
        return None
    }

    private func shouldWriteRawContent(): Bool {
        if (let Some(source) <- sourceBuffer) {
            return source.retainsFullSource()
        }
        return false
    }

    private func estimateJsonCapacity(): Int64 {
        return 128 + literal.size + children.size * 64
    }

    private func mixString(hash: Int64, value: String): Int64 {
        var h = hash
        for (b in value) {
            h = mixInt(h, Int64(b))
        }
        return h
    }

    private func mixInt(hash: Int64, value: Int64): Int64 {
        let mod: Int64 = 1000000007
        var v = value % mod
        if (v < 0) {
            v = -v
        }
        return ((hash % mod) * 131 + v) % mod
    }

    private func fallbackText(): String {
        if (!children.isEmpty()) {
            let sb = StringBuilder()
            for (child in children) {
                sb.append(child.fallbackText())
            }
            return sb.toString()
        }
        return literal
    }

    private func writeString(out: OutputStream, value: String): Unit {
        if (!value.isEmpty()) {
            out.write(value.toArray())
        }
        out.flush()
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
