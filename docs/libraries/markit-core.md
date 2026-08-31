<a id="markit-core"></a>
# markit 内核

`markit` 是 Markdown 解析与渲染内核。它把 Markdown 输入解析为结构化 AST，并提供 HTML、Markdown、Typst、JSON 和调试树等输出。它可以一次性解析完整字符串，也可以持续接收来自文件、网络或 AI SDK 的分片输入。

## 引入

`markit` 已发布到仓颉中心仓。在 `cjpm.toml` 中添加：

```toml
[dependencies]
markit = { version = "0.2.0" }
```

## 适用场景

- 文档站和内容页渲染。
- 服务端 Markdown 转换。
- 编辑器预览、诊断和索引。
- AI 流式 Markdown 输出。
- 项目专属 Markdown 方言和扩展语法。
- 从同一份 Markdown 生成 HTML、Typst/PDF、Markdown 和结构化 JSON。

## 最小用法

```cangjie
import markit.Markit

main(): Unit {
    let out = Markit().parse("# 标题\n\nHello, **Markit**.")

    println(out.toHtml())
    println(out.toMarkdown())
    println(out.toTypst())
    println(out.toJson())
}
```

需要表格、任务列表、脚注、数学公式和裸链接时，使用 GFM bundle：

```cangjie
import markit.Markit
import markit.bundles.GFMBundle

let parser = Markit(GFMBundle())
let out = parser.parse("""
# 发布清单

| 项目 | 状态 |
| --- | --- |
| parser | done |

- [x] streaming
- [ ] export

公式：$E = mc^2$
""")

println(out.toHtml())
```

## 流式解析

```cangjie
let session = Markit(GFMBundle()).createSession()

for (chunk in ["# 标", "题\n\n", "- item\n\n"]) {
    let update = session.feed(chunk)
    for (fragment in update.emittedHtmlFragments) {
        println(fragment.html)
    }
}

session.finalize()
println(session.toHtml())
```

如果输入来自字节流，使用 `feedBytes`，由 UTF-8 decoder 处理跨 chunk 的中文、emoji 和其他多字节字符。

## Bundle 与插件

`markit` 用 bundle 组合常用能力，用 plugin 扩展语法和输出：

| 能力 | 用途 |
| --- | --- |
| Standard Markdown | 标题、段落、列表、引用、代码块、链接、图片、粗体、斜体 |
| CommonMark | HTML block/inline、entity reference、setext heading、CommonMark autolink |
| GFM | 表格、任务列表、脚注、删除线、数学公式、裸链接 |
| i18n | 多语言块和行内内容，按目标语言过滤 |
| TOC | 从 heading 生成目录或结构化标题列表 |

插件可以注册 block parser、inline parser、renderer、session state、symbol table、emission filter 和 finalize processor。内核负责管线和状态管理，站点导航、主题模板和文件系统逻辑由上层应用处理。

## 输出

`ParseOutput` 是一次解析的统一结果：

```cangjie
let out = Markit().parse("# Intro\n\nHello")

let html = out.toHtml()
let markdown = out.toMarkdown()
let typst = out.toTypst()
let json = out.toJson()
let root = out.root()
let snapshot = out.snapshot
```

大文档或批量输出可以使用 writer API：

```cangjie
out.writeHtml(htmlOutput)
out.writeMarkdown(markdownOutput)
out.writeTypst(typstOutput)
out.writeJson(jsonOutput)
```

## 继续阅读

- [快速开始](../getting-started/quick-start.md)
- [架构](../core-concepts/architecture.md)
- [Source 模型](../core-concepts/source-model.md)
- [流式与增量解析](../advanced/streaming-incremental.md)
- [插件系统](../plugins/plugin-system.md)
