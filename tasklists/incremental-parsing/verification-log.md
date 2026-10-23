# 验证记录

<!-- delivery-stop-2026-10-23:start -->
## 当前交付状态：用户要求立即停止并提交现状（2026-10-23）

用户最新指令是“记录问题，然后马上提交推送，不要改代码了”。本轮停止新增功能、源码修复、构建和测试；保留当前部分实现，按 WIP 现状交付，不继续 Task07，也不进入 Task08/09。此前“完成全部07后停止”“Task16后验收”及“不得提交推送”属于历史阶段约束，已被本次明确指令覆盖。提交与推送由交付 owner 执行，本文不代表它们已经成功。

- Task01–06 已按当时修订范围验收：Task06 官方定向 25/25、全量 27 包 717/717；冻结第三方 148 条记录 × 11 字段零差。此结论绑定当时源码，不能继承为最新 Task07 源码通过。
- Task07 状态为 **Paused (partial)**，完整 Standard 插件验收为 **0/13**。有限证据仅为各自冻结版本的核心定向 21/21、InlinePlan helper 3/3、source-only stdio 探针 16/16；后者没有证明真实 provider/render 纵切完成。
- Paragraph 首轮官方 3 例为 **0 passed / 2 failed / 1 error**。编辑快照导出的 HTML 缺少 `<p>`；巨长文本的不等比较触发测试库差分报告 OOM，不是已经证实的产品热路径 OOM。已定位 editing 入口缺少 root render hooks；中断的 Markit 补丁未落盘，本轮不再修复。
- 当前明确构建阻塞：pilot factory 引用了尚未创建的 renderer 函数；Reference 新源码引用尚未实现的 `StandardRawSpellingProof` / `standardNormalizedRaw`。最新工作树没有完整 whole 构建通过的结果。
- 最新 read-refresh、离散 semantic replay、Paragraph boundary 等改动尚未一致编译验证。多 range / 多 source epoch batch、跨行与 mapped raw proof、含 escape 的超长逻辑 Text 局部性、真实跨插件 fresh 与 snapshot 原子性仍未完成，不能标为 Passed。

以下原计划、旧状态说明和历史日志继续保留作为追溯材料；与本说明冲突的继续实施指令不再生效。不通过新测试或改动断言来掩盖已记录的问题。
<!-- delivery-stop-2026-10-23:end -->

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

更新：2026-10-21。当前证据只来自源码静态调查、文档编写与文档静态完整性检查；解析器实现、原型运行、运行期测试和编辑性能验收均未开始。编号任务全部Pending，README进度只能由协调者审查后更新。

## 2026-10-21：源码与输入基线静态调查

- Scope：仓库当前工作树、插件注册与bundle、append解析和预览链路。
- Evidence：执行`rg --files markit/src/plugins -g '*_plugin.cj'`，清单为30个：Standard13、CommonMark5、GFM9、横向3；逐插件parser/state/filter/finalizer/renderer依据见[Standard/CommonMark](plugin-standard-commonmark.md)、[GFM](plugin-gfm.md)、[横向](plugin-cross-cutting.md)。SoftBreak归Paragraph，Mermaid由FencedCodeBlock接入，均不另计Plugin。
- Evidence：读取`markit/src/core/plugin/plugin_registrar.cj::PluginRegistrar`、`markit/src/markit.cj::Markit.createSession/MarkitRuntimePlan`、`core/incremental/incremental_session.cj::feed/feedBytes/finalize`、`core/block/block_tree_builder.cj::parseLines`。现状是append解析；快照/恢复、editing facets、事务边界不是已完成能力。
- Evidence：读取`SessionStateSnapshot`、`Node`、`DocumentSnapshot`、`SourceBuffer/LineIndex/SyntheticSourceBuilder`，确认名称型state snapshot、顺序NodeId、全树snapshot索引、synthetic映射及破坏性finalizer等前置问题。结论是静态缺口，不是运行期复现通过。
- Result：静态盘点完成；未构建、未运行新parser/codec/事务原型、未测任何editing延迟或局部性。后续由01先建立可复现基线，02–06关闭基础设施缺口。

## 2026-10-21：legacy测试与现有预览路径定位

- Evidence：读取`markit/src/tests/utils/parse_mode_test_kit.cj::ParseModeTestKit.collect`，已有direct-parse、incremental-string、incremental-bytes、input-stream；`markit/src/tests/unit/streaming/incremental_state_tests.cj`覆盖pending/基本snapshot/forward-reference final patch。
- Evidence：`docs/advanced/testing-benchmark.md`记录现有`cjpm test --no-progress`、Streaming tag和ParserBenchmarks/SharedFixtureBenchmarks等命令。只核实入口，**本轮未执行**；旧stream benchmark不作为editing证据。
- Evidence：`vscode-extension/src/session.js::PreviewSession.render`调用`spawn`启动`render ... --page`，后续render可加`--incremental true`复用资产；这不是持久解析worker。`src/extension.js::onDidChangeTextDocument`向sync传`event.document.getText()`；此处是当前全文取值路径。
- Evidence：`markit-kit/src/renderers/markdown_renderer.cj::renderWebsite`先调用`HeadingStateScanner.scanAndComputeStates`，随后按renderOnlyFile筛选renderFiles；当前单页渲染仍进行项目标题扫描。`markit-cli/src/commands/render.cj`已有`--page/--incremental`工作树变更。
- Evidence：`vscode-extension/package.json`已有`test: node --test test/*.test.js`，现有session/document/projects/selection测试路径可定位。**未运行npm/node/VSIX测试或native集成**。
- Result：legacy/预览基线定位完成；未来15/16需替换编辑热路径，保留现有功能与用户修改，不把page-only当editing完成。

## 2026-10-21：dirty保护与本地方案排除

- Evidence：`git diff --stat`静态快照为6个已跟踪文件、59行增加/5行删除：`README.md`、`markit-cli/README.md`、`markit-cli/src/commands/render.cj`、`markit-kit/src/models/global_context.cj`、`markit-kit/src/renderers/markdown_renderer.cj`、`readme-zh_CN.md`。这些属于实施前既有修改，非本方案实现。
- Evidence：初始`git status --short`另有`.config/`、`log.txt`、`vscode-extension/`未跟踪；该快照及后续用户变化都必须保留，后继每次重录，不据旧列表清理内容。
- Evidence：协调者已创建`.git/info/exclude`中的`/tasklists/`本地规则；本次只读核实该行。未修改共享`.gitignore`，不跟踪或提交方案。
- Evidence：对已交付的Standard清单、设计锁、范围文件及01–06逐文件执行`git check-ignore`有输出；局部结构检查显示01–06每份有Pending及六个必需章节，18插件清单有18组事实/契约/验收。此项只证明当时这些文档的局部结构与ignore，不代替最终全目录核验。
- Result：只写授权方案文件；未开始产品实现、未commit/push，保留dirty。未来01开始前必须重新保存HEAD/dirty/工具链，不把当时stat当实现成果。

## 2026-10-21：设计与任务交接文档

- Scope：设计锁、18+9+3插件清单、18任务DAG及跟踪文件；文档由不同子agent按授权所有权并行编写，root负责审查和排程。
- Result：冻结全部30插件facet、仓颉1.1.0、typed codec原型、组合source map、稳定身份、完整state/owner effects、已ack源码不随cancel回滚、长logical Text内部局部化、持久worker/索引/renderer/DOM与重型单元调用门槛。这些是**未来验收约束**，不是实现或性能通过。
- Follow-up：02的小型codec原型、05真实checkpoint事务原型、各插件facet、17独立差分/workcount/延迟/RSS均待实施；拟新增tag/tool尚不存在时必须保持“待新增”。
- 局部文档自查：对02/04/06与三份tracking共6份文档用PowerShell提取Markdown本地链接并Test-Path，缺失0；从implementation-order提取hard edge为22。三个tracking逐文件`git check-ignore`均有输出。这只是该作者范围自查，最终28文件/DAG/ignore综合结果见下节。

## 2026-10-21：协调者最终综合检查

协调者实际执行：PowerShell单引号here-string经`py -3.11 -B -`运行Python；Path遍历28份Markdown，去code fence/inline code后提取本地链接，resolve目标与GitHub式heading slug；检查01–18的Pending、六章节、owner/scope、Deps/Unlocks并比对README，解析22条hard edges并做Kahn拓扑；按`*_plugin.cj`正式Plugin类对照三份清单逐节覆盖。另运行`git ls-files -- tasklists`、向`git check-ignore --stdin`输入全部28路径，以及HEAD/status/numstat检查。

实际结果：`docs=28, tasks=18, pending=18, hard_edges=22, acyclic_nodes=18, plugins=30, groups=[18,9,3], local_links=221, fragment_issues=0, ignored_docs=28, tracked_tasklists=false, errors=[]`。独立只读交叉复核通过，无新增实质矛盾。

| 检查 | 当前状态 | 实际证据 |
|---|---|---|
| 全文档链接及目标完整性 | 通过（文档检查） | 28文档、221本地链接，fragment问题0，errors为空 |
| README与18任务依赖/Unlocks、DAG无环、22条hard edges | 通过（文档检查） | 18 Pending任务章节/owner/scope/依赖交接通过；22边、18节点拓扑无环 |
| 所有方案文件均由本地exclude忽略、无已跟踪tasklist | 通过 | 28/28忽略，`git ls-files -- tasklists`为空 |
| 工作树保护、无实现变更/提交 | 调查基线未变 | HEAD仍`795a0e835b0e0ab6433f594e8603dbec0f28e2dc`；numstat仍6文件59+/5-；status无tasklists，既有modified6及未跟踪log.txt/vscode-extension |

早期`.config/`在最终status未显示，不据此归因或执行操作。未build/test、未commit/push。上述通过仅为方案完整性与工作树检查，21项实现缺口和全部编号实现任务仍Pending，无新解析原型、运行期或性能通过结论。

跟踪文档收尾后复查：219链接目标存在、28文件忽略、旧目录不存在

磁盘事件：C盘可用空间为0时写入失败，log曾截为0字节，随后恢复为7,459字节。用户自行清理C:/Users/Shawn/Documents/cpl/.git/lfs/tmp后，据协调者记录恢复约39GiB可用，本次复核37.38GiB；方案目录临时压缩已由协调者还原。约0.3MB方案并非约30GB占用的来源。未删除用户文件、未改实现或提交。


## 2026-10-23 本地同步与 Task01 执行中

- 同步来源：用户自行下载的 `../markit-tasklists-latest-folder-2026-10-23.json`，359959 bytes，SHA256 `01fa0b048906e6b5b9e7eb26ca21a832d694ad6da5057a793996d13b1fdba524`。其恢复来源为已保存评审版与后续明确修订；未声称与丢失云端原文件逐字节一致。
- 同步核验：29文件/351155 bytes，全部UTF-8内容大小与SHA256匹配；重复JSON键、大小写路径冲突、相对路径逃逸及符号链接检查通过，仅写 incremental-parsing。旧28文件在同步前完整备份并逐文件字节一致。
- 备份后续：用户明确授权后，root将本次两份旧计划备份及附带校验JSON清单移至Windows回收站，原路径不存在，未清空回收站、未永久删除。旧sync-report也已回收，不能再当现存文件链接；本条保留此前核验事实。用户下载JSON与新计划保留。
- root复核计划：18编号任务、22条DAG边无环。首轮naive链接扫描把代码示例 `[u](u)` 误当文件而exit1；排除fenced/inline代码后实际231个prose内部链接，missing=[]/exit0。恢复源先前124计数与该次231计数口径不同，未声称相同。
- 起始源代码HEAD `c510aee2e5bbbdb04402cb26bbca6679515a16f4`，Git clean；已确认当前只有1.3.0-alpha及若干更旧/beta SDK，未找到正式1.1.0，G01保持开放，详见[本机环境](task01-baseline/environment.md)。
- 原始 `markit/` 下 `cjpm test --no-progress`：exit1，27 package ERROR、0pass，全部在std.unittest runner的TCP transport连接报Windows SocketException10013，未执行断言，不冒称测试失败或跳过通过。原始证据[legacy-full-test.log](task01-baseline/legacy-full-test.log)。
- 安全替代：官方生成test executable自身 `--help` 支持直接console运行；未修改framework或安全设置。`python task01-baseline/run-legacy-console.py`依次执行27个原有package binary，27/27 exit0、569 tests pass/0fail/0error/0skip；每包命令、binary SHA256和输出见[summary.json](task01-baseline/legacy-console/summary.json)。该轮binary在新增源码安装前编译，不作为新增设施通过证据。
- 初次扩展完整回归exit1（72项42pass24fail6skip）：无扩展名POSIX fake executable直接spawn在Windows ENOENT；后续45项子集39pass2fail4skip，明确2项sandbox temp atomic rename EPERM。保留原始失败日志，不全部归为同一原因。
- 纯保护子集exit0：36项34pass0fail2skip，覆盖当前映射/复制/动画等Node可执行逻辑，未证明被skip的native/真实DOM。
- 用户授权独立Windows harness owner修复测试可移植性；其最终 `npm test` exit0：73项67pass0fail6原有skip，额外真实逐UTF8-byte pipe测试。仅改扩展测试及新helper，生产src未变。完整证据[Windows harness报告](task01-windows-harness/report.md)。5项native与1项Chromium既有skip仍是缺口。
- 新设施首编 `cjpm test --no-run --no-progress`：exit1，oracle typed观察器3处enum缺少toString；已交原owner以显式match修复，未去掉字段或放宽断言。保留[new-facilities-compile.log](task01-baseline/new-facilities-compile.log)。
- 性能探索与首idle校准均保存原始结果；root尚未批准宽噪声分辨率。发现getGCFreedSize为累计计数，owner正在改pre/post delta并重测，不能把snapshot当每样本分配。生产editing未连接，mock/runner自测不计为真实editing或局部性证据。
- 当前状态：Task01 In Progress，Task02未放行。root唯一维护README进度；三个子owner只修改互斥测试/benchmark文件，shared cjpm build/test串行。


## 2026-10-23 Task01 用户裁剪后 Done（待root审查）

- 用户明确裁剪：停止最低SDK兼容补齐及通用oracle/计数/benchmark扩展，未验证/取消项标 `Deferred by user scope`，不得以这些旧门槛阻塞产品Task02–16。已在00/01、implementation-order、review补充、verification-log/gaps与03–18任务头部加优先说明；未编辑02或README。
- 新设施编译：第一轮3个enum.toString错误、第二轮legacy保留字quote错误均保留原日志，owner修正后第三轮 `cjpm test --no-run --no-progress` exit0。
- 第三轮编译对应的正式console产物：27包592pass/0fail/0error/0skip；EditingOracle选中23pass（18工具自测+5legacy），Streaming选中15pass。所有tag未选中数量与实际skip区别记录。见[完整汇总](task01-baseline/new-facilities-full-console/summary.json)、[tag汇总](task01-baseline/editing-oracle-console/summary.json)、[Streaming汇总](task01-baseline/streaming-console/summary.json)。
- 真实legacy归纳：37组/148条/四模式完整，30Plugin inventory一致；最终HTML/Markdown/Typst/JSON/tree逐组相同，3组emittedHtml观察差异、HTML protected duplicateID2未被忽略。证据[report](task01-legacy/report.md)、[纠错表](task01-legacy/known-corrections.md)。
- 已测-O2参考：当前1.3-alpha SDK、i7-8700、120/62462-byte输入、12进程1008样本；String/Stream小median25.467/26.916us，大27.784/27.844ms；实际driver和参数、原始样本及CPU限制均保留。root先前批准的四组绝对noise仅当前SDK参考，不是候选无退化证明。通用校准/比较工程不再为后继强制依赖。
- developer @Bench：独立test编译通过但运行exit3；正式集成binary实际运行亦exit3，`F Check failed: module != nullptr`，日志[integrated-benchmark.log](task01-baseline/integrated-benchmark.log)。该失败未修复、未伪称通过，按用户裁剪延期，不再追加benchmark。
- 正式最低SDK：官方ZIP hash核验、cjc1.1.0版本查询成功，但cjpm在常规/隔离PATH及已批准执行方式均0xC0000005，无项目构建验证。详见task01-sdk-source既有证据；本项 `Deferred by user scope`，不以新SDK工作阻塞产品。
- 仅将本次新增3份通用oracle/benchmark源码移至task01-deferred-scope，可恢复且SHA256一致，未删用户文件；保留2份已通过的最小legacy/第三方fixture。原592/23测试描述移动前已验证的binary/source；移动后未再跑测试或benchmark，不声称移动后树已重测。
- Task01在**修订范围**标Done。root审查后更新README并放行Task02；其他产品依赖保留，Task16完成验证后停止等用户验收，禁止自动开始17/18或提交推送。

## 2026-10-23 Task02 产品契约验收与并行A放行

- root已实际审查Task02修订范围，任务文档标Done；交付与全部证据索引见[final-report](task02-contracts/final-report.md)，接口/文件所有权见[ownership](task02-ownership.md)。共享core.editing只依赖std；03/04不各自修改共享契约，缺口交02 owner串行处理。
- 最终集成`cjpm test --no-run --no-progress`退出0；官方console的EditingContracts 19/19、TypedCodecPrototype 6/6均通过，无失败/错误。全量27包599/599通过，无失败/错误/跳过，见[全量summary](task01-baseline/task02-full-console-1/summary.json)。先前编译失败和错误paragraph推断的测试失败保留原日志；真实调度复核后移除phantom fallback，不改legacy语法。
- 同SDK、同输入、同-O2最小driver构建candidate后，reference→candidate与反向candidate→reference各执行一次，每个binary每次84样本且均exit0。[首方向](task02-contracts/batch-time-comparison.json)的小输入偏慢在[反方向](task02-contracts/batch-time-comparison-reverse.json)未复现；大输入约28ms。原始样本完整保留，不作统计无退化或零成本保证；不继续扩展基线设施。
- 正式1.1.0验证和通用测试/benchmark框架由用户取消，标Deferred by user scope，绝非Passed。实际使用1.3.0-alpha。全部30内置仍须后续真实增量适配，Task02默认false/安全fallback只保外部第三方，当前内置完成0/30。
- 并行A已由root实际启动Task03 source和Task04 tree，各有互斥maps/effects子责任。02 owner协调共享target单写编译：四个owner源码/test均source-ready冻结后才全项目构建；独立包验证须使用独立输出且不得读其他owner半写源码。README只由root维护。Task16验收后停止、不进入17/18、不commit/push的边界不变。

## 2026-10-23 并行A首轮独立验证（尚未放行Task05）

- Task03 source/map以最终冻结editing模块为依赖，独立输出到`task03-source/source-package-2`；产品/官方test编译均exit0，先后两次11/11通过。第二次补真实CR-X-LF删除join、插入split，原日志保留。
- Task03随后按review加入固定2048项anchor投影缓存，跨旧目标仍从出生版本重放，不从被clamp的新投影倒推；历史delta无prune、cold历史查询成本如实交接。共享首次实际编译发现新slot初始化的None绑定SourceRetentionMode而非Option，3errors保留在`parallel-a-verification/integrated-compile-2.log`。此前compile-1为协调者误用不存在的cjpm路径、编译未启动，日志明确记录，不能计为通过。
- 修正Option后，Task03最终独立`source-package-3`产品编译exit0、官方tests编译exit0，13/13通过（0失败/错误/跳过），新case含200次编辑的增量anchor推进、缓存上限、跨文档/affinity隔离及历史clamp回访，见[source测试3](task03-source/source-targeted-test-3.log)。这些尚不替代最终共享全量回归。
- Task04 effects/cache两份新产品仅依赖std及editing，独立partial session模块编译exit0。测试链式cast赋值不符当前语法导致首编1error，owner等价拆local后官方test编译exit0、9/9通过（0失败/错误/跳过），见[effects测试](task04-effects/effects-targeted-test-1.log)。未接真实source生命周期，不因此宣称Task04或05完成。
- Task04 tree已source-ready后，review确认混合不同出生版本子树使区间summaries失效的性能缺口，owner定向修更新路径归一化及同byte affinity；相应三文件暂撤回ready。最终共享构建须等重新冻结，Task03/04此刻均未标Done，Task05未放行。

## 2026-10-23 并行A最终共享编译与真实回归

- 04通过冻结Source抽象仅重建更新路径的区间摘要，保留旧子树/anchor共享；同byte范围min选Before、max选After。新增真实rope的256siblings/128分散编辑定向case，保留局部查询resolver访问少于100次门槛。
- 最终共享命令`cjpm test --no-run --no-progress`（cwd `markit/`）exit0，精确命令与退出标记见`parallel-a-verification/integrated-compile-6-command.json`及[integrated-compile-6.log](parallel-a-verification/integrated-compile-6.log)。先前doc构造器helper过早访问、test refEq接口类型错误均由owner最小修正，原编译3/4失败日志保留。
- 首次PersistentTree实跑10pass/1fail：mixedbirth case期望4遗漏After亲和与既有inclusive区间端点。实际节点应为`[0,252,253,254,255]`；owner补逐节点真实source.resolve位置断言及全257node小reference精确ID对照，在reference后清零counter、原访问阈值不变，产品未改。复跑[PersistentTree测试2](parallel-a-verification/persistent-tree-test-2.log)为11/11pass，0failed/error，exit0；66为tag未选择，不计产品跳过。
- 共享OwnerEffects官方tag9/9pass，0failed/error；共享source包21/21pass（新增13+原8 SourceView），0failed/error/skip。日志分别为`parallel-a-verification/owner-effects-test-1.log`、`source-package-test-1.log`。最后仅测试reference变更后不重复跑这两组，由最终全量覆盖。
- 最终一次官方console全量：使用既有`run-legacy-console.py --output-name parallel-a-full-console-1`，Python为用户本机`C:\Users\Shawn\AppData\Local\Programs\Python\Python311\python.exe`；27包均exit0，632pass、0skip/error/failed。全部commands、binary SHA256与raw logs见[全量summary](task01-baseline/parallel-a-full-console-1/summary.json)。其中Unit77、Source21、Streaming15；未跳过已知失败再宣称通过。
- 当前产品与测试源码冻结；04最小同-O2 driver占唯一计时窗口，最终数值由其report记录。Task03/04是否Done及Task05放行由root依据最终报告审核，不能把本全量回归当30内置已适配或05事务已集成。

### 并行A最小-O2窗口结束

- 03最终driver使用`source-package-3`及冻结editing，compile0/run0，每轮400替换的完整expected结果对照通过。原始[CSV](task03-source/local-edit-time-final.csv)覆盖16KiB、256KiB、1MiB及两种执行顺序；无扩充采样。2048项缓存与历史回放成本/无prune边界保留在03交接，不从局部计时推断任意历史查询有固定成本。
- 04最终driver使用同1.3.0-alpha SDK、`-O2 --static-std`，compile0/run0，树fresh完整值和String全文结果对照全部通过。4096节点/120替换的local为0.492/0.267ms，fresh为466.556/422.729ms；1MiB逻辑Text/400替换local1.041/0.921ms、全文String208.273/211.996ms。全部16KiB/256KiB/1MiB与正反原始数据、命令、输入/二进制hash见[CSV](task04-tree/local-edit-time.csv)、`timing-compile-args.json`、`timing-inputs.json`、`timing-driver-hashes.json`、`timing-sdk.log`。
- 这些是同条件下最小存储操作记录，并非统计无退化证明或整条parser性能结论。计时窗口结束后无运行进程；协调者再次`git diff --check`exit0。Task03/04最终审核与05集成放行仍由root确认。

## 2026-10-23 Task05 首阶段产品与独立类型编译（运行验证尚未开始）

- root已实际验收03/04，放行Task05主engine及session checkpoint/source lifecycle并行责任；04 owner另独占prepared tree/effects、child splice及anchor birth聚合的串行更正。共享`core/editing`仍由02唯一维护，当前未收到必须修改的精确缺口，未扩通用框架或最低SDK验证。
- 主owner落盘`core/block/block_parsing_kernel.cj`，batch `BlockTreeBuilder`与append `IncrementalSession`改为共用内核。首审发现收集结果延后emit会改变ClosedAndReprocess的root/filter/callback可见性，已改同步sink：finalize→emit→重处理，且batch不每行分配新结果容器。即时emit可观测测试与完整运行验证尚待后续冻结。
- 阶段编译固定原tracked block源码+新增kernel，以及原tracked incremental源码；不把主组正在写的新editing文件、session/source或04半写实现纳入编译。只使用并行A最终冻结cjo依赖，输出专属`task05-verification/kernel-stage-3/{block,incremental}`，未写共享target，不用旧Markit布局混新IncrementalSession运行。
- kernel首次有效类型检查发现head未明确`?Byte`的Option泛型推导错误（5errors含派生），owner最小修后block compile3 exit0、incremental compile1 exit0。原compile1协调者漏传seajson传递import path、compile2真实诊断均保留；精确输入/flags及exit见`task05-verification/kernel-*-compile-*-args.json`与对应log。
- source lifecycle组冻结`core/source/{editable_source,line_index,source_buffer}.cj`、`core/session/{persistent_cache,editable_source_lifecycle}.cj`及6项SourceRetention测试。core/source独立输出`task05-verification/source-stage-1`，实际compile exit0，见[source compile1](task05-verification/source-package-compile-1.log)及args。session组仍未ready，因此未编bridge/tests、未运行新功能测试；source→session包环已避免，桥放session→source。
- pin/prune必须涵盖实际可达旧anchor/checkpoint出生版本，不能以新tree/source版本替代旧anchor epoch；当前树版本可能领先共享raw出生版本。这个真实生命周期接线仍由05实现验证，前述编译通过不证明事务、checkpoint或历史裁剪正确。

### Task05 修订后的基础验证与当前门槛

- source stage1的全局持久LineIndex会让legacy默认每行追加承担AVL路径分配，review后修为默认flat+逻辑prefix、显式editing promotion；flat snapshot/restore保持O(1)，旧分支首次写才复制prefix。成功release同时解除lease对store/retention强引用，失败仍可重试。最新`source-stage-2`独编exit0，旧stage1通过仅属旧版本，不为修订版背书。
- registry接线由02独占两行：`createSymbolTables(checkpointEnabled!:Bool=false)`传给state store；main editing显式true、旧入口默认false。factory容器/sandbox栈按需分配，不让默认batch维护编辑恢复工厂；`core/editing`公共契约本轮仍未改变。
- 只编source lifecycle两份冻结session源及对应test，不涉及ParseSession/Markit/04半写源码：产品编译exit0，test首次mutable closure capture错误保留并等价改控制盒。最终官方独立test编译2 exit0，[SourceRetention实跑](task05-verification/source-retention-test-1.log)为7/7pass，0failed/error/skip、exit0，覆盖cold raw epoch、prune/计数、cache及snapshot lease、release失败重试、flat/persistent分支与rope buffer。
- 完整session stage1实际None歧义7errors归各owner修正；stage2编译exit0。main发现早期cp restore截断共享root后不能前向恢复，新增editing专用工作root入口并保留legacy恢复失败原子性。随后加入lazy state sandbox及真实parserAttempt候选事务，stage3完整session编译exit0；尚不据此声明主编辑事务通过。
- 新nodes首编while(true)尾类型错误，04最小尾throw后nodes stage2编译exit0；document stage2及aux重复child修后的stage3编译exit0；block facet/kernel清sink修订版stage2编译exit0。所有阶段精确输入/依赖/退出在`task05-verification`，均用专属输出，未改共享target，不混旧Markit布局运行。
- main incremental首阶段仅两处None歧义，已归main显式Option修；root/A后续实际review推动fallback完整DocumentSnapshot、canStart候选事务、entry/expectedExit分离、grammar与semantic实际read分类、in-flight/checkpoint epoch pin、候选新树语义replay、重叠恢复单位以及传播取消界限。相应文件按owner撤ready/修后重冻，未将旧阶段compile0当新版通过。
- 当前主whole构建/运行门槛仍未关闭：04 nodes/document/atomic tests新增aux bundle与effect invalidated keys接线尚在写；main/block也按上述实际缺口调整。已具备独立稳定依赖的session tests先单独验证，最终须全部source-ready后统一构建、定向/fresh对照及一次全量。Task05未Done、Task06未放行。

- 稳定session12项已在aux/main尚未ready期间独立官方编译/运行：使用新session-stage3/source-stage2/nodes-stage2等一致基础产物，不引用Markit、不读aux半写源码。test编译exit0，[实跑](task05-verification/session-checkpoint-test-1.log)12/12pass、0failed/error/skip、exit0；包括真实candidate失败后下一候选、未触状态0snapshot、早/晚editing checkpoint不截断siblings、legacy前向拒绝、participant/nested失败回滚、foreign cp拒绝。首次两处mutable capture编译失败已等价控制盒修正，原日志保留。atomic/kernel/whole并未因此被跳过，仍等其最新依赖冻结。

### Task05 共享契约与位置恢复修订后的再验证

- 共享 IncrementalCheckpoint 的可变 provider payload 改为 private capturedPayload；构造时克隆、公开只读 getter 每次返回克隆，避免调用者通过旧 checkpoint 改写保存状态。既有 EditingValueContracts 中同时修改入参和 getter 返回值，再读取 fingerprint 保持原值。新 editing 独立编译 exit0，官方 test 编译 exit0、5/5 pass、0 failed/error/skip，见 [editing value 实跑](task05-verification/editing-value-test-1.log) 与 shared-editing-compile-1-args.json；旧依赖的通过只代表旧冻结版本，后续重新编译一致依赖。
- registry 的 createEditingPlan 新增默认 true 的 freezeOnAccepted 内参。执行式 editing 预检可以先构建未冻结计划，只有实际 BlockEditingFacet 执行能力检查成功后发布/冻结；main 对 lazy 默认 bundle 使用临时 registry，Strict 拒绝不能消耗后续自定义默认 bundle。此接线尚待主 whole/fresh 回归，不能仅接口修改写成已通过。
- 新 Source stage4 使用刚重编的 editing 依赖，产品独立 compile exit0，见 [source compile4](task05-verification/source-package-compile-4.log)。包含只读 rope LineIndex view 及 EOF coordinate 计数，避免 size 复制巨大末行；新增第8项 retention 断言以及 Session mapper/memory 第15项、Kernel 第5项仍待本轮实际运行。旧7/12项日志保留为历史版本事实。
- 所有构建仍使用已安装 1.3.0-alpha、专属输出，未运行额外 SDK 验证或新增通用框架。04 aux bundle 尚未冻结，主 whole 未开始，Task05 未完成。

- 本轮一致新 editing/source-stage4/session-stage5 依赖下，完整 Session 产品编译 exit0；官方 SourceRetention8 + SessionCheckpoint15 源码合编 exit0、[实跑23/23 pass](task05-verification/source-session-test-1.log)，0 failed/error/skip、exit0。包含 editable line view/EOF 不读取长末行、restore mapper 失败原子性、工作 checkpoint 不钉旧初始树与 workspace release；精确依赖/参数见 source-session-tests-compile-1-args.json。主 engine、aux 和 kernel 更新版仍待验证，不以这23项替代 whole。

### Task05 冻结核心闭包实际运行结果

- 更新的 nodes aux bundle 编译3 exit0、document ancestor-path 修后编译4 exit0、Session 清除持久 checkpoint 的 borrowed editingContext 后编译6 exit0、完整 Block 包编译5 exit0。均使用 shared-editing-stage1/source-stage4 与显式节点/文档输出，参数/退出标记保存在 task05-verification 对应 *-args.json/log。
- 官方 core 定向 test 首编仅2处新增 identity 断言把接口直接传 refEq 的类型错误；owner 等价 cast 具体 fixture class 后保持同一身份断言，未移除。第二编 exit0，[实跑37/37 pass](task05-verification/core-test-1.log)，0 failed/error/skip、exit0：SourceRetention8、SessionCheckpoint15、KernelCheckpoint5、AtomicStores9。Kernel 包括跨版本有状态 frame 几何映射及 ClosedAndReprocess 同步 sink 顺序；Session 新版恢复保留当前 participant、不钉旧工作上下文。
- doc 辅助祖先纯路径复制曾误加 removedNodeIds，可能撤销未重新解析祖先的 owned effects；04最小删该行，doc4 重编通过。aux owner 在既有4case加入真实 aux-parent10/child11 替换分支，精确断言 parent10 不被列 removed、其旧 effects 保留、child11 新 effects 可见、旧快照不变。官方 aux test 编译 exit0、[4/4 pass](task05-verification/aux-test-1.log)，0 failed/error/skip、exit0，覆盖共享引用、同ID更新及无外部根循环回收。
- 主 incremental 阶段2仅 while(true) 返回类型穷尽推导1error，最小尾 throw 后阶段3编译 exit0；这仍是类型检查，主15/prepare3/whole 尚待真正集成运行。release hook 失败可重试及已发布结果清理原子性正在 main 最小修，源码未冻结时不启动 whole。
- 用户新增统一安全主构造函数授权：本 owner 仅将 editing/plugin 自有5文件10个纯赋值 DTO 改同名 primary/member 参数；保持可见性、let、named/default、参数顺序。校验/clone/复杂构造器本批不变，普通下一次 whole 构建/回归验证，不把写法盘点当新门槛。前述 core37/aux4 明确为此次 style 修改前冻结源码事实。

### Task05 首次全项目构建与主链真实失败

- 所有当前 owner 声明冻结后，首次完整 `cjpm test --no-run --no-progress` 实际 exit0，见 [whole compile1](task05-verification/integrated-compile-1.log) 和 integrated-compile-1-command.json。构建静默约2分钟，未在未确定状态下重跑/终止；最终 tool 与文件均确认 exit0。该轮覆盖此前已落盘的主构造函数写法小批与所有 Task05 新源码。
- 官方集成 Unit binary 选择 BlockEditing：39项选中，37 pass / 2 failed / 0 error，98为 tag 未选中而非产品跳过；命令、binary SHA 与 [完整日志](task05-verification/editing-engine-test-1.log) 保留。准备阶段3、Kernel5、Session15以及主engine16中的14通过，包括回调重入、准备抛错清busy、过期epoch拒绝、语法/语义读取分流、独立facet身份、首空文档恢复、快照lease失败重试。
- 两个失败为 `nestedReplacementSharesOtherRawUnits` 与 `nestedSiblingInsertionAndDeletionUseSplice`：嵌套child更新后，父 EngineUnitNode 的 typed literal 保留旧 one，而 fresh 为 ONE（splice另有空行差）。未降低/移除 fresh 完整树断言；主owner与04讨论局部父payload更新接口，真实问题修复后再正常重编/重跑，暂不重复已知失败的全量。Task05 未完成、06未放行。
- 此正常修复窗口继续用户授权的安全 primary 写法：本 owner 额外10个 single constructor 仅 `init` 改同名 primary、原校验/clone/显式赋值顺序和body保持；加前批共5文件20类型。各独立库/工具/kit按其owner私有输出验证，markit whole 不被描述为覆盖这些独立项目。

- 后续诊断纠正：上述失败的父输出来自 `Node.toString()->rawContent()`，并非已证明 typed literal 字段错误。capture 将 source-derived raw 文本强制写成 override，旧祖先因而冻结原文；修复由04唯一拥有 Node/provenance 与 persistent capture/显式 legacy materialize，保显式 override/mapped source，不新增父语法重算协议、不在热编辑路径拼全文。首轮差异与误判记录保留，尚未据修复声称通过。

### Task05 第二轮构建、主链全通过与全量遗留回归

- 全部当前源依赖冻结后 whole2 编译 exit0，覆盖明确 codec opt-in + SourceBuffer exact identity + 无显式 override 才延迟导出 source raw 的修复。官方主链 [39/39 pass](task05-verification/editing-engine-test-2.log)，0 failed/error、exit0；98为 tag 未选。原 nested 两失败保原 toString 并增加 toJson fresh 全结果断言，现均通过。主16、prepare3、kernel5、session15均实跑通过。
- 随后一次全量27包：26包 exit0，691 pass / 1 failed / 0 error/skip，wrapper exit1。Unit137全部通过，包含新版 atomic9/aux4/source8及此前所有core测试；source包21、streaming15亦通过。唯一 legacy 回归 AutoAnchorTests.nestedParagraphsDoNotReceiveGenericBlockAnchorsAcrossModes：blockquote 多出 source byte20..27属性，四模式均差。原expected未改，见 [full summary](task01-baseline/task05-full-console-1/summary.json) 与对应 anchor raw log。
- 为核同源输出漂移，复用原 summarize_legacy.py 从本轮 Unit log 提取148实际records、37fixture/4mode完整，输出独立 legacy-comparison-1。再逐fixture/mode比较冻结01观察的 HTML、Markdown、Typst、ASTJson、tree、emittedHtml、duplicateIds、coordinateErrors、patch/update/config：仅 edge-2 四模式 ASTJson变化。Quote及其Text源偏移整体+8，Document end7变15；其余字段零差。原3组stream fragment差/已知protected重复ID保留。见 [冻结对照](task05-verification/legacy-comparison-1/versus-frozen01.json) 与 edge2-json-field-diff.json。
- main定位成功legacy nested从原仅depth还原改成完整syntax恢复，改变后续解析看到的activeLine/span；editing/sandbox必须完整恢复，但普通legacy成功分支需保原上下文。修由session唯一owner处理，异常原子恢复仍保。尚未写成通过；停止旧失败全量的无意义重复，修后正常编译/必要对照再全量。-O2 AB尚未开始。

### Task05 最终正确性闭环与同条件最小计时

- Session 保留 legacy 成功 nested 上下文、editing/sandbox 完整隔离、异常完整恢复的最小修后，whole3 `cjpm test --no-run --no-progress` exit0。[主链测试3](task05-verification/editing-engine-test-3.log)39/39 pass、[原Anchor测试](task05-verification/legacy-anchor-test-1.log)9/9 pass，均0 failed/error、exit0，原 expected 未改。
- 最终全量：[27包692/692 pass](task01-baseline/task05-full-console-2/summary.json)，27包均exit0、0 skipped/error/failed。Unit137全通过，含主16/prepare3/kernel5/session15/source8/atomic9/aux4及原测试；Source21、Streaming15亦通过。首次 full691/1 及最初 nested2 失败日志保留，不覆盖。
- 复用原提取器得到148 actual records、37fixture/4mode齐；逐 record 比冻结01的11字段（HTML/MD/Typst/ASTJson/tree/emittedHtml/duplicateIds/coordinateErrors/patch/update/config）**零差**，见 [冻结输出最终比较](task05-verification/legacy-comparison-2/versus-frozen01.json)。原3组fragment不等与已知protected重复ID仍原样，不把已知差异当新通过或删掉。第三方fixture及baseline两文件 SHA256 均与01冻结一致。
- 按root指示只跑原 v2 driver reference→candidate AB一次，原driver SHA b0e9d11b...be9、ref SHA1cf4fc98...7627明确核验；同SDK1.3.0-alpha、-O2、相同输入/21pairs/10warmup/内部ABBA、各84samples且exit0。候选构建与冻结libs清单位于 task01-performance/candidate-task05-product，未覆盖旧baseline。计时期间没有授权其他build/test并行。
- [原始AB比较](task05-verification/batch-time-comparison.json)：small String mean25.991→27.400us、Stream26.945→27.752us；large String27.252→26.451ms、Stream27.224→28.200ms。原始stdout CSV/stderr全部保留；单AB有快有慢，不称统计无退化或零成本证明，不追加采样/通用框架。root按既有noise边界审查，Task05是否Done由其最终验收。
- 所有本轮构建/运行进程已结束。此证据绑定whole3冻结源码；后续纯primary/独立kit工具库改动须普通正常构建回归，不能借本次markit运行冒称覆盖独立项目。正式1.1.0与通用框架仍用户取消，内置真实增量适配仍0/30，06未由本owner擅自放行，16后停止验收、不17/18、不commit/push边界保留。

- root 已实际审查 whole3、692 全量、148冻结对照零差及一次84+84样本AB，正式验收 Task05 在用户裁剪范围 Done。保留 small mean约3–5%偏慢、large约±4%的原始表，不称统计无退化；不追加采样/框架。主Task05文档/README状态由其owner/root更新。
- root 放行 Task06：main负责inline executable/dispatch/facet，source负责局部view/textwindow，session组负责persistent候选/failed-attempt索引。02继续共享editing契约唯一writer与构建单写协调；新接口有明确精确shape后才改。独立工具/kit正常验证用稳定依赖窗口，不阻06产品并行、不借markit692冒称整仓覆盖。全部内置尚未适配，16后停止验收边界继续有效。

### 主构造函数独立工具正常验证（不替代Task06）

- 协调者已实际读取 owner 的 commandline/fswatch commands+SHA+exit JSON 及每份官方 raw log summary，非仅口头报告：commandline 私有target3binary 共70/70，fswatch 私有target4binary 共55/55，均0skip/error/failed、各exit0。fswatch仅本机Windows，未声称其它平台native通过。证据 [commandline results](primary-constructors-verification/commandline-test-results-1.json)、[fswatch results](primary-constructors-verification/fswatch-test-results-1.json)。
- live-server 私有输出正常build日志明确 PRIMARY_LIVE_SERVER_BUILD_EXIT=0，未启动服务。dochir/CLI/kit依赖正在写的06源码，继续等待其稳定读取窗口；不拿markit692宣称其它独立工程均验证。三库由04按root授权单compiler隔离target正常测试，不触共享markit target。
- 此后04 6files8个header 与两个旧helper 4type 的纯写法变更已SOURCE_READY，晚于whole3，明确由06正常编译回归覆盖，不回写到05验证快照。冻结第三方fixture/baseline的01原hash仍保持。

## 2026-10-23 Task06 独立基础与首个真实类型反馈

- main/source/index三owner互斥写 core/inline 新执行facet、局部view与persistent候选/失败索引；共享 editing 仍由02唯一维护，暂不把editing拉入nodes/source包环。actual index 绑定document/version/mapping与parser实例identity，失败证据不随candidate回滚丢失，length metadata 与字符读取分开；sameepoch semantic replacingOwners 不伪造新source version。
- 用户明确同值let应折为主构造成员参数。02将安全SourceIdentity/Anchor/Range/Map等同值字段合并，clone/校验body保；实际 SDK 首编报 `regular parameters must come before member variable parameters`。为保持外部参数顺序与防alias，不为checkpoint payload/dependency clone等普通参数虚增存储字段；保其前缀显式赋值，仅可折末尾安全member后缀。编辑契约首编失败原 [editing compile1](task06-verification/editing-compile-1.log) 保留。
- 最小修后 new editing→source→nodes 专属 base-stage2 一致闭包均 compile exit0，参数/模块输出见 task06-verification/*-compile-2-args.json/log。涵盖本轮主构造成员参数及04 text sliced/concatenated 新API，避免旧CJO字段布局混用；未读main未冻结inline全包。
- 单独编冻结 inline_text_view.cj 的首轮 exit1，仅MappedInlineTextView constructor同一参数排序约束；source owner正最小修，原 inline-view-compile-1.log 保留，尚无新view tests运行通过声明。index原6case新增lengthReaders/sameepoch最小gate后重冻，待与view在稳定闭包独立编/实跑13，不等main session收尾。
- 三库独立正常验证已完成，summary实际读取：codehl74 + mathtex623 + mermaid4cj193 =890 pass，0skip/error/fail，各private compile与官方native exit0，150源/manifest/锁文件SHA无变化。codehl/mermaid自动锁升级保generated证据后恢复原字节。证据 [独立库summary](primary-library-verification/summary.json)；不拿markit692替代独立库运行，不新增框架/SDK门槛。

### Task06 已冻结基础产品的实际定向结果

- 首次完整 view/index 两产品类型编译暴露 Option 推导、构造期间访问未初始化成员及纯验证 helper 调用限制，owner按实际诊断修复，原失败日志保留。产品 inline-core-stage-2 compile0 后，测试先后遇到保留字 `foreign` 与接口直接 `refEq` 类型错误；仅等价变量改名及显式 Object cast，所有身份/拒绝断言保留。
- 官方单元 binary [13/13 pass](task06-verification/inline-core-test-1.log)，0 skip/error/fail、exit0：真实文本视图7和候选索引6。随后索引开放边界 fractional key 改为不增长顺序初建 key 深度，未更改内部邻居中点算法；新增最小共享 `LogicalTextSplice` 值契约记录旧 logical Text UTF8 区间与插入文本，不复制全文、非 raw source offset。
- 新 editing-stage-3、inline-core-stage-3 均 compile0；官方更新闭包 [18/18 pass](task06-verification/inline-core-test-2.log)，0 skip/error/fail、exit0，覆盖 view7/index6及原 EditingValues5（同 case 加入 splice 有效/非法范围断言）。命令、导入 cjo 路径和 binary SHA 在对应 args/command JSON，13旧版本结果不替代18新版本。
- main 阶段产品冻结后，私有 main-stage-1 的 source/nodes/document/session/block 五完整包依次 compile0；editing采用含 LogicalTextSplice 的 stage3，nodes含真实 sliced/concatenated API。该轮只是类型检查，不运行混合旧 Markit、不表示 Task06 引擎或全部内置插件已完成。main 的品牌校验/扩大恢复固定点等审查修正仍待新 SOURCE_READY 和实际引擎测试。
- source owner 在基础编译退出后短窗落盘11文件23类型主构造纯写法，最新 source 正常重编中；旧 main-source-compile-1 的通过只背书写法修改前快照。未新增风格专用验收阶段或测试框架。
- 最新 source 主构造11文件23类型正常重编 [main-source-compile-2](task06-verification/main-source-compile-2.log) exit0；不增加独立风格测试阶段。完整 inline 首次类型编译 [main-inline-compile-1](task06-verification/main-inline-compile-1.log) exit1，仅一处 `Option<PersistentDocumentVersion>` 不能协变为 `Option<PersistentSyntaxVersion>`（inline_editing_session.cj130）；owner采用显式 Option 接口映射修复，原捕获/alias协议不变。main容量中断由root确认无继续写者后，写锁已明确转04接手其既定三项审查修复和新测试，非访问拒绝；当前尚未证明主 inline 引擎通过。
- source 主构造后的一致 main-stage-2 已依次重编 source/nodes/document/session/render 五包，全 exit0；后续主链路仅引用该新闭包。早期 render1 独编漏传递 import 的命令错误已保留，补齐 seajson/markit.utils 后 stage1 日志另存 main-render-stage1-compile-2；非产品逻辑失败。
- 为 Strict 可执行能力预检增加 registry 只读 `inlineParsersForEditing()`，仅显式编辑调用时返回注册实例数组，不 freeze、不创建 session/source；主桥接 owner 将对实际 parser/facet身份与 grammar 做拒绝/运行期 guard。该新 seam 等待 plugin 正常类型编译和真实桥接用例，不写成已验证。
- root确认main容量中断后无继续写者，04接手最小inline修复；完整 inline 第二轮 [compile2](task06-verification/main-inline-compile-2.log) exit0，包含显式 Option 接口映射、私有会话品牌先拒 foreign、恢复窗口/read/opener 单调闭包及 literal-origin 索引合并边界。后续 nonidentity/recursive 运行门槛仍由04完成，类型通过不等于验收。
- 最新 registry readonly seam及主验证闭包接线，private main-stage-2 plugin/incremental 均 compile exit0。短暂Windows连接不可用时保留原session2789，root恢复普通环境并核进程后仅恢复该session取得两包实际exit0，没有重复未知执行。top Markit 此后仅读一致新运行时cjo+旧未改插件类型作入口类型检查，不用该阶段混合产物运行；最终whole重新生成全项目一致运行产物。
- 顶层 Markit [入口类型编译1](task06-verification/main-markit-compile-1.log) 也实际 exit0，真实 InlineEditingFacet 预检与 validateExecution 接口可编；此时主引擎/桥接新测试仍编写中，未计任何主用例通过。最终whole与fresh对照仍待执行，Task06未完成、内置适配仍0/30。

### Task06 首批主引擎真实运行

- 新 `task06_inline_engine_test.cj` 与同算法 legacy/editing grammar 官方编译首轮遇到变量 `foreign` 保留字，仅等价改为 foreignEngine，原7条级联诊断保留；第二轮 compile exit0。
- 一致 main-stage-2 核心闭包（不依赖旧 Markit/builtin）官方单元 binary [4/4 pass](task06-verification/inline-engine-test-1.log)，0 skip/error/fail、exit0。真实覆盖 foreign snapshot 含 empty semantic replay 在 parser/scope/allocator 前拒绝、远处闭合符唤醒失败候选并回滚其状态/effects、成功 parser Text 保留三类 metadata 与独立逻辑节点、512KiB 单 logical Text 受限读取/切片且小 LogicalTextSplice+完整结果对照。命令与 exe SHA 在 inline-engine-test-1-command.json。
- 上述通过绑定 inline compile2 冻结快照；04下一 nonidentity/recursive/payload 修订仍在写，不用该4case通过冒称新源已验。真实 Markit桥接3case已SOURCE_READY（Strict执行拒绝/Compat fresh、raw splice/effects/textpatch、actualfacet漂移拒绝），因依赖完整Markit/builtins将在全项目一致whole后实跑，不用局编混合旧ABI运行。
- 新非身份 literal 修订将 source raw 与 decoded payload 分开持久化，并以 `offsetsFollowLiteral` 显式 opt-in 决定是否可直接局部字节 splice；默认 false 不猜源与解码偏移等价。索引集合去重采用事务内 HashSet，避免交叉候选重复线性查找。该新三产品首次 nodes 编译 main-nodes-compile-3 exit1，仅 raw=None 分支需显式 `?TextBranch`；owner最小类型修后 stage4一致闭包正常重编中，失败未覆盖。
- 主独立测试现6case SOURCE_READY，新增具体反斜杠解码的 raw/decoded 编辑、length-only None→success及删除escape后的成功失效/effect撤销，CP两fixture已READY。旧4通过不背书该新三产品，等待新官方6case实跑。
- raw 分支显式 Option 修后 main-stage-4 的 nodes/document/session/render/block/inline/plugin/incremental 八包均 compile exit0。两具体 fixture 与新6case 官方编译3 exit0，随后 [主引擎6/6 pass](task06-verification/inline-engine-test-2.log)，0 skip/error/fail、exit0；新增 raw/decoded 转义文本编辑与 length-only失败唤醒/删escape撤销真实通过，原4case仍全过。命令/二进制 SHA 在 inline-engine-test-2-command.json。递归新源仍下一owner写窗，6case结果只绑定stage4冻结点。
- 递归新产品阶段 main-stage-5 的 nodes/document/session/render/block 五包实际 compile0；inline compile5 exit1，仅两处新代码对 SourceVersionIdentity/SyntaxNodeIdentity 使用未实现的 !=。owner改为比较完整 document/version 或 document/nodeId 字段，不扩 shared DTO API，失败日志保留，plugin/incremental未启动。
- 同一必要产品修窗补审查边界：源坐标恒等不代表 raw 与 decoded 拼写相同（例如 uppercase 转换）。literal 快路径需同时有拼写证明，缺少则合法扩大恢复而不是碰到底层安全拒绝。主测试已8case就绪；具体grammar fixture正在消除固定lookahead并加入递归真实case，新的whole/主实跑需该fixture重新冻结，不读半写测试。
- stage6一致 nodes/document/session/render/block/inline/plugin/incremental 八包全 compile exit0（main-*-compile-6.log/args）。该冻结点含raw拼写证明、非身份解码在rebuild扩大、仅真实窗口变化参与语法固定点，以及撤销真重解析opener后按实际change splice索引。主8case已就绪，等待grammar固定lookahead修订重新单文件冻结后官方实跑；递归子层semantic读唤醒仍下一必要产品修窗，未标完成。
- 官方主8case编译4 exit0后 [实跑7 pass / 1 fail](task06-verification/inline-engine-test-3.log)，0 skip/error、exit1。失败原 `failedFarCloserRetriesSharedGrammarAndFailedProbeDoesNotLeak`：删除闭合符后增量两个Text/范围与fresh单logicalText不一致；原fresh断言未变，交04做bounded literal邻居合并修复。新增sameepoch语义missing/present/removed和扩大provider窗口拉入外部opener均真实通过。
- 独立递归 fixture官方编译1 exit0，[1/1 pass](task06-verification/inline-recursive-test-1.log)，0 skip/error/fail、exit0：两次length-changing真实child.prepare，父parser无新增调用、未改sibling raw/ID/birth/effect及fresh/old snapshot验证。该结果绑定stage6，不证明随后新增的递归semantic路径。
- stage7补literal合并、持久nested key→owner定位与ordered following childsplices统一atomicgate：block compile7 exit0；inline compile7 exit1，仅新internal Snapshot regular clone参数在memberparams后，按实际SDK规则前置普通参数/后缀member并保clone，原失败保留。主8原case追加uppercase/raw-spelling及未改token引用断言已SOURCE_READY；递归原1case另加双child同key semantic段，未冻结时不读半写源。
- inline stage8仅失败于第二个SDK参数规则：unnamed参数必须先于named参数。把regular named clone参数前置仍与后续unnamed member参数冲突；新internal ctor采用必需unnamed regular前缀、unnamed member后缀，内部调用显式前移None/[]等值，保留clone与安全member折叠；不为未交付内部API造兼容wrapper。原8条诊断完整保留 main-inline-compile-8.log，plugin/incremental未启动。
- stage9 inline/plugin/incremental 三包实际 compile0，内部ctor同时满足regular/member及unnamed/named顺序约束；provider rebase默认None的保守跨epoch证明接口随正常编译通过。随后官方主8编译5 exit0，[最新8/8 pass](task06-verification/inline-engine-test-4.log)，0 skip/error/fail、exit0。
- 原双Text/span回归保留fresh原断言修复通过；同case新增uppercase初始raw=decoded样本123→raw1d3/decoded1D3、明确非raw publicsplice拒绝、首literal编辑后未改两个token raw引用和parser调用不增均实际通过。输入SHA/命令/exeSHA与inline9/block7/node6闭包记录在compile5-inputs/args与test4-command；这不替代递归新semantic/cross-epoch具体用例、真实Markit桥接3或全量whole。
- 冻结源码只读复核发现 InlineParseResult 给所有旧3参数成功返回对象增加 rawReplacement/nested 两编辑字段，属于真实batch对象布局变化，尚未声称测得变慢。root纳同一必要产品窗：旧基类恢复原3字段存储，open编辑只读props默认None，显式editing子类才存新payload。04唯一writer、CP仅改新recursive调用；复用已多轮编译/实跑的 SessionStateSnapshot open/override语法惯例，不增加语法probe或benchmark框架，最终只复用原同O2一次AB记录。
- 最终必要产品窗 stage10 inline/plugin/incremental 均实际 compile exit0。literal payload工厂默认None、provider显式给出mapped raw/decoded关系；旧InlineParseResult恢复三字段布局，editing子类才存handoff，open/override语法复用已验实现。主8最终源已冻结；CP正在把具体fixtures接显式工厂/新result子类/rebase，未冻结前不读半写测试，不用旧8pass替代新工厂版本运行。
- root明确不追加toy grammar计时driver/ABBA新入口，局部性使用受限read/slice、小patch和未改ref/calls真实断言；最终同O2只原01冻结v2 driver/原配置一次AB。07-P负责真实生产纵切edit计时，不把toy速度作为生产结果。
- root确认原CP和fresh接手者均capacity失败且无运行写者，将 index 窄 `hasReadingKey(key)` 方法唯一写权转02。已直接沿semanticReaders AVL单路径按key返回bool，不物化readingKey数组、不改索引结构；04一行消费后 stage11 inline/plugin/incremental 全 compile exit0。新bool存在性查询实际运行仍随最终递归semantic case验证，不把类型通过写成测试通过。
- fresh fixture接手者未执行工具/写入，root把3helper临时唯一写权转04。helper在最终工厂/结果子类/rebase接线后先单独冻结二文件以放行主8，第三recursive文件独立写；没有不确定写操作需重放，不等doc/计时设施才释放已完源码。
- 最终工厂/惰性结果布局版官方主8编译6 exit0，[再次8/8 pass](task06-verification/inline-engine-test-5.log)，0 skip/error/fail、exit0；本轮完成后helper一行历史坐标调用才变更，未与编译读源并发。
- 最小只读 document `resolveAtVersion(anchor,target)` guard 0<=target<=doc.version、复用原SourceStore历史，不伪造倒退版本document。新doc→block→inline→plugin→incremental stage12五包均compile0；具体helpers/recursive全部最终冻结。
- 官方递归编译2 exit0，[最终强singlecase1/1 pass](task06-verification/inline-recursive-test-2.log)，0 skip/error/fail、exit0。原多次source child编辑/ref/effects断言完整保留；追加双wrapper同key missing→present→removed、exact2following childsplices、父0调用/child仅真实reader调用、外tail编辑后跨epochsemantic及混合birth0锚点历史resolve/非法target拒绝，fresh/旧snapshot全部实跑通过。
- 全部最终源码/test冻结后，已实际启动 `cjpm test --no-run --no-progress` 全项目一致构建，命令/STARTED位于 task06-verification/integrated-compile-1-command.json/log。编译尚未退出时不标whole通过；之后真实Markit桥接3、全量27包、148条11字段对照及原同O2一次AB仍需执行。
- Windows恢复后先核原whole1日志终态 TASK06_WHOLE_COMPILE1_EXIT=1（无重复未知运行），root临时唯一授权02仅三行测试集成修：SessionStateKey补plugin/name两字符串，engine两处None显式Option类型，原断言和legacy API不变。whole2正常一致构建 [exit0](task06-verification/integrated-compile-2.log)，Finished/cjpm success均已真实返回。
- 完整官方Unit binary选InlineEditing [24 pass / 1 ERROR / 0 failed](task06-verification/editing-inline-whole-test-1.log)，exit1；137为tag未选中。两个真实桥接rawsplices/effects/textpatch和actualfacet漂移拒发布、view7/index6/main8/recursive1均通过。剩余Bridge strict/compat fixture仅注册inline无paragraph，却读root.children[0]，实际legacy plain文本为空root而越界（与02已撤回phantom paragraph前提一致）；不是生产语法回归，不删除fresh/old snapshot断言，待在Strict断言之后注册真实legacy paragraph fixture最小修复。
- 原冻结零源码第三方fixture/baseline两SHA及原v2 driver源/refexe两SHA再次完全一致，frozen-baseline-hashes.json保留，未用改baseline取得通过。全量/148对照/O2尚未执行，等待该已知fixture error修后正常whole。


### Task06 最终验收收口

root实际审whole4、25官方日志、全量27包717/0/0/0、148×11零差及原同O2一次AB后，按用户修订范围验收Task06 Done。最终命令/exit/binary SHA/输入与冻结libs均保存在task06-verification及task01-performance/candidate-task06-product；batch-time-comparison.json保留large Stream均值+0.55%与所有原始CSV，不声称统计无退化。bridge最终fixture仅新增测试用默认false的legacy ParagraphBlockParser，读取实际SourceLine.text与span并session.attachNode绑定，在Strict断言后注册；原abc/aZc/fresh/旧snapshot断言和生产语法不变。whole3误用content的2条诊断保留，whole4已修并实跑通过。Task07-P后续共享build仍由02唯一协调，契约缺口只按root明确唯一写权处理。


### 2026-10-23 — Task07-P core semantic publication, first staged evidence (not pilot acceptance)

- Added compatible `replaySemanticResult`, detached `BlockPayloadUpdate`, candidate-aware context/key projection, nonsealing semantic worklist and initial forward-reader worklist in the uniquely owned block/incremental files. Existing Unit overrides remain valid; payload-only updates use the persistent ID/path seam.
- [First block check](task07-core/block-compile-1.log) exit0 against frozen06 interfaces. [Stage3 nodes](task07-core/nodes-compile-3.log), session/document/block/inline/plugin/incremental logs each exit0; exact per-package args and input hashes are adjacent. This is package type checking, not a new Standard runtime result.
- [Official stage3 core run](task07-core/core-test-2.log): 21/21 passed, zero skipped/error/failed, exit0 (Atomic9, Aux4, Kernel5, Preparation3). [Compilation](task07-core/core-tests-compile-2.log) exit0. Source/input binding is stage3; later captureChildren and effect guard revisions require final consistent closure verification.
- Failures preserved: nodes stage2 missing `SyntaxNodePayload` import fixed by its unique owner; direct core test link1 omitted frozen `markit.utils`, link2 corrected only argv; shared standard helper stage4 captured a mutable local in `sandboxProbe`, unique owner replaced it with a let control box. No assertion or production grammar was weakened.
- New effect reordering install guard source was type-checked in [session stage4](task07-core/session-compile-4.log), exit0. Heading/Reference standalone package checks follow their frozen source readiness. No whole/pilot completion is inferred from staged checks.
