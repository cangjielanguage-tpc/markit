# Task03 source 实施记录

更新：2026-10-23。最终 13 个 source/map 定向 case、同 O2 计时与共享回归已通过；root 已实际审阅当前范围证据并验收。Task03 状态 Done，产品与测试文件保持冻结。

## 产品文件

- `markit/src/core/source/editable_rope.cj`：不可变 AVL rope，UTF-8 scalar 对齐、最多 1024 byte 的独立叶；聚合 byte/rune/UTF-16、换行数、首 LF/尾 CR 和末行 UTF-16 长度。split/join 只复制路径和有界边界叶。
- `editable_source.cj`：实现冻结 `EditableSourceVersion`/`EditableSourceStore`，坐标查询、line/column、按原版本坐标原子 batch、历史 snapshot 和双向 anchor delta。store 发布后 source 独立于 parse 的取消；history 只保留 delta，不全局保留历史根。固定 2048 条 anchor 投影缓存复用单调目标的前次投影，仅重放新增 batch；整数 key+环形 FIFO，无 String 拼 key 或队首删除。
- `editable_source_map.cj`：通用片段 map、组合 map、mapped text builder；去前缀、去缩进由调用者选择范围，source 层不识别 Markdown marker。非唯一 synthetic/非线性内部点不伪造真实 anchor；span 保留多段 provenance。
- `markit/src/tests/unit/source/editable_source_tests.cj`：8 个 source 定向 case（含 2 个 cache 热路径/旧目标回访测试）。
- `editable_source_map_tests.cj`：5 个 map 定向 case。

所有 core/editing 冻结契约、tree、document、session、runtime 均未改动。旧 append `SourceBuffer` 路径保留；Task05 串行接入真实 editable source。

## 最小复杂度证据

令 N 为当前 source byte 数，L 为叶数，B=1024 byte，k 为返回内容长度，m 为插入 byte 数。AVL 路径高度 O(log L)，所有叶构造/解码扫描受 B 限制；超大输入在构造时拆成独立叶，不保留大 backing slice。

- byte/rune/UTF-16 定位及 line 起点：O(log L+B)。lineAt 另外复制该行返回内容；sliceBytes 为 O(log L+k)。
- 局部 replace：两次 persistent split 与 join，边界叶复制 O(B)，插入构建成本取决于 m；未改子树共享，不 materialize/toArray/toRuneArray 全文。
- 批 edit：先转换并验证全部端点，再从尾向头替换；空 batch 不生成版本；同点零长插入保留数组顺序。
- CRLF aggregate 在 branch join 时减去重复换行；nth line 定位处理跨 branch CRLF 的真实结束 byte。raw offsets 可删单独 CR/LF；CRLF 中点的 line/column 返回 -1。
- 冷 anchor resolve 成本与跨越的 edit delta 数有关，为 O(跨越的 edit 数量)，反向投影每个 batch 另构造 inverse delta 数组，不遍历或重写语法节点。缓存命中且 target 单调时只重放前次 target 后的新增 edits，常规逐 edit 重复二分 bounds 查询不再从出生 epoch 重放。缓存空间硬上限 2048；目标回退从 birth 重新计算且不覆盖较新投影，首次逆向查询不 seed 前向缓存，避免删除 clamp 的不可逆信息损失。冷查、跳跃访问和淘汰抖动仍可能付出历史成本。
- 旧 snapshot 根由持有者保留，store 不收集全部根。当前 store 生存期内保留全部 delta、未提供 history prune；历史内存 O(已接受 edit 数量)，不是所有 anchor 操作 O(log N) 或任意长会话内存恒定的实现。session 级历史回收策略留后续集成按真实 anchor 生存期决定。

这些为代码路径/结构论证，不是通用计数框架或统计性能无退化声明。map 组合的成本与查询跨越的映射片段、组合层数有关。

## 已执行命令

`cjc -p markit/src/core/source --output-type staticlib --import-path tasklists/incremental-parsing/task02-contracts -O2 -Woff unused -o tasklists/incremental-parsing/task03-source/source-package`

- exit 0，日志 `source-compile-1.log`。该独立语法检查使用 Task02 早期冻结 cjo；最终统一编译由 Task02 owner 用最终依赖复核。
- 最终 frozen core/editing 下独立 source compile 0，args/log 见 `source-compile-2-args.json`、`source-compile-2.log`。
- 官方 `--test -O2 --static-std` 定向 test binary 编译 0，11/11 Passed，0 skipped/error/failed，exit 0，见 `source-tests-compile-1-args.json`、`source-targeted-test-1.log`。
- 增补删除 CR 与 LF 中间 X 形成 CRLF、再插 X 拆开断言后，官方 binary 重编 exit 0，复跑 11/11 Passed，0 skipped/error/failed，exit 0，0.444s，见 `source-tests-compile-2.log`、`source-targeted-test-2.log`。
- 加入 anchor cache 后首次共享编译 exit 1，原因是未限定 `None` 被绑定为 source 包的 `SourceRetentionMode.None`，日志 `../parallel-a-verification/integrated-compile-2.log`；已改显式 `Option<RopeAnchorKey>.None`，失败证据保留。
- 最终 source 包独编 exit 0、官方 test binary 编译 exit 0，实际 13/13 Passed，0 skipped/error/failed，exit 0，0.625s，见 `source-compile-3.log`、`source-tests-compile-3.log`、`source-targeted-test-3.log`。新增测试实际验证连续 200 次编辑每次只重放 1 batch、同目标重复无新重放、容量 2048，以及删除 clamp 后旧目标回访不污染新目标。
- 最终共享 `cjpm test --no-run --no-progress` compile6 exit 0，见 [共享编译日志](../parallel-a-verification/integrated-compile-6.log)。全量 27 包官方 binary console 实跑 632/632 Passed，0 skipped/error/failed，27 个 package exit 均为 0；其中 source 21/21（含新增 13）、Streaming 15/15。见 [全量 summary](../task01-baseline/parallel-a-full-console-1/summary.json)、[source 日志](../task01-baseline/parallel-a-full-console-1/markit.tests.unit.source.log)、[Streaming 日志](../task01-baseline/parallel-a-full-console-1/markit.tests.unit.streaming.log)。历史 compile 失败已修复并被最终结果覆盖，不再是当前 gate。

## Task04/05 交接边界

04 确认每个 raw node 保留出生 epoch 的 `SourceAnchor`；版本壳强持 `EditableSourceVersion`，其 `SourceVersionRetention`/lease 约束存活引用。ID 查询/局部替换不 resolve anchor；04 已修复 mixed epoch 范围查询，修改路径生成 project summary，位置范围查询解析二分 bounds 与候选，不因 epoch 混合下探整片子树。typed legacy 全图是显式 O(N) 请求。source 冷 anchor/cache 淘汰仍按上述历史成本计。

root 已批准并落地固定容量投影缓存；同一常用古老 anchor 的单调目标查询只重放新增 batch，新增定向计数测试要求连续 200 次编辑每次仅重放 1 batch，同目标重复查询不再重放。05 必须按 active anchors/source leases 确定安全历史回收点，不能每 edit 全 N 重写 anchor，也不能声称当前历史已经可任意 prune。

## 同 O2 最小计时

`cjc` 1.3.0-alpha.20260920003052，cjnative/x86_64-w64-mingw32；静态 source 包和 driver 同 `-O2`。初版精确编译参数见 `timing-compile-args.json`；最终版改链接 `source-package-3`，参数见 `timing-final-compile-args.json`。两次 driver 编译 exit 0、运行 exit 0，原始结果均保留。每种 N 各做 400 次单 byte 替换，rope 先和 string 先各一次；输入创建与最终全文校验均在计时区外。每样本输出精确匹配独立 expected byte 数组。

| N (byte) | rope 两次 (ms) | string reference 两次 (ms) | 编辑后 rope height |
|---:|---:|---:|---:|
| 16,384 | 1.748 / 1.800 | 6.536 / 41.208 | 12 |
| 262,144 | 2.822 / 5.438 | 45.808 / 83.392 | 13 |
| 1,048,576 | 7.679 / 4.049 | 240.068 / 255.121 | 13 |

表为最终 `local-edit-time-final.csv`，旧 `local-edit-time.csv` 保留。记录支持该局部路径没有随全文大小进行字符串复制；样本明显有噪声，未做分位/显著性或统计无退化结论。表仅是本机本次最小实测。

## 验收结果

最终 shared frozen core/editing 编译及官方 console 的新旧 source/legacy/Streaming 回归均通过，root 当前范围验收完成，Task03 Done。产品与测试保持 `frozen-source.json` 对应内容；Task05 放行前不开展后继实现。delta history prune 仍是上述真实集成边界，不因本任务完成宣称已实现。
