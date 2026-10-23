package markit.core.nodes

import markit.core.editing.SyntaxNodePayload
import markit.core.source.SourceSpan
import std.collection.ArrayList

// Logical Text remains one typed legacy node. These bounded segments are an
// internal editing/render-unit surface, not observable AST children.
public class PersistentTextSegment {
    public let text: String
    public PersistentTextSegment(text: String) {
        if (text.isEmpty() || text.size > 1024) { throw IllegalArgumentException("Invalid text segment size") }
        this.text = text.clone()
    }
}

private class TextBranch {
    public let bytes: Int64
    public let height: Int64
    public let segment: ?PersistentTextSegment
    public let left: ?TextBranch
    public let right: ?TextBranch
    public TextBranch(segment: PersistentTextSegment) {
        this.segment = Some(segment); this.left = None; this.right = None
        this.bytes = segment.text.size; this.height = 1
    }
    public init(left: TextBranch, right: TextBranch) {
        this.segment = None; this.left = Some(left); this.right = Some(right)
        this.bytes = left.bytes + right.bytes
        this.height = 1 + if (left.height > right.height) { left.height } else { right.height }
    }
}

private func textHeight(branch: ?TextBranch): Int64 {
    if (let Some(node) <- branch) { return node.height }; return 0
}

private func textJoin(left: ?TextBranch, right: ?TextBranch): ?TextBranch {
    if (left.isNone()) { return right }; if (right.isNone()) { return left }
    let l = left.getOrThrow(); let r = right.getOrThrow()
    if (l.height > r.height + 1) {
        return Some(textBalance(l.left.getOrThrow(), textJoin(l.right, right).getOrThrow()))
    }
    if (r.height > l.height + 1) {
        return Some(textBalance(textJoin(left, r.left).getOrThrow(), r.right.getOrThrow()))
    }
    return Some(TextBranch(l, r))
}

private func textBalance(left: TextBranch, right: TextBranch): TextBranch {
    if (left.height > right.height + 1) {
        let ll = left.left.getOrThrow(); let lr = left.right.getOrThrow()
        if (ll.height >= lr.height) { return TextBranch(ll, TextBranch(lr, right)) }
        return TextBranch(TextBranch(ll, lr.left.getOrThrow()), TextBranch(lr.right.getOrThrow(), right))
    }
    if (right.height > left.height + 1) {
        let rl = right.left.getOrThrow(); let rr = right.right.getOrThrow()
        if (rr.height >= rl.height) { return TextBranch(TextBranch(left, rl), rr) }
        return TextBranch(TextBranch(left, rl.left.getOrThrow()), TextBranch(rl.right.getOrThrow(), rr))
    }
    return TextBranch(left, right)
}

private func textSplit(branch: ?TextBranch, at: Int64): (?TextBranch, ?TextBranch) {
    if (branch.isNone()) {
        if (at != 0) { throw IllegalArgumentException("Text split out of range") }
        return (None, None)
    }
    let node = branch.getOrThrow()
    if (at < 0 || at > node.bytes) { throw IllegalArgumentException("Text split out of range") }
    if (at == 0) { return (None, branch) }; if (at == node.bytes) { return (branch, None) }
    if (let Some(segment) <- node.segment) {
        // String slicing rejects UTF-8 continuation-byte cuts. Only this
        // bounded leaf is copied, never the complete logical literal.
        return (Some(TextBranch(PersistentTextSegment(segment.text[0..at]))),
            Some(TextBranch(PersistentTextSegment(segment.text[at..segment.text.size]))))
    }
    let l = node.left.getOrThrow()
    if (at < l.bytes) {
        let (before, after) = textSplit(node.left, at)
        return (before, textJoin(after, node.right))
    }
    let (before, after) = textSplit(node.right, at - l.bytes)
    return (textJoin(node.left, before), after)
}

private func textBuild(text: String): ?TextBranch {
    let chunks = ArrayList<TextBranch>()
    var start: Int64 = 0
    while (start < text.size) {
        var end = if (text.size - start > 1024) { start + 1024 } else { text.size }
        while (end < text.size && (text[end] & 0xC0) == 0x80) { end -= 1 }
        chunks.add(TextBranch(PersistentTextSegment(text[start..end])))
        start = end
    }
    return textBuildRange(chunks, 0, chunks.size)
}

private func textBuildRange(chunks: ArrayList<TextBranch>, start: Int64, end: Int64): ?TextBranch {
    if (start == end) { return None }; if (end - start == 1) { return Some(chunks[start]) }
    let middle = start + (end - start) / 2
    return Some(TextBranch(textBuildRange(chunks, start, middle).getOrThrow(),
        textBuildRange(chunks, middle, end).getOrThrow()))
}

private func textCollect(branch: ?TextBranch, start: Int64, end: Int64,
    output: ArrayList<PersistentTextSegment>): Unit {
    if (branch.isNone() || start == end) { return }
    let node = branch.getOrThrow()
    if (let Some(segment) <- node.segment) {
        if (start == 0 && end == node.bytes) { output.add(segment) }
        else { output.add(PersistentTextSegment(segment.text[start..end])) }
        return
    }
    let leftBytes = node.left.getOrThrow().bytes
    if (start < leftBytes) { textCollect(node.left, start, if (end < leftBytes) { end } else { leftBytes }, output) }
    if (end > leftBytes) { textCollect(node.right, if (start > leftBytes) { start - leftBytes } else { 0 }, end - leftBytes, output) }
}

public class PersistentTextPayload <: SyntaxNodePayload {
    private let tree: ?TextBranch
    private let baseState: ?Node
    private let rawTree: ?TextBranch
    private let rawFollowsText: Bool
    public prop codecId: String { get() { return "logical-text" } }
    public prop rawSpellingFollowsText: Bool { get() { return rawFollowsText } }
    public prop byteLength: Int64 { get() { if (let Some(node) <- tree) { return node.bytes }; return 0 } }
    public PersistentTextPayload(text: String) {
        this.tree = textBuild(text); this.baseState = None; this.rawTree = None; this.rawFollowsText = true
    }
    private init(tree: ?TextBranch, baseState: ?Node, rawTree: ?TextBranch, rawFollowsText: Bool) {
        this.tree = tree; this.baseState = baseState; this.rawTree = rawTree; this.rawFollowsText = rawFollowsText
    }
    public static func fromNode(node: TextNode): PersistentTextPayload {
        if (node.literal != node.content) { throw IllegalArgumentException("Text literal/content require typed codec preservation") }
        let base = Node("Text", id: node.id)
        node.copyBaseTo(base)
        base.literal = ""; base.setRawContent("")
        let raw = node.rawContent()
        let same = raw == node.content
        return PersistentTextPayload(textBuild(node.content), Some(base), if (same) { None } else { textBuild(raw) }, same)
    }
    public static func withRawSpelling(text: String, raw: String): PersistentTextPayload {
        let same = text == raw
        return PersistentTextPayload(textBuild(text), None, if (same) { None } else { textBuild(raw) }, same)
    }
    public func originalSpan(): ?SourceSpan {
        if (let Some(base) <- baseState) { return Some(base.sourceSpan) }; return None
    }
    public func clonePayload(): SyntaxNodePayload { return PersistentTextPayload(tree, baseState, rawTree, rawFollowsText) }
    public func sliced(start: Int64, end: Int64): PersistentTextPayload {
        if (start < 0 || end < start || end > byteLength) { throw IllegalArgumentException("Invalid text slice") }
        if (start == 0 && end == byteLength) { return PersistentTextPayload(tree, baseState, rawTree, rawFollowsText) }
        if (!rawFollowsText) { throw IllegalArgumentException("Raw spelling requires provider-proven slice coordinates") }
        let (_, rest) = textSplit(tree, start)
        let (middle, _) = textSplit(rest, end - start)
        return PersistentTextPayload(middle, baseState, None, true)
    }
    public func concatenated(other: PersistentTextPayload): PersistentTextPayload {
        if (!rawFollowsText || !other.rawFollowsText) { throw IllegalArgumentException("Raw spelling requires provider-proven concatenation") }
        return concatenatedSpelling(other)
    }
    // The caller proves that the two adjacent decoded literal units may merge.
    // Raw and decoded sequences retain their independent coordinate spaces.
    public func concatenatedSpelling(other: PersistentTextPayload): PersistentTextPayload {
        if (baseState.isSome() != other.baseState.isSome() ||
            (baseState.isSome() && !refEq(baseState.getOrThrow(), other.baseState.getOrThrow()))) {
            throw IllegalArgumentException("Different text metadata requires provider-proven concatenation")
        }
        let follows = rawFollowsText && other.rawFollowsText
        let raw: ?TextBranch = if (follows) { None } else {
            textJoin(if (rawFollowsText) { tree } else { rawTree },
                if (other.rawFollowsText) { other.tree } else { other.rawTree })
        }
        return PersistentTextPayload(textJoin(tree, other.tree), baseState, raw, follows)
    }
    public func splice(start: Int64, end: Int64, inserted: String): PersistentTextPayload {
        if (start < 0 || end < start || end > byteLength) { throw IllegalArgumentException("Invalid text splice") }
        if (!rawFollowsText) { throw IllegalArgumentException("Raw spelling requires provider-proven splice coordinates") }
        let (before, rest) = textSplit(tree, start)
        let (_, after) = textSplit(rest, end - start)
        return PersistentTextPayload(textJoin(textJoin(before, textBuild(inserted)), after), baseState, rawTree, rawFollowsText)
    }
    public func segments(start: Int64, end: Int64): Array<PersistentTextSegment> {
        if (start < 0 || end < start || end > byteLength) { throw IllegalArgumentException("Invalid text segment range") }
        let output = ArrayList<PersistentTextSegment>()
        textCollect(tree, start, end, output)
        return output.toArray()
    }
    // Explicit O(N) legacy boundary, never called by splice/transaction commit.
    public func materialize(): String {
        let output = StringBuilder()
        for (segment in segments(0, byteLength)) { output.append(segment.text) }
        return output.toString()
    }
    public func materializeNode(id: Int64, span: SourceSpan): TextNode {
        let content = materialize()
        let result = TextNode(id, span, content)
        if (let Some(base) <- baseState) { base.copyBaseTo(result) }
        result.literal = content; result.sourceSpan = span
        if (rawFollowsText) { result.setRawContent(content) }
        else {
            let output = StringBuilder()
            let segments = ArrayList<PersistentTextSegment>()
            if (let Some(raw) <- rawTree) { textCollect(rawTree, 0, raw.bytes, segments) }
            for (segment in segments) { output.append(segment.text) }
            result.setRawContent(output.toString())
        }
        return result
    }
}
