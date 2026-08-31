<a id="code-highlighting"></a>
# 代码块与高亮

Markit 的 fenced code block 支持语言标记、行高亮、按语言过滤的代码行、多文件代码组和构建期语法高亮。`markit-cli` 在生成网站时会把代码块渲染成静态 HTML，页面运行时不需要再加载浏览器端高亮运行时。底层高亮由纯仓颉实现的 `codehl` 提供。

## 引入 codehl

`codehl` 已发布到仓颉中心仓。独立使用代码高亮库时，在 `cjpm.toml` 中添加：

```toml
[dependencies]
codehl = { version = "0.2.0" }
```

## 基础代码块

代码块使用标准 Markdown fenced code block 语法。info string 的第一个词是语言名：

````markdown
```cangjie
main(): Unit {
    println("hello")
}
```
````

常用内置别名：

| 别名 | 语言 |
| --- | --- |
| `cj` | `cangjie` |
| `js` / `mjs` / `cjs` | `javascript` |
| `jsx` | `javascriptreact` |
| `ts` | `typescript` |
| `tsx` | `typescriptreact` |
| `md` | `markdown` |
| `sh` / `shell` / `zsh` / `fish` | `bash` |
| `yml` | `yaml` |

未知语言会输出已转义的普通代码块，不会让整页构建失败。

## 默认支持的语言

Markit 随 `codehl` 打包常用 TextMate grammar，并会从 grammar 文件名、`name`、`scopeName` 和 `fileTypes` 自动发现语言。常用语言可以直接写在 fenced code block 的 info string 中：

| 类别 | 语言 |
| --- | --- |
| Markit 常用 | `cangjie` / `cj`、`markdown` / `md`、`json`、`jsonc`、`jsonl`、`yaml` / `yml`、`toml` |
| Web 与样式 | `html`、`css`、`scss`、`less`、`javascript` / `js`、`javascriptreact` / `jsx`、`typescript` / `ts`、`typescriptreact` / `tsx`、`pug`、`handlebars` / `hbs` |
| 后端与通用语言 | `java`、`go`、`python` / `py`、`ruby` / `rb`、`php`、`csharp` / `cs`、`swift`、`dart`、`lua`、`perl`、`r`、`julia`、`clojure`、`fsharp`、`groovy` |
| 系统与底层 | `c`、`cpp`、`cuda-cpp`、`rust` / `rs`、`objective-c`、`objective-cpp`、`hlsl`、`shaderlab` |
| Shell、构建与运维 | `bash` / `sh`、`powershell` / `ps1`、`batchfile` / `bat` / `cmd`、`docker` / `dockerfile`、`make` / `makefile`、`dotenv` / `env`、`ini`、`sql`、`diff` |
| 文档与其他格式 | `xml`、`latex` / `tex`、`bibtex` / `bib`、`restructuredtext` / `rst`、`antlr4` / `g4` |

如果站点需要额外语言，可以通过 `codeBlock.grammarDirs` 和 `codeBlock.languages` 注册自己的 TextMate grammar。

## 高亮效果示例

下面的代码块就是 Markit 生成本站时的渲染效果。

```cangjie {4,7..=10}
import markit.Markit
import markit.bundles.GFMBundle

main(): Unit {
    let parser = Markit(GFMBundle())
    let out = parser.parse("# Hello\n\n- [x] rendered by Markit")
    println(out.toHtml())
    println(out.toTypst())
}
```

```typescript {3,8}
type Page = {
  title: string
  html: string
}

export function render(page: Page) {
  return `<article><h1>${page.title}</h1>${page.html}</article>`
}
```

```json {2..=6}
{
  "format": "website",
  "title": "Markit",
  "codeBlock": {
    "group": true
  }
}
```

## 行高亮

在语言名后使用 `{...}` 指定需要强调的行。行号从 `1` 开始，支持单行和闭区间：

````markdown
```typescript {1,3..=5}
const name = "markit"
console.log(name)
export const ok = true
export const mode = "website"
export const theme = "dark-plus"
```
````

生成 HTML 时，高亮行会带有稳定的 `highlighted` class，主题 CSS 可以对这些行设置背景或边框。

渲染效果：

```diff {2,5}
- old render path
+ native markit render path
  shared parser
- browser runtime
+ build-time rich content
```

## 代码块 i18n

在行高亮之后可以使用 `[...]` 为代码行标注语言范围。渲染时，Markit 会根据目标语言保留对应行：

````markdown
```cangjie {2} [1..=3:zh,4..=6:en]
main(): Unit {
    println("你好，Markit")
}
main(): Unit {
    println("Hello, Markit")
}
```
````

这适合在同一个 Markdown 文件中维护多语言代码示例。没有 i18n 标注的行默认对所有目标语言可见。

也可以保留公共代码，只过滤注释或输出文本。下面的代码块会按当前站点目标语言显示对应行：

```typescript [2:zh,3:en,5:zh,6:en]
export function greet(name: string) {
  // 输出中文问候
  // Print an English greeting
  const prefix =
    "你好"
    "Hello"
  return `${prefix}, ${name}`
}
```

在生成中文站点时会保留 `zh` 行；生成英文站点时会保留 `en` 行；没有语言标注的函数结构对所有语言可见。

## 多文件代码组

开启代码组后，可以在一个 fenced code block 中用 `///// file [language]` 分隔多个片段：

````markdown
```cangjie
///// main.cj [cangjie]
main(): Unit {
    println("hello")
}
///// README.md [markdown]
# Demo
```
````

网站输出会显示为可切换的代码标签。代码组适合展示一组相关文件、不同语言实现或源码与说明文档的组合。外层语言为 `markdown` 或 `md` 的代码块会按普通 Markdown 示例展示，内部的 fenced code block 文本不会被识别成代码组。

代码组中的每个片段都可以使用自己的语言，高亮由片段头部的 `[language]` 决定：

```cangjie
///// app.cj [cangjie]
import markit.Markit
import markit.bundles.GFMBundle

let html = Markit(GFMBundle()).parse("# Hello").toHtml()
println(html)
///// package.json [json]
{
  "scripts": {
    "docs": "markit render -i docs -o dist"
  }
}
///// preview.sh [bash]
markit serve -i docs -o dist -H 127.0.0.1 -p 8080
```

行高亮、代码块 i18n 和代码组可以组合使用：

```cangjie {3,8} [2..=4:zh,7..=9:en]
///// hello.cj [cangjie]
main(): Unit {
    println("你好，Markit")
}
///// hello.cj [cangjie]
main(): Unit {
    println("Hello, Markit")
}
```

## markit-cli 配置

```json
{
  "codeBlock": {
    "enabled": true,
    "group": true,
    "autoAnchor": true,
    "lightTheme": "light-plus",
    "darkTheme": "dark-plus"
  }
}
```

常用字段：

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `codeBlock.enabled` | `true` | 是否启用构建期高亮 |
| `codeBlock.group` | `false` | 是否启用多文件代码组 |
| `codeBlock.autoAnchor` | `false` | 是否为代码块生成可复制引用的锚点 |
| `codeBlock.theme` | `""` | 单主题名称；设置后浅色和暗色都使用该主题 |
| `codeBlock.lightTheme` | `light-plus` | 浅色主题 |
| `codeBlock.darkTheme` | `dark-plus` | 暗色主题 |
| `codeBlock.grammarDirs` | `[]` | 额外 TextMate grammar 搜索目录 |
| `codeBlock.themeDirs` | `[]` | 额外主题搜索目录 |
| `codeBlock.languages` | `{}` | 注册语言到 grammar 文件的映射 |
| `codeBlock.aliases` | `{}` | 注册语言别名 |

## 自定义 grammar 和主题

```json
{
  "codeBlock": {
    "grammarDirs": ["./grammars"],
    "themeDirs": ["./themes"],
    "languages": {
      "vue": "vue.tmLanguage.json",
      "astro": {
        "grammar": "astro.tmLanguage.json",
        "aliases": ["astrojs"]
      }
    },
    "aliases": {
      "shell": "bash"
    }
  }
}
```

相对路径按 `markit.json` 所在目录解析。显式 `languages` 和 `aliases` 优先级最高，其次是用户目录，最后是内置 grammar 和主题。

## codehl 库能力

`codehl` 是 Markit 使用的纯仓颉构建期高亮库。它读取 VS Code/TextMate grammar JSON 和主题 JSON，生成 token 中间结构或 HTML 片段。JSON 解析依赖第三方库 [`seajson`](https://pkg.cangjie-lang.cn/package/seajson)。

```cangjie
import codehl.{Highlighter, HighlightOptions}

let highlighter = Highlighter()
let html = highlighter.highlight(
    "let value = 1",
    options: HighlightOptions(lang: "cangjie", themeName: "light-plus")
)

println(html)
```

核心能力：

| API | 用途 |
| --- | --- |
| `supportsLanguage(lang)` | 检查语言是否能解析到 tokenizer |
| `supportsTheme(theme)` | 检查主题是否可加载 |
| `codeToTokens(code, options)` | 输出 `CodeBlock` token IR |
| `highlight(code, options)` | 输出单主题 HTML |
| `highlightPlain(code, options)` | 输出 escaped plain HTML |
| `highlightDualTheme(code, options)` | 输出浅色/暗色双主题 wrapper |
| `highlightDualThemeFragments(code, options)` | 分别返回浅色/暗色 HTML 片段，便于上层写入节点 meta |

`HighlightOptions` 可设置 `lang`、`classPrefix`、`highlightLines`、`i18nLines`、`targetLang`、`themeName` 和 `theme`。Markit 的 Markdown 代码块语法会被解析为这些选项，再交给 `codehl` 生成最终 HTML。
