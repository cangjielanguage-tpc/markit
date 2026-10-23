# Task06 persistent inline attempt index

Owner: `task05_engine/session_checkpoint`. The latest index and six focused tests passed official coordinated verification (included in core18 below). No compiler/test was run by this owner. This does not mark Task06 complete.

Owned files:

- `markit/src/core/inline/inline_attempt_index.cj`
- `markit/src/tests/unit/task06_inline_attempt_index_test.cj`

`InlineAttemptRecord` stores an independent private attempt owner, frozen parser ordinal/owner/grammar/mapping identities, evidence birth source, consumed and actually read byte intervals, success/failure, opaque left/right context, nested owner, optional successful raw node ID, positive/negative semantic-read evidence and `dependsOnLength` metadata. Mutable Array wrappers are detached on input and public export. The immutable dependency objects are shared internally when projecting a record; no symbol-state payload is cloned here.

Primary-member folding follows the actual SDK constraint reported from owner02's compilation: every regular constructor parameter must precede every member parameter. The existing `dependencies` parameter remains regular because its input Array must be cloned; its position in the frozen API is retained. Therefore the earlier record fields remain explicit fields/assignments, while the final `nodeId`/`dependsOnLength` suffix is folded. Similarly `InlineAttemptIndex` retains explicit `source`/`mappingIdentity` because its later regular `records` input must not become a redundant aliased member. Pure order-key/branch/locator constructors use member parameters. Guards or clones alone are not treated as a blanket prohibition on folding; the precise parameter-order restriction is the reason for these retained prefixes.

`InlineAttemptIndex(source,mappingIdentity,records:[])` holds five immutable AVL roots: an interval-augmented attempt tree and owner/semantic-key/nested-owner/length-reader locator trees. Stable fractional order keys preserve byte-start/parser-ordinal/attempt-owner ordering. They do not encode current byte positions; suffix edits leave all locator keys intact. `byOwner` follows the locator and accumulates lazy position deltas on the attempt path. `readingKey` includes both found and missing reads and returns only actual readers. `nestedAttempts` selects the requested nested owner. `lengthReaders` selects only attempts which actually observed view-length metadata; it does not invent a whole-body character read. `query`/`intersecting` use closed read footprints, deliberately waking failed EOF reads and either side of a zero-width insertion. Queries preserve all same-position provider attempts in frozen ordinal order. Key-reader results are in owner order, not parser priority order.

`splice(windowStart,oldEnd,newEnd,replacements,target)` validates the same document and an advancing version, removes all reads intersecting/touching the old window (including openers outside that window), then splits and lazily shifts the wholly unaffected suffix. A nonzero byte-length delta also removes actual `lengthReaders`; a same-length edit does not wake those metadata readers merely because the source epoch changed. The caller must retry those affected records; deleting old evidence is not itself a parser retry. Replacement attempts may start outside the edit when a distant failed read is retried, but must carry actual target-version evidence and the stable mapping identity. All work is unpublished until a new index object is returned, so a duplicate/version/mapping refusal preserves the previous snapshot and secondary indexes. Initial construction may process N records once; hot edits visit affected records/tree paths and do not enumerate/copy the surviving suffix, full map or full Array. `records()` is an explicit linear export.

`replacingOwners(ownerIds,replacements)` supports semantic-only retries in the same source epoch. It locates only explicit owner IDs, removes their old positive/negative and length/nested evidence, and inserts actual current-epoch replacements without shifting geometry. Reusing an existing private owner requires its parser ordinal/owner/grammar/mapping/nested schema to remain identical. Cross-document, stale replacement and duplicate-owner refusals preserve the original roots. Actual parser instance identity remains the main engine's frozen-registry responsibility; the index does not infer it from a plugin name.

Fractional order keys use private immutable Int64 digit sequences. Tree work is logarithmic in record count, multiplied by compared key depth; repeated insertions into one densely occupied gap can lengthen that gap's keys. There is no global relabel or old-version walk. This depth cost is explicit rather than described as constant-time. The index itself contains no Markdown delimiter, plugin-name or node-kind boundary logic.

Focused test coverage (tags `InlineEditing`, `InlineReadDependencies`):

1. Missing closer read to a distant boundary, negative key evidence, zero-width closer insertion, outside-opener retry and newly created candidate.
2. Three same-start attempts from two frozen parser ordinals and both read boundaries.
3. Two lazy suffix shifts with owner, semantic and nested locators; old snapshots, context and array ownership retained. Length metadata selects only its real observer; length-changing edits revoke it. Same-epoch semantic retries update read and length locators without a coordinate shift and retain prior snapshots.
4. 128 attempts across 60 local branches, prior snapshot and every locator retained; explicit ordered export.
5. Stale/cross-document/mapping/duplicate replacement and same-owner parser-schema refusals preserve all old indexes.
6. Real `EditableRopeStore` Unicode-rune edits, CRLF, source anchors and projected UTF-8 byte offsets agree across two edits.

## Read-only stdlib observations

- `libs/std/collection/array_list.cj:194` implements `toArray()` by allocating and copying its live prefix; `add` grows amortized storage. Used only for selected query results, explicit export and newly allocated fractional keys, never for an unchanged full attempt set during splice.
- `libs/std/core/array.cj:273` implements `clone()` by allocating and copying all elements. It is used for the small per-attempt dependency input/public getter, not for the index or suffix. Internal coordinate projection shares the private immutable dependency backing.
- `libs/std/core/string.cj:27/1057` provides String Comparable and byte comparison; the secondary AVL compares semantic-key strings, with no conversion or full dictionary clone.

The inspected files are in `C:/Users/Shawn/Desktop/cangjie_runtime/stdlib`; they were not modified. No SDK 1.1 compatibility claim is made. Actual SDK/build/test evidence remains with owner02's normal coordinated verification.

## Actual verification history

Owner02's first coordinated inline-core compilation exited 1 (`task06-verification/inline-core-compile-1.log`). Four index diagnostics were actual SDK initialization rules: a locator aggregate field initializer could not read uninitialized primary-member fields, and the public index constructor could not invoke an instance validation method before all its immutable roots were initialized. The locator now computes height in its constructor body from the already available parameters; record validation is a file-private pure helper taking mapping identity explicitly. No interval, shift, dependency or threshold algorithm changed. The initial failure evidence is retained; the corrected product is SOURCE_READY for the next compile and six-test official run, not yet described as passed.

Subsequent actual product compilation succeeded (`inline-core-compile-2.log`, exit0). The official tests initially rejected the test variable `foreign` as a reserved keyword; only that variable and its reference were renamed to `foreignRecord`, retaining every rejection assertion. The V2 metadata/same-epoch implementation then passed all six index and seven view cases (13/13, no skip/error/fail, `inline-core-test-1.log`, exit0).

The open-boundary fractional-key allocation was then corrected: sequential append uses available integer space instead of repeatedly halving the open right boundary, keeping ordinary initial sorted records at one digit rather than increasing depth every approximately 60 records. Prepend uses available first-digit integer space as well; exhausted boundary space falls back to the original strict-between algorithm, and internal dense-gap behavior remains unchanged. The prior13 result is historical. The final open-boundary implementation was included in `task06-verification/inline-core-test-2.log`: **18/18 PASSED, 0 SKIPPED/ERROR/FAILED, TASK06_INLINE_CORE_TEST2_EXIT=0**, including index6, view7 and the existing value cases. Main inline/session/bridge integration has separate verification and is not implied by this result.
