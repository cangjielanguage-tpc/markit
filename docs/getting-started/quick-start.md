<a id="quick-start"></a>
# 快速开始

这一页用三个最小示例带你跑通 Markit：普通解析、GFM 解析和流式解析。示例都使用仓颉代码块，可以直接作为项目里的入口代码改写。

## 添加依赖

Markit 系列库已发布到仓颉中心仓。只使用 Markdown 解析内核时，在 `cjpm.toml` 中引入 `markit`：

```toml
[dependencies]
markit = { version = "0.2.0" }
```

需要在自己的工具中单独使用代码高亮、数学公式或 Mermaid 渲染时，可以按需添加：

```toml
[dependencies]
codehl = { version = "0.2.0" }
mathtex = { version = "0.2.0" }
mermaid4cj = { version = "0.2.0" }
```

## 最小 parse 示例

默认 `Markit()` 启用 Standard Markdown，适合标题、段落、列表、引用、代码块、链接、图片、粗体、斜体等常用内容。

```cangjie
import markit.Markit

main(): Unit {
    let out = Markit().parse("""
# Markit

Hello, **Markdown**.

- fast
- streaming ready
""")

    println(out.toHtml())
}
```

`parse(markdown: String)` 返回 `ParseOutput`。同一个结果对象可以输出多种格式，也可以访问 AST 与快照：

```cangjie
let out = Markit().parse("# 标题\n\n段落")

let html = out.toHtml()
let markdown = out.toMarkdown()
let typst = out.toTypst()
let json = out.toJson()

let root = out.root()
let snapshot = out.snapshot
let finalUpdate = out.finalUpdate
let tables = out.symbolTables()
```

如果输出很大，优先使用 stream 写出接口：

```cangjie
out.writeHtml(htmlOutput)
out.writeMarkdown(markdownOutput)
out.writeTypst(typstOutput)
out.writeJson(jsonOutput)
```

## GFM 示例

需要表格、任务列表、脚注、删除线、数学公式、裸链接等 GitHub 风格能力时，使用 `GFMBundle`。

```cangjie
import markit.Markit
import markit.bundles.GFMBundle

main(): Unit {
    let parser = Markit(GFMBundle())
    let out = parser.parse("""
# 发布清单

| 项目 | 状态 |
| --- | --- |
| parser | done |
| docs | ready |

- [x] parse
- [ ] publish

公式：$E = mc^2$

参考脚注。[^note]

[^note]: GFM 能力由 bundle 注册。
""")

    println(out.toHtml())
}
```

常用构造方式：

```cangjie
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle, StandardMarkdownBundle}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

let standard = Markit()
let explicitStandard = Markit(StandardMarkdownBundle())
let commonmark = Markit(CommonMarkBundle())
let gfm = Markit(GFMBundle())
let empty = Markit.empty()

let multilingual = Markit(GFMBundle()).use(I18nPlugin(
    config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
))
```

`Markit.empty()` 不注册默认 Standard Markdown，适合插件作者搭建最小环境或做单插件测试。

## Streaming 示例

当输入来自 AI SDK、网络、文件流或分片任务时，使用 `IncrementalSession`。每次 `feed(...)` 都会返回 `IncrementalUpdate`，其中包含本次新稳定的 block、HTML fragment、AST patch 和 pending tail 状态。

```cangjie
import markit.Markit
import markit.bundles.GFMBundle

main(): Unit {
    let session = Markit(GFMBundle()).createSession()

    for (chunk in ["# 标", "题\n\n", "- item\n\n", "~~~cangjie\n", "println(1)\n", "~~~\n"]) {
        let update = session.feed(chunk)

        for (fragment in update.emittedHtmlFragments) {
            println(fragment.html)
        }

        if (update.pendingTailState.hasPendingContent()) {
            println(update.pendingTailState.summary)
        }
    }

    let finalUpdate = session.finalize()
    println(session.toHtml())
}
```

上面的示例里，列表项在空行后可以稳定提交；代码围栏会一直留在 pending tail，直到闭合围栏出现或 `finalize()` 收尾。这样 UI 可以追加稳定 HTML，同时把未完成尾部渲染到临时预览区。

如果 chunk 边界可能切开 UTF-8 多字节字符，请使用 `feedBytes(...)`：

```cangjie
let markdown = "# 中文标题\n\n段落\n"
let session = Markit().createSession()

for (byte in markdown.toArray()) {
    session.feedBytes([byte])
}

session.finalize()
println(session.toHtml())
```

## InputStream 示例

已有 `InputStream` 时，可以直接交给 `parse(input)`。它内部会读取 byte chunk 并走同一套 session 与 UTF-8 decoder。

```cangjie
import std.io.ByteBuffer
import markit.Markit

main(): Unit {
    let input = ByteBuffer("# 标题\n\n从 InputStream 解析。".toArray())
    let out = Markit().parse(input)

    println(out.toHtml())
}
```

需要自定义 `ParseOptions` 时，手动创建 session 并按自己的 chunk 策略调用 `feed` 或 `feedBytes`。

## ParseOptions

`ParseOptions` 控制 source 保留、HTML fragment 和 pending preview：

```cangjie
import markit.Markit
import markit.core.session.ParseOptions
import markit.core.source.SourceRetentionMode

let session = Markit().createSession(options: ParseOptions(
    sourceRetentionMode: SourceRetentionMode.Essential,
    emitHtmlFragments: true,
    emitPreview: true
))
```

常用设置：

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `sourceRetentionMode` | `Essential` | 控制 finalize 后是否保留完整 source。调试或 round-trip 可用 `Full`，低内存场景可用 `None`。 |
| `emitHtmlFragments` | `true` | 是否在 update 中生成稳定 HTML fragment。 |
| `emitPreview` | `true` | 是否在 `pendingTailState.previewText` 中携带预览文本。 |
| `inputChunkSize` | `8192` | 输入 chunk 大小配置入口；自定义读取策略时按这个值或自己的策略手动 feed。 |

## 下一步

跑通本页示例后，可以继续阅读：

- [Bundles 与内置能力](../bundles/bundles-and-builtins.md)：选择 Standard、CommonMark、GFM 或插件组合。
- [架构](../core-concepts/architecture.md)：理解 session、registry、block pipeline 和 renderer。
- [Source Model](../core-concepts/source-model.md)：理解 byte/rune offset、source retention 和 snapshot 查询。
- [流式与增量解析](../advanced/streaming-incremental.md)：接入 AI streaming、HTML fragment、pending tail 和 AST patch。
