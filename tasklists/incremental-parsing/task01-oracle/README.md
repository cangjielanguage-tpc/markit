# Task 01 Oracle 与计数工具交接

当前状态：已实现并通过当前工具链编译，18个Oracle自测全部通过。Task01整体状态与后继放行由协调者审查其他子任务及最低版本证据后决定。

## 文件所有权

- `markit/src/tests/utils/editing_oracle_kit.cj`：测试专用观察、比较、reference model、runner及计数schema。
- `markit/src/tests/unit/editing_oracle_test.cj`：`EditingOracle` tag下的18个测试。
- 本目录：暂存副本、生成器和验证证据。未修改生产代码、README进度或其他agent文件。

## 当前观察范围

- 比较实际已知typed类别、41种节点的public字段、Node通用字段、children顺序、三个metadata类型、rawContent与byte/rune span、HTML/Markdown/Typst输出。
- 比较器不调用`Node.==`作完整等价判断，也不只比较HTML或JSON。FencedCodeBlock的fileGroups完整内容、HTMLInline的attributes/attributesStr以及同名string遮蔽int/bool metadata均有额外观察路径。
- JSON对象key规范化排序；HTMLBlock序列化时把HashMap展平成字符串的attributes字段改为独立排序的完整key/value观察，避免插入顺序误报语义变化。renderer三格式仍按原字节严格比较。metadata的键来自当前Node已排序的metaKeys并逐key读取所有三类值。
- TOC `items`与其子树采用完整观察；同一对象通过items与children多次引用时记录canonical path，区别于不同对象误用同一ID。
- Legacy TocNode/TocItem构造器给合成节点留下`id=0`。观察明确标识`unassignedSyntheticIdentity`，这些节点不作为重复分配的证据，也绝不通过稳定身份断言。其他节点重复ID照常报告；这不是全局忽略0或忽略NodeId。
- Fresh会话按有序结构路径与全部当前可观察的字段对齐；会话间数值ID不要求相同。稳定ID由明确的old/new path复用声明单独检查。
- patch比较独立检查数量、顺序、kind、parent/id/span、三格式payload与附带Node观察，不把结果HTML相同作为patch完整证据。
- reference model使用UTF-8 byte编辑边界，拒绝分裂Unicode scalar与CRLF。源坐标rune按当前scanner的CRLF归一为一个rune处理。

## 不可观测的真实边界

- 当前Node的`sourceBuffer`、raw override来源和内部派生provenance不可从测试公共API枚举。工具只能验证公开rawContent/span及可见metadata；相同raw输出不证明内部source绑定正确。
- 当前不存在生产editing adapter。runner每步显式创建fresh工厂oracle；缺adapter返回`actual=None`、`productionEditingConnected=false`。
- canned adapter仅验证runner交接，既不解析，也不代表生产editing或性能证据。
- 未注册的第三方自定义Node子类的额外字段需要新增观察器；当前公共通用观察不能证明其隐藏私有字段。`compare(...).status`对已知差异返回`Different`，对无已知差异但含未知typed字段返回`IncompletePublicObservation`，仅全部当前public字段有观察器时返回`EquivalentPublicObservation`。`differences`仅为已知差异列表，空列表不是完整性结论。Task02应提供可扩展typed codec/观察契约，不能用通用kind/literal降级掩盖未知字段。
- 当前计数collector未接入生产hook。`None`表示未观测，`Some(0)`才是已开启hook的真实零；测试事件默认`evidenceOrigin=test-self-check`，不得用于生产局部性/性能结论。

## Task02输入

1. 冻结公共的typed codec、完整metadata键枚举/类型区分及可扩展第三方观察契约。
2. 冻结真实source/provenance引用与组合映射观察，含synthetic origin/retention/版本，不靠raw输出推断内部来源。
3. 接入计数schema（source bytes/materialize、rope、probe/parse/finalize、checkpoint/reuse、effect revoke/replay、正负依赖、renderer/cache、CodeHL、公式、图、项目扫描、worker、DOM）。batch禁用编辑bookkeeping的路径保持无额外成本。
4. 编辑adapter接入后提供明确复用声明，结合fresh结构对齐、稳定ID/唯一ID和patch比较三种独立证据。

## 验证记录

- typed visitor生成器：2026-10-23实际运行，退出0，生成41种观察器。
- 首次生成曾因根目录parents索引错误输出0；已修为实际仓库根后重跑。该次不作为覆盖通过证据。
- src安装在既有baseline源码枚举结束之后；该次既有baseline结果不验证新增工具。
- 首次新增编译失败：3个现有enum没有ToString；已改为逐值穷举match，不删字段。错误保留于`../task01-baseline/new-facilities-compile.log`。
- Task01 owner第三次统一编译成功，见`../task01-baseline/new-facilities-compile-3.log`中的`cjpm test success`。第二次失败来自另一owner的legacy测试保留关键字，修复后重编译；不将失败隐藏。
- Task01 owner实际运行官方生成binary console模式，exit 0：18个Oracle自测与5个legacy自测通过，0 failed / 0 error；27个旧unit case因本次tag选择被排除，不算本次回归通过。命令（工作目录`C:\Users\Shawn\markit\markit`）：

```powershell
& 'C:\Users\Shawn\markit\markit\target\release\unittest_bin\markit.tests.unit.exe' --no-progress --no-color --include-tags=EditingOracle --show-all-output
```

- 原始日志：`../task01-baseline/editing-oracle-console/markit.tests.unit.log`；机器可读命令、18个case名称、源码/binary/log SHA256与状态边界：`verification.json`。
- 本轮当前工具链为cjc `1.3.0-alpha.20260920003052`，不能用此结果证明正式最低`1.1.0`兼容；独立版本验证由协调者安排。
- 生产editing adapter、真实生产计数hook以及隐藏source/provenance仍未接入；以上18通过仅验证Task01测试设施。

最终源码SHA256：

- `editing_oracle_kit.cj`：`d8d63b8d66752de3ce8348a95da88fd5540f120ab16d357fbd803d80c158ea56`
- `editing_oracle_test.cj`：`18a5fb5e8835c740e9ed9f00e72f1e1d579f5b2b7a8bd67d3bcdb292ffdcb4f1`
