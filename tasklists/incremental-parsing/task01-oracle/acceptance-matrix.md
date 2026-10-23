# Oracle 子任务验收映射

以下设施已由Task01 owner串行编译、使用官方binary console模式实际运行：18个Oracle自测通过，0 failed/error，exit 0。命令、18个case名称与原始证据见[verification.json](verification.json)；真实生产editing、workcounts和隐藏source/provenance不在本轮通过声明内。

| 要求 | 对应实现/测试 | 当前证据边界 |
|---|---|---|
| typed/children/三类metadata完整公开观察 | `captureNode`、41 typed visitors；`childMetadataAndShadowedMetadataAreNotHiddenBySameHtml`、`allThreeMetadataKindsAndChildOrderAreCompared` | 同名metadata遮蔽和JSON未列typed字段有独立负例 |
| typed class与JSON不充分 | `actualTypedClassCannotBeSpoofedByKindOrJson`、Fenced fileGroups/HTML attributes、unknown型Incomplete tests | 已知41类public字段；未知第三方额外字段使正式比较结论为Incomplete |
| TOC非children图 | `tocItemsCaptureShadowedMetadataAndNestedGrandchildren`、mapping/identity/alias tests | items与nested children全部捕获；synthetic0身份明确未分配 |
| HTML/Markdown/Typst | snapshot三格式；`renderedOutputsAreIndependentComparisonSurfaces` | 输出与结构分开比较 |
| patch完整性与顺序 | `patchDifferences`；遗漏/错序/payload负例 | 当前append AstPatch；未来worker事务需扩展schema |
| fresh身份对齐 vs稳定唯一身份 | `differences`、`stableIds`、`uniqueIds`；独立identity test | fresh不要求数值ID相同；editing稳定声明仍强断言 |
| 公开raw与坐标 | captured raw/span、`mappingFailures`；raw改变/byte-rune坏边界负例 | 内部source/provenance来源不可观察，不声称已证明 |
| 四步reference及fresh oracle | `fourStepRunnerUsesFreshFactoryAndReportsMissingProductionAdapter` | 每步新工厂计数=4；actual=None，生产editing未接入 |
| adapter交接自测 | canned adapter返回预先捕获snapshot | 不调用parse，不作为editing实现或工作量证据 |
| fresh符号表隔离 | `freshSessionsDoNotRetainPreviousReferenceDefinitions` | 新工厂下已定义/未定义引用结果分离 |
| 未观察vs真实零 | `EditingWorkCollector`及JSON schema；collector测试 | `None/count:null` 与 `Some(0)/observed:true`区分；默认test-self-check |

全部新增源都在测试目录；未新增生产hook、解析算法、CLI、kit或extension修改。

本次官方命令：`markit.tests.unit.exe --no-progress --no-color --include-tags=EditingOracle --show-all-output`。同包另5个legacy自测通过，27个旧case因tag过滤不计作本次回归。最低正式1.1.0尚不能由当前alpha工具链结果证明。
