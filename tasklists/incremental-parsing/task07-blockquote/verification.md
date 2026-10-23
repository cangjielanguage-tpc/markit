# Blockquote 最小验证交接

更新：2026-10-23。

- `source-hashes.json`：当前独占产品源和测试源 SHA256，随必要修复更新。
- 静态核对：matcher 与原 stripMarker/startsOuterBlock 判定等价；只有 editing 分支使用物理 span，batch synthetic 逻辑保留。
- 静态核对：normal child splice 不调用 `materializeLegacy(quote)`，未变兄弟不进入 parser；recursive nested plan 先向下定位，再只读取目标子块窗口。
- `git diff --check -- markit/src/plugins/standard/block/blockquote markit/src/tests/unit/task07_blockquote_editing_test.cj`：exit 0，无空白错误；这不是 compiler/runtime 验证。
- 待执行（非 Passed）：由 02 唯一编译 owner 按现有 integrated compile 流程编译后，官方测试 tag `BlockquoteEditing` / `StandardEditing`。包括新增 Task07BlockquoteEditingTests 的 7 测试。
- 待执行：同配置全量回归、实际 frozen oracle、原 driver 同 `-O2`。按用户范围不增加通用框架或最低版 SDK 环境。
- `task07-core/blockquote-compile-10.log`：首轮真实类型检查 exit 1；9 errors/8 printed 均为局部变量名 `quote` 与语言关键字冲突，已等价改名 `quotedNode`。同窗将 QuoteRawNewline 的 source field 改成实际 getter 实现，保持接口语义。保留失败证据，不计 Passed。
- 当前结果不得写为 Done：产品源码尚待官方 compiler/runtime 实证；长 Paragraph mapped candidate、mapped raw view 及 quote ancestor payload 更新已接，04 shared 源已落，等待 02 重新类型编译与官方测试。

## 实质待闭合：同 batch 多处编辑

- 静态发现 DSession 逐 dirty range recover 后按 unit.nodeId/ancestor 去重，仅保留首个 unit。quote 当前把后代恢复委托到 outer quote，其 child plan 只含单次 editStart/editEnd；同 batch 两个 quote 子段编辑会丢第二个计划，同 paragraph 多 range 同类。
- 已报 root 与 04，请共享 owner 冻结完整 dirty range 输入或等价的多单位合并策略；quote 需对真实受影响子段生成多个 child/raw splice，不以整个 quote 常规重 parse 代替未变兄弟复用。
- 现有 7 项测试是单 edit，未宣称此 batch 门槛通过。无权限拒绝/执行不确定：这是明确产品接口缺口，未擅改 core。
