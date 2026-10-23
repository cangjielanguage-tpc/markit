# Task06 bounded text payload split/concat seam

Status: Source Ready; normal Task06 compilation/tests pending.
Owner: `/root/task04_tree`, explicit narrow handoff from `/root/task05_engine`.

Only `core/nodes/persistent_text.cj` and assertions inside two existing `PersistentTree` cases changed. `sliced(start,end)` performs persistent tree splits; `concatenated(other)` joins trees. Unchanged bounded segments remain shared; no full literal materialization is used by either operation. Existing baseState is retained. New IDs are still rejected by the existing base.copyBaseTo identity guard rather than silently dropping metadata.

Partial slicing requires rawFollowsText, since raw spelling byte offsets need not align with decoded logical text. A whole-payload no-op retains the original raw payload. Concatenation requires both rawFollowsText and identical baseState references (or both absent); merging distinct old Text metadata requires later provider/codec proof. This supports Task06's newly created plain payloads without claiming arbitrary old typed Text integration.

Assertions in the existing 512KiB case compare the complete recombined result and first/last PersistentTextSegment reference identity. The existing typed Text case checks all three metadata kinds after split/rejoin, rejects a changed ID and different metadata base, and preserves explicit raw spelling on the allowed whole-payload no-op while rejecting an unproven partial raw slice. Existing case count remains11. `git diff --check` exited0. The build owner performs the normal Task06 compilation/tests; this owner did not launch a Markit/shared-target build.
