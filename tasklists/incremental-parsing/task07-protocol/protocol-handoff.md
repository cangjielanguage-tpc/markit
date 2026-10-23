# 07-P 独立 stdio 探针：Task15 单一协议来源

更新：2026-10-23。所有权：`/root/task07_protocol` 唯一修改本目录；04 owner 拥有真实 Standard profile/session/provider，02 owner 唯一协调编译及官方测试。未修改生产 CLI、workspace 配置、core、plugins 或 README。

状态：根协调者确认02尚未启动私有探针后，已授权本目录 owner 独立编译/pipe小测试；实际 SDK 1.3.0-alpha 编译成功，16项 transport/source 黑盒验证通过（证据见本目录 verification.md）。当前执行后端为 **source-only**，真实 `EditableRopeStore` 接受修改，但 `parseVersion=renderVersion=-1`，flush 返回 `E_PROVIDER_PENDING`。这不是 Task07 产品纵切通过证据。

## 固定 wire 子集（protocolVersion=1）

单一来源为本目录 `protocol.cj`、`stdio_probe.cj` 和本文。Task15 直接接管/迁移这套 framing/schema；原型退役后不得保留另一套实现。Task15 的 workspace、transaction chunks、资源和渐进渲染为同版本的后续扩展，本文不伪称已实现这些方法。

- frame = ASCII `Content-Length: <decimal UTF-8 body byte count>\r\n\r\n` + JSON body。长度 1..1048576；header 总长不超过 8192 bytes。只接受该精确 header grammar；多余 header、重复长度、负号、空长度、不完整数字全部拒绝。长度允许前导零。
- header/framing/UTF-8 错误或不完整 EOF：stderr 诊断，退出码 2，关闭连接，不尝试猜测下一个 frame。UTF-8 解码失败归类为稳定 `E_UTF8`，不要求client理解SDK异常文案。有效 frame 的 JSON/schema/版本错误：结构化 response 后继续接收。
- JSON 使用现有 SeaJson 1.5.0，原生纯 std 路径，无 rpcx、无新增 stdx。JSON 对象重复字段递归拒绝；未知字段忽略，供同版本兼容扩展。未知方法返回 `E_METHOD`。
- stdout 只发完整 frame，单同步写 owner，实际 partial-write loop；stderr 仅诊断。Windows stdin/stdout 设 CRT binary mode，避免 CRLF/Ctrl-Z 改写；不使用按行的 `getStdIn()`。
- body 必须 UTF-8；仅在完整 body 收齐后验证和解码。不会按 read chunk 解码中文或 emoji。

每个 request 是对象，必需 `protocolVersion:1, requestId:string(nonempty), workerEpoch:string, method:string`；文档方法额外需要 `uri:string(nonempty)`。`initialize` 允许 `workerEpoch:""` 引导握手；它返回实际 epoch，其余方法必须原样带回。探针 epoch 为 `probe-epoch-1`，每个进程只在测试约定下使用该值；Task15 必须换成每次真实进程启动唯一 epoch。requestId 为请求的字符串身份，flush 未完成时不得重用。

每个 response：`protocolVersion:1,type:"response",workerEpoch,requestId,uri,code`。存在文档时额外附 `sourceVersion,parseVersion,renderVersion`。source/parse/render 均指各阶段已接受/已提交的 **文档版本**；后续多事务渐进输出单独增加 `renderRevision` 及 base/target 链，不能把 revision 与 document version 混同。`-1` 表示该阶段没有提交结果。可选 `result` 是 JSON 对象。

| method | 增量字段 | 当前语义 |
|---|---|---|
| initialize | 无 | 返回 header/body 限额及真实 backend/productSessionReady |
| document/open | text:string, version:int64>=0 | 仅 open/resync 允许全文；同 URI 重开拒绝 |
| document/change | baseVersion:int64, newVersion=base+1, edits:[{startUtf16,endUtf16,text}] | 1..256 个升序不重叠半开区间，均为旧版本 UTF-16 offset；真实 rope 原子校验并 ack，split surrogate 拒绝；失配返回 E_VERSION_RESYNC |
| document/flush | version:int64 | version 必须为当前 source；QUEUED 记录 sourceVersion，最多16 pending |
| cancel | targetRequestId:string | 移除该 URI 尚未提交的 flush，CANCELLED；保留已 ack source，缺目标 E_NOT_PENDING |
| probe/drain | targetRequestId:string | **仅独立 driver 调度入口**，执行一次排队 flush；响应 requestId 为原 flush ID；source 已前进则 E_SUPERSEDED，不能 commit 旧结果 |
| document/close | 无 | 移除本 URI pending 和后端引用 |
| shutdown | 无 | OK 后停止接收 |

`probe/drain` 是可控调度测试钩子，不是生产 worker 命令承诺。Task15 用事件循环替代它，保留 flush 的取消、过期检查和响应身份。当前没有线程并发或 native 服务，不声称已验证生产计算过程中的取消抢占、断管后的资源回收、背压队列内存或多事务原子渲染。

稳定错误码：`E_EPOCH`、`E_ALREADY_OPEN`、`E_VERSION_RESYNC`、`E_DUPLICATE_REQUEST`、`E_BACKPRESSURE`、`E_NOT_PENDING`、`E_SUPERSEDED`、`E_METHOD`、`E_PROVIDER_PENDING`。请求校验错误外层 `E_REQUEST:<diagnostic>`，diagnostic 为人读信息，client 不依赖其字串。framing fatal 码见源码和黑盒脚本。

## 真实 session 接口交接

04 已确认使用现有 `DocumentEditingSession`，不另造生产 worker API：

```text
Markit(useStandard:false).use(profile 的真实 plugins...)
  .createEditingSession(uri,text,codec,policy:EditingPolicy.Strict)
session.applyEdits(expectedVersion,Array<EditingTextEdit>) -> EditableSourceVersion
session.flush() -> EditingFlushResult
session.cancelComputation() -> Unit
session.versions.sourceVersion / parseVersion
session.snapshot() -> EditingDocumentSnapshot
snapshot.tree / effects / patches; snapshot.release()
session.close()
```

协议直接传 `EditingTextEdit(EditingRange(startUtf16,endUtf16,coordinate:EditingCoordinate.Utf16),text)`；由公共 source 层校验和转换。真实 profile 的构造签名和 codec 由04冻结后，本目录 owner 增加真实 adapter，不能用 SourceOnlyBackend 或测试桩替代。typed renderer 完成有效原子输出之前不得提高 renderVersion。adapter 必须在 close 时释放实际 session、snapshot 和资源。

## 最小可复现验证

共享产品构建和官方测试仍由02唯一协调；根已单独授权本目录owner仅编译/实跑私有probe。独立 exe 位于本目录，禁止抢共享 target。输入候选依赖已冻结于 `task01-performance/candidate-task06-product/frozen-libs/{markit,seajson}`；它只覆盖 transport/source 探针，不代表后来07生产代码。

编译：同 SDK `C:/Program Files (x86)/Cangjie/bin/cjc.exe`，显式两源文件，`-O2 --static-std -Woff unused`，对两个 frozen 库目录增加 `--import-path/-L`，链接 `markit.core.source`、`markit.core.editing`、`seajson`，输出 `task07-protocol/probe.exe`。真实命令及失败诊断已由获根单独授权的本目录owner落盘，最终compile-5通过；见verification.md。

运行：使用实际存在的 `C:/Users/Shawn/AppData/Local/Programs/Python/Python311/python.exe` 执行 `tasklists/incremental-parsing/task07-protocol/verify_stdio.py tasklists/incremental-parsing/task07-protocol/probe.exe --output tasklists/incremental-parsing/task07-protocol/transport-results-5.json`。PATH的WindowsApps python只是不可执行占位入口，不能用它的启动失败当作测试执行。

脚本实际创建常驻子进程并写 binary stdin，逐字节拆 header/body（包含中文/emoji内部 UTF-8 字节）、粘合多个 frames，验证 UTF-16 surrogate 拒绝、change/flush/cancel 保留 sourceVersion、provider 缺失时不伪造 parse/renderVersion、stale change、superseded flush、坏 JSON 后恢复、非法/重复/超限 header、坏 UTF-8 和截断 EOF。通过只证明该独立 transport/source 子集；不跑 benchmark，不替代真实产品纵切验收。

## 未关闭项

- binary-pipe实际验证只证明上述transport/source子集；SDK实际为1.3.0-alpha，不增补最低SDK兼容工作。
- session_backend.cj 的真实DocumentEditingSession适配已单独编译成功，尚未实跑。等04释放 StandardEditingPilot.createSession(uri,text) 与 StandardEditingPilot.render(snapshot):String（当前仅拟议、未SOURCE_READY），接入同一driver验证真实session结果版本、取消后最新flush、typed rendering；未完成前Task07纵切gate保持未通过。真实factory暂只接受open version0，否则明确E_OPEN_VERSION。
- Task15接管生产事件循环/唯一epoch、事务patch、渐进首屏、workspace隔离及完整资源生命周期；不得将本原型的source-only能力当作完成。

