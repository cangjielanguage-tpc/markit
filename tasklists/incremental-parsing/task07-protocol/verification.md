# 07-P 协议独立验证记录

更新：2026-10-23。按已读取的 ACEHarness tasklist 规则记录实际范围和证据；不修改 README 进度。

结论：**独立 transport/source 子集通过；真实产品纵切未执行。** 私有 `probe.exe` 编译成功，16项实际 binary-pipe 检查全部通过；`SessionProbeBackend` 对真实生产类的适配边界另行静态库编译成功，尚未接真实 Standard profile/typed renderer 实跑。

## 实际检查

- `compile-5-args.json`：`C:/Program Files (x86)/Cangjie/bin/cjc.exe` 编译 `protocol.cj`、`stdio_probe.cj`，`-O2 --static-std -Woff unused`，使用冻结06依赖；`compile-5-exit.log=0`。SDK：`1.3.0-alpha.20260920003052`，`x86_64-w64-mingw32`。保留 std.posix read/write 的两条 deprecated warning，未改SDK声明或新增依赖。
- `verify-5-command.json`：实际 Python 路径 `C:/Users/Shawn/AppData/Local/Programs/Python/Python311/python.exe`；运行 `verify_stdio.py probe.exe --output transport-results-5.json`，`verify-5-exit.log=0`，16项通过。最终 exe SHA256：`35AD8E4093303C1F977C6681C11CF7FBF72105ABB357268DA1B5E56340197F7E`。
- `adapter-compile-1-args.json`：同SDK `-O2 --static-std` 将 `protocol.cj + session_backend.cj` 编译为私有静态库；`adapter-compile-1-exit.log=0`。这证明真实 `DocumentEditingSession`、`EditingDocumentSnapshot`、`flush/applyEdits/cancelComputation/commitRender/release/close` API 的编译接入，不证明provider或renderer运行。
- 当前源码、直接使用的冻结 `.cjo/.a`、exe和adapter静态库hash见 `verified-inputs.json`。SeaJson实际依赖声明由 `markit/cjpm.lock` 的 `[requires] seajson version=1.5.0, output-type=static` 核对；输入库来自只读冻结06目录，不从正在修改的07产品源码临时构建。该版cache源码 `seajson-1.5.0/cjpm.toml` 无依赖，未新增 rpcx/stdx。

16项独立进程验证覆盖：逐字节拆 header/body；空epoch initialize握手及旧epoch拒绝；中文/emoji UTF-8 byte长度与UTF-16 surrogate切点拒绝；frame粘包、flush/cancel/source ack版本；provider缺失时parse/render仍为-1；stale change和superseded flush；JSON重复字段与未知方法；坏JSON恢复且stdout无日志；重复/负Content-Length；body/header限额；header/body截断EOF；坏UTF-8 fatal；干净EOF。

invalid UTF-8仍强制 **exit=2、stdout为空、stderr含稳定E_UTF8**。源码将SDK解码异常归类为 `E_UTF8`，不把SDK诊断文本作为wire契约。frame只有一个同步writer，并循环处理实际write返回的部分写长度；普通pipe测试不声称人为注入过内核partial-write。

## 保留的失败证据

- `compile-1.log`：builder callback尾部Unit与SeaJson期望JsonWriter不匹配；修正为显式返回writer。
- `verify-1.log`：PATH解析到不可启动的WindowsApps python占位文件，**没有启动Python或probe测试进程**。PowerShell旧LASTEXITCODE不是此次进程exit，`verify-1-exit.log`已明确记`NOT_STARTED`。随后通过存在的Python311路径执行；不存在待核对的未知probe结果。
- `transport-results-2.json / verify-2.log`：实际坏UTF-8已正确退出2/stdout空，脚本曾误匹配不带连字符的`utf8`，与SDK`Invalid UTF-8...`文案不符。该失败未删除；后续保留同一错误检查，再将源码归类稳定`E_UTF8`并实跑。
- `compile-4.log`：一次主构造简化误用class参数位置，实际SDK拒绝；已按仓颉真实写法将成员参数放在类体内同名构造器，接口不变，`compile-5`通过。SourceOnlyBackend的派生rope字段保留显式初始化。
- `transport-results-3.json`和`transport-results-4.json`保存中间通过结果；对应当前源码的最终结果为 **transport-results-5.json**，不能用旧exe的hash替代。

## 真实接入边界和未关闭项

`SessionProbeBackend(session, renderClosure)`已落真代码并通过静态库编译。change/cancel直接调用真实session；flush调用真实session.flush，持有snapshot，typed-render closure成功且generation/source/parse仍匹配目标后才commitRender，finally释放snapshot。协议close/EOF/shutdown亦释放后端。它不建立Markdown语法或renderer框架。

04回复的待释放入口是拟议 **`StandardEditingPilot.createSession(uri,text)` 和 `StandardEditingPilot.render(snapshot):String`**。04明确工厂尚未SOURCE_READY，当前不得import猜测符号。真实adapter的open非0版本先显式拒绝 `E_OPEN_VERSION`；不会为此改生产createEditingSession API。后续在本目录组装factory/render closure和真实验证，生产profile文件唯一owner仍为04。

尚未执行：真实Paragraph/嵌套块/Heading/ReferenceLink/typed-renderer session的pipe纵切、真实计算中途取消及正确oracle、生产patch事务/渐进首屏/完整资源生命周期、Task15正式worker。当前initialize仍诚实返回`backend=source-only,productSessionReady=false`。不得把本记录当作07-P全部或Task07/Task15完成。

本次未触共享cjpm/target，未运行benchmark或计时，未提交/推送；所有新增文件、日志、exe和静态库均在本专属目录。
