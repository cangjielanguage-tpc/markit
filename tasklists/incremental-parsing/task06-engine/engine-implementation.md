# Task06 inline 编辑主集成

Status: In Progress（尚未 SOURCE_READY）

`InlineTextView` 的 byte/rune/read footprint 全部是 view 坐标；raw edit 投影由具体映射 provider 提供，synthetic 未证明不能猜。索引每个快照绑定 document/source version 与稳定 mapping 配置身份，normal source 迁移不把全部 suffix 视为失效。

字符读取与 owner-length 是两种证据：`view.byteLength` / `context.endByte` 只记录 dependsOnLength，长度变化才唤醒真实 lengthReaders；不会伪造所有字符被读。接口不传无法观察的 primitive endByte。失败候选的 ID/state/write 经 ParseSession.parserAttempt 回滚，独立 read recorder 保存实际正负语义读取，并在失败沙箱退出后重新挂到真实 parent semantic owner，供之后 key 新增唤醒。

主会话只产生 staged immutable snapshot；Task05 的单一发布门决定 source/parse 版本和 tree/effects/patch 原子安装。partial inline children 通过 raw bundle splice 接线，防止整 paragraph replace 的 ID-index 全量重建。逻辑 Text 内部保持有界持久 payload，显式 legacy materialize 可线性，正常编辑与 patch 不应经过全文 String/HTML。

用户要求成员形参折叠；实际 SDK 限制 regular params 必须在 member params 前。因此本轮尚未交付的 DTO 将 regular clone/validation 输入前置，再用 public/private let 成员形参，更新新 callers；保校验后 clone。旧已交付公共 API 不为写法改变参数顺序。所有语法以实际编译为准。

当前主文件为 draft；尚未声称完整 parse window/convergence/recursive reuse 验收通过，真实内置适配仍0/30。全部编译/运行由02，最终需要 directed fresh、长单logicalText局部性与原legacy/O2记录，不新增通用测试/计数/benchmark框架。

## Current implementation record (2026-10-23, Task06 takeover)

Status: In Progress; the earlier draft paragraph above is historical.

Owner: task04_tree uniquely owns inline_editing_session.cj, inline_editing_facet.cj, inline_parse_result.cj, inline_parser_engine.cj, inline_nested_reads.cj and task06_inline_engine_test.cj. session_checkpoint owns the shared grammar, recursive fixture, attempt index and block/incremental/Markit bridge. task02_contracts exclusively compiles and runs official test binaries.

Verified milestones: stage2 first four main cases passed 4/4; stage4 six main cases passed 6/6; the first recursive source case passed 1/1 on its frozen dependency set. The later eight-case run passed 7/8 and exposed adjacent literal normalization after opener deletion. Its original fresh comparison remains unchanged. The fix concatenates only explicit literal-origin payloads and adjacent literal neighbors, retaining independent raw and decoded trees; parser-produced Text retains metadata and is never merged by payload class alone. New stage9 products and the expanded tests await the next official run; historical results do not certify this source revision.

Current products enforce private engine-branded snapshots before scopes or IDs, grammar identity checks, actual successful/failed read evidence, length and semantic locators, provider recovery fixed points, persistent literal provenance, bounded giant-Text splice, and raw child handoffs. Nonidentity decoding expands only its logical literal materialization unit after syntax closure; it does not turn that expansion into another source edit. Only actual retried openers are removed from the attempt index before the actual edit shifts the unaffected suffix, preserving evidence birth versions.

Recursive owners retain actual child engine snapshots. Proven child edits call child.prepare and publish its deep children edit instead of recapturing a parent legacy graph. A persistent UTF-8 key trie locates recursive semantic readers; local read deltas update only changed key/owner paths. Multiple semantic child changes use the compatible BlockRawChildrenEdit.following batch under the existing final publication gate. Provider rebase proof handles immutable child views after source edits outside the owner. Current recursive cross-epoch and multi-owner semantic assertions remain pending execution.

Remaining acceptance: newest main/recursive/bridge tests, full normal regression, exact fresh public output comparison and the existing minimal same-SDK same-O2 record. Built-in parser migrations belong to Task07; no built-in completion is claimed here. No new generic oracle, counter or benchmark framework was added.

### Final necessary source freeze

The stage10 inline/plugin/incremental closure compiled with exit0 after the explicit literal payload factory and result-layout correction. InlineParseResult again stores only its original node/consumedBytes/consumedRunes fields; its editing accessors are open defaults returning None. EditingInlineParseResult alone stores raw/recursive handoffs. InlineLiteralFacet.payload is a provider proof and safely defaults to None: the core does not infer raw source spelling from mapped/synthetic view bytes. Existing fixture providers declare their spelling explicitly.

The stage9 official main run passed all eight cases (inline-engine-test-4.log), including both uppercase/raw counterexamples, nonidentity raw byte/span/old-snapshot checks, unaffected token raw-reference and parser-call assertions, foreign snapshot rejection, failed-probe rollback, semantic missing/present/removed replay, provider-expanded failed-read closure, escaped opener deletion and 512 KiB bounded literal splicing. The original adjacent-Text fresh assertion was retained and passed after the fix. Stage10's additional factory/default-unsupported assertion and recursive rebase/batch assertions await the coherent final official run.

No new timing entry point was created. Per root's scope decision, Task06 uses the bounded-read/slice, actual splice, raw-sharing and call assertions for locality; the existing Task01 frozen batch driver supplies the minimal same-O2 batch comparison. Production-plugin end-to-end editing timing belongs to Task07-P. This document does not claim built-in parser migration or statistical no-regression evidence.

### Final helper ownership and source boundary

After session_checkpoint stopped on model capacity, root explicitly reassigned only the three shared grammar/escaped/recursive fixture files to task06_fixture_finish. No uncertain write was replayed: their actual sizes/timestamps and the absence of payload/rebase methods were checked first. The original block/document bridge remains frozen. task02_contracts alone added InlineAttemptIndex.hasReadingKey, and task04_tree consumed it in one line so local read-delta existence checks follow one locator path instead of materializing all readers of a popular key. Current main session SHA256: 3A06F89D150E7ACD3945812B53A1726DBBEF29E78DFFFC92FDD36CADDCFCCF82. This last one-line revision awaits the normal coherent final build; the eight-case pass remains bound to its recorded earlier source hash.

### Final verification in progress

The explicit-factory/edit-result-subclass revision passed all eight main official tests again (inline-engine-test-5.log, exit0). The last source freeze adds only PersistentDocumentVersion.resolveAtVersion(anchor,target): an immutable-coordinate read through the existing SourceStore contract, guarded by 0 <= target <= document.version and preserving None for unknown/pruned/foreign anchors. It does not construct an old syntax snapshot or alter history/index roots. Final doc SHA256: A85624D0EC6D4A7B88140373B33123ECF13AC187884BC3F07D116F1EE1FBDB9F.

Root transferred the three final fixture files directly to task04_tree after both earlier fixture owners stopped at model capacity before applying their pending patches. The actual missing methods and old constructor calls were read before applying only those missing changes. The same recursive case retains the original two child-edit assertions and now also checks: two independent recursive owners reading the same key, missing/present/removed replay with exactly two deep splices, external-tail edit followed by child key replay, and two earlier child edits followed by an external edit and another child edit with a birth0 sibling projected to immutable view2. Parent parser calls, sibling raw references/effects, fresh complete visible output and old snapshots remain asserted. No new test matrix or parser grammar copy was introduced. These final recursive assertions await the coordinator's new-document coherent run; the normal whole build follows it.

### Final recursive official result

The new doc12/inline12 coherent official recursive binary passed its single combined case: 1/1 PASSED, 0 skipped/errors/failures, exit0 (task06-verification/inline-recursive-test-2.log). This includes the original source-child reuse assertions, both same-key recursive semantic readers and ordered following edits, outside-source-edit semantic rebase, mixed-birth historical projection and invalid-target guards, unchanged sibling raw ID/reference/effects, fresh complete visible fields, and immutable older snapshots. The final whole build and real Markit bridge run are now scheduled by owner02; Task06 is still In Progress until root accepts those results.

## Task07 provider handoff

- A literal provider must implement payload(view,start,end,block) with its real raw spelling. None is unsupported. offsetsFollowLiteral proves coordinate identity only; it does not prove decoded values equal raw bytes. The fast path also checks this actual insertion against its raw view window. Existing metadata-bearing Text payloads retain their codec/base identity restrictions; providers must not silently drop metadata to split or reidentify them.
- parseAttempt keeps the same grammar algorithm as legacy parsing. Its context records actual byte/EOF/length/key observations, including None. A successful parser Text has parser provenance and is not an engine literal merely because its payload is PersistentTextPayload.
- EditingInlineParseResult is the explicit raw handoff; ordinary InlineParseResult remains the legacy three-field object. A recursive handoff must carry an actual child session/snapshot and a provider projection proving parent typed fields, delimiters, mapping and external reads remain valid. project returns the next immutable projection. rebase proves the same unchanged child geometry in a newer containing view; unproved mappings remain unsupported.
- prepare/replaySemantic return staged snapshots only. Publish childrenEdit followed recursively by its following edits through the existing common tree/effect/patch gate. If semantic replay returns the original snapshot reference, it has no new edit to publish. No parent legacy recapture is needed for a child handoff.
- Source edits use closed actual-read intersection; expanded recovery boundaries do not turn unchanged endpoint contact into a new edit. Literal re-decoding units are separate from syntax/read closure. Only retried opener owners are removed before the actual source edit lazily shifts the remaining index, so unchanged evidence keeps its birth version.
- Recursive key routing uses the child's actual read index and local readChanges. Do not replace hasReadingKey with readingKey().isEmpty on a hot existence check, since the latter materializes every reader of the key. Read historical immutable-view coordinates via resolveAtVersion, with retained-source history; a None result is not permission to fabricate coordinates.

## Root accepted completion (current)

Task06 Status: Done, accepted by root. Final whole4 compilation exited0; official InlineEditing25/25 passed; all 27 packages passed 717/717 with zero skip/error/failure; 148 records times 11 frozen fields matched Task01 exactly. The existing same-SDK/O2 v2 driver compiled and both reference/candidate executables exited0, 84 samples each in one reference-to-candidate AB sequence. Means: small String37.418 to33.205us, small Stream42.039 to33.068us, large String28.097 to27.074ms, large Stream27.107 to27.256ms(+0.55%). One AB sequence is not statistical proof of no regression or a speedup. Earlier pending/failing sections above are historical.

The bridge fixture static review originally verified assertion/registration order but missed the SourceLine getter spelling. Whole3 correctly failed on .content; its owner corrected it to the actual .text getter, preserving all assertions. Whole4 and the actual bridge3 run supply the successful execution evidence. Task07-P is now released; no other earlier draft statement overrides this accepted state.
