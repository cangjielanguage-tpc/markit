# Task02 产品接口交付与验证

日期：2026-10-23。状态：root已审查通过用户修订范围，03/04可依赖本交接并发实现。

## 实际产品改动

- `markit/src/core/editing/{editing_contracts,editable_source_contracts,editing_tree_contracts}.cj`：编辑策略/版本/checkpoint、源与坐标/映射、持久树/typed payload/owner effects抽象。该包只依赖std，不反向依赖nodes/source/session具体包。checkpoint含documentId/owner/sourceVersion且clone payload。
- `core/block`三种parser与`core/inline/inline_parser.cj`：安全默认关闭增量，facet及隔离证明默认None，旧第三方无新增抽象义务。
- `core/plugin/{editing_capability_plan,plugin_registry,plugin_registrar}.cj`及`markit.cj`：显式按需能力计划、逐parser缺失诊断、完整provider/owner检查、安全fallback聚合、phase DAG、配置身份边界；未知配置cacheable=false。Strict拒绝不消费待注册默认bundle，不调用provider或变更source/ID/state/patch。库存排序不替代旧bucket调度。
- `core/nodes/{node,node_codec}.cj`：无反向插件依赖的provider注册与lossless typed图重建、三metadata/source/raw/hooks复制、TOC额外引用及别名处理。未知typed节点拒绝。整图clone仅显式原型/legacy桥，不允许未来编辑热路径每次整树调用。
- `core/session/session_state.cj`：旧name-only snapshot保留原字段存储；显式Restorable派生类型才持真实detached payload/version/context，默认restore安全拒绝。

## 实际验证

当前工具链：Cangjie Compiler `1.3.0-alpha.20260920003052` / cjpm `1.3.0-alpha.05`，Windows x86_64。机器记录沿用Task01实际环境：Intel Core i7-8700、12 logical CPUs、约32GB RAM、Windows build26100。

| 检查 | 实际命令 | 结果 | 证据 |
|---|---|---|---|
| 最终集成编译 | `cjpm test --no-run --no-progress`，cwd=`markit/` | exit0 | `integrated-compile-4.log` |
| 接口/能力/值 | 官方`markit.tests.unit.exe --no-progress --no-color --include-tags=EditingContracts --show-all-output` | 19通过、0失败/错误；38项tag未选中 | `editing-contracts-test-2.log` |
| 真实typed codec | 同官方binary，`--include-tags=TypedCodecPrototype --show-all-output` | 6通过、0失败/错误；51项tag未选中 | `typed-codec-test-1.log`；最终全套亦含这6项 |
| 完整回归 | `python tasklists/incremental-parsing/task01-baseline/run-legacy-console.py --output-name task02-full-console-1` | 27包全部exit0，599通过、0失败/错误/跳过 | `../task01-baseline/task02-full-console-1/summary.json`及每包原始输出 |
| patch格式 | `git diff --check` | exit0 | 实际命令完成结果；未commit/push |

原`cjpm`运行测试的TCP10013环境失败与官方console路径分栏保留，不修改或模拟框架。最终599结果来自真实官方测试binary。

## 简明同-O2用时记录

复用既有冻结`batch_driver.cj`（SHA256 `b0e9d11bd5b547949e8f91ff52985eee1bbbf80208e5b1c0921e514a2ec26be9`）及同SDK。旧参考`batch_driver_v2_long_block.exe` SHA256 `1cf4fc98cdc947fa17e1aa971a3e360eaf6b7d5039fd064ecb64f38d5dff7627`；候选SHA256 `d24c8b282c8cedb1976f31f1bb8a0416e38b6e2a4970dacd7950ab0cea0f9cd8`。候选构建使用现有`task01-performance/build-driver.ps1 -OutputDirectory <task01-performance/candidate-task02-product>`，未覆盖参考库或binary。

每个进程84样本、每组API/size21样本，四次进程均exit0。仅计parse区域，保留原driver预热与GC边界，没有加入新框架。

| 顺序 | 场景 | reference mean | candidate mean |
|---|---|---|---|
| reference→candidate | small String | 25.919us | 29.871us |
| reference→candidate | small InputStream | 27.319us | 30.793us |
| reference→candidate | large String | 27.580ms | 27.251ms |
| reference→candidate | large InputStream | 27.261ms | 28.010ms |
| candidate→reference | small String | 27.706us | 27.193us |
| candidate→reference | small InputStream | 29.677us | 29.609us |
| candidate→reference | large String | 27.838ms | 28.028ms |
| candidate→reference | large InputStream | 28.210ms | 28.345ms |

首轮small偏慢在反向未保持，现有简明记录不能区分顺序/调度噪声，**不是统计无退化或零成本证明**。后续用同driver/SDK/输入复测，不删原数据、不擅设允许回退百分比。原始四份stdout CSV、stderr和两份JSON位于本目录：`batch-time-comparison.json`、`batch-time-comparison-reverse.json`等。用户已取消大统计/分配/RSS门槛，不继续扩大基线设施。

## 审查修正与限制

- 初次集成编译因enum缺相等及构造期间实例helper访问失败；第二轮因`None`与Option构造子歧义失败；已修Equatable/static helper并将新variant命名NoFallback。原日志保留。
- 一项新测试以factory闭包存在推断empty配置必产Paragraph，实测越界；读取BlockTreeBuilder/IncrementalSession后确认paragraph非空gate，root撤回该前提，已移除phantom登记并与fresh真实空结果对照。旧生产调度未改变。
- 用户只读stdlib源码已选择性读取，ArrayList.toArray是分配复制、String.size为缓存byte长度；完整选择性说明见`../stdlib-performance-notes.md`。该checkout版本与安装1.3-alpha不一致，源码结论不冒充二进制保证。
- 正式1.1.0项目验证由用户取消本轮门槛，不声称通过，不改变项目声明版本；不用其SDK故障阻塞产品。通用oracle/计数/benchmark扩展同样不再依赖。
- 本任务完成公共契约与最小真实原型，不声称生产文内editing已交付。30个内置插件仍0/30真实增量适配；默认安全fallback只为外部第三方兼容，后续07–13必须完成内置适配。
- 03/04按`../task02-ownership.md`互斥实现；共享接口缺口回到02串行处理。Task16验证后停下等待用户验收，不开始17/18、不提交推送。
