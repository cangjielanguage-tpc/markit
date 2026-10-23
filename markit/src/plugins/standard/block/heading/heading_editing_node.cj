package markit.plugins.standard.block.heading

import markit.core.source.SourceSpan
import markit.plugins.standard.editing.{StandardBlockRecovery, StandardBlockRecoveryCarrier}

public class EditingHeadingNode <: HeadingNode & StandardBlockRecoveryCarrier {
    private let savedRecovery: StandardBlockRecovery
    public var visible: Bool
    public EditingHeadingNode(id: Int64, span: SourceSpan, content: String, level: Int64,
        recovery: StandardBlockRecovery, slug!: String = "", visible!: Bool = true) {
        super(id, span, content, level, slug: slug)
        this.savedRecovery = recovery
        this.visible = visible
    }
    public prop blockRecovery: ?StandardBlockRecovery { get() { return Some(savedRecovery) } }
}
