# Task 01：基线、差分 oracle 与计数设施

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

**2026-10-22补充：** 按[评审补充](review-2026-10-22.md)重录clean `c510aee`基线并保护最新映射/预览/动画。新增同`-O2`配对parse-only时间/吞吐、分配与RSS基线，渲染单列；以噪声之外无可测减速为用户目标，实施前冻结测量与预算，不设未经同意的回退百分比。编辑bookkeeping的batch可关闭/无额外成本路径交02冻结。

Status: Done

## Execution Contract

- Depends on: 无。
- Unlocks: Task 02。
- Execution: 串行；协调者审查本任务证据后才释放02。
- Delegated owner: task01_baseline（内部委派 legacy_fixtures / oracle_tools / perf_baseline，文件所有权见 task01-baseline/environment.md）。
- Scope boundary: 未来只拥有`markit/src/tests/utils/`中的oracle/编辑脚本/计数记录工具、`markit/src/tests/unit/`中独立的baseline fixtures，以及拟新增editing benchmark输入与报告格式。不改生产解析算法，不修插件语义，不动CLI/kit/extension和当前dirty基线；如确需公共可观测hook，提交02协议输入，不能提前修改共享core接口。
- 输入：当前HEAD/dirty工作树、旧四模式工具、30插件静态盘点、[设计锁](00-design-locks.md)。输出：可运行的legacy基线、fresh oracle及编辑序列runner、已知差异清单、计数/负载格式；这些是02的审查输入。

## Goal

在保留用户工作树的前提下建立可信比较基线，使后续任务能证明“结果正确且没有做无关工作”，并将已知错误坐标/重复ID与需要保留的语法语义区分。

## Current State

- `markit/src/tests/utils/parse_mode_test_kit.cj::ParseModeTestKit.collect`已有direct-parse、incremental-string、incremental-bytes、input-stream四模式；ParseModeResult收集HTML/Markdown/Typst/JSON/tree及更新计数，但没有文内edit序列执行器。
- `markit/src/core/incremental/incremental_session.cj::IncrementalSession.feed/feedBytes/finalize`是append路径，不能替换旧范围；其历史benchmark不能证明editing。
- `markit/src/core/nodes/node.cj::Node.==`不包含children/metadata；`markit/src/core/document/document_snapshot.cj::DocumentSnapshot`全树建索引。不能直接用这两个接口推断完整语义等价或局部工作量。
- `HTMLInlinePlugin.pairTags`复用opening.id给Container和protected Text；`BlockquoteParser.finalize`、`ListBlockParser.normalizeDetachedLines`和`ParagraphChildrenBuilder.appendChildren`存在source mapping基础缺口。参见[逐插件证据](plugin-standard-commonmark.md)。
- `markit/cjpm.toml`声明`cjc-version = "1.1.0"`；`docs/advanced/testing-benchmark.md`记录现有`cjpm test --no-progress`、Streaming tag和benchmark命令。本轮尚未执行构建或测试。

## Follow-Up Work

**新增fixture要求：** 冻结至少一个无需编辑能力声明的真实旧式第三方插件源码及其parse/append基线，后续不修改fixture来迁就新接口；另列各facet缺能力的测试变体。交02验证最低1.1.0源码兼容，增加同plugin内两个parser能力不同的fixture，以及已证明隔离/未知全局副作用两种场景；交17检验默认compat安全单位完整解析、无证明整会话回退与显式strict原子拒绝；尚无editing接口时仅记录未接入，不伪造通过。

**新增必做（2026-10-22）：** 在释放02前冻结batch性能测量协议：同机器/工具链/依赖/输入、同`-O2`构建，配对重复测量parse(String)与parse(InputStream)的parse-only耗时/吞吐、可观测分配/GC和peak/steady RSS；小文档固定成本与大文档吞吐均覆盖，渲染/CLI启动另栏。保存样本、预热、噪声/置信区间与原始结果，并确定后继逐阶段复测命令。用户目标为噪声之外无可测减速，具体判据/预算须实施前冻结，不自行设可接受回退百分比。

1. 重录`git rev-parse HEAD`、`git status --short`、`git diff --stat`、`cjc --version`、`cjpm --version`、操作系统/CPU/内存与依赖解析信息。保留[dirty快照](00-design-locks.md)中的全部修改，不reset或暂存；若实际最低版本验证环境不是1.1.0，单列缺口，不能提高最低版本。
2. 建立30插件与bundle/config fixtures清单，复用ParseModeFixture制造rune边界、单byte chunk、CRLF跨chunk、EOF无newline与finalize后输出。记录当前四模式观察值及差异，不事先声称它们全部相同。
3. 新增独立完整比较器：typed类别/字段、children顺序、所有语义metadata、raw/provenance与映射、三格式输出、patch顺序分别检查。独立fresh会话的NodeId可不同，按结构/provenance对齐后检查；编辑会话稳定ID/唯一ID另作强断言，不可全局忽略ID和span。
4. 新增编辑脚本runner和reference text model：按每步合法坐标生成新文本，调用全新Markit工厂得到fresh oracle，并收集每步结果；尚无生产editing时，用可替换被测adapter/明确未接入状态跑runner自测，不能调用fresh parse冒充editing实现。
5. 建立“已知现有语义”与“必须纠正的基础设施差异”表。每条包含最小输入、模式、实际输出/错误坐标/重复ID、影响、拟修任务、明确预期。语义bug保持基线；坐标/ID纠错允许精确、经审查的差异迁移，禁止宽泛忽略全部span或更新所有golden。
6. 定义测试计数事件和可注入collector：源读取/全文materialize、rope访问、probe/parse/finalize、checkpoint/重用、语义效果撤销/重放与正负依赖、renderer/cache、CodeHL行、公式parse、图layout、项目文件扫描、worker启动、DOM patch。当前不可接入项目标为“不具备观测”而非零调用；生产hook由02及后续任务接入。
7. 提供冷启动与warm编辑负载：短/长paragraph、nested items、table rows、code lines、文首/中/尾、跨块与未闭合结构。确定seed、编辑位置/内容、规模、预热和输出格式；新的EditingBenchmarks名称/tag是拟新增。旧stream数字只留在legacy栏，拟议p95目标未实测。

## Acceptance

- **新增硬门槛：** batch `-O2`基线及测量协议可复现，预算已经冻结并附证据；无分配观测能力时明确缺口与替代指标，不记作零。未完成不得仅靠编辑负载放行02。

- 四模式最小输入至少包含中文+emoji+CRLF、多byte切分、pending paragraph、ClosedAndReprocess、forward reference/finalizer；基线runner可复现，失败和现有差异完整保存。
- 小型可跑验收：对`甲😀\r\n\r\n正文`执行插入、替换、删除、撤销四步；reference model与每步fresh会话一致。故意破坏children metadata或漏掉一条patch，比较器必须失败；不能只比较HTML。
- duplicateID和错误source map最小fixture由独立不变量检出；其基线条目精准列明后续基础设施纠错，未通过不得被测试skip掩盖。
- fresh oracle每步新建会话，上一轮symbol table/cache不能污染；被测editing adapter的ID稳定检查与fresh结构对齐分开。
- 计数设施自测能区分未接入与真实零调用，禁止把mock事件数当生产性能证据。计数schema交给02，后继任务可用相同格式记录工作量。
- legacy测试/基准结果与未来editing结果分栏；最低仓颉1.1.0兼容的实际验证或环境缺口有记录。没有源码语义修复、dirty丢失、Git提交或README进度修改。

## Verification Record

- 本轮：仅静态读取ParseModeTestKit、IncrementalSession、Node、DocumentSnapshot、source及相关插件；本任务尚未实施，未运行新oracle/编辑/性能测试。
- 未来从仓库根执行`git rev-parse HEAD`、`git status --short`、`git diff --stat`、`cjc --version`、`cjpm --version`，保存实际结果及失败原因。
- 未来在`markit/`执行现有`cjpm test --no-progress`和`cjpm test --no-progress --include-tags=Streaming`，记录退出码/摘要。
- 拟新增：`cjpm test --no-progress --include-tags=EditingOracle`与`cjpm bench --filter=EditingBenchmarks`。实现对应tag/benchmark后再执行；不得把当前不存在的入口写成通过。


## 2026-10-23 修订范围完成与交接

**结论：Task01 按用户最新裁剪范围 Done，待 root 审查更新 README。** 结束基线/通用框架扩展，后继直接执行产品 Task02。旧章中的扩大 Acceptance 和“未来”命令是历史记录，以本节为当前验收口径。

| 修订后验收 | 实际证据与结论 |
|---|---|
| 当前代码与环境有记录，保护用户工作 | 起始 clean `c510aee2e5bbbdb04402cb26bbca6679515a16f4`；当前SDK 1.3.0-alpha.20260920003052 / cjpm1.3.0-alpha.05，x86_64 Windows；i7-8700、12逻辑CPU、物理内存34123063296 bytes。未改生产解析器/CLI/kit/extension src、未暂存提交推送；扩展测试修复由独立已授权 owner 执行。 |
| 留下已实测同-O2时间及最小driver | `task01-performance/batch_driver.cj` 为实际公共 parse(String/InputStream) driver；现有 `-O2 -Woff unused` 不变。12进程/1008 parse-only样本；小120 bytes String/Stream median25.467/26.916us，大62462 bytes median27.784/27.844ms。渲染/CLI启动不在timed region，不是editing延迟。原始样本、命令及限制见 v2 evidence-report。 |
| 定向真实验证与全量对照，不谎报未执行 | 原有27包官方console 569pass；新增设施编译exit0并全27包592pass/0fail/0error/0skip；EditingOracle筛选23pass（18工具自测+5legacy），27旧unit仅tag未选中；Streaming筛选15pass，其余未选中。原cjpm runner10013与前两次编译错误保留；源码移出后的树未再次测试，未冒称新状态通过。 |
| 当前旧式插件/四模式最小fixture可供后继 | 37组×4=148条真实记录；五类最终输出逐组一致，3组stream emittedHtml差异及protected HTML duplicate ID2精确保留。旧式双parser第三方源码已冻结，只有实际parse/append证据，没有editing能力声明或隔离证明。 |
| 现有预览行为保护证据保留 | 独立Windows harness最终73 tests，67pass/0fail/6既有skip；5 native/1 Chromium环境项未伪称通过，见其report。 |
| 已裁剪工作不阻塞产品 | 正式1.1.0依赖重建/兼容矩阵、通用oracle/计数/benchmark扩展与未完成developer @Bench验证统一 **Deferred by user scope**。已取得正式cjc1.1.0版本，但cjpm查询0xC0000005，未构建项目，不是最低兼容通过。独立与集成 @Bench 都有exit3/runtime fatal，不改写为Passed。 |

### 可恢复收起的本次新增源码

为避免通用测试框架成为后续产品改动的编译/维护前置依赖，仅将本次新增且未跟踪的 `editing_oracle_kit.cj`、`editing_oracle_test.cj`、`editing_batch_baseline_benchmarks.cj` 移至 `task01-deferred-scope/markit/src/tests/...`，没有永久删除，移动前后SHA256一致；完整清单见 [move-manifest.json](task01-deferred-scope/move-manifest.json)。保留本次新增的 `editing_legacy_fixture.cj`、`editing_legacy_baseline_test.cj` 作为已通过的最小fixture。后继无需集成、恢复或继续完善大框架。过去592/23等运行记录绑定当时的binary/source，移动后未新增回归。

### 后继仅需使用的输入

- 当前产品事实与精确纠错：[148条观察报告](task01-legacy/report.md)、[known corrections](task01-legacy/known-corrections.md)、旧式第三方fixture冻结记录。
- 同环境/O2参考：[v2实际时间与限制](task01-performance/baseline-v2-long-block-20261023/evidence-report.md)、实际 `batch_driver.cj` 与 `build-driver.ps1` 命令记录。旧复杂校准框架可参考，不再强制接通；没有新的候选产品性能结论。
- 继续保持SeaJson选型、parser可选能力/安全回退、生产typed renderer类型保真与必要定向验证；不以延期的通用观测接口阻塞产品。
- Task02是否放行及README百分比由root依据本次修订范围审查，不由子agent自行宣布；Task03–16保持产品DAG，Task16后停止验收。
