package markit.core.inline

import std.collection.{ArrayList, HashMap}

public class InlineDispatchTable {
    private let byStartByte = HashMap<Byte, ArrayList<InlineParser>>()
    private let emptyCandidates = ArrayList<InlineParser>()

    public func register(parser: InlineParser): Unit {
        for (b in parser.startBytes) {
            if (!byStartByte.contains(b)) {
                byStartByte[b] = ArrayList<InlineParser>()
            }
            insertByPriority(byStartByte[b], parser)
        }
    }

    public func candidatesFor(byte: Byte): ArrayList<InlineParser> {
        if (let Some(bucket) <- byStartByte.get(byte)) {
            return bucket
        }
        return emptyCandidates
    }

    public func mayHaveCandidates(text: String): Bool {
        return mayHaveCandidates(text, 0, text.size)
    }

    public func mayHaveCandidates(text: String, startByte: Int64, endByte: Int64): Bool {
        var index = startByte
        while (index < endByte) {
            if (byStartByte.contains(text[index])) {
                return true
            }
            index += 1
        }
        return false
    }

    public func scanRange(text: String, startByte: Int64, endByte: Int64): InlineScanSummary {
        var runeCount: Int64 = 0
        var mayHaveCandidates = false
        var index = startByte
        while (index < endByte) {
            let byte = text[index]
            if (!mayHaveCandidates && byStartByte.contains(byte)) {
                mayHaveCandidates = true
            }
            let width = InlineUtils.nextRuneByteSize(text, index)
            if (width == 0) {
                break
            }
            index += width
            runeCount += 1
        }
        return InlineScanSummary(runeCount, mayHaveCandidates)
    }

    private func insertByPriority(parsers: ArrayList<InlineParser>, parser: InlineParser): Unit {
        parsers.add(parser)
        var index = parsers.size - 1
        while (index > 0 && parsers[index].priority < parsers[index - 1].priority) {
            let previous = parsers[index - 1]
            parsers[index - 1] = parsers[index]
            parsers[index] = previous
            index -= 1
        }
    }
}

public class InlineScanSummary {
    public let runeCount: Int64
    public let mayHaveCandidates: Bool

    public init(runeCount: Int64, mayHaveCandidates: Bool) {
        this.runeCount = runeCount
        this.mayHaveCandidates = mayHaveCandidates
    }
}
