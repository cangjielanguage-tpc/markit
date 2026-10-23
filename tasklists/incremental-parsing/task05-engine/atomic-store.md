# Task05 atomic stores / structural splice

Status: Done for Task05 storage supplement; root accepted whole3/full692 and the main same-O2 evidence. Later constructor-only source changes are tracked separately for Task06 normal compilation coverage.
Owner: `/root/task04_tree`, explicit handoff from `/root/task05_engine` after Task04 acceptance.

## Owned files

- `markit/src/core/nodes/persistent_node.cj`
- `markit/src/core/document/persistent_document.cj`
- `markit/src/core/session/owned_effect_store.cj`
- `markit/src/tests/unit/task05_atomic_store_test.cj` (9 `Task05AtomicStores` cases)

No editing contracts, source rope, parser/renderer, main engine, README, shared verification log or Task04 accepted evidence was changed by this supplement.

## Atomic candidate protocol

Tree:

- `PersistentDocumentStore.beginPreparedTransaction(expectedVersion)` returns concrete `PersistentDocumentTransaction`.
- `tx.prepare(sourceVersion)` builds an independent `PersistentDocumentVersion`, without publishing it.
- `tx.validatePrepared(candidate)` checks active transaction, exact candidate identity, and original store root.
- `tx.installPrepared(candidate)` installs without any provider/callback/rejection work. Engine must validate *all* participants immediately beforehand, inside its single-thread publication gate.
- Existing `commit` uses the same prepare/validate/install path.

Effects:

- `OwnedEffectsTransaction.prepare()` returns `PreparedOwnedEffects`; `.snapshot` is immutable and `.invalidatedOwners()` previews positive/missing reader invalidations.
- Provider payload cloning and stale rechecks happen before returning prepared state. Only touched-key lists clone.
- Further transaction changes invalidate the prepared handle; `prepare()` may run again for semantic replay. Older prepared snapshots remain independent, while `validatePrepared(old)` returns false.
- Snapshots now use a persistent AVL key index. Preparing t changed keys updates those paths; it does not copy all semantic keys. Explicit old/current snapshots hold only a root pointer.
- Contribution tokens are transaction-local. Cancel/probe rollback/provider preparation failure never changes the store token clock. Only successful install advances it.
- Engine prechecks tree and effects candidates together, performs both provider-free installs, then publishes one combined tree/effects/patch snapshot root. There must be no callback between validations and installs. Ordinary allocation failure is not recoverable application-level provider rejection.

## Probe / nested rollback

`tx.beginScope(): OwnedEffectsScope` and `scope.complete(commit: Bool)` support nested scopes in reverse closing order.

The scope journal copies before-images only for touched transaction-local key lists, records local revoked flags and reversible read-list mutations, and saves the local token cursor. No full live semantic map clone occurs. A committed nested frame merges its undo state into its parent; a rolled-back frame restores writes, reads, revocations and local tokens. Closed frames clear captured references. Preparing with an open scope is rejected.

## Structural children splice

- `RawSyntaxNode.splicingChildren(start, deleteCount, inserted, version, resolver)` keeps a persistent AVL child sequence.
- `PersistentDocumentVersion.splicingChildren(parentId, start, deleteCount, inserted, targetVersion)` removes only deleted subtrees, inserts only new subtrees, and updates the parent/ancestor paths in the persistent ID index.
- `PersistentDocumentTransaction.spliceChildren` stages that operation.
- Existing siblings have immutable fractional lexicographic order keys. A persistent child-ID→order-key index plus sequence rank lookup finds a sibling after insertion/deletion without renumbering the suffix. The old cached `childIndex` field is no longer used for ancestor-path replacement.
- Splice key/rank work is O(D log siblingCount) plus inserted/deleted records and their persistent ID-index updates, where D is the fractional key digit length. Repeated dense insertions can lengthen keys, but never trigger a whole sibling renumber/reindex pass.
- Payload/metadata and unchanged raw nodes are shared; constructor/getter array ownership remains isolated.

## Earliest anchor floor / explicit legacy export

`RawSyntaxNode.earliestAnchorVersion` is an O(1) cached minimum of its own anchors and children summaries. `PersistentDocumentVersion.earliestAnchorVersion` reads the version ID index's cached minimum, including auxiliary records. Ancestors created on replacement/splice map their own anchors to the target source version; old untouched children retain their original birth anchors. Thus the floor can advance after the last older anchor disappears.

The explicit legacy Document export reads raw text and whole-document source span from that snapshot's retained immutable `EditableSourceVersion`, not a prototype's mutable append buffer or the latest live source. This full-source slice occurs only in explicit legacy materialization; prepare/commit/splice never slices the whole document.

## Verification pending

Nine direct tests cover clone failure before publication and token isolation; immutable/reprepared effect candidates and positive/negative invalidation; provider-free install; stale participant precheck; nested probe rollback; structural insert/delete plus editing a shifted suffix; earliest floor including auxiliaries; dense sibling insertion balance; immutable-source legacy Document export.

`git diff --check`: exit0 (existing unrelated CRLF warning is preserved). Product/test source frozen and handed to `/root/task02_contracts` single-writer scheduling; no `cjpm` was started by this owner. Actual compile/test outcomes must be appended after execution; no pass claim yet.

## Stdlib boundary

Read-only source/notes consulted: `stdlib-performance-notes.md`, ArrayList remove implementation under `C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj`. Removing in the middle moves a suffix; journals therefore operate only on transaction-local observed reads, never a full published semantic table. Persistent indexes replace whole-table cloning; public digit/child arrays do not leak shared mutable backing. Installed SDK is 1.3-alpha; the source tree's 1.2-beta manifest is not proven to match it. No SDK1.1 compatibility or expanded framework work was added.
## Initial actual compilation / review

- `/root/task_a_review` read the frozen three product files and nine direct tests: zero confirmed defects in the reviewed prepared-publication, stable-key splice/rank and floor paths. This is static review, not execution.
- Full session-package isolated compile first attempt exited 1. `owned_effect_store.cj` had three ambiguous bare `None` uses because the full package also sees `SourceRetentionMode.None`; changed only those to explicit `Option<EffectSnapshotIndex>.None` / `Option<ArrayList<EffectCandidate>>.None`. Other four diagnostics belong to the session owner. Original seven-error log is retained at `../task05-verification/session-package-compile-1.log`.
- Repaired source handed back SOURCE_READY. Actual final compilation/tests are still pending.

- Complete session-package second isolated compile: exit0; the new effects candidate/snapshot/scope implementation passed type checking together with the full session package.
- First isolated nodes-package compile: exit1, one return-type diagnostic at `ChildOrderKey.between`: this compiler does not infer that `while(true)` with internal returns never reaches the function end. Added an explicit trailing throw only; the fractional key algorithm and all assertions are unchanged. Original log retained in `../task05-verification/nodes-package-compile-1.log`. Repaired nodes source returned SOURCE_READY; document and direct tests remain pending.

- Isolated nodes package (after explicit-tail fix) and document package compiled exit0. The first combined session/atomic test compilation failed only in the session owner's test capture syntax; no atomic test diagnostic was reported in that attempt.
- Read-only review confirmed one auxiliary-child uniqueness defect in the existing importer: the same raw child placed structurally under two different auxiliary parents was accepted by the same-reference shortcut. The minimal fix permits that shortcut only for an auxiliary root back-reference (`parentId=None`); recursive structural children with an existing ID reject. Additional payload reference IDs remain supported. The existing structural test now asserts rejection for auxiliary parents10/20 sharing child30. Nodes/session products were unchanged; repaired document/test returned SOURCE_READY for recompilation. Nine atomic cases remain nine.

## Auxiliary bundle supplement (new source frozen, execution pending)

Reconnection verification confirmed the reference payload/cache patch was present in `persistent_node.cj`, while the interrupted document helper patch was absent. Only missing work was reapplied. The following new source was handed SOURCE_READY to the single-writer build owner; its compilation and direct tests are still pending.

- `SyntaxReferencePayload` supplies opaque outgoing IDs. Raw nodes cache a private copy, so edge bookkeeping does not invoke provider payload cloning.
- `PersistentNodeBundle.auxiliaryOwnerIds()` records the structural unit that first introduced an auxiliary closure. Nested auxiliary references inherit that owner. `PersistentDocumentVersion.auxiliaryOwnerId` and `ownsAuxiliaryReference` expose this distinction without plugin names.
- `PersistentNodeCapture.capture(..., existing: Some(version))` re-encodes same-ID auxiliary fields owned by the current structural unit/subtree; structural references and auxiliary references owned by other units borrow existing immutable records. A blanket existing-ID skip is not used.
- Pure `replacingBundle` / `splicingBundles`, and transaction `replaceBundle` / `spliceBundles`, carry auxiliary records through local edits. Initial ingestion builds incoming edge counts once; edits apply outgoing-edge deltas for removed/new records. Only auxiliary closures reached by changed negative edges/new auxiliary records are traced. Outside incoming edges root live nodes; internal cycles without an outside entrance are collected. Shared references stay live. No complete graph scan occurs on an ordinary local edit.
- A removed structural node with a surviving external incoming reference is explicitly rejected before publication. Duplicate structural children remain rejected. Updated embedded auxiliary children refresh only their parent paths so raw children and ID lookup agree.
- `tx.removedNodeIds()` includes old replaced IDs and collected auxiliary IDs. Engine can revoke original contributions for a still-present same-ID owner while revoking all contributions for a truly removed owner.
- `OwnedEffectsTransaction.revokeOriginalOwner(owner)` removes only pre-transaction contributions and published read dependencies, preserving new contributions/observed reads from this transaction. Scope journals still restore only touched state.
- `PreparedOwnedEffects.invalidatedKeysForOwner(owner)` reports changed positive/missing dependency keys using the existing affected-owner/key indexes. It does not scan all owners or invoke provider callbacks.

New effects APIs passed the complete session-package isolated compile (session5, exit0). The build owner also reported 23/23 source-retention/session direct tests passing; these do not replace the pending nine atomic-store cases. Atomic cases now include exact invalidated-key assertions and same-owner original-only revocation preserving a new write/read. Separate real-rope/custom-typed auxiliary graph tests are owned by `/root/task05_engine/session_checkpoint`.

The new nodes/document isolated builds both exited0 (`nodes-package-compile-3.log`, `document-package-compile-3.log`). A subsequent one-line self-review correction removes pure auxiliary ancestor path copies from `removedNodeIds`: their payload was not reparsed, so their original semantic contributions must stay live, matching structural ancestor handling. Actual replaced/collected auxiliary IDs remain recorded. Only document source changed; document4 recompilation and direct tests are pending.

## Actual direct verification after auxiliary integration

- `nodes-package-compile-3.log`: exit0; `document-package-compile-4.log`: exit0, including the one-line ancestor-cleanup correction.
- `core-tests-compile-2.log`: official targeted binary compiled exit0. `core-test-1.log`: 37/37 passed, 0 skipped/error/failed, test exit0. This includes all nine `Task05AtomicStores` cases and the new exact invalidated-key/original-only revocation assertions.
- The previous first core-test compilation's two interface `refEq` test diagnostics belonged to the session checkpoint owner and were corrected with concrete referenced objects. Its failed log remains historical evidence.
- Auxiliary typed graph four-case run and first complete project integration remain pending at this update. Source is frozen until the build owner releases the next edit window. Root requested safe primary-constructor style unification in the same three product files as a subsequent normal integration change; no separate benchmark/test framework is being introduced.

- Auxiliary graph official targeted binary compiled exit0 (`aux-tests-compile-1.log`) and ran 4/4 passed, 0 skipped/error/failed, exit0 (`aux-test-1.log`). These are real EditableRopeStore + custom TypedNodeCodec cases: owned same-ID fields/new aliases/global borrowed structural identity; local splice with semantic retirement and floor advancement; shared auxiliary child retention plus the path-copy ancestor effect-preservation branch; self/mutual auxiliary cycles reclaimed after the last external entrance disappears. Old snapshots and detached typed-export isolation are asserted. First complete project integration is still pending.

## Primary constructor style handoff (source not changed yet)

The next normal integration edit can convert 17 single-constructor types in the same three owned files, preserving explicit field assignments, provider clone calls, array-copy ownership, defaults, visibility, and mutable state. Same-name primary-constructor syntax is present in the read-only stdlib (`libs/std/deriving/impl/parse_utils.cj:78`, `parseDerive.cj:111`, `libs/std/core/string_common.cj:266`). Main/build owners coordinate one syntax check, rather than each owner building a probe.

Three types require checking actual secondary-constructor rules before conversion:

- `RawChildSequence`: leaf and two branch constructors initialize disjoint read-only representations; mapped branches additionally project only path summaries. Converting by routing through a leaf would initialize the wrong representation; routing through a new common constructor must preserve projection/ordering and avoid new allocations.
- `RawSyntaxNode`: public ingestion clones provider payload/references and builds child keys; private path-copy constructor deliberately shares already-private immutable payload, keys and reference arrays. Unifying these through the public ingestion path would add clone/provider calls and sibling rebuilds to ordinary edits.
- `PersistentDocumentVersion`: initial ingestion validates/builds the whole ID/reference index once; private fork constructor retains an already-prepared persistent index and captures the current immutable source view only when its epoch matches. Delegation must preserve that distinction, source lifetime, and the initial graph validation order.

These are preliminary semantic constraints, not a blanket refusal based on overload count. Existing overloads remain unchanged until the shared syntax result and next safe normal recompile window establish an equivalent conversion. Root owns the concise repository-wide coverage record; this supplement adds no separate style acceptance framework.

First whole-project integration compile succeeded (`../task05-verification/integrated-compile-1.log`, `TASK05_WHOLE_COMPILE_EXIT=0`). This includes the complete new storage/aux bundle APIs and engine linkage. Whole-project runtime regression is still pending at this update; storage primary-constructor changes have not started.

## Whole1 runtime finding and frozen raw provenance repair

Whole1 compiled successfully, then the main engine's existing fresh-result assertions found two ancestor raw spelling mismatches. The container's typed literal was unchanged by design; Node.toString reads rawContent, and copied ancestors reused the original captured raw override. No ancestor payload-refresh protocol was added.

The second whole build includes the following frozen repair (new runtime results pending):

- `TypedNodeCodec.rawContentFollowsSource(node)` defaults false. A provider must explicitly prove its virtual getter follows the source. NodeCodec also requires no original explicit raw override and SourceBuffer.isBoundTo(the exact document/version identity). Unrelated append buffers, unknown virtual getters, and synthetic/mapped bindings keep frozen spelling.
- `TypedSyntaxPayload.sourceDerivedRaw` preserves that proof separately from the internal captured override. Capture still freezes raw spelling for stable public materializeShallow behavior, including after a mutable parser buffer rebinds. Capture handles initial/new/changed units; ancestor path copying does not recapture or concatenate ancestor text on each edit.
- Explicit version materializeLegacy refreshes proven source-derived raw from that version's retained immutable source view and resolved span. Missing views preserve frozen spelling. Document raw uses the same guard; its existing whole-source span normalization remains independent. Explicit Document overrides remain intact.
- Atomic legacy export case retains the unrelated append-buffer fixture as a frozen fallback branch, adds a real editable-bound branch retaining the ab/cab old/new assertions, an explicit Document raw override, and parser-buffer rebind followed by old snapshot/public shallow raw assertions. The original nine-case count is unchanged.

Node.cj and node_codec.cj were explicitly transferred to this owner for this minimal repair. SourceBuffer helper and the main/prepare test codec opt-ins were written by their respective owners. The new files are frozen in whole2; old atomic9/aux4 passes are historical and do not by themselves verify this repair.

During the same normal repair window, 18 single constructors in the three storage files were converted by same-name rename only (the preliminary count17 omitted EffectScopeFrame). One constructor in each RawChildSequence, RawSyntaxNode and PersistentDocumentVersion was also named primary; remaining secondary constructors retain their original independent bodies. Whole1 had already demonstrated primary/secondary coexistence in I18nPostProcessor, so no signature consolidation, delegation, clone-path merging or new allocations were introduced. The earlier preliminary retention reasons are now resolved by preserving all initialization bodies verbatim. Whole2 will validate these style changes normally.

Whole2 normal compilation succeeded: `integrated-compile-2.log` ends with `cjpm test success` and `TASK05_WHOLE2_COMPILE_EXIT=0`. The new raw-provenance APIs, immutable snapshot export guard, updated atomic assertions, and all primary/secondary constructor changes in this supplement passed real project compilation. New runtime results are still pending at this update.

Whole2 BlockEditing official targeted run passed39 selected cases, 98 other tags skipped, 0 error/failure, exit0 (`editing-engine-test-2.log`). This includes the main nested fresh comparisons that previously found ancestor raw spelling stale. This tag does not include Task05AtomicStores/Task05AuxGraph; their new-binary reruns and the complete all-package regression remain pending at this update.

Whole2's complete unit binary ran137/137 passed, including the new atomic9 and auxiliary4 cases (`task01-baseline/task05-full-console-1/markit.tests.unit.log`). The27-package regression reported691 passed and one legacy anchor failure: nestedParagraphs emitted additional blockquote span attributes20..27. Main is investigating the kernel/session path; this is not represented as an all-package pass. New storage/provenance cases passed on the actual whole2 binary. Source remains frozen for the coordinated remaining legacy correction.

Root accepted Task05 after whole3, the corrected complete regression and main same-O2 evidence. Actual `task01-baseline/task05-full-console-2/summary.json` records27/27 package exit0,692 passed,0 skipped/error/failed; the previous single legacy anchor failure was corrected by the session/main owner. This closes this Task05 storage supplement. The later Node/Document/Text/DocumentSnapshot/HtmlConfig constructor-header-only batch is recorded separately in `../primary-constructors-core.md` and will be covered by Task06 normal compilation, without rewriting accepted Task05 evidence.
