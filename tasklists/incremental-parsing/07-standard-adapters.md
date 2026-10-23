# Task 07：Standard 13 插件适配与共享交接冻结

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

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本任务逐个覆盖13个Standard插件：Blockquote、Heading、Divider、FencedCodeBlock、List、Paragraph（含SoftBreak）、InlineCode、Link、Image、ReferenceLink、Bold、Italic、HardBreak；07-P真实纵切之后仍须完成其余插件，不能以纵切或默认false结项。

标准库热路径只选择性查阅用户提供的只读源码 `C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`：针对本任务实际使用的操作核实复制、扫描、分配及源码/运行SDK版本对应；有争议仅做最小实测，不开展全面标准库研究或新增框架。

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Paused (partial)

更新时间：2026-10-21。当前仅交付方案，以下能力均待实现；源码调查完成不代表任务完成。

## Execution Contract

- Depends on: Task 06。
- Unlocks: Task 08、Task 09、Task 10。
- Execution: 串行共享适配；Task 06 验收经协调者审阅后执行，交接审阅通过后释放并行 B。
- Delegated owner: Standard 插件及共享适配交接子 agent，由协调者指派。
- Scope boundary: 拥有 `markit/src/plugins/standard/**` 内 13 插件的 parser/state/node/renderer/facet 适配、标准节点 codec adapter、该组独立测试，以及供后续插件消费的 Standard 适配 helper。共享 helper 的最终路径和导出签名须在本任务交接表登记并冻结；候选为该目录下新增的 shared adapter 模块，候选路径不是已有文件事实。
- 不拥有：core 协议/源树/树存储/编辑引擎、bundles、CommonMark/GFM/横向插件、worker、webview。Task 02–06 契约若不足，提出最小变更并退回串行前置审查，不自行改 core。
- 输入：Task 06 的成功/失败 inline candidate 及安全窗口、Task 05 的块/嵌套事务与收敛、Task 03 的组合映射、Task 04 的可执行 typed codec 与稳定身份，以及 Task 02 的 facet/phase/依赖契约。
- 输出：13 插件真实适配、按插件的验证证据、冻结的 Heading/Node/嵌套/依赖交接与服务请求接缝；无内置永久 fallback。

## Goal

使全部 Standard 语法能力进入同一正式编辑协议，并把后续并行组必需的共享接口冻结到可调用、可测试的交接状态。普通正文、quote 子单元和 list item 编辑必须复用未变子树及后缀，不能以每次整 paragraph/quote/list 重建作为最终成果。

## Current State

完整逐项依据及至少两例见 [Standard/CommonMark 清单](plugin-standard-commonmark.md#逐插件适配)，共同缺口见该文件“横向缺口与必须关闭的审查项”；顺序兼容见 [横向清单](plugin-cross-cutting.md#1-当前语义次序与兼容锁)。

| 正式类名 | 当前注册/特殊行为 | 本任务必须交付的适配重点 |
| --- | --- | --- |
| BlockquotePlugin | continuation，synthetic source 后 detached parse | marker/lazy 判定、组合映射、可恢复嵌套子单元、兄弟复用 |
| HeadingPlugin | state、leaf、batch、emission、三格式 | 原始隐藏节点、有序 slug/编号/closable 贡献及后继状态收敛 |
| DividerPlugin | leaf，三格式 | 与 pending paragraph/Setext/List 竞争、相邻失效 |
| FencedCodeBlockPlugin | continuation，finalize 直接 Mermaid/CodeHL | fence 完整状态、正文片段增量、服务请求接缝，停止语法阶段无条件 native render |
| ListPlugin | continuation，List renderer 自行处理 items | item/嵌套子单元、pending blanks/tight 汇总、去缩进映射 |
| ParagraphPlugin | paragraph、SoftBreak parser/renderer | 分行映射、termination、长 paragraph candidate 安全窗口；SoftBreak 不另计插件 |
| InlineCodePlugin | 等长 backtick run，可跨行 | opaque 范围与缺失 closing 负读取依赖 |
| LinkPlugin | label 递归；renderer 使用 resolver | typed Link、成功/缺失/模糊文件及标题查询依赖、render 独立失效 |
| ImagePlugin | inline；alt 无递归 children | 与 ImageReference 分类转换、src/alt/title 保真 |
| ReferenceLinkPlugin | registry、definition、两类引用、filter、finalizer | 候选 winner、正负反向索引、可逆 provenance，不删除唯一 refLabel 依据 |
| BoldPlugin | inline 递归 | delimiter/邻接/转义与失败候选依赖 |
| ItalicPlugin | inline 递归，与 Bold 竞争 | 候选覆盖/后继游标/子效果收敛 |
| HardBreakPlugin | state、inline、三格式；state 不是当前开关 | 完整空格 run/反斜杠/换行依赖，与 SoftBreak 互斥 |

代码证据：[Standard bundle](../../markit/src/bundles/standard_markdown_bundle.cj)、[Heading state](../../markit/src/plugins/standard/block/heading/heading_session_state.cj)、[Reference registry](../../markit/src/plugins/standard/inline/reference_link/reference_link_registry.cj)、[围栏 finalize](../../markit/src/plugins/standard/block/fenced_code_block/fenced_code_block_parser.cj)、[Node](../../markit/src/core/nodes/node.cj)、[Markit.createSession](../../markit/src/markit.cj)。

当前 snapshot 仅名称、detached parse 共用 session 局部上下文、ReferenceLink finalize 破坏引用依据、Heading 过滤隐藏节点；Node.== 不覆盖完整 children/metadata。Task 02–06 必须先给出基础设施，本任务不能用这些旧机制作为“已经支持恢复/相等”的证据。

## Follow-Up Work

**新增前置里程碑07-P（2026-10-22，已纳入执行要求）：** 06完成并审查后，07先只适配真实Paragraph、List/Blockquote、Heading与ReferenceLink及其实际typed renderer，运行窄纵切，再开展其余Standard适配。覆盖超长单行中改单字、嵌套局部编辑、唯一标题改名、重复slug与引用定义变化、取消/旧快照完整性；生产语法与legacy共用实现。加最小单文档stdio协议探针，采用15的SeaJson + Content-Length及同一版本/schema约定，验证分帧、change/flush/cancel和结果版本；探针仅是独立测试driver/原型，不注册正式CLI命令，不建设workspace，不声称完成15。

07-P由07 owner负责真实插件/renderer改动和独立测试原型；如需core契约变更，退回02/05/06所属owner串行处理。测试协议schema/framing交接文件须记录唯一owner，正式15消费/迁移同一契约，不维护第二套生产协议。07-P不改变正式18任务hard edges，也不能绕过06。

1. 实施前重新记录 HEAD/dirty 状态，保留已有改动；核对 Task 06 的公共签名、typed codec 原型与实际命令结果，建立 13 插件 facet/phase/register trace 对照表。
2. 接入同一 matcher 内核的纯 probe 或隔离事务，注册完整 frame/state codec、syntax/effect ownership、正/负查询和撤销；不能复制简化 Markdown parser。
3. 为 Blockquote/List/Paragraph 建可恢复子单元：恢复 marker/indent 与 nested context、只替换变更 item/child/inline candidate 区域、复用未变兄弟；记录真实扩大原因与到 EOF 的必要传播。
4. Heading 将原始 ATX 事实与有序 slugCounts/counters/hiddenSectionLevel 结果分离。实现本插件可撤销 reducer/完整状态收敛，保留隐藏原语法；为 Setext 提供同一 Heading 贡献入口。完整语言投影、AutoAnchor/TOC 查询属于 Task 11/12，本任务只交接其所需 typed 数据和依赖。
5. ReferenceLink 保留 definition 候选及原始 full/collapsed/shortcut/image provenance；实现 winner 与 missing 查询反向索引、删除候选接管及可逆 Link/Image/Text 视图。collapsed Unicode span 风险单列基线，基础设施纠错有明确预期。
6. typed codec 覆盖各标准子类型、constructor 字段、raw、metadata、parent、source map 与 stable ID；让实际 renderer 完成类型转换/输出验证，禁止以 plain Node 替代 subtype。
7. 围栏 syntax 与派生服务拆开：finalize 产出稳定代码单元和按需服务请求，cache hit 前不调用 native；payload 使用版本化 source view/持久行索引，正常单行编辑不能 join 整 code literal。公开冻结的源行 iterator、稳定 line identity、服务 handler 和 render subunit 接缝供 Task 13 接入；legacy literal/整块输出显式读取才按需 materialize。保留旧 parse/stream 请求目标的可观察语义，异常/取消不提交半个结果。
8. 形成以下交接表并由协调者冻结。后续 08/09/10 只调用，不改 shared helper；任何新增 shared 需求退回串行契约/集成任务。

9. 对当前 List.startsDetachedBlock 中 fence/heading/divider 的显式判断建立兼容 trace；新嵌套能力必须经注册 parser 的纯 probe/冻结 child parser plan 接入，不新增 foreign marker 名单。让自定义非 Markdown、多字节起始语法插件通过同一接缝参与 quote/list 的 nested 边界判定，保持已有语义。

| 冻结交接 | 必须给出的可执行证据 | 后续消费者 |
| --- | --- | --- |
| Heading typed node + ordered contribution | ATX/Setext 共同 payload、slug/number/visibility 读写键与恢复等价；保留现有两种语法差异基线 | 08、11、12 |
| typed Node codec/adapter extension | 子类型字段、唯一/稳定身份、parent 与 source map 保真；新插件只注册自己的 codec | 08、09、10 |
| mapped nested parse + partial child splice | 局部 frame/pending/activeLine/depth 恢复，全局效果显式归属；异常回滚与兄弟复用 | 08、09、10 |
| positive/negative dependency + ordered reducer | 缺失定义、winner 切换、编号后缀恢复，cache hit 也保留效果所有权 | 08、09、10、11、12 |
| render service request + stable unit identity | 围栏 syntax 不无条件执行 native；版本/目标/资源请求可取消并去重 | 09、10、13 |

## Acceptance

- **07-P放行硬门槛：** 真实超长单行普通字符edit不先构造整行/整段String，未变nested兄弟parser为0调用，实际typed renderer工作；唯一标题改名不重parse无关正文，真实slug/引用依赖正确更新。分列syntax/semantic/render与复制字节计数，逐步fresh oracle相等。
- **07-P协议/性能门槛：** 独立stdio探针对UTF-8拆包/粘包、change/flush/cancel及版本行为有实际结果；batch同`-O2`配对复测满足01冻结预算。未过不得展开07剩余大规模适配；通过仅证明窄纵切，非全部13/30插件或正式worker完成。

- 13 个正式类名全部有真实 facet、codec/状态或明确无状态证明、读写/撤销、缓存与收敛测试；SoftBreak 归 Paragraph，不能漏算或多算。
- [清单 Blockquote/List/Paragraph 案例](plugin-standard-commonmark.md#逐插件适配)：长 quote/list 中只改一个嵌套 item，以及超长 paragraph 普通文本编辑，未变兄弟/安全窗口之外节点不重解析；不能以整容器 fallback 结项。记录扫描单位、重建单位和扩大原因。
- 自定义非 Markdown 且带多字节起始符的测试插件嵌入 quote/list；修改其 opening/closing 边界仍由注册 pure probe/child plan 正确增量，未改兄弟复用。加入该插件无需修改 core 或 List 的 foreign marker 名单；记录成功/失败 probe 均无状态泄漏。
- [Heading 两例](plugin-standard-commonmark.md#02-headingplugin)：同名标题前插标题、closable/level 改动可逆显隐，slug/编号及正负依赖正确；隐藏语法仍存在，未改正文/昂贵单元不重算。
- [ReferenceLink 两例](plugin-standard-commonmark.md#10-referencelinkplugin)：定义增删和首候选移除使 resolved/fallback/shortcut 更新，中文 collapsed span 与 parent/ID 无漂移，不运行全树破坏性 finalize 作为最终路径。
- [FencedCode 两例](plugin-standard-commonmark.md#04-fencedcodeblockplugin)：删 closing 吸入/补回释放后文，language/line rules 改变正确撤销派生；Task 13 handler 未接入前可测试请求桩，不得声称 CodeHL 行增量已完成。
- 全部输出对照同配置新全文 oracle，typed renderer 可用、旧 snapshot 不受新 edit 污染、byte/rune/UTF16/CRLF 映射正确；禁止以 Node.== 或 canonicalization 忽略用户可见 slug/href。
- 共享交接签名/所有权/phase 顺序经协调者审阅冻结；不改 core/bundle，不新增核心 marker/插件名单分支，无永久内置全文 fallback。仓颉最低兼容保持 1.1.0。

## Verification Record

- 本轮：静态阅读 README、设计锁、架构和三组 plugin 清单，并核查上述现有源码路径；仅编写任务文档。
- 未运行：新实现构建、13 插件编辑测试、性能/内存测试；尚无适配完成或通过结论。
- 未来已知命令：在 `markit/` 执行 `cjpm test`；实际工具链和仓颉 1.1.0 环境记录到验证日志。当前没有执行。
- 拟新增验证入口：Standard editing/codec/nested/dependency suite 及 workload counter harness（名称和路径待实施任务创建），包括上述用例和每插件清单至少两例；不得将拟新增 tag/tool 写作现存命令。
- 交付证据：实际命令/结果、失败与基线纠错记录、13 项矩阵、共享交接签名、复用/调用计数、缺口；由协调者决定放行 08/09/10。
