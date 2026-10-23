# Task07-P Blockquote 产品实现

更新：2026-10-23。状态：源码已落盘；等待唯一编译 owner 02 集成验证，尚未宣称通过。

## 独占范围与输入

- 仅写 `markit/src/plugins/standard/block/blockquote/**`、新增 `markit/src/tests/unit/task07_blockquote_editing_test.cj` 与本证据目录。
- 已读适用 README 顶部裁剪、07、00-design-locks、Standard/CommonMark Blockquote/Paragraph 验收及 aceharness-tasklist 技能；未发现适用 AGENTS.md（仅 node_modules 下存在无关 AGENTS）。
- 未修改 core、shared standard/editing、Paragraph、Heading、ReferenceLink 或全局进度表；未启动 compiler/shared target，未提交/推送。

## 已实现

- 原 marker、三列缩进、lazy continuation/outer-start 判定抽为同一 matcher，batch 与 editing 共用。
- BlockquoteState 提供深复制 SourceLine 集合的 RestorableBlockState；公开构造签名保留。
- EditingBlockquoteNode 保留真实类型与恢复记录，BlockquoteNodeCodec 只接受真实 Blockquote 类型，浅重建保持 immutable ID、raw、metadata 与 source binding 由 NodeCodec 统一复制。
- editing 沿剥前缀的物理 SourceLine.span 调用原 parseDetachedLines；末行 terminated=false 保留原 synthetic 语义。batch 原 synthetic 解析路径保留。
- shared StandardMappedRecoveryCarrier/router 将子 Paragraph/Heading 恢复委托到最外层 quote，避免 synthetic checkpoint 直接恢复。
- 普通正文编辑递归选择最深 quote 的受影响子块，按其真实物理行窗口及嵌套 stripDepth 建输入，通过 BlockChildrenEdit 更新对应 parent，不投影未变兄弟。
- Heading aware restore/revoke/defer/rebase/payload update 接口接入实际新子树；未变子树效果不被 blanket revoke。
- quote entry 在 finalize 前、解析 children 前重新 capture，避免 continuation tryStart 早于 kernel.flush 时把前一 pending paragraph 带回恢复。
- quote 本体也保留不可变 mapped raw view：顶层保留 physical CRLF，nested quote 去祖先 marker 并规范化 LF。普通正文变化仅沿 quote ancestor 路径更新 payload/view 实际字节 splice，不取整个 quote 字符串；旧 snapshot 继续持有旧 view。

## 当前待验证与集成点

- 7 项最小测试源码覆盖共用 matcher、Unicode 物理 span、state/typed codec、真实多层 quote 局部 splice、Heading parser spy 0 次、旧 snapshot、separator 与首 marker 删除后的前段合并、32KiB 单行 quote 中 Paragraph ID 保留及实际 fresh HTML/tree 对照。
- 04 的 `registerParagraphEditingCodecs(codec)`、Paragraph/SoftBreak facet 和 mapped raw scope 已落；02 正在统一类型编译，未自行启动 shared target。
- 已接 04 冻结的 `tryParseMappedParagraphUnit(context, childRaw, editStart, editEnd)`：先尝试持久 mapped inline candidate 更新，None 才调用子块完整 grammar。入口实现与官方执行仍待 04/02，不声称已通过该门槛。
- normal recover 不调用 `lineAt/context.lines`，避免在 Paragraph 局部入口前导出整条巨长行；用 byteAtLineColumn 定位物理行，source.readByte 与同一 matcher 内核检查行前缀。真实结构恢复才物化 selected child SourceLine。
- marker/外部边界变化传播已新增实际 fresh 测试源码：当前行不再属于 quote 时恢复前邻可恢复单位并重新解析后缀；只有实际 quote ownership 变化才触发后缀传播。仍待执行，不作为普通正文路径验收证据。

## stdlib 实证

选择性读取用户只读 `stdlib/libs/std/core/string.cj` 的 sliceUnchecked/range 与 string_builder.cj append。sliceUnchecked 通过 Array<Byte> 构造 String；据此仅切选中行前缀，未在普通子块编辑必经路径调用全文取字串。映射 raw 使用按行二分起点及 StringBuilder；不重复 rune/UTF8 整文转换。源码树与执行 SDK 的版本对应未证明，不作版本兼容保证。
