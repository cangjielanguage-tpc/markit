# Task 11：i18n 效果与语言投影

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本任务覆盖3个横向插件中的I18n：逐项适配实际注册的状态、附件、效果、语言投影和依赖；横向能力无需伪装block parser，但同样不能靠外部插件兼容出口结项。

标准库热路径只选择性查阅用户提供的只读源码 `C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`：针对本任务实际使用的操作核实复制、扫描、分配及源码/运行SDK版本对应；有争议仅做最小实测，不开展全面标准库研究或新增框架。

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

## Execution Contract

- Depends on: Task 08、Task 09、Task 10，均须由协调者审查验收后放行；继承 Task 02–06 已冻结契约。
- Unlocks: Task 12。
- Execution: 并行 C，与 Task 13 文件隔离；Task 12 为本任务后的串行集成。
- Delegated owner: 语言投影子 agent，由协调者指派。
- Scope boundary: 拥有 `markit/src/plugins/i18n/**` 及 `markit/src/tests/unit/plugins/i18n/**`；本任务新增编辑测试也放在该测试目录，不并行改共享streaming/benchmark文件。输入为冻结 facet/codec/source-map/effect-store、Standard/CommonMark/GFM 已验收适配和 Task01 注册顺序oracle；输出为全部 I18n facets、可恢复state、结构/语言overlay、测试及交接清单。禁止修改 Task13 的 CodeHL/MathTex/Mermaid服务和围栏渲染缓存；禁止修改 shared core/registry 协议、其他插件实现、README或进度。发现共享缺口退回前置owner，不以并行任务临时改契约。

## Goal

使 I18nPlugin 的inline/block parser、session state、emission filter、session/post-finalizer及四kind三格式renderer全部进入正式编辑协议。保留原syntax，支持可撤销附件/列表结构、语言切换和真实原文映射；普通编辑复用未变子单元，不以每次全树postprocess或内置fallback结项。

## Current State

- `markit/src/plugins/i18n/i18n_plugin.cj:41` 注册 state、inline/continuation parser、filter、两类finalizer及renderer，不是单一显示过滤器。
- `i18n_session_state.cj:20,168,205` 会吞掉当前节点、延迟默认附件、修改/合并前序list和旧patchTarget；pending数组保存可变Node引用。snapshot(:63)只有动态名，且深缩进允许标志在ParseSession里。
- `block/i18n_block_parser.cj:84` 使用零起点SyntheticSourceBuilder解析子树，只冻结rawContent，没有组合回原文的span；未闭合块在EOF回paragraph。
- `processors/i18n_post_processor.cj:24,92` 全树设语言/显隐和可见heading slug；setRenderFlags只添加false，不能直接原地重跑保证恢复。
- 依据：[横向插件清单](plugin-cross-cutting.md)。当前没有本任务新实现/测试证据。

## Follow-Up Work

1. 按facet完整登记owner/priority/ordinal/fingerprint、边界、读写键、state/frame codec、撤销/replay和缓存。语法判定继续由I18n parser提供，不向core/CLI/webview新增插件名或marker分支。
2. 将I18nBlock frame和pending lists/attachments/deferred emissions持久化：使用稳定ID与版本引用，保留list族/有效indent/patchTarget和ParseSession相关context flag；checkpoint共享persistent root，不能逐边界复制全部state。
3. 在原始syntax上记录默认节点、翻译块和原归属；用owned structure overlay表达附件替换、列表合并、move、tight override、隐藏文本等。替换旧单元先撤销旧贡献，再重放；反向修改旧target属于同一事务write set。
4. language/target/visibility与父容器child聚合为可撤销投影。切语言复用原始syntax，不全文重parse；凡target影响旧state/结构判定，重放相应语义/结构投影并复用同构syntax，而非跳过必要E阶段。向Task12发布visible heading text/visibility/slug输入及版本，不抢改其heading索引。
5. 使用Task03组合map表达去缩进、synthetic换行、inline括号/escape和嵌套list/quote/i18n的generated→original映射；三格式renderer输出带对应projection source-map。
6. 使用Task06候选窗口/负closure依赖和block nested subunits；普通文本改动不重扫整个长inlineowner/整list/quote。不闭合或delimiter递归影响可扩大，返回原因与扫描计数。
7. 按Task01当前真实hook顺序保持旧observable结果；phase依赖冲突交Task12集成诊断，禁止自行把i18n移到anchor之前修语义。配置/语言变化先撤销本facet旧render标志，避免残留false。
8. 添加至少四组编辑：删除/补回i18n closing；翻译heading改文/切target；前序list默认附件→翻译替代→删除恢复；深嵌套synthetic中emoji/CRLF编辑。各组含undo/redo、批量edit、取消/重试、旧snapshot隔离、三格式/JSON/source-map及工作量计数。

## Acceptance

- I18n全部注册facets有实际adapter，能力报告中无永久fallback；未知第三方兼容策略不算本插件通过证据。
- 每步结果与同配置fresh parse及注册顺序oracle一致；原syntax仍保留过滤节点/附件，删除翻译后可恢复默认内容；无重复child、悬挂parent、重复ID或旧snapshot污染。
- pending list/attachment、deferred emission和缩进context在checkpoint restore后与连续parse一致；取消/异常不泄漏mutation。
- target切换不重新调用未变原syntax parser；必要projection失效有计数；无关CodeHL/MathTex/Mermaid单元0调用。
- 超长文本普通edit只扫安全候选窗口，深list/quote只重建受影响子单元；真实闭合传播到EOF单独标原因，不拿它替代普通场景局部性。
- byte/rune/UTF16映射精确回原文件，覆盖去缩进、嵌套synthetic、emoji、CRLF；不发布局部0起点作为文件坐标。
- 交接Task12：facet清单、输入/输出依赖键及scope、可撤销贡献类型、语言/heading投影、完整测试命令/结果和仍需集成的顺序冲突。

## Verification Record

- 本轮：只读调查源码与三份插件清单并编写方案；未实现功能、未运行新测试，Status保持Pending。
- 未来：在`markit`包执行`cjpm test`及实际新增编辑测试；`I18nEditing`等tag/过滤入口为拟新增，须落地后记录真实命令，不能引用不存在的runner。
- 既有测试位于`markit/src/tests/unit/plugins/i18n/`；追加stream基线位于`markit/src/tests/unit/streaming/incremental_state_tests.cj`，不能冒充本任务编辑验收。
