# Task01 最小基线交接（用户修订范围）

Task01 Done，等待root审查；不继续扩展基线、最低SDK或通用测试框架。

- 实际工具链：Cangjie1.3.0-alpha.20260920003052 / cjpm1.3.0-alpha.05，Windows x86_64；i7-8700 / 12逻辑CPU / 34123063296 bytes物理内存。
- 当前源代码基线：c510aee2e5bbbdb04402cb26bbca6679515a16f4；用户产品源码未被本任务修改。
- 最小实际parse-only driver：[batch_driver.cj](../task01-performance/batch_driver.cj)；真实构建脚本[build-driver.ps1](../task01-performance/build-driver.ps1)及compiler-args.json记录同-O2编译参数。后继只需同工具链/输入/优化级别做自己的最小比较，不强制接通已有通用统计工程。
- 已测值：小120 bytes String/Stream median25.467/26.916us，大62462 bytes median27.784/27.844ms；12进程1008样本。输入在timed region前构造，真实公开parse创建session，渲染和CLI启动不在其中；不是editing结果。
- 完整实际参数与限制：[v2报告](../task01-performance/baseline-v2-long-block-20261023/evidence-report.md)。系统背景CPU26–40.6%等限制保留，不能跨SDK当产品回归结论。
- 已有回归：原569pass，新设施当时592pass，扩展73项67pass6原有skip；[全部汇总](new-facilities-full-console/summary.json)。新通用源码收起后的树未重测，遵守停止额外回归的指令。
- 后继可直接用[148条四模式报告](../task01-legacy/report.md)和[纠错表](../task01-legacy/known-corrections.md)。最小legacy/第三方fixture保留src；大框架[可恢复延期清单](../task01-deferred-scope/move-manifest.json)不作为交付依赖。
- 未完成项：developer @Bench运行exit3、正式最低SDK项目验证未执行，均 Deferred by user scope，不伪称Passed，不阻塞产品Task02。
