# Task 08：CommonMark 5 插件适配

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本任务逐个覆盖5个CommonMark新增插件：SetextHeading、HTMLBlock、CommonMarkAutolink、HTMLInline、EntityReference；按各自实际注册能力验证，不能以Standard共享能力或外部兼容回退代替。

标准库热路径只选择性查阅用户提供的只读源码 `C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`：针对本任务实际使用的操作核实复制、扫描、分配及源码/运行SDK版本对应；有争议仅做最小实测，不开展全面标准库研究或新增框架。

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

更新时间：2026-10-21。本文件是未来实施合同，当前未实施。

## Execution Contract

- Depends on: Task 07（唯一硬依赖）。
- Unlocks: Task 11；Task 11 还须等待 Task 09、10。
- Execution: 并行 B，与 09/10 隔离执行；07 交接经协调者审阅后释放。
- Delegated owner: CommonMark 插件适配子 agent，由协调者指派。
- Scope boundary: 只拥有 `markit/src/plugins/commonmark/**` 的五插件及该组独立测试。消费 07 冻结的 Heading、typed Node codec、partial nested parse、正负依赖/撤销接口；自己的 codec/facet 仅在本组文件注册。
- 禁止改动：core、bundles、Standard/GFM/横向插件、共享 helper、07 冻结签名或公共测试设施。新 shared 需求退回串行契约/集成审查，不与 09/10 共同修改。
- 输入：07 已验收的交接矩阵、01 的全量 oracle/ID纠错基线、设计锁和 [18 插件清单](plugin-standard-commonmark.md)。
- 输出：五插件适配、HTML pairing/extraction 可撤销 provenance、唯一 ID 与源映射纠错证据、局部性计数及交接缺口。

## Goal

使 SetextHeadingPlugin、HTMLBlockPlugin、CommonMarkAutolinkPlugin、HTMLInlinePlugin、EntityReferencePlugin 全部进入正式增量协议；共享标准 Heading 与 renderer，不引入新的 parser 副本或核心语法判断。

## Current State

事实证据与逐项案例见 [清单第 14–18 项](plugin-standard-commonmark.md#14-setextheadingplugin)。

| 正式类名 | 现状事实 | 适配要点 |
| --- | --- | --- |
| SetextHeadingPlugin | leaf；消费整个 pending paragraph；写 Heading state；无自有 renderer；与 ATX 的 metadata/closable 行为存在差异 | 前向 underline + 向前 pending 读取、同一 ordered Heading 通道，差异保留显式基线 |
| HTMLBlockPlugin | continuation；类型/tag/depth/protected/endMarker 状态；内部 Markdown 按配置启用 | 完整 frame codec、opaque 与 mapped nested 子单元、真实 close/EOF 收敛 |
| CommonMarkAutolinkPlugin | inline `<...>` URI/email；与 HTMLInline 竞争 | 成功/缺失 `>` candidate 依赖、覆盖/游标收敛 |
| HTMLInlinePlugin | inline + postFinalize；pairTags 及 HTMLBlock extraction | 配对前原始 siblings、可逆结构 overlay、局部配对与来源关系 |
| EntityReferencePlugin | inline；semicolon 搜索最多 32；三目标解码不同 | 局部 candidate、失败边界依赖与目标语义保真 |

源码：[Setext parser](../../markit/src/plugins/commonmark/block/setext_heading/setext_heading_parser.cj)、[HTMLBlock state](../../markit/src/plugins/commonmark/block/html_block/html_block_state.cj)、[HTMLInline plugin](../../markit/src/plugins/commonmark/inline/html_inline/html_inline_plugin.cj)、[CommonMarkAutolink parser](../../markit/src/plugins/commonmark/inline/commonmark_autolink/commonmark_autolink_parser.cj)、[Entity parser](../../markit/src/plugins/commonmark/inline/entity_reference/entity_reference_parser.cj)。

HTMLInline 当前配对 Container/protected Text 可复用 opening.id，引入同存活树重复 ID 风险；finalized 树不保留原 siblings。无论 pairing config.enabled，当前 extraction 仍执行。必须基于实际旧注册/生命周期保留可观察语义，不能把“关闭配对”误当关闭全部后处理。

## Follow-Up Work

1. 核对 07 的冻结签名与 scoped tests 命名；对照完整 register trace，保证类别/priority/ordinal 和启停配置按现有语义执行。
2. Setext 使用共享 Heading codec/有序贡献，不修改 Standard 文件。记录 pending paragraph 的反向读取与 mapped 多行内容，消费/退回操作具有事务撤销；ATX/Setext metadata 不对称先保留并列明基线，禁止顺便统一语义。
3. HTMLBlock 提供所有 parser 类型/tag/depth/保护字段的完整恢复和等价；普通内部正文编辑使用 07 的 partial nested 子单元，保留无关兄弟；opener/close/protected 切换按实际影响扩展，旧子 Heading/reference 效果可撤销。
4. CommonMarkAutolink/Entity 消费 06 候选窗口，保存失败读取与外层 opaque/context stamp；候选新增闭合符能唤醒旧负结果，不能无条件扫整个长 paragraph。
5. HTMLInline 保留单 tag 原始事实、pair/extract 前 siblings、父级/角色、保护 raw 来源和组合 source map；派生 Container/移动/SoftBreak 修剪写 owned overlay journal，先撤销旧结果再局部重配。
6. 在该插件适配层分配唯一结构角色 ID，与 04 的身份协议配合。原始 opening、Container、protected Text 不得共用一个 live ID。将此纠错与 oracle 的明确例外/新基线对应，不忽略 ID 校验来维持旧错误。
7. pairing 从受影响 sibling/可恢复 tag 栈传播到完整栈/归属等价处；nested extraction 更新受影响 HTMLBlock 子单元，不全树重新 postFinalize。其子全局语义贡献与读依赖照常进入事务。
8. 形成每插件 capability/codec/依赖/cache/收敛表及交接给 11 的可见结构和 provenance 版本；遇共享 API 缺口停止该依赖路径并报告，不越权补 core。

## Acceptance

- 五插件每项有本组真实适配；不伪造 Setext state/renderer，不重复计 Standard Heading；无内置永久 fallback。
- [Setext 两例](plugin-standard-commonmark.md#14-setextheadingplugin)：`Title\n---` 前置空行/删除 Title 以及 `===→---→==` 重分类与全文一致；Heading 编号/slug 消费同一 reducer，pending/后继状态正确收敛。
- [HTMLInline 两例](plugin-standard-commonmark.md#17-htmlinlineplugin)：`<span>a` 添加/删除 closing、`<code>**a**</code>` 改 span 再恢复，siblings/Container 可逆、provenance/raw/parent 保真，无重复 ID 或旧 Bold 残留。
- [HTMLBlock 两例](plugin-standard-commonmark.md#15-htmlblockplugin)：删补 closing/comment end、内部 Markdown 的 div/pre 切换撤销旧 Heading/reference；长 HTML 内一个普通子单元编辑不重建全部 siblings。
- [Autolink/Entity 案例](plugin-standard-commonmark.md#16-commonmarkautolinkplugin)：缺失 `>`/`;` 后补回能唤醒 candidate，32 边界与中文/emoji/CRLF 映射正确；entity 三目标不得强行统一为浏览器显示字符。
- HTML 配对关闭/开启及 extraction 行为与明确基线一致；语义纠错之外三目标等价。ID 纠错不能用删除 ID 断言或剥离 href 的 oracle 归一化掩盖。
- 记录真实解析/配对/映射/效果工作量；普通候选和嵌套正文编辑支持安全窗口/partial nested，不能把整 inline owner/HTML 容器作为最终默认重算粒度。
- diff 仅包含本组和独立测试，无 core/bundle/shared helper/其他并行组修改；新 shared 需求有串行交接记录。

## Verification Record

- 本轮只静态读取 README、设计锁、三组清单及相关证据；新实现测试未运行。
- 未来已知命令：在 `markit/` 执行 `cjpm test`，当前未执行；仓颉 1.1.0 为最低兼容环境。
- 拟新增：CommonMark editing/pairing/provenance/source-map suite 和计数断言，路径/tag 待任务实施创建，不宣称现存。
- 必须回报：实际命令和失败、五项矩阵、唯一 ID 纠错前后基线、完整/增量差分、扫描/复用计数、shared 缺口；协调者审查后放行 11 的此依赖。
