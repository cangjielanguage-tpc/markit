package markit.core.inline

import std.collection.ArrayList

private func nestedKeyHigh(key: String, bit: Int64): Bool {
    var divisor: Int64 = 1
    for (_ in 0..bit % 8) { divisor *= 2 }
    return Int64(key[bit / 8]) / divisor % 2 != 0
}

// Persistent UTF-8 bit trie: one key path and one owner-ID path per changed
// read. A key wake-up enumerates only its actual recursive owners.
internal class InlineNestedReadKeys {
    public InlineNestedReadKeys(public let key: String, public let owners: ?InlineLiteralOrigins,
        public let zero: ?InlineNestedReadKeys, public let one: ?InlineNestedReadKeys) {}
    public static func get(root: ?InlineNestedReadKeys, key: String, bit!: Int64 = 0): ?InlineLiteralOrigins {
        if (root.isNone()) { return None }; let node = root.getOrThrow()
        if (bit == key.size * 8) { return node.owners }
        let high = nestedKeyHigh(key, bit)
        return get(if (high) { node.one } else { node.zero }, key, bit: bit + 1)
    }
    public static func changed(root: ?InlineNestedReadKeys, key: String, owner: Int64, present: Bool,
        bit!: Int64 = 0): ?InlineNestedReadKeys {
        var owners = root.flatMap({ node => node.owners })
        var zero = root.flatMap({ node => node.zero }); var one = root.flatMap({ node => node.one })
        if (bit == key.size * 8) { owners = InlineLiteralOrigins.changed(owners, owner, present) }
        else if (nestedKeyHigh(key, bit)) { one = changed(one, key, owner, present, bit: bit + 1) }
        else { zero = changed(zero, key, owner, present, bit: bit + 1) }
        if (owners.isNone() && zero.isNone() && one.isNone()) { return None }
        let storedKey = if (bit == key.size * 8) { key } else { root.map({ node => node.key }) ?? "" }
        return Some(InlineNestedReadKeys(storedKey, owners, zero, one))
    }
    public static func keys(root: ?InlineNestedReadKeys, output: ArrayList<String>): Unit {
        if (let Some(node) <- root) {
            if (node.owners.isSome()) { output.add(node.key) }
            keys(node.zero, output); keys(node.one, output)
        }
    }
    public static func ownerIds(root: ?InlineLiteralOrigins, output: ArrayList<Int64>, value!: UInt64 = 0,
        weight!: UInt64 = 1): Unit {
        if (let Some(node) <- root) {
            if (node.marked) { output.add(Int64(value)) }
            if (node.even.isSome()) { ownerIds(node.even, output, value: value, weight: weight * 2) }
            if (node.odd.isSome()) { ownerIds(node.odd, output, value: value + weight, weight: weight * 2) }
        }
    }
}
