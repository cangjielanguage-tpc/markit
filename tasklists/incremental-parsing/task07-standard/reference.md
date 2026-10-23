# Task07-P ReferenceLink

Status: implementation in progress. Owner02's actual Reference package `reference-compile-6` passed with exit0 (3.714s), using Ready8 source and matching stage4 session dependencies. The new effects revision also passed its session package type compilation. Directed runtime tests remain pending; neither type result is a test-pass claim.

Owned production files are `markit/src/plugins/standard/inline/reference_link/*.cj`. Directed tests are `markit/src/tests/unit/task07_reference_editing_test.cj`, tag `Task07ReferenceEditing`. Root additionally assigned `markit/src/core/session/owned_effect_store.cj` exclusively for the necessary generic ordered-key operation. Other core/bundle/plugin files are not edited by this owner.

## Implemented behavior

- `matchReferenceSyntax` is the one reader-based full/collapsed/shortcut/image matcher used by both legacy and editing parsers. It retains `refLabel`, `refForm`, `refRaw`, `refText` and image provenance. Rune consumption counts the actual spelling; collapsed Chinese labels are not counted twice. This is an explicit span correction to the previous baseline.
- Editing attempts observe actual byte/EOF/backslash and positive/negative definition-key reads. Missing link shortcuts remain failed attempts, preserving the existing `[**a**]` inner grammar. Missing full/collapsed/image candidates produce typed `TextNode` views with provenance; resolved candidates produce actual `LinkNode`/`ImageNode` instances. No successful resolution removes `refLabel`.
- Definition nodes retain their own typed label/url/title and block recovery evidence. Editing contributes owner-keyed `LinkDefinition` payloads to `OwnedEffectStore`; it does not populate or copy the whole legacy registry for each edit. The registry retains legacy ordered candidates and can remove a candidate to expose the next winner.
- Legacy finalize visits only the registry's indexed reference nodes. It no longer walks every document subtree or destroys the only label fact. Definition emission remains hidden.
- `registerReferenceEditingCodecs(codec)` covers the actual definition, Link and Image node types. Base/Text codecs are supplied by the containing Standard adapter plan.

## Ordered-key seam

`OwnedEffectsTransaction.reorderKey(key, order)` projects only the affected key's candidates into current source order. It preserves contribution tokens, owners and revocation identity. It stages every callback result before journalling a replacement list, rejects transaction reentry from callbacks, and retains immutable published snapshot roots. An unchanged winning token does not create a reader invalidation.

`LinkDefinition` accepts an optional immutable source anchor without breaking its existing url/title constructor. A definition edit resolves only the same label's candidate anchors before adding the new contribution. Initial parsing skips rebasing because all candidates already share the current source epoch. This prevents a large insertion before reused suffix definitions from comparing a new current offset against their stale birth offsets.

`OwnedEffectsTransaction.refreshOwner(ownerId, replacedReadKeys)` is the explicit partial semantic refresh operation consumed by the core gate only for opted-in providers. It revokes the owner's contributions and replaces only the declared read keys, preserving unrelated published and transaction-local reads. Repeated refreshes accumulate the replaced keys; a prior full revocation remains full. Its prepared payload and scope journal retain that policy. The private reverse read index uses keyed membership so removing selected edges does not enumerate the owner's unrelated keys. Full `revokeOwner` and replay retain their existing safety defaults.

## Focused evidence, pending execution

The five directed cases cover candidate deletion/restore; real `InlineEditingSession` full/collapsed/shortcut/image positive and negative key replay; cancelled staged effects and immutable old trees; real legacy renderer plus Unicode collapsed spans; and a real definition parser/facet case with a 256-byte prefix insertion, fresh Markit winner comparison, winner deletion/takeover, old snapshots and retained reader token facts. Compilation and execution belong exclusively to owner02. These cases are not marked Passed before its logs arrive. The package typecheck evidence is `task07-core/reference-compile-6.log`, with its recorded arguments/input hashes; the initial four `None` inference diagnostics were fixed only by explicit checkpoint Option types, without changing grammar or assertions.

The containing Paragraph owner is responsible for the actual `DocumentEditingSession` vertical case: forward references on initial publication, definition-only edits with actual-key inline replay, unchanged paragraph syntax count, typed fresh equality, old snapshots and cancellation. The shared semantic result API is owned by02; this adapter does not modify its gate.

## Selected standard-library inspection

Only the user-provided read-only `C:/Users/Shawn/Desktop/cangjie_runtime/stdlib` source was inspected. `String` byte size is stored metadata; range slicing checks UTF-8 scalar boundaries then calls `sliceUnchecked`; `runes()` constructs an iterator, while `toArray()` allocates and copies bytes. `StringBuilder.append(String)` copies the appended byte range; `toString()` constructs a String from the populated range. `ArrayList.toArray()` allocates and copies its populated entries and `clone()` constructs a new list. `HashMap.get()` hashes the key and follows that bucket's collision chain.

Accordingly, editing uses observed reader windows and slices only matched reference spelling/label; it does not convert the whole containing paragraph to an array or String. ASCII-lowercase labels return their existing String without a builder allocation. These are source-level findings, not a claim that the supplied manifest and actual 1.3-alpha SDK binaries are identical. No standard-library files were modified and no general benchmark framework was added.

## Remaining integration work

Configured nested labels now call the real child `InlineEditingSession.parseInitial`, retain its raw bundle and nested snapshot, and pass the immutable enclosing semantic owner so invalidation returns to the Paragraph provider. `StandardInlineChildConsumer` allows the configured Standard plan to bind actual registered parser instances. `ReferenceLinkPlugin()` remains available; its additional positional constructor accepts those actual Reference/Image parser instances. Configuration is single-use and changes the parser grammar version so an engine cannot silently change its child grammar after capture.

Label source edits retry their actual parent reference because the public immutable `LinkNode.content` also changes. Semantic-only child replay retains the parent and uses the child snapshot. External source rebasing proves the physical endpoints, label length and bracket boundaries. Normalized quote spelling comes only from the shared provider's scoped `StandardRawSpellingProof`; ordinary CRLF and normalized mapped LF are not guessed from equal lengths or the observed-view wrapper.

Definition entry capture consumes the shared `standardLeafSessionCheckpoint` helper, which clears pending paragraph state only inside a sandbox before freezing the leaf boundary. Its runtime behavior remains pending the containing vertical test. The five tests now also include nested image key replay, `r / s / r` raw-reference retention, `r → s → remove r` dependency retention, scope rollback for partial refresh, and ordered `childrenEdit.following` consumption. The containing core owner is fixing disjoint actual-reader replay; these assertions must not be weakened to accept a contiguous whole-owner rebuild.

The bounded independent core review found that a callback could invoke `installPrepared` with a previously prepared object and publish effects during order projection. The fix guards `installPrepared` before any store mutation. The existing cancellation test now includes that exact prepare/reorder/install sequence and checks rejection, unchanged published version/winner, and safe cancellation. Independent review statically confirmed the guard on core SHA `FD4ED173336520CB2CE8B4C0E29287783E53BA8F5D684105D1D641D6A7993EC8`; runtime execution is still pending.
