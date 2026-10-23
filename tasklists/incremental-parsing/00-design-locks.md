# 设计冻结：插件驱动的激进块级编辑增量

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

更新：2026-10-21。状态：方案冻结输入；尚未开始实现。

本文件记录用户已经确认的方向及当前源码可核实的约束，供后续编号任务和DAG统一引用。接口名称、数据布局和性能数字仍需通过前置原型/基准确定，不能将本文中的能力要求解读为现有API已经实现。范围排除见[out-of-scope.md](out-of-scope.md)。

## 交付边界与既有工作保护

- 当前授权只交付方案，不实施解析器、CLI、worker、webview或渲染器改造，不提交、不推送Git。
- 仓颉最低兼容版本保持用户要求的1.1.0；协议、原型、运行时及依赖选型不得借新API将最低版本抬至1.3.0。若某API在1.1.0不可用，改用兼容实现或记录阻塞，不擅自提高门槛。
- 唯一方案根目录为仓库内`tasklists/incremental-parsing`。用户将`tasklists`作为本地资料：沿用`.git/info/exclude`中的`/tasklists/`，不改`.gitignore`，不将方案加入Git跟踪。协调者只在本目录组织任务、依赖、审查和进度；子任务只写分配文件。
- 保留当前工作树所有既有修改和未跟踪内容。不得reset/checkout覆盖、清理未跟踪目录、暂存或混入未来实现提交。每个实现任务开始时必须重读工作树状态，不把下述快照误认为永远不变。

### 当前dirty基线（只读快照）

2026-10-21执行`git status --short`与`git diff --stat`得到：

| 状态 | 路径 |
|---|---|
| M | `README.md` |
| M | `markit-cli/README.md` |
| M | `markit-cli/src/commands/render.cj` |
| M | `markit-kit/src/models/global_context.cj` |
| M | `markit-kit/src/renderers/markdown_renderer.cj` |
| M | `readme-zh_CN.md` |
| ?? | `.config/` |
| ?? | `log.txt` |
| ?? | `vscode-extension/` |

已跟踪差异为6个文件、59行增加、5行删除。这只是当时快照，不判定任何改动来源或完成程度。`git check-ignore tasklists/incremental-parsing/plugin-standard-commonmark.md`确认方案文件被本地规则忽略。未来任何任务必须保留这些内容及其后用户新增变更；尤其CLI与扩展集成不能先覆盖现有render命令或未跟踪extension再重建。

## 术语与目标

- **编辑增量**：对已有文档版本的插入、删除、替换或批量编辑事务，复用未失效语法、语义、渲染及DOM；支持任意文内编辑。已有append/stream路径不构成编辑增量完成证据。
- **激进块级增量**：以插件提供的可重解析单位、恢复状态和依赖为依据，定位脏区、回溯到合法恢复点、重解析到真实收敛边界，再复用后缀；在块内按插件能力细化。不能固定“前后N行”、只替换当前行，或每次全文解析后再做渲染diff。
- **facet**：插件声明增量能力的通用能力面，覆盖探测、语法单位与边界、checkpoint/restore、子解析与映射、语义读写/撤销、派生阶段、codec、依赖和缓存。具体类型/方法名由共享协议任务冻结，核心不能根据内置插件名称选择算法。
- **原始语法层**：保留源语法、隐藏节点、未解析引用、配对前形状及其provenance的可编辑记录；**语义层/派生层**是可撤销、可重算的解释与渲染结果，不能破坏唯一原始依据。
- **收敛**：对应新旧位置上，相关语法上下文、完整状态、语义效果、依赖、映射及后继判定满足插件协议的等价条件。源码后缀相同、literal相同或`Node.==`相等都不足以独立证明收敛。

目标是全部内置能力与core、CLI、扩展、worker、项目索引、renderer、DOM形成可验证的完整编辑链路；其正确性和局部性均须有证据，不以“接口存在”或“能运行”代替。

完整quote/list/paragraph等容器重解析只可作为迁移期安全起点，不是最终粒度承诺。checkpoint和组合source map完备后，正文编辑必须复用未受影响的嵌套子树，支持nested subunits/items/table rows及inline安全candidate窗口；超长paragraph不能无条件整段重parse。真实delimiter匹配失败、容器边界变化或语义依赖可扩大扫描，但需由facet解释范围并提供证据，不得以“保守”无限代替优化。

## 30个插件覆盖冻结

所有30个插件必须按其实际注册能力完成facet适配，不得把某个内置留在永久兼容fallback。横向插件不是block parser，不要求伪造语法边界，但必须提供本身效果与依赖的增量契约。

| 组 | 数量 | 覆盖 |
|---|---:|---|
| Standard | 13 | Blockquote、Heading、Divider、FencedCodeBlock、List、Paragraph（含SoftBreak）、InlineCode、Link、Image、ReferenceLink、Bold、Italic、HardBreak |
| CommonMark新增 | 5 | SetextHeading、HTMLBlock、CommonMarkAutolink、HTMLInline、EntityReference |
| GFM | 9 | AlphabeticList、MathBlock、Table、TaskList、Autolink、Footnote、InlineMath、RelaxedEmphasis、Strikethrough |
| 横向 | 3 | AutoAnchor、I18n、Toc |

这里的简称对应各`*Plugin`类；SoftBreak属于Paragraph，不另计插件。Bundle组合、注册顺序和配置也需进入计划/缓存版本。逐插件证据、拟议适配和案例分别见[Standard/CommonMark](plugin-standard-commonmark.md)、[GFM](plugin-gfm.md)、[横向插件](plugin-cross-cutting.md)；若文件尚待相应作者交付，不能据此宣称覆盖完成。

## 插件所有权与核心中立

### 2026-10-22确认：插件编辑增量能力可选，提供安全默认实现

- 以既有BlockParser及相关parser/extension point为直接能力声明单位，提供默认false的supportsIncremental设置及安全默认增量方法（均为候选名称）；第三方无需覆盖即可保留普通解析，选择支持时覆盖相应方法。同一plugin可同时注册支持和不支持增量的parser，plugin级设置仅补充，不能替代逐parser判断。bool只表示资格声明，不证明完整checkpoint/restore/effects能力。具体仓颉1.1.0默认方法语法由02原型验证，禁止新增旧插件必须实现的抽象方法。
- 默认compat按已证明安全的最小范围回退：仅当引擎或provider证明边界、状态及语义副作用隔离时，调用该单位完整解析；无法证明隔离则整会话full-rebuild，不假定未知插件局部安全。报告owner/parser/facet/reason及fallback范围，strict仍须显式开启并原子拒绝。
- 默认增量方法安全返回unsupported/未实现，或在已有隔离证明的单位调用完整解析，不能空restore、空撤销或伪报stateless/local-safe。旧源码零修改仍编译、注册、parse/append。
- 全部30内置插件适配是本项目交付目标，不是强迫第三方实现编辑协议的公共契约；内置不得用默认fallback逃避最终验收。

- Markdown语法由插件定义；core/CLI/webview不得用语法marker、内置插件名称、节点kind名单或前端正则来决定编辑重解析边界、终止条件、依赖传播或回退策略。
- 核心提供通用源存储、映射、事务、索引、调度、依赖图、身份分配与patch协议；插件通过facet声明自身规则。注册类别及priority是通用调度输入，具体Markdown判定仍归插件。
- 复用同一套语法实现服务旧parse/stream与新editing，不维护“完整解析器”和“编辑用简化解析器”两份语法算法。需要分离纯探测/提交或返回语法记录时，必须由同一实现内核提供。
- 已有parse与stream可观察语义保留，原公共入口、分块feed和finalize行为在迁移中回归验证。旧路径与新路径不得因语法复制而永久漂移。
- 未知第三方插件必须显式选择兼容fallback或strict拒绝，并在能力/诊断中说明原因与作用范围。不得默默假装具备facet；strict不能静默降级。这个出口只处理未适配的外部插件，不是内置验收逃生口。

## 探测、事务与状态恢复

- 起始probe必须纯，或在可回滚的隔离事务里执行；失败候选、nested detector及缓存查询不得遗留NodeId分配、symbol table、pending paragraph、patch、源引用或外部效果。
- 语法上下文和文档语义作用域分开。嵌套解析要保存/恢复activeLine、pending paragraph、frame/depth等局部上下文；允许文档全局生效的标题/引用定义等写入必须显式归属、可撤销和重放。
- checkpoint必须保存可恢复的完整状态与必要源引用，并有restore和可验证fingerprint；只存state名称不合格。外部资源或不可克隆对象不能靠浅拷贝冒充快照。
- 原单位替换时先在暂存事务中撤销其效果与依赖，再原子发布新语法、语义和patch；异常/取消/过期版本不得发布半个事务。失败回滚指未提交的语法/语义overlay/patch不得污染已发布快照，不是删除用户已经输入的内容。
- document/change已经ack的source编辑不能因取消旧parse/render而丢弃或回滚；sourceVersion允许领先已提交parseVersion/renderVersion。后续计算必须从最新accepted source恢复，已提交语义/渲染快照在失败时保持完整，并携带自己的版本；不得把旧快照假称为最新source的结果。
- 读依赖包含成功查询与missing/negative查询；写依赖包含文序候选、winner、编号/slug、隐藏区段、配对和项目索引版本。缓存命中需重放或复用有归属的效果，不能跳过语义写入。
- 收敛需要由facet给出完备条件。边界/嵌套或全局状态真实改变时可继续传播到EOF；这是有原因的实际影响，不是默认全文重算。

## typed Node codec原型门槛

- 当前Node派生类型与typed renderer依赖必须保留。不得仅把Node降为kind+literal或丢失派生字段/metadata的通用对象后宣称可复用。
- 编号实现任务大规模迁移前，必须完成**可执行**typed Node codec原型：encode/decode/clone或等价重建，覆盖代表性的typed节点、children、各类metadata、raw/provenance、source mapping、parent links与稳定ID，并通过实际renderer使用验证类型保真。
- Task02的小型可执行codec原型负责typed保真与接口冻结，可用测试Source/存储假件，不要求提前实现03/04。Task05必须用真实source和持久tree实际运行完整checkpoint事务原型，演示恢复、旧单位复用、新单位替换、效果撤销及失败回滚，并验证没有source悬挂引用、重复ID或别名污染；这是释放07大规模插件适配前的硬门槛，接口草图/伪代码不放行。
- codec的具体API、存储布局和全部节点注册方式由前置任务根据原型冻结，不能把未运行设计提前记为已验证事实。

## Source rope、坐标与组合映射

- 文档源采用支持局部编辑与版本引用的rope或等价分段结构；禁止热路径每次取得或复制全文以寻找边界。公共取全文能力可作为显式调用保留，不得成为编辑必经步骤。
- 统一处理UTF-8 byte、Unicode rune、UTF-16（编辑器协议）、line/column坐标及CRLF；编辑切点/换行计数/无效边界策略在公共协议前置测试中明确，不混用byte与rune delta。
- 去marker、去缩进、换行规范化、跨行拼接、HTML内部提取和生成文本使用可组合source map，记录真实与synthetic来源，嵌套映射可回到文件坐标。
- quote的局部零起点span、list去缩进后旧span、paragraph多行拼接等既有缺口必须修复，不允许简单整体delta冒充正确映射。
- Node位置采用惰性解析/锚点与版本映射，避免每次编辑遍历所有节点重写绝对offset。客户端需要的source属性也随版本映射更新，不能内容未变就保留旧坐标。
- NodeId在同一逻辑节点可复用时稳定，新节点唯一；identity不能等同offset或本次parse序号。HTMLInline父子复用opening.id等重复ID属于基础设施必须修复问题。

## 原始语法、语义与派生结果

- 隐藏Heading、LinkDefinition、未解析reference、footnote、HTML配对前后结构等都要保留编辑恢复依据；最终可见树不能作为唯一语法存储。
- finalize/postprocessor须声明phase、scope、依赖、可逆派生结果及重入策略。新增/删除定义、开关配置或改变配对必须能撤销旧效果。
- 符号表、项目索引与renderer缓存按文档版本/语义版本协同；dirty单位重算和未变单位复用均须保持同样语义。
- 不借此新增Markdown语法或顺手修完整parser既有语义。重复ID、错误source map、事务泄漏等影响增量基础正确性的问题必须修；若因此使AST/span/输出与旧路径有差异，建立显式基线记录、范围和回归，不能当作无关bug忽略或悄悄更新golden。

## 完整执行链路与昂贵派生阶段

### 2026-10-22确认的CLI迁移边界

- 预览统一使用`worker --stdio`：输入document open/change/flush/close等协议消息，输出response/status和有版本的patch事务。文档URI替代协议里的`--page`选择，worker自动管理资产/缓存，不要求`--incremental`开关。
- 保留`render`/`build`文件输出与`render --page`独立单页构建。仅在Task15/16协调迁移、旧调用清零及回归通过后淘汰预览旧参数`--preview-stream`和`--incremental`；此前不提前删除，也不永久保留两套预览路径。淘汰后旧参数明确报错并指向新用法/help，不静默忽略。
- 首次open保留渐进首屏：分多次**完整原子事务**发布可见结果，事务间有序关联render版本；不是发送一个巨大事务的未commit片段冒充渐进。cancel/epoch/document version检查适用于每次commit，后续失效不撤销已接受源码。
- 此例外只改变上述CLI预览参数，不删除Markit append/createSession/feed/feedBytes/finalize API，也不因同名“incremental”删除build coordinator的内部增量方法。其余兼容、正确性、性能门槛保持。

- 保持持久worker，编辑消息携带文档/版本与增量内容；禁止每次编辑spawn新CLI进程、传全文hex或调用全文getText→全文HTML链路。
- 项目索引持久维护，按文件变化更新；不得每次编辑扫描项目所有文件或重建所有标题/链接信息。查询正负依赖、文件重命名和删除需被版本化传播。
- renderer按单位与依赖复用，语法未变但解析环境/主题/索引变化时独立失效；输出有序DOM patch，携带文档/版本与目标身份。旧版本或乱序响应必须丢弃/重同步，不能覆盖新文档。
- webview消费结构化patch并保留有效DOM身份/交互状态；不得用前端语法正则二次猜AST与编辑坐标，不得以整篇innerHTML替换当最终增量实现。
- **CodeHL行级状态传播与收敛属于最终范围**：编辑受影响行后，仅沿高亮状态依赖传播到收敛；未变代码单元零调用。主题/grammar等全局输入变化的真实全量失效必须单独记录。
- **公式**：内容改变时允许只对该公式完整重新解析；未变公式单元零解析调用，位置变化不能导致重新解析。当前不承诺TeX parser内部增量。
- **图**：内容改变时允许只对该图完整重新layout；未变图单元零layout调用，位置变化不能导致layout。当前不承诺单图layout内部增量。
- 上述昂贵单元缓存键必须包含语义输入、config/版本和身份相关派生参数。零调用要求用实际计数器/spy验证，不以相同HTML输出推断。

## 验证、性能与最终门槛

- 正确性以同配置完整解析为oracle，覆盖所有30插件、组合bundle、嵌套解析、编辑/回滚/取消、正负依赖、typed codec、CRLF/中文/emoji、NodeId与source map、乱序patch及项目变化。
- 既有语义偏差先记录基线；基础设施纠错另标明确预期，避免用错误旧span或重复ID作兼容目标。不得为了“等价”关闭必要校验。
- 局部性验收记录实际扫描/重解析单位、状态传播长度、语义/渲染命中失效、CodeHL/公式/图调用次数、worker/索引/DOM行为；全篇reparse后diff不合格。
- 性能目标均为拟议，未实测、未达成。具体规模、场景、p50/p95、内存、调用预算与验收阈值须由独立编辑基准任务先冻结，再测量报告；缺少数字时不得虚构。
- 旧stream benchmark只证明其原有append场景，不得当editing性能证据。编辑基准应包括文首/中部/尾部、跨块、多次编辑、最坏未闭合结构、语义传播和项目索引变更，并分冷启动与持久worker稳态。
- 分阶段可有显式临时fallback，以保持迁移可运行；须记录能力、原因、成本与移除任务。最终门槛是30内置facet完成、基础设施缺口关闭、全链路增量和局部性证据通过审查，不能用临时fallback结项。

## 当前证据与待放行事项

已核实当前`PluginRegistrar`无编辑facet；`SessionStateSnapshot`仅名称；`Markit.createSession`共享session执行detached parse；`Node.==`不比较children/metadata；Standard/CommonMark静态调查详见对应清单。以上是静态事实，尚无新编辑功能的测试或性能通过结论。

下一阶段先建立编号任务、严格DAG与文件所有权，执行共享协议和typed codec可运行原型等前置门槛；后续插件组、worker/索引/renderer/DOM接入按已冻结接口分波次并行，所有后继由协调者审查证据放行。不能跳过前置门槛直接大规模复制修改30插件。
