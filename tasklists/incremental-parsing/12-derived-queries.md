# Task 12：有序语义、AutoAnchor 与 TOC 查询

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本任务覆盖3个横向插件中的AutoAnchor与Toc：实际有序语义、slug/编号、查询正负依赖与派生结果须可失效、重放和验证；不以默认整会话回退替代。

标准库热路径只选择性查阅用户提供的只读源码 `C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`：针对本任务实际使用的操作核实复制、扫描、分配及源码/运行SDK版本对应；有争议仅做最小实测，不开展全面标准库研究或新增框架。

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

## Execution Contract

- Depends on: Task 11；Task11承接08/09/10，Standard/CommonMark共享适配已结束，须审查其交接。
- Unlocks: Task 14（还需Task13完成）。
- Execution: 串行集成，不能与Task11同时修改语言投影，也不抢Task13服务文件。
- Delegated owner: 有序语义与派生查询子 agent，由协调者指派。
- Scope boundary: 拥有拟新增derived query/index组件、`markit/src/plugins/anchor/**`、`markit/src/plugins/toc/**`、Standard Heading/ReferenceLink语义adapter及相应测试；07/08已结束后允许串行调整其语义接入。输入为真实注册顺序oracle、冻结effect/dependency contract、Task11语言投影及前置全部适配；输出为ordered reducers、正负查询索引、Anchor/TOC完整增量能力和对Task14的项目链接接口。禁止改syntax grammar、heavy render服务、worker/扩展、README；共享core契约问题退回owner。

## Goal

以可撤销有序贡献和查询索引替代每edit全树finalizer/TOC扫描，保持heading编号/closable/slug、引用winner、AutoAnchor、TOC及本地heading链接的当前observable语义，并在完整状态与依赖上下文收敛处停止传播。

## Current State

- `markit/src/plugins/standard/block/heading/heading_session_state.cj`持有slugCounts、六级counters、hiddenSectionLevel，当前snapshot不保存这些数据；Setext共享Heading状态。
- `standard/inline/reference_link/reference_link_registry.cj` 为ASCII lower label、first definition wins；finalizer可能删refLabel或把reference破坏性转Text，visible树不足以恢复新增定义。
- `anchor/auto_anchor_plugin.cj:26`只有post-finalize，processor按文序遍历，heading重置计数(:112)，source绝对坐标复制到metadata(:107)。AutoAnchor目前识别List/TaskList，不得顺带扩展其他kind语义。
- `toc/toc_plugin.cj:20`仅renderer；Toc.parse/extract*递归全树，依赖visible text/slug/number；TocNode.items独立于children，item默认ID0。
- `PluginRegistry`现将post hooks按注册顺序扁平化；bundle早注册AutoAnchor、用户后use I18n可能先anchor后i18n，不能假定旧顺序就是理想依赖顺序。详见[横向清单](plugin-cross-cutting.md)和[Standard清单](plugin-standard-commonmark.md)。

## Follow-Up Work

1. 从Task01冻结的有限代表性矩阵提取最终语义和阶段trace：Standard/CommonMark/GFM、I18n/Anchor/Toc相对注册次序、相同priority冲突及实际风险配置，不能只测默认bundle。按Task02保留owner/priority/ordinal/fingerprint建立有序phase graph；依赖要求与legacy顺序冲突时返回明确诊断或经oracle证明等价的适配，不能静默重排。额外覆盖相关pairwise和固定seed生成组合，不要求30!注册排列或2^30插件子集穷举。
2. 用persistent contribution tree维护heading文序、编号入口/出口、hidden section、baseSlug重复项和Typst label；每单位删除/替换先撤销owned贡献，保留原始hidden heading syntax。state summary仅在可证明可结合时聚合，否则检查点重放至真实收敛。
3. 定义/引用索引保留重复定义有序候选及first-winner规则；订阅包含成功解析和missing负查询。保留reference syntax与fallback Text overlay，新增/删首定义时唤醒所有受影响消费者而不全文DFS。
4. 消费Task11已提交语言/结构投影，生成HeadingProjection(nodeId/order/level/visibleText/number/slug/visibility/version)。可见text还受inline/ref/html/footnote等已声明依赖影响，不按literal猜文本。
5. AutoAnchor按section/list有序摘要重放：seen唯一性、sectionNumbers/currentPrefix、各类counter、nested path、table sourceTarget。visible anchor与稳定NodeId解耦；位置变化用source-map/position delta，不逐节点重写offset或重新高亮。
6. TOC基于HeadingProjection维护多title/min/maxLevel视图和层次，派生item身份通过view allocator+heading身份映射，不能按slug/offset/hash或全部0。保留Toc.parse/extract*/generateTextToc、typed TocNode/TocItem与三格式/JSON行为。
7. 将本地heading/FileTree/resolver查询适配为版本化读依赖，输出给Task14文档级heading contributions与正负link subscriptions；不在此实现workspace全项目生命周期。
8. 添加案例：重复slug前插/删同名heading；closable开关恢复隐藏section；ref缺定义→新增→重复首定义删除；i18n改visible heading→TOC/link；同section前插code改变anchor但不重高亮；TOC H2→H3/delete/undo；table首cell换target和配置关闭撤销。

## Acceptance

- AutoAnchor/Toc两插件全部facet真适配，Standard Heading/Reference语义可撤销且与07语法内核共用，不新造编辑简化语法。
- Task01冻结代表性注册顺序矩阵、相关pairwise/真实风险组合与固定seed生成样例均与基线oracle一致；不要求无界排列穷举。冲突有可复现诊断/等价适配，不靠重排或剥用户可见slug/anchor绕过比较。随机HTML/SVG内部ID若规范化必须验证引用一致。
- 正/负查询、重复定义winner、slug occurrence、编号、hidden section、语言投影、TOC text/href/number与fresh parse一致；添加定义能从Text overlay恢复Link而原syntax未丢失。
- 普通paragraph编辑不扫全树heading/anchor/TOC；有序传播在入口/出口state及依赖相同后收敛；位置变化不导致未变内容render/CodeHL/公式/图调用。
- TOC多视图、空视图、跳级、min/maxLevel/DSL输出兼容；派生ID唯一且跟heading身份稳定，旧snapshot不变。
- schema明确Task14要消费的heading/filelink正负依赖和版本；交接包含函数契约、适配清单、测试和传播计数。

## Verification Record

- 本轮仅静态源码盘点和方案编写，未运行新实现；Status Pending。
- 未来在`markit`包执行`cjpm test`和实际落地的有序语义/查询编辑矩阵；`DerivedEditing`/`QueryEditing`等tag为拟新增，不能当作现有入口。
- 现有`markit/src/tests/unit/plugins/anchor/`、`toc/`以及streaming测试可作兼容基线，不能替代负查询/undo/局部性证据。
