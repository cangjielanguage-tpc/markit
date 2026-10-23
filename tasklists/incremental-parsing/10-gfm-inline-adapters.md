# Task 10：GFM 五个 inline/脚注插件适配

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本任务逐个覆盖5个GFM inline/脚注插件：Autolink、Footnote、InlineMath、RelaxedEmphasis、Strikethrough；成功/失败读取、定义与使用者、配对及传播按实际注册能力适配并验证。

标准库热路径只选择性查阅用户提供的只读源码 `C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`：针对本任务实际使用的操作核实复制、扫描、分配及源码/运行SDK版本对应；有争议仅做最小实测，不开展全面标准库研究或新增框架。

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

更新时间：2026-10-21。本轮仅方案，所有适配与测试待实现。

## Execution Contract

- Depends on: Task 07（唯一硬依赖）。
- Unlocks: Task 11、Task 13；其他硬依赖见总执行图。
- Execution: 并行 B，与 08/09 隔离，07 冻结交接经协调者审阅后执行。
- Delegated owner: GFM inline/Footnote 适配子 agent，由协调者指派。
- Scope boundary: 只拥有 `markit/src/plugins/gfm/inline/autolink/**`、`footnote/**`、`inline_math/**`、`relaxed_emphasis/**`、`strikethrough/**` 与本组独立测试。Footnote definition continuation/filter/state/renderer 同属于本任务，不能因目录名 inline 漏掉。
- 禁止：改 core、bundles、共享 helper/冻结接口、Standard/CommonMark/GFM block/i18n。math renderer 在任务完成后交接 13；新 shared 需求退回串行审查，不越权处理。
- 输入：07 的 typed Node、候选窗口、正负依赖、ordered reducer、服务请求与 partial nested 交接，及 [GFM 清单](plugin-gfm.md)。
- 输出：五插件所有 facet 适配、脚注定义/编号/逆依赖与可撤销视图、Typst 索引查找、服务交接、编辑差分及调用计数。

## Goal

对 AutolinkPlugin、FootnotePlugin、InlineMathPlugin、RelaxedEmphasisPlugin、StrikethroughPlugin 实现候选安全窗口和必要依赖传播。脚注全局编号变化只重做真实受影响派生结果，不以全文重解析解决；未改公式不因外层编辑重新解析。

## Current State

逐项事实和案例：[Autolink](plugin-gfm.md#7-autolinkplugin)、[Footnote](plugin-gfm.md#8-footnoteplugin)、[InlineMath](plugin-gfm.md#9-inlinemathplugin)、[RelaxedEmphasis](plugin-gfm.md#10-relaxedemphasisplugin)、[Strikethrough](plugin-gfm.md#11-strikethroughplugin)。

- Autolink 无 session state，扫描 URL/email 到边界并剥离标点；不能与 CommonMarkAutolink 混为同插件。
- InlineMath 禁跨 CR/LF；RelaxedEmphasis/Strikethrough 扫描未禁换行，递归子 inline；不能为这些插件统一假设“只读本行”。RelaxedEmphasis 产生标准 Bold/Italic，无自有 renderer。
- Footnote 同时注册 definition continuation、reference inline、registry、duplicate emission filter、三目标 renderer，没有现成统一 finalize 重编号阶段。
- Registry snapshot 仅名称；number 按首次引用分配，node number immutable；首个非空 definition content 胜出，duplicate 会过滤，未定义引用有占位。
- Typst reference 当前每次沿 parent 到 root 并全树 DFS 查 definition；没有反向使用索引和可撤销编号。

源码：[FootnoteRegistry](../../markit/src/plugins/gfm/inline/footnote/footnote_registry.cj)、[Footnote renderers](../../markit/src/plugins/gfm/inline/footnote/footnote_renderers.cj)、[InlineMath parser](../../markit/src/plugins/gfm/inline/inline_math/inline_math_parser.cj)、[Relaxed parser](../../markit/src/plugins/gfm/inline/relaxed_emphasis/relaxed_emphasis_parser.cj)、[Strike parser](../../markit/src/plugins/gfm/inline/strikethrough/strikethrough_parser.cj)。

## Follow-Up Work

1. 五插件按真实注册面实现 facet/typed codec；无状态插件给出空持久状态证明，但保留读取窗口、负 closing 依赖、递归效果和配置版本。
2. 使用 06 的 candidate 读区间、失败查找和 delimiter/escape/邻接条件安全窗口，复用长 paragraph 内窗口外的节点。可用整 owner 作为迁移起点，不得以此完成任务。
3. Footnote 定义保存有序候选与原始语法，reference 保存稳定 occurrence 和原文位置；按同 id 建使用者反向索引，包括当前缺失定义的负查询。
4. 把 winner/duplicate/number 从破坏性节点字段中分离为可撤销派生视图，或安全重建受影响 typed view；不得只改 registry 然后沿用旧 immutable number。first-use 顺序索引/reducer 利用 07 冻结接口，不改其实现。
5. 替换单位撤销原 definition/reference/占位/first-use 贡献，重新计算实际变化集合。编号传播可跨全文引用序列，但不能重解析无关正文或重渲染未依赖该编号的公式。
6. Typst 使用 definition 索引获取 winner 和缓存正文，禁止每个 reference root DFS。引用 render key 按目标包含 number 或 definition/body 版本；missing→defined 和 winner 切换都唤醒正确使用者。
7. InlineMath 产出内容/displayMode/目标的按需公式请求并保持 delimiter 配对来源，语法阶段不无条件 MathTex；GFM math renderer 具体缓存 handler 交接 13，未改子公式主体通过服务 key 复用。
8. 为 RelaxedEmphasis 明确 owner 与实际 Bold/Italic kind 的 codec/render 组合；Strike/Emphasis 容器变化先撤销旧子引用，再提交新范围，避免重复 occurrence。
9. 输出同版本可见文本/footnote typed 依赖供 11/12 消费，保持旧 phase trace 和完整 parse 语义；禁止暗增新脚注语法或顺便改不相关 parser 行为。

## Acceptance

- 五插件真实注册、codec/完整状态或无状态证明、缓存键、撤销与收敛齐全；脚注 definition/filter 不遗漏，Relaxed 不伪造专有 renderer，无永久内置 fallback。
- [Footnote 案例](plugin-gfm.md#8-footnoteplugin)：仅改文末 a 定义只唤醒 a 的 Typst 使用者/definition 输出，b 和无关正文复用；首同名定义删除后第二候选接管，duplicate 可逆恢复；Typst root DFS 次数为零。
- 文首新增/删除首次引用导致编号按全文基准变化，旧 immutable number 不泄漏；定义缺失时记录负依赖，后补定义能更新旧引用。记录实际编号传播集合而非整文 parse。
- [Autolink/InlineMath 案例](plugin-gfm.md#7-autolinkplugin)：改 URL 尾标点、email 合法性或 math delimiter/escape 后覆盖/后继游标正确；长 paragraph 安全窗口外节点不重建。
- [Relaxed/Strike 案例](plugin-gfm.md#10-relaxedemphasisplugin)：`_word_!→_word_a`、删除/转义 closing `~~`、跨行匹配按当前规则重判；旧嵌套 reference occurrence 撤销，未改 math 内容不生成新计算请求。
- 正确性覆盖三目标、JSON、typed 字段、raw/provenance、Unicode/CRLF/source-map、稳定唯一 ID/parent、取消回滚/undo-redo；不以 Node.== 或剥离编号/href 作等价。
- Footnote cache hit 保留有归属贡献和依赖，不能跳过语义写入；语义编号传播与语法范围分别计数，真实到 EOF 可解释，默认全篇不可接受。
- 文件只属于本组和测试；不改 core/bundle/shared helper/i18n/其他并行组；math 服务文件交接与 13 的所有权切换清楚。

## Verification Record

- 本轮：只静态核查 README、设计锁、三组 plugin 清单及列出的源码，没有新实现。
- 未运行：构建、编辑差分、脚注编号/DFS 计数和性能测试；全部案例待实施。
- 未来已知命令：在 `markit/` 执行 `cjpm test`，当前未执行，最低仓颉 1.1.0 环境需记录。
- 拟新增：GFM inline candidate/dependency/footnote ordering suite、Typst lookup spy、Math request spy；名称/tag/路径待实施，不声称已有。
- 必须返回实际命令/失败、五项矩阵、winner/number/missing 传播日志、root DFS=0 和局部工作量、服务交接及新 shared 缺口；由协调者审阅放行后继。
