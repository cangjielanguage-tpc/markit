# Task05 ParseSession checkpoint 与 nested/probe 沙盒

2026-10-23 legacy compatibility update (SOURCE_READY, verification pending): successful legacy `parseDetachedLines` now preserves the original active-line and pending-paragraph side effects and restores only detached depth. It does not clear the caller's paragraph before invoking a legacy delegate. `editingContext=Some` or explicit `sandboxedStates=true` still isolates the working root, state, effects and paragraph context, restoring outer syntax on success and failure. Legacy exceptions still restore outer syntax and allocator. The existing non-restorable-state test retains its exception assertions and now also checks successful legacy pre-context visibility, retained inner active/pending state, allocator advancement and depth restoration. This supersedes the earlier blanket statement that all successful legacy nested calls restore outer syntax. The change follows the actual AutoAnchor/full1 and 148-record baseline comparison; no plugin/kind/symbol branching or expected-output update was introduced. Earlier 15/15 results describe the prior source; this small final compatibility change awaits the coordinator's next official run.

Final compatibility verification: `task05-verification/integrated-compile-3.log` records `TASK05_WHOLE3_COMPILE_EXIT=0`. `editing-engine-test-3.log` records 39 selected cases PASSED, ERROR 0, FAILED 0, exit0 (the runner also reports 98 unselected SKIPPED cases in total137); this includes all final SessionCheckpoint15 cases and the appended legacy-success assertions. `legacy-anchor-test-1.log` records 9/9 PASSED, SKIPPED/ERROR/FAILED 0, exit0, preserving the original anchor expectations. Full-suite acceptance remains with the main owner/coordinator.

Owner: `task05_engine/session_checkpoint`。状态：本组最新15项官方测试已通过（包含在core 37/37中），源码冻结。整体Task05集成/全量验收由主owner与02继续负责；历史失败与修复过程保留如下。

## 产品改动与接口

独占产品文件：

- `markit/src/core/session/parse_session.cj`
- `markit/src/core/session/parse_session_checkpoint.cj`
- `markit/src/core/session/session_patch_queue.cj`
- `markit/src/core/session/session_symbol_table_store.cj`
- 独立测试：`markit/src/tests/unit/task05_session_checkpoint_test.cj`

`ParseSession.checkpoint(): ParseSessionCheckpoint` 与 `restoreCheckpoint(checkpoint): Bool` 保存/恢复 active line、pending lines/span、allocator、depth、indent flag、finalized、line-index root、patch-queue root、working-root append cursor、事务 context 引用与完整可恢复 symbol-state payload。跨 session 拒绝。source 为已接受输入的独立事实，session checkpoint 不回退 source；block frames/facet/version/mapping/owned effects 的完整组合由主 kernel/编辑事务负责。

`nextNodeId` 只读，`setNextNodeIdForEditing(next)` 只允许提高 ID 高水位，恢复旧单位后由主引擎提高到未改 suffix 的 allocator 上界，避免重复 ID。

`SessionSymbolTableStore(checkpointEnabled: true)` 明确启用。默认构造不分配 factory map，不抓 snapshot，不假称可恢复。启用后 checkpoint 需要每个 state 的真实 restore codec；缺失、名称不符、payload/version/context 不完整均拒绝。保存时将公共 snapshot envelope 重新冻结为 `RestorableSessionStateSnapshot`，由 payload.detachedCopy 断开可变别名。restore 先用 factories 建立全部候选 state，全部恢复成功后一次换 state map；provider 拒绝或异常不会改动 live state root。

`ParseSession.sandboxProbe(() -> Bool)` 在独立 symbol-state root、空 working DocumentNode 和独立 patch queue 运行，finally 恢复原 roots、ID、line index 与语法上下文。probe 经 `session.root`/`session.patches` 不能拿到旧 tree/queued Node 引用。完整保护只针对 session/事务拥有的数据；provider 若闭包直接修改外部既有 Node 或 state 实例，违反 owned 数据约束，不能声称由通用 sandbox 撤销外部内存。

`setRegisteredBlockStartDetector(detector, sandboxed: false)` 保持旧 detector 的默认行为和 root 可见性；编辑 opt-in 需要 true。`setDetachedBlockParser(parser, sandboxedStates: false)` 默认只 finally 恢复 outer 语法上下文，不在 batch/nested 隐式 deep-copy 所有 state。编辑 opt-in true 时同时使用独立 working root/queue 与完整 state 沙盒：成功保留新分配 ID、合并新增 patch、保留允许的语义状态；异常丢弃。outer pending paragraph 在进入 nested 前隔离，退出或异常都恢复 active line/pending/span/depth/flags。

`ParseSession.editingContext: ?IncrementalParserContext = None` 无默认分配。非空 context 在 probe / sandboxed nested 必须实现 `ParseSessionTransactionParticipant.beginSessionScope(): ParseSessionTransactionScope`，scope 用 `complete(commit: Bool)` 提交/撤销暂存状态与 effects。无 participant 安全拒绝。scope 的成功收尾也纳入 gate：parser 返回但 scope.complete(true) 抛时，尝试 complete(false)，丢弃本地 ID/state/patch/root 结果。participant 若提交抛必须保持可回滚，其 commit 仅应安装已准备 roots，不能运行会失败的 provider 代码。

## 成本与兼容边界

- patch queue 改为 immutable records 链，snapshot/restore O(1)，仅 drain 按输出大小建立数组；不复制 Node 图。原来的按 ID 去重行为和 replace/remove 顺序保留。
- line-index snapshot/restore 依赖 source owner 的 O(1) root/flat-prefix 接口；默认 legacy 仍为 flat append，编辑主入口显式 enablePersistent。
- session checkpoint 复制实际 pending paragraph 和显式 state payload。不得在每个普通 body 行无条件抓全 session checkpoint；恢复单位由 provider 与主 kernel 选择。
- 不改 core/editing、不导入 core.block，避免 package 环。PluginRegistry 的 checkpointEnabled 接线由 02 唯一维护。
- 不对 shared target 自行构建，没有并发 cjpm。

## 定向验证（待统一运行）

`Task05SessionCheckpointTests`，tags: `BlockEditing`, `SessionCheckpoint`，9 cases：

1. 完整 checkpoint 与 pending/active/ID/flags/line-index/patch 反复前后恢复。
2. 多次成功/失败/异常 probe，不漏 state、ID、patch、root append；旧 root/child 的三类 metadata/span/raw 不变。
3. registered detector 的 accepted/declined probe 都回滚。
4. nested 成功保留 owned results，恢复 outer 语法。
5. nested 异常完整回滚。
6. 非恢复 state 在执行 probe 前拒绝；legacy nested 异常仍恢复 outer，旧 detector 读取既有 root 与调用顺序保留。
7. provider restore 拒绝与 foreign checkpoint 不半提交；allocator 高水位不能下降。
8. context participant 的 probe effects 回滚 / nested 成功提交 / 异常撤销。
9. parser 成功但 participant commit 拒绝时，本地结果仍全部丢弃。

当前证据：代码/测试已写，尚未编译/运行。实际 SDK 沿用 02 统一命令记录；未补最低版本兼容或通用框架。

## 2026-10-23 集成修正与实际编译记录

02 统一独包编译第1轮 `task05-verification/session-package-compile-1.log` exit 1；session 的局部 `if/else None` 因 source 包的 `None` 枚举歧义产生3条诊断，已显式标注 `?SessionSymbolTableSandbox` 与 `Option<SessionSymbolTableSandbox>.None`。同轮 owned-effect 诊断归04修复；保留失败证据，等待第2轮，不声称通过。

主引擎实际接线发现多个恢复点共享 legacy mutable root 的别名：旧 append cursor rewind 会截掉后一个恢复点的 children。已新增 `restoreEditingCheckpoint(checkpoint): Bool`：恢复 symbols 与局部上下文，但不改旧 root.children，随后进入新的空 working root 与新 patch queue。编辑恢复点只用此入口，已发布语法来自 context.previous 的持久 tree。原 `restoreCheckpoint` 仅为 legacy scratch append-cursor restore；若先前 rewind 已毁掉目标 cursor 所需 children，先于任何 state 变更返回 false，不能虚称前向恢复成功。编辑事务的新workingroot使旧publishroot在失败rollback时保持完整，无整图clone。

新增两个定向 case（当前共11）：共享 early/later/final 恢复点保留旧3siblings与metadata/raw，临时工作root切换后rollback回旧root；legacy scratch rewind后前向缺children明确拒绝且不半改symbol state。

02 的第2轮完整 session 产品包独编已真实 exit 0：`task05-verification/session-package-compile-2.log` 为 `SESSION_PACKAGE_COMPILE_EXIT=0`。11项测试仍待统一 unit 构建/官方运行，不能把产品包类型编译等同测试通过。

## 单次真实候选事务与 lazy state overlay（当前源码）

新增 `ParseSession.parserAttempt<T>(attempt: () -> ?T): ?T`，用于 kernel 实际 `tryStart`/`tryParse`，不先 probe 再重跑 parser。`editingContext=None` 直接调用 legacy 原路径。editing 时进入独立 scratch root/queue、symbol overlay 与 effects/context scope；`None` 或异常完整撤销，`Some` 只提交一次，保留返回的 node/frame、state、IDs、局部语法状态，合并新增 patches 并恢复 outer root/queue 指针，root append 本身不发布，实际 emit 仍由 kernel 负责。

为避免每个候选复制所有 symbol payload，`SessionSymbolTableStore.beginLazySandbox()` 建立小 overlay，`get(name)`/`get<T>` 首次实际读取某 state 时才用其 factory + frozen payload 克隆；未触达 state 不抓 snapshot。成功仅合并触达 entries，失败丢 overlay 还原原 map。嵌套 overlay 查父 scope，可重复 nested；probe 和显式 sandboxed nested 同步复用。默认未启用 store 的 factory map 与 scope stack 都为 None，不分配增量集合。显式完整 `checkpoint()` 仍保存全恢复状态，不伪装只保存触达状态就足够恢复任意 provider。

基础测试独编第1轮 `task05-verification/checkpoint-atomic-tests-compile-1.log` exit1：两处测试捕获可变局部 `invoked`/`trace`，已等价改为 let 控制对象字段，保留全部未调用与顺序断言。新增第12项实际候选测试：失败候选写 state/ID/root/patch/effect 后返回 None，下一成功候选只调用一次并看见干净前态；验证未读 state snapshot 调用为0，并注入异常验证回滚。当前新源码已 SOURCE_READY，等待 02 重新编译与官方执行；此前 session-package-compile-2 的成功不覆盖本轮新增代码。

新增 parserAttempt + lazy overlay 的完整 session 包第3轮实际类型编译通过：`task05-verification/session-package-compile-3.log` 为 `SESSION_PACKAGE_COMPILE_EXIT=0`。只读审查报告本轮没有确认的剩余 session 缺陷；真实 kernel 的候选调用接线与 entry fixture 由主 owner 验证，12项本组测试仍待官方编译/运行。

## 官方12项实跑与跨版本行位置预检（新轮14项待测）

02 已使用一致的 source2 + nodes2 + session3 产物完成本组官方测试独立编译，exit0：`task05-verification/session-checkpoint-tests-compile-1.log`。官方执行 `task05-verification/session-checkpoint-test-1.log` 实际 **12/12 Passed，0 skipped/error/failed，exit0**，总用时约1.566ms。该事实只覆盖当轮12项断言，不冒称后续新代码已验证。

主集成随后发现旧 checkpoint 的 active/pending SourceLine absolute span 在 accepted source 前插后需重新映射。新增 `restoreEditingCheckpoint(cp, remapLine: ?(SourceLine,Bool)->SourceLine=None)`：调用方传 `Some(mapper)`，false 表示 active line 可从 target source 重读，true 表示 pending 行必须验证正文与 termination 未变；session 进一步强制检查 pending.text / terminated 相同，否则要求 provider 扩大/吸收恢复窗口。所有 active/pending 映射回调与 span 非负/有序验证先在临时对象完成，paragraphSpan 由 mapped pending 重新 merge；全部预检成功后才 restore symbols 与发布局部上下文。mapper 抛、返回非法 span 或改写 pending 都不半改 live state/root/ID/patch/flags/index。旧无 callback 行为不变，旧 checkpoint 的 SourceLine/pending 数组不被修改。

映射文档身份、source version、synthetic mappingVersion 及 frame 几何恢复由主 provider/context 负责，不在 session 根据符号猜坐标，也不遍历重写全 line index 或 AST。新增2项（现共14）：不同 byte/rune 位移、active 重读与 pending/span 保留、旧 checkpoint 再利用；末 pending mapper 抛/changed pending/invalid span 三类失败的原子性。新轮源码已冻结交 02 重新编译和官方执行。

为配合 source owner 的 `LineIndex.bindEditableSource` O(1) rope view，`ParseSession.recordSourceLine` 现仅在 `!lineIndex.isEditableView` 时 append；默认 legacy flat append 不变。编辑入口在 restore 后绑定最新 target source view，避免 prefix line geometry 保留旧 source 或全 N 重建。该 guard 与新 source API 一起冻结，02 等新 source 包后统一编译，不拿旧包制造缺 API 的假诊断。

最新 remap + LineIndex editable-view guard 的产品包已实际类型编译通过：`task05-verification/session-package-compile-4.log` 为 `SESSION_PACKAGE_COMPILE_EXIT=0`，使用新 source-package-compile-3 一致依赖。14项测试仍待本轮官方执行。

## 编辑 checkpoint 不钉 initial legacy graph（新轮15项待测）

主 owner 发现初始解析每个单位的 cp.syntax.root 都引用同一个会继续增长的 initial DocumentNode。即使 raw tree 已持久化，一枚旧恢复点也会额外钉住整个 legacy graph。现仅 `editingContext=Some` 的公共 checkpoint 使用 `syntaxCheckpoint(detachEditingRoot:true)`：保存 shallow empty DocumentNode，保留 Document typed kind/ID、base metadata/source/hooks，但不含 children；不修改 live working root。相同原因，保存的 patch queue 也改为独立 wrapper 指向当时 immutable patch root（O1），不引用之后继续增长的 live wrapper。完整当时 patch 记录仍保留。

内部 parserAttempt / sandboxProbe / nested 的 syntaxCheckpoint 默认仍保存真实 outer root，不能为省引用破坏失败回滚。legacy editingContext=None 的公共 checkpoint/append cursor 完全维持原义。

新增 `releaseEditingWorkspace(): Unit`，只允许显式 editingContext=Some，主入口在初始持久 tree capture 后释放 scratch root/queue；不清 states、allocator、active/pending、source 或已发布持久 snapshot。legacyNone明确拒绝，避免误清第三方兼容 fallback 的 legacy graph。新增第15项验证：capture不动live initialroot、恢复编辑cp为空root且root metadata保留，旧queue后增记录不被早cp引用/恢复覆盖，release保state/ID/active/pending/source，旧graph仍未被修改；无GC数字断言，不声称测得释放字节数。新源码再次READY交02，不将旧12的实跑结果冒充最新15通过。

最新 memory+mapper轮已由02官方实际执行：`task05-verification/source-session-test-1.log` 中 session15 + SourceRetention8 合计 **23/23 Passed，0 fail/error/skip，exit0**。这覆盖第15 root/queue detach与releaseWorkspace版本。

随后确认另一同类pin：持久unit cp.syntax.editingContext引用live BlockEditingContext，会连带保存previous rawsnapshot/effects transaction。现detached editing checkpoint明确保存 `Option<IncrementalParserContext>.None`；内部candidate/probe/nested本地cp仍保存真实借用context供finally恢复。`restoreEditingCheckpoint`保留调用前当前participant（不取旧tx，也不让cp.None覆盖当前participant）；主引擎仍可显式set当轮context。第15保留原断言，追加public cp还原None、内部attempt失败还原actualcontext、editing restore保当前context三断言。总数仍15，最新小改重新READY待02复跑，不把旧23/23结果冒充本小改已过。

最新core-tests-compile1产品compile6已exit0，测试编译仅第15的两处接口类型refEq报错（IncrementalParserContext接口不能直接作为Class-Object），已保留身份断言并等价先cast为fixture CheckpointEditingContext再refEq，未删除断言。只改测试两处，产品未变；SOURCE_READY交02复编。aux新4case由独立文件验证，不混入旧23通过数字。

## 最新冻结版官方验证结果

- `task05-verification/core-tests-compile-2.log`：`TASK05_CORE_TEST2_COMPILE_EXIT=0`（完整命令输入保留在同名 `-args.json`）。
- `task05-verification/core-test-1.log`：**37/37 Passed，0 skipped/error/failed，TASK05_CORE_TEST_EXIT=0**。包括本组 **15/15 SessionCheckpoint**（finalcontext/mapper/root+queue detach/完整rollback全部新增断言），及source8、kernel5、atomic9。
- 该轮使用最新一致source/nodes/document/session/block依赖；session产品 `session-package-compile-6.log` 也exit0。测试refEq修复保留了actual class identity断言，没有降级验证。
- 本组产品4文件与session test保持冻结，未自行构建shared target、提交或推送。尚待主owner/02完成整体Task05真实引擎集成及全项目回归；本记录不把core定向验证等同整体Task05 Done。
