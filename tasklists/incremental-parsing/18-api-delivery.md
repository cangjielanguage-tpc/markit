# Task 18：公共 API、文档与本地交付门槛

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

更新时间：2026-10-21。当前授权仅方案；本任务描述未来获得实施授权后的交付步骤，不授权现在实现、打包、提交或发布。

## Execution Contract

- Depends on: Task 17（唯一硬依赖）。
- Unlocks: 无；最终交付需协调者审阅全部证据。
- Execution: 串行交付；17 的 30 插件正确性/局部性/全链路/性能证据经协调者审查后开始。
- Delegated owner: API 兼容与交付子 agent，由协调者指派。
- Scope boundary: 未来授权后拥有公共 API 导出/兼容 shim、source/public API 注释与示例、根及各包英文 docs/README、既有中文翻译同步、公共 API 兼容测试、扩展英文 UI/docs/manifest 的交付核查、packaging 配置与本地产物验收。只修交付/API/文档范围；如测试发现语法/协议/性能缺陷，退回对应已拥有任务修复并重过 17，不在本任务重写 core 算法。
- 不拥有/不授权：本轮源码改造或产物生成；自动 commit/push、registry/Marketplace/网站发布、依赖或 SDK 自动安装升级、提高最低仓颉版本、覆盖用户 dirty/未跟踪工作。打包命令仅在以后明确授权实施时执行。
- 输入：17 的完整审阅报告、全部 18 任务证据、三组 plugin 清单与 API/phase/patch 冻结契约、现有 dirty 状态和打包入口。
- 输出：完整源码/API/docs/UI 审核矩阵、可运行兼容与示例证据、未来本地 VSIX 0.1.0 及资产完整性记录、已知限制和显式未发布声明；不得把方案进度记作实现完成。

## Goal

在保持仓颉最低 1.1.0、旧 parse/stream/typed Node 使用方式与新编辑 API 清晰分离的前提下，交付可审阅、可复现的完整源码和英文 API/docs/UI。未来只准备本地扩展 `0.1.0` 产物，不自动发布或提交。

## Current State

- [Markit 公共入口](../../markit/src/markit.cj) 当前提供构造/use/empty、parse(String/InputStream)、renderHtml、parseWithCallbacks、createSession；parse 本身通过 feed/finalize 实现。编辑 API 是拟新增能力，不能改名旧 API 后宣称兼容。
- [架构 API 边界](architecture.md#1-当前事实与目标边界) 要求保留旧 finalize 的 terminal 行为，编辑会话另有可重复 flush/provisional close；[设计锁](00-design-locks.md#交付边界与既有工作保护) 明确最低仓颉 1.1.0、保护 dirty 工作且当前仅方案。
- [markit/cjpm.toml](../../markit/cjpm.toml) 当前 `cjc-version="1.1.0"`、包版本 0.1.0；不能把 SDK 最低版本与包版本混淆，或擅自提升到仓颉 1.3.0。
- [扩展 package.json](../../vscode-extension/package.json) 当前 version=0.1.0，英文 command/config 文案；现有 scripts 为 `npm test`、`npm run package`，后者输出 `target/markit-preview-0.1.0.vsix`。这是未来本地目标，不代表当前已有该产物。
- [扩展 README](../../vscode-extension/README.md) 说明 MARKIT_TEST_BINARY 可启用既有 native 端到端测试、资产须邻接可执行文件；已有单页 snapshot 预览不构成新 worker/edit/patch 完成证据。
- [核心库文档](../../docs/libraries/markit-core.md)、[插件文档](../../docs/plugins/plugin-system.md)、[CLI 文档](../../markit-cli/README.md)、[英文根 README](../../README.md)、[中文 README](../../readme-zh_CN.md) 需要在未来真实能力落地后同步；不能提前写“已支持”或保留虚假性能结论。
- 既有 dirty/未跟踪清单只是调查快照，实施前须重新读取；特别不能重建并覆盖用户的 `vscode-extension/` 或现有 CLI 单页改动。

## Follow-Up Work

**新增公共API交付要求：** 公开并文档化“增量能力可选 + 安全默认实现”：旧插件零源码修改即可编译/注册/普通parse/append，BlockParser等直接提供默认false能力和安全默认方法；同plugin可混合支持能力，编辑默认compat按已证明隔离的安全单位完整解析、无证明整会话回退，strict显式启用。说明诊断owner/facet/reason与成本，不把默认fallback包装成真增量；30内置真适配是项目交付承诺而非第三方必实现接口。以02在仓颉1.1.0验证的接口形式为准，交付示例包含完全不声明editing能力的旧插件。

1. 先审阅 17 的逐插件清单和工作量/延迟证据，核对 30 插件真实 facet、所有 fallback 移除门禁、行 patch/索引/worker/DOM 全链路。发现缺口回退对应任务，不以文档措辞替代实现。
2. 建 public API/源码交付矩阵：旧函数签名、类型/字段、typed subclasses、JSON、callbacks、InputStream/feedBytes/retention/异常行为；新编辑会话/坐标/版本/事务/查询/能力诊断与第三方 fallback/strict 明确公开。完整 source 包含实际运行依赖的源码、资产和测试入口，不交付仅包装脚本。
3. 使用仓颉 1.1.0 真实环境编译公共示例和兼容测试；若依赖选型/API 不可用，改兼容实现或记录阻塞，不升级 SDK 下限。仅标注版本字符串不算兼容证明，不自动安装/更改本机 SDK。
4. API 扩展按冻结契约公开，保留旧 terminal finalize 和 callbacks/typed renderer 行为；lazy literal/显式整文 materialize 能力注明 O(N)，新编辑热路径不依赖这些兼容入口。
5. 新增/修改的 source 标识符、注释、public API 说明、开发者文档、示例和产品 UI 文案使用英文，保持整个交付术语一致。既有中文 README/本轮中文方案保留对应定位并同步事实，不将要求误解为删除用户指定中文资料；禁止混入源码调试细节到用户 UI。
6. 更新核心/插件/CLI/kit/扩展/CodeHL/MathTex/Mermaid 文档：清楚区分 append stream 与 edit、初次完整构建与 warm 局部更新、EOF provisional/terminal、取消/版本冲突/重同步、未知第三方模式、缓存配额与真实传播。
7. 示例覆盖从零创建编辑会话、UTF16/byte/rune/CRLF、batch edits、嵌套自定义插件、正负定义依赖、跨页索引、语言投影和行级 patch；仅引用实际存在且运行过的 API，不把候选名直接写为可用接口。
8. 英文 UI 核查命令名、配置、错误/状态/诊断与 webview 操作；记录英文扫描和人工核查范围。引用 parser/服务诊断时保持可理解产品信息，不泄露不必要内部状态。
9. **仅在以后明确授权实施/打包时**：运行现有扩展测试及 package 脚本，验证本地 `target/markit-preview-0.1.0.vsix` manifest/version/运行资源与可执行路径；验证 native assets/grammar/theme/Mermaid 依赖完整。不给包或 registry 发 publish，不执行 Git commit/push，也不将 tasklists 加入版本控制。
10. 形成交付说明：源码变更与兼容策略、实际命令/环境/产物校验、17 性能结果及限制、未公开/未发布事项；协调者最后审阅。产品发布仍是独立未来授权行为。

## Acceptance

- **可选插件API兼容：** 原封不动旧插件fixture在最低仓颉1.1.0编译并通过parse/append；默认parser能力false、混合plugin、已证明隔离单位完整解析/无证明整会话重建和显式strict拒绝均有真实测试及公开文档。没有新增必实现抽象方法、伪默认stateless/local-safe或空restore；未知能力诊断清晰，内置30插件完成要求不被放宽。

- **CLI迁移交付：** 文档/help/examples明确worker --stdio预览入口及open/change/flush/close、response/status/patch语义；移除旧两个flag的推荐用法并注明迁移后明确错误。保留render/build文件输出、render --page以及Markit append API文档；附15/16/17联合迁移与渐进首屏证据，不把计划写成已实现。

- 全 30 插件矩阵与 [Standard/CommonMark](plugin-standard-commonmark.md)、[GFM](plugin-gfm.md)、[横向插件](plugin-cross-cutting.md) 一致；Mermaid 不另计 Plugin。所有内置最终无永久 full fallback，未知第三方明确 mode/reason 与 strict 拒绝行为。
- 旧 API 兼容案例：相同输入通过 parse(String/InputStream)、callbacks、分片 feedBytes/finalize 得到基线结果，finalize 后 feed 仍按旧 terminal 语义拒绝；typed renderer/DSL/JSON/SourceSpan/raw/source retention 不被 plain Node 或候选 API 替代。
- 新 API 交付案例：重复 flush 后继续 batch edit、取消/过期版本和 UTF16 emoji/CRLF 边界得到明确行为；旧 snapshot 不变，版本冲突不覆盖新结果，示例在最低仓颉 1.1.0 实际可编译运行。
- [逐插件案例交付交叉检查](plugin-standard-commonmark.md#验证记录与交付审查)：reference definition 新增/移除、HTML pairing provenance/ID 纠错和局部 nested 编辑在公开示例/测试中有入口；不是只展示一个普通 paragraph。
- [重型服务交付案例](plugin-gfm.md#15-统一验证协议证据与未证明项)：普通一行 code 编辑不整 literal/HTML materialize，未变公式/图零调用；文档如述性能必须链接 17 的实际负载/硬件/冷暖/p50/p95 与未达项，不把旧 stream benchmark 当 editing 证明。
- 新增/修改源码/public API/docs/UI 为英文且术语、实际 signatures/manifest 一致；既有中文翻译同步保留；README 不夸大未实现功能或把候选名当现有 API。
- 未来已授权本地打包案例：VSIX manifest 为 0.1.0，安装/启动/持久 worker/line patch/assets 可用，真实 native E2E 测试没有因未设置 binary 静默跳过；目标文件路径和校验明确，未发布到 Marketplace/registry。
- 当前方案阶段负验收：没有运行 package/build 产出交付包，没有修改 SDK/依赖/最低版本，没有 commit/push/publish，没有暂存方案或覆盖 dirty 工作；未来实现也不自动获得发布授权。
- 任何算法/API/性能缺陷必须回原任务并重跑相关 17 gate；不能用删除测试、忽略 ID/href/编号、抬高 SDK 或扩大永久 fallback 解除门槛。

## Verification Record

- 本轮实际完成：静态读取 README/设计锁/三清单、Markit 公共入口、markit/cjpm.toml、扩展 package.json/README 和文档路径；仅编写此任务方案。
- 未运行：新公共 API、兼容测试、最低 SDK 编译、扩展打包/安装/发布；未生成或验证 VSIX，不声称实现完成。
- 未来已知命令（仅实施授权后，在对应工作目录运行）：`markit/` 下 `cjpm test`，`markit-cli/` 下 `cjpm build`，`vscode-extension/` 下 `npm test`、`npm run package`。MARKIT_TEST_BINARY 需设置为已验证 native binary，记录 E2E 是否实际执行；当前不执行这些命令。
- 拟新增：public API compatibility/examples/source-map/strict-mode suite、1.1.0 compatibility runner、英文术语/公开导出和 VSIX 内容校验工具；名称/tag/路径待实施，不能写成已存在或已通过。
- 最终回报应包含实际环境/命令/结果和跳过项、完整 source/API/docs/UI 矩阵、1.1.0 证明、未来本地 VSIX 0.1.0 checksum/内容、未发布声明；由协调者审阅后才可认定完成。
