# Task03 handoff

状态：Done。产品、定向测试与共享回归均通过，root 已实际审阅当前范围证据并验收；产品与测试文件冻结。没有 commit/push，没有改变 core/editing 契约或 Task04 文件。Task05 放行前不开展后继实现。

## 文件与执行

只新增 `core/source/editable_rope.cj`、`editable_source.cj`、`editable_source_map.cj` 和 `src/tests/unit/source/editable_source{,_map}_tests.cj`。产品为持久 AVL rope（叶最多 1024 byte）、Unicode/line 索引、CRLF 跨叶 split/join、原子原坐标 batch、snapshot、anchor delta 与通用组合映射。冻结 hash 在 `frozen-source.json`。

Task02 owner 使用最终 core/editing cjo 独立编译 source-package-3，exit 0；以官方 `cjc --test -O2 --static-std` 链接两新测试文件，exit 0；官方 test binary console 实跑 13/13 Passed，0 skip/error/fail，exit 0（0.625s）。精确参数在 `source-compile-3-args.json`、`source-tests-compile-3-args.json`，实际日志 `source-compile-3.log`、`source-tests-compile-3.log`、`source-targeted-test-3.log`。

最终共享 `cjpm test --no-run --no-progress` compile6 exit 0，见 [共享编译日志](../parallel-a-verification/integrated-compile-6.log)。27 包官方 binary console 全量实跑 632/632 Passed，0 skipped/error/failed，所有 package exit 0；其中 source 21/21（含新增 13）、Streaming 15/15。见 [全量 summary](../task01-baseline/parallel-a-full-console-1/summary.json)、[source 日志](../task01-baseline/parallel-a-full-console-1/markit.tests.unit.source.log)、[Streaming 日志](../task01-baseline/parallel-a-full-console-1/markit.tests.unit.streaming.log)。共享 gate 已关闭，历史失败保留但不再是当前阻断。

13 个 case 包含 Unicode 坐标、CRLF 中点与跨叶单删 CR/LF、删中间 X 新配对/插 X 拆开、旧 snapshot、batch 同点稳定序、非法 UTF 半点/过期原子拒绝、120 次局部编辑 fresh 文本/坐标、200 次古老 anchor 逐 edit 仅新增 1 batch、2048 cache 硬上限、删除 clamp 后旧 target 回访，以及 map 裁剪/normalize/组合/synthetic/Array 隔离。

同 SDK `1.3.0-alpha.20260920003052`、同 O2 的 driver 最终编译/运行均 exit 0，参数 `timing-final-compile-args.json`、结果 `local-edit-time-final.csv`。400 次替换：16 KiB rope 1.748/1.800 ms，string 6.536/41.208 ms；256 KiB rope 2.822/5.438 ms，string 45.808/83.392 ms；1 MiB rope 7.679/4.049 ms，string 240.068/255.121 ms。正反顺序均精确校验 expected 文本；噪声明确保留，不作统计无退化结论。

首次共享 compile 因 source 包 `None` 同名导致 cache slot 类型推断错误 exit 1，已显式 `Option<RopeAnchorKey>.None` 修复。失败日志保留在 `../parallel-a-verification/integrated-compile-2.log`，最终独编/测试已验证该修复。

## 05 消费边界

- 使用 `EditableRopeStore(documentId, text: ..., version: ...)`，`current` 返回冻结 `EditableSourceVersion`，`snapshot` 为具体版本。所有编辑先验证 batch，再发布一次 version；空 batch 不增 version。
- source 被接受后不随 parse/render 取消回滚；05 应独立管理 parse commit。
- 定位 O(log L+B)，返回 slice/line 另付输出规模。store 不保全历史 roots，旧版本由持有者 pin；文本/叶不被后续编辑修改。
- anchor cache 为 store 内 2048 条整数 key/环形 FIFO；docID 先验证。常用单调 target 从上次投影重放新增 edits；冷查、历史 target、淘汰抖动仍 O(跨历史 edits)。历史回访从出生 epoch 重新计算，不从已删除 clamp 的新投影逆推。
- 04 已用修改路径 project summary 处理 mixed birth epochs，位置查询只解析二分 bounds/候选，不因混合 epoch 下探整片子树；source 冷 anchor 的历史成本仍如上披露。
- delta history 当前 O(累计 edits)，尚无 prune。04 提供 source version lease，但 05 需要结合实际 active raw-node birth epochs 和用户 anchors 决定安全回收，不能每 edit 全 N 重基或声称历史已回收。
- mapped text builder 仅处理调用者给定 spans/变换；source 层不识别 Markdown markers，组合 map 保留多个来源段。synthetic 无唯一 raw 来源时 mapByte 为 None。

完整实现路径与复杂度论证见 `implementation.md`。README/共享 verification 由 root 维护。
