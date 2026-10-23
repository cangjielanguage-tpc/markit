# 范围排除与不可接受的完成方式

更新：2026-10-21。当前交付只有方案，实施尚未开始。已确认的最终范围见[00-design-locks.md](00-design-locks.md)。本文件不把必需能力推迟出范围。

## 当前方案交付不包含的操作

- 已确认的未来CLI迁移属于计划范围：worker --stdio替代预览旧--preview-stream/--incremental，必须CLI/扩展联合通过后才淘汰；本轮不执行删除。不得扩大为删除render/build文件输出、render --page、Markit append API或内部build增量方法；详见[设计锁](00-design-locks.md)。

- 不实施源码、CLI、extension、worker、renderer或webview改造；不运行会改写实现/测试golden的迁移。
- 不commit、push、部署或发布。不暂存当前dirty工作树，不清理或覆盖用户修改/未跟踪文件；基线见设计冻结文档。
- 不改`.gitignore`，不跟踪`tasklists`；仅沿用用户选择的`.git/info/exclude`本地排除。
- 不将仓颉最低版本从1.1.0提升至1.3.0，不以新API/依赖选型绕开最低版本兼容要求。
- 不在`tasklists/incremental-parsing`之外创建本任务方案资料。未授权的文件不能被并行任务顺手修改。

## 不新增语法，不夹带无关语义修复

- 本轮不新增Markdown方言/语法、重写语法标准或扩充既有parser支持范围；不顺手修完整parser既有语义偏差，不把目标变成CommonMark全面兼容工程。
- 旧parse/stream可观察语义须回归保留，同一语法内核供各入口复用；不能新建“编辑简化语法”并永久与原实现分叉。
- **重复NodeId、错误source map、坐标混用、事务泄漏和无法撤销效果不在排除之列**。这些影响编辑基础正确性的缺口必须关闭；由纠错引起的差异须显式记录基线、理由与回归，不能忽略，也不能借此无边界扩大语义修复。

## 不作为当前承诺的更细内部增量

- TeX parser内部的token/语法树增量属于可选未来工作。本轮允许公式内容改变后，只对该公式完整重parse；未变公式必须零解析调用。
- 单图layout内部节点/边的增量算法属于可选未来工作。本轮允许图内容改变后，只对该图完整重layout；未变图必须零layout调用。
- 上述粒度约束不能被解释为允许每次编辑重算所有公式/图。位置或外层布局变化不能绕过内容/配置依赖而触发无关解析/layout。
- **CodeHL行级状态传播到收敛已在最终范围内**，不得放到未来可选项。CodeHL、公式、图的缓存与实际调用计数均在本轮验收。

## 明确禁止的实现捷径

- 每次全文重parse，再以AST/HTML diff包装成“块级增量”；用全文reparse fallback给某个内置插件盖完成章。
- 在core、CLI或webview按Markdown语法、marker、内置plugin名称或kind名单挑边界；用前端语法正则猜节点、映射source span或控制重解析。
- 编辑热路径每次全文`getText()`、复制/hex编码全文、生成整篇HTML或整篇`innerHTML`替换；按编辑次数spawn CLI/worker。显式导出/取全文API可保留，但不得作为增量必经步骤。
- 每次编辑扫描项目所有文件、重建全部标题/符号索引、遍历所有节点重写offset；以绝对位置变化强制所有单元解析和渲染。
- 只按当前行、固定前后N行或空行决定恢复范围；忽略open fence、pending paragraph、Setext反向吸收、quote/list/HTML嵌套与真实全局状态。
- 将迁移期whole-container重parse当最终性能门槛：正文局部编辑无条件重parse整个quote/list/超长paragraph，忽略nested subunits/items/table rows和inline安全candidate窗口。真实delimiter/语义依赖扩大扫描须有facet依据，不能伪报局部性。
- 将名称型snapshot当完整checkpoint，把浅拷贝当restore；失败probe遗留语义写/NodeId/patch；跳过缓存命中单元应有的效果归属与依赖。
- 丢弃typed Node字段、metadata或renderer类型要求，依赖kind+literal通用对象冒充可恢复AST；只提交codec接口而不完成可运行原型。
- 将最终可见AST当唯一编辑依据，丢掉隐藏Heading、definitions、missing references、HTML配对前语法；依赖不可逆finalizer后树推测原语法。
- 只给synthetic子树整体加offset，混用byte/rune/UTF-16/CRLF坐标；用源码位置或本次分配序号充当稳定NodeId；容忍同树重复ID。
- 只比较literal或当前`Node.==`证明收敛；仅源码哈希命中而忽略状态、索引、主题、grammar、path和negative依赖。
- 乱序/过期worker响应覆盖新版本DOM；无版本patch或无序DOM替换；把保留有效DOM身份/交互状态推迟到本轮之外。

## 临时fallback与未知第三方边界

- 迁移期允许能力明确、可诊断的临时fallback，用于前置协议与消费者尚未全部落地时保持可运行。每处必须记录原因、作用范围、成本、移除任务和最终验收门槛。
- 最终全部30个内置插件都需按实际facet完成；“暂时全文重算”不得改名成内置永久策略。真实未闭合语法或语义状态传播到EOF时，按插件协议扫描至EOF是有因成本，须能与无条件fallback区分。
- 未知第三方插件可显式选择兼容fallback或strict拒绝，这是外部兼容机制；不得静默降级、默认为内置补洞或伪称具有未实现facet。
- 插件没有某项能力时不必制造虚假facet，例如纯横向插件无需伪造block parser，但必须完成其真实语义/派生依赖与失效支持。

## 不可声称的验证结论

- 当前只完成静态调查和方案，不声称编辑功能、测试、原型、性能或30插件适配已经完成。
- 所有性能数字在编辑基准冻结与运行之前都是拟议目标；不得凭旧stream benchmark、热缓存单次结果或相同输出推断editing性能达成。
- 最终不能只凭编译通过或几张预览图结项：必须有完整解析差分、typed codec/source map/ID/依赖/回滚、全链路worker与项目索引、render cache、有序DOM patch和昂贵单元零调用证据。
- 不隐去失败验证和既有基线差异，不自动把未适配内置或未验证场景写成“已支持”。
