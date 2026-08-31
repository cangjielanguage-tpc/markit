# examples

`commandline/examples/` 下的每个目录都是一个独立 executable 包，可以直接 `cjpm run`。

## 示例列表

| 示例 | 覆盖能力 | 目录 |
|---|---|---|
| `output-demo` | `@Plain / @Info / @Verbose / @Warn / @Err / @NewLine / @Write / @Success` | [output-demo](/usr1/markit/commandline/examples/output-demo) |
| `progress-demo` | `@Progress` 与进度条生成 | [progress-demo](/usr1/markit/commandline/examples/progress-demo) |
| `spinner-demo` | `@Spinner / @UpdateSpinner / @InsertBefore / @StopSpinner` | [spinner-demo](/usr1/markit/commandline/examples/spinner-demo) |
| `color-demo` | `@Color / @Background / @Styled` | [color-demo](/usr1/markit/commandline/examples/color-demo) |
| `interactive-demo` | `@Prompt / @Confirm / @Select / @MultiSelect` | [interactive-demo](/usr1/markit/commandline/examples/interactive-demo) |
| `cli-app-demo` | `@CLIApp / @Cmd / @Opt` | [cli-app-demo](/usr1/markit/commandline/examples/cli-app-demo) |
| `showcase-demo` | 交互式总入口，可按分类/分层查看所有 example | [showcase-demo](/usr1/markit/commandline/examples/showcase-demo) |

## 运行方式

进入任意示例目录后执行：

```bash
cjpm run
```

`cli-app-demo` 需要额外的命令参数，例如：

```bash
cd /usr1/markit/commandline/examples/cli-app-demo
cjpm run -- hello --name world
```

交互类示例在 Unix/macOS 终端下支持方向键；Windows 当前默认回退为文本输入模式。
