# Task 17：全插件差分、压力与性能验收

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

**2026-10-22补充：** [评审补充](review-2026-10-22.md)新增独立batch `-O2`不退化门槛：按01冻结的同条件配对方案复测parse-only吞吐/时间、分配/GC与RSS，噪声之外无可测减速为目标，warm edit通过不能替代。另验证标题/定义变化时syntax复用与semantic传播分离，并验收SeaJson自实现framing的部分读写、限额和错误恢复；这些均尚未执行。

Status: Pending

## Execution Contract

- Depends on: Task 16，其前驱实现与交接均须协调者审查。
- Unlocks: Task 18。
- Execution: 串行独立验收；失败修复退回相应任务owner，审查通过前不放行交付。
- Delegated owner: 差分与性能验收子 agent，由协调者指派。
- Scope boundary: 拥有`markit/src/tests/**`、必要kit/CLI/extension集成测试与拟新增跨链路benchmark/driver、证据报告。输入为01–16真实实现、冻结基线/known corrections/计数契约和构件；输出为完整矩阵、复现命令、失败最小化样例、性能/内存/IPC/DOM报告。禁止抢改解析器、插件、renderer、worker、workspace、扩展产品实现；失败分派原owner修，之后重验。测试共享文件改动也需串行协调，不改README百分比、不伪造绿灯。

## Goal

独立证明30内置Plugin及组合在任意编辑后正确、可恢复、源映射可靠，且真实工作量与端到端性能达到已冻结门槛。现有append benchmark、单页渲染或相同HTML输出不足以通过。

## Current State

- 盘点确认30Plugin：Standard13、CommonMark5、GFM9、横向3；SoftBreak归Paragraph、Mermaid非额外Plugin。详见三份插件清单及00设计锁。
- 现有`markit/src/tests/unit/streaming/incremental_state_tests.cj`覆盖追加pending tail、基本snapshot/range、forward reference final patch；不覆盖任意位置edit、撤销、协议版本与局部工作量。
- `markit/src/tests/benchmark/homepage_showcase_benchmarks.cj`主要batch/stream；扩展native session测试需`MARKIT_TEST_BINARY`，主要证明page-only/语言/资产复用。
- 本任务所有新矩阵、driver/tag和性能数字都尚未实施/实测。warm native p95≤30ms、可见≤100ms、patch≤16ms为拟议目标。

## Follow-Up Work

**新增必做：** 汇总各阶段batch复测并与01冻结基线做同条件`-O2`配对验证，分别报告parse(String/InputStream) parse-only吞吐/耗时、分配/GC与RSS，原始样本、噪声及置信区间齐全。复验07-P真实单行/nested/标题与引用场景及15依赖/framing限制，不能以mock、warm编辑或渲染提速抵消batch减速。

1. 锁定硬件/OS、仓颉最低1.1.0兼容与实际编译器、release/debug、依赖版本、worker/扩展/配置fingerprints、HEAD/dirty基线和数据集seed。复现所有旧parse(String/InputStream)、stream chunk/bytes、callbacks/finalize/API输出。
2. 30Plugin逐facet能力清单核对实际adapter，内置永久fallback为失败；组合覆盖Task01冻结的有限代表性矩阵：Standard/CommonMark/GFM、I18n/Anchor/Toc相对注册次序、相同priority冲突和实际风险config，并补相关pairwise/真实风险组合与固定seed生成样例。无需30!注册排列或2^30插件子集穷举，也不能只测默认bundle；报告矩阵条目、seed和覆盖依据。包括自定义非Markdown plugin与unknown外部strict/fallback诊断，静态检查core/CLI/webview无按语法/插件名硬编码边界。
3. 建立每步fresh full parse oracle：随机insert/delete/replace/multiedit/undo/redo，每一步比较完整语法/语义/metadata/rawContent与HTML/Markdown/Typst/JSON。NodeId另测唯一与未改节点稳定，不把全量parse新ID当相等要求；不能仅用Node.==或stableHash。
4. 独立range/source oracle由原始输入与UTF8/rune/UTF16/CRLF算术构造，不调用被测同一map代码。覆盖byte↔rune↔UTF16↔line、半字符非法边界、synthetic去缩进/拼接/虚拟字符、深quote/list/i18n/HTML内部Markdown。重复ID、错误旧span等known correction单独标基线/预期/范围，禁止无声更新golden或保留错误作为兼容。
5. 可规范化HTML/SVG随机内部ID，但验证所有ID引用保真；用户可见slug/anchor、TOC href、source位置不得剥掉以绕oracle。差异最小化保存seed/edit序列、旧/新版本、插件trace与expected/actual。
6. 混合用例覆盖：负引用新增/首定义删除；footnote首次出现重排；重复heading/closable；i18n语言/附件替代；HTML配对；三线表邻接；list/task/alphabetic嵌套；fence/math/i18n缺closing/补回；长paragraph候选失败转成功；深quote/item局部重建；重型服务配置/主题/宏变化。
7. 故障/事务矩阵：probe失败不污染、restore完整state/deferred、异常/取消不半commit、旧snapshot不可变、stale/duplicate/out-of-order消息、render取消但source不丢、背压、workercrash新epoch、断管/close与多doc/project/root/language隔离。多个root/文档目录直接打开Markdown须自动归属，单一归属不弹项目选择器，共享页真实多归属才确认；各项目语言分别写入各自项目配置，热切换、文档切换和close/reopen后保持且不互相覆盖。
8. 性能数据集固定为10KiB/100KiB/1MiB/10MiB文档，100/1,000文件项目；文首/中/尾、单字符/跨块/批量编辑，连续100/1,000/10,000 edits；含长单paragraph、深quote、大list/table/code和真实广域delimiter/编号变更。强制加入千/万行fence中间改单表达式，验证stable line ID与row级patch；超长单paragraph、深quote/item的普通edit验证nested subunit/候选窗口计数。分cold open、warm steady与全局配置失效，不混平均值。
9. 采集p50/p95/p99：source接受、queue/debounce、parse、semantic、render、IPC、DOMcommit、可见paint；默认16–32ms/adaptive debounce计入可见延迟。记录scanned/reparsed bytes/lines/units、checkpoint/propagation、正负dependency、cachehit/miss、CodeHL行/MathTex parse/Mermaid layout、未改文件read/parse、snapshotclone/hash/offsetrewrite、spawn/getText/fullHTML/hex、IPCbytes/DOMinsert/remove/reuse。另统计大code literal/HTML join/copy字节、整codeblock innerHTML重置、row patch数和未改行DOM引用：tokenizer增量但native重拼整串或client重建整块同样失败。
   超长纯文本paragraph单巨大TextNode为必测反例：统计bounded leaves/versioned payload、text-splice字节与native map UTF16切点、DOM Text range替换长度。候选parse已局部但整literal/HTML materialize、整段传输或paragraph替换仍判失败；显式legacy全文导出O(N)单列允许，不得编辑热路径隐式调用。
10. 采集GC次数/时间、peak和steady RSS、source oldbuffers、checkpoint/snapshot/index/cache/队列字节、10,000edits后retained memory及close释放；有界quota淘汰/背压均测试，不能只看一次编辑小内存。
11. 性能/正确性失败交原owner，报告具体Task编号、最小样例与缺口；修复后先重验受影响门槛，再在新变更/风险依据下补全矩阵，不在验证任务直接抢改产品实现。

## Acceptance

- **第三方增量能力可选：** 01冻结的未修改旧插件源码在仓颉1.1.0编译、注册、普通parse/append通过；无editing声明默认compat，同plugin混合parser能力分别调度，默认false/安全默认方法生效；有边界/状态/语义隔离证明才局部完整解析并保留无关单位，无证明整会话full-rebuild；逐个实际facet缺失给出owner/parser/facet/reason/范围，与fresh oracle和版本一致，单独bool=true不替代能力完整性验证。strict仅显式开启且拒绝无source/ID/state/patch变动；默认不是stateless/local-safe/空restore。30内置仍须全部真适配，不以第三方兼容测试替代。

- **CLI迁移与渐进首屏：** render/build文件输出、render --page独立单页能力及Markit append API回归通过；旧--preview-stream/--incremental明确报错并提供新help，扩展无旧flag调用。worker --stdio自动资产/cache和URI路由通过；延迟后部服务时前部完整事务先显示、后续多次原子commit，cancel/version/epoch安全，单个大commit不通过。检查没有因同名incremental误删内部build方法。

- **新增发布阻断门槛：** batch parse满足01实施前冻结的测量协议与预算，目标为噪声之外无可测减速；没有观测/结论不确定则标缺口，不自动通过。syntax与semantic分离、07-P生产纵切和15 SeaJson/framing选型均有实际证据；任一失败退回owner修复并重验。

| 门槛 | 可观测判据 |
|---|---|
| 覆盖 | 30/30内置按实际facet通过，无永久fallback；三格式/JSON、Task01代表性bundle/顺序矩阵、相关pairwise/真实风险及固定seed组合、typedcodec和旧API通过；不要求排列/子集穷举 |
| source与身份 | 独立rangeoracle通过；已知ID/span纠错明确记录；无重复ID、未变身份漂移或旧snapshot污染 |
| 普通局部工作量 | 未改syntax/兄弟子树parser0调用，未变CodeHL/公式/图0调用；warm未改项目文件read/parse0；无常态wholeowner/fullpage/fullproject路径 |
| code行全链路 | 千/万行fence改单表达式只重扫至词法state收敛、只拼改变行片段/row patch；未改行ID/DOM/选择/滚动保留，整literal/HTML join与整codeblock innerHTML重置0次 |
| 超长纯文本全链路 | 单巨大TextNode场景普通字符edit用有界payload/text-splice，native UTF16 map正确，正常edit整literal/HTML materialize和整paragraph DOM替换0次；显式全文导出另测 |
| native延迟 | warm普通局部native p95≤30ms；当前为拟议未实测，报告不达标原因，不改数字掩盖 |
| 可见/DOM | edit至可见p95≤100ms（含debounce），DOMpatch p95≤16ms；IPC/DOM工作量有实际计数 |
| 规模趋势 | 保持变更及依赖范围相同、无关文档体量10倍时，warm local p95≤2倍；必要对固定小/大规模配对报告并统计置信/抖动，不以噪声样本硬判 |
| 真实广域影响 | 未闭合/级别/全局配置等另报传播原因、范围、耗时，仍与oracle一致，不拿此类样例替代局部性gate |
| 生命周期 | cancel/backpressure/restart/close、多doc/project/language正确；连续edit内存有界且引用释放；无每editspawn/getText/fullMDhex/fullHTMLreconcile |
| 自动归属与语言 | 多root/多文档目录打开Markdown自动归属，无先选项目流程；仅真实归属歧义才确认，各项目配置持久化语言、热切换/重开保持且独立 |
| 可复现 | 命令、seed、构建/机器/版本、数据集、原始结果和失败最小样例齐全；skip明确未通过，不编造现成tag/tool |

全量测试与编辑oracle共用语法实现，但rangeoracle必须独立；不因full parser已有bug就关闭该项校验。未通过项进入verification-gaps并阻止Task18放行，修复由所属owner完成后重新审查。

## Verification Record

- 本轮：静态读取任务/设计锁/插件清单并编写本方案；未执行新编辑实现、oracle、benchmark或VSIX测试。所有门槛Pending。
- 未来：按实际包运行`cjpm test`与已落地的编辑/协议/扩展scripts；`EditingDifferential`、`SourceRangeOracle`、`WarmEditPerf`等名称是拟新增tag/tool，不声称现存可用。
- 每次记录scope、完整命令、pass/fail/skip、样本数/seed、原始指标文件位置与后继Task；不将旧benchmark或方案文件存在视为新功能通过。
