# Task06 concrete recursive owner fixture

Owner: `task05_engine/session_checkpoint`. Product engine ownership remains with owner04; this file records the concrete provider and its directed test in `markit/src/tests/unit/task06_recursive_inline.cj`.

The test-only wrapper grammar is `^body!`. Its legacy and editing entry points share one wrapper reader and delegate the body to the existing `Task06InlineGrammar` through the normal legacy/inline editing engines. The wrapper payload is the fixed semantic value `box`; it does not copy child raw text into a parent field. Its typed codec preserves that payload. The nested body view retains a stable identity, and every successful projection returns the next immutable body bounds for subsequent edits.

The original single case performs two length-changing edits inside one nested owner. It asserts no additional wrapper parser calls, one actual child parser call per edit, retained sibling raw reference/ID/birth epoch and effect, a fresh parse comparison, and an unchanged old snapshot. Owner02 compiled and ran this original revision with the official test executable: `task06-verification/inline-recursive-test-1.log`, 1/1 passed, zero skipped/error/failure, exit 0.

The current revision extends that same case with two independent wrappers reading the same absent semantic key. Missing-to-present-to-removed replay stays at source epoch zero, invokes only the two actual child readers each time, retains unrelated child references/effects and wrapper IDs, and applies both deep child splices via `following`. Fresh and old snapshots are checked. This extension is SOURCE_READY; its official result must be recorded separately from the original source-edit pass.

The bridge adds only immutable `BlockRawChildrenEdit.following` with defensive array copies. Document editing applies the first edit and its ordered descendants to the existing staged tree, emits each small logical text patch, and preserves the existing final tree/effects publication gate. Patch supersession removes older recovery-unit patches only; it retains every patch emitted by the current batch. No parser marker or plugin name is recognized by the core bridge.
