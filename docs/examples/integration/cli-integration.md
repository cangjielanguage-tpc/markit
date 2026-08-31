<a id="cli-integration"></a>
# CLI 集成提示

`markit-cli` 是 Markit 作为库集成的典型示例：CLI 负责文件扫描、站点配置、主题、导航、搜索索引和资源处理；Markit 负责把单份 Markdown 解析成 AST，并输出 HTML、Markdown、Typst 或 JSON。

Markit 系列库已发布到仓颉中心仓。应用侧在 `cjpm.toml` 中按版本引入需要的库：

```toml
[dependencies]
markit = { version = "0.2.0" }
codehl = { version = "0.2.0" }
mathtex = { version = "0.2.0" }
mermaid4cj = { version = "0.2.0" }
```

## 集中构造 parser

CLI 侧推荐集中构造 parser，而不是在每个 processor 中散落 bundle 配置。当前入口是 `markit-cli/src/utils/cli_markit_factory.cj`。

```cangjie
let parser = CliMarkitFactory.build(
    config,
    linkConfig: Some(linkConfig),
    currentPagePath: currentPagePath,
    headingInitialState: Some(headingInitialState)
)

let output = parser.parse(content)
let document = CliMarkitFactory.documentOf(output)
```

这种集成方式有几个好处：

- FileTree、HeadingInfo、RenderMode、heading numbering、i18n、table、fenced code group 等配置都由 CLI 在构造 parser 时注入。
- 每次 `process` 都有独立 session，适合并行渲染。
- parser 插件实例不保存跨文档状态，跨文档状态由 CLI 的扫描结果或 `GlobalContext` 管理。
- Markit core 保持小而可插拔，站点构建逻辑留在 CLI。

## 推荐配置组合

文档站通常使用 `GFMBundle` 加 i18n，并注入站点级链接和 heading 配置。

```cangjie
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.commonmark.block.html_block.HtmlBlockConfig
import markit.plugins.gfm.block.table.TableConfig
import markit.plugins.i18n.I18nPlugin
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.plugins.standard.block.heading.{HeadingClosableConfig, HeadingNumberingConfig, HeadingSlugConfig}

let parser = Markit().use(GFMBundle(
    headingNumberingConfig: HeadingNumberingConfig(enabled: true),
    closableConfig: HeadingClosableConfig(enabled: config.headingClosable),
    headingSlugConfig: HeadingSlugConfig(currentPagePath: currentPagePath),
    fencedCodeBlockConfig: FencedCodeBlockConfig(enableGroup: config.codeblockGroupEnabled),
    tableConfig: TableConfig(enableThreeLineTable: config.tableThreeLine),
    htmlBlockConfig: HtmlBlockConfig(enableInlineMarkdownParsing: true),
    linkConfig: linkConfig
)).use(I18nPlugin(config: i18nConfig))
```

`currentPagePath`、`linkConfig` 和 heading 初始状态应由 CLI 根据当前文件、summary、站点结构和渲染目标计算。Markit 不扫描目录，也不持有全站导航。

## ParseOutput 用法

站点、PDF、Markdown、Typst 输出都应消费 `ParseOutput`。

```cangjie
let output = parser.parse(content)

let html = output.toHtml()
let markdown = output.toMarkdown()
let typst = output.toTypst()
let json = output.toJson()
```

需要 `DocumentNode` 时，可以集中提供一个收窄函数：

```cangjie
import markit.ParseOutput
import markit.core.nodes.DocumentNode

public static func documentOf(output: ParseOutput): DocumentNode {
    return (output.root() as DocumentNode).getOrThrow()
}
```

这样 processor 内部不用重复写类型转换，也方便以后统一增加断言或错误信息。

## HTML 输出

网站 processor 通常做这几步：

1. 构造带当前页面配置的 parser。
2. `parse(content)` 得到 `ParseOutput`。
3. 从 `DocumentNode` 提取 heading、TOC、搜索索引字段。
4. `document.toHtml()` 或 `output.toHtml()` 得到正文 HTML。
5. CLI 层处理主题模板、导航、资源路径、复制按钮、统计信息等。

```cangjie
let parseResult = createParser(currentPagePath).parse(content)
let document = CliMarkitFactory.documentOf(parseResult)

let headings = Toc.extractDetailedHeadingList(document, minLevel: 1, maxLevel: 3)
let htmlContent = document.toHtml()
```

本地图片重写、Mermaid、站点导航、搜索索引、Git 链接、主题模板等都属于应用层。它们可以使用 Markit 输出的 AST/HTML，但不需要进入 parser core。

## Markdown 与 Typst 输出

Markdown processor 可以把 parse 后的规范化 Markdown 串起来，适合合并文档、生成单文件输出或做格式化。

```cangjie
let parseResult = parser.parse(content)
let document = CliMarkitFactory.documentOf(parseResult)
let markdownContent = document.toMarkdown()
```

Typst/PDF 管线通常使用 `toTypst()` 或 stream API：

```cangjie
let typst = parser.parse(content).toTypst()
```

大文件或批量任务可以优先使用 writer API：

```cangjie
let out = parser.parse(content)
out.writeHtml(htmlOutputStream)
out.writeTypst(typstOutputStream)
```

## 流式预览

watch/serve、编辑器集成或远程内容预览可以直接使用 `IncrementalSession`。稳定内容用 fragment 追加，临时内容用 pending tail 预览，finalize 时处理最后的 patch。

```cangjie
let session = parser.createSession()

for (chunk in chunks) {
    let update = session.feedBytes(chunk)
    for (fragment in update.emittedHtmlFragments) {
        sendStableHtml(fragment.nodeId, fragment.html)
    }
    if (update.pendingTailState.hasPendingContent()) {
        sendPreview(update.pendingTailState.previewText)
    }
    for (patch in update.astPatches) {
        sendPatch(patch.nodeId, patch.html)
    }
}

let finalUpdate = session.finalize()
```

这类集成要特别注意：

- 输入是 bytes 时使用 `feedBytes`，避免切开 UTF-8 字符。
- final update 也要消费，因为 footnote、reference、i18n 等能力可能在 finalize 产生 patch。
- 如果不需要实时 HTML fragment，可以用 `ParseOptions(emitHtmlFragments: false)` 降低中间输出成本。

## 多语言站点

多语言渲染通常组合：

- `GFMBundle`
- `I18nPlugin`
- heading slug/numbering
- link config
- fenced code group
- table config
- HTML block config

CLI 负责决定当前语言、可用语言列表、输出目录和语言切换链接；Markit 负责按 `I18nConfig(defaultLanguage, targetLanguage)` 过滤和渲染当前文档。

```cangjie
let parser = CliMarkitFactory.build(
    config,
    linkConfig: Some(linkConfig),
    currentPagePath: currentPagePath,
    headingInitialState: Some(headingInitialState)
)

let output = parser.parse(content)
```

TOC 应在 parse 后基于当前语言的 `DocumentNode` 提取，避免把其他语言标题混入当前页面目录。

## 目录渲染约定

目录渲染使用 `markit.md + markit.json` 约定：

```bash
cd markit-cli
cjpm build
cjpm run -- render -i ../docs -o ../target/markit-docs
```

`markit.md` 负责章节导航和 homepage，`markit.json` 负责 theme、toc、heading numbering、summary 文件名、站点信息等配置。

## 集成边界

保持边界清晰会让 CLI 更容易维护：

- Markit 处理当前文档的解析、AST、session state 和多格式输出。
- CLI 处理文件系统、并行任务、站点结构、主题模板和资源复制。
- 全站链接信息通过 `LinkConfig`、`FileTree`、`HeadingInfo` 注入 parser。
- 多语言目标通过 `I18nConfig` 注入 parser。
- 搜索索引、统计信息、PDF asset rewrite、导航 HTML 留在 CLI。

这样的边界让 parser 可以在 CLI、服务端、编辑器和测试工具中复用，而不会携带站点构建器的假设。
