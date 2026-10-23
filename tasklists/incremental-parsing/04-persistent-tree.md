# Task 04：持久语法树与 owner 效果存储

Status: Done

## Execution Contract

- Depends on: Task02 冻结契约；与 Task03 并行实现。
- Unlocks: Task05（须 root 审查 Task03/04 实际证据）。
- Delegated owner: `/root/task04_tree`；独立 effects/cache 子责任 `/root/task04_tree/effects`。
- Scope: `core/nodes/`、`core/document/`、`core/session/` 内自有产品文件与独立 `tests/unit/` 测试；不改冻结 `core/editing/`、03 source 实现、插件、CLI 或 runtime 接线。
- 用户当前裁剪优先：实施到 Task16 验证后停；不做 Task17/18、不提交或推送。最低 SDK 兼容环境、通用 oracle/计数/benchmark 框架延期；保留产品必要定向测试、完整结果对照和同 `-O2` 小记录。实际 SDK 为 1.3-alpha，未验证 1.1.0。

## Goal

提供实际共享 raw 记录、局部替换和版本视图，以及可撤销 owner effects 和有界缓存。旧 typed API 在显式 legacy materialization 边界保留类型、字段、metadata、raw、source 及额外引用。

## Completed Implementation (verification pending where stated)

- `RawSyntaxNode` 私有 payload、持久二叉 children 序列；getter 不泄漏可写数组或 live mutable Node。单个子节点替换只复制二叉序列路径，祖先共享其私有不可变 payload。
- `PersistentDocumentVersion` 使用不可变 AVL ID 索引，替换仅删除旧局部子树、插入新局部子树并复制祖先路径；不用全 HashMap clone、overlay 历史链、tombstone 或全树 reindex。重复稳定 ID、跨文档 records/source 在发布前拒绝。
- `SyntaxNodeView` 按版本解释 parent/path；raw 节点保存 source anchors，位置消费仅依赖 Task02 Source 抽象。children 空间摘要沿修改路径解析到目标 source epoch，混合 birth 版本不要求全量重基；同 offset 的 min/max 分别保留 Before/After affinity。
- `PersistentNodeCapture` 是显式 legacy 导入，按 ID memo 保留 typed codec 的额外引用；`materializeLegacy` 是显式 O(N) detached 图导出，保留 metadata 三类型、typed renderer 和额外引用 alias。普通替换不调用 `NodeCodec.clone`。
- `PersistentTextPayload` 内部 UTF-8 有界 1024-byte leaves 和持久 AVL split/join。常规标准 Text capture 已接入；单处 splice 不拼接整 literal，不生成整 HTML；显式导出仍是一个 TextNode、零额外 children。base metadata/source/render hooks 保留；raw 与 logical 不同的记录分别保留 raw payload。
- `OwnedEffectStore`：有序候选、winner、owner 撤销与重放、positive/missing 读依赖、按 key overlay、旧快照隔离、cancel/stale 拒绝；payload 出入 clone。
- `PersistentQuotaCache` 与 `SourceVersionRetention`：cost/quota LRU、cache pin、current/snapshot/cache source lease 和 release callback。

## Verification Record

- effects/cache 两产品源独立 `cjc -O2` 编译 exit 0；官方测试二次编译 exit 0，生成 binary 直接执行：**9/9 OwnerEffects Passed，exit 0**。首次测试链式赋值语法失败保留在证据中，未改写为通过。详见 [effects report](task04-tree/effects-report.md)。
- `PersistentTree` 已有 11 个最小测试源码：持久共享、真实 typed renderer/metadata/raw、引用 alias、重复 ID/取消/过期原子性、辅助子树 root 修复、raw 数组与 source append 隔离、超长 Text、文档内 Text splice、抽象 source anchors、真实 rope 混合 birth 空间摘要及同 offset affinity。
- tree 完整项目第六次实际编译 exit0；官方生成 binary 直接 console 执行 **11/11 PersistentTree Passed，exit0**（`parallel-a-verification/persistent-tree-test-2.log`）。最终全27包 **632/632 Passed，0skip/error/fail**，全部exit0；同O2操作driver编译/运行exit0，正反顺序每轮完整结果断言通过。详见 [tree report](task04-tree/tree-report.md)。root已实际审查源码/定向与全包/同O2证据并验收通过，产品与测试冻结。
- 三个只读预审确认缺陷已修并有回归断言：aux descendant 替换污染文档 root、aux records 重复 ID 绕过、跨文档 source 绑定。混合 birth 摘要退化问题已定向修复并加真实 rope 测试，定向执行通过。
- [同 O2 小记录 driver](task04-tree/local-edit-time.cj) 已准备：4096 sibling 的局部替换与 fresh 全重建、长 Text splice 与完整 String 替换，正反顺序各一轮，计时后校验相同结果；已经实际执行exit0；最小同O2结果与适用边界记录在tree report，不作统计/整体parser性能结论。
- `git diff --check` 当前 exit 0。

## Remaining / Task05 Handoff

- tree定向11/11、effects9/9、全27包632/632、同O2 driver均已完成；已保留实际SDK/命令/exit/首次失败及修复记录。root已审查并验收当前Task04范围。
- runtime 的 parse/checkpoint/effects/source/patch 原子组合由 Task05 串行接线；此任务不声称真实 parser/finalizer 已使用 raw tree，也不声称 30 插件 codec 已适配。
- source version 强引用仅确保旧 view 坐标/文本仍可访问；03 历史 delta 和 active raw anchor epoch 的生命周期需要 Task05 通过 lease 协调。04 不调用 03 私有结构，不声称历史 resolve 是 O(log N)。
- 03 anchor resolve 的有界热缓存由其 owner 实现；冷查询仍按跨版本历史工作，真实安全 prune/epoch 生命周期接线留05。04 range query只解析 touched bounds/candidates，旧 raw offsets不全量重写。
- 长 Text raw/logical 异形映射由 plugin/source-map owner 解释；logical splice 不猜测 Markdown marker。显式 legacy 字符串/typed 图导出允许线性工作，editing 路径不依赖这些导出。
- HTMLInline 重复 ID 的实际插件构造修复及全部内置 provider 注册归后续插件任务，基础设施已拒绝重复 ID，不把校验关闭作为兼容办法。

## Historical Baseline

Task04 开始前仅有 mutable `Node`、整图 `NodeCodec.clone`、每次全索引的旧 `DocumentSnapshot` 和无 owner effects 的旧 session 存储。旧 API 原有 batch 行为仍保留；新增持久存储的 runtime 接线由 Task05 完成，不能将旧行为描述成已被替换。