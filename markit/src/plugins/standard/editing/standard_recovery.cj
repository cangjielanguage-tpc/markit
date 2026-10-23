package markit.plugins.standard.editing

import std.collection.ArrayList
import markit.core.block.{BlockKernelCheckpoint, BlockRecoveryUnit, BlockParsingKernel, BlockEditingFacet, BlockEditingContext,
    ContinuationBlockDispatchTable, BlockDispatchTable, ParagraphBlockParser}
import markit.core.editing.IncrementalCheckpoint
import markit.core.nodes.{RawSyntaxNode, MaterializableNodePayload}
import markit.core.session.ParseSessionCheckpoint
import markit.core.session.ParseSession

// A leaf/finished paragraph owns no continuation frame. This asks the shared
// kernel for its real closed-state checkpoint rather than constructing one.
public func standardClosedKernelCheckpoint(session: ParseSession): BlockKernelCheckpoint {
    return BlockParsingKernel(session, ContinuationBlockDispatchTable(), BlockDispatchTable(),
        ArrayList<ParagraphBlockParser>()).checkpoint()
}
// Leaf recovery starts after the preceding paragraph has its own tree owner.
// Capture this state in the existing sandbox without dropping live pending text.
private class StandardLeafCheckpointBox {
    public var value: ?ParseSessionCheckpoint = None
}
public func standardLeafSessionCheckpoint(session: ParseSession): ParseSessionCheckpoint {
    let saved = StandardLeafCheckpointBox()
    session.sandboxProbe({ =>
        session.clearPendingParagraph()
        saved.value = Some(session.checkpoint())
        return true
    })
    return saved.value.getOrThrow()
}

// Legacy typed nodes return None; an explicit editing subtype carries the
// immutable entry/exit evidence. The helper never recognizes plugin syntax.
public interface StandardBlockRecoveryCarrier {
    prop blockRecovery: ?StandardBlockRecovery
}
public interface StandardMappedRecoveryCarrier {
    prop mappedRecoveryProvider: BlockEditingFacet
}
public func recoverStandardMappedAncestor(context: BlockEditingContext, node: RawSyntaxNode,
    editStart: Int64, editEnd: Int64): ?BlockRecoveryUnit {
    if (context.previous.isNone()) { return None }
    let previous = context.previous.getOrThrow()
    var cursor = previous.parentOf(node.identity.nodeId)
    var selected: ?(BlockEditingFacet, RawSyntaxNode) = None
    while (let Some(parent) <- cursor) {
        if (let payload: MaterializableNodePayload <- parent.syntax.payload) {
            if (let mapped: StandardMappedRecoveryCarrier <- payload.materializeShallow()) {
                selected = Some((mapped.mappedRecoveryProvider, parent.syntax))
            }
        }
        cursor = parent.parent()
    }
    if (let Some((provider, owner)) <- selected) { return provider.recover(context, owner, editStart, editEnd) }
    return None
}

public class StandardBlockRecovery {
    public StandardBlockRecovery(public let session: ParseSessionCheckpoint,
        public let syntax: IncrementalCheckpoint, public let kernel: BlockKernelCheckpoint,
        public let expectedExit: IncrementalCheckpoint, public let expectedKernel: BlockKernelCheckpoint) {}

    public func unit(owner: String, node: RawSyntaxNode, mappingVersion!: Int64 = -1,
        nestedContext!: String = ""): BlockRecoveryUnit {
        return BlockRecoveryUnit(owner, node.identity.nodeId, node.startAnchor, node.endAnchor,
            session, kernel, syntax, expectedExit: Some(expectedExit), expectedKernel: Some(expectedKernel),
            mappingVersion: mappingVersion, nestedContext: nestedContext)
    }
}
