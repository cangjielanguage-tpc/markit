package markit.plugins.standard.block.heading

import markit.core.editing.OwnedEffectPayload
import markit.core.session.OwnedEffectSnapshot

// The independent semantic owner publishes exactly one candidate for this key.
// Cloning shares only immutable index records, including their source anchors.
public class HeadingIndexPayload <: OwnedEffectPayload {
    public HeadingIndexPayload(public let index: HeadingOrderedIndex) {}
    public func cloneEffectPayload(): OwnedEffectPayload { return HeadingIndexPayload(index) }
}

public func headingIndexFor(effects: OwnedEffectSnapshot): ?HeadingOrderedIndex {
    if (let Some(effect) <- effects.winner("standard.heading.index")) {
        if (let payload: HeadingIndexPayload <- effect.payload) { return Some(payload.index) }
    }
    return None
}
