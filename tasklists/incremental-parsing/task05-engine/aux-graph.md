# Task05 typed auxiliary graph 定向验收

Owner：`task05_engine/session_checkpoint`。独占文件：`markit/src/tests/unit/task05_aux_graph_test.cj` 与本记录。状态：最新4项官方测试已通过，源码冻结；历史准备记录保留如下。

## 冻结输入

04已明确并最终冻结：

- `PersistentNodeCapture.capture(root, source, existing: Some(version)) -> PersistentNodeBundle`
- bundle 的 `root / auxiliaryRecords() / auxiliaryOwnerIds()`，构造可传 `ownerIds`。
- transaction `replaceBundle / spliceBundles / removedNodeIds` 与 pure `replacingBundle / splicingBundles`。
- `removedNodeIds` 包括同ID替换的旧记录 owner，用于撤销旧 effects，不仅表示最终消失的 ID；新同ID候选仍可存活。
- `OwnedEffectsTransaction.revokeOriginalOwner` 只撤原版本贡献，允许本轮新候选后续重放。
- capture(existing) 对本单位拥有的 aux 抓新typed payload，对外部 structural/其他unit aux借用已存 raw；GC按incoming与受影响aux closure处理shared、自环、互环，不全graph扫描。

本组不修改04产品、不修改原atomic tests，不增加通用oracle/benchmark/统计框架，不自行build。新测试不import Markit/main/plugins，仅使用core真实rope、持久store、typed codec与owned effects，可在统一稳定core闭包单独官方编译执行。

## 4个实际case

1. **localBundleReplacementUpdatesSameIdAuxAndAddsTypedAliasesWithoutMutatingOldSnapshot**：真实rope从v0到v1，旧owner refs含aux10、结构sibling2、重复aux10别名和独占aux12。局部bundle替换owner1，同IDaux10的typed detail/rank刷新、新增aux20、借用旧structural sibling2，撤旧aux12。检查raw sibling共享、newaux/sameID typed字段、reference与structural同一实例、重复refs别名、旧snapshot与后续detached export互不污染。
2. **spliceBundleKeepsGlobalReferenceAndReclaimsExclusiveAuxOwnersAndBirthFloor**：使用真实typed payload将3个structural raw明确重绑定到v1，保留aux10 birth0，它独占pin住floor0；随后真实rope进v2，splice新owner3+aux30，引用未改global2。检查旧owner1/aux10撤销清单、global raw共享及export alias，独占aux消失后floor推进到1（global birth1/newaux birth2）。同一稳定候选中撤销移除owner的原effects并重放新owner，检查正读者90失效、旧effects snapshot不改。
3. **sharedAuxiliaryAndItsChildSurviveUntilTheLastStructuralOwnerDisappears**：两structural owners共享aux10，aux10含structural child11。删除第一个owner时raw10共享、aux10/11不回收，最后一个owner删除时两者一起回收、tree只剩root、anchor floor推进到v2，旧snapshot仍完整。
4. **affectedAuxClosureCollectsMutualAndSelfCyclesWithoutARemainingExternalOwner**：aux10↔aux11互环且aux11有self ref，先验证真实typed materialize别名闭环；移除唯一外部owner后affected closure同时回收两aux，floor推进v1，旧snapshot仍能find两者。

## 静态自核与协议修正

04只读审核后修正两处测试期望：sameID aux10出现在removedNodeIds用于撤销旧贡献应为true；case2 before.version=1必须commit到更高sourceVersion，故显式进v2、capture/splice/prepare2。手工保留aux旧epoch的bundle显式 `ownerIds:[1]`。这些是新测试fixture协议修正，未靠放松产品断言掩盖失败。

## 验证

当前只完成源码与04静态API核对。4项测试tag为 `Task05AuxGraph`，已SOURCE_READY交02统一官方编译与执行；待回填真实命令/日志和结果。无当前拒绝或权限阻塞。

## 祖先 effect 保留的精确回归（仍4cases）

root/04发现并修复：bundle 引入更新的 aux child11 时，仅copy其现有 aux parent10 的 child path，parent10 payload并未重parse，不能把10加入 `removedNodeIds` 导致 engine 撤销保留的effect。普通root splice不足以触发原错误行。

已在case3加入一个独立真实rope `aux-ancestor` 小分支，不改原shared两次删除断言：left1新bundle仅引用owned aux11新typed值，right2继续引用父aux10；验证撤销名单含1/11而不含10，按真实名单调用 `revokeOriginalOwner` 后10的effect原值仍在，11重放新effect，typed parent10.children11已更新，旧snapshot仍保原child。仍为4cases，无新设施。该精确版本已重新SOURCE_READY交02单独官方编译执行；session15等其他37项由02另行先验证，不并发改其冻结输入。

## 最新冻结版官方验证结果

- `task05-verification/aux-tests-compile-1.log`：`TASK05_AUX_TEST_COMPILE_EXIT=0`，命令输入见 `aux-tests-compile-1-args.json`。
- `task05-verification/aux-test-1.log`：**4/4 Passed，0 skipped/error/failed，TASK05_AUX_TEST_EXIT=0**，总运行约3.702ms。4项均含原有完整断言，其中case3包括后来精确补入的aux parent10 effect保留分支。
- 验证使用04新冻结bundle/GC产品，真实rope/typed codec/stores/effects，不是API fake。未改04产品或原atomic tests，未自行build。新aux test文件保持冻结。
- 本组无剩余已确认阻塞。整体Task05 engine/full-suite验收仍由主owner和02完成；本4项通过不等同30内置插件已适配。
