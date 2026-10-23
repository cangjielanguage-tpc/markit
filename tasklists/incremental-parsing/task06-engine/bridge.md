# Task06 block/document/Markit bridge

Owner: `task05_engine/session_checkpoint`, reassigned by root after the earlier main owner was interrupted. Inline session/facet/main engine tests remain exclusively owned by `task04_tree`. Shared editing contracts and registry changes remain owned by `task02_contracts`.

Product scope:

- `markit/src/markit.cj`: validates actual registered inline parser instances through the executable `InlineEditingFacet` protocol, not only generic capability booleans. The provider must match the existing owner contract, have a nonempty grammar identity and all required facets, and provide stable object identity. Rejection happens before the runtime registry is frozen and before constructing source/session state. Compat keeps the independent full legacy parse path for unsupported execution.
- `markit/src/core/incremental/document_editing_session.cj`: accepts an optional frozen-execution validator. Initial parsing checks it before and after work, and every existing stale/cancel/publication guard checks it again. A changing inline provider cannot publish over the accepted source or overwrite an older committed parse. The existing Task05 prepared tree/effect installation and acknowledged-source lifetime remain unchanged.
- `markit/src/core/block/block_editing_facet.cj`: ownership transferred for the bridge, but no additional change was needed in this phase. The existing `BlockRawChildrenEdit` detaches inserted bundle and `LogicalTextSplice` arrays. Its text splices already flow through raw-child transaction staging to `EditingNodePatch` and the published document snapshot. The opt-in `preservesUntouchedChildEffects` contract leaves localized revocation to the provider; default providers retain the safe existing subtree revocation. A completed `BlockEditingScope` already clears context, previous state-root and effect-scope references.

The registry's read-only `inlineParsersForEditing()` seam was implemented by its sole owner02. It returns the actual registration objects without freezing, constructing source or invoking parser/state factories. Creating the explicit editing entry point may clone this small cold registration array; batch paths do not gain this work.

The raw-child publication path preserves untouched structural records and effects. The prepared syntax transaction's actual removed/replaced record IDs control effect revocation: a same-ID replacement revokes original contributions while retaining new staged contributions; an absent ID revokes the complete owner. A path-copied ancestor is not treated as re-parsed. `LogicalTextSplice` values are carried with the actual resulting patch, not merely retained in a private DTO.

## Focused verification

`markit/src/tests/unit/task06_inline_bridge_test.cj` has exactly three concrete cases (`InlineEditing`, `Task06InlineBridge`):

1. A parser declaring all generic flags but lacking executable inline methods is rejected in Strict before parser/state factory calls, and registration remains mutable. Compat publishes complete legacy snapshots, keeps old snapshots immutable, acknowledges input before parse, and matches a fresh parse.
2. The real `Markit.createEditingSession` / `DocumentEditingSession` path applies a same-ID raw child splice, preserves both untouched sibling records and their effects, retains the new middle-child effect, and delivers a one-byte `LogicalTextSplice` in the final snapshot. The resulting content matches a fresh run of the same test block parser.
3. Replacing an actual inline facet object after source acknowledgement rejects publication without parsing or losing the new source. Restoring the original frozen object permits a retry to commit the acknowledged input.

Actual product type checks reported by owner02: new block closure `main-block-compile-2` exit0, plugin (including registry seam) exit0, incremental (including validator) exit0, top-level `main-markit-compile-1.log` exit0. These partial compilation products are not mixed with old libraries for runtime claims. The three bridge cases are SOURCE_READY and wait for the coordinator's coherent whole build and official run. No new oracle/count/benchmark framework or plugin migration is included.

An environment interruption occurred after source writes were confirmed. No new Windows action was attempted while root reported it unavailable. After recovery, the absence of the new bridge-test file and the completed grammar `returnsText` write were checked before creating this test once; no uncertain build/write was blindly replayed.
