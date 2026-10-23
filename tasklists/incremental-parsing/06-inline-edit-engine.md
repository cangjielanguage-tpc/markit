# Task 06：inline 候选与安全窗口

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Done

## 2026-10-23 最终交付与所有权

Task06 已由 root 按本次用户裁剪范围验收：whole4 编译 exit0，官方 InlineEditing 25/25，全量 27 包 717/717、零 skip/error/fail；冻结旧第三方 148 条记录 × 11 字段零差。原同 O2 driver 一次 AB 两 exe 各 84 样本且 exit0；large Stream 均值 +0.55% 如实保留，不声明统计无退化。完整命令、哈希、历史失败和最终日志见下方 Verification Record。

| Owner | 最终交付范围 |
|---|---|
| task05_engine（前期）/ task04_tree（后期唯一 writer） | 可执行 inline facet/session、递归与语义局部重放、raw/decoded payload 证明、主 8 个真实定向用例与最终 helper |
| source_lifecycle | rope/window/persistent mapped view 与 7 个 view 用例 |
| session_checkpoint（前期）/ task02_contracts（最后窄接口） | 成功/失败 attempt、owner/key/nested/length 持久索引及 6 个用例；最终 existence-only hasReadingKey |
| task04_tree | bounded PersistentTextPayload、historical document resolve 与必要 typed bridge |
| task02_contracts | 公共 LogicalTextSplice、只读 registry seam、共同 block/raw-splice 接线集成审查、唯一编译/官方程序/全量/148 对照与最小 O2 协调 |

这里完成的是核心编辑引擎，内置插件仍为 0/30 已验收。真实 ParagraphChildrenBuilder、Heading、ReferenceLink 等生产路径与 SourceLine/block 前置 materialization 成本由下一步 07-P 真实纵切验证。

## Execution Contract

- Depends on: Task 05。
- Unlocks: Task 07。
- Execution: 串行；05完整事务原型和块会话审查通过后实施，本任务审查后才释放07。
- Delegated owner: inline候选与局部编辑子agent，实施时由协调者指定。
- Scope boundary: 未来拥有`markit/src/core/inline/`与独立inline editing/property/benchmark测试；可在05冻结接口上接owner/read evidence，不改各语法plugin算法、source/tree底层、CLI/webview或新建core Markdown语法表。共享契约变化退回02审查，block集成修改须列明并串行处理。
- 输入：05可运行edit/checkpoint/nested事务、02inline facet和成功/失败读取协议、03映射与04索引/负依赖、01oracle/collector。输出：candidate索引、成功/失败读取区间与安全窗口算法、递归子单位复用、超长paragraph局部性证据，交给07适配真实Standard语法。

## Goal

在保留同一inline语法实现的前提下，让编辑只重试受影响candidate与必要上下文；成功token和失败匹配的读取依赖共同决定安全窗口，普通超长paragraph局部正文编辑不无条件整段scan。

## Current State（历史计划基线）

- `markit/src/core/inline/inline_parser_engine.cj::InlineParserEngine.parseRange`先scanRange整个range，再逐byte candidate调用tryParse；没有编辑索引、read footprint或旧token复用。
- `inline_dispatch_table.cj::InlineDispatchTable`按startBytes与priority分派，scanRange遍历range；`InlineParseResult`仅node/consumedBytes/consumedRunes，None无法说明读取至何处。
- engine先检查`InlineUtils.isEscaped`；Bold/Italic/Link等会递归appendInlineChildrenRange，InlineCode可匹配跨newline，ReferenceLink依赖symbol lookup。分隔符、escape和negative查询规则来自具体parser，不能在core猜测。
- `ParagraphChildrenBuilder.appendChildren`把逻辑段一次拼接供inline；仅缩小parseRange但仍每edit拼接/扫描整个超长paragraph，不能算真正局部。
- 超长无候选paragraph可表现为单个巨大TextNode；candidate0次不证明局部性，literal重拼/整Text HTML/全Text escape扫描也要计数。内部text分段不能未经基线决策改变legacy AST/JSON的logical Text结构。

## Follow-Up Work（计划拆分，完成证据见下）

1. 按02facet实现分层candidate索引与局部文本view，记录每次成功/失败attempt的读取区间、左右上下文、delimiter/escape状态、nested owner、语义正负读及grammar/config版本。失败无closer扫描到range尾也必须入索引。
2. 为tryParse桥接带证据的结果/失败，不复制语法算法；插件声明候选触发、读取与恢复规则，core只管理通用区间、cursor、状态和调度。legacy String adapter可迁移但不能成为最终整段materialize出口。
3. 编辑时以实际source map命中候选/attempt read footprints，包含边界插入亲和和因编辑新出现的start candidates；向前/后扩展到facet证明的安全点，不用固定N字符/行或内置标点正则。
4. 覆盖escaped opener和escape parity：本次token未匹配可能是前置转义造成，需保存足够前文状态。delimiter run长度、邻字符变化、quote/bracket嵌套均由插件read evidence影响窗口。
5. 递归inline owner具备局部checkpoint与子索引；编辑子label/强调内容时复用未变兄弟及必要父结构，保留语义效果归属；opaque body不执行未声明递归解析。
6. 处理missing closer和missing symbol：后方插入close、前方插入open、删除escape或新增definition均可唤醒先前失败；旧成功token缩短/消失则撤销原children/effects，释放范围重新分派。
7. 与05块/段落边界联动：段落合并/拆分、termination与map变化须按facet重新定owner。无需块变化的普通编辑不能让block层先整段inline预扫再进入本算法。
8. 实现收敛：对应旧边界的新cursor、candidate/attempt依赖、递归state/effects、后继上下文及身份映射一致才复用后缀；真实未闭合依赖可扩到整owner/EOF，但必须返回扩展原因和读取范围。
9. 接01计数，区分查索引、读取字符、候选重试、失败读取、递归parse、token复用、full-owner scan/materialize。给07冻结inline facet适配示例与测量工具，不能仅提供新接口让后续插件默认fallback。
10. 消费04的bounded内部text leaves/versioned payload，candidate遍历、escape与Text合并均可局部splice；为后继renderer/DOM提供版本化text-splice或render subunit patch交接，不能因一个logical Text无children就重传整段HTML。保持legacy同一logical Text的typed兼容view，显式getliteral/toHtml可按需O(N)，正常editing不得必经materialize。02原型应已验证public String/renderer cast桥接，未证明处退回02，不在core内偷偷改变observable children。

## Acceptance

- **新增交接门槛：** 向07提交真实超长单行生产纵切的计数陷阱与接口：不仅监测inline扫描，还记录SourceLine/block入口前的String构造/复制和整段materialize。06测试facet通过不代替07真实parser证据；07必须先完成下述pilot才展开剩余适配。

- 小型可跑验收由测试插件实现自己的delimiter/escape/recursive规则，完整解析与editing共用同一parser；先缺closer后在远处补close、删opening/escape、改变delimiter run与nested内容，逐步fresh oracle相等，失败attempt能被正确唤醒。
- 一个missing语义key的失败candidate在key新增后被重试；已有key移除后旧token及owner effects撤销。只记录成功token的实现必须被测试检出。
- 超长普通paragraph（规模由01fixture固定）中部改一个非触发字符：工作量由局部窗口/索引与实际输出规模决定，不随整个paragraph线性扫描；未变token/子树ID保持。设置全文materialize/完整scan计数陷阱，不能靠快速全段扫描过关。
- 补充无任何语法的超长单logical Text：改一字后candidate遍历、Text合并、转义/渲染和patch字节均不因无关Text长度线性增长。内部bounded text subunit可改变，但legacy AST/JSON的Text节点结构不漂移；显式全量导出另算O(N)，不能在每次编辑暗中调用。
- 合法全范围扩展案例（远处新增closer/原closer删除）可重试较长范围，但诊断明确是哪个插件read dependency阻止收敛，不能把所有编辑默认标成该原因。
- 中文/emoji/CRLF/跨mapped segment与边界插入时source映射正确，递归父子范围/parent/ID无污染；取消/过期inline事务沿05语义不回滚已ack源码。
- core不识别Markdown delimiter语义/内置插件name/kind来选窗口，调用实际facet；保留legacy四模式语义；正式1.1.0验证由用户延期，本轮实际SDK为1.3.0-alpha。
- 07取得candidate/read evidence/owner接口、typed codec与完整05原型审查证据；本任务通过不等于13个Standard或全部30插件已适配，最终真实插件局部性另由07及后续验收。

## Verification Record（最终，2026-10-23）

root已审查并按用户修订范围验收 **Task06 Done**。实际SDK为1.3.0-alpha.20260920003052；manifest最低版本未提高，正式1.1.0验证/通用oracle计数benchmark框架保持Deferred by user scope，不记为通过。

- 正常 `cjpm test --no-run --no-progress`（cwd `markit/`）whole4 exit0：[构建日志](task06-verification/integrated-compile-4.log)。官方binary console运行避免原cjpm runner TCP10013故障，未替换测试框架。
- 官方InlineEditing **25/25通过**，0error/failed，137为tag未选：[日志](task06-verification/editing-inline-whole-test-2.log)。包括view7/index6/main8/真实Markit桥接3/递归1；递归单case含多次child编辑、双owner同key正负依赖、ordered following splices、跨epoch投影/历史锚点、父0重解析及未改兄弟/effects/fresh/旧snapshot。
- 原wrapper全量 **27包717/717通过，0skip/error/failed，所有包exit0**：[summary](task01-baseline/task06-full-console-1/summary.json)。Unit162、Source21、Streaming15均通过。
- 148条37fixture/四模式观察逐11字段与冻结01零差，observations SHA同为 `dd0eb7467e170fbb4d54c533235f99225087e814a93f625bfe9aef2d46ce6b1e`：[比较](task06-verification/legacy-comparison-1/versus-frozen01.json)。原3个stream fragment差和known protected重复ID原样保留。
- 只复用原v2 `-O2` driver一次reference→candidate；compile/两exe均exit0，各84samples，21pairs/10warmup/原ABBA配置未改：[原始比较](task06-verification/batch-time-comparison.json)。均值small String37.418→33.205us、Stream42.039→33.068us；large String28.097→27.074ms、Stream27.107→27.256ms（+0.55%）。单AB有快有慢且历史噪声宽，不声明统计无退化或速度提升，不追加采样。
- 初始主8的双Text/fresh差异、两次whole集成类型问题及bridge缺实际paragraph/SourceLine字段错误均已保留在[验证记录](verification-log.md)，原fresh/abc/aZc/旧snapshot断言未删除；fixture的真实legacy paragraph仅在Strict拒绝且factory/parser零调用断言之后注册，生产语法未修改。

## 最终实现与交接边界

- 执行内联facet以真实byte/EOF/length/正负key读取确定恢复范围；语法闭包与literal重新解码分离。没有core Markdown标点/name/kind判边界。具体fixture legacy/editing共享同一grammar。
- immutable view与persistent attempt/nested-key索引支持局部splice；hasReadingKey直接AVL存在性查询，不物化热门key所有读者。512KiB单logical Text通过受限read/slice与小LogicalTextSplice、稳定ID/未改token引用断言。
- raw/decoded与坐标恒等证明分开：literal工厂默认None，具体provider显式提供raw映射；快速splice验证本次插入，不从等长样本猜测。公开legacy Text结构和typed metadata不变，显式全量导出仍可O(N)。
- 旧InlineParseResult保留原三字段存储，编辑专用EditingInlineParseResult才存raw/nested handoff。Strict在source/session创建前预检真实facet/grammar/实例身份，执行期再次guard；外部旧插件Compat明确整会话fresh fallback。
- nested更新真实调用child.prepare/replaySemantic，按actual read key定位子owner；provider project/rebase证明当前view映射。childrenEdit及following由已有统一tree/effects/patch原子门交付，不回退已ack源码。
- 最终产品与8case主要owner为task04_tree；初期source/index/bridge由session_checkpoint等实施。原owner与fresh接手者capacity停止后，root将三helper最终唯一权转task04_tree；02维护hasReadingKey、共享契约、必要集成fixture修、全部实际构建/运行与本任务验证文档。

## 后续门槛

本任务通过只证明通用内联引擎与具体可执行fixture，**不表示任一内置已完成适配，当前仍0/30**。Task07必须先执行 **07-P真实Standard生产纵切**，验证SourceLine/block入口前的扫描、复制、materialize与实际编辑局部性；toy fixture速度不是生产结果。renderer/DOM/IPC消费与全部30插件实际适配由后继任务验收。API使用细节与生命周期边界见[引擎交接](task06-engine/engine-implementation.md)。Task16验证后停止等用户验收，不进入17/18，不提交推送。
