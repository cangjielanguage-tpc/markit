package markit.core.inline

import markit.core.editing.{IncrementalReadDependency, SourceVersionIdentity}
import std.collection.ArrayList

// owner identifies one private parser attempt, independently of syntax Node IDs.
// Coordinates returned by an index belong to index.source; source is the birth
// version of the evidence. Shifting geometry never invents new parser evidence.
public class InlineAttemptRecord {
    public let owner: Int64
    public let parserIdentity: Int64
    public let parserOwner: String
    public let grammarVersion: String
    public let mappingIdentity: String
    public let source: SourceVersionIdentity
    public let startByte: Int64
    public let endByte: Int64
    public let readStart: Int64
    public let readEnd: Int64
    public let succeeded: Bool
    public let leftContext: String
    public let rightContext: String
    public let nestedOwner: Int64
    private let capturedDependencies: Array<IncrementalReadDependency>
    public prop dependencies: Array<IncrementalReadDependency> { get() { return capturedDependencies.clone() } }
    internal prop dependencyCount: Int64 { get() { return capturedDependencies.size } }
    internal func dependencyAt(index: Int64): IncrementalReadDependency { return capturedDependencies[index] }

    public InlineAttemptRecord(owner: Int64, parserIdentity: Int64, parserOwner: String,
        grammarVersion: String, mappingIdentity: String, source: SourceVersionIdentity,
        startByte: Int64, endByte: Int64, readStart: Int64, readEnd: Int64,
        succeeded: Bool, leftContext!: String = "", rightContext!: String = "",
        nestedOwner!: Int64 = -1, dependencies!: Array<IncrementalReadDependency> = [], public let nodeId!: Int64 = -1,
        public let dependsOnLength!: Bool = false) {
        if (owner < 0 || parserIdentity < 0 || parserOwner.isEmpty() || grammarVersion.isEmpty() ||
            mappingIdentity.isEmpty() || startByte < 0 || endByte < startByte ||
            readStart < 0 || readStart > startByte || readEnd < endByte || nestedOwner < -1 || nodeId < -1) {
            throw IllegalArgumentException("Invalid inline attempt evidence")
        }
        this.owner = owner; this.parserIdentity = parserIdentity; this.parserOwner = parserOwner
        this.grammarVersion = grammarVersion; this.mappingIdentity = mappingIdentity; this.source = source
        this.startByte = startByte; this.endByte = endByte; this.readStart = readStart; this.readEnd = readEnd
        this.succeeded = succeeded; this.leftContext = leftContext; this.rightContext = rightContext
        this.nestedOwner = nestedOwner; capturedDependencies = dependencies.clone()
    }

    private init(original: InlineAttemptRecord, delta: Int64) {
        owner = original.owner; parserIdentity = original.parserIdentity; parserOwner = original.parserOwner
        grammarVersion = original.grammarVersion; mappingIdentity = original.mappingIdentity; source = original.source
        startByte = original.startByte + delta; endByte = original.endByte + delta
        readStart = original.readStart + delta; readEnd = original.readEnd + delta
        succeeded = original.succeeded; leftContext = original.leftContext; rightContext = original.rightContext
        nestedOwner = original.nestedOwner; nodeId = original.nodeId; dependsOnLength = original.dependsOnLength
        capturedDependencies = original.capturedDependencies
    }

    internal func shifted(delta: Int64): InlineAttemptRecord {
        return if (delta == 0) { this } else { InlineAttemptRecord(this, delta) }
    }
}

// Stable fractional keys locate attempts through both persistent indexes. They
// are independent of byte coordinates, so a suffix shift updates no locators.
// Missing digits mean zero; stored keys never have a trailing zero digit.
internal class InlineAttemptOrder {
    internal InlineAttemptOrder(private let digits: Array<Int64>) {}
    internal prop size: Int64 { get() { return digits.size } }
    internal func digit(index: Int64): Int64 { return if (index < digits.size) { digits[index] } else { 0 } }
}

private func iaiOrderCompare(left: InlineAttemptOrder, right: InlineAttemptOrder): Int64 {
    if (refEq(left, right)) { return 0 }
    let size = if (left.size > right.size) { left.size } else { right.size }
    for (i in 0..size) {
        if (left.digit(i) < right.digit(i)) { return -1 }
        if (left.digit(i) > right.digit(i)) { return 1 }
    }
    return 0
}

private func iaiBetween(left: ?InlineAttemptOrder, right: ?InlineAttemptOrder): InlineAttemptOrder {
    let base: Int64 = 1152921504606846976
    // Open boundaries have integer space: do not halve that same space on
    // every sequential append/prepend and grow keys with initial record count.
    if (right.isNone()) {
        if (let Some(key) <- left) {
            if (key.digit(key.size - 1) < base - 1) {
                let appended = ArrayList<Int64>()
                for (i in 0..key.size - 1) { appended.add(key.digit(i)) }
                appended.add(key.digit(key.size - 1) + 1)
                return InlineAttemptOrder(appended.toArray())
            }
        }
    } else if (left.isNone() && right.getOrThrow().digit(0) > 1) {
        return InlineAttemptOrder([right.getOrThrow().digit(0) - 1])
    }
    let digits = ArrayList<Int64>()
    var upperOpen = right.isNone()
    var position: Int64 = 0
    while (true) {
        let low = if (let Some(key) <- left) { key.digit(position) } else { 0 }
        let high = if (upperOpen) { base } else { right.getOrThrow().digit(position) }
        if (high - low > 1) {
            digits.add(low + (high - low) / 2)
            return InlineAttemptOrder(digits.toArray())
        }
        digits.add(low)
        if (high > low) { upperOpen = true }
        position += 1
    }
    throw IllegalArgumentException("Unreachable inline fractional-key search")
}

internal class InlineAttemptBranch {
    let height: Int64
    let size: Int64
    let minimumRead: Int64
    let maximumRead: Int64
    let minimumStart: Int64
    let maximumStart: Int64

    InlineAttemptBranch(let order: InlineAttemptOrder, let record: InlineAttemptRecord,
        let left: ?InlineAttemptBranch, let right: ?InlineAttemptBranch, let lazyDelta!: Int64 = 0) {
        let lh = iaiHeight(left); let rh = iaiHeight(right)
        height = 1 + if (lh > rh) { lh } else { rh }
        size = 1 + iaiSize(left) + iaiSize(right)
        var lowRead = record.readStart; var highRead = record.readEnd
        var lowStart = record.startByte; var highStart = record.startByte
        if (let Some(child) <- left) {
            if (child.minimumRead < lowRead) { lowRead = child.minimumRead }
            if (child.maximumRead > highRead) { highRead = child.maximumRead }
            lowStart = child.minimumStart
        }
        if (let Some(child) <- right) {
            if (child.minimumRead < lowRead) { lowRead = child.minimumRead }
            if (child.maximumRead > highRead) { highRead = child.maximumRead }
            highStart = child.maximumStart
        }
        minimumRead = lowRead + lazyDelta; maximumRead = highRead + lazyDelta
        minimumStart = lowStart + lazyDelta; maximumStart = highStart + lazyDelta
    }
}

private func iaiHeight(node: ?InlineAttemptBranch): Int64 { return if (let Some(n) <- node) { n.height } else { 0 } }
private func iaiSize(node: ?InlineAttemptBranch): Int64 { return if (let Some(n) <- node) { n.size } else { 0 } }
private func iaiShift(node: ?InlineAttemptBranch, delta: Int64): ?InlineAttemptBranch {
    if (delta == 0) { return node }
    if (let Some(n) <- node) {
        return Some(InlineAttemptBranch(n.order, n.record, n.left, n.right, lazyDelta: n.lazyDelta + delta))
    }
    return None
}
private func iaiPush(node: InlineAttemptBranch): InlineAttemptBranch {
    if (node.lazyDelta == 0) { return node }
    return InlineAttemptBranch(node.order, node.record.shifted(node.lazyDelta),
        iaiShift(node.left, node.lazyDelta), iaiShift(node.right, node.lazyDelta))
}
private func iaiBalance(node: InlineAttemptBranch): InlineAttemptBranch {
    let n = iaiPush(node)
    if (iaiHeight(n.left) > iaiHeight(n.right) + 1) {
        let l = iaiPush(n.left.getOrThrow())
        if (iaiHeight(l.left) >= iaiHeight(l.right)) {
            return InlineAttemptBranch(l.order, l.record, l.left,
                Some(InlineAttemptBranch(n.order, n.record, l.right, n.right)))
        }
        let middle = iaiPush(l.right.getOrThrow())
        return InlineAttemptBranch(middle.order, middle.record,
            Some(InlineAttemptBranch(l.order, l.record, l.left, middle.left)),
            Some(InlineAttemptBranch(n.order, n.record, middle.right, n.right)))
    }
    if (iaiHeight(n.right) > iaiHeight(n.left) + 1) {
        let r = iaiPush(n.right.getOrThrow())
        if (iaiHeight(r.right) >= iaiHeight(r.left)) {
            return InlineAttemptBranch(r.order, r.record,
                Some(InlineAttemptBranch(n.order, n.record, n.left, r.left)), r.right)
        }
        let middle = iaiPush(r.left.getOrThrow())
        return InlineAttemptBranch(middle.order, middle.record,
            Some(InlineAttemptBranch(n.order, n.record, n.left, middle.left)),
            Some(InlineAttemptBranch(r.order, r.record, middle.right, r.right)))
    }
    return n
}
private func iaiJoin(left: ?InlineAttemptBranch, order: InlineAttemptOrder, record: InlineAttemptRecord,
    right: ?InlineAttemptBranch): InlineAttemptBranch {
    if (iaiHeight(left) > iaiHeight(right) + 1) {
        let l = iaiPush(left.getOrThrow())
        return iaiBalance(InlineAttemptBranch(l.order, l.record, l.left, Some(iaiJoin(l.right, order, record, right))))
    }
    if (iaiHeight(right) > iaiHeight(left) + 1) {
        let r = iaiPush(right.getOrThrow())
        return iaiBalance(InlineAttemptBranch(r.order, r.record, Some(iaiJoin(left, order, record, r.left)), r.right))
    }
    return InlineAttemptBranch(order, record, left, right)
}
private func iaiInsert(root: ?InlineAttemptBranch, order: InlineAttemptOrder, record: InlineAttemptRecord): InlineAttemptBranch {
    if (let Some(raw) <- root) {
        let n = iaiPush(raw)
        let comparison = iaiOrderCompare(order, n.order)
        if (comparison < 0) { return iaiBalance(InlineAttemptBranch(n.order, n.record, Some(iaiInsert(n.left, order, record)), n.right)) }
        if (comparison > 0) { return iaiBalance(InlineAttemptBranch(n.order, n.record, n.left, Some(iaiInsert(n.right, order, record)))) }
        throw IllegalArgumentException("Duplicate inline attempt order")
    }
    return InlineAttemptBranch(order, record, None, None)
}
private func iaiMinimum(root: InlineAttemptBranch): InlineAttemptBranch {
    var n = iaiPush(root)
    while (let Some(left) <- n.left) { n = iaiPush(left) }
    return n
}
private func iaiDelete(root: ?InlineAttemptBranch, order: InlineAttemptOrder): ?InlineAttemptBranch {
    if (let Some(raw) <- root) {
        let n = iaiPush(raw); let comparison = iaiOrderCompare(order, n.order)
        if (comparison < 0) { return Some(iaiBalance(InlineAttemptBranch(n.order, n.record, iaiDelete(n.left, order), n.right))) }
        if (comparison > 0) { return Some(iaiBalance(InlineAttemptBranch(n.order, n.record, n.left, iaiDelete(n.right, order)))) }
        if (n.left.isNone()) { return n.right }
        if (n.right.isNone()) { return n.left }
        let next = iaiMinimum(n.right.getOrThrow())
        return Some(iaiBalance(InlineAttemptBranch(next.order, next.record, n.left, iaiDelete(n.right, next.order))))
    }
    return None
}
private func iaiSplit(root: ?InlineAttemptBranch, position: Int64): (?InlineAttemptBranch, ?InlineAttemptBranch) {
    if (let Some(raw) <- root) {
        let n = iaiPush(raw)
        if (n.record.startByte <= position) {
            let (near, far) = iaiSplit(n.right, position)
            return (Some(iaiJoin(n.left, n.order, n.record, near)), far)
        }
        let (far, near) = iaiSplit(n.left, position)
        return (far, Some(iaiJoin(near, n.order, n.record, n.right)))
    }
    return (None, None)
}
private func iaiConcat(left: ?InlineAttemptBranch, right: ?InlineAttemptBranch): ?InlineAttemptBranch {
    if (left.isNone()) { return right }
    if (right.isNone()) { return left }
    let next = iaiMinimum(right.getOrThrow())
    return Some(iaiJoin(left, next.order, next.record, iaiDelete(right, next.order)))
}
private func iaiFind(root: ?InlineAttemptBranch, order: InlineAttemptOrder): ?InlineAttemptRecord {
    var cursor = root; var delta: Int64 = 0
    while (let Some(n) <- cursor) {
        delta += n.lazyDelta
        let comparison = iaiOrderCompare(order, n.order)
        if (comparison == 0) { return Some(n.record.shifted(delta)) }
        cursor = if (comparison < 0) { n.left } else { n.right }
    }
    return None
}
private func iaiRecordBefore(left: InlineAttemptRecord, right: InlineAttemptRecord): Bool {
    if (left.startByte != right.startByte) { return left.startByte < right.startByte }
    if (left.parserIdentity != right.parserIdentity) { return left.parserIdentity < right.parserIdentity }
    return left.owner < right.owner
}
private func iaiNeighbors(root: ?InlineAttemptBranch, record: InlineAttemptRecord): (?InlineAttemptOrder, ?InlineAttemptOrder) {
    var cursor = root; var delta: Int64 = 0
    var before: ?InlineAttemptOrder = None; var after: ?InlineAttemptOrder = None
    while (let Some(n) <- cursor) {
        delta += n.lazyDelta
        if (iaiRecordBefore(n.record.shifted(delta), record)) { before = Some(n.order); cursor = n.right }
        else { after = Some(n.order); cursor = n.left }
    }
    return (before, after)
}
private func iaiQuery(root: ?InlineAttemptBranch, start: Int64, end: Int64,
    delta: Int64, result: ArrayList<InlineAttemptRecord>): Unit {
    if (let Some(n) <- root) {
        if (n.maximumRead + delta < start || n.minimumRead + delta > end) { return }
        let shifted = delta + n.lazyDelta
        iaiQuery(n.left, start, end, shifted, result)
        if (n.record.readStart + shifted <= end && n.record.readEnd + shifted >= start) { result.add(n.record.shifted(shifted)) }
        iaiQuery(n.right, start, end, shifted, result)
    }
}
private func iaiCollect(root: ?InlineAttemptBranch, delta: Int64, result: ArrayList<InlineAttemptRecord>): Unit {
    if (let Some(n) <- root) {
        let shifted = delta + n.lazyDelta
        iaiCollect(n.left, shifted, result); result.add(n.record.shifted(shifted)); iaiCollect(n.right, shifted, result)
    }
}

// Shared persistent AVL implementation for owner, semantic-key and nested-owner
// locators. No locator contains a mutable branch pointer or current byte offset.
internal class InlineAttemptLocator {
    let height: Int64
    InlineAttemptLocator(let key: String, let group: Int64, let owner: Int64, let order: InlineAttemptOrder,
        let left: ?InlineAttemptLocator, let right: ?InlineAttemptLocator) {
        height = 1 + if (iaiLocatorHeight(left) > iaiLocatorHeight(right)) { iaiLocatorHeight(left) } else { iaiLocatorHeight(right) }
    }
}
private func iaiLocatorHeight(root: ?InlineAttemptLocator): Int64 { return if (let Some(n) <- root) { n.height } else { 0 } }
private func iaiLocatorCompare(key: String, group: Int64, owner: Int64, n: InlineAttemptLocator): Int64 {
    if (key != n.key) { return if (key < n.key) { -1 } else { 1 } }
    if (group != n.group) { return if (group < n.group) { -1 } else { 1 } }
    return if (owner < n.owner) { -1 } else if (owner > n.owner) { 1 } else { 0 }
}
private func iaiLocatorBalance(n: InlineAttemptLocator): InlineAttemptLocator {
    if (iaiLocatorHeight(n.left) > iaiLocatorHeight(n.right) + 1) {
        let l = n.left.getOrThrow()
        if (iaiLocatorHeight(l.left) >= iaiLocatorHeight(l.right)) {
            return InlineAttemptLocator(l.key, l.group, l.owner, l.order, l.left,
                Some(InlineAttemptLocator(n.key, n.group, n.owner, n.order, l.right, n.right)))
        }
        let m = l.right.getOrThrow()
        return InlineAttemptLocator(m.key, m.group, m.owner, m.order,
            Some(InlineAttemptLocator(l.key, l.group, l.owner, l.order, l.left, m.left)),
            Some(InlineAttemptLocator(n.key, n.group, n.owner, n.order, m.right, n.right)))
    }
    if (iaiLocatorHeight(n.right) > iaiLocatorHeight(n.left) + 1) {
        let r = n.right.getOrThrow()
        if (iaiLocatorHeight(r.right) >= iaiLocatorHeight(r.left)) {
            return InlineAttemptLocator(r.key, r.group, r.owner, r.order,
                Some(InlineAttemptLocator(n.key, n.group, n.owner, n.order, n.left, r.left)), r.right)
        }
        let m = r.left.getOrThrow()
        return InlineAttemptLocator(m.key, m.group, m.owner, m.order,
            Some(InlineAttemptLocator(n.key, n.group, n.owner, n.order, n.left, m.left)),
            Some(InlineAttemptLocator(r.key, r.group, r.owner, r.order, m.right, r.right)))
    }
    return n
}
private func iaiLocatorPut(root: ?InlineAttemptLocator, key: String, group: Int64, owner: Int64,
    order: InlineAttemptOrder): InlineAttemptLocator {
    if (let Some(n) <- root) {
        let comparison = iaiLocatorCompare(key, group, owner, n)
        if (comparison < 0) { return iaiLocatorBalance(InlineAttemptLocator(n.key, n.group, n.owner, n.order,
            Some(iaiLocatorPut(n.left, key, group, owner, order)), n.right)) }
        if (comparison > 0) { return iaiLocatorBalance(InlineAttemptLocator(n.key, n.group, n.owner, n.order,
            n.left, Some(iaiLocatorPut(n.right, key, group, owner, order)))) }
        return InlineAttemptLocator(key, group, owner, order, n.left, n.right)
    }
    return InlineAttemptLocator(key, group, owner, order, None, None)
}
private func iaiLocatorGet(root: ?InlineAttemptLocator, key: String, group: Int64, owner: Int64): ?InlineAttemptOrder {
    var cursor = root
    while (let Some(n) <- cursor) {
        let comparison = iaiLocatorCompare(key, group, owner, n)
        if (comparison == 0) { return Some(n.order) }
        cursor = if (comparison < 0) { n.left } else { n.right }
    }
    return None
}
private func iaiLocatorDelete(root: ?InlineAttemptLocator, key: String, group: Int64, owner: Int64): ?InlineAttemptLocator {
    if (let Some(n) <- root) {
        let comparison = iaiLocatorCompare(key, group, owner, n)
        if (comparison < 0) { return Some(iaiLocatorBalance(InlineAttemptLocator(n.key, n.group, n.owner, n.order,
            iaiLocatorDelete(n.left, key, group, owner), n.right))) }
        if (comparison > 0) { return Some(iaiLocatorBalance(InlineAttemptLocator(n.key, n.group, n.owner, n.order,
            n.left, iaiLocatorDelete(n.right, key, group, owner)))) }
        if (n.left.isNone()) { return n.right }
        if (n.right.isNone()) { return n.left }
        var next = n.right.getOrThrow()
        while (let Some(left) <- next.left) { next = left }
        return Some(iaiLocatorBalance(InlineAttemptLocator(next.key, next.group, next.owner, next.order,
            n.left, iaiLocatorDelete(n.right, next.key, next.group, next.owner))))
    }
    return None
}
private func iaiLocatorSelect(root: ?InlineAttemptLocator, key: String, group: Int64,
    attempts: ?InlineAttemptBranch, result: ArrayList<InlineAttemptRecord>): Unit {
    if (let Some(n) <- root) {
        if (key < n.key || (key == n.key && group < n.group)) { iaiLocatorSelect(n.left, key, group, attempts, result) }
        else if (key > n.key || (key == n.key && group > n.group)) { iaiLocatorSelect(n.right, key, group, attempts, result) }
        else {
            iaiLocatorSelect(n.left, key, group, attempts, result)
            if (let Some(record) <- iaiFind(attempts, n.order)) { result.add(record) }
            iaiLocatorSelect(n.right, key, group, attempts, result)
        }
    }
}

private func iaiValidateRecord(record: InlineAttemptRecord, target: SourceVersionIdentity, mappingIdentity: String): Unit {
    if (record.source.documentId != target.documentId || record.source.version > target.version ||
        record.mappingIdentity != mappingIdentity) { throw IllegalArgumentException("Mismatched inline evidence source/mapping") }
}

public class InlineAttemptIndex {
    public let source: SourceVersionIdentity
    public let mappingIdentity: String
    private let attempts: ?InlineAttemptBranch
    private let owners: ?InlineAttemptLocator
    private let semanticReaders: ?InlineAttemptLocator
    private let nestedReaders: ?InlineAttemptLocator
    private let lengthReaderOwners: ?InlineAttemptLocator
    public prop size: Int64 { get() { return iaiSize(attempts) } }

    public InlineAttemptIndex(source: SourceVersionIdentity, mappingIdentity: String,
        records!: Array<InlineAttemptRecord> = []) {
        if (mappingIdentity.isEmpty()) { throw IllegalArgumentException("Missing inline mapping identity") }
        this.source = source; this.mappingIdentity = mappingIdentity
        var root: ?InlineAttemptBranch = None; var ownerRoot: ?InlineAttemptLocator = None
        var semanticRoot: ?InlineAttemptLocator = None; var nestedRoot: ?InlineAttemptLocator = None
        var lengthRoot: ?InlineAttemptLocator = None
        for (record in records) {
            iaiValidateRecord(record, source, mappingIdentity)
            if (iaiLocatorGet(ownerRoot, "", 0, record.owner).isSome()) { throw IllegalArgumentException("Duplicate inline attempt owner") }
            let (before, after) = iaiNeighbors(root, record)
            let order = iaiBetween(before, after)
            root = Some(iaiInsert(root, order, record))
            ownerRoot = Some(iaiLocatorPut(ownerRoot, "", 0, record.owner, order))
            for (i in 0..record.dependencyCount) {
                semanticRoot = Some(iaiLocatorPut(semanticRoot, record.dependencyAt(i).key, 0, record.owner, order))
            }
            nestedRoot = Some(iaiLocatorPut(nestedRoot, "", record.nestedOwner, record.owner, order))
            if (record.dependsOnLength) { lengthRoot = Some(iaiLocatorPut(lengthRoot, "", 0, record.owner, order)) }
        }
        attempts = root; owners = ownerRoot; semanticReaders = semanticRoot; nestedReaders = nestedRoot
        lengthReaderOwners = lengthRoot
    }

    private init(source: SourceVersionIdentity, mappingIdentity: String, attempts: ?InlineAttemptBranch,
        owners: ?InlineAttemptLocator, semanticReaders: ?InlineAttemptLocator, nestedReaders: ?InlineAttemptLocator,
        lengthReaderOwners: ?InlineAttemptLocator) {
        this.source = source; this.mappingIdentity = mappingIdentity; this.attempts = attempts
        this.owners = owners; this.semanticReaders = semanticReaders; this.nestedReaders = nestedReaders
        this.lengthReaderOwners = lengthReaderOwners
    }

    private func validateOwnerSchema(record: InlineAttemptRecord): Unit {
        if (let Some(previous) <- byOwner(record.owner)) {
            if (record.parserIdentity != previous.parserIdentity || record.parserOwner != previous.parserOwner ||
                record.grammarVersion != previous.grammarVersion || record.mappingIdentity != previous.mappingIdentity ||
                record.nestedOwner != previous.nestedOwner) {
                throw IllegalArgumentException("Changed schema for existing inline attempt owner")
            }
        }
    }

    // Closed read-footprint intersection intentionally includes either side of
    // a zero-width insertion: an absent closer may have read exactly to EOF.
    public func query(start: Int64, end: Int64): Array<InlineAttemptRecord> {
        if (start < 0 || end < start) { throw IllegalArgumentException("Invalid inline read query") }
        let result = ArrayList<InlineAttemptRecord>()
        iaiQuery(attempts, start, end, 0, result)
        return result.toArray()
    }
    public func intersecting(start: Int64, end: Int64): Array<InlineAttemptRecord> { return query(start, end) }
    public func byOwner(owner: Int64): ?InlineAttemptRecord {
        if (let Some(order) <- iaiLocatorGet(owners, "", 0, owner)) { return iaiFind(attempts, order) }
        return None
    }
    public func readingKey(key: String): Array<InlineAttemptRecord> {
        let result = ArrayList<InlineAttemptRecord>()
        iaiLocatorSelect(semanticReaders, key, 0, attempts, result)
        return result.toArray()
    }
    public func hasReadingKey(key: String): Bool {
        var cursor = semanticReaders
        while (let Some(reader) <- cursor) {
            if (key == reader.key) { return true }
            cursor = if (key < reader.key) { reader.left } else { reader.right }
        }
        return false
    }
    public func nestedAttempts(owner: Int64): Array<InlineAttemptRecord> {
        let result = ArrayList<InlineAttemptRecord>()
        iaiLocatorSelect(nestedReaders, "", owner, attempts, result)
        return result.toArray()
    }
    // Length is an observable metadata dependency, not a fabricated character
    // read covering an entire owner. Call only when the view's length changes.
    public func lengthReaders(): Array<InlineAttemptRecord> {
        let result = ArrayList<InlineAttemptRecord>()
        iaiLocatorSelect(lengthReaderOwners, "", 0, attempts, result)
        return result.toArray()
    }
    // Explicit export only. Hot edits use augmented read queries and locators.
    public func records(): Array<InlineAttemptRecord> {
        let result = ArrayList<InlineAttemptRecord>()
        iaiCollect(attempts, 0, result)
        return result.toArray()
    }

    // The caller retries query(windowStart,oldEnd), including attempts whose
    // opener is outside the edit but whose failed read crosses it. All touched
    // evidence is removed before adding actual replacement attempts. Only a
    // wholly unaffected suffix receives a lazy coordinate delta.
    public func splice(windowStart: Int64, oldEnd: Int64, newEnd: Int64,
        replacements: Array<InlineAttemptRecord>, target: SourceVersionIdentity): InlineAttemptIndex {
        if (windowStart < 0 || oldEnd < windowStart || newEnd < windowStart ||
            target.documentId != source.documentId || target.version <= source.version) {
            throw IllegalArgumentException("Invalid inline index splice version/range")
        }
        var root = attempts; var ownerRoot = owners
        var semanticRoot = semanticReaders; var nestedRoot = nestedReaders
        var lengthRoot = lengthReaderOwners
        let invalidated = ArrayList<InlineAttemptRecord>()
        for (record in query(windowStart, oldEnd)) { invalidated.add(record) }
        if (newEnd != oldEnd) {
            for (record in lengthReaders()) { invalidated.add(record) }
        }
        for (record in invalidated) {
            let located = iaiLocatorGet(ownerRoot, "", 0, record.owner)
            if (located.isNone()) { continue }
            root = iaiDelete(root, located.getOrThrow())
            ownerRoot = iaiLocatorDelete(ownerRoot, "", 0, record.owner)
            for (i in 0..record.dependencyCount) {
                semanticRoot = iaiLocatorDelete(semanticRoot, record.dependencyAt(i).key, 0, record.owner)
            }
            nestedRoot = iaiLocatorDelete(nestedRoot, "", record.nestedOwner, record.owner)
            if (record.dependsOnLength) { lengthRoot = iaiLocatorDelete(lengthRoot, "", 0, record.owner) }
        }
        let (prefix, suffix) = iaiSplit(root, oldEnd)
        root = iaiConcat(prefix, iaiShift(suffix, newEnd - oldEnd))
        for (record in replacements) {
            iaiValidateRecord(record, target, mappingIdentity)
            validateOwnerSchema(record)
            if (record.source.version != target.version || iaiLocatorGet(ownerRoot, "", 0, record.owner).isSome()) {
                throw IllegalArgumentException("Stale or duplicate replacement inline attempt")
            }
            let (before, after) = iaiNeighbors(root, record)
            let order = iaiBetween(before, after)
            root = Some(iaiInsert(root, order, record))
            ownerRoot = Some(iaiLocatorPut(ownerRoot, "", 0, record.owner, order))
            for (i in 0..record.dependencyCount) {
                semanticRoot = Some(iaiLocatorPut(semanticRoot, record.dependencyAt(i).key, 0, record.owner, order))
            }
            nestedRoot = Some(iaiLocatorPut(nestedRoot, "", record.nestedOwner, record.owner, order))
            if (record.dependsOnLength) { lengthRoot = Some(iaiLocatorPut(lengthRoot, "", 0, record.owner, order)) }
        }
        return InlineAttemptIndex(target, mappingIdentity, root, ownerRoot, semanticRoot, nestedRoot, lengthRoot)
    }

    // Semantic-only retries replace explicit owners in the same source epoch.
    // Geometry is not shifted and unrelated read/key/length locators are shared.
    public func replacingOwners(ownerIds: Array<Int64>, replacements: Array<InlineAttemptRecord>): InlineAttemptIndex {
        var root = attempts; var ownerRoot = owners
        var semanticRoot = semanticReaders; var nestedRoot = nestedReaders
        var lengthRoot = lengthReaderOwners
        for (owner in ownerIds) {
            if (let Some(order) <- iaiLocatorGet(ownerRoot, "", 0, owner)) {
                let record = iaiFind(root, order).getOrThrow()
                root = iaiDelete(root, order)
                ownerRoot = iaiLocatorDelete(ownerRoot, "", 0, owner)
                for (i in 0..record.dependencyCount) {
                    semanticRoot = iaiLocatorDelete(semanticRoot, record.dependencyAt(i).key, 0, owner)
                }
                nestedRoot = iaiLocatorDelete(nestedRoot, "", record.nestedOwner, owner)
                if (record.dependsOnLength) { lengthRoot = iaiLocatorDelete(lengthRoot, "", 0, owner) }
            }
        }
        for (record in replacements) {
            iaiValidateRecord(record, source, mappingIdentity)
            validateOwnerSchema(record)
            if (record.source.version != source.version || iaiLocatorGet(ownerRoot, "", 0, record.owner).isSome()) {
                throw IllegalArgumentException("Stale or duplicate semantic inline attempt")
            }
            let (before, after) = iaiNeighbors(root, record)
            let order = iaiBetween(before, after)
            root = Some(iaiInsert(root, order, record))
            ownerRoot = Some(iaiLocatorPut(ownerRoot, "", 0, record.owner, order))
            for (i in 0..record.dependencyCount) {
                semanticRoot = Some(iaiLocatorPut(semanticRoot, record.dependencyAt(i).key, 0, record.owner, order))
            }
            nestedRoot = Some(iaiLocatorPut(nestedRoot, "", record.nestedOwner, record.owner, order))
            if (record.dependsOnLength) { lengthRoot = Some(iaiLocatorPut(lengthRoot, "", 0, record.owner, order)) }
        }
        return InlineAttemptIndex(source, mappingIdentity, root, ownerRoot, semanticRoot, nestedRoot, lengthRoot)
    }
}
