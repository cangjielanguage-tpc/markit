# 插件驱动的编辑增量架构

**2026-10-22补充（优先澄清）：** 见[最新评审](review-2026-10-22.md)。当前基线为clean `c510aee`；旧源码缺口须重新确认，保留已有映射/渐进预览/动画。batch不应强付编辑记录成本。第4节的后缀收敛须区分raw syntax与独立语义传播，不能以无关slug/编号全状态不等阻止语法复用。worker选用现有SeaJson 1.5.0 + 自实现Content-Length stdio，不引入rpcx或新增stdx。

更新时间：2026-10-21。本文是待实施设计，不表示下述候选接口已经存在、编译或通过测试。源码证据基于当前工作区，包含尚未提交的 CLI `--page` 和 `vscode-extension/` 工作；不覆盖或回退这些工作。

## 1. 当前事实与目标边界

现有 `markit/src/core/incremental/incremental_session.cj:45` 的 feed/feedBytes 只追加；finalize 在 :62 关闭块、冲刷段落、执行 session/post-finalize hook、置 finalized 并按 retention mode 释放源。`markit/src/markit.cj:138` 的批处理 parse 也由 createSession/feed/finalize 实现。这些是流式追加能力，不能直接称为任意位置编辑增量。

本项目新增持久编辑会话。每批编辑应只重做真实受影响语法区域、语义依赖和渲染单元，允许 fence、容器、编号等实际语义传播到文末。所有 30 个内置 Plugin 必须逐 facet 真适配并验证；只给内置插件贴 fallback 标记不算完成。第三方parser默认不支持增量；有边界/状态/语义隔离证明时可对安全单位完整重解析，无证明才整会话重建，显式strict可拒绝；禁止误报incremental。

保留 Markit.parse(String/InputStream)、renderHtml、parseWithCallbacks、createSession/feed/feedBytes/finalize 和现有 ParseOutput/typed Node 使用习惯。编辑 API 独立提供可重复 flush 与 EOF provisional close；不能让旧 finalize 后再 feed 的错误行为悄悄改变。

## 2. 数据与接口前置门槛

以下均为候选名和结构草案，实施任务须先用当前仓颉工具链做最小可编译原型，随后冻结正式接口。不能仅画不可变树示意图后跳过现有 typed Node、继承、字段和 renderer 的迁移成本。

### 2.1 版本化源与位置

候选 `EditableSource` 使用 piece tree/rope：叶片引用不可变 original/add buffers，分支聚合 UTF8 bytes、Unicode runes、UTF16 code units、逻辑行数、首尾是否 CR/LF。编辑边界跨片的 CR+LF 必须按一个换行处理；未闭合 UTF8 输入只由旧 feedBytes decoder 处理，编辑协议本身只接受合法 Unicode 文本。

| 操作 | 候选复杂度与条件 |
|---|---|
| apply sorted old-version edits | O(k log n + inserted bytes)，不能先 materialize 全源 |
| range slice / iterator | O(log n + returned bytes)，跨片正确拼接 |
| byte/rune/UTF16/line 转换 | O(log n + bounded leaf scan)，多字节字符边界有明确拒绝策略 |
| source anchor resolve | 锚点依附 piece/leaf identity 加偏移与左右亲和性，不按所有节点逐项平移 |
| 行索引 splice | 使用源树行聚合或共享的增量行树，不能每次 split 全文 |

编辑协议采用 VSCode 的 UTF16 rangeOffset/rangeLength，worker 只在该版本源树转换。public SourceSpan 的 byte/rune 数值仍可按需从版本化 source anchor 解析，保持旧 API 可读；新内核不为前方插入逐个重写后续所有 Node/source-meta。位置 delta 作为独立区间变换输出，HTML 中位置属性按实际访问或受影响可见节点更新。

当前 `SourceBuffer` 只有 append，byteAt/slice 遍历 segments，materialize 全量复制（`markit/src/core/source/source_buffer.cj:21,82,102,164`）。`LineIndex.findByByteOffset` 全扫（`markit/src/core/source/line_index.cj:30`）。必须实现并基准验证新数据结构，不能在相同 ArrayList 外包新接口而宣称达到目标。

### 2.2 Lossless syntax、typed view 与 overlay

候选 `SyntaxRecord` 保存 kind、稳定 NodeId、源锚点范围、原始分隔符/空白/换行、子节点槽位、插件 payload 和组合 source map。它是不可变、lossless 的原始语法层。未知语法也保留原始文本。解析贡献和渲染语义属于版本化 overlay：显隐、resolved link、fallback Text 视图、number/slug、anchor、语言等不覆盖原始语法。

前向引用最终 fallback 成 Text 是关键反例：当前 `reference_link_plugin.cj` 会在 finalizer 中替换 child。编辑后新增定义必须从保留的 reference syntax 再投影为 Link，不能从被破坏的 Text 缓存猜回语法。i18n 的吞节点、列表合并、附件移动同样作为可撤销结构投影，保留原始节点所有权。

稳定 ID 使用 session-scoped 单调 allocator；未变树复用原 ID，替换节点分配新 ID，容器自身仅在明确保留身份时沿用。不得用 byte offset、内容 hash、slug 或 anchor 编号分配 ID；重复文本仍是不同节点。缓存内容摘要不得含绝对坐标；另有 shape/content/semantic/render/position revision。当前 `Node.stableHash()` 包含绝对坐标且递归整树（`markit/src/core/nodes/node.cj:344`），不能直接作为每次编辑缓存键或收敛条件。

typed 兼容门槛是用 HeadingNode、LinkNode、TextNode、TocNode/TocItem 和至少一个容器做实际 prototype：

1. 定义 `NodeCodec`/`NodeViewFactory` 按注册 kind 将 SyntaxRecord+overlay 投影为原有 subtype；验证 renderer 的 `as HeadingNode`/`as LinkNode` 仍成功，字段语义一致。
2. 验证 typed view 的 children/parent、rawContent/sourceSpan、metadata、JSON、三格式输出、继承 renderer hook 均保持旧行为；不能用 plain Node 悄悄代替 subtype。
3. 编辑 snapshot 的 view 不允许原地改动已发布版本；旧可变 Node 构造和 DSL 使用通过兼容 materializer 工作。overlay 事务内修改必须走受控 adapter，不能直接把老 children 数组共享到多个版本。
4. 若 view 方案不满足当前语言/公共字段约束，先实现按变更路径 COW 的 typed codec；只 materialize 被查询的兼容视图。记录内存和 clone 数，禁止每 edit 全树复制。

`DocumentSnapshot` 当前直接持有可变 root/lineIndex，构造全树索引、range lookup 全扫（`markit/src/core/document/document_snapshot.cj:13,27,46`）。新 snapshot 应固定版本并共享未变索引树；nodeById 索引按 splice 更新，区间查询用 source anchor/order 索引。历史 snapshot 在后续编辑后结果不变；历史数量和保留字节有 quota。

### 2.3 真实 source map

候选 `SourceMapSegment` 表达 generated range 到 parent source range 的映射、被移除前缀、插入虚拟字节、边界亲和性与映射精度。映射链可组合到原始文档；API 同时支持 byte/rune/UTF16，并明确 unmatched/generated region 的最近可定位边界。

当前 `SyntheticSourceBuilder` 从 0 重建坐标（`markit/src/core/source/synthetic_source_builder.cj:40`）；I18n block 解析 synthetic 子树后只冻结 rawContent，没有原文 span remap（`markit/src/plugins/i18n/block/i18n_block_parser.cj:84`）。需覆盖列表/quote/i18n 去缩进、换行归一、inline 子区间、转义/entity、code 高亮包装和渲染生成字符。不能把 synthetic-local span 发布为文档绝对 span。rawContent 缓存和 source-map 是两项独立验收。

## 3. 插件定义与冻结运行计划

### 3.1 按 facet 声明，而非一个 stateless 开关

**2026-10-22用户澄清：** 以既有BlockParser及相关parser/extension point为直接能力声明单位，提供默认false的supportsIncremental设置及安全默认增量方法（均为候选名称）；第三方无需覆盖即可保留普通解析，选择支持时覆盖相应方法。同一plugin可同时注册支持和不支持增量的parser，plugin级设置仅补充，不能替代逐parser判断。bool只表示资格声明，不证明完整checkpoint/restore/effects能力。具体仓颉1.1.0默认方法语法由02原型验证，禁止新增旧插件必须实现的抽象方法。默认compat按已证明安全的最小范围回退：仅当引擎或provider证明边界、状态及语义副作用隔离时，调用该单位完整解析；无法证明隔离则整会话full-rebuild，不假定未知插件局部安全。报告owner/parser/facet/reason及fallback范围，strict仍须显式开启并原子拒绝。默认方法报告unsupported或在已证明安全单位调用完整解析，不空restore。全部30内置适配是独立交付门槛。

插件定义语法及手写注册 API 应生成同一种候选 `FacetRegistration`。核心只认识通用 facet contract、依赖键和能力，不根据 Markdown 符号或插件 name 分支。语法匹配、容器规则、边界扩展和恢复方法由相应插件提供。

每条 registration 保留 ownerPluginId、pluginVersion、facetId、priority、registrationOrdinal、grammarVersion、配置 fingerprint、implementation fingerprint。freeze 后排序仍遵循现有 priority/注册次序，建立不可变 runtime plan 与 plan fingerprint。裸 finalizer lambda 不得丢失 owner 和副作用描述；配置相同但顺序不同不能误用缓存。

| Facet | 必须声明或实现 |
|---|---|
| parser：leaf/continuation/paragraph/inline | dispatch hints、真实 matcher、probe purity、重解析容器、lookbehind/dependency、frame codec、EOF provisional 行为、语法贡献 |
| session state | 初始状态、persistent snapshot/restore、等价/摘要、配置依赖、读写键、ordered contribution reducer |
| emission filter | reads/writes、可能吞节点/反向修改/移动范围、deferred emission 描述、撤销和 replay；不是仅返回 Bool |
| batch processor | 输入区域、前后文/顺序依赖、输出 ownership、树变换 journal、局部 replay/收敛摘要 |
| session/post finalizer | 阶段与排序、读取集合、贡献、撤销、EOF 临时封口、可重复投影/兼容 terminal adapter |
| renderer | 格式、读取的 syntax/overlay/config keys、单位边界、source-map、输出资源与缓存键、外部依赖 |

能力可组合 local/container/ordered/dependency/document，不等于字符串标签就是实现。内置每一 facet 要有可运行 adapter、编辑案例和调用计数证据。未知第三方 facet 缺项时在打开会话阶段做 safe fallback/strict error，结果明确实际mode、fallback范围和owner/parser/facet/reason（无法证明隔离时`mode=full-rebuild`）；不能仅因 parser 声称 local 而忽略其 finalizer 未声明。

### 3.2 Probe 与事务

当前 registered block detector 会调用 tryStart（`markit/src/markit.cj:96`），tryStart 可以分配 frame/修改状态；以它做边界探测会污染重放。候选 `probeStart(ReadOnlyParseContext, SourceCursor)` 必须纯读取，不 allocate NodeId、不写 state、不发 patch。实际 parse 在事务中提交 mutation journal；无法拆纯 probe 的既有 parser 先用可丢弃 fork transaction，成功后也只由正式 parse 提交一次。

事务包含 syntax splice、overlay contribution、dependency subscriptions、state transition、resource requests、patch records。异常、cancel、版本被替代时整体丢弃，不泄漏到 live root、symbol table 或 renderer cache 的可见索引。内容 cache 可暂存，但只有完整键和提交后的引用计数才能保持。

## 4. 检查点、恢复与收敛

候选 `ParseCheckpoint` 至少包含 source version/anchor、runtime-plan fingerprint、openFrames 栈及各 plugin frame snapshot、pendingParagraph 行锚点/termination context、deferred emissions、插件 session state persistent root、ordered reducer入口状态、依赖上下文 stamp、detached/source-map stack、indent/context flags、allocator high-water mark。不能只保存 parser 名称或最近行号。

SessionStateSnapshot 当前仅 dynamicName、没有 restore；Heading/I18n/Reference/Footnote 快照也未包含有效内容。设计要求 persistent map/trie 或版本化 undo journal：每次变更记录增量贡献/新 root，checkpoint 共享未变 map root；绝不在每块边界 clone 全 symbol table 或所有 Node 引用。deferred state 引用稳定 ID 与 syntax/overlay version，不引用可变旧 Node。

选择最近仍有效的前置检查点，恢复输入状态。只有以下条件全部满足才能复用旧后缀：

1. 对齐到同一未改源后缀与容器边界，源片段内容相同；hash 只是加速筛选，有碰撞验证或等价结构验证。
2. openFrames、pendingParagraph、deferred emissions、所有影响后续解析的 plugin state 等价。
3. runtime plan/配置相同，读过的依赖上下文版本一致；包括“当时没有定义”的负查询。
4. ordered reducer出口状态、结构归属和 source-map context 等价；不能只比当前行文本或单一 stableHash。

可以在每个稳定块/容器边界保存检查点，按配额和成本自适应稀疏化。未闭合块必须从其 opener 或更早有效边界恢复；不承诺固定前后 N 行。后退/前进范围由 plugin contract 决定，核心不写 fence、heading 或 `:::` 特判。

EOF 在编辑会话中形成版本化 provisional close：临时完成 paragraph/open frame/finalizer 派生视图，但保留 close 之前可恢复状态和原始语法。下次 edit 先撤销 provisional 贡献再恢复。独立 `close()` 释放会话；旧 streaming finalize 保持 terminal、不可再 feed。

## 5. 一次编辑的执行算法

以下是拟议执行顺序，可直接拆成实现与验收任务。

1. 验证 session/workerEpoch/baseVersion、文档开放状态、UTF16范围合法和 edits 不重叠；所有 edits 解释在同一旧版本，按逆位置应用到 source tree。成功更新源版本但尚不发布解析结果。
2. 查询增量区间索引，结合 plugin facet contract 计算最早受影响可恢复子单元/检查点和可能反向修改目标。whole inline owner或whole block容器重建只能作为迁移安全起点，不是激进方案完成状态；最终需使用下节的嵌套子单元和候选读取窗口。
3. 创建 transaction，撤销该区域拥有的 syntax/overlay/state/dependency contributions，包括上版 EOF provisional close；保留可复用原始语法和未变资源缓存。
4. 恢复完整 checkpoint，使用冻结 runtime plan 重解析变更区域；保留未变节点 ID，逐次记录 source-map、读依赖和输出状态。扩展区域直至恢复收敛，或 EOF。
5. 对变更贡献做 dependency diff。更新符号定义有序集合及反向 subscriptions；定义新增、删除、首定义切换都唤醒正查询和负查询。ordered 数据从最早受影响位置重放，出口状态相同则停止。
6. 按冻结的兼容语义阶段执行可撤销 overlay，计算可见 heading/text、slug/number、reference、i18n结构、anchor/TOC等；阶段依赖应由注册数据给出，不能核心按插件名调度。具体兼容次序见 [跨插件说明](plugin-cross-cutting.md)。
7. 只为 render key 改变的单元生成请求格式片段与 source-map patch。位置变化走独立位置变换；未变 syntax/semantic/render 单元调用次数为零。
8. 在 commit 前检查取消、源版本和事务输入依赖仍有效；原子发布 snapshot/index/overlay/patch transaction。旧版本结果可以完整丢弃，不能把半个 transaction 显示给 webview。
9. 对慢计算/资源完成发送同目标版本的后续事务，检查其单元 render key 仍匹配；过期结果不得覆盖新代码/公式。记录解析范围、传播范围、cache、fallback、耗时与 IPC字节。

语义依赖使用 `DependencyKey(owner, namespace, key, scope)`，订阅记录查询参数和结果版本。定义集必须保留重复定义的文档顺序与 winner 规则；删除首定义会显露后定义。缓存不存在查询同样是依赖；不能只索引 resolved link。全局编号、重复 slug、anchor 和 footnote顺序用按文档序的 contribution tree/summary reducer，复用可结合摘要；归约不具可结合性时从检查点重放到真实状态收敛，不能虚报 O(log n)。

### 5.1 激进粒度的独立完成门槛

block engine须允许plugin声明可恢复子单元和嵌套检查点，例如paragraph的inline片段、quote的逻辑行/子块、list的item/子块。最小重建路径由编辑点所在leaf向外上升，只有相应容器的continuation/归属state变化才扩大；普通深quote/item文字编辑不得常态重解析整quote/list。保存每层输入/输出context、去前缀映射和有序贡献，重建变更路径并共享未变兄弟，避免仅把top-level node当最小单位。

inline engine须保存成功候选和失败候选的实际读取区间、read-before/read-after、delimiter/escape上下文、递归owner、未找到closure的负依赖，以及输出节点范围。编辑点命中失败候选读取区间时需回退到该候选起点；否则可能漏掉在编辑点之前开始、因本次补闭合而成功的语法。普通inline文本修改从安全检查点重扫小窗口，只有源内容、候选读取依赖、delimiter栈/递归state和出站context一致才复用后缀。

超长纯文本paragraph可能只含一个巨大TextNode，局部parse仍不足以避免O(N) literal/HTML拼接和DOM替换。Task04/06必须提供bounded text leaves或versioned text payload，保留legacy TextNode可查询视图；正常编辑输出通用text-splice或render subunit patch，UTF16边界与转义/entity映射由native source-map给出，webview只替换局部DOM Text range。不得为一次普通字符edit整段HTML/全文传输。显式调用legacy toHtml/literal全文导出可以O(N)，但不成为热路径必经步骤。

新增/删除delimiter、closure、escape或递归语法可能真实影响到inline owner末尾，这类扩大允许但必须输出原因、扫描字节/候选数；不能对每个普通字都全owner重扫，也不能固定N字符窗口忽略负读取。所有候选规则来自已注册plugin，核心不得硬编码强调、link或i18n符号。

该能力由总体DAG独立Task06验收，不能留成“将来优化”。加入超长单paragraph、数千item list、深quote和嵌套inline数据集：普通文本小edit只重扫受影响窗口/子单元，未变兄弟parser与renderer0调用；闭合符改变真实扩展时与full parse一致并有工作量解释。Task05建立事务/保守正确路径，Task06关闭whole-owner常态重扫缺口，再释放全面插件适配。

## 6. 渲染、CodeHL、公式与配额

渲染缓存键包含语法内容/形状、renderer fingerprint、格式、读取的 overlay keys、语言/主题/配置、外部资源版本。内容与 source-position 分离；source-map 更新不得要求重做高亮。缓存项有字节大小、最近访问、引用计数、generation和命中计数，按 session/project/global quota 淘汰，不能永久保存每个 edit 的全文/HTML/snapshot。

CodeHL 以代码单元为入口缓存，支持行级词法状态检查点：从首个改变行的前置状态重算，比较行内容与完整词法出站状态，收敛后复用后续 tokens。多行注释/字符串或语言/主题变化按实际影响失效。不能只比较高亮字符串或固定重跑数行。不变代码单元 CodeHL 调用数必须为 0；单位内部改变的后缀行应有复用计数。

行内/块公式以表达式、display mode、宏/配置/字体/引擎版本缓存，图按其 DSL/content/config 单元缓存；不变单元公式/图渲染调用数必须为 0。数学/图依赖全局宏时登记明确依赖并失效相关单元，不能每个正文字符都清空全缓存。render overlay输出与 source-map mapping 分别缓存。

配额覆盖 source old buffers、checkpoint、历史snapshot、syntax payload、dependency indexes、HTML/token/math/graph缓存和pending请求。建议配置字节上限与 LRU；打开/关闭文档、worker restart、取消都必须释放引用。性能测试记录 10,000 次编辑后的 retained memory，排除只测单次 latency。

## 7. 持久 workspace 与 CLI 协议

**2026-10-22迁移约束：** document URI取代预览命令行page选择，worker自动管理资产/cache；open/change/flush/close输入对应response/status及patch事务。首次open必须多个独立完整原子事务渐进展示首屏，每次commit校验source version/epoch/cancel及递增render revision链；不能用一个巨大事务的末尾commit回退到等全篇完成。具体淘汰时序与验收见[Task15](15-cli-worker.md)、[Task16](16-vscode-preview.md)。

现有扩展每 render spawn CLI（`vscode-extension/src/session.js:123,131`），CLI `--page` 在全项目 scanner 之后才裁剪 renderFiles（`markit-kit/src/renderers/markdown_renderer.cj:781,789`）。本设计使用独立常驻`worker --stdio`；保留render/build文件输出、render --page独立单页构建与Markit append stream API。预览旧--preview-stream/--incremental仅在CLI和扩展同步迁移验收后淘汰，旧flag明确报错并指向新用法，不能笼统要求所有旧flag永久兼容。worker 依 stdin/stdout运行，不依赖 live-server，不每 edit 重启。

候选 `WorkspaceSession` 持有 config/summary/file ownership、各文档编辑会话、heading contribution、FileTree、跨页链接反向索引、编号入口/出口摘要和资产缓存。首次建索引可读全项目；普通改文档只读其事件/增量，不扫描未改文件。文件创建/删除/rename、summary顺序、config和语言事件精确更新；全局编号按文件序向后传播到出口状态收敛。

当前 `GlobalContext` 是进程静态可变状态。第一阶段 worker 明确串行调度项目/语言任务并在安全边界切换完整 context，禁止并发污染；完成实例化 workspace context且有多项目测试后才开放并行。串行阶段也保留多个持久会话，不等于每次丢弃索引。

### 7.1 Framing 与消息

拟议 framing 为 ASCII `Content-Length: <UTF8 byte length>\r\n\r\n` 加一个 JSON body；支持任意 chunk分片、多个 frame粘包、非ASCII payload。stdout只发协议，日志/进度走 stderr；限制 header/body大小、拒绝坏长度并返回明确错误。以下方法名与字段均为草案，实施时先锁schema并做双端契约测试。

| 消息 | 必需语义 |
|---|---|
| initialize | protocolVersion、clientCapabilities、workerEpoch、serverCapabilities、limits |
| workspace/open / updateConfig / filesChanged / close | projectId、config fingerprint、事件版本；返回索引ready/version与失效摘要 |
| document/open | URI、language/config、完整初始text、documentVersion；返回sessionId与初始snapshot |
| document/change | requestId、sessionId、workerEpoch、baseVersion、newVersion、同旧版本UTF16 edits；响应accepted或versionMismatch |
| document/flush | 请求目标version和输出格式；16–32ms/adaptive debounce只合并计算，不丢 edit |
| cancel | requestId；取消计算不回滚已接受源版本，下一任务从最新源继续 |
| render/transaction | transactionId、baseRenderVersion、targetDocumentVersion、overlayVersion、开始/patch分片/commit；client只commit完整事务 |
| resync | 错版本/丢patch/worker重启时重发该文档full text/snapshot，不能常态每edit全文传输 |
| close / shutdown | drain或取消策略、最终ack、释放session/worker资源；父进程退出/管道关闭也清理 |

change 接收确认和render提交分开。响应含 mode、fallbackDiagnostics、reparsedRange/workCounters；strict模式在缺能力时拒绝会话。协议包含错误码、超时、最大pending bytes/requests，服务器发 backpressure/high-water通知，客户端合并未发送 edits或延迟flush；不能无限积压完整版本。源edit从不因latest-wins漏应用，过期render可取消。

worker crash 后 client递增/替换epoch，清除该epoch未完成事务，重启一次worker并重开active documents；新epoch不能接受旧response。重启次数/退避有上限并显示错误，不能无限静默重启。缓存恢复只接纳完整fingerprint匹配的内容cache；不可直接信任上次未commit的state。

## 8. VSCode 与 DOM 差量

`onDidChangeTextDocument` 使用 contentChanges 的 rangeOffset/rangeLength/text和document.version；首次open/resync才 getText。不要为验证selection长度反复 getText；使用document offsetAt(end)/已知版本长度。扩展只维护必要源长度/版本与workerack，不重复拼接全文镜像。磁盘watch与dirty overlay分版本去重。

worker发顶层或已声明DOM单元的 insert/remove/move/replace/meta patch，带稳定nodeId、parentId、beforeSibling/slot、source-map差量和资源键；webview维护nodeId→DOM索引，有序应用事务，错误请求局部resync。相同HTML的重复节点不得依outerHTML猜身份。无需完整HTML template parse和signature reconcile；不再把全MD hex嵌入预览更新。

滚动/选择映射来自原生parser+renderer source map，不能在selection.js硬编码i18n/entity/Markdown语法。按渲染块保存DOM text range→原始UTF16区间映射，变更块重建、未变块复用；生成字符和隐藏语言边界有明确映射策略。位置delta更新映射索引，避免全文offset重写。

布局索引按可见块缓存top/height及source范围，用ResizeObserver/图片加载/代码展开使相关区域失效；定位用有序索引/二分，不每scroll querySelectorAll+getBoundingClientRect+sort。只初始化新增/改变的CodeHL、公式、图单元。原有选择、滚动、copy-source、跨页链接与语言切换必须有自动/人工回归。

## 9. 性能与正确性验收

下列是**拟议目标，未实测**，不是现有能力或保证。实现任务需先记录当前基线、固定机器/构建模式/数据集，报告p50/p95/p99与工作量，不用孤立平均值判断。

| 场景/指标 | 候选验收 |
|---|---|
| warm普通局部编辑native update | p95 ≤30ms；源版本接受到提交测量，单列debounce |
| 编辑到可见预览 | p95 ≤100ms；默认16–32ms或负载自适应debounce，原120ms默认无法达标 |
| webview patch | p95 ≤16ms；大真实变更可分事务准备，commit保持原子可见 |
| 普通局部修改 | 未受影响parser/semantic/render单元0调用；不变CodeHL/公式/图单元0调用 |
| workspace | 未改文件读取/parse数0，不每edit整站prescan |
| hot path禁项 | 不spawn、不getText全源、不发全MD hex、不全页HTML reconcile、不全树hash/snapshotclone、不逐节点offset平移 |
| scale | 10KB/1MB/10MB文档，100/1,000文件；文首/中/尾、100/1,000/10,000次edit；局部工作量随无关体量增大保持常数/对数趋势 |

每edit记录accepted/source/parse/semantic/render/IPC/DOM阶段耗时，reparsed bytes/lines/blocks、checkpoint恢复、状态传播长度、依赖失效keys、cachehit/miss、HTML/IPC字节、DOM复用/替换、源/历史snapshot/cache内存、fallback原因。

正确性以同配置fresh全量parse为oracle：AST语义、三格式、JSON、rawContent、可见heading/TOC/link/anchor/footnote/i18n和源映射一致；ID单独验证未变节点稳定。包含随机编辑/撤销重做、多edit、分块UTF8 stream、CRLF、emoji、负查询、重复定义/slug、syntax fallback恢复、嵌套synthetic映射、取消/重启/多项目/背压和30插件混合。现有stream测试不能替代这些编辑测试。

## 10. 实施释放门槛

依赖顺序是：事实与兼容基线 → facet/runtime/schema契约 → source tree/indices/source-map和typed codec/view原型 → 事务/完整checkpoint → 编辑解析/收敛 → 全部内置facet适配与跨插件overlay → workspace/缓存 → 常驻协议 → VSCode差量 → 差分/性能/兼容总验收。共享接口由单独串行任务冻结后，插件组才可按隔离文件并行；后继必须由协调者审阅前驱证据后释放。

以下任一未完成不能宣称功能完成：source/tree结构仅stub；typed renderer回退plain Node；snapshot仍全树clone；内置facet fallback；source map仍synthetic局部坐标；改正文仍全站扫描/全页hex/HTML；协议缺版本/事务/恢复；性能目标没有可复现数字。所有接口名与复杂度仍须由实施证据确认。
