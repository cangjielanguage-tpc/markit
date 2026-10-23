# Task01 legacy 子任务实际结果

更新：2026-10-23。交付由 Task01 owner 的共享构建与官方测试 executable console 模式执行验证；不使用被本机 IPC socket 拒绝的 cjpm runner 结果冒充通过。

## 改动与范围

- 新增 `markit/src/tests/utils/editing_legacy_fixture.cj`：30 内置插件/bundle/config fixture，真实旧式第三方双 parser 扩展，独立 duplicate-ID、byte/rune 坐标及 opt-in 字面映射检查。
- 新增 `markit/src/tests/unit/editing_legacy_baseline_test.cj`：5 个测试案例，实际执行 37 个 fixture 的四输入模式。
- 本目录保留暂存源码、[30 插件源码清单](inventory.json)、[148 条真实观察](observations.json)、[逐组归纳](summary.json)、[语义与纠错表](known-corrections.md)、[冻结源码身份](third-party-source-freeze.json)。未改生产 parser/core/CLI/kit/extension、README 进度或 Git 提交。

## 实际验证

- 首轮源码编译记录了 `quote` 为仓颉保留字的失败；已改变量名为 `quoteNode`，失败日志保留于 `../task01-baseline/new-facilities-compile-2.log`。
- 后续实际共享编译成功；`markit.tests.unit.exe --no-progress --no-color --include-tags=EditingOracle --show-all-output`：**exit 0，23 个选中测试通过**（本子任务 5 + oracle 子任务 18），27 个原 unit 测试被本次 tag filter 排除，未把它们当作本次通过。
- 真实执行命令、binary hash、exit/counts 保存在 `../task01-baseline/editing-oracle-console/results.json`；[原始 log](../task01-baseline/editing-oracle-console/markit.tests.unit.log) 共 148 条 `EDITING_LEGACY_RESULT`。
- `python summarize_legacy.py ../task01-baseline/editing-oracle-console/markit.tests.unit.log`（从本目录运行）：exit 0。精确验证 **37 fixture /148 record /4 distinct modes**。最终 HTML/Markdown/Typst/AST JSON/tree 在每组四模式全部一致，3 组 emittedHtml 差异均保留；protected inline HTML 的重复 ID2 在四模式都由独立不变量检出，未 skip。
- 归纳工具的显式 synthetic 截断负例：只有首组四模式时 exit 1 拒绝，见 [selftest](summarizer-selftest.json)。它只证明报告工具拒绝不完整输入，不是 parser 或性能结果。
- 坐标/映射负例实际运行通过；当前修正过的 quote 中文 emoji 叶节点 byte10..17/rune10..12 与原文片段一致。

## 冻结的第三方源码

`EditingLegacyNoticePlugin` 注册两个真正消费 `~note ` / `!note ` 行并生成 typed TextNode 的 leaf parser，不含任何编辑能力声明。四模式对 `~note 甲😀\r\n!note second` 都生成两个 top-level 节点，三格式输出均为 `甲😀second`。

- 编译源码文件 SHA-256：`31837f5064696fa3477d8631b4799f102594f989b32c107259880deafbba9642`。
- 测试源码 SHA-256：`ef6123912759b2d9d08a9ad4a53432134c208b9b1b20f144556c35c02fbf9104`。
- Task02 必须用相同源码证明默认方法兼容，不为新协议修改 fixture。混合支持/不支持 parser、缺 facet、已证明隔离/未知副作用变体写入其他新 fixture。当前仍未接入生产 editing，不把 parse/append 当 editing 通过。

## 仍需协调者保留的缺口

- 本机实测编译器是 **1.3.0-alpha**；正式最低版 **1.1.0 未验证**，不能以 alpha/beta 或源码声明替代。最低版本不提升。
- protected HTML 重复 ID 是已定位、已检测的现有基础设施缺陷，交04/08精确修正；最终状态不得继续容忍此重复。
- legacy emittedHtml 在 reference finalizer/AutoAnchor 上不等于最终渲染；新 worker/patch 必须补完整事务链。
- 本子任务没有生产 editing adapter、生产工作量或性能通过声明；同-O2 batch 门槛由独立性能子任务提供，Task01 owner/root 完整审查前不能释放02。
