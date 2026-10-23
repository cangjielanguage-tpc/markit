package markit.core.source

import std.collection.ArrayList

// Immutable AVL rope. Only bounded leaves decode bytes; branches cache metrics.
internal class RopeNode {
    let text: String
    let left: ?RopeNode
    let right: ?RopeNode
    let height: Int64
    let bytes: Int64
    let runes: Int64
    let utf16: Int64
    let breaks: Int64
    let startsLF: Bool
    let endsCR: Bool
    let tail16: Int64

    RopeNode(text: String) {
        this.text = text.clone()
        left = None; right = None; height = 1
        bytes = text.size
        var r: Int64 = 0; var u: Int64 = 0; var b: Int64 = 0; var tail: Int64 = 0
        var p: Int64 = 0; var cr = false
        while (p < text.size) {
            let c = text[p]; let w = ropeWidth(c); let units: Int64 = if (w == 4) { 2 } else { 1 }
            r += 1; u += units
            if (c == 13) { b += 1; tail = 0 }
            else if (c == 10) { if (!cr) { b += 1 }; tail = 0 }
            else { tail += units }
            cr = c == 13; p += w
        }
        runes = r; utf16 = u; breaks = b; tail16 = tail
        startsLF = bytes > 0 && text[0] == 10
        endsCR = bytes > 0 && text[bytes - 1] == 13
    }

    init(a: RopeNode, b: RopeNode) {
        text = ""; left = Some(a); right = Some(b)
        height = 1 + if (a.height > b.height) { a.height } else { b.height }
        bytes = a.bytes + b.bytes; runes = a.runes + b.runes; utf16 = a.utf16 + b.utf16
        breaks = a.breaks + b.breaks - if (a.endsCR && b.startsLF) { 1 } else { 0 }
        startsLF = a.startsLF; endsCR = b.endsCR
        tail16 = if (b.breaks > 0) { b.tail16 } else { a.tail16 + b.utf16 }
    }
}

internal func ropeWidth(b: Byte): Int64 {
    if (b < 128) { return 1 }
    if (b < 224) { return 2 }
    if (b < 240) { return 3 }
    return 4
}

internal func ropeBranch(a: RopeNode, b: RopeNode): RopeNode {
    if (a.bytes == 0) { return b }; if (b.bytes == 0) { return a }
    return RopeNode(a, b)
}

internal func ropeBalance(a: RopeNode, b: RopeNode): RopeNode {
    if (a.height > b.height + 1) {
        let al = a.left.getOrThrow(); let ar = a.right.getOrThrow()
        if (al.height >= ar.height) { return ropeBranch(al, ropeBranch(ar, b)) }
        return ropeBranch(ropeBranch(al, ar.left.getOrThrow()), ropeBranch(ar.right.getOrThrow(), b))
    }
    if (b.height > a.height + 1) {
        let bl = b.left.getOrThrow(); let br = b.right.getOrThrow()
        if (br.height >= bl.height) { return ropeBranch(ropeBranch(a, bl), br) }
        return ropeBranch(ropeBranch(a, bl.left.getOrThrow()), ropeBranch(bl.right.getOrThrow(), br))
    }
    return ropeBranch(a, b)
}

internal func ropeJoin(a: RopeNode, b: RopeNode): RopeNode {
    if (a.bytes == 0) { return b }; if (b.bytes == 0) { return a }
    if (a.height > b.height + 1) { return ropeBalance(a.left.getOrThrow(), ropeJoin(a.right.getOrThrow(), b)) }
    if (b.height > a.height + 1) { return ropeBalance(ropeJoin(a, b.left.getOrThrow()), b.right.getOrThrow()) }
    return ropeBranch(a, b)
}

internal func ropeFromText(text: String): RopeNode {
    var root = RopeNode(""); var start: Int64 = 0
    while (start < text.size) {
        var end = start + 1024
        if (end > text.size) { end = text.size }
        while (end < text.size && text[end] >= 128 && text[end] < 192) { end -= 1 }
        root = ropeJoin(root, RopeNode(text[start..end])); start = end
    }
    return root
}

internal func ropeByte(root: RopeNode, offset: Int64): Byte {
    if (let Some(a) <- root.left) {
        if (offset < a.bytes) { return ropeByte(a, offset) }
        return ropeByte(root.right.getOrThrow(), offset - a.bytes)
    }
    return root.text[offset]
}

internal func ropeBoundary(root: RopeNode, offset: Int64): Bool {
    return offset >= 0 && offset <= root.bytes &&
        (offset == root.bytes || ropeByte(root, offset) < 128 || ropeByte(root, offset) >= 192)
}

internal func ropeSplit(root: RopeNode, offset: Int64): (RopeNode, RopeNode) {
    if (offset == 0) { return (RopeNode(""), root) }
    if (offset == root.bytes) { return (root, RopeNode("")) }
    if (let Some(a) <- root.left) {
        let b = root.right.getOrThrow()
        if (offset < a.bytes) { let (x, y) = ropeSplit(a, offset); return (x, ropeJoin(y, b)) }
        let (x, y) = ropeSplit(b, offset - a.bytes); return (ropeJoin(a, x), y)
    }
    return (RopeNode(root.text[0..offset]), RopeNode(root.text[offset..root.bytes]))
}

internal func ropeSlice(root: RopeNode, start: Int64, end: Int64, output: StringBuilder): Unit {
    if (start == end) { return }
    if (let Some(a) <- root.left) {
        if (start < a.bytes) { ropeSlice(a, start, if (end < a.bytes) { end } else { a.bytes }, output) }
        if (end > a.bytes) { ropeSlice(root.right.getOrThrow(), if (start > a.bytes) { start - a.bytes } else { 0 }, end - a.bytes, output) }
    } else { output.append(root.text[start..end]) }
}

// Prefix summaries reuse complete subtree aggregates and scan at most one leaf.
internal func ropePrefix(root: RopeNode, offset: Int64): RopeNode {
    if (offset == root.bytes) { return root }
    if (offset == 0) { return RopeNode("") }
    if (let Some(a) <- root.left) {
        if (offset <= a.bytes) { return ropePrefix(a, offset) }
        return ropeBranch(a, ropePrefix(root.right.getOrThrow(), offset - a.bytes))
    }
    return RopeNode(root.text[0..offset])
}

internal func ropeOffset(root: RopeNode, offset: Int64, utf16: Bool): ?Int64 {
    let total = if (utf16) { root.utf16 } else { root.runes }
    if (offset < 0 || offset > total) { return None }
    if (offset == total) { return Some(root.bytes) }
    if (let Some(a) <- root.left) {
        let count = if (utf16) { a.utf16 } else { a.runes }
        if (offset <= count) { return ropeOffset(a, offset, utf16) }
        if (let Some(p) <- ropeOffset(root.right.getOrThrow(), offset - count, utf16)) { return Some(a.bytes + p) }
        return None
    }
    var p: Int64 = 0; var units: Int64 = 0
    while (p < root.bytes) {
        if (units == offset) { return Some(p) }
        let w = ropeWidth(root.text[p]); units += if (utf16 && w == 4) { 2 } else { 1 }; p += w
        if (units > offset) { return None }
    }
    return Some(p)
}

// n is one based. A CRLF crossing a branch contributes one break ending after LF.
internal func ropeBreakEnd(root: RopeNode, n: Int64): Int64 {
    if (let Some(a) <- root.left) {
        let b = root.right.getOrThrow(); let pair = a.endsCR && b.startsLF
        if (n <= a.breaks) {
            if (pair && n == a.breaks) { return a.bytes + 1 }
            return ropeBreakEnd(a, n)
        }
        return a.bytes + ropeBreakEnd(b, n - a.breaks + if (pair) { 1 } else { 0 })
    }
    var p: Int64 = 0; var count: Int64 = 0
    while (p < root.bytes) {
        let c = root.text[p]; p += ropeWidth(c)
        if (c == 13) { if (p < root.bytes && root.text[p] == 10) { p += 1 }; count += 1 }
        else if (c == 10) { count += 1 }
        if (count == n) { return p }
    }
    return p
}
