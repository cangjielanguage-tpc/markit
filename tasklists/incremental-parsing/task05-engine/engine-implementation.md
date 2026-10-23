# Task05 主引擎实施记录

Status: Done，2026-10-23。所有最终sharedtarget构建由02串行执行；阶段编译不等于最终运行。

## 实际产品接口

- `Markit.createEditingSession(documentId,text,codec,policy)`：先检查runtime capability与真正`BlockEditingFacet`执行接口。Strict缺执行facet/未知hook在创建source前拒绝。Compat用明确Session fallback。
- `DocumentEditingSession.applyEdits`立即确认真实rope source；`flush`独立计算并以epoch/sourceVersion最终护栏拒绝取消/过期任务。busy guard从provider checkpoint前到完整finally，防snapshot回调重入flush。
- `BlockRecoveryUnit`由provider提供稳定owner/nodeID、raw anchors、完整session+kernel checkpoint、facet payload、映射版本及nested context。core没有Markdown marker/kind/plugin边界表。
- 共享`BlockParsingKernel`供旧append、detached/batch和恢复调用。同步sink保持ClosedAndReprocess的finalize→emit→reprocess顺序；stream结束后清sink，避免保留上一update及HTML。
- 修改单位仅局部`PersistentNodeCapture`；siblings插删走持久splice。语法收敛与effects真读者传播分开，semantic lookup使用新prepared tree，删除单位所有owner贡献撤销。
- 所有provider/codec调用及patch构造先完成；tree/effects都validate后无provider callback install，最后单snapshot指针发布。失败丢弃暂存，accepted source保留。

## 兼容出口

未知外部derived Node无法无损通用clone。Session fallback保留每次真实fresh parse的完整独立`DocumentSnapshot`/typed graph，含额外引用及typed render hooks，不要求旧plugin实现codec、不降plain Node。`EditingDocumentSnapshot.fallbackScope/fallbackReason`明确模式，fallback从`legacySnapshot`读取完整旧API图；`tree`在该模式明确拒绝。新旧版本引擎不相互修改legacy graph，但按旧API可变的外部图不声称能撤销任意外部闭包修改。

## 生命周期与限制

真实source roots由immutable rope view强持，warm正常编辑无全文slice/append。快照pin实际`earliestAnchorVersion`（含aux）；inflight恢复额外pincheckpoint/mapping/anchor epoch并finally释放。对无法证明payload不持更老epoch的provider，`retainsOnlyRawBirthEpochs=false`默认保守pin初始history至close。只有显式声明true的provider可按raw floor释放；因此unknown provider不声称历史已回收。

测试 EngineFacet 的 opaque container checkpoint 仍可能是 birth 0，因此其声明已改为保守 false；本会话不作为 raw-only pruning 证明。实际 source/store floor 推进证据单独保留在 source 8 个用例中。后续真实 provider 必须诚实维护 checkpoint/mapping 的 epoch 声明。

## 显式 raw 导出边界

首轮 nested fresh 对照检出祖先 source-derived rawContent 被捕获为旧 override。修正采用 codec 显式 `rawContentFollowsSource` 声明，默认 false；还必须证明节点未设置显式 raw override，且 SourceBuffer 绑定 capture 的实际 document/version。只有具备这份证据的内容可在显式 legacy 导出时从该快照的 immutable source view 与映射 span 取值。未知虚拟 getter、显式 override、synthetic source 均保留原 codec 语义。capture 仍冻结该局部单位原始 raw，保证 public shallow 出口不随 parser buffer 重绑定变化；缺 snapshot view 时也保留冻结值。热编辑不重新 capture 或重拼祖先正文，不引入通用祖先重算协议。

## Legacy nested 兼容层

旧 `parseDetachedLines` 成功时只恢复 depth，inner activeLine/pending 的可见副作用是既有旧输出的一部分。新 editingContext 或显式 sandbox 模式成功/异常均恢复完整 outer 上下文；旧 legacy 成功维持原效果，异常仍恢复 outer。此分层不会按 Markdown kind/anchor 类型特判，也不会为了通过全量改写旧 HTML 期待。未声明的第三方仍获得原成功执行顺序与 context 行为；不声称 legacy 成功具备新的 checkpoint 隔离协议。

## 最小正确性测试

主测试覆盖nested raw/ID复用、semantic真读者且普通body零syntax重parse、取消旧计算后新source不丢、失败重试、nested insert/delete splice+fresh、祖孙batch恢复规范化、未知外部typed无codec fallback+fresh、legacy reprocess可见顺序、failed candidate无ID/pending/effects/patch泄漏、opaque旧checkpoint epoch保护。运行状态待02实际结果，不提前Passed。

## stdlib操作依据

按实际使用只读本机`C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj`的toArray/remove/contains。toArray分配并复制引用，contains线性扫描，remove非尾部会搬移suffix。主引擎ArrayList仅存本batch dirty/recovery/patch/worklist，不存全doc children；全doc sibling操作走04持久sequence/ID index。真实parser window读rope.lineAt，无每edit全文copy。manifest 1.2beta与实际1.3alpha是否同一stdlib尚未证实，未声称1.1兼容。

## 当前验证

- `task05-verification/integrated-compile-1.log`：2026-10-23 官方 `cjpm test --no-run --no-progress` 全闭包编译成功，exit 0；实际 SDK 为 1.3.0-alpha.20260920003052，不声称 1.1 已通过。
- `core-test-1.log`：37/37 实际 Passed（source retention 8、session checkpoint 15、真实 kernel checkpoint 5、atomic stores 9），0 fail/error/skip，exit 0。
- `aux-test-1.log`：真实 typed aux graph 4/4 Passed，含同 ID 字段更新、共享引用、受影响闭包回收与仅路径复制祖先 effects 保留；0 fail/error/skip，exit 0。
- `editing-engine-test-1.log`：首轮 BlockEditing 选中 39 个 case，37 Passed / 2 Failed，98 个其他 tag 未选，exit 1。主引擎 16 中 14 Passed；preparation 3、kernel 5、session 15 全通过。两个真实 nested fresh 差异来自捕获祖先的 source-derived rawContent 被冻结为旧 override，正在由存储 owner 修正显式 legacy 导出来源；保留完整 fresh 断言与原失败日志，不标 Passed。全量回归待修后执行。
- `integrated-compile-2.log`：provenance 修复、fixture 诚实 retention 声明及本轮安全主构造转换的全闭包编译 exit 0。
- `editing-engine-test-2.log`：39/39 选中 case 全部 Passed（主 16、preparation 3、kernel 5、session 15），0 fail/error，exit 0；原两个 nested 的完整 toString 与 toJson fresh 对照均通过。98 个未选 tag 不冒充通过。首轮失败日志继续保留。
- `task01-baseline/task05-full-console-1/summary.json`：首轮 27 包全量得到 691 Passed / 1 Failed，0 error/skip；唯一失败为原 AutoAnchor nested Paragraph 四模式。已定位为新的 nested 成功恢复改变了旧 legacy activeLine 副作用，使原 Blockquote source attributes 改变；root 决定通过显式 editing/sandbox opt-in 分层保留旧成功行为，异常仍恢复 outer。原期待与失败日志保留，修后重跑，不标全量通过。
- `integrated-compile-3.log`：legacy 成功兼容层修复后全闭包编译 exit 0。`editing-engine-test-3.log` 主选中 39/39 Passed；`legacy-anchor-test-1.log` 原 anchor 9/9 Passed，原 HTML 期待未改。
- `task01-baseline/task05-full-console-2/summary.json`：修后全量 27 包均 exit 0，692/692 Passed，0 skipped/error/failed。首轮 691/1 日志原样保留。
- `legacy-comparison-2/versus-frozen01.json`：148 条记录、11 字段逐项零差；baseline/current observations 的 SHA256 同为 `dd0eb7467e170fbb4d54c533235f99225087e814a93f625bfe9aef2d46ce6b1e`。原 legacy 保护源码哈希未改。
- `batch-time-comparison.json`：同 SDK、同源 v2 driver、同 `-O2`，reference SHA256 `1cf4fc98cdc947fa17e1aa971a3e360eaf6b7d5039fd064ecb64f38d5dff7627`；顺序 AB 一次，每 binary 84 samples，均 exit 0，没有并行 build/test。

| 输入 / API | reference mean | candidate mean | ratio |
|---|---:|---:|---:|
| small String | 25.991 μs | 27.400 μs | 1.05419 |
| small Stream | 26.945 μs | 27.752 μs | 1.02996 |
| large String | 27.252 ms | 26.451 ms | 0.97058 |
| large Stream | 27.224 ms | 28.200 ms | 1.03585 |

以上是保留原条件的一次记录，有快有慢，不作为统计显著性或“无退化”证明。不扩采样、计数或 benchmark 框架。root 已实际审查全部证据，Task05 按用户裁剪后的最小验证范围完成；不声称统计无退化。新内置适配仍 0/30。

发布收尾已修正：工作区释放属于 prepare；安装成功后的 cleanup 失败不会恢复旧 parser 或虚报未提交。失败释放句柄保留，后续计算/close 可重试；snapshot 与 session 仅在释放成功后关闭。最小 wrapper 失败重试断言随主 case 编译。
