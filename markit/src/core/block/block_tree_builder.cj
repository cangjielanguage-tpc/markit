package markit.core.block

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.SourceLine

public class BlockTreeBuilder {
    public static func parseLines(session: ParseSession,
        continuationBlockDispatchTable: ContinuationBlockDispatchTable,
        blockDispatchTable: BlockDispatchTable,
        paragraphBlockParsers: ArrayList<ParagraphBlockParser>,
        lines: ArrayList<SourceLine>): ArrayList<Node> {
        let kernel = BlockParsingKernel(session, continuationBlockDispatchTable,
            blockDispatchTable, paragraphBlockParsers)
        let result = ArrayList<Node>()
        kernel.setEmissionSink({ node: Node => result.add(node) })
        for (line in lines) { kernel.feed(line) }
        kernel.finish()
        return result
    }
}