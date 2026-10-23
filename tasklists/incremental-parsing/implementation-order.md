# 依赖、执行波次与审查放行

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

更新：2026-10-21。状态：全部编号实现任务Pending；当前仅方案文档。依赖以[README任务表](README.md)为准，本文将其展开为执行图，不增加隐藏串行边。

## Dependency Edges

以下22条均为hard edge；前驱完成后还必须由协调者审查证据才放行后继。多个前驱意味着全部通过。

- Task 01 -> Task 02
- Task 02 -> Task 03
- Task 02 -> Task 04
- Task 03 -> Task 05
- Task 04 -> Task 05
- Task 05 -> Task 06
- Task 06 -> Task 07
- Task 07 -> Task 08
- Task 07 -> Task 09
- Task 07 -> Task 10
- Task 08 -> Task 11
- Task 09 -> Task 11
- Task 10 -> Task 11
- Task 11 -> Task 12
- Task 09 -> Task 13
- Task 10 -> Task 13
- Task 12 -> Task 14
- Task 13 -> Task 14
- Task 14 -> Task 15
- Task 15 -> Task 16
- Task 16 -> Task 17
- Task 17 -> Task 18

不得额外添加Task13 -> Task12：12消费11的投影，在11审查通过后即可启动；只要文件所有权隔离，12可与仍运行的13重叠。也不得以“并行C尚未全结束”为由额外阻塞12。

## Execution Waves

“波次”是安全并行集合和审查点，不是所有任务必须等待同一批次结束的全局屏障。表中列出全部18任务；C中11、13各自按前驱就绪，13无需等待08/11。

| Wave | Tasks | 前驱与输入 | 所有权/执行规则 | Release Gate |
|---|---|---|---|---|
| S1 | [01](01-baseline-oracle.md) | 无 | 串行，子agent建立legacy/oracle/计数基线 | root审查dirty保护、四模式及known correction策略；仅放行02 |
| S2 | [02](02-plugin-contracts.md) | 01 | 串行，冻结公共facets、Source/Node/Mapping、runtime plan与typed最小原型 | root审查1.1.0可运行原型、接口与03/04互斥文件表；放行A |
| A | [03](03-editable-source.md)、[04](04-persistent-tree.md) | 各依赖02 | 两子agent并行：03仅source与source测试；04仅nodes/document/session效果存储与tree测试；shared interfaces冻结 | root分别审查，双方通过才放行05；不能仅一个Done就集成 |
| S3 | [05](05-block-edit-engine.md) | 03、04 | 串行集成真实rope/tree、恢复/事务/收敛 | root审查完整checkpoint事务原型、取消已ack源码语义及局部子树证据；放行06 |
| S4 | [06](06-inline-edit-engine.md) | 05 | 串行，成功/失败读取依赖与inline窗口；长logical Text不得隐藏O(N) | root审查安全窗口、负闭合依赖、text payload/patch局部性；放行07 |
| S5 | [07](07-standard-adapters.md) | 06 | 串行共享适配；冻结Heading、嵌套helper、标准typed codec与跨插件接口 | root审查13插件与共享交接，包括05真实事务原型；放行B |
| B | [08](08-commonmark-adapters.md)、[09](09-gfm-block-adapters.md)、[10](10-gfm-inline-adapters.md) | 各依赖07 | 三子agent并行，仅各组parser/state/adapter与独立测试；不同时改shared helper/core/codec注册面 | root独立审查；09+10通过可放行13，08+09+10通过可放行11 |
| C | [11](11-i18n-projection.md)、[13](13-render-services.md) | 11依赖08/09/10；13依赖09/10 | 就绪即分派：11拥有i18n投影/附件效果；13拥有CodeHL/MathTex/Mermaid服务与缓存；不得共同改插件状态/配置接口 | root审查11后放行12，不等13；root审查13后登记14的另一前置已满足 |
| S6 | [12](12-derived-queries.md) | 11 | 串行派生语义集成；可与未完13安全重叠，不改heavy service | root审查有序语义/AutoAnchor/TOC与14查询接口；12+13均通过才放行14 |
| S7 | [14](14-project-workspace.md) | 12、13 | 串行workspace/项目索引集成，保留dirty kit修改 | root审查cross-file、未改文件零扫描、多项目语言隔离；放行15 |
| S8 | [15](15-cli-worker.md) | 14 | 串行持久worker/版本/取消/resync/backpressure，保留既有CLI路径 | root审查进程协议与故障恢复，不回滚已ack source；放行16 |
| S9 | [16](16-vscode-preview.md) | 15 | 串行扩展/DOM消费，保留未跟踪extension既有工作 | root审查增量发送/有序patch/source map/scroll与交互；放行17 |
| S10 | [17](17-validation-gates.md) | 16 | 独立验收子agent串行执行全矩阵；失败派回owner修，不抢改产品实现 | root审查正确性、workcount、性能/RSS/10x规模及所有缺口；放行18 |
| S11 | [18](18-api-delivery.md) | 17 | 串行API/文档/交付门槛，按实际通过证据写结论 | root复核最终范围、legacy兼容与未解决项；无另行授权不commit/push |

## Scheduling Notes

### 07内部新增先行里程碑（2026-10-22）

Task06审查通过 → **07-P真实插件纵切 + 最小单文档stdio测试探针** → 07-P正确性/局部性/batch `-O2`复测审查通过 → Task07剩余Standard适配 → 原有B波次。此为Task07内部强制gate，不增加/删除18项正式任务之间的22条hard edges。

07-P范围与文件所有权按[Task07](07-standard-adapters.md)执行：实际Paragraph/List或Quote/Heading/ReferenceLink与typed renderer；协议探针仅独立测试原型、采用Task15同一schema，不改正式CLI或提前承诺workspace。06的成功不能替代07-P真实String成本验证。正式15仍依赖14并承担完整worker交付；最终30插件及全链路范围不变。

- root只负责安排、分派、交接、review、README百分比和最终报告；所有编号任务的调查、实现、测试与集成编辑均交给子agent，root不吸收未完成任务。
- 有3个可用子agent槽位时，A分派2个，B分派3个；C按就绪启动11/13，11通过后可释放槽位给12。不要为了填满槽位提前做未放行后继。
- 共享变更一律有唯一owner和串行交接。并行A的接口缺口退回02；B的共享Heading/helper/codec问题退回07或协调串行修订；C的语言投影与heavy服务互不改对方文件。不能将“改动很小”当并行抢改共享文件的理由。
- 编号task文件中的Scope boundary是具体约束；开始时列出实际可变文件表，发现重叠立即交协调者调整，不能只靠不同模块名声称隔离。
- 02可用Source假件验证typed codec保真；05必须运行真实source+tree完整事务原型。后者未过，即使06代码存在也不能释放07的大适配。
- 已ack source编辑与未提交parse/render事务分离；取消失败不丢输入。每次放行review同时检查版本/owner、状态/效果、映射/ID与计数证据，不能只看编译通过。
- 完成声明必须附改动清单、实际命令/退出码、oracle及计数/最小案例、环境版本、缺口与新增依赖；root审查后才可改README。当前文档存在不等于实现完成。
- 全部任务共用[设计锁](00-design-locks.md)与[验证缺口](verification-gaps.md)。新语义决定先回写契约并审查，不在后继任务中自行推翻冻结方向；全部30内置不得靠永久fallback结项。

## 本轮文档校验状态

协调者已实际完成并经独立只读交叉复核：28文档、18 Pending任务契约、22 hard edges/18节点无环、30Plugin的18+9+3覆盖、221本地链接及fragment问题0、28/28忽略、无跟踪tasklists，`errors=[]`。HEAD及6文件59+/5-基线未变；命令方法见[verification-log.md](verification-log.md)。这只证明方案完整性，全部编号实现任务仍Pending，未build/test或commit/push。
