package markit.core.block

import std.collection.{ArrayList, HashMap}

public class BlockDispatchTable {
    private let byStartByte = HashMap<Byte, ArrayList<LeafBlockParser>>()
    private let anyNonBlank = ArrayList<LeafBlockParser>()
    private let combinedByStartByte = HashMap<Byte, ArrayList<LeafBlockParser>>()
    private let emptyCandidates = ArrayList<LeafBlockParser>()

    public func register(parser: LeafBlockParser): Unit {
        for (b in parser.startBytes) {
            if (!byStartByte.contains(b)) {
                byStartByte[b] = ArrayList<LeafBlockParser>()
            }
            insertByPriority(byStartByte[b], parser)
        }
        if (parser.acceptsAnyNonBlank) {
            insertByPriority(anyNonBlank, parser)
        }
    }

    public func candidatesFor(line: String): ArrayList<LeafBlockParser> {
        let maybeHead = firstNonSpaceByte(line)
        return candidatesForFirstNonSpace(maybeHead)
    }

    public func candidatesForFirstNonSpace(maybeHead: ?Byte): ArrayList<LeafBlockParser> {
        if (let Some(head) <- maybeHead) {
            if (let Some(bucket) <- byStartByte.get(head)) {
                if (anyNonBlank.isEmpty()) {
                    return bucket
                }
                if (let Some(cached) <- combinedByStartByte.get(head)) {
                    return cached
                }
                let combined = ArrayList<LeafBlockParser>()
                for (parser in bucket) {
                    combined.add(parser)
                }
                for (parser in anyNonBlank) {
                    combined.add(parser)
                }
                combinedByStartByte[head] = combined
                return combined
            }
            if (!anyNonBlank.isEmpty()) {
                return anyNonBlank
            }
        }
        return emptyCandidates
    }

    private func firstNonSpaceByte(line: String): ?Byte {
        var index: Int64 = 0
        while (index < line.size && (line[index] == b' ' || line[index] == b'\t')) {
            index += 1
        }
        if (index >= line.size) {
            return None
        }
        return Some(line[index])
    }

    private func insertByPriority(parsers: ArrayList<LeafBlockParser>, parser: LeafBlockParser): Unit {
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
