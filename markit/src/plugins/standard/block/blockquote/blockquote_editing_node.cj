package markit.plugins.standard.block.blockquote

import markit.core.source.SourceSpan
import markit.core.block.BlockEditingFacet
import markit.core.inline.MappedInlineTextView
import markit.plugins.standard.editing.{StandardBlockRecovery, StandardBlockRecoveryCarrier, StandardMappedRecoveryCarrier}

public class EditingBlockquoteNode <: BlockquoteNode & StandardBlockRecoveryCarrier & StandardMappedRecoveryCarrier {
    public EditingBlockquoteNode(id: Int64, span: SourceSpan,
        private let saved: StandardBlockRecovery, public let editingProvider: BlockquoteEditingFacet,
        public let rawView: MappedInlineTextView, public let parentQuoteDepth: Int64) {
        super(id, span)
    }
    public prop blockRecovery: ?StandardBlockRecovery { get() { return Some(saved) } }
    public prop mappedRecoveryProvider: BlockEditingFacet { get() { return editingProvider } }
    public override func rawContent(): String { return rawView.sliceBytes(0, rawView.byteLength) }
}
