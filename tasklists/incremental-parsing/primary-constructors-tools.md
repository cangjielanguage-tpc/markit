# 工具模块主构造函数写法整理

范围：markit-cli、commandline、dochir/src、fswatch、live-server 的自有仓颉源。盘点 src 下 91 个 .cj；测试/示例未发现需要本批修改的普通构造，不改其行为。排除 target、dist、libs、build-script-cache、temp、原生资产与生成声明镜像；dochir/example 不在本批 src 范围。

本批只改构造写法，不改业务逻辑、资源操作、参数解析或插件增量算法。02 确认这些工具不在 markit 的依赖清单内后落盘；当前 markit 整编期间未运行其他 build/test，也未写任何共享 target。

## 已冻结修改

23 文件、46 类型：23 类型将同序直接赋值合并为成员形参，23 类型保留完整初始化体并改为同名主构造函数。保持访问权限、let/var、参数顺序、命名标记、默认值和剩余 init 重载；FileEvent 保留逐字段文档原位，因此不搬字段。写前全文件 preflight，写后逐文件读回一致。

| 文件 | 类型与处理 |
| --- | --- |
| `markit-cli/src/kit_hooks.cj` | `CommandlineKitHookSink`：保留原初始化体 |
| `commandline/src/terminal/interactive_form.cj` | `InteractiveForm`：成员形参 |
| `commandline/src/terminal/interactive_models.cj` | `SelectMenuState`：保留原初始化体；`MultiSelectMenuState`：保留原初始化体 |
| `commandline/src/terminal/terminal.cj` | `ProgressLogger`：保留原初始化体 |
| `commandline/src/terminal/unix_terminal_backend.cj` | `NativeTerminalBackend`：成员形参 |
| `commandline/src/terminal/windows_terminal_backend.cj` | `NativeTerminalBackend`：成员形参 |
| `dochir/src/docgen/emit_model_markdown.cj` | `SourceTarget`：成员形参；`SourceLinkConfig`：成员形参；`DocTemplate`：保留原初始化体 |
| `dochir/src/docgen/source_comments.cj` | `SourceLocation`：成员形参；`SourceDoc`：成员形参；`DocParseState`：保留原初始化体 |
| `dochir/src/dochir.cj` | `DocChirConfig`：保留原初始化体 |
| `dochir/src/model/doc_codec.cj` | `FunctionBuild`：保留原初始化体；`EnumCtorBuild`：保留原初始化体；`TypeBuild`：保留原初始化体 |
| `dochir/src/model/doc_model.cj` | `DocParam`：成员形参；`DocTag`：成员形参；`DocValue`：成员形参；`DocFunction`：成员形参；`DocEnumConstructor`：成员形参；`DocType`：成员形参；`DocPackage`：成员形参；`DocProject`：成员形参 |
| `dochir/src/model/doc_store.cj` | `DocPluginConfig`：成员形参 |
| `fswatch/src/backends/linux_inotify_backend.cj` | `WatchScope`：保留原初始化体；`LinuxInotifyBackend`：成员形参 |
| `fswatch/src/backends/macos_fsevents_backend.cj` | `WatchScope`：保留原初始化体；`MacOSFSEventsBackend`：成员形参 |
| `fswatch/src/backends/polling_backend.cj` | `FileState`：保留原初始化体；`PollingBackend`：保留原初始化体 |
| `fswatch/src/core/file_monitor.cj` | `PerformanceStats`：保留原初始化体；`FileMonitor`：保留原初始化体 |
| `fswatch/src/core/monitor_config.cj` | `MonitorConfig`：保留原初始化体 |
| `fswatch/src/errors/monitor_exception.cj` | `MonitorException`：保留原初始化体 |
| `fswatch/src/events/event_handler.cj` | `EventHandlerWrapper`：保留原初始化体 |
| `fswatch/src/events/file_event.cj` | `FileEvent`：保留原初始化体 |
| `fswatch/src/filters/event_filter.cj` | `CompositeEventFilter`：成员形参；`PathEventFilter`：保留原初始化体；`EventTypeFilter`：成员形参；`TimeRangeFilter`：成员形参 |
| `fswatch/src/filters/path_pattern.cj` | `PathPattern`：保留原初始化体 |
| `live-server/src/live_server.cj` | `HttpRequest`：成员形参；`WatchRegistration`：成员形参；`LiveServer`：保留原初始化体 |

## 保留理由

- 已有主构造函数保持：NotImplementedException、AnnotationParameter、AppConfig、CmdMeta、CommandMetadata、OptionFieldInfo、OptionMetadata、FileSizeFilter。已有普通 init 重载保留，避免产生第二主构造函数。
- commandline/src/macros/cli_app.cj 的 createCLIConstructor 和 macros/cmd.cj 的 createParameterParsingConstructor 仍生成 init。它们使用 FuncDecl 作为供宿主类追加的普通构造声明，可与用户已有主构造共存；改为 PrimaryCtorDecl 会改变宏的宿主契约与 AST 插入类型。本批不机械替换，也不把这些自有模板误称为第三方。
- WatchScope、FileState、FileMonitor、ProgressLogger、LiveServer 等保留路径规范化、文件信息查询、资源创建/克隆、验证及异常路径的原执行顺序；MonitorException、EventHandlerWrapper、FileEvent 的剩余重载保持原样。只改同名构造语法，不移动这些执行体。
- native 平台资产、生成输出和 declaration 镜像不属于构造写法修改对象；跨平台源码会正常参与所属平台条件编译，不能把本机 Windows 结果声称为 Linux/macOS 运行通过。

## 验证

Task05 审核 Done、full/O2 全部结束且 02 确认锁释放后，使用各项目正常 build/test 的隔离 `--target-dir` 执行；未新增测试设施或风格关卡。

- commandline：在其目录执行 `cjpm test --no-run --target-dir C:\Users\Shawn\markit\tmp\primary-tools-target\commandline`，exit 0；随后顺序执行该输出目录中的三个官方 binary，各传 `--no-color`。interfaces 1、macros 36、terminal 33，共 **70 passed / 0 skipped / 0 error / 0 failed**，三个进程 exit 0。命令、binary SHA256、各日志位置见 `primary-constructors-verification/commandline-test-results-1.json`，编译日志为同目录 `commandline-test-compile-1.log`。
- fswatch：在其目录执行 `cjpm test --no-run --target-dir C:\Users\Shawn\markit\tmp\primary-tools-target\fswatch`，exit 0；随后四个官方 binary 逐个传 `--no-color`，integration 6、backends 17、core 18、events 14，共 **55 passed / 0 skipped / 0 error / 0 failed**，四个进程 exit 0。命令、binary SHA256、各日志位置见 `primary-constructors-verification/fswatch-test-results-1.json`，编译日志为同目录 `fswatch-test-compile-1.log`。
- live-server：在其目录执行 `cjpm build --target-dir C:\Users\Shawn\markit\tmp\primary-tools-target\live-server`，exit 0，日志 `primary-constructors-verification/live-server-build-1.log`。该项目没有现有测试 case；未启动网络服务器，不能将构建通过描述为服务端运行验证。
- 尚未执行：dochir 与 markit-cli 的正常 build/test。两个真实 manifest 均依赖 markit 与 markit-kit，Task06 产品正在修改这些源；按 root/02 调度等待稳定源窗口，状态为 pending，未被安全拒绝，也没有失败命令需要重试。已完成三个独立项目的进程均已结束。

上述 fswatch 结果是本机 Windows 的实际测试，不宣称 Linux inotify 或 macOS FSEvents 原生后端已运行通过。此轮未遇到 TCP runner 10013，也未修改安全设置或替换测试 runner；运行的是当前 SDK 生成的官方 package binary。

## 有限残余盘点与旧测试 helper 收尾

当前 codehl、markit-kit、工具和插件分区的残余 init 粗读仅剩已存在同名 primary 的合法 secondary，另有上文两处自有宏模板。未覆盖候选集中在 markit 的 source/nodes/inline/session 产品与 Task02/03/04/05 新定向测试，继续归原 owner；本项不越权改写。tasklists 中的历史、已推迟 oracle 与 timing 证据源不作为当前生产漏改数。粗分足以调度，不追求 AST 精确总数。

root 另确认本 owner 可转换两个旧 helper 文件：`markit/src/tests/unit/registry_dispatch_tests.cj` 的 TestLeafParser、TestContinuationParser、TestInlineParser，以及 `markit/src/tests/unit/streaming/streaming_feed_tests.cj` 的 ChunkedInputStream。只合并 private let 同序直赋，stream 的 var 游标及初值保留。Task05 审核 Done、绑定冻结解除后，02 确认无 Task06 compiler 的短窗已实际落盘并重新 SOURCE_READY 冻结；由 Task06 正常重编覆盖，**未被此前 whole3 验证**，不增加 Task05 验收等待。

`tests/utils/editing_legacy_fixture.cj` 与 `tests/unit/editing_legacy_baseline_test.cj` 保持原字节：它们是固定的“第三方零源码修改仍兼容”验证夹具，改变其写法会破坏该证据目的，不能按普通可改产品源码处理。其余新增定向、generators/utils/benchmark、当前热测试均排除。

短窗落盘后只读核实其 SHA256 仍分别为 `31837f5064696fa3477d8631b4799f102594f989b32c107259880deafbba9642` 和 `ef6123912759b2d9d08a9ad4a53432134c208b9b1b20f144556c35c02fbf9104`。
