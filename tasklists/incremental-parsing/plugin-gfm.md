# GFM 插件与 CodeHL、MathTex、Mermaid 增量适配方案

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本清单逐个核对9个GFM插件（4 block + 5 inline/脚注），并覆盖其CodeHL/MathTex/Mermaid实际接入路径；服务复用不是新增插件计数或其他插件适配的替代。

更新日期：2026-10-21。状态：源码调查已完成；本文所有“拟议”能力均待实现和验收，不能据此认为项目已支持编辑增量。

## 执行合同与范围

- 文档根目录：`tasklists/incremental-parsing`，由用户确认；本文仅拥有 `plugin-gfm.md`，不修改实现、其他方案文档或进度百分比，不提交 Git。
- 本文目标：为九个 GFM 插件以及 CodeHL、MathTex、Mermaid 的适配提供逐项代码依据、边界、状态、依赖、缓存、收敛规则和编辑验收。
- 依赖：根方案先冻结编辑事务、源位置重定位、稳定节点标识、插件增量能力注册、可撤销贡献、依赖索引、缓存版本和诊断计数契约；这些契约通过协调者审阅后才能实施适配。
- 并行边界：独立插件的适配可在共享契约冻结后分波并行；`PluginRegistrar`、`ParseSession`、共享渲染注册表等文件由串行契约任务负责。围栏代码、CodeHL 与 Mermaid 共用围栏代码插件实现，必须由同一任务拥有或显式串行交接，不能并行争改。
- 后继门禁：每项适配提交新全文基准对比、实际重算计数及缓存/依赖失效证据，协调者审阅后才进入集成。本文不是编号任务的替代物，具体编号和所有权由总执行图确定。
- 排除：本次只编写方案；没有修改或运行新实现，也没有宣称下文案例已通过。

## 1. 已核实的基础事实与完成约束

### 1.1 注册入口及内置适配范围

[GFMBundle.plugins](../../markit/src/bundles/gfm_bundle.cj) 当前依次组合以下 28 个内置插件，版本为 2.0.0，并声明 `includesStandardMarkdown=true`：

| 顺序 | 插件 | 所属范围 |
| --- | --- | --- |
| 1–7 | BlockquotePlugin、HeadingPlugin、AutoAnchorPlugin、SetextHeadingPlugin、DividerPlugin、HTMLBlockPlugin、MathBlockPlugin | 块及后处理 |
| 8–14 | FencedCodeBlockPlugin、TaskListPlugin、AlphabeticListPlugin、TablePlugin、ListPlugin、InlineCodePlugin、CommonMarkAutolinkPlugin | 块与行内 |
| 15–21 | AutolinkPlugin、HTMLInlinePlugin、LinkPlugin、ImagePlugin、ReferenceLinkPlugin、EntityReferencePlugin、FootnotePlugin | 行内及符号 |
| 22–28 | InlineMathPlugin、StrikethroughPlugin、RelaxedEmphasisPlugin、BoldPlugin、ItalicPlugin、HardBreakPlugin、ParagraphPlugin | 行内与段落 |

本文详细覆盖 GFM 目录内九项：TaskListPlugin、AlphabeticListPlugin、TablePlugin、MathBlockPlugin、AutolinkPlugin、FootnotePlugin、InlineMathPlugin、RelaxedEmphasisPlugin、StrikethroughPlugin。其余 19 项由其他清单覆盖；完成本文件不等于完成 GFMBundle 或全部内置插件适配。

### 1.2 当前扩展契约的缺口

事实证据：[PluginRegistrar](../../markit/src/core/plugin/plugin_registrar.cj)、[SessionState/SessionStateSnapshot](../../markit/src/core/session/session_state.cj)。

- 现有注册类别包括 leaf/continuation/paragraph block parser、inline parser、session state、node batch processor、emission filter、HTML/Markdown/Typst renderer、session finalize 和 post finalize。
- 当前注册器没有声明重解析边界、前后观察窗口、恢复 checkpoint、结构等价、贡献撤销、依赖传播、缓存版本或重算收敛的专用接口。
- `SessionStateSnapshot` 仅保存 `dynamicName`；`SessionState` 只有 `reset()`、`snapshot()`，没有恢复操作。不能把当前 snapshot 直接当作可恢复增量状态。
- 当前 GFM continuation parser 均在 `finalize` 中重新构造所属块及其子节点，没有 item/row 局部编辑入口。
- 普通 GFM renderer 没有自己的输出缓存。下述“缓存键”“恢复”“贡献”“窗口”都是拟议契约角色，不是已存在的 API 名称。

### 1.3 不可绕过的设计与验收要求

1. 所有语法识别由插件提供。核心只处理通用编辑事务、源索引、状态恢复、调度、依赖和缓存，不识别 `$`、`$$`、列表 marker、表格 alignment、脚注或 `mermaid` language。
2. 内置插件必须最终提供相应的增量能力；缺能力时全篇 fallback 只能是迁移状态，不能记为完成。未知第三方插件可明确退化，诊断必须说明原因和范围。
3. 局部块的子节点可能由其他插件创建。例如列表或表格 cell 内有脚注引用，局部块边界稳定也不能跳过该子插件的符号贡献撤销和依赖更新。
4. 每次编辑先撤销被替换子树的旧解析贡献及派生贡献，再提交新贡献，避免残留编号、重复定义标记、三线表样式和隐藏 divider。
5. AST/渲染一致性分别验证；只复用 AST 却全篇重新调用 CodeHL、MathTex、Mermaid，不能算性能验收通过。
6. 外部公式内部解析和单图布局允许以一个公式/diagram 为单元重算；未变单元必须零调用。大代码块内部必须逐行复用并以完整 tokenizer 状态收敛，不能长期整块重新 tokenize。
7. 所谓“相等”必须包含影响后续行为的完整状态、容器上下文和依赖版本。只比较 node kind、状态类型名或栈深度不足以证明收敛。
8. 位置位移和内容变化分离。前文插字不应使未改公式/diagram 重算，但其 source span、anchor/source attributes 和 DOM 定位仍须正确更新。

## 2. GFM 插件注册总表

以下 parser priority 是现状事实；不以表内数值推导未核实的调度排序方向。每项 renderer 覆盖 HTML、Markdown、Typst，RelaxedEmphasis 除外。

| 插件 | 注册入口 | 解析注册与状态 | 输出 kind / 后处理 |
| --- | --- | --- | --- |
| TaskListPlugin | [task_list_plugin.cj](../../markit/src/plugins/gfm/block/task_list/task_list_plugin.cj) | continuation；priority 60；start `- * +` | TaskList、TaskListItem |
| AlphabeticListPlugin | [alphabetic_list_plugin.cj](../../markit/src/plugins/gfm/block/alphabetic_list/alphabetic_list_plugin.cj) | continuation；85；ASCII 字母 | AlphabeticList、AlphabeticListItem |
| TablePlugin | [table_plugin.cj](../../markit/src/plugins/gfm/block/table/table_plugin.cj) | continuation；40；`\| - :` | Table、TableRow、TableCell；可选 batch 与 postFinalize |
| MathBlockPlugin | [math_block_plugin.cj](../../markit/src/plugins/gfm/block/math_block/math_block_plugin.cj) | continuation；90；`$` | MathBlock |
| AutolinkPlugin | [autolink_plugin.cj](../../markit/src/plugins/gfm/inline/autolink/autolink_plugin.cj) | inline；750；ASCII 字母数字 | Autolink |
| FootnotePlugin | [footnote_plugin.cj](../../markit/src/plugins/gfm/inline/footnote/footnote_plugin.cj) | definition continuation 40；reference inline 250；state key `FootnotePlugin/registry` | FootnoteDefinition、FootnoteReference；duplicate emission filter |
| InlineMathPlugin | [inline_math_plugin.cj](../../markit/src/plugins/gfm/inline/inline_math/inline_math_plugin.cj) | inline；650；`$` | InlineMath |
| RelaxedEmphasisPlugin | [relaxed_emphasis_plugin.cj](../../markit/src/plugins/gfm/inline/relaxed_emphasis/relaxed_emphasis_plugin.cj) | inline；880；`_` | 标准 Bold/Italic；无自有 renderer |
| StrikethroughPlugin | [strikethrough_plugin.cj](../../markit/src/plugins/gfm/inline/strikethrough/strikethrough_plugin.cj) | inline；850；`~` | Strikethrough |

## 3. TaskListPlugin

### 当前事实与证据

源码：[TaskListParser](../../markit/src/plugins/gfm/block/task_list/task_list_parser.cj)、[TaskListBlockState/TaskListItemData](../../markit/src/plugins/gfm/block/task_list/task_list_model.cj)、[renderers](../../markit/src/plugins/gfm/block/task_list/task_list_renderers.cj)、[list node](../../markit/src/plugins/gfm/block/task_list/task_list_node.cj)、[item node](../../markit/src/plugins/gfm/block/task_list/task_list_item_node.cj)。

- marker 为 `-/*/+` 后空白及 `[ ]/[x]/[X]`；同 `baseIndent` 的 marker 增加 item；更深 marker/普通行加入当前 item；空行继续并令 `tight=false`；其他行关闭并重处理。
- state 保存 baseIndent、tight、items、sourceSpan；item 保存 marker、checked、leadingContent、首行/续行 source spans 与换行终止信息。
- finalize 创建所有 items。单行正文走 inline；多行正文先分 paragraph，遇空行、嵌套 task marker、fence、heading、divider 后进入 detached 模式并 `parseDetachedLines`。
- detached 区域按所有非空行的最小缩进规范化。某一行缩进变化可能影响该 item 整个 detached 子树。
- HTML item renderer 平铺 paragraph；Markdown/Typst list renderer 遍历并组合所有 items，不是每个目标都直接委托 item renderer。

### 拟议能力、快照、依赖与撤销

- 正文/checked 编辑以 item 为优先重解析单元；保留其余 items。marker、baseIndent、空行或脱离缩进变化从前一可信 item 恢复，验证分组、tight、结束边界和后继块。
- checkpoint 至少包含 baseIndent、tight 的汇总依据、当前 item 起点及续行模式；最小缩进参与 detached 子树输入签名，不能只缓存规范化后的首行。
- list/item 的结构贡献与 item 内子插件贡献分开登记。替换 item 时撤销旧 inline/reference/anchor 等贡献；空行删除后重新汇总 tight，不能保留旧 false。
- 无固有全局符号表；但嵌套脚注/引用/锚点依赖必须从子插件组合进入该块依赖。

### 拟议缓存与收敛

- item 模型、各目标 item 片段、list 外壳分层缓存。键包含正文、checked、marker、缩进/规范化上下文、子树与依赖版本、目标和渲染配置。
- checked-only 编辑应复用未变正文的内联解析和昂贵子单元；list 外壳只组合更新，不能重新解析所有 items。
- 分组变化收敛条件：新旧对应边界的当前列表状态、后继行输入、容器上下文一致；否则扩展到 list 结束及下一稳定块。

### 编辑验收

1. `- [ ] alpha` 改 `- [x] alpha`：只有此 item 的 checked/输出变化；相邻 item 和后方大代码块身份复用，CodeHL/MathTex/Mermaid 无关单元调用为零。
2. item 内插入/删除空行或降低 continuation 缩进：tight、paragraph/detached 子块及 list 结束与新全文基准一致，旧 detached 子树贡献不残留。
3. 单 item 的某 continuation 行缩进改变最小缩进：重建其受影响 detached 区域，其他 items 的嵌套代码高亮不重算。

## 4. AlphabeticListPlugin

### 当前事实与证据

源码：[AlphabeticListParser](../../markit/src/plugins/gfm/block/alphabetic_list/alphabetic_list_parser.cj)、[state/model](../../markit/src/plugins/gfm/block/alphabetic_list/alphabetic_list_model.cj)、[renderers](../../markit/src/plugins/gfm/block/alphabetic_list/alphabetic_list_renderers.cj)、[list node](../../markit/src/plugins/gfm/block/alphabetic_list/alphabetic_list_node.cj)、[item node](../../markit/src/plugins/gfm/block/alphabetic_list/alphabetic_list_item_node.cj)。

- marker 是单 ASCII 字母加 `.` 或 `)`，随后为空白或结束。同缩进续项须 delimiter、大小写、expectedLetter 全部匹配；失败会关闭并重处理。
- state 含 baseIndent、startLetter、isUpperCase、delimiter、expectedLetter、tight、items 和 sourceSpan，支持 `z→a`、`Z→A` 回绕。
- 续行、detached 解析与最小缩进处理类似任务列表；finalize 当前构造整个列表。
- HTML 使用 alphabetic-list/uppercase class；Markdown 输出真实字母与 delimiter；Typst 输出 `+` 列表。不得把期望功能当作当前输出语义。

### 拟议能力、快照、依赖与撤销

- 正文改动优先单 item；marker 编辑从前一 marker 的可恢复输出状态启动，处理列表拆分、合并与后续顺序检查。
- checkpoint 必须包括 expectedLetter、大小写、delimiter、baseIndent、tight 汇总以及当前 item 的 detached 规范化输入；仅记录“在 AlphabeticList 中”不够。
- 撤销被替换 item/列表的旧子插件贡献；分裂/合并时重新登记新容器关系及锚点事实，不让旧 parent 或 source spans 留在复用节点上。
- 无自有全局符号依赖；子节点符号和派生渲染依赖照常组合。

### 拟议缓存与收敛

- 缓存 item 正文与 list 元数据/外壳；字母、大小写、delimiter、序列起点影响目标输出，纳入版本。
- 完整 expectedLetter 等状态与旧对应后缀相等后才停；顺序不匹配可能把一块拆成多块，须扩展到稳定列表/非列表边界。
- 文本编辑不得导致其余 items 的 inline 或昂贵渲染重复执行。

### 编辑验收

1. `a. one\nb. two\nc. three` 只改 `two`：a/c 的 item 子树复用，b item 正文更新，三目标与全文一致。
2. `b.` 改 `d.` 或 `B)`：按当前字母、大小写与 delimiter 规则拆分列表；后续非列表块恢复正常，不能只改旧 item 的 marker 字段。
3. `z. end\na. next` 回绕处插删项：expectedLetter 正确传播；状态未等价前不能提前停扫。

## 5. TablePlugin 与三线表

### 当前事实与证据

源码：[TableParser](../../markit/src/plugins/gfm/block/table/table_parser.cj)、[TableState](../../markit/src/plugins/gfm/block/table/table_state.cj)、[TableParsingUtils](../../markit/src/plugins/gfm/block/table/table_parsing_utils.cj)、[TableConfig](../../markit/src/plugins/gfm/block/table/table_config.cj)、[TableThreeLineProcessor](../../markit/src/plugins/gfm/block/table/table_three_line_processor.cj)、[plugin postFinalize](../../markit/src/plugins/gfm/block/table/table_plugin.cj)、[renderers](../../markit/src/plugins/gfm/block/table/table_renderers.cj)。

- tryStart 需要恰好一行 pending paragraph 作 header，当前行是 alignment，header cell 数与 alignment 数一致；成功清除 pending paragraph。表格识别具有向前一行依赖。
- body 是非空且 `isTableRow` 的连续行，否则关闭并重处理。state 保存 headerLine、alignmentLine、alignments、bodyLines、span。
- 行拆分识别 escaped pipe 和 backtick run，不携带跨行 code 状态。每行 cell 数按 alignment 截断或补空。
- `cellSpan` 用 `line.text.indexOf(content)` 定位；同一行重复内容可能定位到第一处。当前源范围不是可靠的唯一 cell 标识，局部更新须解决或规避该歧义。
- `enableThreeLineTable` 默认 false；开启后注册 batch processor 与 postFinalize，递归匹配相邻 hyphen Divider/Table/hyphen Divider。batch 设置 `tableStyle=three-line`；postFinalize 另设前后 divider 的 `render=false`。
- [TableThreeLineDividerEmissionFilter](../../markit/src/plugins/gfm/block/table/table_emission_filter.cj) 类存在，但 TablePlugin 当前没有注册它；不得把它列为已生效 emission filter。
- 三线表处理只设置旧属性，没有撤销逻辑。Typst 输出还依赖总行数和末行边线位置。

### 拟议能力、快照、依赖与撤销

- body cell 内容编辑优先重解析 cell 所属 row 的拆分与 inline，保留其他 rows。cell 的 stable key/source slice 必须来自本次行拆分的真实位置，不能仅依赖当前 indexOf。
- header/alignment/pipe/backtick 编辑至少检查 header+alignment+受影响行；列数改变要更新所有 row cell 模型，但不必重解析内容与上下文不变的昂贵 inline 子单元。
- 表格产生/消失必须由插件声明向前一行 pending paragraph 观察；向后到连续 table body 结束再证明收敛。
- checkpoint 包含 header 输入、alignment/列数、所属容器、body 行边界。alignment 改变而列数未变时可更新 cell 属性并复用未变内容解析。
- 三线表登记相邻 siblings 窗口和可撤销派生贡献：tableStyle、两个 divider 的隐藏状态都属于该匹配的输出。新匹配前先移除受影响旧匹配的贡献，再检查新旧邻域。
- siblings 插删需扫描旧/新匹配可能覆盖的邻接三元组；当前三元组的局部依赖可用编辑项左右各两项作为候选窗口，再按实际匹配更新，不能递归全树才能完成。
- 表格 cell 内符号引用按子插件登记；自动锚点由 AutoAnchorPlugin 贡献，不由核心写死表格规则。

### 拟议缓存与收敛

- cell inline、row 片段、table 外壳三层缓存，键覆盖 alignment、列数、header 标志、tableStyle、row count、anchor/HTML class、子依赖版本。
- 普通 cell 修改不重解析其余 row；Typst 总行数变化可使 table 外壳失效而保留 row/cell 片段。
- parser 在新旧 header/alignment/容器和后缀表行边界相等后收敛；三线表派生计算在受影响邻接窗口中独立收敛。两者都稳定后才发布输出。

### 编辑验收

1. 千行表格的某 body cell `alpha→beta`：只该行拆分/inline 及 table 组合更新，其他 rows 与外部代码块复用；未改公式调用为零。
2. 修改 alignment 列数或冒号位置：补空/截断和对齐与全文一致，列数不变且正文未变时其内容解析可复用。
3. `--- / Table / ---` 删除底部 divider，再撤销：三线 class、Markdown 包装、Typst 边线和两个 divider 的可见性全部恢复，无旧 render=false 残留。
4. 两行普通文本改为 header+alignment，再破坏 alignment：前一行可被接管和恢复；后继块边界、源位置与全文一致。
5. 同行两个相同 cell 内容，仅改第二处：第二个 cell 的映射和 patch 正确，不误改第一处。

## 6. MathBlockPlugin

### 当前事实与证据

源码：[MathBlockParser](../../markit/src/plugins/gfm/block/math_block/math_block_parser.cj)、[MathBlockState](../../markit/src/plugins/gfm/block/math_block/math_block_state.cj)、[renderers/config](../../markit/src/plugins/gfm/block/math_block/math_block_renderers.cj)、[MathBlockNode](../../markit/src/plugins/gfm/block/math_block/math_block_node.cj)。

- opening 行要求 `trimAscii()=="$$"`；缩进超过 4 时取决于 `allowDeepIndentedBlockStart()`。closing 行缩进不大于 openingIndent，trim 后只要求 `startsWith("$$")`。
- state 保存 openingLine、indentLevel、contentLines、closingLine、closed、sourceSpan。
- EOF 未闭合时整个区域 fallback 为 paragraph，再走普通 inline；删除 closing 可能把后文吞到 EOF，不能限定只更新旧 math block。
- HTML/Typst renderer 当前各次调用 MathRenderer 并完整解析；block 的 anchor/source attributes 由 AnchorRenderUtils 组合。

### 拟议能力、快照、依赖与撤销

- 已闭合公式正文编辑以一个 math block 为单元；开闭 delimiter 或缩进变化恢复 opening 前状态，传播到新 closing 或 EOF，验证后继块。
- checkpoint 包含 opening indent/内容、closed、容器上下文和真实源行终止信息。fallback paragraph 与 math 两种结果必须具有可替换的贡献集合。
- 撤销旧 math/anchor 及 fallback 子 inline 贡献再提交新结果，避免删 closing 后仍保留旧图形输出或锚点。
- 无全局 TeX macro 状态是本文已检查路径的现状；如后续引擎扩展上下文，必须引入对应依赖版本，不能无条件以文本作为全部 key。

### 拟议缓存与收敛

- TeX 内容、displayMode=true、目标、MathRenderOptions 和引擎版本组成公式主体缓存；anchor/source 属性放外层，位置位移不使公式主体失效。
- HTML/MathML/Typst 可共享同一解析 expression；内容改动允许整公式内部重解析，不允许无关编辑重新解析所有公式。
- delimiter 保持且 closed 边界/恢复状态等价时，单块后停止；未闭合须延伸到实际新边界或 EOF。

### 编辑验收

1. 已闭合 `x^2→x^3`：仅当前公式产生一次新解析，其他公式与代码块调用为零。
2. 删除 closing `$$` 再补回：paragraph fallback、吞入后文和恢复后继块均与全文基准一致；旧 MathTex 缓存不能错误显示。
3. 公式前插入中文造成 byte/rune 位移：公式主体命中，source spans 和 anchor source attributes 正确重定位。

## 7. AutolinkPlugin

### 当前事实与证据

源码：[AutolinkParser](../../markit/src/plugins/gfm/inline/autolink/autolink_parser.cj)、[node](../../markit/src/plugins/gfm/inline/autolink/autolink_node.cj)、[renderers](../../markit/src/plugins/gfm/inline/autolink/autolink_renderers.cj)。

- 支持 `http://`、`https://`、`ftp://` 及 email；与 bundle 中 CommonMarkAutolinkPlugin 是不同插件。
- URL 扫到非法 byte，再剥离尾部 punctuation；email 验证 local/domain 和点号条件。
- 没有 session state 或自有跨块符号依赖；renderer 依据 url/displayText/raw 及 HTML classes 输出。

### 拟议能力、快照、依赖与撤销

- 先提供所属 inline 容器的增量重解析，不把 core 改成识别 protocol、`@` 或邮箱词边界。更细 token 窗口由插件另行证明。
- inline checkpoint 要包括输入范围、外层容器和其他 parser 的上下文；本插件的语法状态为空，但不能忽略 InlineCode/Link 等外层结构改变。
- 撤销旧 Autolink 事实和相应输出片段；不虚构 session 符号贡献。容器中其他子插件的贡献由组合协议独立更新。

### 拟议缓存与收敛

- token 输出按 raw/url/displayText、目标和样式配置缓存；变化影响向左 token 起点和右侧终止标点，不能只替换原节点 literal。
- 所属 inline 容器结果及外层块边界等价即可停，不扩散到其他 paragraph。token 窗口优化必须证明未读邻接字符不改变识别。

### 编辑验收

1. `https://a.test/path).` 修改尾部标点：链接范围与剩余 Text 正确，邻段不重解析。
2. `a@b.test→a@b→a@b.test`：Autolink/Text 转换与全文一致；反复编辑不残留旧 href。
3. 把上述文本包入 inline code 再移除：遵守 parser 组合语义，不保留旧自动链接。

## 8. FootnotePlugin

### 当前事实与证据

源码：[definition parser](../../markit/src/plugins/gfm/inline/footnote/footnote_definition_parser.cj)、[reference parser](../../markit/src/plugins/gfm/inline/footnote/footnote_reference_parser.cj)、[FootnoteRegistry](../../markit/src/plugins/gfm/inline/footnote/footnote_registry.cj)、[emission filter](../../markit/src/plugins/gfm/inline/footnote/footnote_emission_filter.cj)、[renderers](../../markit/src/plugins/gfm/inline/footnote/footnote_renderers.cj)、[definition node](../../markit/src/plugins/gfm/inline/footnote/footnote_definition_node.cj)、[reference node](../../markit/src/plugins/gfm/inline/footnote/footnote_reference_node.cj)。

- definition 从行首 `[^id]:` 开始，definition id 禁止空白；空行或至少 4 格缩进行续入。content 按 trim 后拼接并走 inline，不调用 detached block parser。
- registry 保存 id→content/number/reference offsets 和 nextNumber；首个非空 content 胜出。duplicate definition 节点标记并过滤；undefined reference 创建空 content 占位。
- 编号按首次引用顺序分配。引用节点和定义节点的 footnoteNumber 是构造时的 immutable 字段，仅修改 registry 不会更新复用节点编号。
- `snapshot()` 仅返回类型名，无 definitions/nextNumber/references 内容及恢复能力。
- HTML reference 显示 number 并链接 definition；Typst reference 每次沿 parent 找 root，再整树 DFS 找 definition 并渲染正文；Typst definition renderer 自身为空。
- 本插件没有注册 session/post finalize；不存在现成统一重编号阶段可直接复用。

### 拟议能力、快照、依赖与撤销

- definition body 改动只重解析该 definition block；reference 插删只重解析所属 inline 容器，随后更新符号索引和派生编号。
- 按 id 保存有序定义候选及引用反向索引；first-use 顺序/number 与解析事实分离。为 immutable number 采用版本化派生视图或安全重建受影响引用，不能静默沿用旧编号。
- 每个块贡献定义候选、引用 occurrence/stable key、位置和顺序。替换/删除块撤销旧贡献，再计算 winner/duplicate 和 first use，不能通过累加 nextNumber 维持编辑状态。
- 结构化 checkpoint/等价必须覆盖定义候选顺序、占位、引用顺序与 nextNumber 的派生依据；也可用持久化索引版本和贡献摘要实现恢复，但现有类型名 snapshot 不满足。
- HTML 引用依赖 number/id 版本；Typst 引用依赖 winner definition body/子依赖版本；definition duplicate 可见性依赖同 id 候选顺序。不存在引用的 id 也须记录缺失依赖，保证之后新增定义能唤醒引用。
- Typst 查找使用索引，禁止每次引用整树 DFS。正文内的内嵌公式等作为共享子单元缓存，definition 文本未变时重新编号不应重新 MathTex parse。

### 拟议缓存与收敛

- 定义模型、定义 body 各目标输出、引用输出、编号派生分别缓存。引用 key 包含目标相关的 number/definition 版本，不能只包含原始 `[^id]`。
- 修改定义 a 只唤醒 a 的使用者及其组合外壳；编号改变可能传播到很多后续引用，但不得全篇重解析无关块。
- 收敛以候选 winner、first-use 序列及依赖版本的实际变化集合为准；允许必要的全局编号派生更新，不允许借此重新解析/渲染所有正文和外部单元。

### 编辑验收

1. 文末 `[^a]: old→new`：更新 definition HTML 及所有 a 引用的 Typst 输出；b 引用和无关块复用，引用查找全树 DFS 次数为零。
2. 文首新增 `[^b]`：后续编号按新首次引用顺序变化；未改 definition 的正文解析与 MathTex 调用不增加。
3. 删除首个同名定义：下个候选成为 winner，旧 duplicate 状态和显示正确恢复；撤销后恢复原 winner。
4. 删除引用块再插入：无陈旧 reference offset/nextNumber/first use；未定义引用后新增定义能够更新对应 Typst 输出。

## 9. InlineMathPlugin

### 当前事实与证据

源码：[InlineMathParser](../../markit/src/plugins/gfm/inline/inline_math/inline_math_parser.cj)、[node](../../markit/src/plugins/gfm/inline/inline_math/inline_math_node.cj)、[renderers/config](../../markit/src/plugins/gfm/inline/inline_math/inline_math_renderers.cj)。

- 从 `$` 找下一个未转义 `$`，禁止跨 CR/LF；没有额外金额规则，也未特殊排斥 `$$`。
- 无自有 session state。HTML/Typst 默认调用 MathRenderer，displayMode=false；unsupported 返回原始公式 fallback，异常重抛包含 node.id。
- 每次 render 都新建 MathRenderer 并完整 parse，没有公式缓存。

### 拟议能力、快照、依赖与撤销

- 所属 inline 容器是基本重解析单元；删 delimiter/改转义可能影响同一行后续 `$` 配对。不得仅覆盖原公式节点字符串。
- checkpoint 使用通用 inline 容器上下文和公式源 slice；本插件不需要虚构全局 session state。
- 旧 InlineMath 事实/渲染引用随子树替换撤销；新配对提交新事实。外层 Bold/Strike/Link 结构或样式变化与公式内容 key 分开。
- 使用统一 MathTex 单元服务，与 block 公式区分 displayMode，内部解析和缓存版本见第 13 节。

### 拟议缓存与收敛

- 按内容、displayMode=false、options、引擎版本缓存 expression 和目标输出；相同内容可跨节点复用主体，源位置与 identity 不污染主体缓存。
- inline 容器和所属块外部状态稳定后停止；更细配对窗口由插件证明，不能假定单个 `$` 节点自足。

### 编辑验收

1. `$a+b$→$a-b$`：该容器重解析，仅改变公式进行一次新 MathTex parse，其余公式输出命中。
2. 删除 `$` 或添加 `\`：后续 math/Text 范围与全文一致；插入换行不得错误跨行配对。
3. 只在公式前插入中文：内容缓存命中，byte/rune 源位置重定位正确。

## 10. RelaxedEmphasisPlugin

### 当前事实与证据

源码：[RelaxedEmphasisParser](../../markit/src/plugins/gfm/inline/relaxed_emphasis/relaxed_emphasis_parser.cj)、[plugin](../../markit/src/plugins/gfm/inline/relaxed_emphasis/relaxed_emphasis_plugin.cj)。

- 只注册 inline parser，产生标准 BoldNode/ItalicNode，依赖标准 Bold/Italic renderer，不存在 RelaxedEmphasis 专有 renderer。
- `_`/`__` 开头内容不能 whitespace；closing 前不能 whitespace，closing 后须不是 ASCII alphanumeric 或到输入结尾。
- 扫描识别 escape，未禁止换行；递归 `appendInlineChildren`。无自有 session state，但子节点可包含脚注、引用、公式依赖。

### 拟议能力、快照、依赖与撤销

- 以 inline 容器更新；更细窗口必须包含 closing 后的邻接字符以及所有可能被重配对的 delimiter。
- checkpoint 记录通用 inline 上下文与递归范围；不能按“单行无状态”处理，因为当前 parser 可跨换行。
- 注册解析 owner 与实际输出 kind 的对应关系；依赖与渲染派发不能只按 ownerPlugin 查同名 renderer。
- 替换容器时撤销旧嵌套子插件贡献；未改子公式主体可通过内容 key 复用。

### 拟议缓存与收敛

- Bold/Italic 输出缓存由实际 kind、marker、children、HTML class/目标配置、子依赖版本确定。
- 容器级重解析完成且 delimiter/邻接字符结果稳定后停止；禁止只比较编辑点内字符就复用旧 emphasis 节点。

### 编辑验收

1. `_word_!` 的 `!→a`：closing 条件变化导致正确退化或重配对，不能保留旧 Italic；其他 paragraph 复用。
2. `__a $x$__` 删除一个 closing underscore 或添加 escape：Bold/Italic 子结构与全文一致；内容相同的 `$x$` 不重复 MathTex parse。
3. 跨换行 delimiter 用例编辑中间行：按当前跨行语义解析，不能以单行窗口截断。

## 11. StrikethroughPlugin

### 当前事实与证据

源码：[StrikethroughParser](../../markit/src/plugins/gfm/inline/strikethrough/strikethrough_parser.cj)、[node](../../markit/src/plugins/gfm/inline/strikethrough/strikethrough_node.cj)、[renderers](../../markit/src/plugins/gfm/inline/strikethrough/strikethrough_renderers.cj)。

- `~~` 后找第一个未转义 `~~`，内容非空；扫描未禁止换行，递归 `appendInlineChildrenRange`。
- 无直接 session state；输出 `<del>`、Markdown `~~`、Typst `#strike` 并遍历 children，无输出缓存。

### 拟议能力、快照、依赖与撤销

- 基本粒度为所属 inline 容器；delimiter 删除、转义或外层结构编辑需重新配对，不能固定为单行或旧 node 范围。
- 使用通用 inline checkpoint 和递归范围；本插件无跨块符号表，但 children 的引用/脚注贡献与依赖必须登记。
- 替换时撤销旧 children 的符号与渲染依赖，再提交新嵌套结果，保证删 delimiter 后不残留旧 reference occurrence。

### 拟议缓存与收敛

- 按 kind、children、目标/样式及依赖版本缓存；内容不变的公式/链接子单元可复用。
- inline 容器边界及外部块状态一致后收敛；若证明更细窗口必须包含 escape 状态和潜在后续 closing，而非固定向两边扩字节。

### 编辑验收

1. `~~old~~→~~new~~`：只所属容器更新，旁边 paragraph、公式和代码缓存保持命中。
2. 删除或转义 closing `~~`：Text/Strikethrough 新配对与全文一致，旧嵌套符号贡献正确撤销。
3. 跨换行 `~~` 用例编辑：保持当前语义；不能因行级优化漏更新后一行。

## 12. CodeHL 联动：逐行状态必须真正收敛

### 12.1 当前可复用能力与缺口

证据：[CodeTokenizer/TokenizerState/TokenizerContext](../../codehl/src/languages/token.cj)、[GrammarTokenizer.tokenizeLine](../../codehl/src/languages/grammar_tokenizer.cj)、[Highlighter.codeToTokens](../../codehl/src/core/highlighter.cj)、[CodeLine/CodeBlock](../../codehl/src/core/code_block.cj)、[TokenHtmlRenderer](../../codehl/src/core/token_html_renderer.cj)、[LanguageRegistry](../../codehl/src/languages/languages.cj)、[markit adapter](../../markit/src/plugins/standard/block/fenced_code_block/fenced_code_block_codehl_renderer.cj)。

已具备：

- `tokenizeLine(line,state): LineTokens` 接受上行状态并返回 tokens 与新状态；GrammarTokenizer 拷入 context 栈，清除 line-local context 后返回，具备逐行恢复的基础。
- context 完整字段为 scope、contentScope、endPattern、whilePattern、applyEndPatternLast、patterns、endCaptures、whileCaptures、grammarScope、canCarryAcrossLines；动态 end/while 和嵌入语法不能被省略。
- `codeToTokens(initialState)` 可从外部状态处理给定代码，但每次仍遍历全部给定 lines，只返回整体 finalState。
- CodeLine 有 text/spans/lineNumber/highlighted/visible；CodeBlock.withTheme 可共享 token lines 换主题。Dual-theme 已只 tokenize 一次后分别输出。
- LanguageRegistry 缓存 grammar/tokenizer；GrammarTokenizer 缓存 expanded patterns、scanners、scope class/stack、regex；ThemeResolver 缓存 styles；markit 静态缓存配置对应 Highlighter，节点存 light/dark HTML。

尚缺：

- TokenizerState/Context 无公开结构等价、指纹、版本或恢复序列化协议；CodeLine 不保存逐行入态/出态，CodeBlock 仅 finalState。
- 无编辑更新、行缓存、旧新行映射和收敛停止接口。Highlighter 的 LanguageRegistry 私有；公开 LanguageRegistry.findTokenizer 可用，但需要保持与 Highlighter 相同配置和语法版本。
- TokenHtmlRenderer 的逐行输出 helper 是 private，缺稳定 public 行片段输出入口。
- highlight/i18n/lineNumber 使用行号；插删行后即使词法状态已收敛，后缀 HTML 的这些派生属性仍可能变化。
- markit Highlighter cache key 记录目录及 languages/aliases 等配置字符串，没有外部 grammar/theme 文件内容版本失效协议。
- 当前围栏 finalize 仍整块 highlight；节点 HTML 属性缓存只支持不重建节点的复用，不能支持编辑代码块内部的行复用。

### 12.2 拟议实施策略

1. 为每个 code 单元保存逐行 `{stableLineKey, textHash, inState, outState, tokens}`；fence indent 去除后的有效代码输入、语言、grammar/alias 版本进入 token key。
2. 暴露 tokenizer 获取和逐行 token/render 的窄接口，或以公开 LanguageRegistry 建适配服务；共享同一配置与版本，避免另建一个行为不同的 tokenizer。
3. 最早编辑行以前一未变行 outState 为恢复点；按新旧稳定行映射向后 tokenize。文本相同、完整 outState 等价且后继映射/配置一致后停止，复用后缀。
4. 为 grammar/pattern/capture 提供稳定语义 identity 或结构等价；不能只比较 context 数、scope 或对象地址。cache 中不得持有可变旧状态引用造成回写污染。
5. token 与 render 缓存分离：主题、行号、高亮、i18n 可见性变更只更新所需行片段/外壳，tokenizer 调用为零。Dual-theme 从一份 tokens 生成两种输出。
6. 撤销旧代码单元的行映射、token/render 引用及依赖贡献；关闭/开启 fence、language/fileGroups 改动时清除不再适用的 CodeHL/Mermaid 结果。
7. 对 code group 以真实 file group 为子单元维护缓存和行号作用域；group 分割变化重新映射受影响 groups，不能只覆盖普通单 code 路径。

### 12.3 必须记录的调用次数验收

| 编辑 | 预期 tokenizer/外部调用 | 其他验收 |
| --- | --- | --- |
| 千行块中一行普通表达式变化，出态即等价 | 该行重算；以可证明的首个收敛边界停止，后缀不得完整 tokenize | 未变 token rows 身份复用；双主题一致 |
| 插入 `/*` 或多行字符串开始符 | 从编辑行传播至真实关闭和状态等价处，允许必要范围 | 不得固定只算一行或提前按栈深停 |
| 只修改 theme/highlight/i18n 规则 | tokenizeLine=0 | 主题/高亮/可见性正确，不复用错误 HTML |
| 中间插入一行 | 新行及必要词法传播；其余 tokens 可复用 | 后缀 lineNumber/highlight/i18n 重映射正确 |
| 代码块前编辑普通段落 | tokenizeLine=0，该 code 输出主体命中 | source/anchor 包装位置更新 |
| language/grammar 内容版本改变 | 受影响代码单元重新 tokenize | 未受影响代码块零调用，旧 grammar cache 不误命中 |

计数应从 tokenizer 真正入口记录，不以“适配器更新函数调用一次”替代实际行数；额外读取但未 tokenize 的边界观察另记扫描行数。

## 13. MathTex 联动：公式单元缓存，禁止误报流式增量

### 13.1 当前事实

证据：[MathParseSession](../../mathtex/src/parser/session.cj)、[MathRenderer.render](../../mathtex/src/core/renderer.cj)、[AST](../../mathtex/src/ast/math_ast.cj)、[HTML writer](../../mathtex/src/html/writer.cj)、[MathML writer](../../mathtex/src/mathml/writer.cj)。

- feed/feedBytes 只累积 chunks；snapshot/finalize 都重新组合完整 source 并调用 TexParser.parse。不是编辑增量 parser。
- MathRenderer 每个 render 目标都重新 MathTex.parse；没有公式 edit、checkpoint 或输出 cache。
- AST 与 writer 是解析后复用的基础，可用于共享 expression，不能据此声称已有增量 AST。

### 13.2 拟议实施策略、依赖与收敛

- InlineMath/MathBlock 插件提交独立公式渲染请求，内容不变时零 parse；外层 markit node/source/anchor 与公式 expression、输出主体分离。
- expression key 含 TeX、displayMode、parser/命令支持版本及真实解析选项；目标输出 key 再含 classPrefix/errorColor/outputMode 等 writer 参数。throwOnError 等行为选项也必须正确处理，不能复用错误行为。
- 同一公式请求 HTML/MathML/Typst 时共享一次 expression，分别 writer；unsupported/diagnostics 与 fallback 结果一并缓存，不能只缓存成功 HTML。
- 公式内容编辑允许整公式内部重算；不要求本轮实现 TeX 内部任意范围编辑恢复。markit delimiter/容器边界是否稳定仍由两个 Math 插件证明。
- 替换/删除公式撤销旧单元引用及输出贡献；缓存可按生命周期/LRU 保留内容条目，不可因此继续把旧输出挂到新 node。
- 收敛以公式主体 key 和外层边界/依赖分别判定；位置位移不是 TeX 内容失效条件。

### 13.3 调用次数验收

1. 文档前部插字，后方多公式内容不变：MathTex parse=0、writer=0；只更新必要源位置/外壳。
2. 一处公式变化同时请求 HTML+Typst：该新内容 expression parse=1，各目标 writer 按需求执行；未改其他公式 parse/writer=0。
3. inline 与 block 内容相同但 displayMode 不同：不得错误共用不兼容 expression/输出；相同模式、相同内容重复使用可命中。
4. 只变 HTML classPrefix/errorColor：已有 expression 复用，输出按新 writer 参数更新；Typst 未受影响时不重写。
5. unsupported→supported 或异常选项变化：fallback/diagnostics/抛错与无缓存全文行为一致，无旧成功或失败结果泄漏。

## 14. Mermaid 联动：围栏插件分支与原生渲染触发时机

### 14.1 必须保留的源码事实

证据：[FencedCodeBlockPlugin](../../markit/src/plugins/standard/block/fenced_code_block/fenced_code_block_plugin.cj)、[FencedCodeBlockParser.finalize](../../markit/src/plugins/standard/block/fenced_code_block/fenced_code_block_parser.cj)、[FencedCodeBlockMermaidRenderer.renderInto](../../markit/src/plugins/standard/block/fenced_code_block/fenced_code_block_mermaid_renderer.cj)、[HTML renderer](../../markit/src/plugins/standard/block/fenced_code_block/fenced_code_block_html_renderer.cj)、[MermaidRenderer](../../mermaid4cj/src/renderer.cj)、[TS viewer](../../markit-kit/ts-render/src/renderer/mermaid-viewer.ts)。

- Mermaid 不是独立 plugin；它是 FencedCodeBlockPlugin 的分支。当前语言判断在该插件内部，核心无需知道 Mermaid。
- 原生渲染触发时机是 `FencedCodeBlockParser.finalize`：创建/attach node 后先 `FencedCodeBlockMermaidRenderer.renderInto`，再 `FencedCodeBlockCodehlRenderer.renderInto`。因此仅仅复用 HTML renderer 或前端 DOM 并不能阻止解析阶段已经发生的昂贵重算。
- Mermaid 条件是 enableMermaid、无 fileGroups、language trim/lower 等于 mermaid。调用 native `renderMarkitHtml`，Dual theme、classPrefix=mk-mermaid、idPrefix=`mk-mermaid-${node.id}`，结果写 node `mermaid4cj.html`。
- HTML 优先使用 Mermaid 属性，其次 CodeHL。CodeHL renderInto 未显式排除 Mermaid，默认还可能经过 CodeHL 分支，最终展示仍是 Mermaid。
- MermaidRenderer 提供 Flowchart/Sequence/Mindmap/Class/State/ER/Pie/Gantt parse/render 接口；没有编辑 session/cache。
- Dual flowchart 路径已有一次 parse+layout 后生成双主题 SVG；其他七类 Dual 路径各调 renderKindSvg 两次，重复 parse，布局是否重复依具体类型实现。
- TS viewer 不解析 Mermaid，只初始化 native container；WeakMap 以 DOM container 保存缩放平移，dataset ready 防重初始化。全页替换会丢失未改图的交互状态。

### 14.2 拟议关键改动与边界

1. **必须改变 native 渲染触发时机**：围栏语法 finalize 先产生语法事实和稳定代码单元；昂贵 Mermaid/CodeHL 工作交给围栏插件登记的派生渲染阶段或缓存服务，在确认单元内容/配置失效后才执行。若保留 finalize 中可缓存调用，必须证明它在 cache hit 前不做 parse/layout/highlight，并保持解析与输出需求分离；不能仍无条件 native render。
2. 语言分派和 Mermaid 请求由围栏插件定义，core 只调度派生请求。明确 Mermaid 命中时不再生成随后不会消费的 CodeHL 输出。
3. parser 的 fence checkpoint 包含 marker、长度、indent、closed、language、line rules/group 配置、容器上下文；正文编辑且 fence 边界稳定时只更新该代码/diagram 单元。删除 closing 仍按围栏语义传播到新结束或 EOF。
4. diagram key 包含内容、diagram kind、选项、textMeasurer 语义版本、引擎版本；解析结果/布局/双主题 SVG 可分层缓存。以单 diagram 为允许的内部重算边界，不要求此次实现图内部局部布局。
5. 稳定 identity/idPrefix 与纯内容输出分离：当前 node.id 进入 SVG ids，不能直接跨节点复制旧 HTML 造成重复 id。可用稳定块标识生成 prefix，或缓存可实例化模板；方案选择要有唯一性和撤销证据。
6. 缓存 hits 不调用 Mermaid parse/layout；新图/改图允许整图 parse/layout。双主题应共享可共享的 parse/model，flowchart 维持已有 layout 复用；其他图型的共享改造按公开模型能力实施，不能未经核实宣称所有图都已有共享布局。
7. language、enableMermaid、fileGroups、内容/版本变化时撤销旧 mermaid4cj.html、CodeHL 与依赖贡献；将旧属性视作可撤销派生输出而非永久节点事实。
8. HTML patch 保留未改 diagram container，未改图的 viewer WeakMap 状态和事件处理不重建；改图可在容器内部更新 SVG，交互状态保留策略由 viewer 集成任务明确验证。
9. Markdown/Typst 等不消费 native Mermaid HTML 的请求不应仅因解析而无条件生成双主题 SVG。各目标真实消费路径需补充可执行证据，不把本文未逐项核查的输出行为写成事实。

### 14.3 调用次数和编辑验收

1. Mermaid 前修改普通 paragraph：Mermaid parse=0、layout=0、SVG writer=0；图主体/container 复用，缩放平移不变，anchor/source 可重定位。
2. 两张图只改第一张的一条边：仅第一张 native 请求失效；第二张 parse/layout/writer=0，identity 和 viewer 状态不变。
3. `mermaid→text→mermaid` 或启停 enableMermaid：旧派生结果正确撤销，text 时显示代码，恢复时正确命中/生成图；不沿用失效 mermaid4cj.html。
4. 在图前插入其他 fence：现有图 SVG ids 稳定且全页唯一，不因为 node 分配序号位移重新 layout。
5. 新/改 flowchart 的 Dual 输出：parse=1、layout=1，双主题 writer 分别执行；不得退回两次独立完整 renderSvg。
6. 未消费 Mermaid HTML 的解析/目标输出路径：parse/layout=0，除非该目标明确登记并消费图形派生请求；用实际请求跟踪证明，而非只看最终 HTML 字符串。
7. 删除/恢复 closing fence：所属围栏范围和后继块与全文一致；失效范围外图形零调用。

## 15. 统一验证协议、证据与未证明项

### 15.1 实施时必须产生的证据

每个适配任务至少返回：拥有的文件、能力注册项、状态/贡献/依赖结构、重解析范围、缓存键、停止条件、实际命令、结果与未通过项。每个编辑案例记录以下两组结果：

- 正确性：新文本重新全量解析的 AST 语义、源 byte/rune 范围、HTML/Markdown/Typst 与增量结果一致；不将旧节点 id 的数值差异直接作为语义失败，单独验证稳定 identity。
- 增量性：扫描行/字节、重新解析的块/items/rows、复用节点、恢复 checkpoint、撤销/新增贡献、依赖唤醒集合、cache hit/miss、CodeHL tokenizeLine、MathTex parse/writer、Mermaid parse/layout/writer 的真实次数。

必须覆盖插入、删除、替换、撤销/重做、Unicode byte/rune 位移、嵌套容器、EOF/未闭合和跨插件组合。首次冷构建与编辑增量计数分别记录，不能用预热过程掩盖重复工作。

### 15.2 本次实际完成的验证

- 静态读取九个 `markit/src/plugins/gfm/**/*_plugin.cj`、对应 parser/state/model/renderers、table processors、footnote registry/filter 与 gfm_bundle。
- 静态读取 CodeHL token/state/highlighter/code block/renderer、MathTex session/renderer/AST 导出与 Mermaid 原生接入/renderer/viewer。
- 使用 `rg --files` 建清单，使用 `Get-Content` 与 `rg -n` 核查注册和调用符号；结论是源码调查和待实施方案，不是运行期基准。
- 本次没有修改实现；没有执行增量案例、性能测量或新的编译测试。上述案例状态均为“待实现、待运行”。

### 15.3 必须在后续任务关闭的验证缺口

| 缺口 | 为什么必须关闭 | 负责边界 |
| --- | --- | --- |
| 通用能力/恢复/撤销/依赖/计数契约尚未实现 | 各插件不能自行采用互不兼容的缓存与状态 | 串行共享契约任务 |
| 九插件均无已运行编辑对比证据 | 静态可行性不能证明边界与收敛正确 | 对应插件适配任务 |
| 重复 table cell 源定位歧义 | 可能把 patch 映射到同一行错误 cell | Table 适配任务 |
| Footnote immutable number 与整树 Typst 查找 | 会使复用编号失真、引用输出重复扫描 | Footnote 适配任务 |
| Tokenizer 完整状态等价和 grammar 文件版本 | 错误提前收敛或旧缓存命中 | CodeHL 服务任务 |
| Code groups/i18n/line rules 组合证据 | 普通代码路径通过不代表分组路径增量通过 | 围栏/CodeHL 集成任务 |
| native Mermaid 触发时机及双服务重复工作 | 仅缓存 renderer 无法阻止 finalize 重算 | 围栏/Mermaid 集成任务 |
| Mermaid SVG id 唯一性与 viewer 状态保持 | 主体缓存和 DOM patch 可能引入可见错误 | 围栏身份与前端集成任务 |
| 三目标真实需求与派生计算关系 | 避免不消费图形也生成昂贵 native 输出 | 目标渲染集成任务 |

完成门禁：每个内置插件都提交局部重解析、依赖传播和缓存失效证据；未知第三方退化可诊断；全量基准只作为对照，不作为内置插件永久执行路径。公式内部整单元解析、单图整单元布局属于明确允许边界，大代码块逐行状态收敛则是必须交付项。
