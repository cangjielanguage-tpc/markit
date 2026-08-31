package markit.core.incremental

import std.collection.ArrayList
import markit.core.nodes.Node

public class IncrementalUpdate {
    public let sealedBlocks: ArrayList<Node>
    public let emittedHtmlFragments: ArrayList<HtmlFragment>
    public let astPatches: ArrayList<AstPatch>
    public let pendingTailState: PendingTailState
    public let bytesAccepted: Int64
    public let bytesCommitted: Int64
    public let isFinal: Bool

    public init(
        sealedBlocks!: ArrayList<Node> = ArrayList<Node>(),
        emittedHtmlFragments!: ArrayList<HtmlFragment> = ArrayList<HtmlFragment>(),
        astPatches!: ArrayList<AstPatch> = ArrayList<AstPatch>(),
        pendingTailState!: PendingTailState = PendingTailState(),
        bytesAccepted!: Int64 = 0,
        bytesCommitted!: Int64 = 0,
        isFinal!: Bool = false
    ) {
        this.sealedBlocks = sealedBlocks
        this.emittedHtmlFragments = emittedHtmlFragments
        this.astPatches = astPatches
        this.pendingTailState = pendingTailState
        this.bytesAccepted = bytesAccepted
        this.bytesCommitted = bytesCommitted
        this.isFinal = isFinal
    }
}
