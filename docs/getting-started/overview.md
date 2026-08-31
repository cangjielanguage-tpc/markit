<a id="overview"></a>
# 概览

Markit 是一组用仓颉编写的 Markdown 文档处理项目，覆盖解析内核、命令行文档站生成、代码高亮、数学公式、Mermaid 图表和本地预览。`markit` 内核把一次性解析、流式解析、AST 查询和多格式输出放在同一套 session 模型里：你可以从一个字符串得到 HTML，也可以连续喂入网络 byte chunk，在每个稳定块生成时立即拿到 HTML fragment。

Markit 的核心入口是 `Markit`。默认构造会启用 Standard Markdown；需要 CommonMark、GFM、i18n、TOC 或业务语法时，再组合 bundle 与 plugin。

```cangjie
import markit.Markit

main(): Unit {
    let out = Markit().parse("# 标题\n\n段落 with **bold**")

    println(out.toHtml())
    println(out.toMarkdown())
    println(out.toTypst())
    println(out.toJson())
}
```

## 你可以用 Markit 做什么

Markit 适合把 Markdown 放进真实产品流程，而不只是把一段文本转成 HTML。

- **渲染文档与内容页**：把 Markdown 输出为 HTML、Markdown、Typst、JSON 或 AST debug tree，用同一次解析结果服务页面、导出、搜索索引和测试断言。
- **构建 AI 输出界面**：对模型逐 chunk 输出的 Markdown 做流式解析，只提交已经稳定的 block，把未完成代码围栏、表格、脚注或段落留在 pending tail。
- **处理大文档和长会话**：通过 `InputStream`、`feedBytes`、`writeHtml` 等接口减少一次性字符串分配，并在 finalize 后按 retention 策略释放 source。
- **扩展 Markdown 方言**：通过 bundle/plugin 注册 block parser、inline parser、renderer、session state、symbol table、filter 和 finalize processor。
- **做结构化分析**：从 `DocumentSnapshot` 查询节点、source span、heading、symbol table、AST patch 和 stable hash，接入编辑器、索引器或增量渲染系统。

## 基本心智模型

使用 Markit 时，可以把解析过程理解成四步：

```text
选择能力
  -> 创建 parser 或 session
  -> 输入 Markdown 字符串、InputStream、String chunk 或 byte chunk
  -> 消费 ParseOutput、IncrementalUpdate、HTML fragment 或 DocumentSnapshot
```

批量解析使用 `parse(...)`，它会创建 session、feed 输入、finalize，并返回 `ParseOutput`：

```cangjie
let out = Markit().parse("# Intro\n\nHello")

let html = out.toHtml()
let root = out.root()
let snapshot = out.snapshot
```

流式解析使用 `createSession()`，你负责在输入结束时调用 `finalize()`：

```cangjie
let session = Markit().createSession()

session.feed("# Intro")
session.feed("\n\nHello")
let finalUpdate = session.finalize()

println(session.toHtml())
```

这两种入口共享同一套 parser、renderer、source model 和插件系统。先从批量解析开始最简单；当输入来自文件、网络或 AI SDK 时，再切到 session。

## 能力组合

Markit 用 bundle 打包常用语法能力：

| 能力 | 入口 | 适合场景 |
| --- | --- | --- |
| Standard Markdown | `Markit()` 或 `Markit(StandardMarkdownBundle())` | 标题、段落、列表、引用、代码块、链接、图片、粗体、斜体等常用内容 |
| CommonMark | `Markit(CommonMarkBundle())` | 需要 HTML block/inline、entity reference、setext heading、CommonMark autolink 的内容 |
| GFM | `Markit(GFMBundle())` | 表格、任务列表、脚注、删除线、数学公式、裸链接等 GitHub 风格内容 |
| i18n | `Markit(...).use(I18nPlugin(...))` | 多语言块、多语言行内内容和按目标语言过滤输出 |
| TOC | `Toc.parse(out.root(), ...)` | 从 heading 生成目录或结构化 heading 列表 |

示例：

```cangjie
import markit.Markit
import markit.bundles.GFMBundle

let parser = Markit(GFMBundle())
let out = parser.parse("""
# Roadmap

| Item | Done |
| --- | --- |
| Parser | yes |

- [x] streaming
- [ ] export
""")

println(out.toHtml())
```

## 学习路径

如果你是第一次使用 Markit，推荐按下面顺序阅读：

1. **快速开始**：先跑通最小 parse、GFM 和 streaming 示例，理解 `ParseOutput` 与 `IncrementalUpdate`。
2. **Bundles 与内置能力**：选择 Standard、CommonMark、GFM，了解每个 bundle 注册了哪些语法。
3. **架构**：理解 `IncrementalSession`、registry、block pipeline、inline pipeline 和 renderer 如何协作。
4. **Source Model**：掌握 `SourceBuffer`、`SourceSpan`、`LineIndex`、byte/rune offset 和 source retention。
5. **流式与增量解析**：接入 AI streaming、网络输入、HTML fragment、pending tail 和 AST patch。
6. **插件系统**：当内置语法不够时，再编写自己的 parser、renderer 或 finalize processor。

## AI streaming 的价值

AI 输出不是完整文档，而是一条不断增长的 Markdown 流。直接把每个 chunk 当完整 Markdown 渲染，常见问题是闪烁、重复、代码围栏提前闭合、表格结构误判，或者中文与 emoji 被 byte boundary 切开。

Markit 的 session 模型把“稳定内容”和“未完成尾部”分开：

- 已经 seal 的 top-level block 会进入 `sealedBlocks`，并可生成 `emittedHtmlFragments`。
- 未完成段落、代码围栏、HTML block、math block、脚注定义或 i18n block 会留在 `pendingTailState`。
- 后发信息需要修正已有节点时，插件可以通过 `astPatches` 发出更新。
- byte stream 可以走 `feedBytes`，由 UTF-8 decoder 处理跨 chunk 多字节字符。

因此，UI 可以把稳定 fragment 追加到正文，把 pending tail 放在临时预览区，并在流结束时调用 `finalize()` 收口。这让 AI 输出既能快速出现，又不会把半成品误提交为最终 HTML。
