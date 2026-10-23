# Task 05：块级编辑事务与检查点收敛

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Done

## 2026-10-23 当前实施与所有权

03/04 已由 root 审核通过；Task05 已放行实施。共享构建由 task02_contracts 串行排程，以下代码尚未通过本轮编译，不能视为已验收。

| Owner | 独占产品范围 |
|---|---|
| task05_engine | `core/block/`、`core/incremental/`、`markit.cj`及主事务测试 |
| session_checkpoint | `parse_session.cj`、`session_patch_queue.cj`、`session_symbol_table_store.cj`、新增checkpoint文件及独立测试 |
| source_lifecycle | `editable_source.cj`、`line_index.cj`、新增source生命周期、`persistent_cache.cj`及独立测试 |
| task04_tree（明确转交） | `persistent_document.cj`、`persistent_node.cj`、`owned_effect_store.cj`及原子store测试：组合prepare、birth epoch聚合、局部结构splice |
| task02_contracts | `core/editing/`共享契约审查更正与唯一sharedtarget构建 |

已落盘：共用 `BlockParsingKernel`，批量与流式入口正在接入同一调度器。完整checkpoint、源码历史安全保留、组合发布准备接口和主编辑会话正在实施。以下早期 Current State/Verification Record 为实施前历史，当前真实结果追加在 task05-engine/，不冒充通过。

## Execution Contract

- Depends on: Task 03、Task 04。
- Unlocks: Task 06。
- Execution: 串行集成；03与04均经协调者审查后开始，不与它们同时改交接实现。
- Delegated owner: 块编辑引擎与事务集成子agent，实施时由协调者指定。
- Scope boundary: 未来拥有`markit/src/core/block/`、`core/incremental/`、`markit/src/markit.cj`的编辑接线及block/edit事务测试；03/04交接所需source/tree/session接线修正可在本串行任务明确列出后修改。不得批量适配内置插件或改CLI/webview；共享契约新增语义需退回02审查再改。
- 输入：03真实rope/mapping、04真实持久tree/effects、02facets/runtime plan、01oracle/collector；输出：可运行的块编辑会话、完整checkpoint/rollback/收敛、nested subunit调度、完整事务原型证据，为06提供稳定接口。

## Goal

让编辑会话基于插件声明的检查点和依赖重解析至收敛，原子提交语法/语义/patch，正确复用嵌套未变单元，且取消旧计算不丢失已接受源码。

## Current State

- `markit/src/core/incremental/incremental_session.cj::IncrementalSession`只有feed/feedBytes/finalize，保存一个openBlockParser/frame并处理pending paragraph，finalize执行两类hook后releaseRetainedSource；没有replace或版本化编辑事务。
- `markit/src/core/block/block_tree_builder.cj::BlockTreeBuilder.parseLines`在local openBlock与session.pendingParagraph之间调度，ClosedAndReprocess会重新处理本行；checkpoint恢复必须覆盖两者。
- `markit/src/markit.cj::Markit.createSession`的detached parser共享ParseSession，registered detector直接调用tryStart；`ParseSession.parseDetachedLines`只维护depth，nested activeLine/pending/state可能外溢。
- `BlockFrame/BlockState`未保存恢复契约；state snapshot仅名称。旧AstPatch/IncrementalUpdate没有完整document/source/parse版本事务协议。

## Follow-Up Work

**新增必做：** 将syntax convergence与semantic convergence分开实现和计数。raw syntax复用只要求该单位完整语法上下文及实际正负读取依赖有效；slug/编号/引用等overlay按key或ordered reducer另行传播。真正被语法读取的状态必须参与失效，但不能因无关全局map不等禁止后缀raw复用。

1. 接入03与04，建立document edit会话：区分accepted sourceVersion、committed parseVersion和renderVersion；校验edit顺序/版本，ack源码后保留该输入，后续计算以最新accepted source为准。旧任务取消不得undo已ack用户编辑。
2. checkpoint保存完整block frames、parser/facet身份与版本、pending paragraph lines/span/termination上下文、active line/depth、嵌套路径、状态payload、semantic owner/effect游标与映射版本；不可只保存“某块名称/起始行”。
3. 基于source/tree索引找最小命中单位与插件声明恢复点。支持向前吸收pending上下文、nested subunits/items/rows与父容器摘要；恢复到合法checkpoint后共用原parse内核。禁止在core写Markdown marker或内置kind分支选边界。
4. probe改为纯或沙盒事务，失败候选不会漏NodeId、state、pending、patch、外部效果；registered detector按facet能力工作，不再把提交型tryStart当无条件纯探测。
5. nested parse建立独立语法上下文栈：进入时继承明确配置/语义作用域，退出或异常时恢复activeLine/pending/frames/depth；全局允许的语义写通过owner effects传递，不能全部隔离丢失也不能无归属外溢。
6. 在暂存tree/effects事务中撤销旧owner、解析新单位、记录正负依赖与state出口。遇到source位置映射、完整state、边界分类/后继、效果/依赖fingerprint全部相等才复用后缀；需要继续传播时输出原因。不要单凭相同文字或Node.==停止。
7. 原子publish新parse snapshot/effects和有序patch；取消、过期或异常回滚未提交语法/overlay/patch，保留已发布旧快照完整。sourceVersion领先时明确版本状态，下一次从最新accepted source选择可用旧checkpoint重算，不假称旧parse等于新source。
8. 兼容旧parse/stream入口、callbacks/patch顺序及retention生命周期；允许legacy适配层，但同一语法实现复用。03/04接口实现问题在本串行集成记录修正，不悄悄改掉协议含义。
9. **运行完整checkpoint事务原型硬门槛**：真实rope+持久raw tree+typed codec+完整state，执行一次nested局部编辑，展示旧单位复用、新typed单位替换、效果撤销/重放、source map正确；注入失败/取消并恢复，证实无悬挂源/别名/重复ID。这份实际证据必须在释放07大规模适配前通过，02小原型不能替代。
10. 用测试facet实现有状态容器/paragraph/文序定义等最小语法，规则只在测试插件，给06提供edit/observer/nested owner接口。内置支持留07起按清单完成，不能以测试facet声称30插件完成。

## Acceptance

- **新增硬门槛：** 测试facet改变文首某语义key时，未读该key的后续正文parser为0调用；真实依赖者被唤醒，semantic replay与syntax扫描分栏且fresh oracle一致。实际Heading/Reference版本由07纵切再次验证，不能仅以测试facet完成生产验收。

- 小型可跑验收：三个siblings、中间含nested两个子单位；编辑其中一个正文，另一子单位和左右siblings保持raw/NodeId，计数显示未被无条件重parse。改变测试插件容器delimiter后允许扫描扩大，但须说明依赖与新边界。
- pending paragraph+向前吸收、ClosedAndReprocess、EOF open frame、nested异常四场景与fresh oracle一致；退出nested后outer activeLine/pending/frame正确，不重复/丢失退出行。
- probe故意试写state/NodeId/patch后失败，所有未提交效果被回滚；同一个输入重复probe结果相同且外部可见状态无变化。
- source v2已ack，parse v2中途取消，随后v3已ack：v2/v3输入不丢，旧parse快照不被半改，最终从v3计算并提交v3；过期v2事务不得覆盖v3。取消不等价于撤销用户编辑。
- 删除一个定义owner后，候选winner和missing读失效正确；cached未变单位的效果未漏重放/重复写入。恢复state后与从头解析结果一致。
- 完整原型在真实03/04实现与仓颉1.1.0运行通过，记录命令、输入序列、计数与错误注入；此项未过不得释放大适配。长容器局部编辑不能以whole-container常态重parse结项。
- legacy四模式回归差异依01精确基线审查；没有core Markdown边界表、全文materialize热路径、全树offset重写或每edit新进程。

## Verification Record

- 本轮：仅静态读取IncrementalSession、BlockTreeBuilder、ParseSession、Markit.createSession与AstPatch；没有实施edit会话或运行完整原型。
- 未来在`markit/`执行`cjpm test --no-progress`与现有Streaming回归；记录1.1.0工具链和03/04交接版本。
- 拟新增：`cjpm test --no-progress --include-tags=BlockEditing`、`cjpm test --no-progress --include-tags=CheckpointTransactionPrototype`、`cjpm bench --filter=BlockEditingBenchmarks`；保存取消/过期/异常重放序列、复用计数与convergence原因。


## 2026-10-23 实施交接接口（当前冻结）

主会话产品位于 `DocumentEditingSession`；`applyEdits` 先确认 source，`flush` 以独立 parseVersion 发布，取消保留已接收输入。Strict 必须证明具体可执行 `BlockEditingFacet` 与全部 hook，未知第三方 Compat 经完整 `DocumentSnapshot` 会话回退保留旧 typed graph、renderer 与 LineIndex。

块 provider 返回完整恢复点及独立的 expected exit/kernel 证据；缺证据不会伪造后缀收敛。跨 source epoch 的 pending/active geometry 通过显式映射恢复，open frame 几何由实际 provider 恢复，synthetic 未声明映射拒绝恢复并请求扩展。语法与语义失效分别消费实际读取证据；没有相关读取的 body 不执行语法 parser。

`BlockUnitParseResult.rawReplacement` 可直接提交局部持久 bundle，供后续 inline/text 窗口消费已有 `PersistentTextPayload.splice`，无需每次 materialize/capture 整段。新增/删除 sibling 通过持久 `spliceBundles`；辅助引用由 owner-aware capture、局部入边索引和受影响闭包回收接线。

所有 callback、payload 克隆、codec 与 patch 准备发生在共同发布门前。两个 store 完整 validate 后无 callback install，再发布一个 snapshot 指针。已提交后的释放失败保持 committed 状态，保存失败句柄等待重试；不会恢复旧 parser 或撤销 accepted source。

真实验证汇总见 `task05-engine/engine-implementation.md` 与 02 维护的 `verification-log.md`。首轮 whole compile exit 0；主 BlockEditing 首轮 37 Passed/2 Failed，保留原失败日志，source-derived ancestor raw 导出差异已按显式 codec proof 修复并进入 whole2。不得把待运行 whole2 或后续全量标为通过。


### 当前真实结果（root 已审查）

- 官方 whole3 全闭包 `--no-run` 编译 exit 0。
- 主 BlockEditing 选中 39/39 Passed，原 anchor 9/9 Passed；nested 原 toString/toJson fresh 对照未放宽。
- 修后 27 包全量 692/692 Passed，0 skipped/error/failed：`task01-baseline/task05-full-console-2/summary.json`。
- 初次 nested 导出 2 个失败、初次全量 691/1 的原日志均保留；不覆盖或重命名失败结果。
- 实际 SDK 1.3.0-alpha.20260920003052；没有最低 1.1 兼容通过声明。内置 parser 适配仍 0/30，本轮 test facets 不冒充真实 plugin 纵切。


### 最终补齐的对照/用时记录

`task05-verification/legacy-comparison-2/versus-frozen01.json` 记录 148 条 / 11 字段零差；冻结和当前 observations SHA256 一致。`batch-time-comparison.json` 记录同 SDK / 同源 v2 / 同 `-O2` 原条件 AB 一次，每 binary 84 samples，均 exit 0；small String/Stream mean ratio 1.05419/1.02996，large String/Stream 0.97058/1.03585。有快有慢，仅一次记录，不声称统计无退化；未额外采样或扩 benchmark 框架。具体接口、生命周期限制和旧失败日志保留见 `task05-engine/engine-implementation.md`。
