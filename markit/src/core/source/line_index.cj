package markit.core.source

import std.collection.ArrayList
import markit.core.editing.EditableSourceVersion

private func sourceViewLineCount(source: EditableSourceVersion): Int64 {
    if (source.byteLength == 0) { return 0 }
    let count = source.lineCount
    // The rope's final editor position is not an emitted parser line when a
    // line ending already consumed the final byte (including CRLF).
    let ending = source.coordinateAtByte(source.byteLength).getOrThrow()
    return count - if (ending.utf16Column == 0) { 1 } else { 0 }
}

// Immutable append sequence: checkpoint keeps one root and append copies only
// the AVL right spine. SourceLine and SourceSpan themselves are immutable.
internal class IndexedLineNode {
    let line: ?SourceLine
    let left: ?IndexedLineNode
    let right: ?IndexedLineNode
    let size: Int64
    let height: Int64

    IndexedLineNode(line: SourceLine) {
        this.line = Some(line); left = None; right = None; size = 1; height = 1
    }

    init(left: IndexedLineNode, right: IndexedLineNode) {
        line = None; this.left = Some(left); this.right = Some(right)
        size = left.size + right.size
        height = 1 + if (left.height > right.height) { left.height } else { right.height }
    }
}

public class LineIndexSnapshot {
    internal let root: ?IndexedLineNode
    internal let flat: ?ArrayList<SourceLine>
    internal let capturedSize: Int64
    public prop size: Int64 {
        get() { return if (let Some(source) <- sourceView) { sourceViewLineCount(source) } else { capturedSize } }
    }
    internal LineIndexSnapshot(root: ?IndexedLineNode, flat: ?ArrayList<SourceLine>, size: Int64,
        internal let sourceView: ?EditableSourceVersion) {
        this.root = root; this.flat = flat; this.capturedSize = size
    }
}

public class LineIndex {
    private var root: ?IndexedLineNode = None
    private var flat: ?ArrayList<SourceLine> = Some(ArrayList<SourceLine>())
    private var flatSize: Int64 = 0
    private var sourceView: ?EditableSourceVersion = None
    public prop isEditableView: Bool { get() { return sourceView.isSome() } }

    public prop size: Int64 {
        get() {
            return if (let Some(source) <- sourceView) { sourceViewLineCount(source) }
                else if (flat.isSome()) { flatSize } else if (let Some(node) <- root) { node.size } else { 0 }
        }
    }

    // Default batch append keeps its original ArrayList cost. Flat snapshots
    // retain a prefix length; only an actual historical branch needs a copy.
    public func snapshot(): LineIndexSnapshot {
        let recorded = if (flat.isSome()) { flatSize } else if (let Some(node) <- root) { node.size } else { 0 }
        return LineIndexSnapshot(root, flat, recorded, sourceView)
    }
    public func restore(snapshot: LineIndexSnapshot): Unit {
        root = snapshot.root; flat = snapshot.flat; flatSize = snapshot.capturedSize; sourceView = snapshot.sourceView
    }

    // The immutable source already owns its line/rune index. Rebinding after
    // recovery never scans or copies a stale checkpoint's recorded prefix.
    public func bindEditableSource(version: EditableSourceVersion): Unit {
        if (let Some(previous) <- sourceView) {
            if (previous.identity.documentId != version.identity.documentId) {
                throw IllegalArgumentException("Cross-document line source view")
            }
        }
        sourceView = Some(version)
        root = None; flat = None; flatSize = 0
    }

    // Editing sessions opt in while the index is empty. Explicit promotion of
    // an existing flat index is O(N) once; all following checkpoints are O(1).
    public func enablePersistent(): Unit {
        if (sourceView.isSome()) { return }
        if (let Some(lines) <- flat) {
            root = build(lines, 0, flatSize)
            flat = None
        }
    }

    public func add(line: SourceLine): Unit {
        if (sourceView.isSome()) { throw IllegalArgumentException("Editable line source view cannot append") }
        if (let Some(lines) <- flat) {
            if (flatSize == lines.size) { lines.add(line) }
            else {
                let branch = ArrayList<SourceLine>()
                for (i in 0..flatSize) { branch.add(lines[i]) }
                branch.add(line)
                flat = Some(branch)
            }
            flatSize += 1
            return
        }
        let leaf = IndexedLineNode(line)
        root = Some(if (let Some(node) <- root) { append(node, leaf) } else { leaf })
    }

    public func lineAt(index: Int64): SourceLine {
        if (index < 0 || index >= size) { throw IllegalArgumentException("Line index out of bounds") }
        if (let Some(source) <- sourceView) {
            let line = source.lineAt(index).getOrThrow()
            let endByte = line.startByte + line.content.size
            let startRune = source.coordinateAtByte(line.startByte).getOrThrow().runeOffset
            let endRune = source.coordinateAtByte(endByte).getOrThrow().runeOffset
            return SourceLine(line.content, SourceSpan(line.startByte, endByte, startRune, endRune),
                terminated: !line.lineEnding.isEmpty())
        }
        if (let Some(lines) <- flat) { return lines[index] }
        var node = root.getOrThrow()
        var offset = index
        while (node.line.isNone()) {
            let left = node.left.getOrThrow()
            if (offset < left.size) { node = left } else { offset -= left.size; node = node.right.getOrThrow() }
        }
        return node.line.getOrThrow()
    }

    // Explicit legacy export retains its output-sized cost.
    public func lines(): ArrayList<SourceLine> {
        let output = ArrayList<SourceLine>()
        if (sourceView.isSome()) {
            for (index in 0..size) { output.add(lineAt(index)) }
            return output
        }
        if (let Some(lines) <- flat) {
            for (i in 0..flatSize) { output.add(lines[i]) }
            return output
        }
        if (let Some(node) <- root) { collect(node, output) }
        return output
    }

    public func findByByteOffset(byteOffset: Int64): ?SourceLine {
        if (let Some(source) <- sourceView) {
            if (byteOffset < 0 || byteOffset > source.byteLength) { return None }
            var at = byteOffset
            var coordinate = source.coordinateAtByte(at)
            // Preserve lookup for raw continuation bytes inside a text scalar.
            while (coordinate.isNone() && at > 0 && byteOffset - at < 3) {
                at -= 1; coordinate = source.coordinateAtByte(at)
            }
            if (let Some(position) <- coordinate) {
                if (position.line < 0 || position.line >= size) { return None }
                let line = lineAt(position.line)
                if (byteOffset >= line.span.startByte && byteOffset <= line.span.endByte) { return Some(line) }
            }
            return None
        }
        if (let Some(lines) <- flat) {
            for (i in 0..flatSize) {
                let line = lines[i]
                if (byteOffset >= line.span.startByte && byteOffset <= line.span.endByte) { return Some(line) }
            }
            return None
        }
        return if (let Some(node) <- root) { find(node, byteOffset) } else { None }
    }

    private func build(lines: ArrayList<SourceLine>, start: Int64, end: Int64): ?IndexedLineNode {
        if (start == end) { return None }
        if (end - start == 1) { return Some(IndexedLineNode(lines[start])) }
        let middle = start + (end - start) / 2
        return Some(IndexedLineNode(build(lines, start, middle).getOrThrow(), build(lines, middle, end).getOrThrow()))
    }

    private func append(node: IndexedLineNode, leaf: IndexedLineNode): IndexedLineNode {
        if (node.line.isSome()) { return IndexedLineNode(node, leaf) }
        return balance(node.left.getOrThrow(), append(node.right.getOrThrow(), leaf))
    }

    private func balance(left: IndexedLineNode, right: IndexedLineNode): IndexedLineNode {
        if (right.height > left.height + 1) {
            let inner = right.left.getOrThrow()
            let outer = right.right.getOrThrow()
            if (inner.height > outer.height) {
                return IndexedLineNode(IndexedLineNode(left, inner.left.getOrThrow()),
                    IndexedLineNode(inner.right.getOrThrow(), outer))
            }
            return IndexedLineNode(IndexedLineNode(left, inner), outer)
        }
        return IndexedLineNode(left, right)
    }

    private func collect(node: IndexedLineNode, output: ArrayList<SourceLine>): Unit {
        if (let Some(line) <- node.line) { output.add(line); return }
        collect(node.left.getOrThrow(), output)
        collect(node.right.getOrThrow(), output)
    }

    private func find(node: IndexedLineNode, byteOffset: Int64): ?SourceLine {
        if (let Some(line) <- node.line) {
            return if (byteOffset >= line.span.startByte && byteOffset <= line.span.endByte) { Some(line) } else { None }
        }
        // Preserve first-match semantics for shared endpoints/synthetic spans.
        if (let Some(line) <- find(node.left.getOrThrow(), byteOffset)) { return Some(line) }
        return find(node.right.getOrThrow(), byteOffset)
    }
}
