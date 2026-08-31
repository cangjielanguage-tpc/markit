# color-demo

演示 `commandline` 的颜色和样式宏。这个示例现在不是“几条打印”，而是一个完整的样式展示页，代码里把常见用法都铺开了。

- `@Color`
- `@Background`
- `@Styled`
- `@Info`
- `@Warn`
- `@Err`
- `@Plain`
- `@NewLine`
- `@Verbose`
- `@Success`

## 运行

```bash
cd /usr1/markit/commandline/examples/color-demo
cjpm run
```

## 展示内容

这个示例分成 5 段：

1. `Foreground Palette`
   展示常用前景色和亮色。
2. `Background Tags`
   展示背景色标签和带语义感的 tag 风格。
3. `Composed Styles`
   展示前景色、背景色、`Bold`、`Dim` 的组合样式。
4. `Styled Log Macros`
   展示把彩色字符串嵌进 `@Info / @Warn / @Err / @Verbose / @Success` 这类日志宏里。
5. `Inline Composition`
   展示先把 `@Styled / @Color` 结果赋值，再拼进普通文本里的写法。

## 预期效果

- 先看到一组前景色样本，方便确认 ANSI 色是否正常
- 再看到几种背景 tag 写法，方便确认标签类视觉
- 再看到几种组合样式，方便确认 `Bold / Dim / foreground / background` 是否能叠加
- 最后看到几条带彩色内容的日志消息，方便确认颜色宏和日志宏可以一起用
- 最后还能看到“先生成样式字符串，再做拼接”的常见组合写法

## 适合拿来验证什么

- 当前终端是否支持 ANSI 颜色
- `@Color / @Background / @Styled` 的实际视觉差异
- 彩色字符串放进日志宏后是否仍然正常显示
- 灰色、亮色、背景色在你的终端主题下是否可读

## 可以直接抄的用法

- 用 `@Color(...)` 做局部高亮：
  - `@Info("Server: " + @Color("http://127.0.0.1:8080", AnsiColor.Cyan))`
- 用 `@Background(...)` 做简单 tag：
  - `@Plain("  " + @Background(" tag ", AnsiColor.BgCyan) + " background only")`
- 用 `@Styled(...)` 做完整 banner：
  - `@Styled(" ERROR ", foreground: AnsiColor.White, background: AnsiColor.BgRed, styles: [AnsiColor.Bold])`
- 在日志宏里嵌入颜色片段：
  - `@Warn("Cache policy: " + @Styled(...))`
- 先生成样式字符串，再嵌回普通文本：
  - `let banner = @Styled(" commandline ", foreground: AnsiColor.White, background: AnsiColor.BgCyan, styles: [AnsiColor.Bold])`
  - `@Plain("  ${banner} ...")`

## 关键代码

主程序在 [main.cj](/usr1/markit/commandline/examples/color-demo/src/main.cj)。
