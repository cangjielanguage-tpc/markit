# Markit 编辑增量解析执行方案

## 当前执行状态（2026-10-23，协调者维护）

### 最终暂停与提交范围（用户最新指令，2026-10-23）

**现在停止所有源码修改和新增功能，只记录问题并提交推送当前工作快照。** Task07 为暂停的部分实现，不做完07，不启动08/09或后续任务。此前“完成Task16再停止”“完整Task07完成再停止”及“tasklist仅本地、不提交”的安排均已被本条覆盖。用户明确要求将当前计划Markdown纳入提交；共享ignore不改，精确加入文档，排除传输JSON、日志、临时目录、备份、SDK及构建产物。

| 范围 | 已验证或当前状态 | 尚未完成 |
| --- | --- | --- |
| Task01–06 | 已按当时修订范围验收；Task06正常whole4编译成功，官方25/25、27包717/717，0失败/错误/跳过；148条×11字段与冻结01零差 | 这些结果属于已记录的Task06冻结版本，不能背书后来07改动后的整个工作树 |
| Task07 Standard | 4个插件域已有部分适配源码：Paragraph、Heading、ReferenceLink、Blockquote；SoftBreak/共享inline plan产品定向3/3通过 | **完整插件验收0/13**；剩余9个Standard插件未展开，4个当前域也未完成联合验收 |
| Task07核心补口 | 先前7包一致类型编译成功，限定stage3核心定向21/21通过 | 后续capture/semantic refresh/离散重放/boundary等变更未完成最终一致回归，不继承旧版通过结论 |
| 独立协议探针 | transport/source子集16/16；真实SessionProbeBackend仅编译通过 | 未接真实Standard profile/typed renderer实跑；不是正式worker或完整07-P验收 |
| 主构造函数写法 | markit原正常回归覆盖已转换源码；自有库890/890、commandline70/70、fswatch55/55、live-server编译通过 | kit/CLI/dochir等未完成独立正常项目验证；不声称所有项目已通过 |
| Task08及后续 | 保留Pending，本次不启动 | 仍须按依赖执行；**完整07验收后**08/09/10才可在文件所有权不冲突时并行，不能以编号相邻直接越过07 |

#### 本次原样保留的已知问题

1. **已知构建缺口：** `plugins/standard/pilot/standard_pilot.cj` 调用尚未创建的 `renderStandardPilotSnapshot` / `renderStandardPilotChanges`；工厂没有完成交付。
2. **已知构建缺口：** Reference新版消费 `StandardRawSpellingProof` / `standardNormalizedRaw`，共享helper没有提供这些接口。此次不补实现、不伪造默认结果。
3. **Paragraph首轮真实运行未通过：** 3项为0通过、2失败、1错误。编辑会话创建时未给root绑定render hooks，导出缺少`<p>`而fresh parse有；大文本不等的测试差分又触发SDK MultilineDiff OOM。原输入、检查条件和失败日志保留。被中断的hooks补丁经SHA核实未落盘，此次不重试、不改源码。
4. 同unit多range/batch编辑可能因去重保首计划而漏第二处修改；需要真正old/new/source版本映射，不能只给current范围或用min/max整owner扫描掩盖。
5. 新semantic读刷新与同key离散reader重放已有部分源码，但最新版本未一致实跑；r/s读边保留、中间无关reader复用仍须真实验证。
6. 跨行/quote引用的normalized raw proof尚未闭合；有远处escape时当前literal路径仍可能重解码整个logical Text。只证明无slash巨型Text的局部定向用例，不能推广为全部输入性能已达标。
7. typed snapshot局部渲染、真实stdio产品纵切及后续工作仍未完成。整体内置插件仍**0/30完整验收**，不能把默认fallback、源码落盘或类型编译算插件完成。

**本次不再做额外整编或测试修复。当前提交是明确的WIP工作快照，存在上述构建缺口，不声称可构建或全测试通过。** 已有日志与二进制证据继续留在本机；本次仅加入计划/报告Markdown，不提交本地临时验证产物。

可恢复保全位置：`C:\Users\Shawn\markit\tasklists\.delivery-preserve-20261023T095707951Z`。428份文件（含一个不提交的临时Markdown探针）、3,901,800字节，复制前后SHA/大小全部一致；manifest SHA256 `d8fe2be6d011f3cf6e8447e93017531c1d5c7ea4a182065fa47bb91591d0a169`。未回退或丢弃07工作。下面的执行记录均按各自版本理解；冻结前owner均已停止产品写入。


用户最新裁剪优先：停止补最低SDK兼容验证，停止扩展通用oracle/计数/benchmark框架。保留已测`-O2`用时、实际环境、最小复测脚本，以及产品所需的最小定向测试、全量结果对照和同条件用时比较。取消/未验证事项记为 **Deferred by user scope**，不算通过，不阻塞核心实现。第三方parser可选增量、安全默认与正确回退设计继续有效。

**30个内置插件必须全部实际适配：** 默认`supportsIncremental=false`与安全fallback仅为外部第三方兼容出口，不能把任何内置停在该状态并声称完成。Task02接口不计插件适配，当前为 **0/30已验收**（Standard0/13、CommonMark0/5、GFM0/9、横向0/3）；07–13按清单逐项实现并验证，不以blanket full-session fallback替代。真实广范围传播需记录实际依赖和触发原因。

**当前最终结论以本节暂停记录为准：Task01–06已验收；Task07部分实现暂停，完整验收0/13，不启动08/09，按用户要求记录问题后提交推送当前WIP。** 下列为冻结前的历史验证依据。

| 冻结前owner（均已停止）                          | 独占产品范围                                                                                                            | 实际状态                                                                                                                   |    |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | :- |
| `task03_source`                    | `core/source/` rope/store、坐标、anchor及source定向测试                                                                 | Done；独编13/13、共享source包21/21和最终632全量已审，交接冻结                                                              |    |
| `task04_tree` | Paragraph payload/facet/initialhandoff/集成；原nodes/codec/doc及必要core inline session/facet唯一writer | Paragraph阶段1源码已Ready交02；新增captureChildren/语义read outerOwner补口在窄窗口，保raw child Link.id、默认旧调用不变；后续一致闭包和真实pilot待跑 |
| `task07_inline_plan` | new standard/editing/standard_inline_plan.cj、已有SoftBreak两文件及独立定向test | 已实际启动；固定plan.create/paragraph mapped view/escape metadata真实proof，与04和Quote直接交接，不并改Paragraph/core/shared recovery |
| `task04_tree/standard_heading` | standard/block/heading/**与task07_heading_editing_test.cj | 真实目录compile7 exit0；持久index/typed semantic更新已接，7case未运行。普通正文hidden可见性需绑定immutable snapshot index，由04最小render集成 |
| `task04_tree/standard_reference` | reference_link/**与5tests；owned_effect_store.cj唯一writer | 真实目录compile6 exit0；reorder投影重入修s6 sessiontype0，5case尚未实跑；nested label read改外层semanticOwner消费待04窄core接口 |
| `task07_protocol` | task07-protocol/**独立driver/probe/同15schema交接 | 最终compile5/verify5 exit0、transport16/16已审；真实SessionProbeBackend静态库compile0但provider未跑。待StandardEditingPilot工厂/render签名，有限交付已完成、无未知操作 |
| `task07_blockquote` | standard/block/blockquote/**与task07_blockquote_editing_test.cj | 已实际启动，复用冻结recovery签名做真实mapped nested child恢复；不改shared/core |
| `task03_source/source_map`         | `core/source/editable_source_map.cj`与独立map测试                                                                       | 已完成冻结；5例计入首批11/11，通用组合映射不识别Markdown语法                                                               |    |
| `task04_tree/effects`              | `core/session/owned_effect_store.cj`、`persistent_cache.cj`与独立tests                                                  | 独编和官方测试9/9通过，0失败/错误/跳过；真实source生命周期接线待05                                                         |    |
| `task_a_review`                    | 只读06窄预审、独立工具正常验证、旧helper两文件写法收尾                                                                  | view/index已静态审；工具commandline70+fswatch55全过/live-server build0，dochir/CLI等稳定依赖窗                             |    |
| `task02_contracts` | block_editing_facet.cj + document_editing_session.cj；共享产品编译/验证唯一owner | 首版7包compile0、官方core21/21（0skip/error/fail）已审；helper mutable capture类型错由04已修，Heading/Ref独立包编排中。新capture/effects重入修仍需新闭包 |
| `task05_engine`                    | 原06主owner，容量恢复未产出后已由root暂停写入                                                                           | 原prepareCore/rebuildWindow保留核验后移交04；block/incremental/Markit桥接移交CP；不再并发写同文件                          |    |
| `task05_engine/session_checkpoint` | 桥接产品已冻，原recursive/helper owner已因capacity停止 | 原递归syntax1/1及桥接3源码保留；最后3fixture写权转04，index hasReadingKey转02；不恢复并写、不把未验项当通过 |    |
| `task05_engine/source_lifecycle` | 已冻view7及core/source写法收尾 | view7/7已通过；source11文件23类型新写法已随06正常whole及717全量通过；当前无待写产品 |    |

06当前集成证据：[基础18/18](task06-verification/inline-core-test-2.log)已由root读取；新source/nodes/document/session/render/block一致闭包各compile0。首次完整inline编译的capture Option不协变错已修；[inline第二次编译exit0](task06-verification/main-inline-compile-2.log)，同版含snapshot私有brand、attempt/proof单调闭包、literal来源持久ID集合三修。plugin/incremental及顶层Markit亦类型compile0；顶层使用未改builtins旧类型仅查接口、不运行混合产物，最终whole重建一致运行产物，不把类型检查当实跑。非恒等literal的raw保真/坐标切片、递归子owner真实局部handoff及bridge实跑仍未完；主4例随后已实际通过。07:14 UTC Windows瞬断后已核仓库、源码hash与无遗留compiler；主/bridge test文件当时均未创建，已确认grammar returnsText小修成功，不重复写入。原main容量恢复无产出已暂停，04/CP按不重叠产品文件继续，02唯一构建，无当前本机权限阻塞。

05:15 UTC重连后root已核原仓库/HEAD `c510aee`、Git未提交修改、README与已完成日志；无遗留cjc/cjpm进程。断连未回传操作已由各owner按成功回执/文件实际状态区分，未重复补丁。当前无外部权限或SDK阻塞。先前[官方source/session合跑23/23通过](task05-verification/source-session-test-1.log)后，新doc4与session清context引用版一致编译，最新[core官方37/37通过](task05-verification/core-test-1.log)，0失败/错误/跳过、exit0（kernel5、atomic9、checkpoint15、retention8）；其后[aux4/4通过](task05-verification/aux-test-1.log)，含祖先effect保留断言，root已读编译及运行日志。主incremental stage3编译exit0，主15/prepare3和全量待验证；发布后清理/lease失败重试边界做最后必要修正，源码统一冻结后整编。构建失败日志保留，未用类型编译冒称测试通过；06仍未放行。

最新整编/运行：[whole1编译exit0](task05-verification/integrated-compile-1.log)，[BlockEditing定向选中39项：37通过、2失败](task05-verification/editing-engine-test-1.log)，exit1；98项是tag未选，不计实际跳过的验证成果。失败为两个nested fresh导出对照：捕获的source-backed祖先rawContent override仍旧，子单位/ID复用断言已过。现修复已冻结：[whole2正在编译](task05-verification/integrated-compile-2.log)，codec默认未知、不猜第三方virtual getter或mapped source，明确opt-in并匹配真实source identity后才在显式导出刷新；capture仍冻结旧raw，旧shallow/快照稳定，不热拼祖先文本。主fixture含opaque旧checkpoint，已诚实用默认保守history pin，不冒称raw-only证明。原fresh断言保留，完整全量与同O2比较待结果。

后续真实运行：[主39/39通过](task05-verification/editing-engine-test-2.log)；[27包全量691通过/1失败](task01-baseline/task05-full-console-1/summary.json)，0错误/跳过，unit137全部通过。失败仅原AutoAnchor nestedParagraph输出；[148条冻结记录对照](task05-verification/legacy-comparison-1/versus-frozen01.json)仅edge-2四mode AST源坐标漂移，HTML/Markdown/Typst/tree等保持，原3fragment差与2重复ID保留。原因是旧legacy成功nested原只恢复depth，而新完整restore改变了旧activeLine副作用；现将完整恢复限定到显式editing/sandbox，旧入口成功保持原语义，异常安全恢复，不写Markdown特例、不修改原anchor期望。待修后正常编译/定向/全量重跑。

Task05最终审结依据：[whole3编译exit0](task05-verification/integrated-compile-3.log)、[主39/39](task05-verification/editing-engine-test-3.log)、[anchor9/9](task05-verification/legacy-anchor-test-1.log)、[27包692/692](task01-baseline/task05-full-console-2/summary.json)、[148条11字段零差](task05-verification/legacy-comparison-2/versus-frozen01.json)。[原driver同O2一次AB](task05-verification/batch-time-comparison.json)各84 samples、exit0：small String mean25.991→27.400us、Stream26.945→27.752us；large String27.252→26.451ms、Stream27.224→28.200ms。具体偏慢数据保留，不把单次有快有慢记录说成统计无退化；按用户裁剪范围只保原条件可复测记录，不追加框架/采样。以上通过后放行06；内置插件适配仍0/30，必须后续真实落实。

### 独立工作：整仓主构造函数统一

用户追加授权对本仓库自有Cangjie源码做安全转换；直接与产品实现一起改，属于纯写法整理，使用正常编译回归，不另设阻塞阶段或大型验收。不碰第三方/vendor、生成物及外部stdlib，不混入增量任务完成率。保持API可见性、默认参数、重载、初始化顺序、异常与副作用、继承调用、可变性和性能，不适合者保留并简记原因。Task16验收前覆盖安全范围，不放行17/18、不提交推送。

| owner | 范围与当前结果 |
| --- | --- |
| `source_lifecycle` | 7个非热generator/utils/benchmark文件已随whole通过；markit-kit17文件22类型已冻结待项目验证；core/source新11文件23类型已随06正常whole编译及717全量通过 |
| `task_a_review` | 自有plugins区101文件117类型已转换冻结，余126文件无显式构造；保留I18n第2重载；随普通whole验证，不提前实现07插件适配 |
| `task04_tree` | core/render、parse_callbacks/output、bundles/dsl的13文件17个单构造已转换冻结；DslDocument重载与storage待后续正常写窗，inline留06 |
| `session_checkpoint` | 已核归属并转换codehl/mathtex/mermaid4cj自有55文件193单构造，排除全部上游assets；三个库正常编译及890/890回归通过；core/session按原所有权继续 |
| `task_a_review`（工具后批） | commandline/CLI/dochir/fswatch/live-server自有23文件46类型已转换冻结，宏生成secondary构造契约保留；commandline70/70、fswatch55/55通过，live-server build0；dochir/CLI等markit依赖稳定窗 |
| Task05各唯一owner | 各自正在改写的block/incremental/session/source/tree/document/Markit文件，下一必要编译窗口顺带安全转换；不跨文件所有权 |
| `task02_contracts` | 自有editing/registry契约5文件20类型已转换冻结；首10纯值已随whole1编译，后10保序body待下一轮；不增验收设施 |

状态：分区盘点和并行转换已启动，随产品正常编译回归核验，不暂停增量关键路径。

Task02证据已由root审阅：25/25定向通过；27包599测试通过、0失败/错误/跳过。最小同源同SDK`-O2`正反两次数据均保留：首轮small均值偏慢在反向未保持，反向String27.706→27.193us、Stream29.677→29.609us，大文档约28ms。该简明记录不作统计无退化/零成本证明，不再扩框架；见`task02-contracts/batch-time-comparison.json`与`batch-time-comparison-reverse.json`。共享接口、CRLF/坐标/同点插入/空batch政策见[交接](task02-ownership.md)。

并行A实测：独立[source 13/13](task03-source/source-targeted-test-3.log)与[effects/cache 9/9](task04-effects/effects-targeted-test-1.log)通过；最终统一编译exit0，共享[source包21/21](parallel-a-verification/source-package-test-1.log)及effects9例通过。tree首轮10/11失败保留，确认After亲和+闭区间预期后补精确ID/端点/reference，修后[11/11通过](parallel-a-verification/persistent-tree-test-2.log)。tag未选出的66/68项不算本次通过；最终[27包632/632全量通过](task01-baseline/parallel-a-full-console-1/summary.json)，0失败/错误/跳过。最终1MiB源400次单字替换最小`-O2`记录rope 7.679/4.049ms，对照String 240.068/255.121ms；04 4096节点120次局部替换0.492/0.267ms，对照fresh重建466.556/422.729ms，均完整核对最终值。04 [最小计时](task04-tree/local-edit-time.csv)编译/执行exit0。仅说明具体操作负载，不外推端到端延迟。现已放行05，没有权限阻塞；compile-2/3/4与首轮测试失败日志保留。

性能实现依据：用户提供只读标准库`C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`，按实际字符串/集合操作选择性看复制、扫描、扩容及别名。争议只最小实测，不全面研究或造框架。源码清单1.2-beta与实际1.3-alpha对应未证实，Git元数据被拒绝已停止，不能当二进制保证；[定向笔记](stdlib-performance-notes.md)已交03/04及02owner。

### 已测最小基线

本机i7-8700、12逻辑CPU、约32GiB内存；Cangjie `1.3.0-alpha.20260920003052` / cjpm `1.3.0-alpha.05`，同`-O2`，parse-only，不含渲染/CLI启动。12进程1008样本，系统背景CPU26–40.6%，原始数据全部保留。

| 输入 | parse(String) median | parse(InputStream) median |
| --- | --- | --- |
| 120 bytes | 25.467us | 26.916us |
| 62462 bytes | 27.784ms | 27.844ms |

复测入口、参数与限制见[最小交接](task01-baseline/minimal-handoff.md)。不得跨SDK比较，不设自行允许的回退百分比；这些是原有batch结果，不代表编辑功能或迁移后无退化。

已有证据：原有回归569通过；新设施当时592通过；148条四模式记录完整；Windows测试harness最终73项67通过、0失败、6既有skip。三份通用新源码已按裁剪[可恢复归档](task01-deferred-scope/move-manifest.json)，移动后未追加回归；最小旧插件fixture保留。最低SDK项目验证、`@Bench`失败与其余过度设施均延期，不伪称通过。历史命令、失败原因和完整证据见[验证记录](verification-log.md)。

### 同步来源与保护

本地传输JSON为359959字节，SHA-256 `01fa0b048906e6b5b9e7eb26ca21a832d694ad6da5057a793996d13b1fdba524`；29份计划逐文件大小/哈希及路径安全核验通过后同步。来源是恢复评审版及后续明确修订记录，不声称与丢失云端原文件逐字节相同。起始HEAD `c510aee2e5bbbdb04402cb26bbca6679515a16f4`，Git clean。用户要求不保留本次两份旧计划备份，已再次校验后连同清单移入Windows回收站，未永久删除或清空回收站；最新JSON与当前计划保留。

下文2026-10-21/22的仅文档授权、旧dirty清单和扩大的基线门槛均为历史记录，由当前用户裁剪说明覆盖；产品设计、第三方安全回退、07-P纵切、既有映射/渐进首屏/复制/动画/无白屏刷新及其余依赖继续有效。

**2026-10-22评审更新：** 请先读[最新基线、SeaJson选型与三项补强](review-2026-10-22.md)。当前核对基线为clean `c510aee`；下文2026-10-21 dirty情况及28文件校验均是历史记录。用户最终选择现有SeaJson 1.5.0 + 自实现Content-Length stdio，不引入rpcx或新stdx依赖。方案实施仍为Pending。

更新：2026-10-21。当前交付：设计与任务文档；**实现进度 0%，尚未开始改造解析器**。

目标是由 plugin 定义语法及其增量能力，让常见编辑只重解析受影响的语法区域，并将收益延伸到语义、渲染、CLI 和 VSCode 预览。初次打开允许完整解析和项目索引；后续编辑应复用进程、源索引、未变语法树及渲染结果。

本方案以本地 `codex/vscode-live-preview` 分支 `795a0e835b0e0ab6433f594e8603dbec0f28e2dc` 及调查时的未提交修改为依据。CLI 的 `--page`、kit 的单页渲染和未跟踪的 `vscode-extension/` 是现有工作的一部分，不能把它们误当成已合入版本或已实现编辑增量。实施前须重新记录 HEAD、工作区差异及运行环境，保留用户修改。

本目录采用用户确认的名称 `tasklists/incremental-parsing/`。整个 `/tasklists/` 已通过仓库本地 `.git/info/exclude` 排除，不修改共享 `.gitignore`，不提交这些文档。

## 阅读入口

1. [设计锁与禁止方向](00-design-locks.md)：所有任务必须遵守的边界。
2. [具体架构与编辑算法](architecture.md)：插件能力、源与树模型、检查点、依赖、协议及预览链路。
3. [执行依赖和并行波次](implementation-order.md)：先冻结共享契约，再释放隔离任务。
4. 逐插件适配：[Standard / CommonMark 18 个](plugin-standard-commonmark.md)、[GFM 9 个及 CodeHL / MathTex / Mermaid](plugin-gfm.md)、[i18n / AutoAnchor / TOC 3 个](plugin-cross-cutting.md)。
5. [验证记录](verification-log.md)、[尚缺证明](verification-gaps.md)、[范围边界](out-of-scope.md)。

## 本次已落实的任务调整（2026-10-22）

- **parser级增量可选：** BlockParser等提供默认false能力设置及安全默认方法；旧插件不改源码，同一plugin可混合支持/不支持的parser。只在边界/状态/语义隔离已证明时局部full-parse，否则整会话回退；strict显式启用。1.1.0语法待02实证，30内置目标不变。

- **CLI迁移已确认：** 预览统一worker --stdio，自动资产/cache、URI选择文档与渐进首屏多次原子事务；CLI+扩展迁移通过后淘汰--preview-stream/--incremental。保留render/build文件输出、render --page独立构建、Markit append API及内部build增量能力；本次仅改计划，尚未删除代码。

- 01/02/17：同`-O2` batch解析基线与不退化门槛，编辑专属记录不得默认拖慢batch。
- 05/07：语法收敛与语义传播分开验收。
- 06完成后先运行07-P真实插件/renderer纵切与最小stdio测试探针，通过才展开07剩余适配；正式18任务hard edges及30插件最终范围不变。
- 15：SeaJson 1.5.0 + 自实现Content-Length stdio依赖、限额、部分读写及错误验收。
- 本次仅调整计划，不授权或声称已实施产品改造。

## 当前判断

- 源码中有 **30 个内置 Plugin**：13 个 Standard、5 个 CommonMark、9 个 GFM、3 个横向插件。Mermaid 通过 FencedCodeBlockPlugin 接入，不额外计数。
- 现有 `IncrementalSession` 支持追加输入，不能替换已输入的区域；目前预览修改会启动新 CLI、重解析当前页，并执行项目标题扫描。
- 现有状态快照没有完整恢复协议；隐藏节点、引用解析及 i18n 附件还涉及不可逆修改旧树。需要先分离原始语法事实与可撤销语义派生结果。
- 嵌套 synthetic source、绝对偏移、顺序 NodeId 和全树 snapshot 索引会阻碍可靠复用；这些基础设施是前置工作。
- CodeHL 已有逐行 tokenizer，但缺少行状态缓存与编辑收敛接口。MathTex 与 Mermaid 可先按独立公式/图缓存，变更的单元允许完整重算。
- 本轮只做源码盘点和方案文档校验；不将历史测试数量、旧流式 benchmark 或单页渲染时间当成本方案的通过证据。

方案文档已通过协调审查和独立交叉复核：28 份文件、18 项任务的必需章节与双向依赖一致，22 条依赖边无环，30 个插件逐项覆盖，本地文件及标题目标链接检查通过。28 份文件均被本地规则忽略，Git 未跟踪 `tasklists`；实现任务仍全部为 Pending。详见验证记录。

## 完成的含义

所有内置插件都进入正式增量协议。普通正文、列表项、表格行和代码行编辑应在安全边界内复用后缀；不能把每次整段长 paragraph、整 quote 或整 list 重解析作为最终性能成果。删除 fence、改变标题可见区间等操作确实可能传播很远，必须记录真实影响及传播原因。

解析核心只调度插件提供的边界、状态、效果和依赖；CLI 与 webview 只消费协议及 source map。不得将 Markdown 标点、插件名称或节点 kind 的特殊判断搬进这些层来决定重解析边界。能力不足的第三方parser允许有隔离证明的安全单位完整解析、无证明时会话重建，或显式strict拒绝，不能借此跳过内置插件适配。

最终验收同时检查全量结果等价、稳定身份、精确源映射、工作量计数和端到端延迟。拟议目标为 warm 普通局部编辑 native p95 ≤30ms、预览可见 p95 ≤100ms、webview patch p95 ≤16ms；**尚无实测结论**，需在指定硬件及负载下验证。

## 执行职责

- 主协调 agent：安排依赖、分派子任务、审查交接与验收证据、更新本表及报告。
- 子 agent：只执行被分派任务的实现、文档和任务级验证，返回修改清单、命令结果、阻塞和新增依赖。
- 表内全部是将来的实现任务。调查和文档完成不等于实现任务完成；只有协调 agent 审查验收证据后才能更改百分比。
- 并行任务必须有互不重叠的可变文件所有权；共享接口调整退回前置契约任务或排入串行集成，不以并行名义同时改共享文件。

## 任务状态

依赖为硬依赖。波次及每次审查门槛以 [implementation-order.md](implementation-order.md) 为准；数字顺序不能替代依赖声明。

| 进度 | 任务 | 状态 | 依赖 | 执行 |
| --- | --- | --- | --- | --- |
| 100% | [01 基线、差分 oracle 与计数设施](01-baseline-oracle.md) | Done（用户修订范围） | 无 | 已实测用时/环境/最小复测脚本；取消设施不算通过 |
| 100% | [02 插件能力契约与 runtime plan](02-plugin-contracts.md) | Done | 01（修订范围已审查） | 25定向/599全量通过，最小正反用时记录已审；接口冻结 |
| 100% | [03 可编辑源、坐标索引与组合映射](03-editable-source.md) | Done | 02 | 并行 A；13新定向/21source/632全量及最小O2已审 |
| 100% | [04 持久语法树、身份与效果存储](04-persistent-tree.md) | Done | 02 | 并行 A；11tree/9effects/632全量及同O2已审 |
| 100% | [05 块级编辑事务与检查点收敛](05-block-edit-engine.md) | Done（当前裁剪范围） | 03、04 | whole3/主39/anchor9/27包692；148×11零差；原O2一次AB已审，非统计保证 |
| 100% | [06 inline 候选与安全窗口](06-inline-edit-engine.md) | Done | 05（已审） | 统一25/25、27包717/717、148×11零差及原O2记录已审；07-P已放行 |
| 部分，0/13完整验收 | [07 Standard 13 插件适配](07-standard-adapters.md) | Paused | 06（已审） | 4插件域有适配源码，联合验收未完成；已知构建/测试问题见顶部，停止修改并提交当前WIP |
| 0% | [08 CommonMark 5 插件适配](08-commonmark-adapters.md) | Pending | 07 | 并行 B |
| 0% | [09 GFM 4 个 block 插件适配](09-gfm-block-adapters.md) | Pending | 07 | 并行 B |
| 0% | [10 GFM 5 个 inline / 脚注插件适配](10-gfm-inline-adapters.md) | Pending | 07 | 并行 B |
| 0% | [11 i18n 效果与语言投影](11-i18n-projection.md) | Pending | 08、09、10 | 并行 C |
| 0% | [12 有序语义、AutoAnchor 与 TOC 查询](12-derived-queries.md) | Pending | 11 | 串行集成 |
| 0% | [13 CodeHL、MathTex 与 Mermaid 复用](13-render-services.md) | Pending | 09、10 | 并行 C |
| 0% | [14 持久项目索引与 workspace](14-project-workspace.md) | Pending | 12、13 | 串行集成 |
| 0% | [15 持久 CLI worker 与版本协议](15-cli-worker.md) | Pending | 14 | 串行 |
| 0% | [16 VSCode 增量预览消费端](16-vscode-preview.md) | Pending | 15 | 串行 |
| 0% | [17 全插件差分、压力与性能验收](17-validation-gates.md) | Pending | 16 | 串行验收 |
| 0% | [18 API、文档与交付门槛](18-api-delivery.md) | Pending | 17 | 串行交付 |

任务 07 先提供冻结的 Heading、嵌套解析、标准节点 codec 和跨插件依赖接口，08/09/10 才能安全并行。任务 11 与 13 分别拥有语言投影和重型渲染服务，避免共同修改插件状态文件。12 必须使用 11 输出的语言投影；14 必须同时接收 12 与 13 的验收结果。
