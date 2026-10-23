# Task04 owner effects / quota cache evidence

Date: 2026-10-23. Owner: `task04_tree/effects`.

## Scope and state

Implemented only these new product files:

- `markit/src/core/session/owned_effect_store.cj`
- `markit/src/core/session/persistent_cache.cj`
- `markit/src/tests/unit/owned_effect_store_test.cj`

No shared `core/editing` contract, source rope, parser, renderer, CLI, README,
verification log, or existing user change was edited. The frozen
`OwnedEffectTransaction` contract is implemented by `OwnedEffectsTransaction`.

Source is READY for the single-writer build scheduled by `task02_contracts`.
The isolated two-file product compilation and official targeted test binary
compilation passed. All nine tests passed. The first test compilation found
one test-only chained-assignment syntax error; the retained failure was fixed
with an equivalent local-variable assignment. This is not Task04 completion
or full-project verification.

## Implemented invariants

- Contributions retain owner/key/order and a private winner token. Winner order
  is ascending document order, then owner ID, then contribution token.
- Transactions copy only touched-key candidate lists. Owner-to-contribution-key
  and owner-to-read-key indexes support targeted revocation. No full semantic
  table clone occurs at transaction start.
- Positive and missing reads record the actual observed winner token. Changing
  a losing candidate does not invalidate readers; winner changes notify only
  registered consumers of that key. Read-before-later-write in one transaction
  is also detected.
- Revocation removes only the selected owner's effects and dependencies. Replay
  validates owner bindings before changing the transaction's staging area.
- Store version checks reject stale transactions before publication. Cancel
  drops staging; committed/cancelled transaction objects release their staging
  references. A private contribution-token sequence may contain gaps after a
  cancelled add; it is not a public node/source/version clock.
- Provider payloads clone on insertion and export. Explicit effect snapshots
  copy candidate-list structure, share private immutable candidates, and clone
  payloads when read; later transactions cannot mutate an older snapshot.
- The quota cache owns only optional derived payloads. Cost-based LRU eviction
  skips pinned entries, rejects oversized/unplaceable entries, and exposes an
  over-quota state when a reduced quota cannot evict pinned entries. Unpin
  retries trimming. Neither raw syntax nor source contents are cache entries.
- Source version leases independently retain current version, caller-owned
  snapshots, and cache entries. Last release invokes the source owner's generic
  callback. Replacing a same-version cache entry retains the new lease before
  releasing the old one. Lease release is idempotent.

## Integration API

`OwnedEffectStore`: `beginTransaction`, `winner`, `snapshot`,
`effectsForOwner` (ordered detached export), `readDependencies`,
`takeInvalidatedOwners`.

`OwnedEffectsTransaction`: frozen `revokeOwner`, `add`, `read`, `commit`,
`cancel`, plus `replay(ownerId, effects)`.

`PersistentQuotaCache`: `put`, `get`, `pin`, `unpin`, `remove`, `clear`,
`setQuota`, with entry/cost/quota properties.

`SourceVersionRetention`: document-scoped `setCurrent`, `clearCurrent`,
`retain`, counts, and a release callback carrying `SourceVersionIdentity`.
`SourceVersionLease.release()` is explicit. Task05 must connect this generic
callback and snapshot lifetime to real source storage; this task does not claim
that rope lifecycle wiring has happened. Providers remain responsible for
lossless payload clone implementations.

## Verification

- `git diff --check`: exit 0 before source-ready handoff.
- `task_a_review` read-only review of the stable three-file revision: zero
  confirmed defects. The reviewer did not run a build or tests.
- Nine `@Tag[OwnerEffects]` tests authored: winner retraction and old snapshot;
  positive/missing dependencies and losing candidates; cancel/stale atomicity;
  detached ordered export/replay; reader revocation; read-before-write; quota
  eviction and current/snapshot lifetime; pin/oversize outcomes; cloned cache
  payload and same-version replacement lifetime.
- Isolated product build: `cjc owned_effect_store.cj persistent_cache.cj
  --output-type=staticlib --import-path markit/target/release/markit -O2 -Woff
  unused -o .../task04-effects/effects-package-1/libmarkit.core.session.a`:
  exit 0. Exact arguments and output are recorded by `task02_contracts` in
  `../task04-effects/effects-compile-1-args.json` and `effects-compile-1.log`.
- Official `--test -O2 --static-std` first test compile: exit 1, only error at
  `owned_effect_store_test.cj:115`, Cangjie rejects assigning through a cast/call
  chain. The test now binds the cast result to `exportedPayload` before mutating
  its value, preserving the mutation-isolation assertion. Failure evidence is
  retained in `../task04-effects/effects-tests-compile-1.log`.
- Official `--test -O2 --static-std` second test compile: exit 0, recorded in
  `../task04-effects/effects-tests-compile-2.log` with exact arguments in the
  corresponding `-args.json`.
- Official generated `owned-effects-targeted-2.exe` direct console run:
  **9 passed, 0 failed, 0 errors, 0 skipped; exit 0**. The framework reported
  0.964 ms; this is one functional run, not a statistical performance claim.
  Evidence: `../task04-effects/effects-targeted-test-1.log`.
- Final shared full-project build and real rope/source lifecycle wiring remain
  pending with the respective Task04/Task05 owners. This isolated build imports
  the frozen editing package and does not validate partially written tree/source
  implementations or compatibility with a different SDK.

## Deliberate boundaries

The generic effect payload contract has no content-equivalence method. A replay
creates new contribution identities, so replaying a winning effect can
invalidate its consumers even if a provider considers its new payload
semantically equal. Losing replayed candidates still leave the winning token
unchanged. Cache/source retention hooks are product mechanisms awaiting Task05
wiring, not proof of real rope reclamation.
