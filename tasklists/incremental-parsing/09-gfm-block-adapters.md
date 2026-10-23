# Task 09：GFM 四个 block 插件的 item/row 局部适配

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本任务逐个覆盖4个GFM block插件：AlphabeticList、MathBlock、Table、TaskList；嵌套单位、行/单元、状态及依赖按各插件实际注册能力适配并验证。

标准库热路径只选择性查阅用户提供的只读源码 `C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`：针对本任务实际使用的操作核实复制、扫描、分配及源码/运行SDK版本对应；有争议仅做最小实测，不开展全面标准库研究或新增框架。

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

更新时间：2026-10-21。仅方案，尚未实现或运行编辑验收。

## Execution Contract

- Depends on: Task 07（唯一硬依赖）。
- Unlocks: Task 11、Task 13；二者还需各自其他前置任务。
- Execution: 并行 B，与 08/10 隔离；07 冻结交接经协调者审阅后启动。
- Delegated owner: GFM block 适配子 agent，由协调者指派。
- Scope boundary: 仅拥有 `markit/src/plugins/gfm/block/task_list/**`、`alphabetic_list/**`、`table/**`、`math_block/**` 的四插件及本组独立测试。使用 07 冻结的 typed Node/Heading/partial nested/依赖和服务请求接缝；数学 renderer 在本任务结束后明确交接给 13，不与其并行修改。
- 不拥有：core、bundles、`gfm/block/block_line_utils.cj` 等跨组共享 helper、Standard/CommonMark/GFM inline/i18n 文件；需要新 shared 能力时退回串行前置或集成任务。
- 输入：07 的完整交接与 01 oracle/计数，及 [GFM 清单](plugin-gfm.md)。
- 输出：四插件实际 facet/codec/贡献/局部重解析、三线表可撤销窗口、MathBlock syntax/render 请求与服务交接、差分及局部性证据。

## Goal

使 TaskListPlugin、AlphabeticListPlugin、TablePlugin、MathBlockPlugin 完成局部增量。普通 list 正文按 item/嵌套子单元更新，表格按 row/cell 更新；不以整个长 list/table/容器重建作为最终验收。

## Current State

具体规则、状态字段、缓存及案例分别见 [TaskList](plugin-gfm.md#3-tasklistplugin)、[AlphabeticList](plugin-gfm.md#4-alphabeticlistplugin)、[Table/三线表](plugin-gfm.md#5-tableplugin-与三线表)、[MathBlock](plugin-gfm.md#6-mathblockplugin)。

- 四项均是 continuation parser，finalize 当前创建整个块及全部 children，未有 item/row 编辑接口。
- TaskList 的 tight/continuation/detached 最小缩进与 Alphabetic 的 expectedLetter/大小写/delimiter 会影响后续分组，不能只比较改动 item literal。
- Table tryStart 向前消费一条 pending paragraph；alignment 影响全列，cellSpan 的 indexOf 对重复内容有歧义。三线表 batch/postFinalize 只设置 tableStyle/render，没有撤销。
- MathBlock 未闭合 fallback paragraph，可实际影响至 EOF；renderer 每次调用 MathTex，没有公式 cache。

源码依据：[task model](../../markit/src/plugins/gfm/block/task_list/task_list_model.cj)、[alphabetic model](../../markit/src/plugins/gfm/block/alphabetic_list/alphabetic_list_model.cj)、[table parser](../../markit/src/plugins/gfm/block/table/table_parser.cj)、[table plugin](../../markit/src/plugins/gfm/block/table/table_plugin.cj)、[math parser](../../markit/src/plugins/gfm/block/math_block/math_block_parser.cj)。

## Follow-Up Work

1. 注册四插件所有 facet、typed codecs、完整 frame snapshot/restore/equality、语法/派生 ownership；由原有 matcher 内核提供 probe/parse，保留 priority/ordinal。
2. TaskList/Alphabetic 建 item 索引与恢复点，复用未变兄弟；缩进规范化变化只影响该 item 的必要 detached 区域。tight 由可撤销空行事实汇总，Alphabetic expectedLetter 按完整序列状态传播到收敛。
3. 嵌套 item 用 07 组合映射和局部 nested context；撤销旧子插件贡献再提交新子树。不得修改共享 nested helper，也不能在核心复制 list marker 判断。
4. Table 行拆分返回真实 cell 源区间和稳定角色，消除 indexOf 重复内容歧义；body 改动优先 row/cell inline candidate，保留其他 rows。header/alignment 改动按列数和真实内容依赖扩大。
5. Table 声明前一 pending 行的观察与反向消费，准确恢复失败候选和后继 pending 状态。三线表将邻接三元组变为 owned overlay，撤销旧隐藏 divider/tableStyle，再检查新旧相邻窗口，禁止每 edit 递归全树 mark。
6. MathBlock 保留 closed/indent/opening/fallback 原始事实和源映射；delimiter 变化传播到真实新 close/EOF。使用冻结的按需公式请求接口，不在 syntax 阶段无条件 MathTex；Task 13 接管 expression/output cache 和 math renderer 具体 handler。
7. 分离 item/row/cell 内容、容器外壳、派生语义、位置缓存版本；alignment/tight/row count/style 改变只使相应层失效。自动锚点/i18n 仅发布可订阅结构/依赖，交由 11/12，禁止本组扩展其旧语义。
8. 提交四项工作量预算与 phase/依赖输出，冻结 math renderer/服务文件交接给 13；共享缺口送协调者串行处理。

## Acceptance

- 四插件有真实局部能力及所有 state/codec/贡献/负依赖证据；语法和派生层可回滚/取消，旧 snapshot 不被污染；无永久内置全文 fallback。
- [TaskList/Alphabetic 案例](plugin-gfm.md#3-tasklistplugin)：勾选单项或修改正文只更新该 item；插空行/降缩进、`b.→d.` 或大小写/delimiter 变化正确传播；未变 item 子树、昂贵单元与后缀复用，记录 expectedLetter/tight 收敛。
- [Table 案例](plugin-gfm.md#5-tableplugin-与三线表)：千行表改单 cell 只重算对应 row/candidate；重复 cell 只更新真实第二处；alignment 列数变化补空/截断正确，未变内容可复用。
- 删除/恢复三线表一侧 divider，三个目标样式与 divider 可见性恢复；旧 tableStyle/render=false 无残留，邻域处理计数证明非全树重扫。
- [MathBlock 案例](plugin-gfm.md#6-mathblockplugin)：`x^2→x^3` 只产生该公式失效请求；删/补 closing 的 paragraph fallback/后继恢复与全文一致；内容未改只移动位置不产生新公式计算请求。
- item/row 与 long paragraph 子内容使用 06/07 安全窗口，不以每次整 list/table/inline owner 重算为完成。真实结构传播可扩大，但必须给出 facet 原因和扫描范围。
- 三目标、JSON、typed 字段、stable ID、parent、raw 和 byte/rune/UTF16/CRLF/emoji source map 与修正基线一致；MathTex 重型调用的最终证明留给 13，不在本任务虚报完成。
- 文件 diff 不含 core、bundle、共享 helper、其他并行组或 i18n；服务交接清楚且没有并发所有权冲突。

## Verification Record

- 本轮：已静态读取三组清单、README、设计锁与上述源码证据；仅写方案。
- 未运行：四插件新实现的构建、编辑差分和性能；验收案例全部待实施。
- 未来已知命令：`markit/` 下 `cjpm test`，当前未执行，保留仓颉 1.1.0 兼容验证。
- 拟新增：GFM block editing/item/row/three-line rollback/source-map suite 及计数入口，名称/tag 待创建，不假装已有。
- 回报必须含实际命令/失败、每项至少两例证据、重算/复用/传播统计、state codec、三线表撤销日志、math 服务交接清单；由协调者审阅放行 11/13。
