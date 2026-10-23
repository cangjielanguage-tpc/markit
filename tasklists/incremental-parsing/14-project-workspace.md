# Task 14：持久项目索引与 workspace

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

## Execution Contract

- Depends on: Task 12、Task 13，双方交接均由协调者审查后释放。
- Unlocks: Task 15。
- Execution: 串行集成。
- Delegated owner: 项目索引/workspace子 agent，由协调者指派。
- Scope boundary: 拥有`markit-kit`内拟新增workspace/context、项目heading scanner/FileTree/link resolution增量接入及对应测试；允许串行修改`models/global_context.cj`、`scanners/heading_state_scanner.cj`、`renderers/markdown_renderer.cj`、必要processor/summary接入。输入为Task12派生query契约与Task13重型服务；输出为多项目/多语言持久workspace API、索引/缓存生命周期和文件事件事务。保留当前dirty单页工作，禁止覆盖用户修改；不改CLI framing/命令、extension、core grammar、heavyservice内部、README。

## Goal

首次打开允许完整项目建索引，此后按文档/配置/summary/文件事件更新持久上下文，使普通当前页edit不扫描未改项目文件，保留本地文件/heading智能链接、summary归属、编号及多语言项目隔离。

## Current State

- `markit-kit/src/renderers/markdown_renderer.cj:781`在`--page`选择renderFiles前无条件运行全项目HeadingStateScanner；:820只提前退出全站后处理，不代表编辑增量。
- `scanners/heading_state_scanner.cj`逐文件readFileContent、提取heading、计算initialStates，再重建FileTree；选中页在WebsiteProcessor中还会完整parse。
- `models/global_context.cj`是静态可变上下文；当前processor、Summary/FileTree/配置读该上下文，不能未经隔离证明就并发两个项目/语言。
- LinkPlugin SmartHeadingLinkResolver消费FileTree、currentFilePath、LinkConfig；索引变化即使source未改也可改变渲染。summary scope/路线/语言影响文件归属。现有事实见[架构方案](architecture.md)与三份插件清单。

## Follow-Up Work

1. 设计并实现WorkspaceSession，隔离projectId、workspace root(s)、summary scope/顺序、配置fingerprint、target language、URI规范化、文档dirty overlay、索引版本与缓存quota。打开Markdown时自动检测其所属文档项目，不先要求用户手工选项目；仅有多个真实有效归属时提示确认。多root/多文档目录的同名或共享文件按配置与summary解析ownership，不能仅basename或最近目录猜测。
2. 将GlobalContext迁移为可传入的实例context或隔离adapter。过渡期间worker调度必须串行完整项目任务，明确context切换/恢复；完成多项目实例化与测试后才允许并行。不得用进程静态变量假装独立session。
3. cold open按summary与showDrafts等规则收集项目文件，缓存每文件版本/content fingerprint、lossless syntax引用、heading projection、有序编号入口/出口摘要、输出路径、FileTree entries与正负link subscriptions。复用Task12查询结果，不再额外“轻量parse”同文件。
4. warm edit只更新对应dirty文档贡献；通过文件序有序reducer传播编号到状态收敛处，按reverse subscriptions失效引用该文件/heading的页。未改文件read/parse数为0；删除首heading、重复slug等不漏依赖。
5. 处理create/delete/rename、目录变化、summary条目/顺序/路由前缀、config/theme/target变化；记录本地`.md/.markdown/html`路径、相对链接、锚点、fuzzy/missing查询的键与scope。文件不存在和heading不存在必须有负查询，新增后自动更新。
6. 每项目语言分别持久化在该项目配置，支持热切换，拥有独立投影/缓存/编号状态；文档切换自动采用所属项目配置，不要求预选项目。同source可共享语法内容但不共享可变overlay。dirty buffer优先于diskwatch，事件带版本并去重；跨项目只失效真实消费者，不能全局clear。
7. 资产/主题/资源复用含配置和引擎版本；关闭项目/文档释放source、snapshot、cache引用，保留quota内可复用内容cache。向Task15提供open/change/flush/config/files/close与计数，不依live-server。
8. 添加100/1,000文件项目、多个root/文档目录同名页自动归属、共享页真实歧义才确认、每项目不同语言配置持久化/热切换、summary重排、外页缺失目标新增/rename/delete、dirty与disk乱序、配置切换、close/reopen的测试。

## Acceptance

- cold全读允许且有明确计数；warm普通当前页edit不读取/解析未改文件，不重建完整FileTree或全项目prescan。
- 本地文件/heading/智能链接与fresh项目build一致，正/负查询、summary归属、路径大小写/分隔符/URI、输出路由和文件变更覆盖；无网络服务依赖。
- 编号跨文件传播只到真实收敛点，无法局部化的配置变化有清晰原因；同页不为prescan再parse一遍。
- 多root/项目/语言无state泄漏；在GlobalContext完全实例化前串行执行有测试/诊断，不能默许并发污染。
- 多root和多文档目录直接打开Markdown即自动归属，不出现常态“先选项目”；只有真实多归属才确认。各项目语言独立保存至项目配置，热切换及close/reopen后保持，切换其他项目不被覆盖。
- 配置/语言/主题变更保留未变原syntax并只失效相关overlay/重型服务键；Task13不变代码/公式/图0调用标准保持。
- 返回Task15稳定workspace API、事件schema、version/fingerprint、索引ready条件、配额/close行为及实际测试/工作量证据。

## Verification Record

- 本轮为静态调查与方案编写；未实现WorkspaceSession，未跑项目增量测试。
- 未来执行`markit-kit`包的`cjpm test`及实际新增WorkspaceEditing矩阵；tag/场景入口为拟新增，落地后记录真实命令、数据集、冷/热文件计数。
- 不把当前CLI `--page`/`--incremental`资产复用测试当作本任务持久索引通过证据。
