# Task07-P semantic publication seam

Status: Implemented, integrated verification pending. This is necessary production work for the real Standard pilot, not a completed plugin count.

Unique core writer: `task02_contracts` owns `core/block/block_editing_facet.cj` and `core/incremental/document_editing_session.cj`. `task04_tree` owns the persistent node/document bridges; Reference owner owns the separately assigned affected-key effect ordering seam.

- `BlockEditingFacet.replaySemanticResult(context,node):?BlockUnitParseResult` defaults to the existing `replaySemantic(context,node):Unit` followed by `None`. Existing overrides retain source compatibility.
- `BlockPayloadUpdate(payload:SyntaxNodePayload,nodeId:Int64)` detaches input/output payloads. `BlockUnitParseResult.payloadUpdates` defaults to an empty array. Updates can accompany a child splice; a payload-only result does not replace/reindex the whole subtree.
- `BlockEditingContext.withPrevious(candidate,invalidatedKeys:keys)` observes the staged candidate and actual changed keys. It shares transactional state in O(1), refuses an active nested state scope, and retains the same effects transaction. Exported key arrays are copied.
- The editing-only result stager consumes raw/typed replacements, ordered child edits, and payload updates. Payload updates preserve child identities, source anchors, and the existing persistent child index. Deleted owners are revoked; surviving descendant effects are retained.
- Later edits use a nonsealing syntax preview during semantic fixed point. Syntax is sealed once after local semantic changes settle; source acknowledgement, cancellation/staleness checks, parser rollback, and the existing joint tree/effects publication gate remain in force. Semantic updates do not call syntax parsers or increase `syntaxUnitsParsed`.
- Initialization also replays actual invalidated readers after the one syntax pass and before the first tree/effects publication, allowing a reference before its later definition to receive its typed view without a source pre-scan.

First actual result: `block-compile-1.log` records SDK 1.3-alpha package compilation exit 0 against immutable Task06 dependencies. It validates the new block API syntax/types only. New persistent storage/effects closure, real Standard fresh comparisons, old snapshots, cancellation/staleness atomicity, and the full suite remain pending; no runtime pass is inferred from this result.

Required real pilot checks are initial forward references, definition change/removal resolved/missing typed transitions without unrelated syntax work, stable IDs/source spans and old snapshots, local payload updates of other affected headings, and failure/cancel/stale rejection before common publication. The existing real Standard pilot tests should carry these checks rather than a new general testing framework.
