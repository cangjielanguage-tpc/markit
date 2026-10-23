# I18n、AutoAnchor 与 Toc 的完整增量适配

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本清单逐个核对AutoAnchor、I18n、Toc三个横向插件的实际注册能力；不得要求它们伪造语法parser，也不得借此免除效果、依赖和派生结果的增量适配。

更新时间：2026-10-21。本文是实施方案和验收依据，所有“拟议”接口/阶段尚未编译实现。事实来自当前工作区；本目录三组各只有一个 `Plugin` 类，共三项，相关parser/state/filter/finalizer/renderer/query也在适配范围。

共同前置：[架构方案](architecture.md) 的不可变lossless syntax、可撤销overlay、稳定ID、版本化源/组合source-map、typedcodec/view原型、逐facet contract、完整checkpoint和依赖负查询。内置三插件不得只声明整会话fallback后记为完成。

## 1. 当前语义次序与兼容锁

现有 runtime 顺序有实际语义：parser创建语法和session state → detached parse内node batch processors → top-level emission filters按注册次序接受/吞节点/修改前文 → EOF关闭open block和paragraph → session finalize hooks按注册次序 → post-finalize hooks按注册次序 →调用方查询TOC/渲染。见 `markit/src/markit.cj:73–135` 与 `markit/src/core/incremental/incremental_session.cj:62–91,291`。

不能把设计中逻辑上的“语言、heading、anchor、TOC”随意重排并改变全量输出。bundles在较早位置注册AutoAnchor，CliMarkitFactory先use bundle后use I18n，因此当前AutoAnchor post-finalize可能先于I18n post-finalize执行；i18n emission阶段已提供部分显隐/结构信息，两阶段不是可互换的单个filter。Task01先记录每种bundle/config/注册组合的真实注册trace和最终输出oracle；Task02再将hook转为有owner、priority、ordinal、reads/writes、before/after约束的冻结phase plan，依赖声明与legacy顺序冲突时显式诊断或提供经oracle证明语义等价的适配。Task11/12采用可撤销依赖图维持old observable semantics，不悄悄修复旧语义。若要调整语义，必须单独列明产品变更，不能夹带在增量迁移内。

拟议phase graph可按下表表达，但每个阶段内部须保持原有priority/ordinal；若依赖与当前结果冲突，先保留旧行为并记录冲突，不以名称分支修补。

| 逻辑阶段 | 拟议输入/输出和撤销边界 |
|---|---|
| S syntax | lossless原始树、插件payload、synthetic映射、语法state贡献；不丢被过滤原节点 |
| E emission/structure | 按现有filter/batch顺序生成结构overlay、deferred emissions、可见候选；可反向修改拥有的旧目标 |
| F session-finalize | forward references等EOF派生贡献，保留原syntax；编辑会话为provisional |
| P post-finalize | 按冻结兼容次序执行插件owned overlay（含anchor与i18n postprocessor）；每facet可撤销/replay |
| Q query projection | typed可见heading投影、TOC、文件heading/link索引；只消费已提交的overlay版本 |
| R render | 订阅实际读取的syntax/overlay/source-map/config keys，按变更单元输出请求格式 |

除新parse失效外，依赖传播可以触发F/P/Q/R局部replay；所有贡献带owner/facet/version和撤销journal。不得把整树postprocessor在每edit重新调用当作已完成激进增量。

## 2. I18nPlugin：全facet清单

### 2.1 当前证据

`markit/src/plugins/i18n/i18n_plugin.cj:41` 注册I18nSessionState、I18nInlineParser、I18nBlockParser、I18nEmissionFilter、session-finalize、post-finalize，以及I18nInline/UniversalInline/I18nBlock/UniversalBlock四kind的HTML/Markdown/Typst renderer，插件版本2.0.0。

| Facet | 当前行为与缺口 |
|---|---|
| inline parser | `inline/i18n_inline_parser.cj:37`识别`:language{content}:`/通用inline，支持嵌套花括号/转义，不跨行；consumer不得复制其正则 |
| block parser/frame | `block/i18n_block_parser.cj:31,100,122`识别`:::language`/通用块、缩进和closing；未闭合在:145回paragraph，编辑闭合符可影响到EOF |
| state | `i18n_session_state.cj:12`含pendingTopLevelLists、pendingDefaultAttachments；snapshot在:63只dynamicName，不含数据/恢复 |
| filter | `i18n_session_state.cj:20`吞当前节点、附着/合并到旧列表；:168修改旧目标/源span并发replace；:205继续合并同类前序列表 |
| session-finalizer | :54 flush pending默认附件，可能修改已经输出的列表 |
| post-finalizer | `processors/i18n_post_processor.cj:24`全树标语言和render，:92按可见heading文字重排重复slug/Typst label |
| renderer | 依赖继承语言、target、render、结构overlay及子节点，三格式都要保留；隐藏的语法仍应可恢复 |

I18n state还通过ParseSession的topLevelIndentedBlockStartsAllowed影响后续block能否启动（`i18n_session_state.cj:373,379`）。checkpoint必须恢复此context flag，不能仅clone两数组。现有pending存活Node引用，改为稳定ID+版本引用/持久贡献root，避免旧snapshot被新edit污染。

### 2.2 拟议状态、撤销与依赖

I18nBlock frame的persistent snapshot包含opening anchor、languageId/universal、indent、content line anchors、closing状态和source-map。state checkpoint包含pending list stack（listId、patchTargetId、有效indent/族）、pending默认附件ID、有序语言/继承context、deferred emission及相关parse flags；共享未变persistent根，不每边界clone整表。

原始树保留默认段落、翻译块、列表和所有原始归属；E阶段overlay记录“合并item/移动附件/隐藏原节点/替换默认附件/tight override”贡献。撤销只清该facet拥有的贡献，恢复前序结构后重放，不把同一个child重复add进缓存列表。把修改旧patchTarget的区域纳入transaction write set，发稳定ID的move/meta/replace patch；不只发布当前新节点。

语言annotation和显隐为可撤销overlay键，父容器聚合child visibility；从changed child向祖先传播直到聚合值不变。语言切换使相关render投影失效，原始语法可复用；但当前i18n state参与结构和块启动判定，不能未经证明就承诺语言切换只render。受target影响的E/state区域需从有效检查点replay，再在同构语法区域复用S记录。

visible heading text/baseSlug/occurrence/Typst label贡献进入有序heading索引；改变某baseSlug的一个贡献只重排同baseSlug受影响后续项，编号/section规则另行传播。TOC、文件heading索引和link订阅slug/visibleText/version；不存在目标也登记负查询。默认语言/target/config fingerprint包含在相关state/overlay/cache键。

旧postprocessor的setRenderFlags只写false、不完整清旧值（`processors/i18n_post_processor.cj:58`）；必须先撤销owned overlay再replay，不能在旧节点上直接重跑导致已可见内容继续隐藏。

### 2.3 source map与缓存

I18n block内容去缩进后经SyntheticSourceBuilder重建0起坐标（`block/i18n_block_parser.cj:84`、`core/source/synthetic_source_builder.cj:40`），冻结rawContent不等于映射。拟议生成每行generated→original映射，组合nested list/quote/i18n映射；inline内容映射保留开闭delimiter/brace escape和UTF8/rune/UTF16差别。被移除的prefix映射边界有明确亲和性；所有公开anchor/source-map必须回原始文档。

缓存分syntax（内容、frame/context、parser fingerprint）与overlay/render（language/target、child visibility、结构贡献版本、heading依赖、renderer/config）。前方只移动位置不重做inline识别或高亮；source-map按anchor解析。消费者`vscode-extension/media/selection.js:24`现有i18n regex必须删除，用原生source-map替代，不能为新语法另添前端识别器。

### 2.4 编辑案例与可验证验收

| 编辑 | 必须观察到的结果/工作量 |
|---|---|
| `:::en`块删除closing，再恢复closing | 删除时按真实parser扩到EOF并按现有全量结果回paragraph/重归属；恢复时从opener前checkpoint重建，后缀状态收敛后复用；无重复附件、无源丢失 |
| 两个重复visible heading之一改`:en{Title}:`内容或切target | visibleText/slug/occurrence/Typst label与fresh parse一致，TOC与正/负link依赖更新；无关code/math单元0调用 |
| 前序list后缩进默认paragraph，随后插翻译替代附件 | 撤销默认附件贡献，挂到正确旧list item；旧patchTarget更新，child ID/parent/源映射不重复或丢失；再删翻译可恢复默认原syntax |
| nested i18n/list/quote中emoji前插字符 | 子节点定位回原文UTF16/byte/rune正确，未变syntax/CodeHL复用；不把synthetic局部0当原文0 |

每例覆盖en/zh/default/universal、HTML/Markdown/Typst/JSON、source-map、snapshot隔离、undo/redo；含i18n+reference/footnote+heading closable混合。自动断言过滤原syntax仍存在、deferred queue恢复正确、无整树postprocessor调用。

inline普通文本edit须使用Task06的成功/失败候选读取窗口与负closure依赖，不以每次全I18nInline owner重扫作为最终性能验收；嵌套list/quote/i18n由plugin声明可恢复子单元，未改兄弟不重建。delimiter编辑确有递归影响时允许扩大，但记录原因与工作量。

## 3. AutoAnchorPlugin：有序贡献与位置分离

### 3.1 当前证据

插件版本0.1.0，配置全部关则不注册；否则只注册post-finalize processor（`markit/src/plugins/anchor/auto_anchor_plugin.cj:26`），没有独立syntax parser。不要为其发明Markdown marker规则。

`auto_anchor_post_processor.cj:25`顺序遍历：heading进入section并记录source range；list生成嵌套路径；code/math/table/generic block按配置顺序编号。:112在heading使用number或六级fallback prefix，重置各计数及listCounters。:87把table anchor设在首个cell，source span取整个table。:107把绝对byte坐标复制进metadata。list目前识别List/TaskList（:147），alphabetic list扩展属于另行语义决定。

其local state包含seen、listCounters、sectionNumbers[6]、currentSectionPrefix、code/math/table/block counters、listPath。当前每次post-finalize新建processor，编辑会话若复用必须显式restore和撤销旧metadata，不能重用seen导致误报重复或残留anchor。

### 3.2 拟议贡献、状态与失效

P阶段按现有可见/结构结果记录section与list有序贡献。checkpoint/summary包含入口section counters、heading编号依赖、currentPrefix、各类counter、nested list path与family、同scope唯一性集合。每个anchor贡献owner/nodeId/sourceTargetId/ordinal；撤销删除贡献并按有序后缀重放，出口state和输入结构等价才停止。

可见anchor ID依赖用户内容顺序，必须允许变化；持久NodeId不跟随anchor改号。新增code只传播本section受影响code编号，新增heading/number改变可能传播后续sections；nested list插item会改该list之后的路径，按真实有序依赖扩展。不能只向当前edited node发patch。

source metadata独立订阅源锚点位置，不混入anchor内容cache。前方文本插入只发位置变换，未变anchor编号和HTML内容复用；必要的DOM id/meta patch与source-map patch独立。table首cell被替换/删除时anchor target迁移仍订阅table完整source范围，不能遗留旧cell target。

typedcodec/view保留现有metadata与三格式renderer行为；关闭某anchor配置必须撤销该facet旧owned属性，不因“现无注册”而留下旧anchor。runtime-plan/config变化触发明确epoch/rebind，完整清理相应overlay。

### 3.3 编辑案例与验收

| 编辑 | 必须观察到的结果/工作量 |
|---|---|
| 同section首code前新增code，然后撤销 | 后续code anchor依次改号；不变code内容CodeHL调用0；后续无关section在state收敛处停止；NodeId不改，anchor ID按fresh parse改变 |
| 文首普通paragraph插入emoji/新行，未新增anchor候选 | 未变anchor编号/内容render0调用；source map/位置delta正确，不逐节点平移sourceSpan/metadata |
| nested task/list中插入item或移动附件 | 受影响路径和unique集合正确，前后旧item身份保留，DOM按nodeId移动；与i18n列表合并后再编号的兼容顺序一致 |
| 新增heading或改heading级别/number，再删table首cell | section prefix与受影响后续anchor全量一致；table新target引用table源范围，旧cell无残留anchor |

每例验证HTML anchor/id、sourceStart/End、三格式/JSON兼容、无重复seen、撤销恢复和配置开关；验证订阅heading-number/结构overlay，而非核心按kind/插件名重新扫树。

## 4. TocPlugin：派生查询增量

### 4.1 当前证据

插件版本2.0.0，只注册三格式renderer（`markit/src/plugins/toc/toc_plugin.cj:20`）。`toc.cj:9`的Toc.parse独立从AST提取HeadingNode并buildHierarchy；:75遇render=false剪枝；:123递归收集可见inline文字；:148优先heading.slug。它没有Markdown TOC syntax，核心不得硬编码`[TOC]`之类标记。

TocNode.items独立于Node.children（`toc_node.cj:10`），TocItem children才用于层次。构造器都未传ID，Node默认0；不能直接把这棵派生树塞进普通nodesById并假设唯一。需专用derived identity或typedcodec提供稳定派生ID，并保持现有API输出。

### 4.2 拟议索引与缓存

候选HeadingProjection包含heading NodeId、文档顺序、level、visibleText、number、slug、visibility、语言/配置和依赖版本，来源是已提交S/E/F/P视图。projection以有序树维护，接受insert/remove/move/update；普通paragraph改字且不影响heading祖先显隐时查询层调用0。

TOC视图键为document/overlay version、title、min/maxLevel、格式及renderer fingerprint。层次由heading level stack或可组合summary维护；从首个变动heading更新到父链/stack出口收敛。若层级改动真实覆盖很多item，应更新真实受影响层次，不承诺总是常数操作。不要每次递归全AST提取heading再重新建树。

derived item ID可由view instance allocator加heading NodeId映射稳定分配，不能使用slug/offset/hash。title/level过滤改变只影响对应view；多个title/minmax视图可并存，避免共享一个可变TocNode缓存。兼容Toc.parse/extractHeadingList/extractDetailedHeadingList/generateTextToc继续提供同结果，查询可以命中新投影或按需materialize typed TocNode。

删heading/翻译隐藏时撤销projection贡献，后继item重新挂到正确父节点；slug/number/text变化只meta/text patch，item身份保持；负查询与文件heading索引订阅相同projection数据。Toc query不能提前读未commit i18n显隐或slug；跨版本UI保持完整事务。

### 4.3 编辑案例与验收

| 编辑 | 必须观察到的结果/工作量 |
|---|---|
| 改普通paragraph文字，heading集合不变 | TOC查询重建/renderer调用0，原TOC DOM与item ID保留 |
| 中间heading从H2改H3或删除H2后undo | 其子项与后续层次按现有buildHierarchy规则重挂；未变heading ID对应derived item ID稳定，文本/anchor与fresh parse一致 |
| 修改翻译heading可见文字或隐藏整个quote/i18n祖先 | TOC可见项/text/slug同步更新，隐藏heading消失后恢复不丢原syntax；跨页heading链接得到同版本索引 |
| 同名heading前新增同名heading | slug occurrence变化传播到真实受影响后继；TOC href更新但item身份不随slug改；无全AST扫描 |

覆盖空TOC、跳级heading、min/maxLevel、number、title自定义、多视图、HTML/Markdown/Typst/JSON以及DSL TocNode现有使用。特别测试items与children的typed兼容和snapshot节点唯一性。

## 5. 跨插件交互矩阵与完成标准

| 链路 | 必须注册的依赖与测试 |
|---|---|
| inline解析 → I18n可见text → heading slug → TOC/link | parser提供语法/map；I18n发布visibleText/visibility，heading有序slug发布正负依赖，TOC/FileTree/link消费同一提交版本 |
| list/task/alphabetic/container → I18n附件/合并 → Anchor | 结构overlay可撤销；Anchor按冻结兼容顺序消费projected结构，未实现alphabetic语义不得随意扩展 |
| heading closable/number → i18n/Anchor/TOC | closable可能吞一整section，number/visible heading各有ordered状态；恢复检查点包括隐藏level、slug counts、编号和pending附件 |
| reference/footnote finalizer → visibleText/render | syntax保留未解析引用，finalize fallback不能破坏缓存；定义新增/删除/负查询使前方节点更新，i18n和TOC按实际读依赖replay |
| synthetic容器 → Anchor/source map → VSCode | 任意嵌套去缩进映射组合回原文；选择/滚动不再自行parse i18n，位置变化与HTML内容分离 |
| workspace编号/FileTree → 当前页所有格式 | 仅重扫changed文件，ordered文件摘要传播至收敛；当前页依赖外页heading缺失时保留负查询，外页新增后更新 |

对三插件分别提供facet注册清单、state/frame真实codec、撤销journal、依赖键及scope、配置fingerprint、cachequota、编辑差分和工作量断言。30内置总清单由总体任务负责，但这三项不能以global finalizer fallback替代；第三方fallback只作为显式兼容模式，不进入内置通过计数。

验收必须证明：多edit和撤销重做与fresh parse三格式/JSON/语义一致；旧parse/stream/callback顺序和输出保留；旧snapshot不被后续edit污染；未变代码/公式/图0调用；普通改段落不全树扫TOC/anchor/i18n；source映射覆盖emoji/CRLF/synthetic；重复slug/定义负查询/有序编号正确；所有patch带版本并原子commit。当前文档没有执行这些测试，所有目标仍待实施任务提交可复现证据。

oracle仅可规范化HTML/SVG等渲染器随机内部ID，且须验证规范化前后的所有ID引用仍一致；用户可见slug/anchor/TOC href不得剥离、忽略或归一化以掩盖顺序/编号回归。既有增量测试证据路径为 `markit/src/tests/unit/streaming/incremental_state_tests.cj`，新增编辑矩阵不能误引用不存在的repo级tests路径。
