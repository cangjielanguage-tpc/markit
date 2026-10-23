# Standard / CommonMark：18 个语法插件的编辑增量适配方案

## 2026-10-23 澄清：30个内置必须逐项适配

零源码修改的默认兼容出口用于**外部旧插件**。我们自己的全部30个内置插件（13 Standard + 5 CommonMark新增 + 9 GFM + 3横向）仍须逐个实现并验证其**实际注册的增量能力**；Task02提供的 `supportsIncremental=false` 和安全默认方法不是内置适配完成，不能用 blanket full-session fallback 替代实现或标记Done。该30插件目标不因基线/通用框架裁剪而删除。

每个插件按其真实parser、状态、checkpoint/恢复、组合映射、读写依赖、可撤销效果及派生/渲染能力适配，适用哪些能力就验证哪些，不伪造未注册的facet。真实语法或语义变化允许广传播乃至EOF，但须说明触发状态/依赖与实际范围，区分语法重解析、语义传播和渲染失效，不能把默认整会话重建冒充真实影响。

本清单逐个核对13个Standard与5个CommonMark新增插件，18个条目都必须完成实际注册能力的增量适配与定向验证。

更新：2026-10-21。状态：方案；实现、运行测试及性能验证均未开始。

本文件依据当前仓库只读调查编写，负责 13 个 Standard 语法插件和 CommonMark 新增的 5 个语法插件，共 18 个。源码路径均相对仓库根目录，明确符号用于后续定位。AutoAnchor 不计入这 18 个，见 [横向插件方案](plugin-cross-cutting.md)。本文只提出适配契约，不声称这些契约已存在或测试已经通过。

## 范围、共同前置与完成条件

- 输入：统一编辑事务、插件增量协议、可恢复状态、依赖图、source mapping、稳定身份协议定稿后，18 个插件按本文件适配。
- 输出：每个插件拥有自己的重解析边界、状态或效果记录、依赖与失效规则、收敛判定及验收用例；核心只实现通用调度、事务、区间索引和依赖传播。
- 禁止：核心根据 Markdown marker 或 Heading / Link 等节点 kind 硬编码重解析策略；将任何内置插件永久留在全文重解析 fallback；仅实现局部高亮渲染就宣称解析增量完成。
- 迁移期间的保守重算必须记录原因和范围，最终验收须证明所有 18 个插件进入正式增量协议。语法本身无闭合边界或全局依赖真实传播到 EOF 时允许实际扫描至 EOF，不能借此取消插件边界协议。
- 下文完整quote/list/paragraph等容器是迁移期安全恢复起点，不是最终每次编辑的重解析粒度。checkpoint与组合source map完备后，正文编辑必须复用不受影响的嵌套子树，支持nested subunits/items及inline安全candidate窗口；超长paragraph不能无条件整段重parse。table rows的同类门槛由GFM方案负责，CodeHL行级状态收敛属于最终范围。真实delimiter/容器边界或语义依赖可以扩大扫描，但必须有facet原因及局部性证据。
- 仓颉最低兼容版本保持1.1.0，不得通过新API或依赖选型抬到1.3.0。
- 并行边界：各插件实现与独立用例可在共享协议冻结后分组分派；`markit.cj`、core 协议和公共测试设施由专门串行任务拥有，插件任务不能抢改。Heading 与 Setext、Link/Image 与 ReferenceLink 的共享输出和依赖交接必须经集成审查。
- 下述案例都是**待实施验收**。每例都对比同配置完整重解析的语法结构、语义元数据、HTML/Markdown/Typst 输出；另检查有效节点 ID 唯一、未受影响节点 ID 稳定、source byte/rune 映射、依赖撤销及实际失效范围。不能用当前 `Node.==` 充当完整等价判定。

## 注册、优先级与生命周期现状

证据：`markit/src/bundles/standard_markdown_bundle.cj::StandardMarkdownBundle.plugins`、`markit/src/bundles/commonmark_bundle.cj::CommonMarkBundle.plugins`。

- Standard：Blockquote、Heading、Divider、FencedCodeBlock、List、Paragraph、InlineCode、Link、Image、ReferenceLink、Bold、Italic、HardBreak；另注册 AutoAnchor。
- CommonMark 复用上述能力，再增加 SetextHeading、HTMLBlock、CommonMarkAutolink、HTMLInline、EntityReference，`includesStandardMarkdown=true`。
- `markit/src/core/plugin/plugin_registrar.cj::PluginRegistrar` 当前能注册 state、leaf block、continuation block、paragraph、inline、batch processor、emission filter、session finalize、post finalize、HTML/Markdown/Typst renderer；没有编辑恢复边界、效果撤销、依赖追踪或缓存键协议。
- `markit/src/core/block/block_dispatch_table.cj::BlockDispatchTable.insertByPriority` 与 `markit/src/core/inline/inline_dispatch_table.cj::InlineDispatchTable.insertByPriority` 按数值升序；同值保持原注册顺序。`markit/src/core/block/block_tree_builder.cj::BlockTreeBuilder.parseLines` 先试 continuation 整组，再试 leaf 整组，最后 paragraph；不同类别的 priority 不能放入一张混排表。
- inline engine 在实际 parser 前检查转义，parser 可能读取到 enclosing inline range 末尾并递归子解析。失败的 candidate 也可能产生“缺少闭合符”依赖；不能只记录成功 token 的范围。
- 当前通用 AST/render 缓存未提供。本文“缓存”描述拟议键与失效要求；已有的代码高亮器静态缓存、节点派生 HTML 元数据另行明确标注。
- 公共 render key 至少区分格式、HtmlConfig 快照、plugin/renderer/config 版本、完整 children 与 metadata、`render` 属性和 anchor 属性。仅 node.id、literal 或源码哈希不足以覆盖语义与渲染环境变化。

## 逐插件适配

### 01 BlockquotePlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/block/blockquote/blockquote_plugin.cj::BlockquotePlugin.register`。注册 continuation `BlockquoteParser`（priority 70，`>`）与 Blockquote 三格式 renderer。
- `blockquote_parser.cj::BlockquoteParser.continueBlock` 接受显式 marker，也接受未被 `startsOuterBlock` 判成外部块的非空 lazy continuation；空行或外部起始返回 ClosedAndReprocess。
- `blockquote_state.cj::BlockquoteState` 保存剥 marker 后 lines 与外层 sourceSpan。finalize 用 SyntheticSourceBuilder 构造局部源码，调用共享 session.parseDetachedLines，再冻结子树 rawContent。

**拟议适配契约**

- 重解析单位：完整 quote 容器；从 opening 行或已有可恢复 quote frame 开始。marker、空行、lazy continuation 分类变化后扫描到新退出边界，并重处理退出行。
- 状态/读写：frame 保存每行 marker 剥离映射与 lazy 判定；递归解析产生的 Heading、ReferenceLink 等语义效果必须归属此单位并可撤销/重放，不能标为纯局部。
- 依赖/失效：读外部起始分类、嵌套 grammar fingerprint 与递归子依赖；边界变化失效容器及接邻 paragraph。嵌套全局写沿依赖图继续传播。
- 收敛：新旧退出位置映射、frame 状态、递归效果及后继输入分类相同，才可接回后缀。
- 缓存：容器文本、marker/source map、lazy 分类、子语法集合、输入语义状态；synthetic child span 不可充当真实文件索引。

**编辑验收**

1. 删除 quote 中间行 `>`，验证仍可 lazy continuation 或按实际新分类退出，退出行不丢失。
2. 将 quote 后普通行改成 `# title`，验证 quote 结束、新 Heading 和其 slug/编号依赖同步更新。

### 02 HeadingPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/block/heading/heading_plugin.cj::HeadingPlugin.register`。注册 `HeadingPlugin.heading`、leaf HeadingBlockParser（priority 100，`#`）、HeadingNodeBatchProcessor、HeadingNodeEmissionFilter、Heading 三格式 renderer。
- `heading_session_state.cj::HeadingSessionState` 含 slugCounts、六级 counters、hiddenSectionLevel；`allocateSlug`、`assignNumber` 和 `acceptTopLevelNode` 改全局顺序状态。
- `heading_block_parser.cj::HeadingBlockParser.tryParse` 写 slug、baseSlug、slugOccurrence、typstLabel、number、numberInHtml、closable，并递归 inline。
- `heading_node_batch_processor.cj::rewriteNodes` 递归删除 closable 隐藏兄弟；emission filter 也按持久 hiddenSectionLevel 隐藏顶层节点。现 snapshot 仅名称，未保存上述字段。

**拟议适配契约**

- 重解析单位：ATX 语法一行；语义层另设文序标题聚合，不能把一行语法边界当全局语义边界。
- 状态/读写：完整可恢复 slugCounts、counters、hiddenSectionLevel，或等价文序聚合索引；保留隐藏节点的原始语法记录。拆分语法节点与 slug/编号/可见性派生结果。
- 依赖/失效：同名 slug 后继、编号文序后继、隐藏区段至同级/更高级标题、使用标题索引的 Link/其他插件均接收变化；Setext 必须写同一聚合通道。
- 收敛：比较对应 checkpoint 的全部语义状态和可见性，而非只比较当前标题 literal；状态相等后可停止后缀语义传播。
- 缓存：inline children、标题原始文本、输入聚合状态、page path、numbering/closable/slug config；渲染缓存还读派生 metadata。

**编辑验收**

1. 两个 `# A` 之前插入 `# A`，后续 slug 正确成为 a-2/a-3，相关链接和锚点同步失效。
2. 开启 closable 后编辑标题 level/闭合标记，整段隐藏内容可逆显隐，后续编号与过滤状态等于全解析。

### 03 DividerPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/block/divider/divider_plugin.cj::DividerPlugin.register`。注册 leaf DividerBlockParser（priority 90，`- * _`）和 Divider 三格式 renderer。
- `divider_block_parser.cj::tryParse` 接受至少三个相同 marker，允许空格/tab，无专有 session state。

**拟议适配契约**

- 单位：候选一行，但读 pending paragraph 与 Setext/List 等竞争分类；编辑边界触发邻接 paragraph 合并/拆分。
- 状态/依赖：无持久语义写；记录候选分类和 marker/count，anchor/render 由横向依赖附加；不能把独立一行 parse 结果直接拼接。
- 收敛：行类别、pending paragraph 转移及后继 block 分类均一致。
- 缓存：marker/count、行及邻接分类、grammar fingerprint、anchor metadata。

**编辑验收**

1. `---` 改为 `--`，Divider 转 Paragraph，正确处理其前后段落。
2. CommonMark 下调整 `Title\n---` 的前置空行或删除 Title，验证 Setext 与 Divider 的优先级和上下文竞争。

### 04 FencedCodeBlockPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/block/fenced_code_block/fenced_code_block_plugin.cj::FencedCodeBlockPlugin.register`。注册 continuation priority 100（反引号/`~`）及三格式 renderer。
- `fenced_code_block_state.cj::FencedCodeBlockState` 保存 marker/length/indent、language、highlightLines/i18nLines、opening/content/closing lines、closed/span。
- `fenced_code_block_parser.cj::finalize` 生成 literal/fileGroups，并执行 Mermaid/codehl，派生 HTML 写入节点 metadata。`fenced_code_block_html_renderer.cj` 对缺少派生片段的情况仍可能现场高亮。
- `fenced_code_block_mermaid_renderer.cj::renderInto` 的 idPrefix 包含 node.id。`fenced_code_block_codehl_renderer.cj::highlighterCacheKey` 含目录字符串及内联 grammar/alias 配置，未把目录文件内容版本自动纳入。

**拟议适配契约**

- 单位：完整 fenced block，body opaque。内容编辑可局部重建；opening marker/length/indent 或 closing 改动必须从 opener 扫到新 closing/EOF。
- 状态/依赖：frame 可恢复全部 fence 判定字段；语言、group、行规则、targetLanguage、grammar/theme/alias 内容版本、Mermaid 版本分别作为派生阶段依赖。
- 收敛：同一映射后 closing、closed 状态、后继分类与派生输入一致；真实未闭合导致 EOF 扫描需记录原因。
- 缓存：区分 syntax cache、codehl 内容片段 cache、带身份的 Mermaid HTML；不能跨 node.id 直接复用带 idPrefix 的片段，不能因 source 文本未变忽略主题/目录变更。

**编辑验收**

1. 删除 closing fence，后续 Heading/Paragraph 被吸入代码块；补回后恢复且旧全局语义效果撤销/重放正确。
2. 修改 language 为 mermaid，或修改 highlight/i18n 行规则、主题配置，派生 HTML 必须失效，不沿用旧 metadata。

### 05 ListPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/block/list/list_plugin.cj::ListPlugin.register`。注册 continuation ListBlockParser（priority 80，`- * + 0..9`）及 List 三格式 renderer；ListItem 由 List renderer 处理，无独立注册。
- `list_model.cj::ListBlockState` 含 ordered/baseIndent/delimiter/startNumber/tight/items/pendingBlankLines。blank flush 可使整个 list loose。
- `list_block_parser.cj::buildItemChildren` 对简单 item inline，对复杂 item 构造 paragraph 并 detached parse；`startsDetachedBlock` 含本插件 nested fence/heading/divider 判定，并调用 registered continuation detector。
- `ListConfig` 当前只有 autoAnchor，经 bundle 送给 AutoAnchor；List parser/renderer 本身未用此值控制解析。

**拟议适配契约**

- 单位：完整 list 为安全恢复单位；允许 item 优化的前提是验证 ordered/delimiter/baseIndent/tight、相邻 item 边界不变。
- 状态/依赖：可恢复 pending blanks 与 item 边界；递归全局效果传递到外层。行缩进与 marker 分类、同级序号、tight、i18n_tight_override、嵌套 grammar 与 anchor path 均须有依赖。
- 收敛：frame、pending blanks、下一 item/退出边界及聚合 tight 状态相同，不能只比已编辑 item。
- 缓存：list 属性、item 顺序和子树；inline 内容变化可能使 single Text item 与 Paragraph item 结构切换。去缩进文本必须配真实 source map。

**编辑验收**

1. 两 item 中间插入/删除空行，所有 item 的 tight/loose 输出正确变化。
2. 修改子行缩进，或首 marker `1.` 改 `1)`，验证 list 分裂/嵌套与退出行重处理，相关依赖未残留。

### 06 ParagraphPlugin（包括 SoftBreak）

**现有事实与证据**

- 入口：`markit/src/plugins/standard/block/paragraph/paragraph_plugin.cj::ParagraphPlugin.register`。注册 paragraph parser、SoftBreakParser（priority 10，newline）以及 Paragraph/SoftBreak 三格式 renderer；不存在独立 SoftBreakPlugin。
- `paragraph_block_parser.cj::ParagraphBlockParserImpl` 对非空行起段，trimAsciiStart。`paragraph_children_builder.cj` 拼接多行一次 inline parse，结尾 SoftBreak 取决于 ParagraphTermination 与行 terminated。
- HTML paragraph renderer 忽略末 SoftBreak 的显示，不代表 AST/Markdown/Typst 可以忽略它。

**拟议适配契约**

- 单位：完整逻辑 paragraph 是通用安全 inline owner；读前后 block 分类及结尾 termination/newline，支持 Setext 反向消费 pending paragraph。
- 状态/依赖：pending paragraph line list/span 可恢复；依赖全部嵌套 inline 的正/负查询。跨行 inline、空白规范化与源映射由该插件提供。
- 收敛：paragraph 边界、termination 与后继 pending 状态一致；不是看到空行就无条件停止。
- 缓存：全文、分行/source map、termination、grammar fingerprint、递归语义依赖；拼接长度不能替代真实文件连续跨度。

**编辑验收**

1. 删除两段间空行，合并 paragraph，允许 inline 在新边界跨行匹配；插回后正确拆分。
2. 文件末尾增删换行，terminal SoftBreak 与三格式输出均等于完整重解析。

### 07 InlineCodePlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/inline/inline_code/inline_code_plugin.cj::InlineCodePlugin.register`。inline priority 100（反引号）与 InlineCode 三格式 renderer，无 session state/递归 children。
- `inline_code_parser.cj::tryParse` 找等长 backtick run，可跨 newline；normalizeCodeSpan 归并 newline，当前调用 processEscapes。

**拟议适配契约**

- 单位：enclosing inline owner；更细优化必须记录 opener/closer run、失败搜索直至 range 末尾的依赖。body opaque。
- 状态/依赖：无语义写；读完整分隔符 run、转义与 inline range 边界；关闭符变化可释放原 body 参与其他插件解析。
- 收敛：token覆盖与后继游标、原始/规范化内容一致。
- 缓存：raw、normalized literal、fenceLength、range/escape 上下文，避免只按可见 code 文本命中。

**编辑验收**

1. 删除 closing backtick，原 body 中强调/链接重新参与 inline 解析。
2. 双反引号变单反引号，验证内部单反引号造成的匹配边界变化与 newline normalization。

### 08 LinkPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/inline/link/link_plugin.cj::LinkPlugin.register`。inline LinkParser priority 300 `[` 与 Link 三格式 renderer；parser 递归解析 label。
- `smart_heading_link_resolver.cj::SmartHeadingLinkResolver.resolve` 在渲染阶段处理 `~`、`#~`、fuzzy 文件匹配、`.md` 扩展等；读 LinkConfig、FileTree、currentFilePath。LinkPlugin.updateConfig 可变更全部 renderer 共用 resolver。
- `link_render_utils.cj::extractText` 递归提取 label 并跳过 render=false；输出 href 不只取决于 URL。

**拟议适配契约**

- 单位：完整 inline owner；记录括号、转义、nested label 和 destination quote 的查找范围。
- 状态/依赖：parse无专有全局写；render声明文件树版本、标题查询结果、missing/fuzzy query、当前路径、输出扩展与 renderMode。标题索引变更可只失效 render。
- 收敛：语法 token 与递归效果一致；render查询必须按依赖版本独立收敛。
- 缓存：url/title/可见子文本、resolver config与索引版本；ReferenceLink 产生的 LinkNode 也消费这组 renderer，需共享输入契约。

**编辑验收**

1. 修改 `[**A**](#~)` 的 label，resolved href 随提取文本变化。
2. 源码不变，仅更新 FileTree/当前路径/输出扩展，相关链接重新渲染，AST无需全部重建。

### 09 ImagePlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/inline/image/image_plugin.cj::ImagePlugin.register`。inline priority 500 `!` 与 Image 三格式 renderer，无专有状态。
- `image_parser.cj::ImageParser.tryParse` 解析 destination quote 与 bracket，alt/title processEscapes，无 alt inline children；与 ImageReference priority 600 竞争。不使用 LinkResolver 文件树语义。

**拟议适配契约**

- 单位：enclosing inline owner；读 `![]()`、转义和闭合失败范围，写 src/alt/title，不能擅自继承 Link 的渲染依赖。
- 收敛：匹配覆盖及剩余游标一致，Image↔ImageReference 分类变化撤销旧依赖。
- 缓存：src/alt/title、raw边界、renderer/config；不把源码相似的 ImageReference 当同依赖节点。

**编辑验收**

1. 删除 destination 的 `)`，Image 降回文本，剩余 inline 正确解析。
2. `![a](u)` 改 `![a][r]`，验证分派转换和 definition 依赖绑定/解绑。

### 10 ReferenceLinkPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/inline/reference_link/reference_link_plugin.cj::ReferenceLinkPlugin.register`。state `ReferenceLinkPlugin.registry`；leaf LinkDefinitionParser priority 200 `[`；inline ReferenceLinkParser priority 400 `[`、ImageReferenceParser priority 600 `!`；LinkDefinition filter和空三格式 renderer；session finalize resolveForwardReferences。
- `reference_link_registry.cj::ReferenceLinkRegistry` 用 ASCII lower label，first definition wins；definitions/pendingRefs/pendingImages，snapshot不含内容。finalizer实际遍历root。
- full/collapsed link可先占位，shortcut `[a]` 在解析当时无definition即拒绝；image shortcut可先占位。已解析 Link/Image 不保留 refLabel，finalize成功也删除 refLabel；失败则破坏性替换同ID同span Text。definition节点被 emission filter隐藏。
- `reference_link_parser.cj` 与 `image_reference_parser.cj` 对collapsed空label替换为显示文本后计算consumedRunes，存在多计label runes的风险，需专项验证而非沿用。

**拟议适配契约**

- 单位：definition行与引用所属inline owner；保留不可见definition语法记录和可逆引用provenance，不能仅复用finalize后的树。
- 状态/读写：写 normalizedLabel → 文序候选列表，派生winner；引用读包括missing的label依赖。移除旧单位先撤销其定义和引用效果，再提交新效果。
- 依赖/失效：新增/删除/改名/重排definition，所有对应引用（包括已解析Link/Image、fallback Text和shortcut负依赖）更新；同label第二候选可接管，不影响别的label。
- 收敛：候选序列/winner与使用者解析语义一致；finalized=true或当前无refLabel不是可收敛证明。
- 缓存：label winner版本、candidate顺序、missing版本、syntax provenance；Link输出还继承Link renderer环境依赖。

**编辑验收**

1. 文末增删 `[r]: /u`，前面的 `[x][r]`、`![x][r]`、shortcut与missing文本正确重判；去定义再恢复可逆。
2. 删除第一条重复 `[r]` 定义，第二条成为winner，所有r引用更新；带中文的`[文][]`后续rune spans正确。

### 11 BoldPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/inline/bold/bold_plugin.cj::BoldPlugin.register`。inline priority 900 `* _` 与 Bold三格式renderer。
- `bold_parser.cj::tryParse` 匹配双marker，首内容非空白，closing前非空白，underscore closing后检查ASCII alphanumeric；递归inline，无专有状态。

**拟议适配契约**

- 单位：inline owner；正负依赖包含opening/closing、escape、邻字符、失败扫描范围；递归子依赖必须传递。
- 收敛：分隔符选择、覆盖范围、children语义效果、后继游标全部一致。
- 缓存：marker、literal、children、邻接字符、range边界；与Italic分派优先级进grammar版本。

**编辑验收**

1. 删除`**a**`一个末marker，Bold/Italic/Text重新组合。
2. 将`__a__ x`末marker后空格改字母，closing判定变化使旧token失效；嵌套reference依赖随之正确撤销/重绑。

### 12 ItalicPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/inline/italic/italic_plugin.cj::ItalicPlugin.register`。inline priority 1000 `* _` 与Italic三格式renderer。
- `italic_parser.cj::tryParse` 单marker，拒绝紧接同marker，首内容/closing前非空白，underscore closing后检查ASCII alphanumeric；递归inline，无专有状态。

**拟议适配契约**

- 单位与依赖：完整inline owner，记录分隔符、邻字符、转义、range边界、失败扫描和子效果；由插件解释强调语法。
- 收敛：覆盖、children、后继游标及效果一致；需包含Bold竞争结果。
- 缓存：marker/literal/children/邻接上下文/grammar版本。

**编辑验收**

1. `*a*`开头增加`*`，按实际优先级重判Bold/Italic/Text。
2. `_a_ x`末marker后改字母，原Italic消失或匹配范围改变，后续token spans无漂移。

### 13 HardBreakPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/standard/inline/hard_break/hard_break_plugin.cj::HardBreakPlugin.register`。state HardBreakPlugin.enabled、inline priority5（反斜杠/空格）、HardBreak三格式renderer。
- `hard_break_state.cj::HardBreakState` reset为空，snapshot仅名称；parser不读此state，它不是现有开关。
- `hard_break_parser.cj::tryParse` backslash后允许空格再newline；空格分支在当前candidate处要求run恰好两个再newline；inline engine另检查isEscaped。多空格场景要按完整engine实际行为验证，不能仅据单次candidate推断。

**拟议适配契约**

- 单位：paragraph/inline owner，局部优化须读前置backslash奇偶、完整空格run和后置newline。
- 状态/依赖：无有效专有语义状态；明确marker+newline归属，与SoftBreak互斥；paragraph termination变化也可失效。
- 收敛：breakType、覆盖、后继游标一致，无多余SoftBreak。
- 缓存：breakType、whitespace、escape上下文、newline/termination；不能把空state名当语义版本。

**编辑验收**

1. `a  \nb`改一个或三个空格，比较完整engine得到的HardBreak/Text/SoftBreak，不预设三空格的结果。
2. backslash+newline中删除backslash或newline，验证token归属和末尾换行变化。

### 14 SetextHeadingPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/commonmark/block/setext_heading/setext_heading_plugin.cj::SetextHeadingPlugin.register`。只注册leaf SetextHeadingParser（priority50，`= -`），无自有state/renderer，输出Standard HeadingNode并依赖HeadingPlugin。
- `setext_heading_parser.cj::tryParse` 要求trim后至少三个相同marker及非空pendingParagraphLines，消费整个pending paragraph并clear；调用Heading state.uniqueSlug/assignNumber；每行独立inline，中间插零宽span Text newline。
- 与ATX实现不对称：当前不设置baseSlug/slugOccurrence/typstLabel，也不实现closable。这是现状，是否统一语义应显式决策，不能暗中改变完整解析基准。

**拟议适配契约**

- 单位：前一个完整pending paragraph+underline；声明向前吸收/重分类，不能只重解析marker行。
- 状态/依赖：写Heading共同文序聚合，读pending内容/分行、marker与竞争分类；level改变传播编号/slug/标题索引。
- 收敛：pending消费结果、Heading聚合出口、后继分类全部一致。
- 缓存：pending全文/分行/source map、underline、Heading输入状态；保留synthetic newline来源。

**编辑验收**

1. `Title\n---`前插空行、删除Title或把Title接到上段，验证Heading↔Divider/Paragraph分类。
2. underline `===`改`---`再改`==`，level、后续编号与段落边界都正确更新。

### 15 HTMLBlockPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/commonmark/block/html_block/html_block_plugin.cj::HTMLBlockPlugin.register`。continuation priority300 `<` 与HTMLBlock三格式renderer。
- `html_block_state.cj::HTMLBlockState` 保存类型、tagName、selfClosing/protected、attrs、endMarker、closed、nestingDepth、lines/span。parser支持comment/processing/CDATA/declaration及列举的safe block tag；同名tag计depth，其余按endMarker；未闭合可延至EOF。
- `html_block_config.cj::HtmlBlockConfig` 内部Markdown默认关闭；开启后safe/nonprotected/nonselfclosing的inner lines递归detached parse。renderer可能raw输出，也可能依据children重建。

**拟议适配契约**

- 单位：完整HTML block，从opener/frame恢复到新close/EOF；是否opaque和递归由插件判定。
- 状态/依赖：全部类型/tag/depth/保护字段可恢复；内部Markdown效果须可撤销；attrs、config、children与anchor分别进入依赖。
- 收敛：同映射closing、frame出口、child effects与后继分类一致；不能以空行固定结束。
- 缓存：raw路径与重建路径分开，包含tag/protected/config/source map和子树版本。

**编辑验收**

1. 删除/补回`</div>`或comment的`-->`，后续块被吸入/释放且语义效果撤销正确。
2. 开启内部Markdown后将div改pre，内部Heading/ReferenceLink效果撤销并按raw输出；改回后恢复。

### 16 CommonMarkAutolinkPlugin

**现有事实与证据**

- 入口：`markit/src/plugins/commonmark/inline/commonmark_autolink/commonmark_autolink_plugin.cj::CommonMarkAutolinkPlugin.register`。inline priority700 `<`（先于HTMLInline）及三格式renderer，无state/children。
- `commonmark_autolink_parser.cj::tryParse` 匹配URI/email，空白/newline/内部`<`拒绝；URI scheme长2..32，email使用本实现的字符与domain检查。Markdown写raw。

**拟议适配契约**

- 单位：inline owner，或证明有效的完整`<...>`candidate；记录缺失`>`的负查找，及HTMLInline/HTMLBlock竞争分类。
- 状态/依赖：无语义写，保存raw/url/displayText/type；opaque body不递归。
- 收敛：candidate类别、覆盖与后继游标一致。
- 缓存：raw/type/url/displayText、escape/range与grammar版本、HTML类配置。

**编辑验收**

1. `<a@b.com>`删除/补回`>`，Text↔Autolink正确。
2. `<ab:cd>`改为`<span>`，从Autolink转HTMLInline并正确触发tag pairing。

### 17 HTMLInlinePlugin

**现有事实与证据**

- 入口：`markit/src/plugins/commonmark/inline/html_inline/html_inline_plugin.cj::HTMLInlinePlugin.register`。inline priority800 `<`、三格式renderer及post finalize。
- config.enabled默认true时pairTags；无论enabled值，都执行extractHtmlInlineFromHtmlBlocks。parser只识别列举的safe tags，code受保护。
- pairTags递归处理同parent siblings，按同名tag depth配对并创建Container；protected code内部恢复raw Text。extract函数还将HTMLBlock下Paragraph的HTMLInline提升到HTMLBlock层并修剪SoftBreak。
- `pairTags` 创建Container和protected Text都复用opening.id，可能同存活树重复ID；最终树不再保存原siblings形状。

**拟议适配契约**

- 单位：完整siblings list/inline owner；需before-finalize语法层或等价可逆provenance，以支持拆开Container再配对。
- 状态/依赖：tag/attrs/protected、兄弟序列、pairing config与HTMLBlock children重组；新增close会改变前方opening的匹配，不能只失效新tag。
- 收敛：配对关系、parent/children归属、raw和保护模式一致；每个新结构节点分配唯一ID并提供稳定角色匹配。
- 缓存：区分单tag语法缓存和配对子树缓存；移除旧Container后旧派生raw/children不可沿用。

**编辑验收**

1. `<span>a`后添加/删除`</span>`，siblings↔Container可逆，parent links与ID唯一性正确。
2. `<code>**a**</code>`改span再改回，protected raw与Markdown children切换，无旧Bold、重复ID或缓存残留。

### 18 EntityReferencePlugin

**现有事实与证据**

- 入口：`markit/src/plugins/commonmark/inline/entity_reference/entity_reference_plugin.cj::EntityReferencePlugin.register`。inline priority1500 `&` 与三格式renderer，无state/children。
- `entity_reference_parser.cj::tryParse` 查找semicolon距离不超过32，只接受代码列举named entities及decimal/hex形式。HTML/Markdown写entityReference；`entity_reference_renderers.cj::decodeBasic`在Typst只解码六个basic named entity，其余保留原文本。

**拟议适配契约**

- 单位：可局部candidate，但须向前找到所属`&`，记录到`;`/32限制/range尾的读取范围；受opaque owner及escape上下文约束。
- 状态/依赖：无全局写；raw/entityType/value与格式decoder版本，不把浏览器解码字符当三格式统一语义。
- 收敛：候选是否合法、覆盖和后继游标一致。
- 缓存：raw/type/value、decoder/plugin版本与上下文；前方多字节文本编辑后byte/rune映射分别平移。

**编辑验收**

1. `&amp;`删除/补回`;`，Text↔Entity正确，32边界附近失败扫描能被后续编辑唤醒。
2. 中文之后的`&#65;`改为`&#x41;`再改非法数字，三格式输出和后续rune/byte span等于全解析。

## 横向缺口与必须关闭的审查项

### 嵌套解析不是隔离事务

事实证据：`markit/src/markit.cj::Markit.createSession` 的setDetachedBlockParser闭包直接用同一个ParseSession调BlockTreeBuilder，再运行nodeBatchProcessors；`markit/src/core/session/parse_session.cj::ParseSession.parseDetachedLines`只改detachedParseDepth，没有保存/恢复activeLine、pendingParagraphLines/span、symbolTables、nextId。

拟议要求：嵌套语法上下文与文档语义效果分开；局部parser frame要恢复，允许全局生效的Heading/ReferenceLink写入则必须显式归属、撤销和重放。cache命中不能跳过这些效果。异常时depth与事务也要恢复。

### 起始探测没有纯度协议

事实证据：`markit/src/markit.cj::Markit.createSession`的setRegisteredBlockStartDetector调用continuation.tryStart，只检查continuation、不含leaf；没有副作用隔离。`ListBlockParser.startsDetachedBlock`同时有显式nested判断。

拟议要求：统一纯detect或事务化probe协议，由插件声明所需上下文；不能在核心重新写一套Markdown起始判断。当前内置tryStart通常只构造state，不构成任意第三方插件均无副作用的保证。

### Synthetic source与真实source缺少映射

事实证据：`markit/src/core/source/synthetic_source_builder.cj::SyntheticSourceBuilder.build`从0构造局部span；`BlockquoteParser.finalize`冻结synthetic raw；`markit/src/core/nodes/node.cj::Node.addChild`又递归attach外层source。quote子节点坐标不是文件绝对坐标。

`ListBlockParser.normalizeDetachedLines`去缩进却保留旧line.span，raw重建marker/空格；`ParagraphChildrenBuilder.appendChildren`从首行起点加拼接长度推inline span，未表达分行去缩进、CRLF等非线性映射；Setext插入literal newline的span为零宽。

拟议要求：所有18插件消费统一mapped text/segmented source协议，显式区分真实与synthetic范围，支持marker删除、去缩进、规范化、拼接和生成文本。编辑命中、patch与source属性必须回到文档坐标；不得只给synthetic subtree整体加delta。quote/list/HTML内部Markdown与含中文、tab、CRLF的组合必须纳入专项用例。

### ID、相等性与可见树不足

事实证据：`ParseSession.allocateNodeId`是session内单调计数；`Node.id`不可变。全文重建会改变后续ID，保存nextId只保证不重号而不保证稳定。HTMLInline已存在同ID父子风险。`Node.==`比较name/span/literal/level/slug/info，忽略children和各metadata。

拟议要求：编辑引擎提供身份匹配与新ID分配，插件声明结构角色/provenance；完整语义等价验证包含children、metadata、raw/source map及输出，不能复用Node.==。保留隐藏Heading、LinkDefinition、未解析reference和HTML tag配对前形状，编辑索引不依赖最终可见树。

### 状态、finalize与cache的收敛

事实证据：`markit/src/core/session/session_state.cj::SessionStateSnapshot`仅有dynamicName；Heading和ReferenceLink未持久化真实状态。session finalize与post finalize是不同队列；AutoAnchor在bundle中先于HTMLInline注册post hook。finalize会破坏性改树和删除refLabel。

拟议要求：phase/dependency、可逆派生结果、输入/输出state fingerprint、效果日志与cache dependency版本统一建模。不能仅重复现hook就宣称幂等增量；配置关闭时必须清除旧派生结果。AutoAnchor专项见[横向插件方案](plugin-cross-cutting.md)，其source属性更新与本文mapping/稳定ID协议联测。

## 验证记录与交付审查

- 已完成：`rg --files -g '*_plugin.cj'`及Standard/CommonMark目录的parser/state/renderer/bundle静态读取，核对18个语法插件、SoftBreak归属及注册类别；读取`Markit.createSession`、PluginRegistrar、BlockTreeBuilder、InlineParserEngine、Node和source builder的交接代码。
- 未执行：构建、单元测试、编辑差分测试、随机编辑、性能测试；本文不提供测试通过结论。
- 实施放行：共享插件协议、状态/效果撤销、source mapping、ID与依赖键先冻结，之后才能安全分派插件适配。
- 最终放行：18插件逐个完成上述至少两例，补全跨插件嵌套/定义/隐藏/配对矩阵；记录真实dirty范围、parse/semantic/render cache命中与失效证据。清除内置长期fallback，核心无新增Markdown语法分支，由独立审查者复核。
