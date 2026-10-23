# 尚缺证明与关闭条件

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

## 当前缺口状态（Task06验收后，2026-10-23）

root已按用户修订范围验收Task01–06。以下当前结论优先于后文历史“全部Pending/未实现”；详细证据见[Task06最终记录](06-inline-edit-engine.md)和[验证日志](verification-log.md)。

| 缺口 | 当前已验证边界 | 继续开放的交接 |
|---|---|---|
| G01 | 正式1.1.0验证为Deferred by user scope，未记Passed；实际1.3-alpha | 不作为02–16实施阻塞 |
| G02/G03 | typed桥接与source/多坐标/CRLF/map基础实现，02–06具体用例与全量通过 | 真实生产嵌套映射由07-P/后继验证 |
| G04 | persistent树/typed/ID/单logical Text受限读与小splice基础通过 | renderer/IPC/DOM实际消费由07-P及16验证 |
| G05/G06 | owner效果/正负读/checkpoint/nested/原子publish基础具体用例通过，05/06已验收 | 真实插件贡献/worker协议取消由后继关闭 |
| G07 | 通用inline view/attempt/read恢复、literal/raw证明、递归语义与历史投影通过，官方25+全量717 | 07-P真实Standard纵切与pre-inline入口成本，不能用toy替代 |
| G08 | 仍0/30内置实际适配，默认false/Compat fallback不算完成 | Task07–13逐项实现；07-P先行 |
| G09 | legacy148条四模式逐11字段零差；具体editing fixture逐步fresh对照通过 | 全部真实插件editing组合/独立验证仍未完成 |
| G14 | 具体第三方genericflags拒绝/不freeze、零构造、Compat fresh与实际facet漂移用例通过 | 未知真实第三方/跨进程集成按后继范围验证 |
| G10–13/G15–21 | 不因基础引擎通过而整体关闭；大观测/统计矩阵按用户裁剪延期 | 真实插件/workspace/stdio/预览仍按任务推进；16后停下，不启动17/18 |

最终同-O2只记录原冻结driver一次AB：各84samples/exit0，large Stream均值+0.55%，有快有慢且历史噪声宽；不宣布统计无退化/端到端editing达标，不增加toy计时设施。原扩展5 native/1 Chromium跳过仍未证明，未写成73/73。所有历史失败与更早规划保留如下。


## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

30个内置插件逐项实现与验证的目标保持开放，分别由Task07–13实际产品适配关闭；基线裁剪只延期额外兼容/通用框架，不删除内置覆盖目标，也不将默认false或fallback诊断当适配通过。

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

更新：2026-10-21。当前所有新编辑实现门槛未证明；本轮只静态调查并编写方案。这里的owner是未来实施任务，不表示已经分派或实现完成；具体子agent由协调者指定。结果证据进入[verification-log.md](verification-log.md)，进度只由root更新README。

## 执行与命令约定

- 根目录先记录`git rev-parse HEAD`、`git status --short`、`git diff --stat`、`cjc --version`、`cjpm --version`；必须保护当前dirty和未跟踪内容。
- 下列`cjpm`命令均在`markit/`执行；`npm test`在`vscode-extension/`执行；其他包集成测试在相应任务落地后给出真实工作目录/入口。这里**没有运行结果**。
- 现有命令：`cjpm test --no-progress`、`cjpm test --no-progress --include-tags=Streaming`、`cjpm bench --filter=ParserBenchmarks`及扩展`npm test`。旧ParserBenchmarks仅legacy参考，不能关闭editing性能缺口。
- 下列Editing*/Typed*/Source*/Owner*/Warm*/Workspace*/Worker*/DOM*等tag、benchmark或driver均是**拟新增**，须对应任务先实现、确认确有测试被收集，再运行记录样本/退出码。空匹配或skip不算通过，不能把拟议命令写成现成可用。
- 每条缺口需保存构建/机器/配置/版本、seed/编辑序列、expected/actual、计数与必要原始结果，审查通过才关闭。失败修复归相应owner，验收任务不抢改实现。

## G01 仓颉1.1.0真实兼容环境

- Owner：Task01记录基线；Task02–16各实现owner；Task17独立复核。
- 未证明：`markit/cjpm.toml`声明1.1.0不等于新协议/依赖/codec已在1.1.0构建运行；本轮未执行工具链。
- 关闭证据：实际最低版本环境、依赖版本及全相关包build/test结果，无借新API把最低要求升至1.3.0。若环境不具备，明确未通过并补环境，不能仅最新编译器成功结项。
- 未来命令：根目录版本采集；`markit/`运行`cjpm test --no-progress`和各任务新tag；其他包命令由17汇总真实入口。

## G02 typed codec小原型与public String桥接

- Owner：Task02；Task04实现lossless codec；Task05完整事务原型复核。
- 未证明：现typed subclass/renderer cast、metadata/raw/parent/source/ID可无损往返；public String literal若无法lazy，尚无证据证明editing不会被迫重拼巨大Text。
- 关闭证据：02可用测试Source的小型**可执行**原型，真实typed renderer验证并故意丢字段失败；明确独立editing record与按需legacy typed view、logical Text不变及String/cast桥接。不能用假件声称03/04已完成。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=TypedCodecPrototype`；保存真实renderer结果及假件范围。

## G03 rope多坐标、CRLF编辑join与组合map

- Owner：Task03；Task05集成；Task17独立source oracle。
- 未证明：局部edit/查询复杂度、byte/rune/UTF-16/line转换、CRLF跨叶join/split、synthetic去marker/缩进/拼接/生成文本的组合映射。
- 关闭证据：独立reference model/property序列、非法切点原子失败、旧版本view有效；计数证明查找O(log N+有界叶解码)、输出按k成本，不全文materialize/重写全部offset。嵌套quote/list/HTML/i18n回文档坐标。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=EditableSource`、`cjpm test --no-progress --include-tags=SourceRangeOracle`、`cjpm bench --filter=EditableSourceBenchmarks`。

## G04 lossless COW、稳定ID与巨大logical Text

- Owner：Task04；Task06局部文本；Task07/16渲染及patch消费；Task17计数。
- 未证明：新旧snapshot不会别名污染、typed恢复lossless、NodeId唯一/稳定、惰性位置索引，以及一个巨大Text改一字不复制literal/整Text HTML。
- 关闭证据：真实typed树局部替换后旧snapshot不变，内部bounded text leaves/versioned payload和text-splice/subunit patch工作；legacy AST/JSON仍保持原logical Text结构。显式toHtml/getliteral可O(N)，正常editing路径无必经全文materialize。记录copied/rendered/IPC bytes而非只candidate次数。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=PersistentTree`、`cjpm bench --filter=PersistentTreeBenchmarks`、`cjpm bench --filter=InlineEditingBenchmarks`；16补实际DOM/IPC脚本。

## G05 可撤销owner effects、有序候选与负依赖

- Owner：Task04存储；Task07/10/11/12适配真实语义。
- 未证明：definition/footnote/heading等删旧贡献后正确接管，missing读被新定义唤醒，cache命中不漏重放；隐藏/配对/附件结果可恢复原语法。
- 关闭证据：两个同key有序候选删除winner后备用接管；删一owner不删别人贡献；missing→present→missing可逆；raw syntax始终保留；效果/依赖绑定与内存回收可观测。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=OwnerEffects`；真实插件案例由07–12相应新tag补充。

## G06 完整state/checkpoint、nested上下文与事务恢复

- Owner：Task05；Task15核对协议取消语义。
- 未证明：frame/pending paragraph/activeLine/depth/源映射/完整state恢复、probe纯度、nested隔离、异常回滚，以及真实source+tree原型运行。
- 关闭证据：真实03/04实现运行checkpoint恢复、旧单位复用、新typed替换、效果撤销/重放和失败注入；source已ack后取消旧parse不丢输入，未提交overlay/patch不污染旧快照。sourceVersion可领先parse/render并从最新accepted source恢复。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=CheckpointTransactionPrototype`、`cjpm test --no-progress --include-tags=BlockEditing`。此缺口未关闭，不释放07大适配。

## G07 inline成功/失败读取、安全窗口与局部性

- Owner：Task06；Task07/08/10真实插件适配。
- 未证明：成功token以外的失败closing/escaped opener/negative symbol依赖被追踪；超长paragraph安全窗口不先做全owner预扫。
- 关闭证据：增删delimiter/escape/远处closer唤醒失败attempt，递归owner与opaque范围正确；普通编辑局部，真实扩大范围有具体插件依赖原因。无语法长Text也不全量escape/render。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=InlineReadDependencies`、`cjpm test --no-progress --include-tags=InlineEditing`、`cjpm bench --filter=InlineEditingBenchmarks`。

## G08 全部30内置facet及组合覆盖

- Owner：Task07（13 Standard）、08（5 CommonMark）、09（4 GFM block）、10（5 GFM inline）、11（I18n）、12（AutoAnchor/Toc）；Task17总审查。
- 未证明：目前只有静态清单，不是30/30编辑支持。每插件所有注册parser/state/filter/processor/finalizer/renderer的依赖、恢复、cache均需落地。
- 关闭证据：逐插件至少两例与混合bundle/priority/config/嵌套矩阵；nested items/table rows/inline窗口复用、未变单元零调用；不能长期whole-container或builtin fallback结项，core/CLI/webview无语法/name/kind边界特判。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=EditingDifferential`；各适配任务实际新增tag/入口记录在任务文件后运行，17核实30项非skip。

## G09 fresh oracle、legacy四模式与known corrections

- Owner：Task01建立；Task17独立验收；各基础设施/插件owner修复。
- 未证明：逐步fresh parse比较器、旧parse/feed/feedBytes/InputStream可观察语义保持、source/重复ID纠错差异的精确边界。
- 关闭证据：每步insert/delete/replace/undo/redo/multiedit比较typed AST/metadata/raw/三格式/JSON；ID稳定独立测；独立source oracle。既有语义偏差记录保留，基础设施纠错显式expected迁移，不全局剥span/ID或批量改golden蒙混。
- 未来命令：现有`cjpm test --no-progress --include-tags=Streaming`；拟新增`--include-tags=EditingOracle`、`--include-tags=EditingDifferential`、`--include-tags=SourceRangeOracle`。

## G10 i18n注册序、语言投影与附件回滚

- Owner：Task11；Task12消费投影；Task17矩阵。
- 未证明：I18n实际注册顺序/phase兼容、附件与结构变换可撤销、语言切换复用raw、嵌套/跨行source map正确。
- 关闭证据：真实注册序oracle，开启/关闭与插删语言片段后的三格式/结构/效果等价；未变source不重parse，投影无跨语言污染。不能擅自按理想语义重排finalizer而不记录差异。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=I18nEditing`；运行11最终实际测试入口并记录未匹配tag失败。

## G11 ordered语义、Anchor/TOC查询收敛

- Owner：Task12；Task14跨文件集成。
- 未证明：编号/slug/closable/引用winner/footnote首次顺序、AutoAnchor、TOC、source属性的局部传播和语言投影一致性。
- 关闭证据：文序贡献与query索引恢复；同名标题插删、隐藏区段、首引用变更后正确传播至状态收敛；不每edit全树finalizer/TOC扫描，不残留旧anchor或错source。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=DerivedQueriesEditing`；12实际tag落地后确认收集。

## G12 CodeHL行级收敛、公式/图单元缓存

- Owner：Task13；Task17独立调用计数与图/公式输出检查。
- 未证明：CodeHL行状态缓存与真实收敛；公式/图内容/config/宏/身份相关key正确；未变单元零parse/layout调用。
- 关闭证据：code行编辑按状态传播到收敛而非每block全量高亮；公式内容改动只重parse该公式、图改动只重layout该图；未变/仅位置变化零调用。主题/grammar/语言/宏变更的真实全局失效独立测试。TeX内部与图内部增量不作本轮承诺。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=RenderServiceEditing`、`cjpm bench --filter=RenderServiceEditingBenchmarks`；13对实际库还需记录可执行入口与spy计数。

## G13 持久项目索引与cross-file正负查询

- Owner：Task14；Task12提供查询；Task17验收。
- 未证明：当前页普通edit不扫描未改项目文件、文件变更按依赖传播、cross-file引用/通配符/missing目标/编号/summary/config生命周期正确。
- 关闭证据：初次建索引后，未改文件read/parse为0；新增/删除/重命名/目录变更唤醒正负查询，dirty buffers优先且外部变更不覆盖未保存内容。源语义与全项目fresh基准等价。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=WorkspaceEditing`及14实际kit包测试入口；记录每文件read/parse计数，不能拿page-only render当持久索引证明。

## G14 未知第三方fallback/strict与核心中立

- Owner：Task02契约；Task17独立自定义插件测试。
- 未证明：未知插件有显式能力诊断/兼容fallback或strict拒绝，strict原子，内置缺facet不会借外部出口伪装完成。
- 关闭证据：非Markdown测试插件规则全由facet给出，核心不写marker名单；缺能力时诊断owner/范围/成本，strict无半提交。30内置全部正式facet通过。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=EditingContracts`与17第三方矩阵；配合静态diff审查core/CLI/webview新增边界逻辑，不能只依赖字符串搜索零匹配。

## G15 worker取消、版本、resync与背压

- Owner：Task15；Task16消费；Task17故障注入。
- 未证明：持久进程/消息framing、accepted source与parse/render版本分离、取消/乱序/丢包/重启/close、resync和队列/输出背压。
- 关闭证据：多edit不每次spawn；已ack输入不会因取消丢失，stale结果不覆盖新版本；workercrash新epoch按协议恢复最新源码。队列/IPC容量有界、过载合并/重同步明确，不阻塞或无界积压。
- 未来命令（拟新增）：`node tools/worker-edit-protocol-test.js`作为拟新增driver，确切位置/参数由15落地并记录；实际CLI包test命令也须记录。空driver不能作为通过证据。

## G16 多项目、多文档、多语言生命周期

- Owner：Task14 workspace；Task15 worker；Task16 UI；Task17总验收。
- 未证明：并发文档/项目/config/语言隔离，切换/关闭后状态与缓存释放，跨项目同名path/NodeId不串用。
- 关闭证据：两个root、同名文件、多个dirty buffers、语言切换/文件删除/项目重载连续序列与各自fresh结果一致；只失效受影响project/language，关闭pin/索引/worker资源能回收。
- 未来命令（拟新增）：WorkspaceEditing/WorkerProtocolEditing测试及扩展新增`node --test test/incremental-workspace.test.js`（路径拟新增，16落地后再运行）。

## G17 DOM身份、source映射与scroll/selection

- Owner：Task16；Task17实际webview验收。
- 未证明：有序DOM/text-splice patch的版本与身份、安全text转义、Unicode映射、双向selection/scroll、有效DOM交互状态保留。
- 关闭证据：长Text一字编辑不替换整Text HTML或整page；乱序patch拒绝/重同步；中文/emoji/CRLF与nested source ranges点击/选择/滚动命中正确，无前端Markdown正则猜边界。tab/折叠等未失效状态保持。
- 未来命令：现有扩展`npm test`；拟新增`node --test test/incremental-preview.test.js`及实际VSCode/webview自动化driver。Node测试不能代替真实DOM/paint/scroll证据。

## G18 全插件随机/组合差分与故障最小化

- Owner：Task17独立验证，失败交01–16相应owner。
- 未证明：固定seed随机编辑、语法组合、异常/取消/回滚及关闭重开在所有30插件/配置下正确；同一实现oracle可能共享bug。
- 关闭证据：完整fresh语法oracle加独立坐标/身份不变量，多seed和最坏case；保存最小失败编辑序列，不随意normalize用户slug/anchor/source字段；不以相同HTML忽略AST/效果错误。
- 未来命令（拟新增）：`cjpm test --no-progress --include-tags=EditingDifferential`、`cjpm test --no-progress --include-tags=SourceRangeOracle`；17固定driver/seed参数后报告完整重放命令。

## G19 真工作量、端到端延迟与10倍规模趋势

- Owner：Task17；01计数基础、各实现owner接hook。
- 未证明：warm native p95≤30ms、可见p95≤100ms、DOM patch p95≤16ms及无关体量10倍时local p95≤2倍。全部为拟议目标，尚无实测结果。
- 关闭证据：固定硬件/构建/负载，分cold/warm/真实广域影响，报告p50/p95/p99与样本。记录读取/复制/解析/语义/render/IPC/DOM字节和各昂贵调用；无无关文件扫描、全文getText/HTML/hex、每editspawn、全offset改写，长Text也局部。10x配对控制相同编辑依赖范围并记录抖动/置信。
- 未来命令（拟新增）：`cjpm bench --filter=EditingBenchmarks`与17拟新增WarmEditPerf端到端driver；具体规模含10KiB/100KiB/1MiB/10MiB与100/1000文件项目，按17落地并报告。旧stream/单页耗时不能关闭此缺口。

## G20 RSS、quota、长编辑序列与close回收

- Owner：Task04/13/14/15/16各资源owner；Task17独立采集。
- 未证明：source版本/checkpoint/typed view/effects/cache/索引/IPC/DOM存活内存有界；GC或cache驱逐不会破坏恢复能力。
- 关闭证据：100/1000/10000编辑序列，peak/steady RSS、GC时间、retained source/cache/queue字节；有界quota驱逐仍正确，close/restart释放引用。按10x规模单独报告必要索引增长与泄漏，不能只看managed heap或一次编辑。
- 未来命令（拟新增）：PersistentTreeBenchmarks及17拟新增memory/worker/DOM driver；实际RSS采集工具、采样频率、暖机与进程树范围由17记录，未定义采集器前不贴达标数字。

## G21 API/文档与最终交付

- Owner：Task18；root审查17证据后放行。
- 未证明：公开editing/legacy API、默认/strict/fallback语义、示例、版本与资源生命周期文档和实际行为一致；所有临时内置fallback移除。
- 关闭证据：17全部必需门槛通过，18真实示例可跑，明确支持范围与剩余optional项；README百分比由root依据证据更新。保留用户dirty，不擅自commit/push/publish。
- 未来命令：18实际示例/文档/API测试命令落地后执行并记入log；本轮文档综合检查已通过，见verification-log，未来产品API/示例验收仍Pending。

## 本轮文档综合验证（已关闭）

- Owner：root协调者；这是方案完整性审查，非编号实现进度。
- 关闭证据：协调者实际检查28文档、18 Pending任务章节/owner/scope/Deps/Unlocks、22边18节点无环、30Plugin的18+9+3逐节覆盖、221本地链接及fragment问题0、28/28忽略、无跟踪tasklists，`errors=[]`；独立只读交叉审查通过。HEAD与6文件59+/5-基线未变，详情见[验证记录](verification-log.md)。
- 此项只关闭文档综合核验；G01–G21实现缺口仍全部Pending，未build/test或commit/push。


## 2026-10-23 Task01 实施期仍开放的验证边界

- G01：本机PATH为1.3.0-alpha，另有1.1.0-beta.10/.22但未找到正式1.1.0。beta/alpha通过不能代替最低正式版本；Task02不得据此放行后继。
- cjpm标准runner在sandbox的本机TCP transport报10013；原27包通过官方test binary console模式实测569pass，但不改写原runner失败事实。后续继续优先正常console方式，不能造mock结果。
- 扩展最终Windows fixture suite为73项67pass0fail6skip；5个native与1个Chromium实际环境缺口仍须后继真实环境验证，Node静态/模拟测试不能关闭DOM paint、原生源映射与完整预览门槛。
- Task01 oracle只能观察现有public typed字段、metadata与raw/span；sourceBuffer绑定、raw override来源和内部provenance无公开枚举，Task02须冻结可扩展typed codec/观察契约，未注册第三方字段不能静默当完整等价。
- 性能基线原始样本已采集但噪声较宽，root尚未冻结；GC累计计数需差分并重测。不能把跨0区间自动当通过预算，不能声明batch无退化、零分配或真实editing达标。


## 2026-10-23 裁剪后的缺口状态（优先于历史门槛）

- G01正式最低版依赖/项目验证：**Deferred by user scope**。已有正式cjc版本不等于项目通过，cjpm native崩溃仍是失败事实；不再追加兼容验证、不阻塞Task02–16。
- 通用oracle完整私有provenance/metadata反射/所有typed扩展观察、通用生产计数hook、完整benchmark/RSS/GC/统计矩阵扩展：**Deferred by user scope**。过去工具自测和样本留档，产品只做自己所需最小定向测试/全量对照/同-O2比较，不要求恢复延期框架。
- developer @Bench独立和集成exit3：**Deferred by user scope（failed, not passed）**。Task01仅以实际成功的-O2公共API driver记录当前环境时间，不假称@Bench成功。
- 新建通用源码可恢复收起后未追加回归；592全量/23tag结果只绑定此前真实测试树。后继实际产品更改仍须运行必要定向测试，不能借裁剪跳过产品正确性。
- 既有扩展5 native/1 Chromium跳过项仍未证明，保留事实；不得写成73/73执行通过。
- 原有语法/身份/映射/事务/默认兼容回退/stdio版本与预览保留要求不因裁剪失效；07-P及Task16后停下验收继续有效。
