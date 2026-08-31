<a id="supporting-libraries"></a>
# 支撑库

Markit 项目中的支撑库可以独立使用，也可以组合进文档生成流程。

JSON 解析和输出相关能力依赖第三方库 [`seajson`](https://pkg.cangjie-lang.cn/package/seajson)。

这些库已发布到仓颉中心仓。按需在 `cjpm.toml` 中引入：

```toml
[dependencies]
commandline = { version = "0.2.0" }
fswatch = { version = "0.2.0" }
live_server = { version = "0.2.0" }
```

## commandline

`commandline` 是宏驱动的仓颉 CLI 框架，用少量注解定义命令、选项、帮助文本和终端交互。

```cangjie
import commandline.macros.{CLIApp, Cmd, Opt, Plain}
import commandline.terminal.progressLogger

@CLIApp[name: "myapp", version: "1.0.0", description: "My CLI tool"]
class MyApp {}

@Cmd[command: ["hello"], description: "Say hello"]
class HelloCommand {
    @Opt[["--name", "-n"], help: "Your name", required: true]
    public var name: ?String = None

    public func execute(): Int {
        @Plain("Hello, ${name.getOrThrow()}!")
        return 0
    }
}

main(args: Array<String>): Int {
    return MyApp(args).use(HelloCommand()).execute()
}
```

它提供：

- `@CLIApp`、`@Cmd`、`@Opt` 命令定义宏。
- `@Success`、`@Warn`、`@Err`、`@Info`、`@Plain` 等输出宏。
- spinner、progress、颜色、confirm、prompt、select、multi-select 等终端能力。
- 自动帮助文本、未知命令提示和必填参数校验。

## fswatch

`fswatch` 是跨平台文件监听库，适合本地预览、自动重建和开发工具。

```cangjie
import fswatch.{FileMonitor, EventType}
import std.fs.Path

let monitor = FileMonitor()

monitor.addEventHandler { event =>
    match (event.eventType) {
        case EventType.Created => println("created: ${event.path}")
        case EventType.Modified => println("modified: ${event.path}")
        case EventType.Deleted => println("deleted: ${event.path}")
        case _ => {}
    }
}

monitor.watch(Path("./docs"), recursive: true)
monitor.start()
```

后端选择：

| 平台 | 后端 |
| --- | --- |
| Linux | `inotify` |
| macOS | `FSEvents` |
| Windows | `PollingBackend` |
| 其他平台 | `PollingBackend` |

`BackendType.Auto` 会优先尝试 native 后端，不可用时回退到 polling。

## live-server

`live-server` 提供本地静态服务能力，适合 `markit-cli serve` 这类预览场景。它通常作为上层工具的内部依赖使用，用户直接使用 `markit serve` 即可获得本地 HTTP 预览和 watch 体验。

## dochir

`dochir` 是仓颉 API 文档生成辅助工具，用于从包、类型和成员信息生成面向库用户的 Markdown 文档。它适合和 `markit-cli` 组合：先生成 API Markdown，再由 Markit 文档站统一渲染为网站或 PDF。
