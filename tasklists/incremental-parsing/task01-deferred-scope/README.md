# Deferred by user scope — 2026-10-23

按用户最新裁剪停止通用oracle/计数/benchmark框架扩展。这里仅保存本次创建的三份未跟踪测试源码；没有用户或生产文件被移动，全部可恢复，SHA256见move-manifest.json。

已有18工具自测、5legacy及完整592测试结果保留其真实时间/源码/binary证据。developer @Bench独立与正式集成运行均失败exit3，包含 `F Check failed: module != nullptr`；该项延期，不写Passed。移动后没有再次运行测试，遵守停止额外回归的指令。

后继产品任务不需要恢复或接入本框架。已通过的最小legacy/第三方fixture保留在原tests路径；最小-O2 parse driver和已有实测数据留在task01-performance。
