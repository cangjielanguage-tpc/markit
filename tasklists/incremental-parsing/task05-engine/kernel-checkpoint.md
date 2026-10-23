# Task05 shared block kernel checkpoint tests

Owner: `task05_engine/source_lifecycle`. Updated: 2026-10-23.

Only the new `markit/src/tests/unit/task05_kernel_checkpoint_test.cj` is owned by this validation slice. It uses the real product `BlockParsingKernel`, real `ParseSession` checkpoint envelopes and `RestorableBlockState`, without a second dispatcher or a copied Markdown parser. The tiny test-only grammar defines a container, a leaf and a paragraph provider; its delimiter and kind choices do not appear in the product engine.

Five `@Tag[BlockEditing, KernelCheckpoint]` cases cover:

- A mutable open continuation frame plus session allocator/active line/line-index checkpoint, a speculative branch, restore and continued parsing, compared against a fresh run through the same product kernel. Re-restoring the checkpoint verifies that resumed provider state did not alias the captured state.
- `ClosedAndReprocess`: container finalization, synchronous emission sink, then the same source line's leaf parser, with exact event ordering and unconsumed-line source spans.
- Pending paragraph recovery that includes its earlier line and start span, drops a speculative blank-terminated branch, resumes to EOF, and matches fresh output/ID.
- EOF with an open continuation frame, repeated finish without duplicate emission, and paragraph EOF-with-newline termination.
- A real rope edit before an open frame where byte and rune deltas differ. The test provider maps its opaque frame span explicitly through source anchors, session active-line geometry is remapped, and the line index is rebound to current source. Continued output literal/ID/byte/rune spans match fresh kernel parsing of the new source; the captured old frame remains unchanged. This tests the explicit provider path without claiming a generic core geometry codec.

The fixture supplies a real source buffer, explicitly enables the persistent line index, and registers an explicitly checkpoint-enabled symbol store. It does not duplicate the session group's nested-exception tests, add a general oracle/count/benchmark framework, adapt built-in plugins, or claim Task05 complete.

Verification: source-ready directed test authored; `git diff --check` passed. No build/test process was started by this owner. Official compilation and execution remain scheduled by `task02_contracts` after the main kernel's stable gate.


2026-10-23 actual verification: kernel 5/5 passed in `core-test-1.log` (37/37 total, exit 0), and again against whole2 consistent dependencies in `editing-engine-test-2.log` (39/39 selected, exit 0). All compiler/test runs were owned by 02.
