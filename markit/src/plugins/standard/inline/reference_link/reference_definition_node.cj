package markit.plugins.standard.inline.reference_link

import markit.core.nodes.Node
import markit.core.source.SourceSpan
import markit.plugins.standard.editing.{StandardBlockRecovery, StandardBlockRecoveryCarrier}

public class ReferenceDefinitionNode <: Node & StandardBlockRecoveryCarrier {
    public ReferenceDefinitionNode(id: Int64, span: SourceSpan, public let label: String,
        public let url: String, public let title: String, private let recovery!: ?StandardBlockRecovery = None) {
        super("LinkDefinition", id: id, sourceSpan: span)
    }
    public prop blockRecovery: ?StandardBlockRecovery { get() { return recovery } }
}
