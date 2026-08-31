<a id="bundles"></a>
# Bundles 与内置能力

bundle 是一组插件的组合。Markit 内置 Standard、CommonMark 和 GFM 三个常用能力集合；i18n 和 TOC 作为独立插件/工具提供，可以按需叠加。

```cangjie
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle, StandardMarkdownBundle}

let standard = Markit(StandardMarkdownBundle())
let commonmark = Markit(CommonMarkBundle())
let gfm = Markit(GFMBundle())
```

默认 `Markit()` 等价于启用 Standard Markdown。文档站、README 渲染、开发者内容和带表格/任务列表的 Markdown 通常直接使用 `GFMBundle()`。

## 选择建议

| 场景 | 推荐组合 |
| --- | --- |
| 基础 Markdown、标题、列表、链接、代码块 | `Markit()` 或 `Markit(StandardMarkdownBundle())` |
| 需要 HTML block/inline、entity、setext heading、CommonMark autolink | `Markit(CommonMarkBundle())` |
| 需要 table、task list、footnote、math、strikethrough | `Markit(GFMBundle())` |
| 多语言文档 | `Markit(GFMBundle()).use(I18nPlugin(...))` |
| 文档站目录 | `GFMBundle` 加 `Toc` 工具或 `TocPlugin` renderer |

bundle 包含关系：

```text
StandardMarkdownBundle
  -> CommonMarkBundle
      -> GFMBundle
```

`CommonMarkBundle` 和 `GFMBundle` 都声明包含 Standard Markdown。使用 `Markit(GFMBundle())` 时不需要额外 `.use(StandardMarkdownBundle())`。

## 插件规格速查

内置 parser 插件按 block、inline、finalize/filter 和 renderer 协同工作。下表列出各 bundle 面向用户承诺的语法入口和主要输出范围。

### Standard 插件

| 插件 | Markdown 语法 | 主要节点/能力 | 输出 |
| --- | --- | --- | --- |
| Blockquote | `>` 引用块 | blockquote block | HTML / Markdown / Typst / JSON |
| Heading | `#` 到 `######` | heading、slug、编号、折叠配置、heading state | HTML / Markdown / Typst / JSON |
| Divider | `---`、`***`、`___` | thematic break | HTML / Markdown / Typst / JSON |
| Fenced Code Block | 三反引号或波浪线代码块 | 语言、行高亮、代码组、代码块 i18n、codehl/mermaid 集成 | HTML / Markdown / Typst / JSON |
| List | `-`、`*`、`+`、数字有序列表 | ordered/unordered list、嵌套列表 | HTML / Markdown / Typst / JSON |
| Paragraph | 普通文本段落 | paragraph、soft break | HTML / Markdown / Typst / JSON |
| Inline Code | `` `code` `` | inline code span | HTML / Markdown / Typst / JSON |
| Link | `[text](url)` | link、文档站链接重写、heading/file tree 集成 | HTML / Markdown / Typst / JSON |
| Image | `![alt](src)` | image、资源路径输出 | HTML / Markdown / Typst / JSON |
| Reference | `[text][id]`、`[id]: url` | reference link/image definition 与引用解析 | HTML / Markdown / Typst / JSON |
| Bold / Italic | `**strong**`、`*em*` | emphasis、strong emphasis | HTML / Markdown / Typst / JSON |
| Break | 行尾空格、反斜杠换行、普通换行 | hard break、soft break | HTML / Markdown / Typst / JSON |

### CommonMark 插件

| 插件 | Markdown 语法 | 主要节点/能力 | 输出 |
| --- | --- | --- | --- |
| Setext Heading | 标题下方 `===` / `---` | setext heading | HTML / Markdown / Typst / JSON |
| HTML Block | 块级 HTML | HTML block，可配置是否继续解析 inline Markdown | HTML / Markdown / JSON |
| HTML Inline | 行内 HTML | HTML inline，可配置标签配对 | HTML / Markdown / JSON |
| Entity Reference | `&amp;`、`&#x26;` | 命名和数字 entity | HTML / Markdown / Typst / JSON |
| CommonMark Autolink | `<https://...>`、`<user@example.com>` | autolink | HTML / Markdown / Typst / JSON |

### GFM 插件

| 插件 | Markdown 语法 | 主要节点/能力 | 输出 |
| --- | --- | --- | --- |
| Table | pipe table | 对齐、表头、表体、三线表配置 | HTML / Markdown / Typst / JSON |
| Task List | `- [ ]`、`- [x]` | task checkbox state | HTML / Markdown / Typst / JSON |
| Alphabetic List | 字母序号列表 | alphabetic ordered list | HTML / Markdown / Typst / JSON |
| Math Block | `$$...$$` | block math，接入 mathtex | HTML / Markdown / Typst / JSON |
| Inline Math | `$...$` | inline math，接入 mathtex | HTML / Markdown / Typst / JSON |
| Bare Autolink | 裸 URL / email | GFM autolink | HTML / Markdown / Typst / JSON |
| Footnote | `[^id]` 与 definition | 脚注编号、definition state、finalize 输出 | HTML / Markdown / Typst / JSON |
| Strikethrough | `~~text~~` | strikethrough | HTML / Markdown / Typst / JSON |
| Relaxed Emphasis | GFM 风格 emphasis 边界 | 更贴近 GitHub 的强调解析 | HTML / Markdown / Typst / JSON |

### 独立插件和工具

| 能力 | 语法/入口 | 主要用途 | 输出 |
| --- | --- | --- | --- |
| I18nPlugin | `:zh{...}:`、语言 block、代码块行语言标注 | 同一份 Markdown 中维护多语言内容，按目标语言过滤节点 | HTML / Markdown / Typst / JSON |
| Toc / TocPlugin | 从 `DocumentNode` 提取 heading | 页面目录、侧边栏锚点、文档站导航 | HTML / Markdown / Typst / JSON |

## StandardMarkdownBundle

`StandardMarkdownBundle` 提供 Markit 的基础 Markdown 能力：

- blockquote
- heading
- divider/thematic break
- fenced code block
- ordered/unordered list
- paragraph
- inline code
- link
- image
- reference link / image reference
- bold
- italic
- hard break
- soft break, registered by `ParagraphPlugin`

配置示例：

```cangjie
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.plugins.standard.block.heading.{HeadingClosableConfig, HeadingNumberingConfig, HeadingSlugConfig}
import markit.plugins.standard.inline.link.{FileTree, HeadingInfo, LinkConfig, RenderMode}

let tree = FileTree(["docs/intro.md", "docs/api.md"])
tree.addHeading(HeadingInfo("API", "api", "docs/api.md", 1))

let parser = Markit(StandardMarkdownBundle(
    headingNumberingConfig: HeadingNumberingConfig(enabled: true),
    closableConfig: HeadingClosableConfig(enabled: true),
    headingSlugConfig: HeadingSlugConfig(
        currentPagePath: "docs/intro.md",
        enablePathLabels: true
    ),
    fencedCodeBlockConfig: FencedCodeBlockConfig(enableGroup: true),
    linkConfig: LinkConfig(
        fileTree: Some(tree),
        renderMode: RenderMode.Normal,
        outputExtension: "html",
        currentFilePath: "docs/intro.md"
    )
))
```

### Heading 能力

heading 插件提供：

- ATX heading 解析。
- slug 生成。
- heading numbering。
- 可折叠 heading 配置。
- HTML/Markdown/Typst renderer。
- heading session state，供链接解析、TOC 和站点集成读取。

常用配置：

```cangjie
import markit.plugins.standard.block.heading.{HeadingNumberingConfig, HeadingSlugConfig}

let numbering = HeadingNumberingConfig(
    enabled: true,
    maxDepth: 3,
    includeInHtml: true,
    separator: "."
)

let slug = HeadingSlugConfig(
    currentPagePath: "guide/start.md",
    enablePathLabels: true
)
```

### Link 能力

link 插件可以结合 `FileTree`、`HeadingInfo`、`currentFilePath` 和输出扩展名解析文档站链接。

```cangjie
import markit.plugins.standard.inline.link.{FileTree, HeadingInfo, LinkConfig, RenderMode}

let tree = FileTree(["guide/start.md", "api/core.md"])
tree.addHeading(HeadingInfo("Core API", "core-api", "api/core.md", 1))

let linkConfig = LinkConfig(
    fileTree: Some(tree),
    renderMode: RenderMode.Normal,
    outputExtension: "html",
    currentFilePath: "guide/start.md"
)
```

它适合 CLI 或站点生成器集中注入跨文档信息；parser 自身仍只处理当前文档。

### Fenced Code Group

`FencedCodeBlockConfig(enableGroup: true)` 启用代码块分组识别，适合文档站把相邻代码示例渲染成可切换的代码组。配置由 bundle 传入：

```cangjie
let parser = Markit(StandardMarkdownBundle(
    fencedCodeBlockConfig: FencedCodeBlockConfig(enableGroup: true)
))
```

## CommonMarkBundle

`CommonMarkBundle` 包含 Standard Markdown，并增加：

- setext heading
- HTML block
- HTML inline
- CommonMark autolink
- entity reference

相关配置：

```cangjie
import markit.Markit
import markit.bundles.CommonMarkBundle
import markit.plugins.commonmark.block.html_block.HtmlBlockConfig
import markit.plugins.commonmark.inline.html_inline.HtmlInlineTagPairingConfig

let parser = Markit(CommonMarkBundle(
    htmlInlineTagPairingConfig: HtmlInlineTagPairingConfig(enabled: true),
    htmlBlockConfig: HtmlBlockConfig(enableInlineMarkdownParsing: false)
))
```

`HtmlBlockConfig(enableInlineMarkdownParsing: true)` 允许 HTML block 内部继续解析 inline Markdown。站点生成器如果需要在自定义 HTML 容器里保留 Markdown 语义，可以开启它。

## GFMBundle

`GFMBundle` 包含 CommonMark 和 Standard 能力，并增加：

- table
- task list
- alphabetic list
- math block
- bare autolink
- footnote
- inline math
- strikethrough
- relaxed emphasis

配置示例：

```cangjie
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.gfm.block.table.TableConfig

let parser = Markit(GFMBundle(
    tableConfig: TableConfig(enableThreeLineTable: true)
))
```

### Table

table 插件提供 GFM table 解析和 HTML/Markdown/Typst 输出。开启 `enableThreeLineTable` 后，表格前后的三线分隔会被识别为表格样式标记，渲染时隐藏辅助 divider，并给 table 写入 meta。

```cangjie
let parser = Markit(GFMBundle(
    tableConfig: TableConfig(enableThreeLineTable: true)
))
```

### Task List

task list 插件识别 `- [ ]` 与 `- [x]` 项，并输出带 checkbox 语义的 HTML。Markdown 输出会保持任务列表标记，Typst 输出会使用对应文本结构。

```cangjie
let out = Markit(GFMBundle()).parse("""
- [x] 完成解析
- [ ] 补充文档
""")

println(out.toHtml())
```

### Footnote

footnote 插件由 continuation block parser、inline parser、node emission filter 和 renderer 组成。definition 会进入 session state，reference 在 finalize 或后续处理时获得编号和输出。

```cangjie
let out = Markit(GFMBundle()).parse("""
这是一个脚注引用[^note]。

[^note]: 脚注内容。
""")

println(out.toHtml())
```

### Math 与 Strikethrough

GFM bundle 提供 inline math、math block 和 strikethrough。它们会同时注册 HTML、Markdown 和 Typst renderer，适合把同一份 Markdown 输出到网页和 Typst/PDF 管线。

```cangjie
let out = Markit(GFMBundle()).parse("""
行内公式 $a^2 + b^2 = c^2$，以及 ~~删除线~~。

$$
E = mc^2
$$
""")
```

## i18n

`I18nPlugin` 是独立插件，通常与 `GFMBundle` 或 `CommonMarkBundle` 组合。

```cangjie
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

let parser = Markit(GFMBundle()).use(I18nPlugin(
    config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
))

let out = parser.parse("""
# :zh{中文标题}: :en{English Title}:

:::zh
默认中文
:::
:::en
English text
:::
""")

println(out.toHtml())
```

i18n 通过 session state、inline parser、continuation block parser、node emission filter、session finalize processor 和 post finalize processor 协同工作。它会对节点写入语言 meta，根据目标语言过滤渲染，并在列表/缩进块合并等场景产生 AST patch。

常见用法：

- 在同一份 Markdown 中维护多语言 block。
- 在标题、链接文本或段落中使用 inline 多语言片段。
- 为文档站构建不同目标语言输出。
- 配合 TOC 和 heading slug 保持每种语言的导航一致。

## TOC

TOC 以工具类和节点形式提供。它可以从 `DocumentNode` 中提取 heading，生成可渲染的 `TocNode`。

```cangjie
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.toc.Toc

let out = Markit(GFMBundle()).parse("# Intro\n\n## Start\n")
let toc = Toc.parse(out.root(), title: "Table of Contents", minLevel: 1, maxLevel: 3)

println(toc.toHtml())
println(toc.toMarkdown())
println(toc.toTypst())
println(toc.toJson())
```

常用方法：

- `Toc.parse(document, title, minLevel, maxLevel): TocNode`
- `Toc.extractHeadingList(document): ArrayList<(String, Int64)>`
- `Toc.extractDetailedHeadingList(document, minLevel, maxLevel): ArrayList<(String, Int64, String, String)>`
- `Toc.generateTextToc(document, indent: "  "): String`

`TocPlugin` 注册 `Toc` 节点 renderer；`TocNode` 自身也支持直接输出。站点生成器通常先 parse 文档，再用 TOC 工具提取当前页面目录、侧边栏锚点或浮动目录。

## 组合模式

### 文档站

```cangjie
let parser = Markit(GFMBundle(
    headingNumberingConfig: HeadingNumberingConfig(enabled: true),
    headingSlugConfig: HeadingSlugConfig(currentPagePath: "guide/start.md"),
    fencedCodeBlockConfig: FencedCodeBlockConfig(enableGroup: true),
    tableConfig: TableConfig(enableThreeLineTable: true),
    htmlBlockConfig: HtmlBlockConfig(enableInlineMarkdownParsing: true),
    linkConfig: linkConfig
)).use(I18nPlugin(config: i18nConfig))
```

### API 文档或 README

```cangjie
let parser = Markit(GFMBundle())
let out = parser.parse(readme)

out.dumpHtml("./dist", filename: "README.html")
out.dumpMarkdown("./dist", filename: "README.md")
```

### 自定义最小解析器

```cangjie
let parser = Markit.empty()
    .use(StandardMarkdownBundle())
    .use(CalloutPlugin())
```

`Markit.empty()` 适合插件测试、最小能力验证或需要精确控制注册顺序的场景。
