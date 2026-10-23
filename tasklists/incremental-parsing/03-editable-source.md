# Task 03：可编辑源、坐标索引与组合映射

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Done

## Execution Contract

- Depends on: Task 02。
- Unlocks: Task 05（仍需Task 04完成并审查）。
- Execution: 并行A，与04并行；必须在02冻结Source/Node/Mapping接口后开始。
- Delegated owner: 源存储与坐标子agent，实施时由协调者指定。
- Scope boundary: 未来只拥有`markit/src/core/source/`的接口后实现、`markit/src/tests/unit/source/`及独立source property/benchmark测试。不得修改02冻结的shared interfaces、core/nodes/document/session实现或04的tree测试；接口问题退回02，runtime接线留给05串行集成。
- 输入：02版本源/坐标/anchor/map接口与edit合法性、01reference model与计数collector。输出：可编辑source实现、组合map/anchor实现、复杂度与Unicode/CRLF证据、可供04/05使用的稳定源句柄；不宣称tree事务已完成。

## Goal

用支持局部编辑、版本共享和多坐标索引的rope或等价分段结构替换编辑热路径上的线性扫描/全文拼接，并为嵌套规范化提供可组合真实source map。

## Historical State (before Task03 implementation)

- `markit/src/core/source/source_buffer.cj::SourceBuffer`以ArrayList segments追加；byteAt/slice扫描segments，materialize构造全文缓存，没有replace/version树索引。
- `line_index.cj::LineIndex`以ArrayList add，findByByteOffset逐行扫描；`line_scanner.cj::LineScanner`处理append chunks和CRLF但没有编辑join/split恢复。
- `source_span.cj::SourceSpan`保存绝对byte/rune端点，slice/merge只做算术；TextView/Cursor依赖SourceBuffer，尚无UTF-16、惰性anchor或组合映射。
- `synthetic_source_builder.cj::SyntheticSourceBuilder.build`从0生成剥marker文本坐标；不能直接映射回quote文件位置。list去缩进、paragraph拼接及HTML内部提取也需要分段来源。

## Original Implementation Plan (historical; current evidence below)

1. 按02接口实现持久rope/分段平衡索引，节点聚合byte/rune/UTF-16与换行信息；局部insert/delete/replace产生新版本，旧view/snapshot仍有效。source版本接受/ack与parse提交分离，已ack源码版本不可因旧计算取消回滚。叶大小有界，避免以“一个巨大叶”退化为全文扫描。
2. 实现byte↔rune↔UTF-16↔line/column查找与局部cursor/slice，遵守02非法切点和端点亲和规则；跨版本anchor resolve与edit delta map不遍历全部节点或旧offset。
3. 处理CRLF跨叶与编辑join：插入/删除CR、LF使原两叶拼成或拆开CRLF；line aggregate同时保存边缘状态，不得只更新被编辑叶而遗漏邻接pair。raw与normalized坐标按02协议映射，不偷换定义。
4. 实现line split/concat与增量line index，读取任意局部范围不调用materialize；在EOF、空文档、末newline、单CR及连续newline上与reference model对照。
5. 实现可组合mapped text：保留segments来源、删除的marker/indent、CRLF→newline规范化、跨行join和synthetic文本的来源类别；支持map compose、局部source query及多段结果，不能把一段synthetic span强行压成真实连续span。
6. 用测试场景模拟quote去marker→list去缩进→paragraph拼接、HTML内片段提取；映射组合回原文。实现通用变换，不在core/source写Markdown语法识别；具体变换由后续插件声明。
7. 兼容旧SourceBuffer/TextView/Cursor/LineScanner公共行为与retention modes；编辑会话所需版本引用不可被legacy finalize release提前释放。引用生命周期/释放策略交给04/05使用，不通过永久保留所有版本逃避内存门槛。
8. 接01计数：树高/索引访问、叶扫描、slice输出字节、materialize次数、版本共享/回收；提供可执行复杂度检查和不同N的负载。写入短替换不应因文档前缀增长而线性访问全部行。

## Acceptance

- 小型可跑验收：源`甲😀\r\nB`分在CR与LF两侧叶，删LF、恢复、插CR/LF制造join，再在emoji前后合法替换。所有坐标round-trip、line结果与reference model一致；非法UTF切点按02策略失败且版本不变。
- 旧版本slice在后续编辑后保持原值，新版本slice正确；局部查询和edit不调用全文materialize。全文导出显式调用仍可使用，不禁止合理O(N)导出成本。
- 复杂度门槛：定位/坐标查找为O(log N + B)（B为有界叶内解码），edit为O(log N + 变更叶/插入字节成本)，slice为O(log N + 输出规模)，不能要求输出k字节却声称O(log N)总成本。通过计数而非仅wall time验证，N指索引规模。
- 组合映射最小例覆盖去前缀、去缩进、CRLF normalize、join、生成newline，并可把深层局部编辑命中真实文件位置；synthetic无唯一来源时显式表示，不能返回编造坐标。
- 不遍历全文件行索引重写offset，不修改Node/Document实现，不抬仓颉最低版本；legacy source/Streaming回归差异均解释记录。
- 输出接口符合02冻结契约，04可独立消费抽象句柄；05取得真实源实现与测试证据，完整编辑事务尚待05。

## Historical Verification Record

- 本轮：仅静态读取SourceBuffer、SourceSpan、LineScanner、LineIndex、SyntheticSourceBuilder和调用缺口；未实现rope，未运行复杂度/新测试。
- 未来在`markit/`执行`cjpm test --no-progress`及`cjpm test --no-progress --include-tags=Streaming`，记录1.1.0编译器/工具版本。
- 拟新增：`cjpm test --no-progress --include-tags=EditableSource`、`cjpm bench --filter=EditableSourceBenchmarks`；测试中固定seed输出失败edit序列和rope操作计数，不能只贴平均耗时。

## 2026-10-23 当前实施与验证

- Owner：`/root/task03_source` 实现 rope/store/坐标与主测试；`/root/task03_source/source_map` 只实现 map/builder 与 map 测试。Task02 owner 独占共享编译，root 独占 README 与共享 verification。
- 可变范围实际为 `markit/src/core/source/editable_{rope,source,source_map}.cj`、`markit/src/tests/unit/source/editable_source{,_map}_tests.cj`、本任务文档及 `task03-source/`。冻结 core/editing、nodes、document、session、Task04 文件和 runtime 未修改。
- 已实现不可变 AVL rope，叶上限 1024 byte；byte/rune/UTF-16/line 索引、跨叶 CRLF split/join、原版本 batch 原子发布、同点插入稳定序、旧快照、正反向 delta anchor，以及无 Markdown 识别的通用 mapped text/source map compose。
- 首版最终冻结依赖下 source 包 compile exit 0，官方 `--test -O2` 两次 11/11 Passed，0 skipped/error/failed，exit 0；第二轮包括删 CR/LF 中间 X 形成新 CRLF，再插 X 拆开的断言。见 [实施与命令证据](task03-source/implementation.md)、[第二轮测试日志](task03-source/source-targeted-test-2.log)。
- 已记录同 SDK 1.3-alpha、同 O2 的 16 KiB/256 KiB/1 MiB 局部替换与字符串参考正反顺序计时，每样本文本精确校验通过；无统计无退化结论。原始记录见 [初版最小计时](task03-source/local-edit-time.csv)。
- 按 root 审查补固定容量 2048 anchor 投影缓存，整数 key+环形 FIFO；同一出生 anchor 的单调 target 只重放新增 batch，旧目标从 birth 计算不覆盖较新 projection。新增 2 个定向测试（共 13 个）已最终独编复跑 13/13 Passed，0 skipped/error/failed、exit 0（0.625s）。见 source-compile-3.log、source-tests-compile-3.log、source-targeted-test-3.log。首次共享 compile 被 source 包 `None` 枚举同名绑定阻断，现已显式 `Option<RopeAnchorKey>.None` 修复并冻结重交；保留失败日志，不记为通过。
- 最终 source-package-3 已重新链接同 O2 driver，compile/run exit 0，所有输出精确 expected 校验通过，见 local-edit-time-final.csv。最终共享 `cjpm test --no-run --no-progress` compile6 exit 0；27 包全量官方 binary console 实跑 632/632 Passed，0 skipped/error/failed，其中 source 21/21（含新增 13）、Streaming 15/15。root 已实际审阅并通过当前范围验收，状态 Done。见 [共享编译日志](parallel-a-verification/integrated-compile-6.log)、[全量回归 summary](task01-baseline/parallel-a-full-console-1/summary.json)。历史失败日志继续保留，不再作为当前阻断。
- 复杂度边界：坐标 O(log L+B)，slice O(log L+返回内容)，局部 edit 路径复制；冷/淘汰 anchor O(跨越 edits)，cache 命中仅重放新增 edits。store 不保所有旧 roots，但 delta history 尚未 prune，空间 O(已接受 edits)；05 必须按 active source/anchor leases 决定安全回收。不能宣称所有 resolve O(log N)、长期历史已回收或内存恒定。

上文原始计划中的最低 SDK、通用 oracle/计数/benchmark 框架和统计性能门禁按本页用户裁剪说明 Deferred by user scope；现实施仅有产品代码、最小定向测试与最小实测。

