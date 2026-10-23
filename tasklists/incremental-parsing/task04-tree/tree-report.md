# Task04 tree 产品实现与交接

更新：2026-10-23。owner：`/root/task04_tree`。

## 实际文件

新增产品：
- `markit/src/core/nodes/persistent_node.cj`
- `markit/src/core/nodes/persistent_text.cj`
- `markit/src/core/document/persistent_document.cj`

在已有/Task02节点文件上追加：
- `node_codec.cj`：单记录 `copyShallow`、额外引用读/恢复；未更改整图 `clone` 语义。
- `node.cj`：protected raw override 读取 hook。
- `document_node.cj`：已有 setRawContent override 优先于读取 mutable append source，保证 explicit persistent snapshot raw 冻结。

独立新增测试：`tests/unit/persistent_tree_test.cj`，11 `PersistentTree` cases。
独立 effects/cache owner 结果见 [effects report](effects-report.md)。

## 存储与复杂度

- `RawSyntaxNode` 没有 mutable parent；payload 在进入/公开返回边界 clone；私有 immutable payload/children branch 可共享。
- children 使用二叉持久序列而非复制 root sibling 数组；单 sibling 替换 O(log siblingCount) 分支，ancestor path 依次更新。
- 版本 ID map 是不可变 AVL；替换旧子树 k 个记录、新子树 m 个记录只更新 k+m 和 ancestor IDs，单项 map O(log N)。无全树 index rebuild、全 map clone、tombstone 或跨版本 overlay链。
- parentId/childIndex 位于版本 map；旧 snapshot 的 raw/parent/path 不随新版本污染。aux references 图保持 detached typed materialization alias。
- 空间 bounds 缓存在 children 二叉分支。更新时只投影修改路径两侧的 min/max summary anchors 到实际 target source epoch；不归一未改子树里的所有 anchors。Before/After tie 取 minBefore/maxAfter，避免后续插入漏剪枝。
- `PersistentTextPayload` 是1024-byte上限UTF-8叶子的持久AVL。splice仅split触及叶子和join路径；未改segments用引用共享。文本树不包含HTML规则；后续renderer可用segments作render subunit，普通编辑不调用materialize/toHtml。
- 显式 legacy capture/export 允许 O(N)；capture uses HashMap ID memo，不把旧 `NodeCodec.clone` 当普通编辑实现。
- source resolve成本由03实现承担，04不声称冷跨历史映射O(log N)。位置查询与ID编辑分离；ID替换不全树rewrite offsets。

## 实际review发现与修复

- aux descendant替换误把aux root发布为document root：根据最终爬到的branch identity决定是否更新document rawRoot。
- aux入口已存在ID绕过校验：无条件调用校验helper，只有同raw引用允许合法回指，跨doc或不同record同ID拒绝。
- source store docId不匹配：public版本ctor发布前拒绝。
- 混合birth导致所有summary None退化：更新路径通过Source抽象解析targetEpoch summary，真实03 256siblings/128分散更新+range-call上限断言，保留未改raw引用。
- 同offset affinity区分：真实03插入回归覆盖。
- compile3 ctor实例helper访问早于全部field初始化：helper静态化并显式传docId。
- compile4 test宏中对接口值使用refEq：保留同一共享断言，改具体raw引用；compile5全项目编译exit0。

## 当前验证事实

- `git diff --check` exit0。
- effects/cache 独编与官方binary9/9通过，见独立报告。
- tree/source共享全项目编译的前几次失败日志由02保留 `../parallel-a-verification/integrated-compile-*.log`；该阶段尚未声明通过，最终结果见下文。
- 该阶段11tree测试和同O2 driver已准备；最终构建/执行均通过，见下文。runtime组合由05完成。

## Task05最小API

- `PersistentNodeCapture(codec).capture(legacyNode, sourceIdentity)`：显式legacy局部导入；不要每次传整doc。直接provider raw记录可使用 `RawSyntaxNode` 和opaque payload。
- `PersistentDocumentVersion(bundle, source: Some(editableStore))`，`raw/find/view/pathTo/nodesInByteRange/resolvedSpan`。
- `PersistentDocumentStore.snapshot/beginTransaction(expectedVersion)`；事务 `replace/commit(sourceVersion)/cancel`。替换会在暂存版本构造完后发布，无副作用污染旧版；过期publish拒绝。
- `PersistentTextPayload.fromNode` 已用于标准Text capture；`splice/segments/materializeNode`。raw/logical不同的原始raw另外保存，插件负责变换后的raw/source映射，不能猜marker。
- `TypedSyntaxPayload` 通过provider浅重建保留字段/metadata/source/render hooks，额外引用用稳定ID。公开legacy图每次独立。
- `OwnedEffectStore`、`OwnedEffectsTransaction`、`PersistentQuotaCache`、`SourceVersionRetention`详见effects报告。

## 明确边界

Task04不接parser/finalizer/runtime，不注册全部内置codec，不修HTMLInline构造点。Source版本强引用和lease机制已存在，但真实rope registry/prune/active anchor epoch与snapshot寿命接线由05实施。legacy模板保留SourceBuffer binding和冻结raw，不能把整图legacy capture变成每edit入口；新editing record需由provider使用source抽象/映射及局部payload。未验证1.1SDK、统计性能结论或用户延期的通用框架。

## 首轮tree执行与边界预期修复

compile5实际全项目编译exit0。11tree首跑10Passed/1Failed（0error）：mixed-birth查询预期4而实际5。经root、02、A reviewer独立核对Source冻结affinity与旧API inclusive交集，旧node252原[251,252]的endAfter252遇replace[252,253]后合法变253，故命中query[253,254]。测试现硬编码IDs[0,252,253,254,255]、starts[1,251,252,253,254]、ends[256,253,253,255,255]，逐真实resolve断言，并以257nodes小reference对照；reference后清counter再验证原<100局部调用门槛。未改产品、通用anchor规则或放宽阈值。首轮失败日志保留。

05需明确parser source span边界归属：legacy capture保存Before起点/After终点，owner边界替换可能使相邻anchor范围增长，这是通用affinity语义；插件重解析/源映射不能把cursor affinity自动等同不变lexical span归属。RawSyntaxNode构造允许provider显式给出正确affinity。


## 最终定向执行（真实）

- markit/ 的 cjpm test --no-run --no-progress 第六次共享构建：exit0；实际SDK 1.3.0-alpha.20260920003052、项目-O2。命令与构建输出由02保存在 parallel-a-verification/integrated-compile-6-{command.json,log}。
- 官方生成unit test binary直接console执行PersistentTree tag：11Passed、0Failed、0Error；同binary其它66例被tag filter跳过，exit0（框架28.56ms，功能运行时间，不是统计性能结论）。日志 parallel-a-verification/persistent-tree-test-2.log。
- 新mixedbirth case真实rope source逐endpoint/ID参考和<100调用断言均通过，旧raw引用共享断言通过。
- 当时全27包回归与O2小记录仍pending；最终均已通过，见下节。

## 完整回归与同 O2 操作记录（真实完成）

- `cjpm test --no-run --no-progress` 最终编译 exit0。
- 官方生成的27个 test binaries 直接console执行：632 Passed、0 Skipped、0 Error、0 Failed，全部package exit0。证据：[全包summary](../task01-baseline/parallel-a-full-console-1/summary.json)。
- 独立性能driver编译 `cjc local-edit-time.cj -O2 --static-std -Woff unused ...` exit0；运行exit0。精确import/link flags在 `timing-compile-args.json`，静态输入SHA256在 `timing-inputs.json`，driver源码与exe hash在 `timing-driver-hashes.json`。
- 实际SDK：`1.3.0-alpha.20260920003052 (cjnative)`，`x86_64-w64-mingw32`；没有运行或声称最低1.1兼容。
- 原始输出 `local-edit-time.csv` 保留正序(local→full)及反序(full→local)各一轮。每轮计时后都验证完整结果；tree逐payload对照fresh值并断言未改raw引用共享，text对照完整预期String。所有断言通过。

| 场景 | edits | local ms：正序 / 反序 | full/fresh ms：正序 / 反序 |
|---|---:|---:|---:|
| 4096 sibling raw tree | 120 | 0.4918 / 0.2666 | 466.5563 / 422.7291 |
| 16 KiB logical Text | 400 | 0.3185 / 0.3206 | 0.7749 / 0.7890 |
| 256 KiB logical Text | 400 | 0.3610 / 0.8438 | 62.7084 / 37.3172 |
| 1 MiB logical Text | 400 | 1.0410 / 0.9214 | 208.2733 / 211.9955 |

这只是同一个最终-O2程序中的最小操作对照：tree比较局部索引/child-path替换与fresh完整raw/index重建；Text比较内部splice与完整String替换。它不证明整个Markdown parser/render/worker性能，不是统计无退化结论，没有扩展用户延期的benchmark框架。

最终产品与11tree/9effects tests已冻结。root已实际审查源码、定向/全包及同O2证据，验收Task04当前范围；**Status: Done**。Task05真实runtime/source/effects事务与生命周期接线边界仍保留。
