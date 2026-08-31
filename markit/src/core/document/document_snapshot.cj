package markit.core.document

import std.collection.{ArrayList, HashMap}
import markit.core.nodes.Node
import markit.core.source.{LineIndex, SourceLine}

public class DocumentSnapshot {
    public let root: Node
    public let lineIndex: LineIndex
    private let nodesById = HashMap<Int64, Node>()
    private let orderedNodes = ArrayList<Node>()

    public init(root: Node, lineIndex!: LineIndex = LineIndex()) {
        this.root = root
        this.lineIndex = lineIndex
        index(root)
    }

    public func nodeCount(): Int64 {
        return orderedNodes.size
    }

    public func nodeById(id: Int64): ?Node {
        return nodesById.get(id)
    }

    public func nodesInByteRange(startByte: Int64, endByte: Int64): ArrayList<Node> {
        let result = ArrayList<Node>()
        for (node in orderedNodes) {
            let span = node.sourceSpan
            if (span.endByte >= startByte && span.startByte <= endByte) {
                result.add(node)
            }
        }
        return result
    }

    public func lineAt(index: Int64): SourceLine {
        return lineIndex.lineAt(index)
    }

    public func stableHash(): Int64 {
        return root.stableHash()
    }

    private func index(node: Node): Unit {
        nodesById[node.id] = node
        orderedNodes.add(node)
        for (child in node.children) {
            index(child)
        }
    }
}
