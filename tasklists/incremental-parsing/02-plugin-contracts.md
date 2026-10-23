# Task 02：插件能力契约与 runtime plan

Status: Done

## 2026-10-23 用户裁剪与当前执行

用户明确要求基线测完即进入产品实现，取消补正式1.1.0兼容验证与通用oracle/计数/benchmark框架扩展。旧文档中要求正式1.1.0实测及大框架接入的门槛本轮不再阻塞；取消不等于通过。实际工具链为1.3.0-alpha，不提高项目声明最低版本，不声称最低版本兼容。

保留本任务产品正确性：parser级可选增量与安全默认、真实第三方旧源码可运行、混合parser能力、安全隔离证明与strict拒绝、batch不启用编辑记录、必要Source/Node/Mapping契约、真实typed renderer原型、最小定向测试与fresh全量结果对照、同-O2用时比较。

用户再次明确：默认false和安全fallback只为外部第三方零源码修改兼容；全部30个内置插件仍须后续真实增量适配。Task02增加接口默认不计入插件适配完成，当前仍为0/30。07–13不得以blanket full-session fallback结项；真实影响远距离传播仍须说明具体依赖/原因。

标准库性能判断选择性参考用户提供的只读`C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`，按实际调用读取String/StringBuilder/UTF8/Array/ArrayList/HashMap等具体方法，不能假定slice零复制；checkout与当前1.3-alpha二进制的版本关系须明确。此为必要实现取舍参考，不扩大成标准库调查或新benchmark框架。

产品并行文件所有权与共享API见[task02-ownership.md](task02-ownership.md)。当前公共契约已写入`core/editing`，parser/runtime/typed codec由三个子agent在互斥文件实现；共享编译由task02_contracts串行安排。

### 实际实现与检查点

- `core/editing`三份生产契约已落盘，Source/Node/Mapping协议只依赖std公共值；独立`cjc -p ... --output-type=staticlib -O2`初次通过。后续加入显式enum Equatable的语法失败保留在`task02-contracts/public-contracts-compile-2.log`，修正match tuple语法后`public-contracts-compile-3.log`退出0。
- 四类既有parser均已有默认false/None/None，不增加旧parser必须实现的方法。NodeCodec使用注册provider保真重建，core不import插件包；Node私有三metadata/source/raw/hooks复制已实现。旧SessionStateSnapshot维持原name-only存储，显式Restorable派生类型才持编辑payload。
- runtime按需计划、phase DAG、Markit显式入口及最小测试已写入。首次集成`cjpm test --no-run --no-progress`退出1，错误为enum无相等运算符及构造期间调用instance helper；原日志`task02-contracts/integrated-compile-1.log`保留。运行时owner正将helper改static并修复审查发现的配置不可缓存/默认paragraph fallback漏记。
- 以上不是验收完成或生产editing已可用声明。接口检查、最小真实typed/能力测试及同-O2简明前后用时须实际运行后才放行03/04。
- 只读review曾以paragraph factory闭包存在推断empty/leaf-only必产段落；实际定向测试报children为空，读取BlockTreeBuilder及IncrementalSession后确认启动/flush受真实paragraph parser非空gate保护。root撤回该前提，已移除由此误判产生的phantom能力登记；用例改为真实可达parser库存与fresh同配置结果对照，未改旧生产语法。原失败保留于`editing-contracts-test-1.log`。

## Execution Contract

- Depends on: Task 01。
- Unlocks: Task 03、Task 04。
- Execution: 串行；01审查通过后执行，02契约与原型审查通过才释放并行A。
- Delegated owner: 插件与公共协议子agent，实施时由协调者指定。
- Scope boundary: 未来拥有`markit/src/core/plugin/`、公共facet/state/source/node/mapping/edit/codec接口声明、`markit/src/markit.cj`的runtime plan编译接线，以及独立契约/最小原型测试。只冻结Source/Node/Mapping的接口与测试假件，不实现03的rope或04的持久存储；不开始30插件批量适配、不改CLI/extension/重型服务。
- 输入：01 oracle与计数schema、现有注册器/parse内核、[设计锁](00-design-locks.md)、三份插件清单。输出：版本化公共协议、能力诊断与runtime plan、可运行最小typed codec原型、03/04隔离所有权交接表；共享接口在并行A期间冻结。

## Goal

把编辑所需的规则全部纳入插件声明能力，验证typed节点恢复方案可运行，并形成03和04可独立实现的共同接口。

## Current State

- `markit/src/core/plugin/plugin_registrar.cj::PluginRegistrar`已有各parser、state、processor、filter、finalizer和renderer注册；没有编辑facet或其依赖计划。
- `markit/src/markit.cj::Markit.ensureRuntimePlan/MarkitRuntimePlan`缓存dispatch table、inline engine与hook列表；`createSession`把共享ParseSession传入detached parser和continuation探测，没有纯probe/事务能力描述。
- `markit/src/core/session/session_state.cj::SessionStateSnapshot`只含dynamicName，SessionState无restore；`core/block/continuation_block_parser.cj::BlockState`为空接口，BlockFrame只装state。
- `core/inline/inline_parser.cj::InlineParser.tryParse`仅返回可选InlineParseResult，后者只有node/consumedBytes/consumedRunes，没有失败读取区间；现parser消费String与SourceSpan。
- typed renderers通过具体Node子类cast读取字段；Node metadata/private source/raw信息不能靠kind+literal完整重建。

## Follow-Up Work

**用户澄清后的parser级兼容要求（2026-10-22）：** 以既有BlockParser及相关parser/extension point为直接能力声明单位，提供默认false的supportsIncremental设置及安全默认增量方法（均为候选名称）；第三方无需覆盖即可保留普通解析，选择支持时覆盖相应方法。同一plugin可同时注册支持和不支持增量的parser，plugin级设置仅补充，不能替代逐parser判断。bool只表示资格声明，不证明完整checkpoint/restore/effects能力。具体仓颉1.1.0默认方法语法由02原型验证，禁止新增旧插件必须实现的抽象方法。

默认compat按已证明安全的最小范围回退：仅当引擎或provider证明边界、状态及语义副作用隔离时，调用该单位完整解析；无法证明隔离则整会话full-rebuild，不假定未知插件局部安全。报告owner/parser/facet/reason及fallback范围，strict仍须显式开启并原子拒绝。默认方法不得空restore/撤销或伪报已增量；保留旧插件零源码修改的compile/register/parse/append。

**新增必做：** 冻结batch与editing的记录策略：共享同一语法实现，但checkpoint、历史版本、candidate read evidence、owner/effect跟踪等编辑专属成本须显式启用或提供经测量无额外成本的等价路径。不得让旧parse(String/InputStream)默认承担全部编辑状态维护；保持既有输出与stream行为。

1. 编译通用facet集合：纯/事务probe、block与nested subunit恢复边界、inline成功/失败读取证据、完整state codec/restore/equivalence、typed node codec、owner effects/正负依赖、派生phase、source map、render/cache/config版本与quota、诊断。具体名称在本任务定稿，不能靠core硬编码内置name/kind/marker。
2. 先冻结edit事务基础值：DocumentId/Version/EditId、坐标种类、半开range/端点亲和、批量edit顺序/重叠策略、非法Unicode切点/CRLF坐标策略、取消/过期/异常结果；区分raw source rune与规范化view坐标。区分accepted sourceVersion与已提交parseVersion/renderVersion：已ack源码不随旧计算取消回滚，失败仅回滚未提交语法/overlay/patch，下一次从最新accepted source恢复。生产API保持1.1.0兼容。
3. 冻结Source/Node/Mapping交接面：版本源句柄、局部slice/cursor/line查找、惰性anchor/resolve、组合map与synthetic来源；raw syntax记录、typed重建/访问、稳定ID与版本父子视图；checkpoint/效果日志使用这些抽象。03只实现source，04只实现tree/document/session存储，不相互修改接口。
4. 将runtime plan从简单列表扩展为可验证能力计划：保持continuation先于leaf、组内升序priority/稳定注册次序和paragraph兜底；phase依赖按显式DAG校验循环/缺失依赖；grammar/plugin/config版本进入fingerprint。legacy parse/stream仍走同一语法内核，不复制editing语法实现。
5. 未知第三方能力不足时提供显式兼容fallback与strict拒绝，诊断owner、缺失facet、成本/范围；strict原子拒绝。对内置建立覆盖登记，迁移能力缺口显式Pending，不允许fallback使30插件完成统计变绿。
6. 定义observer hook接入01计数schema；probe副作用策略、cache key与效果归属、phase输入输出必须可观测，未声明能力不能静默推断。
7. **运行最小typed codec原型**：样本固定覆盖HeadingNode、LinkNode、TextNode、TocNode/TocItem和至少一个容器及其现renderer，与architecture保持一致；尤其TocNode.items独立于children，必须无损恢复，Link/Heading的typed字段不能丢失。验证children、三类metadata、raw/provenance、parent links、稳定ID/source句柄；encode/decode/clone后实际渲染，并修改副本检查无别名污染。验证public String literal与typed renderer cast的桥接，长logical Text内部可分段但legacy observable节点形状保持；无法lazy时使用独立editing record和按需legacy adapter。可用测试Source与树事务假件，但不能声称03/04已经完成。
8. 原型展示state snapshot/restore、owner效果撤销的最小契约；将真实rope+持久tree+checkpoint+替换+rollback的**完整事务原型**明确交给05，05验收前必须实际运行。本任务不以假件替代该后续门槛。
9. 输出公共接口/所有权表及所有30插件facet实施清单，给03/04固定输入；并行A发现接口缺口时暂停相关实现并退回本任务串行修订，不让两个任务同时改shared interfaces。

## Acceptance

### 2026-10-23 本轮修订范围验收（root已审查放行）

- 公共值、版本时钟、Source/Mapping/Tree抽象契约已实际编译；四类parser的默认false/None/None不增加旧第三方必需方法。现有第三方源码未改，parse/append通过。
- 19项`EditingContracts`及6项`TypedCodecPrototype`均实际通过；包括Strict正负向及拒绝原子性、跨文档checkpoint拒绝、所有required flags/owner匹配、未知配置不可缓存、真实bucket-before-any行为、phase DAG、真实typed renderer三输出/TOC额外引用/metadata/source binding/副本隔离。
- 官方27包console完整回归599通过、0失败、0错误、0跳过。最终日志与精确命令见[交付报告](task02-contracts/final-report.md)。先前编译失败和错误测试假设均保留，不能把tag过滤未选中算作最终套跳过。
- 同源、同实际1.3-alpha SDK、同`-O2`的参考/候选各完成两种顺序的简明用时记录。small首轮偏慢在反向未复现，不能区分顺序/调度噪声，不声称已证明无退化或零成本；不追加已取消的大统计/分配框架。
- [03/04所有权与契约](task02-ownership.md)已冻结；root已明确审查通过本轮修订范围并放行并行A。03实现真实源，04实现真实持久树，本任务的桥接原型不冒充其完成。
- 正式1.1.0验证、通用oracle/计数/benchmark扩展由用户取消本轮门槛，标记Deferred by user scope，不写通过；已有事实不抹除。全部30内置仍0/30真实适配，后续不得用默认fallback结项。

### 原验收要求（历史；受上方用户裁剪与当前结论覆盖）

- **新增可选能力硬门槛：** 未修改的真实旧式第三方插件源码在仓颉1.1.0编译、注册、parse与分片append/finalize通过；记录采用的接口/default实现形式及命令，不能仅mock新插件或改旧fixture后声称零迁移。
- **混合plugin硬门槛：** 同一第三方plugin注册支持/不支持增量的两个真实parser，分别选择路径；有完整隔离证明时只对不支持单位full-parse并复用无关单位，无证明/全局副作用时保守整会话重建。结果版本与fresh oracle一致，诊断包含范围和证明依据。单独把supportsIncremental设true而缺restore/effects不可通过能力校验；strict拒绝无source/ID/state/patch变动。

- **新增硬门槛：** 原型展示batch不启用编辑专属记录，或用01同`-O2`配对结果证明等价路径满足冻结预算；语法实现未复制，旧API结果不变。性能未测不能以“只是接口”直接放行。

- 小型可跑验收：注册两个测试插件（规则只在插件中），验证同priority注册稳定性、continuation/leaf类别顺序及phase依赖；构造循环或缺失codec/facet产生明确诊断，core没有测试marker专用分支。
- 一个缺facet第三方插件：compat模式报告可解释fallback；strict模式拒绝且源版本、NodeId、状态、patch均未改变。内置能力缺口不能被该路径掩盖。
- 最小typed codec原型在仓颉1.1.0实际编译运行，覆盖HeadingNode、LinkNode、TextNode、TocNode/TocItem与至少一个容器；真实renderer仍能cast并产生一致输出。Toc.items非children载荷、Link/Heading typed字段、children/metadata/raw/map/parent/ID与String桥接均受断言，故意丢字段或Toc.items会失败；不能仅任意两个简单子类通过就放行。
- snapshot/restore契约包括真实payload、fingerprint与源版本/嵌套上下文边界；不能只存名称，不能依赖不可恢复浅拷贝。accepted source可领先parse/render；取消旧计算不丢已ack输入，不发布旧结果冒充新版本。
- Source/Node/Mapping接口、edit合法性、effect/negative dependency、read evidence与observer schema已冻结并审查；03/04有互不重叠文件表。01 legacy四模式无新增未解释差异。
- 全事务原型明确属于05放行条件，02假件结果不冒充03/04/05完成；无30插件大规模实现、最低版本提升、前端语法特判或生产editing完成声明。

## Verification Record

- 本轮：仅静态读取PluginRegistrar、MarkitRuntimePlan、SessionState、BlockFrame、InlineParser及typed renderer相关实现；未实施新协议，未运行原型或新测试。
- 未来在`markit/`执行`cjpm test --no-progress`和现有Streaming测试；同时记录`cjc --version`与`cjpm --version`，最低1.1.0须实际验证。
- 拟新增：`cjpm test --no-progress --include-tags=EditingContracts`与`cjpm test --no-progress --include-tags=TypedCodecPrototype`；tag实现后执行，报告原型使用的假件边界及真实renderer结果。
- 静态审查：`rg -n 'HeadingPlugin|ReferenceLinkPlugin|FencedCodeBlockPlugin' markit/src/core`检查新增边界调度是否依赖内置名；实际review需区分既有代码/注释/测试，不能把零匹配当唯一中立性证明。
