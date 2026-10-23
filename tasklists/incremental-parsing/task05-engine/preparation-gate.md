# Task05 preparation callback gate tests

Owner: `task05_engine/source_lifecycle`. Updated: 2026-10-23.

Three directed cases in `markit/src/tests/unit/task05_engine_prepare_test.cj` construct the real public `DocumentEditingSession` with a rope-backed `ParseSession`, checkpoint-enabled state store, empty block kernel/provider registry, and a DocumentNode-only typed codec. A custom restorable state arms its snapshot callback only after construction and after source v1 is accepted.

The callback separately attempts a reentrant flush, throws, or cancels computation. Assertions require busy rejection without recursion; busy cleanup allowing retry/close after a throw; source v1 text `ab` preserved while parse remains v0; and cancellation of the epoch captured before checkpoint preparation preventing publication. The empty grammar intentionally cannot recover a dirty unit; retry assertions concern gate cleanup, not a fabricated successful parse.

No product or shared fixture was changed. `git diff --check`: passed. Official compilation and execution are scheduled by 02 after the main engine source-ready gate; not yet run by this owner.


2026-10-23 actual verification: official whole2 compile exit 0; all 3 preparation gate cases passed in `task05-verification/editing-engine-test-2.log` (selected BlockEditing 39/39, exit 0). No independent compiler was started by this owner.
