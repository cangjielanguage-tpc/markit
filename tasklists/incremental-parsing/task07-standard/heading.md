# Task07-P Heading adapter

Status: SOURCE_READY for the first directed compile; not verified or Done.

Owner: task04_tree/standard_heading. The existing dirty Heading files were preserved. This owner changes only `markit/src/plugins/standard/block/heading/**`, the new `task07_heading_editing_test.cj`, and this record. Core, bundles, shared editing helpers, official compiler/test execution, README and verification-log remain with their assigned owners.

## Implemented source

- `matchAtxHeading` is the single ATX grammar matcher used by the existing `HeadingBlockParser`; it retains the existing empty-title, indentation, whitespace and optional closable suffix behavior.
- `HeadingSessionState` has a complete restorable payload for ordered slug counts, six numbering counters, hidden section level and configuration identity. Editing state additionally shares an immutable heading index and captures bounded pending changes/deferred mapped parse depth. Numbering configuration getters return detached arrays.
- `EditingHeadingNode` carries the shared `StandardBlockRecovery` without enlarging legacy Heading nodes. `registerHeadingEditingCodecs(codec)` registers only the real Heading types and preserves their constructor fields, base metadata, source/raw bindings and recovery evidence.
- `HeadingEditingFacet` recovers physical single-line grammar windows through the real registered kernel. Changed headings use an explicit child splice; other affected headings use `BlockPayloadUpdate` and preserve their existing children, anchors and IDs. Syntax equivalence excludes slug, number and visibility.
- The immutable `HeadingOrderedIndex` uses AVL heading order, AVL exact slug-key buckets and a persistent owner-ID index. A rename visits only its old/new slug buckets; numbering and hidden state propagate over heading successors until their continuation state converges. No body nodes are stored, reparsed or cloned. `visibleAt` is an immutable render-time predecessor query.
- Owned `HeadingContribution` payloads use per-owner keys and physical source anchors. Editing emission/batch hooks keep closable headings and hidden body syntax. Heading renderers honor the editing subtype's visibility field; this internal field does not add metadata to legacy JSON output.
- Mapped-container exports: `parseMappedHeadingContributions`, `rebaseHeadingContributions`, `revokeHeadingContributions`, `takeHeadingPayloadUpdates`, and `restoreHeadingAwareSession`. Containers defer synthetic-offset contributions, map only newly parsed child nodes back to physical spans, and then contribute. Heading recovery delegates mapped ancestors through the shared provider carrier.

## Directed verification request

The new test file has seven cases tagged `HeadingEditing` and `StandardEditing`: real strict Markit Heading editing with unique-to-duplicate rename and touch-start duplicate insertion, fresh HTML comparison and unchanged tail Text sharing; matcher Unicode byte offsets/legacy grammar; complete state restoration and config rejection; typed codec fidelity; ordered slug rename/revocation and old index stability; numbering/visibility convergence; and owned contribution revocation with an older effect snapshot.

No compiler or official test binary was run by this owner. Task02 is the sole build/test scheduler. The above is source intent, not a Passed result. Exact compile errors and directed results must be attached to the source hashes reported to Task02.

Task02's first Heading compile (compile5) exited 1 with two parser errors in the owner-index helper's default `bit` parameters. The minimum repair marks them as named defaults and labels their recursive calls. The algorithm and seven assertions are unchanged; the repaired revision awaits the next actual compile.

Task02's compile6 exited 1 with four errors: the private alternate index constructor needed secondary `init` syntax (and produced one cascading extra-argument diagnostic), while the parser's saved session and syntax checkpoints needed explicit Option types. The minimum repair changes only those declarations. Directed tests have not run.

Task02's compile7 compiled the complete Heading package successfully: exit 0 in 6.394 seconds, with log/arguments/input hashes under `task07-core/heading-compile-7.*`. This result covers SOURCE_READY-5, including `heading_ordered_index.cj` SHA256 `609A9AEE7EDFE6FD050DC6CD662B15CF37F4F8CC5F03E4B14CEC2320167DEB68` and `heading_block_parser.cj` SHA256 `ED7CAA8BE9351BA0CB64EDA56C78AB50BDDCFBEE6AA0B2374BB40D317E266761`. The seven directed runtime tests, fresh comparison and hidden body renderer integration remain pending; type compilation is not product acceptance.

## Remaining integration boundary

Hidden body syntax is retained, and the index provides immutable visibility queries. A dedicated semantic owner now publishes exactly one `HeadingIndexPayload` candidate under `standard.heading.index`; `headingIndexFor(snapshot.effects)` returns the index for that exact snapshot. The owner ID is captured by the full state codec, survives syntax-only recovery, and joins rollback with the index. Each update replays the single candidate, including an empty index after deleting the last heading, without taking Document owner 0 or accumulating candidates. The real Markit test checks both stable effect ownership and an unchanged older effect snapshot. This addition awaits the next type compile and runtime tests.

The ordinary body renderer still needs to consume that immutable snapshot index; a mutable session-state closure is deliberately not used. Quote/List owners must call the mapped hooks and carry their returned payload updates through the shared commit gate. Full 07-P acceptance remains pending those integrations and actual directed execution.

## Selected standard-library inspection

Read-only source: `C:/Users/Shawn/Desktop/cangjie_runtime/stdlib`.

- `libs/std/core/string.cj`: `clone` (238-241) allocates and copies all bytes; `hashCode` (249-250) calls wyhash over the string; range slicing (1202-1234) validates scalar boundaries and delegates to `sliceUnchecked`. This source inspection is not a binary SDK equivalence claim.
- `libs/std/core/string_builder.cj`: `toString` (116-117) constructs a String from the written data range.
- `libs/std/collection/array_list.cj`: `toArray` (194-201) allocates and copies the logical elements; `clone` (894-895) calls the collection constructor.
- `libs/std/collection/hash_map.cj`: `get` (480 onward) hashes the key and traverses its bucket chain; `contains` (777 onward) does the same lookup work.

Consequences in this adapter: do not clone title/body strings for index retention; share immutable index roots in checkpoints; cache index summaries; bound temporary arrays and HashMaps to actual changed headings; use AVL slug keys rather than allocating one trie node per title bit. Manifest/SDK compatibility has not been established by this inspection, and no stdlib file was changed.
