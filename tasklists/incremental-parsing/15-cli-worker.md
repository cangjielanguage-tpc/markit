# Task 15：持久 CLI worker 与版本协议

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

**2026-10-22选型更新：** 用户最终确定使用现有SeaJson 1.5.0处理JSON，自实现Content-Length stdio framing与调度，**不引入rpcx，不新增stdx依赖**。见[评审补充](review-2026-10-22.md)的字节长度、限额、部分读写、写端串行及错误策略要求；最低仓颉1.1.0兼容仍须实测。当前基线为clean `c510aee`，下文“未提交”措辞仅为旧调查状态，须保护已合入的预览、映射和动画，不覆盖重建。

Status: Pending

## Execution Contract

- Depends on: Task 14。
- Unlocks: Task 16。
- Execution: 串行。
- Delegated owner: CLI协议与worker生命周期子 agent，由协调者指派。
- Scope boundary: 拥有`markit-cli`新增stdio worker命令、framing/schema/dispatch/lifecycle组件及其协议测试；消费Task14 workspace和既有render命令。输入为已验收workspace版本API、frozen capability/error contract、30插件适配报告；输出为可持续运行的worker、版本协议和client契约。禁止实现语法分支、修改extension、抢改workspace/core/重型服务、改README进度；不得覆盖当前render.cj未提交改动。

## Goal

提供stdin/stdout常驻worker，正常编辑只传差量并复用文档/项目会话；版本、取消、事务提交、背压、重同步及重启可验证。保留render/build文件输出、render --page与Markit append stream API；旧预览参数按15/16协调迁移后淘汰，不依赖live-server或每edit重启。

## Current State

- `markit-cli/src/commands/render.cj:26`已有未提交`--page`；`--incremental`仅复用输出资产，仍走build协调路径。
- `vscode-extension/src/session.js:123,131`每render新spawn并写镜像/读完整HTML。worker协议、frame parser和版本生命周期尚不存在。
- `markit-kit`当前GlobalContext静态状态要求过渡期串行项目任务；Task14负责实例化证明，本任务不得假定天然可并行。

## Follow-Up Work

**新增迁移必做：** worker以document URI选择文档，open/change/flush/close输入对应response/status/patch事务输出；资产/缓存自动管理，不暴露预览incremental开关。与16 owner串行交接：先完成worker与扩展新路径，双方集成测试通过且扩展无旧参数调用后，由15 owner删除CLI旧`--preview-stream`/`--incremental`入口并更新help；16消费其证据，17复验。不越权改扩展，不提前删入口。

**首次open渐进契约：** 在同一document source version下输出多个可独立完整commit的原子事务，维护递增render revision及base/target链；每个事务只提交有效、可显示单元或明确占位/状态，后续语义/资源修正以新事务更新。每次commit检查epoch/version/cancel，首次首屏不等全文/昂贵服务完成，不用单个巨型事务最后一次commit替代现有渐进体验。

1. 新增`worker --stdio`命令，保留render/build文件输出和`render --page`独立单页构建；`--preview-stream`与`--incremental`仅在15/16联合迁移验收后淘汰，旧参数明确报错并指向worker新用法/help，不再笼统承诺所有旧flag兼容。依仓颉1.1.0可用API实现流式读取、UTF8 JSON和stdout输出；工具链不支持时兼容实现，不擅自抬最低版本。
2. 冻结schema版本：ASCII Content-Length header、CRLFCRLF、UTF8 body byte长度；测试拆header/body、多frame粘包、中文/emoji、坏长度/JSON、超限body与断管。stdout只协议，日志/进度stderr。
3. 提供initialize/capabilities、workspace open/config/files/close、document open/change/flush/close、cancel、resync、shutdown；消息带requestId/projectId/sessionId/URI/workerEpoch/baseVersion/newVersion，change范围为同旧版本UTF16 offsets且验证不重叠。
4. 分离source edit accepted与render committed：所有source changes按版本应用，cancel只取消对应计算/响应，不丢已接受edit；latest-wins可取消旧render，下一计算从最新source开始。baseVersion不匹配返回结构化error和resync要求。
5. render用transaction begin/patch chunks/commit，标baseRenderVersion、targetDocumentVersion、overlay/index versions、order/target IDs/source map/resourcekeys；异常/取消/过期不能commit半事务。协议支持通用render subunit slots及其稳定ID/行片段/source-map delta，消费Task13交接，不靠core或协议按CodeHL名称特判；支持Task04/06 bounded text leaves/versioned payload的text-splice，UTF16切点由native map提供。client丢chunk/乱版本有恢复路径；正常行/文本edit不得为传输join整个大code或巨大TextNode literal/HTML。
6. 输出mode/incremental capability、fallback owner/facet/reason和workCounters；未知第三方parser/facet缺能力须报告实际回退范围：已证明隔离可安全单位full-parse，无证明整会话full-rebuild，strict显式启用，30内置无永久fallback。
7. request/byte高水位、maxpending、backpressure通知、合并flush和公平调度；source edits仍有有序ack，不无限存全文版本。worker任务在context实例化验证前串行多项目/语言，之后按Task14能力显式开启并行；多doc互不覆盖。
8. 关闭文档/项目释放引用，shutdown有drain/cancel策略和ack；stdin EOF/父进程退出清理。crash后client以新epoch重启、重新open活跃文档，旧response/未commit事务作废；有退避/次数限制与清晰错误。
9. 制作独立协议driver（拟新增）模拟乱序、cancel、背压、断管、重启、多个文档/项目/语言和strict/fallback，向Task16交接schema/样例/错误码/生命周期。

## Acceptance

- **迁移硬门槛：** worker自动资产/缓存复用、document URI路由及response/status/patch均通过；render --page与build文件输出保持。15/16集成通过后旧两个flag产生清楚错误和新help指引，扩展调用记录中二者为0；不能因此删除Markit append API或内部build增量方法。
- **渐进首屏硬门槛：** 人为延迟后部块/重型服务，首个完整有效事务已显示前部内容，随后有多个完整有序commit；中途cancel、文档改版与重启的新epoch阻止旧事务提交，无半事务可见。单次最终大commit不通过。

- **新增选型硬门槛：** JSON使用现有SeaJson 1.5.0，检查实际依赖解析结果，不引入rpcx、不新增stdx；最低仓颉1.1.0构建兼容有实证或明确阻塞。消费07-P同一schema/framing契约，验证UTF-8字节长度、部分读写、串行frame写出、header/body限额、重复/非法长度、坏UTF-8/JSON、截断EOF及错误恢复；SeaJson解析成功不替代schema/版本/范围验证。

- worker在连续1,000 edits中PID不变，正常change无临时完整MD/HTML文件、无全项目扫描、无全MD hex；首次open和显式resync允许全文。
- 每source版本被准确应用一次；取消render后随后flush结果等于最新完整source oracle；多个doc和project version隔离，过期epoch响应不能commit。
- framing对任意分片、UTF8长度、错误输入与限制有契约测试；stdout混日志测试失败，stderr正常记录诊断。
- transaction原子可见；错误/取消/缺chunk/错baseRenderVersion均不发布半结果并可恢复。重启只需active docs resync，不无限静默重启。
- 背压有有界内存/队列证据、不丢source edit；close/shutdown/断管释放source/snapshot/cache引用。
- GlobalContext迁移未完成时串行策略有效且可观测，未使用live-server或每edit新worker掩盖隔离问题。
- 保留CLI render/build文件输出、render --page及Markit parse/append stream回归；预览旧参数按迁移门槛淘汰而非继续兼容；交接Task16实际schema、兼容版本、driver命令/结果和打包调用路径。

## Verification Record

- 本轮只作静态调查和设计；没有新增worker或运行协议driver。
- 未来`markit-cli`的`cjpm test`及拟新增worker协议driver须记录真实命令；任何`WorkerProtocol`tag/driver名均为拟新增，不宣称现有可运行。
- 进程稳定、内存、队列和IPC字节通过实际计数验证，不能用“对象名叫Session”推断持久化。
