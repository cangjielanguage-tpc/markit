# Task02 runtime capability plan handoff

Scope: `core/plugin/editing_capability_plan.cj`, `plugin_registry.cj`,
`plugin_registrar.cj`, `markit.cj`, and the independent
`tests/unit/editing_capability_plan_test.cj`. Shared compilation belongs to
`task02_contracts`; no independent cjpm build or target writes were started.

## Product API and safety boundary

- `Markit.createEditingPlan` / `getEditingPlan` are explicit on-demand APIs.
  `ensureRuntimePlan`, batch `parse` and append session creation do not call
  them and never query parser editing declarations. Ordinary registration
  retains only existing plugin/bundle references as configuration metadata.
- `EditingCapabilityPlan.accepted` means the selected policy accepts the
  configuration; **it does not mean local incremental execution**. Inspect
  `fallback` and `fullyIncrementalReady`. Session fallback dominates isolated
  units, Strict rejects missing capabilities, and an invalid phase DAG rejects
  either policy. `requireAccepted` is the gate for future editing consumers.
  The no-fallback enum value is `EditingFallbackScope.NoFallback` (not `None`,
  which conflicts with the standard Option constructor in this compiler).
- Parser readiness requires explicit opt-in, a provider, matching nonempty
  owner, and all four declared state/effect/read/node-codec flags. Provider
  operations are not executed during planning; flags are declarations, not
  evidence that later restore or parse operations have succeeded.
- Legacy local fallback requires `ParserIsolationProof.verified`. Missing or
  incomplete evidence means whole-session rebuilding; no builtin/plugin name,
  node kind or grammar marker is used to infer safe boundaries.
- Inventory contains real registered parsers only. Although Markit installs a
  generic paragraph factory, both existing engines require a nonempty paragraph
  parser list to start/flush ordinary paragraphs. Empty/leaf-only configurations
  therefore ignore unmatched ordinary text in the existing API. No phantom
  parser is registered for that inactive factory branch. Empty Strict readiness
  describes that empty configured grammar, not builtin Markdown support.
- Anonymous legacy derived processors/hooks have no reversible editing
  provider. They remain Session fallback / Strict rejection. Phase id/dependency
  metadata validates order only and never blesses an opaque callback as safe.

## Ordering and fingerprint

- `plan.parsers` is a **capability inventory**, not an execution candidate list.
  Priority is a stable display order within categories. Parsing must reuse the
  existing dispatch tables, including leaf start-byte bucket before generic
  any-nonblank candidates. No legacy dispatch algorithm was changed.
- Explicit phase registrations validate missing, duplicate and cyclic ids;
  stable topological order chooses the earliest currently ready registration.
- Fingerprint is a length-prefixed canonical configuration identity, not a
  cryptographic proof. It includes policy, grammar/config tokens, plugin/bundle
  names and versions, parser declarations, fallback evidence and phase graph.
- `cacheable` is false for unspecified/empty configuration or missing version
  identity. Existing Plugin exposes no private configuration reflection: the
  caller must change its explicit configuration token whenever private plugin
  configuration changes. Unknown configurations must not be cached by equal
  canonical metadata. This flag concerns capability-plan identity, not parsed
  syntax or render-result reuse.
- Rejected plans do not freeze the registry or create a parse/source session,
  allocate NodeIds, invoke provider methods, run finalizers or emit patches.
  If Markit's default Standard bundle is still lazy, planning uses an isolated
  temporary registry; rejection does not publish its registry or pending flag.
  This preserves later `.use(StandardMarkdownBundle(...))` replacement behavior.
- Every builtin currently still has its actual default declaration. This Task02
  inventory completes **0/30** builtin incremental adapters; external legacy
  fallback is not a completion path for the thirty required builtin adapters.

## Directed checks and current evidence

Ten directed tests cover mixed real parsers, each missing required facet,
provider-owner mismatch, Strict rejection, cross-plugin priority ties,
bucket-before-any dispatch, phase errors, real AutoAnchor config identity,
batch/append provider-read absence, derived hooks, and actual empty/leaf-only
inventory and fresh same-configuration output.
The complete positive provider owns a real cloneable payload and context-based
checkpoint/restore/effect revocation; planning asserts that it is not invoked.
Checkpoint ownership includes a mandatory document id: same-owner/version
restoration or revocation against another document is rejected before mutation.
The same mixed-parser case also verifies the positive Strict path with an
explicit complete Paragraph provider plus Leaf provider and no opaque hooks:
accepted, fully ready, NoFallback, and unchanged provider-operation count.

First integrated compile failed on shared enum equality and instance helpers
used before constructor initialization. The main owner adds shared Equatable
operators; the two pure runtime helpers are now static. Initial errors remain
in `../task02-contracts/integrated-compile-1.log`.

The second compile narrowed to two Option/enum `None` ambiguities. The shared
owner renamed the enum value to NoFallback; this owner's references were
updated. The main owner's third integrated compile passed, as read from
`../task02-contracts/integrated-compile-3.log`: test-profile compilation success,
`TASK02_COMPILE_EXIT=0`. Product/test source remains frozen for directed runs.
Compilation is not a test execution pass; directed runtime assertions still
await the main owner's actual run results.
The first directed run passed 18/19 EditingContracts and all 6 TypedCodec tests;
its one ERROR was this owner's erroneous assumption that an empty paragraph
parser list still produces a Paragraph node. Reading both dispatch gates and
observing the empty root disproved it. The original failure remains in
`../task02-contracts/editing-contracts-test-1.log`. Per root decision, the
phantom inventory entry was removed and that test now compares empty/leaf-only
behavior with fresh identical configurations, preserving source/byte progress,
Strict rejection for genuinely unsupported parsers and derived side effects,
and all existing grammar behavior. Revised source is frozen for compile/run 4.
The fourth integrated compile passed (`TASK02_COMPILE_EXIT=0`). The second
directed EditingContracts run then passed **19/19**, with **0 ERROR / 0 FAILED**,
including all ten `EditingCapabilityPlanTests` listed above. Evidence:
`../task02-contracts/integrated-compile-4.log` and
`../task02-contracts/editing-contracts-test-2.log`. The 38 unrelated cases in
that tag-filtered binary were excluded by the main owner's test selection;
none of these ten runtime cases was skipped. Main owner separately owns wider
regressions and same-condition batch timing. `git diff --check` on this owner's
tracked product edits passed.

This work does not implement Task03's rope, Task04's persistent tree or Task05's
editing transaction engine, and does not claim any builtin adapter completed.
