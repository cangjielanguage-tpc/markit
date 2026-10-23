# Task07-P inline plan handoff

Updated: 2026-10-23

Status: current helper product compile and official targeted test compile both exited 0; the final C3D2 source snapshot passed all three official cases, with zero failures/errors/skips. Shared-build owner `task02_contracts` executed the serial compilation and run. Wider Paragraph/Quote/Reference integration and the explicit remaining boundaries below are not implied by these three passes.

- Owned product file: `markit/src/plugins/standard/editing/standard_inline_plan.cj`.
- Accepted SoftBreak handoff from `task04_tree`: `markit/src/plugins/standard/inline/soft_break/soft_break_parser.cj` and `soft_break_editing.cj`. Existing shared `matchesSoftBreak` newline grammar is preserved. Editing now observes preceding backslash parity, matching the legacy engine's escaped-opener suppression; failed newline attempts keep those real reads.
- Targeted tests: `markit/src/tests/unit/task07_inline_plan_test.cj`, three cases, tag `StandardInlinePlan`. They reuse the existing test package's `task06Codec` helper; no new oracle, benchmark, or counter framework.

## Frozen interfaces

`StandardInlinePlan(parsers: Array<InlineParser>, codec: NodeCodec)` exposes `codec`, `literal: StandardLiteralFacet`, and `create(): InlineEditingSession`. One plan registers its SoftBreak typed codec; callers must not register that codec a second time. Each paragraph retains its own created engine and snapshot.

Parsers that implement `StandardInlineChildConsumer` expose `hasEditingChildren` and `configureEditingChildren(factory: () -> InlineEditingSession)`. After constructing its real dispatch inventory and codec, the plan configures only consumers that have no child engine factory. The closure captures already-initialized dispatch/codec/literal local references, and recursive labels use the actual registered inventory rather than a separate parser plan.

`StandardParagraphInlineView(mapped: MappedInlineTextView, escapeCount: Int64, normalizedRaw!: Bool = false)` exposes immutable values and delegates `InlineTextView`. Construction validates the nonnegative count only, with O(1) metadata work. The paragraph provider owns the initial count and its edit-local difference updates. The plan does not count the whole paragraph on each edit. `normalizedRaw` is explicit provider evidence that legacy raw uses the mapped spelling (quote prefix removal and LF normalization); the Paragraph owner must preserve it across local edits and semantic rebases.

## Provenance and recovery

- Literal decoding calls the actual `InlineUtils.processEscapes` algorithm. There is no second escape table or alternate Markdown parser.
- Only the explicit paragraph carrier can provide a literal payload. It checks source identity and each scalar's mapped provenance in the selected materialization unit; absent interior mapping returns `None`. Opposite endpoint affinities select each scalar's own mapped part. Adjacent source intervals are coalesced before export, while physical prefix gaps are excluded. The explicitly normalized provider uses the validated mapped spelling for raw; ordinary providers retain physical line endings such as CRLF. Arbitrary/unmapped views do not receive invented raw text.
- `projectRaw` binary-searches logical byte positions using the persistent weighted mapped view's anchors. It resolves old anchors at the requested immutable view version, checks both endpoint affinities, and refuses unmapped gaps.
- Recovery includes the preceding slash run and the following scalar when escape metadata is nonzero. This supplies actual parity/opener dependencies without full-session reparsing.
- SoftBreak reads the actual newline candidate and its preceding slash run through `InlineAttemptContext`; it does not use a guessed default escape flag. Whether a terminal newline is exposed in the paragraph view remains the Paragraph provider's real `SourceLine.terminated` plus `ParagraphTermination` decision, through the existing `shouldAppendTerminalSoftBreak` grammar. The inline facet does not fabricate a termination read or claim to own that block-level decision.

## Exact locality boundary

The long single-logical-Text test uses an edit-time guard rejecting more than 64 byte reads or a String export larger than 64 bytes. It covers a paragraph whose actual `escapeCount` is zero, checks a single logical Text and stable node ID, one local text patch, old payload preservation, and a multibyte Unicode/UTF-16 result.

Initial literal capture is not O(1): the selected literal is exported once, every scalar's mapping is checked, contiguous raw intervals are exported and escapes are decoded, then persistent payload leaves are built. The wrapper's O(1) claim applies only to construction of its already-proven metadata carrier. On the ordinary no-slash single-Text fast path, the engine bypasses payload creation; splice, candidate checks, and inserted spelling concern the actual edit window. A newly parsed/rebuilt literal still pays for its actual materialization unit. No zero-cost or constant-time claim is made for initial parse, rebuilt literals, or legacy export.

This guard does **not** cover a long logical Text containing a distant escape. Any nonzero paragraph `escapeCount` makes `offsetsFollowLiteral` false. The core then expands an affected literal to that entire logical Text to preserve independent decoded/raw coordinates; payload creation scans and decodes that necessary Text. A remote escape in the same Text therefore still causes O(Text length) work. This is an explicit remaining locality limitation, not evidence of fully local editing for escaped paragraphs. The expansion is a real literal unit, not blanket full-session fallback.

The remaining tests check real escaped decoded/raw values before and after editing, immutable old snapshots, rejection of generic views as raw providers, and failed escaped-newline reads becoming a successful SoftBreak after slash removal. These are targeted functional checks, not acceptance of all Standard plugins or the full 30-plugin inventory.

## Source snapshot submitted to serial verifier

| File | SHA256 |
| --- | --- |
| `standard_inline_plan.cj` | `C3D2C6C29998426BB454A69DE53374003B97BDC7BF98347763FB9B3B52461A6A` |
| `soft_break_parser.cj` | `054A6FD88F33BDC0687B1FF88AB425771B09300D9E32D0897B94CCAFC211E1B2` |
| `soft_break_editing.cj` | `249F964BF3946F0D47390FC36C023AB069FB339670E27C131EAF0D5737642417` |
| `task07_inline_plan_test.cj` | `668CA40FDBE11229EC3983553AD737E2C678781EA57FEAB2CD210D64D1D025FB` |

Read-only standard-library spot-check: `C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj` implements `String.toArray` and `clone` with allocation/copy. The implementation avoids repeated whole-paragraph UTF-8 array conversion and does not clone/export the whole paragraph to compute its escape metadata. This source is not claimed to match the installed SDK version.

## Serial verification and correction

- Final C3D2 product: [exact compiler arguments](product-compile-1-args.json), [exit-0 product log](product-compile-1.log). Final targeted tests: [exact compiler arguments](tests-compile-1-args.json), [exit-0 test compiler log](tests-compile-1.log), [exact executable arguments](tests-run-1-args.json), [official 3/3 output](tests-1.log). No tests were skipped, and executable exit was 0. These are functional checks; elapsed times in official logs are not a performance benchmark claim.
- `task02_contracts` reported `compile8`: both SoftBreak and editing package compiled with exit 0 before the raw-gap correction. That result is retained as historical interface/type evidence only; it does not verify the current payload implementation.
- `task02_contracts` reported the next `stage10` build exited: current raw-gap-corrected helper `AAE89...` and Paragraph compiled with exit 0. After the read lock was released, the necessary child-consumer interface/factory hookup was added and the new final hash submitted for compilation and the first official three-case run. The old hash's compilation does not prove this final hookup.
- The first payload implementation used a physical first/last source interval. Review found that multi-line quotes could place removed `> ` prefixes inside literal raw. That implementation was corrected after the compiler's read lock ended. The current source snapshot above uses scalar mapping proof and coalesced intervals; the verifier has the new hash.
- `standardProjectMappedRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64` is now public for the Quote provider's own ordered mapped raw view. This is an inverse-coordinate helper, not a raw-spelling authorization. Quote retains ownership of its own raw provider and ancestor payload updates.
- The three narrow inline cases do not establish top-level CRLF paragraph normalization versus fresh raw/span, or quote marker-removal/LF normalization versus fresh raw/span. Those real builder checks were handed to the Paragraph and Quote owners for their existing targeted suites, including an escaped newline spanning two physical lines. Acceptance remains pending until those actual results arrive; merely setting `normalizedRaw` does not prove the builder convention.

## Exact cross-line label handoff gap

Reference's shared matcher permits labels across newline. Its label projection receives `InlineAttemptContext.view`, which is the core observed wrapper rather than the original `StandardParagraphInlineView`. That wrapper currently hides the explicit `normalizedRaw` provider proof. Reference therefore keeps the safe physical-raw default, which agrees for single-line labels but does not prove legacy normalized-LF raw inside a quote across CRLF. The Reference owner confirmed this boundary; Paragraph/core owners were notified that a minimal generic proof passthrough or an explicit original-view provider channel is needed. No mapping-identity string parsing, equal-length inference, or fabricated normalized guarantee is used. This cross-line raw compatibility remains unverified until that contract and its targeted fresh/old test are integrated.
