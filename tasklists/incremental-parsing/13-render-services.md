# Task 13：CodeHL、MathTex 与 Mermaid 派生服务复用

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本任务验证CodeHL、MathTex与Mermaid相关实际渲染服务的复用/失效：CodeHL按行状态传播至收敛；内容变化的公式/图允许单元内完整重算，未变单元应复用。它们按既有插件接入路径覆盖，不新增或冲抵30插件计数，也不要求另造通用计数框架。

标准库热路径只选择性查阅用户提供的只读源码 `C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`：针对本任务实际使用的操作核实复制、扫描、分配及源码/运行SDK版本对应；有争议仅做最小实测，不开展全面标准库研究或新增框架。

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

更新时间：2026-10-21。当前只有源码调查和方案，没有新服务实现、性能或零调用通过结论。

## Execution Contract

- Depends on: Task 09、Task 10（仅这两项硬依赖）。
- Unlocks: Task 14；14 还需 Task 12。
- Execution: 并行 C，与 Task 11 的 i18n 投影隔离；09/10 及其继承的 07 交接经协调者审阅后执行。
- Delegated owner: 重型渲染服务子 agent，由协调者指派。
- Scope boundary: 只拥有 FencedCode 的 service 适配文件 `fenced_code_block_codehl_renderer.cj`、`fenced_code_block_mermaid_renderer.cj` 及 07 留出的新增服务 adapter 文件；`codehl/`、`mathtex/`、`mermaid4cj/` 内 cache/服务接口实现及专用测试；GFM `math_block_renderers.cj`、`inline_math_renderers.cj` 的数学服务适配和相应独立测试。
- 不拥有：围栏 parser/state/line rules/group/i18n 配置及一般 HTML renderer、i18n 插件或 11 的文件，core/bundle/共享 helper、CLI worker/webview。围栏 syntax→服务请求及版本化 payload 接缝须由 07/09/10 交付；若不足，退回串行交接，不与 11 并发争改。不得借本任务顺手重写外部库语法算法。
- 输入：09/10 冻结的公式请求与 typed 节点/依赖，07 的围栏服务接缝和版本化代码单元/源行迭代、02/04 的资源事务和稳定身份契约，及 [GFM 服务调查](plugin-gfm.md#12-codehl-联动逐行状态必须真正收敛)。
- 输出：按需、版本化、可取消的服务实现；代码行增量与行 patch 契约；公式 AST/目标输出缓存；图模型/layout/SVG 缓存；真调用计数与 14/16 的消费交接。

## Goal

把解析器的局部性延伸到真实高亮、公式、图和输出传输。未变昂贵单元零计算；大代码块不仅只 tokenize 必要行，还不能在正常编辑热路径重新 join 全部 code literal、串联全部 HTML 或发送全代码块输出。

## Current State

详细事实/案例：[CodeHL](plugin-gfm.md#12-codehl-联动逐行状态必须真正收敛)、[MathTex](plugin-gfm.md#13-mathtex-联动公式单元缓存禁止误报流式增量)、[Mermaid](plugin-gfm.md#14-mermaid-联动围栏插件分支与原生渲染触发时机)。

- [围栏 finalize](../../markit/src/plugins/standard/block/fenced_code_block/fenced_code_block_parser.cj) 当前 join 整个 literal，再依次调用 native Mermaid 与 CodeHL；HTML renderer 缺缓存时仍可能现场高亮。Mermaid 是围栏插件分支，不是第 31 个 Plugin。
- [CodeTokenizer](../../codehl/src/languages/token.cj) 已有 tokenizeLine(line,state)，完整 context 保存动态 end/while/captures/grammar 等；[Highlighter](../../codehl/src/core/highlighter.cj) codeToTokens 支持 initialState，但遍历给定所有行，只有整体 finalState；CodeLine 无逐行状态，状态无结构等价协议。
- CodeHL dual-theme 已共享一次 tokens；grammar/tokenizer/regex/theme 有静态 cache，但这些不是编辑行缓存，也未自动纳入外部配置文件内容版本。
- [MathParseSession](../../mathtex/src/parser/session.cj) feed 只积累，snapshot/finalize 完整 TexParser.parse；[MathRenderer](../../mathtex/src/core/renderer.cj) 各目标重新 parse，未有 AST cache。
- [MermaidRenderer](../../mermaid4cj/src/renderer.cj) flowchart Dual 已一次 parse/layout 后双主题 writer，其他图型 Dual 路径可能重复 parse。当前无编辑缓存，idPrefix 含 node.id。
- [native viewer](../../markit-kit/ts-render/src/renderer/mermaid-viewer.ts) WeakMap 以 DOM container 保存状态；全量替换 container 会丢缩放/平移。本任务只给 patch/identity 合同，前端改造由 16 拥有。

## Follow-Up Work

### 1. 阶段、资源请求与所有权

1. 接入 07/09/10 的按需请求，不在 syntax 阶段无条件执行 native render；请求包含文档/版本、稳定 unit、内容/配置/依赖 key、输出目标和取消信息。cache hit 前不得先 parse/layout。
2. Mermaid 分支命中后不再生成最终不会消费的 CodeHL 输出。Markdown/Typst 等不消费 native HTML 的请求不得仅因 parse 而生成双主题 SVG；保持现有各目标显式 API 输出语义。
3. 发布结果前检查 unit key/版本仍匹配；旧计算可保留内容缓存，但不得挂接到新版本节点或发出过期 patch。撤销 language/config/group 切换后不适用的旧输出和依赖。
4. 与 11 只通过冻结 key/版本交互：targetLanguage、i18n 可见行和结构投影作为输入，13 不改语言规则/旧 i18n 文件。11/13 共享需求提交串行集成。

### 2. CodeHL 行增量与不 materialize 的热路径

1. code syntax payload 使用 versioned source view、持久行索引及 mapped source anchors，保留未变行/片段。不能每次 finalize join 全 literal，再向服务传完整 String。07 未交付时以具体证据退回前置修正，不在本任务越权修改 parser/state。
2. 服务从源 iterator 读取必要行；行记录至少含 stable line ID、text/version、inState/outState、tokens、source map 及 render revisions。line ID 是持久身份，不等于物理行号、offset 或内容 hash；相同文本的两行仍需不同身份。
3. earliest changed line 从前一可信 outState 恢复，按旧新稳定行映射重算；完整 context 的结构等价包括 mode、scope/contentScope、动态 end/while、applyEndPatternLast、patterns/captures identity、grammarScope、跨行标记，不能仅比较栈深或 scope。
4. 首个完整 outState 与对应未改后缀输入/配置一致的合法边界停止 tokenize；长期引用使用不可变 snapshot，不可浅拷贝可变 context 污染旧状态。外部 grammar/alias 内容版本变化按真实范围使 token cache 失效。
5. tokens 和 theme/line metadata 分层。主题变动只重做需要的样式/片段；行号、高亮、i18n visible 改动发布 metadata delta/range transformation，tokens 调用为零。不能以 tokens=0 掩盖所有行重新串为完整 HTML。
6. 实现独立行片段 renderer/缓存和 ordered patch；插删/替换必要行，保留其他行 DOM。位置与样式元数据用独立 patch，不为前方插行重建所有后缀 span。
7. fileGroups 以真实 group 为子单元保持单独行号作用域与缓存，group 分割变化按受影响组处理。07 语法 group 接缝不足需明确回退依赖审查，不重写 i18n/line-rule 文件。
8. legacy literal/codeToHtml/整块 toHtml 作为调用者显式请求可按需 O(N) materialize；正常编辑事务不必经该路径。保留兼容 API，不以删去 literal 字段读取能力换取局部性。

### 3. MathTex expression 与目标输出缓存

1. expression cache 按 TeX、displayMode、parser/command/config 版本组织；HTML/MathML/Typst 共享一次 parse。输出 cache 再含目标、classPrefix/errorColor 等 writer 选项及诊断行为。
2. 内容变化允许只在该公式内部完整 parse；未变公式 parse/writer=0，位置位移仅更新外层 source/anchor。unsupported/fallback/throwOnError 语义与完整路径一致。
3. 公式内容缓存与挂载节点 identity/目标版本分离；删除或替换只撤销该 unit 的引用/输出，不残留旧图形。设置 quota/eviction 与真实命中诊断，不无限持有文档/历史树。

### 4. Mermaid 模型、布局与 SVG identity

1. 缓存 diagram kind/parse model/layout/双主题输出，key 含 source、options、引擎、textMeasurer 语义版本；允许变化的单图完整 layout，不承诺图内部局部布局。
2. 维持 flowchart Dual 一次 parse/layout；其他图型按实际公开模型能力共享 parse，布局依赖核实后再共享，不假定所有图已有同一 layout API。
3. 带 idPrefix 的 SVG 不能跨节点照抄。使用稳定 unit prefix 或可实例化缓存模板，验证 DOM id、url(#id)、href/xlink:href、clip/mask/marker/style scope 等引用一致且页面唯一；可见 anchor/href 不得被归一化抹除。
4. 输出图主体 patch 与外层 anchor/source/position 分离，未改图保留 container 和资源引用；交给 16 的合同明确 viewer 状态保留和改图内部 patch 策略。

### 5. 冻结给 Task 14/15/16 的行 patch 合同

| 合同字段/操作（语义要求，最终命名由前置协议决定） | 本任务交付与消费边界 |
| --- | --- |
| document/version/unitId/groupId/stableLineId | 13 发出具版本和唯一目标的资源行输出；15 保持版本，16 仅消费 |
| line insert/remove/move/content replacement | 源行顺序与身份精确对应；未变后缀无需完整 HTML |
| line metadata/style/visibility delta | 行号、高亮、i18n 可见性和主题变化与 tokens 解耦，可范围表达 |
| mapped source/position transform | 能回原始 byte/rune/UTF16，插行不逐行重写完整 source HTML |
| retained resource/container identity | 未变图/代码行的 DOM 与交互状态保留，过期结果可丢弃 |
| generic render subunit slots | 使用 04/06 冻结的通用子单元/有界 payload；代码行和长纯文本 paragraph 分别提供行片段及 text-splice，消费者不需 Markdown 专用分支 |
| capability/version and failure/resync | 协议版本不支持时显式重同步/诊断；内置最终不靠整块 HTML 热路径 |

此交接须由协调者与 16 作者审阅冻结；13 不修改 16 的实现文件，16 不通过前端正则识别代码行/Markdown 来补后端缺口。

与 15/16/17 的交接验收保持一致：千/万行代码中改单表达式不重置整 pre/code.innerHTML，未改行 DOM/selection/scroll 保留。长纯文本 paragraph 的有界 payload 与 DOM Text range/text-splice 由 04/06 及其渲染交接负责，13 只消费通用 subunit 契约，不能将其误改为 code 专用协议；不能只有 parser/tokenizer 局部而字符串/DOM 仍全量重建。

## Acceptance

- [CodeHL 案例](plugin-gfm.md#12-codehl-联动逐行状态必须真正收敛)：大 fence 中普通一行修改，仅沿词法状态依赖重算至首次合法收敛；注释/多行字符串开闭变化传播至真实新边界。记录真实 tokenizeLine 次数及扫描、状态比较、片段输出字节。
- 普通一行编辑不执行整 code literal join、不重串/传输全代码块 HTML；稳定 line IDs 和行级 DOM/source-map patch 已由服务测试证明。materialized bytes、HTML encoded bytes、IPC 计划字节与编辑范围相符，不能只验 tokenizer 调用。
- 主题或 highlight/i18n/行号变化 tokenizeLine=0；使用片段/元数据/range delta，不全量重拼后缀 HTML。前文普通段落编辑该 code 单元 tokenize/HTML writer=0。
- [MathTex 案例](plugin-gfm.md#13-mathtex-联动公式单元缓存禁止误报流式增量)：单公式变化且请求 HTML+Typst 时 parse=1，其余公式 parse/writer=0；只位置变化全部零调用，displayMode/options/fallback 正确。
- [Mermaid 案例](plugin-gfm.md#14-mermaid-联动围栏插件分支与原生渲染触发时机)：两张图只改其一，另一图 parse/layout/writer=0；flowchart Dual 新内容 parse=1/layout=1。前插 fence 不改旧图 prefix，所有 SVG 内部引用及外层可见 anchor 正确。
- language `mermaid→text→mermaid`、enable/config/grammar/version 变化撤销旧输出，无过期结果覆盖；不消费 Mermaid HTML 的路径 native parse/layout=0，除非该目标显式请求。
- 各服务计数从真实入口 spy 记录，不能用相同 HTML 推断零调用；cache quota/取消/旧版本/并发 snapshot 隔离有证据。公式/图内部全量允许，大代码行增量为必须交付。
- 三目标与旧显式 APIs 保持兼容，最低仓颉 1.1.0；文件 diff 不侵入 11 i18n/围栏 parser/state/shared helper/core；行 patch 合同已冻结并交接。

## Verification Record

- 本轮只静态阅读已有服务/适配/库源码和三组清单，未修改实现或执行新测试。
- 未来已知命令：分别在 `codehl/`、`mathtex/`、`mermaid4cj/`、`markit/` 执行 `cjpm test`，当前未执行。实际仓颉 1.1.0 编译环境及命令结果须记录。
- 拟新增：editing row-state convergence spy、source-materialization/HTML byte counter、formula AST cache spy、diagram layout/SVG-reference/line-patch contract suite；名称/tag/路径待实施创建，不冒充现有工具。
- 后续回报：真实调用与字节计数、quota/过期事务结果、每服务至少两例、冷/暖分离、失败与共享缺口、13→14/16 合同。运行性能阈值以 01/17 冻结负载为准，不凭静态代码宣称达标。
