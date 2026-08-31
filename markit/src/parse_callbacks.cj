package markit

import markit.core.document.DocumentSnapshot
import markit.core.incremental.{AstPatch, HtmlFragment, IncrementalUpdate, PendingTailState}
import markit.core.nodes.Node

public class ParseCallbacks {
    public let onUpdate: (IncrementalUpdate) -> Unit
    public let onBlockSealed: (Node) -> Unit
    public let onHtmlFragment: (HtmlFragment) -> Unit
    public let onAstPatch: (AstPatch) -> Unit
    public let onTailChanged: (PendingTailState) -> Unit
    public let onFinalize: (DocumentSnapshot) -> Unit

    public init(
        onUpdate!: (IncrementalUpdate) -> Unit = { _: IncrementalUpdate => },
        onBlockSealed!: (Node) -> Unit = { _: Node => },
        onHtmlFragment!: (HtmlFragment) -> Unit = { _: HtmlFragment => },
        onAstPatch!: (AstPatch) -> Unit = { _: AstPatch => },
        onTailChanged!: (PendingTailState) -> Unit = { _: PendingTailState => },
        onFinalize!: (DocumentSnapshot) -> Unit = { _: DocumentSnapshot => }
    ) {
        this.onUpdate = onUpdate
        this.onBlockSealed = onBlockSealed
        this.onHtmlFragment = onHtmlFragment
        this.onAstPatch = onAstPatch
        this.onTailChanged = onTailChanged
        this.onFinalize = onFinalize
    }
}
