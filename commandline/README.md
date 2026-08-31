# commandline

> 宏驱动的 Cangjie CLI 框架。命令定义、帮助生成、终端输出都优先通过宏完成。

## 快速开始

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

## 终端宏

### 必要导入

终端宏展开后会直接使用运行时符号，因此需要把这些符号导入到当前作用域：

```cangjie
import commandline.macros.*
import commandline.terminal.{progressLogger, interactiveForm, ProgressLogger, ColorUtil, AnsiColor, SelectResult, MultiSelectResult}
```

- `@Success / @Warn / @Err / @Info / @Verbose / @Plain / @NewLine / @Write / @Spinner / @UpdateSpinner / @StopSpinner / @InsertBefore / @Progress / @StopProgress / @Prompt / @Confirm / @Select / @MultiSelect / @SelectValue / @MultiSelectValues / @RequireConfirm` 依赖 `progressLogger`
- `@ProgressBar` 依赖 `ProgressLogger`
- `@Color / @Background / @Styled` 依赖 `ColorUtil`
- 涉及颜色枚举时需要 `AnsiColor`

### 宏总览

| 宏 | 返回值 | 作用 | 示例 | 对应 example |
|---|---|---|---|---|
| `@Spinner("msg")` | `Unit` | 启动 spinner | `@Spinner("Building...")` | `examples/spinner-demo` |
| `@UpdateSpinner("msg")` | `Unit` | 更新 spinner 文案 | `@UpdateSpinner("Building... 2/5")` | `examples/spinner-demo` |
| `@StopSpinner(@Success(...))` | `Unit` | 停止 spinner，并立刻输出最终结果 | `@StopSpinner(@Success("Build complete"))` | `examples/spinner-demo` |
| `@StopSpinner()` | `Unit` | 仅停止 spinner | `@StopSpinner()` | `examples/spinner-demo` |
| `@InsertBefore(@Warn(...))` | `Unit` | 临时清掉 spinner，插入一条消息，再恢复 spinner | `@InsertBefore(@Warn("cache miss"))` | `examples/spinner-demo` |
| `@Progress("msg")` | `Unit` | 更新纯文本进度行 | `@Progress("File changed, rebuilding...")` | `examples/progress-demo` |
| `@Progress(67)` | `Unit` | 输出单百分比进度条 | `@Progress(67)` | `examples/progress-demo` |
| `@Progress("Rendering", 67)` | `Unit` | 输出带文案的单百分比进度条 | `@Progress("Rendering", 67)` | `examples/progress-demo` |
| `@Progress(25, 75)` | `Unit` | 输出三段式双百分比进度条 | `@Progress(25, 75)` | `examples/progress-demo` |
| `@Progress("Pipeline", 25, 75)` | `Unit` | 输出带文案的三段式进度条 | `@Progress("Pipeline", 25, 75)` | `examples/progress-demo` |
| `@StopProgress(@Success(...))` | `Unit` | 停止 progress，并立刻输出最终结果 | `@StopProgress(@Success("Render done"))` | `examples/progress-demo` |
| `@StopProgress()` | `Unit` | 仅停止 progress | `@StopProgress()` | `examples/progress-demo` |
| `@ProgressBar(...)` | `String` | 生成百分比进度条字符串 | `@ProgressBar(67)` | `examples/progress-demo` |
| `@Success("msg")` | `Unit` | 成功消息 | `@Success("Done")` | `examples/output-demo` |
| `@Warn("msg")` | `Unit` | 警告消息 | `@Warn("Using fallback")` | `examples/output-demo` |
| `@Err("msg")` | `Unit` | 错误消息 | `@Err("Build failed")` | `examples/output-demo` |
| `@Info("msg")` | `Unit` | 信息消息 | `@Info("Server: http://127.0.0.1:8080")` | `examples/output-demo` |
| `@Verbose("msg")` | `Unit` | 低优先级日志 | `@Verbose("Copied 12 assets")` | `examples/output-demo` |
| `@Plain("msg")` | `Unit` | 普通整行输出 | `@Plain(cli.getHelp())` | `examples/output-demo` |
| `@NewLine()` | `Unit` | 输出空行 | `@NewLine()` | `examples/output-demo` |
| `@Write(text)` | `Unit` | 原样写出，不自动补换行 | `@Write(output)` | `examples/output-demo` |
| `@Prompt(...)` | `String` | 读取单行输入 | `let name = @Prompt("Project name")` | `examples/interactive-demo` |
| `@Confirm(...)` | `Bool` | 读取确认输入 | `let ok = @Confirm("Continue?", defaultValue: Some(true))` | `examples/interactive-demo` |
| `@Select(...)` | `SelectResult` | 单选，返回选中结果或取消 | `let theme = @Select("Theme", ["light", "dark"])` | `examples/interactive-demo` |
| `@MultiSelect(...)` | `MultiSelectResult` | 多选，返回选中结果或取消 | `let values = @MultiSelect("Features", ["spinner", "prompt"])` | `examples/interactive-demo` |
| `@SelectValue(...)` | `?String` | 单选并直接返回值 | `let theme = @SelectValue("Theme", ["light", "dark"])` | `examples/interactive-demo` |
| `@MultiSelectValues(...)` | `?Array<String>` | 多选并直接返回值数组 | `let values = @MultiSelectValues("Features", ["spinner", "prompt"])` | `examples/interactive-demo` |
| `@RequireConfirm(...)` | `Unit` | 确认失败时直接抛异常 | `@RequireConfirm("Continue?", abortMessage: "stopped")` | `examples/interactive-demo` |
| `@Color(text, color)` | `String` | 前景色样式值 | `let t = @Color("hot", AnsiColor.Red)` | `examples/color-demo` |
| `@Background(text, color)` | `String` | 背景色样式值 | `let t = @Background("tag", AnsiColor.BgBlue)` | `examples/color-demo` |
| `@Styled(...)` | `String` | 前景色、背景色、样式组合 | `@Styled("banner", foreground: AnsiColor.White, background: AnsiColor.BgBlue)` | `examples/color-demo` |

### 语义约束

- `@Success / @Warn / @Err / @Info / @Verbose / @Plain / @NewLine` 不会自动停止 spinner。
- 当 spinner 或其他 transient line 仍然激活时，以上宏会抛错，避免输出把动态行冲掉。
- 需要“先插一条消息，再继续 spinner”时，用 `@InsertBefore(...)`。
- 推荐把结束动作写成 `@StopSpinner(@Success("..."))`，语义最清晰。
- `@Prompt / @Confirm / @Select / @MultiSelect` 也要求终端处于空闲状态，不能在 spinner 还活着时直接进入交互。
- `@Select` 返回 `SelectResult`；选中时是 `Selected(index)`，取消时是 `Cancelled`。
- `@MultiSelect` 返回 `MultiSelectResult`；选中时是 `Selected(indices)`，取消时是 `Cancelled`。
- `@SelectValue` 把 `Selected(index)` 自动映射成 `Some(options[index])`，取消时返回 `None`。
- `@MultiSelectValues` 把 `Selected(indices)` 自动映射成 `Some(Array<String>)`，取消时返回 `None`。
- `@RequireConfirm` 基于 `@Confirm`，结果为 `false` 时按 `abortMessage` 抛异常。
- `@Select / @MultiSelect / @Confirm` 在 Unix/macOS 真实 TTY 下使用方向键交互；在 Windows、非 TTY 或测试注入行输入场景下自动回退为行输入。

### 交互宏

| 宏 | 典型参数 | 行为 | 空输入行为 |
|---|---|---|---|
| `@Prompt(message, defaultValue: Some("x"), allowEmpty: false)` | 文案、默认值、是否允许空串 | 读取一行文本 | 有默认值时回退默认值；`allowEmpty: true` 时返回 `""`；否则重试 |
| `@Confirm(message, defaultValue: Some(true))` | 文案、默认值 | Unix/macOS TTY 下支持 `↑ / ↓ + Enter` 或直接按 `y/n`；其他环境接受 `y/yes/n/no/true/false/1/0` | 有默认值时回退默认值；否则重试 |
| `@Select(message, ["a", "b"], defaultIndex: Some(0))` | 标题、候选项、默认项 | Unix/macOS TTY 下用 `↑ / ↓ + Enter` 选择；Windows/非 TTY/测试行输入时回退为单行输入 | 有默认值时回退默认项；否则重试 |
| `@MultiSelect(message, ["a", "b"], defaultIndices: [0, 2])` | 标题、候选项、默认项数组 | Unix/macOS TTY 下用 `↑ / ↓` 移动、`Space` 勾选、`Enter` 提交；Windows/非 TTY/测试行输入时回退为单行输入 | 有默认值时回退默认项数组；否则重试 |
| `@SelectValue(...)` | 标题、候选项、默认项 | 在 `@Select` 基础上直接返回值 | 取消时返回 `None` |
| `@MultiSelectValues(...)` | 标题、候选项、默认项数组 | 在 `@MultiSelect` 基础上直接返回值数组 | 取消时返回 `None` |
| `@RequireConfirm(...)` | 文案、默认值、中止文案 | 在 `@Confirm` 基础上做强约束确认 | 结果为 `false` 时抛异常 |

交互宏的设计目标是“宏能直接覆盖使用场景”，所以它们都可以直接出现在表达式位置：

```cangjie
import commandline.macros.{Confirm, MultiSelect, Plain, Prompt, Select}
import commandline.terminal.progressLogger

main(): Int {
    let projectName = @Prompt("Project name", defaultValue: Some("markit-demo"))
    let themeIndex = @Select("Theme", ["light", "dark", "system"], defaultIndex: Some(2))
    let featureIndexes = @MultiSelect("Features", ["spinner", "color", "prompt"], defaultIndices: [0, 1])
    let confirmed = @Confirm("Create project?", defaultValue: Some(true))

    @Plain("project=${projectName}")
    match (themeIndex) {
        case SelectResult.Selected(index) => @Plain("theme=${index}")
        case SelectResult.Cancelled => @Plain("theme=cancelled")
    }
    match (featureIndexes) {
        case MultiSelectResult.Selected(indices) => @Plain("features=${indices}")
        case MultiSelectResult.Cancelled => @Plain("features=cancelled")
    }
    @Plain("confirmed=${confirmed}")
    return 0
}
```

真实终端下的快捷键：

- `Prompt`: 支持退格编辑，`secret: true` 时只显示遮罩
- `Confirm`: `↑ / ↓` 切换，`Enter` 提交，也可以直接按 `y / n`
- `Select`: `↑ / ↓` 选择，`Enter` 提交，`Esc` 取消
- `MultiSelect`: `↑ / ↓` 移动，`Space` 勾选，`Enter` 提交
- `MultiSelect` 额外支持 `a` 全选、`c` 清空
- Windows 当前默认使用文本回退模式，不进入 raw key mode

## 示例

### 长任务 + 最终状态

```cangjie
import commandline.macros.{Spinner, UpdateSpinner, StopSpinner, Success}
import commandline.terminal.progressLogger

main(): Int {
    @Spinner("Packaging...")
    sleep(Duration.second)
    @UpdateSpinner("Packaging... 3/5")
    sleep(Duration.second)
    @StopSpinner(@Success("Package completed"))
    return 0
}
```

### 长任务中插入警告

```cangjie
import commandline.macros.{InsertBefore, Spinner, StopSpinner, Success, Warn}
import commandline.terminal.progressLogger

main(): Int {
    @Spinner("Uploading...")
    @InsertBefore(@Warn("Network jitter detected"))
    @StopSpinner(@Success("Upload completed"))
    return 0
}
```

### 交互式命令

```cangjie
import commandline.macros.{Confirm, MultiSelect, Prompt, Select, Success}
import commandline.terminal.{MultiSelectResult, SelectResult, progressLogger}

main(): Int {
    let name = @Prompt("Package name", defaultValue: Some("demo-cli"))
    let template = @Select("Template", ["basic", "docs", "website"], defaultIndex: Some(0))
    let features = @MultiSelect("Features", ["spinner", "color", "interactive"], defaultIndices: [0, 1])

    if (@Confirm("Generate project?", defaultValue: Some(true))) {
        match (template) {
            case SelectResult.Selected(templateIndex) =>
                match (features) {
                    case MultiSelectResult.Selected(featureIndexes) =>
                        @Success("Generated ${name}, template=${templateIndex}, features=${featureIndexes}")
                    case MultiSelectResult.Cancelled =>
                        @Success("Generated ${name}, template=${templateIndex}, features=cancelled")
                }
            case SelectResult.Cancelled => @Success("Generated ${name}, template=cancelled")
        }
    }
    return 0
}
```

### 值级交互宏

```cangjie
import commandline.macros.{MultiSelectValues, RequireConfirm, SelectValue, Success}
import commandline.terminal.progressLogger

main(): Int {
    let template = @SelectValue("Template", ["basic", "docs", "website"], defaultIndex: Some(0))
    let features = @MultiSelectValues("Features", ["spinner", "progress", "interactive"], defaultIndices: [0, 1])
    @RequireConfirm("Generate project?", defaultValue: Some(true), abortMessage: "generation aborted")
    @Success("template=${template}, features=${features}")
    return 0
}
```

### 彩色文本

```cangjie
import commandline.macros.{Color, Plain, Styled}
import commandline.terminal.{progressLogger, ColorUtil, AnsiColor}

main(): Int {
    @Plain(@Color("highlight", AnsiColor.Cyan))
    @Plain(@Styled("banner", foreground: AnsiColor.White, background: AnsiColor.BgBlue))
    return 0
}
```

## Example 项目

`commandline/examples/` 下提供了几个独立的 executable 示例包，每个都通过本地路径依赖引用 `commandline`，可以直接 `cjpm run`：

| 示例 | 作用 | 运行方式 |
|---|---|---|
| `examples/output-demo` | 基础输出宏 | `cd commandline/examples/output-demo && cjpm run` |
| `examples/progress-demo` | `@Progress` 与进度条生成 | `cd commandline/examples/progress-demo && cjpm run` |
| `examples/spinner-demo` | spinner / stop / insert-before | `cd commandline/examples/spinner-demo && cjpm run` |
| `examples/color-demo` | 前景色 / 背景色 / 组合样式 | `cd commandline/examples/color-demo && cjpm run` |
| `examples/interactive-demo` | `@Prompt / @Confirm / @Select / @MultiSelect` | `cd commandline/examples/interactive-demo && cjpm run` |
| `examples/showcase-demo` | 交互式总入口，按分类查看所有 example | `cd commandline/examples/showcase-demo && cjpm run` |
| `examples/cli-app-demo` | `@CLIApp / @Cmd / @Opt` 基础用法 | `cd commandline/examples/cli-app-demo && cjpm run -- hello --name world` |

这些 example 主要用于两件事：

- 当作文档，直接看真实用法
- 当手工冒烟测试，验证真实终端行为

完整索引见 [examples/README.md](/usr1/markit/commandline/examples/README.md)。

## CLI 宏

| 宏 | 作用 | 示例 |
|---|---|---|
| `@CLIApp[...]` | 定义 CLI 应用元信息与路由入口 | `@CLIApp[name: "app", version: "1.0.0"]` |
| `@Cmd[...]` | 定义命令与别名 | `@Cmd[command: ["serve", "s"], description: "Run server"]` |
| `@Opt[...]` | 定义命令选项 | `@Opt[["--port", "-p"], help: "Port"]` |

这些宏会自动生成：

- 命令路由
- 帮助文本
- 未知命令和未知选项提示
- 必填参数校验

## 测试

```bash
cjpm test

# 运行特定测试
cjpm test --include-tags=MacroSystem
```

## 项目结构

```text
commandline/
├── src/
│   ├── interfaces/          # 核心接口
│   │   ├── cli.cj          # CLI应用程序接口
│   │   └── command.cj      # 命令接口
│   ├── macros/             # 宏实现
│   │   ├── cli_app.cj      # @CLIApp宏
│   │   ├── cmd.cj          # @Cmd宏
│   │   ├── opt.cj          # @Opt宏
│   │   └── terminal.cj     # 调用式终端宏（输出 + 交互）
│   ├── terminal/           # 终端运行时模块
│   │   ├── terminal.cj     # spinner / progress / color / interactive
│   │   ├── interactive_models.cj
│   │   └── unix_terminal_backend.cj
│   ├── utils/              # 工具类
│   └── tests/              # 测试套件
├── cjpm.toml               # 项目配置
└── README.md               # 本文档
```

## 适用场景

- **开发者工具**: 构建面向开发者的CLI应用
- **自动化脚本**: 需要参数解析的自动化工具  
- **系统管理**: 服务器管理和运维工具
- **数据处理**: 批量数据处理CLI应用
- **部署工具**: CI/CD相关的命令行工具

## 许可证

本项目采用 Apache License 2.0 许可证。详见 [LICENSE](../LICENSE) 文件。

## 相关链接

- **markit项目**: [../markit/README.md](../markit/README.md) - 高性能Markdown解析引擎
- **markit-cli示例**: [../markit-cli/src/main.cj](../markit-cli/src/main.cj) - 完整的CLI应用示例

---

<div align="center">

**commandline** - 让CLI开发变得简单而强大

*CLI 壳层宏驱动 • 终端能力内建 • 极致简洁 • 功能完整*

</div>
