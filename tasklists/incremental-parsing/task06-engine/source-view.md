# Task06 local inline source and literal windows

Owner: `task05_engine/source_lifecycle`. Updated: 2026-10-23.

Product scope is exclusively new `markit/src/core/inline/inline_text_view.cj`; directed tests are exclusively new `markit/src/tests/unit/task06_inline_view_test.cj`. No existing inline parser/dispatch, plugin ParagraphChildrenBuilder, source/tree implementation or shared editing contract was changed.

## Frozen public seam

`InlineTextView` exposes `source: SourceVersionIdentity`, `mappingIdentity: String`, `byteLength`, `readByte(index)`, explicit `sliceBytes(start,end)`, `runeOffsetAtByte(index)`, and `mapByte(index,affinity)`.

- Every offset and read footprint at this seam is a **view-local UTF-8 byte offset**. The provider owning a transformation projects raw source edits into its view; core does not guess marker stripping, escapes, indentation, or raw/edit coordinates from a kind/plugin name.
- `runeOffsetAtByte` rejects partial UTF-8 scalar boundaries. Raw byte access deliberately supports continuation bytes. CR and LF remain separate raw Unicode runes, including a boundary inside CRLF.
- `source` declares the view document/version domain. `mappingIdentity` is supplied explicitly for a mapped layout; it is not a hash/materialization of the whole text, and providers must change it when their mapping/layout proof changes.
- `mapByte` returns an actual birth-version anchor. It never overwrites an older raw anchor's identity with a target version. The owning editing session/provider must retain the necessary source epochs while those maps/checkpoints are reachable and use Task03 resolution to project a returned anchor into a later target.
- Providers supplying custom `InlineTextView` implementations must keep their byte contents, source declaration and mappings immutable. Mapped construction/insertion rejects new parts with a foreign document or a source epoch beyond target; map lookup additionally rejects a returned foreign/future anchor even if a custom view lies in its declaration.

`RopeInlineTextView(source,start,end,mappingIdentity:"raw")` consumes the real immutable `EditableRopeVersion`, retaining that version and delegating byte reads/small slices/coordinate queries to Task03. Construction validates only endpoints; it does not slice the text. Non-rope implementations cannot silently turn into a String adapter.

`InlineTextWindow(view,start,end)` references a subrange. A window of a window collapses to the original base and absolute local endpoints, preventing repeated local cuts from creating an ever-growing chain of wrappers. Its constructor validates scalar boundaries through coordinate queries without slicing content.

`UnmappedInlineTextView(source,view,mappingKey)` uses an explicit target document/version domain but returns None for every raw mapping. It is the explicit representation for synthetic bytes held by an immutable temporary rope/window; copying an endpoint identity is not treated as provenance.

## Persistent mapped parts

`MappedInlineTextView(parts,sourceIdentity,mappingKey)` builds an immutable balanced sequence of view references, caching byte/rune/part totals and height. It captures individual references while building, not a caller-mutable parts array. No leaf content is cloned or exported at construction. The new draft's ordinary parts parameter precedes its promoted private source/mapping fields, respecting the SDK's primary-constructor rule without retaining duplicate DTO field assignments.

Public `partCount`, `partAt`, `replacePart`, `splicingParts` and `spliceBytes` support local updates. Every update requires an explicit same-document, nondecreasing target identity and an explicit mapping identity. Only newly inserted parts are checked; unchanged older parts keep their original view and source anchors.

- Initial build is O(P) view references plus their endpoint coordinate-query cost, where P is number of parts.
- Part replace/splice copies O(log P) tree paths plus inserted parts; byte splice also creates only the two endpoint windows. It does not clone a full parts array or scan/rebase all previous parts.
- Byte/rune/map lookup descends the weighted tree, then delegates to the selected leaf. For direct rope leaves this adds O(log rope) coordinate/read work. An explicit provider stack of arbitrary nested mapped transformations still pays its actual nesting depth; no universal constant-time claim is made for custom providers.
- Boundary affinity chooses the preceding part for Before and following part for After. Synthetic interiors and their unprovable endpoints stay None. A mapped range export obtains only intersecting leaf windows; explicit full-range export remains output-sized by caller choice.
- Zero-length sequences have zero bytes/runes and no unique raw anchor. Failed scalar/provenance/range validation leaves prior immutable roots untouched.

## Bounded logical Text bridge

`PersistentInlineLiteralWindow(payload,start,end)` consumes Task04's actual `PersistentTextPayload`. `segments` and `sliceBytes` export only that selected range; `splice(inserted)` delegates to persistent bounded-leaf splice, preserving the rest of the payload. Scalar validation for payload output/splice comes from Task04's bounded leaf operations. `toLegacyNode(id,span)` is explicitly the whole logical Text export and may cost O(N); it is not invoked by local view reads or local splice. No observable Text children are introduced or split.

## Directed evidence

Seven `@Tag[InlineEditing,InlineTextViews]` cases are authored:

1. Rope windows with Chinese/emoji/CRLF raw byte and rune positions, invalid scalar rejection, nested windows and old version isolation.
2. A real 2 MiB rope middle edit. A private guard rejects any slice over 32 bytes; construction/splice perform zero slices, and a six-byte export touches only the endpoint windows. Joined anchors keep different v0/v1 births and resolve through the real source store.
3. Four parts splitting Chinese, emoji and CRLF, detached input array, exact rune summaries, partial-scalar splice rejection and empty sequences.
4. Omitted raw gaps plus a synthetic part, proving affinity-specific real anchors and None mappings.
5. 1,024 initial parts with direct unchanged-reference checks and 40 local part splices compared with a small fresh String reference; old sequence stays readable.
6. Foreign/future source parts reject at construction and insertion; dishonest foreign/future returned anchors reject on lookup; legitimate old-epoch anchors remain unchanged.
7. A 256 KiB Task04 Text payload receives a one-byte-to-Chinese local splice. Selected windows remain bounded; an explicit legacy export retains one typed TextNode, ID and metadata, and matches fresh content.

`git diff --check`: passed. Product and tests are SOURCE_READY/frozen. Official type compilation and directed execution are scheduled exclusively by `task02_contracts`, using a private partial-inline output because this file depends only on stable editing/source/nodes and does not require the main new inline facets/index. First compilation found one SDK syntax error: ordinary primary-constructor parameters must precede member parameters (`../task06-verification/inline-view-compile-1.log`). The first shared view/index type compile then found one root view inference issue for an if-expression ending in None (four diagnostics), fixed by explicitly typing it `?SourceAnchor` (`inline-core-compile-1.log`; other index diagnostics belong to the index owner). In that required safe write window, root's clarified draft-API rule was applied: the new mapped constructor became parts-first so source/mapping fields can both be promoted; all new test callers were updated and a repository call-site search found no main consumers to modify. No compatibility wrapper or extra state was added. The source was returned SOURCE_READY for immediate recompilation. No tests have yet been claimed passed for this revision; final Task06 still requires the main engine's shared integration and existing regressions.

The implementation uses the already reviewed Task03 rope and Task04 bounded text operations; no additional stdlib performance research, product counters, generalized oracle, benchmark framework or toolchain compatibility expansion was introduced. The actual SDK remains 1.3 alpha, with no claim of a 1.1 run.

The corrected view/index product closure then actually compiled with exit 0 (`../task06-verification/inline-core-compile-2.log`, products `inline-core-stage2`). Its first official combined 13-case test compile found the test-local variable `foreign` is an SDK reserved word. Only that view-test variable was renamed to `foreignView`; the source-rejection assertions remain intact. Index-test diagnostics are owned and fixed separately. The test compile failure is retained (`inline-core-tests-compile-1.log`); official execution is pending the test-only recompilation and is not inferred from the successful product build.

The second official test compile retained three SDK type diagnostics for `refEq` receiving `InlineTextView` interface values (`inline-core-tests-compile-2.log`). The three assertions now explicitly cast interface references to `Object`; both the identity checks and their expected true values remain intact. No product source changed. Tests were returned frozen for the third official compile and execution.

The third official test compile exited 0 (`../task06-verification/inline-core-tests-compile-3.log`). The official binary then actually passed all seven view cases and all six index cases: **13/13 passed, 0 skipped/error/failed, exit 0**, total 32.7153 ms (`../task06-verification/inline-core-test-1.log`). Its executable, arguments, SHA-256 and frozen source scope are recorded in `inline-core-test-1-command.json`. This proves the parts-first promoted constructor, persistent mapped views and bounded Text bridge on the current SDK; the scope excludes the main inline session/facet draft. Product and seven tests remain frozen for main-engine integration and normal project regression; this directed pass does not replace that integration gate.
