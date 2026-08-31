package markit.core.block

import std.collection.{ArrayList, HashMap}
import markit.core.nodes.Node
import markit.core.session.ParseSession

public interface BlockState {}

public class BlockFrame {
    public let state: BlockState

    public init(state: BlockState) {
        this.state = state
    }
}

public enum ContinueResult {
    |Open
    |Closed
    |ClosedAndReprocess
}

public interface ContinuationBlockParser {
    prop name: String
    prop ownerPlugin: String
    prop priority: Int64
    prop startBytes: Array<Byte>

    func tryStart(session: ParseSession, line: String): ?BlockFrame
    func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult
    func finalize(session: ParseSession, frame: BlockFrame): Node
}

public class ContinuationBlockDispatchTable {
    private let byStartByte = HashMap<Byte, ArrayList<ContinuationBlockParser>>()
    private let emptyCandidates = ArrayList<ContinuationBlockParser>()

    public func register(parser: ContinuationBlockParser): Unit {
        for (b in parser.startBytes) {
            if (!byStartByte.contains(b)) {
                byStartByte[b] = ArrayList<ContinuationBlockParser>()
            }
            insertByPriority(byStartByte[b], parser)
        }
    }

    public func candidatesFor(line: String): ArrayList<ContinuationBlockParser> {
        let maybeHead = firstNonSpaceByte(line)
        return candidatesForFirstNonSpace(maybeHead)
    }

    public func candidatesForFirstNonSpace(maybeHead: ?Byte): ArrayList<ContinuationBlockParser> {
        if (let Some(head) <- maybeHead) {
            if (let Some(bucket) <- byStartByte.get(head)) {
                return bucket
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

    private func insertByPriority(parsers: ArrayList<ContinuationBlockParser>, parser: ContinuationBlockParser): Unit {
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
