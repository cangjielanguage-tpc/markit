# Markit CLI - 命令行选项和配置项文档

本文档详细列出了 markit-cli 支持的所有命令行选项和配置文件设置项。

## 目录

- [命令行选项](#命令行选项)
  - [render 命令](#render-命令)
  - [serve 命令](#serve-命令)
  - [help 命令](#help-命令)
  - [version 命令](#version-命令)
- [配置文件设置项](#配置文件设置项)
  - [基础配置](#基础配置)
  - [i18n 配置](#i18n-配置)
  - [标题编号配置](#标题编号配置)
  - [Summary 配置](#summary-配置)
  - [章节导航配置](#章节导航配置)
  - [文章统计配置](#文章统计配置)
  - [Git 配置](#git-配置)
  - [仓库链接配置](#仓库链接配置)
  - [静态资源配置](#静态资源配置)
  - [构建期渲染能力](#构建期渲染能力)
  - [代码块配置](#代码块配置)
  - [PDF 生成配置](#pdf-生成配置)
- [Summary 文件](#summary-文件)
  - [组织文档结构](#组织文档结构)
  - [指定 Summary 文件](#指定-summary-文件)
  - [支持的 Summary 内容](#支持的-summary-内容)
  - [草稿章节](#草稿章节)
  - [Homepage 内置样式](#homepage-内置样式)
  - [生成的文档结构](#生成的文档结构)

---

## 命令行选项

### render 命令

渲染 Markdown 文件/文件夹为网站、PDF 或合并 Markdown 格式。

| 选项 | 简写 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `--input` | `-i` | String | ✅ | - | 输入文件或目录路径 |
| `--output` | `-o` | String | ❌ | `./dist` | 输出目录路径 |
| `--config` | `-c` | String | ❌ | 自动查找 | markit.json 配置文件路径 |
| `--jobs` | `-j` | Number | ❌ | `1` | 并行渲染任务数（1=串行，>1=并行，0=自动检测CPU核心数） |

**使用示例：**
```bash
# 基本用法（串行渲染）
markit render --input ./docs --output ./dist

# 使用简写
markit render -i ./docs -o ./dist

# 指定配置文件
markit render -i ./docs -c ./markit.json

# 使用并行渲染（4个并发任务）
markit render -i ./docs -o ./dist -j 4

# 使用并行渲染（8个并发任务）
markit render -i ./docs -o ./dist -j 8
```

**性能提示：**
- 默认使用串行渲染（`-j 1`），适合小型项目
- 对于大型项目（10+ 文件），建议使用 `-j 4` 或 `-j 8` 提升性能
- 并发数建议不超过 CPU 核心数
- 实际性能提升取决于文件数量、大小和 I/O 性能

---

### serve 命令

启动 HTTP 服务器进行 Markdown 预览，支持自动渲染和热重载。

| 选项 | 简写 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `--input` | `-i` | String | ✅ | - | 输入文件或目录路径 |
| `--output` | `-o` | String | ❌ | `./dist` | 输出目录路径 |
| `--config` | `-c` | String | ❌ | 自动查找 | 配置文件路径（JSON 格式） |
| `--host` | `-H` | String | ❌ | `127.0.0.1` | HTTP 服务器绑定的 IP 地址（使用 `0.0.0.0` 允许局域网访问） |
| `--port` | `-p` | String | ❌ | `8080` | HTTP 服务器端口 |
| `--watch` | `-w` | String | ❌ | `true` | 启用文件监听（文件变化时自动重新渲染） |
| `--jobs` | `-j` | Number | ❌ | `1` | 并行渲染任务数（1=串行，>1=并行，0=自动检测CPU核心数） |

**使用示例：**
```bash
# 基本用法
markit serve --input ./docs

# 自定义端口和主机
markit serve -i ./docs -H 0.0.0.0 -p 3000

# 禁用文件监听
markit serve -i ./docs --watch false

# 使用并行渲染
markit serve -i ./docs -j 4
```

---

### help 命令

显示帮助信息。

| 选项 | 简写 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| 无选项 | - | - | - | - | 显示所有命令的帮助信息 |

**使用示例：**
```bash
markit help
```

---

### version 命令

显示版本信息。

| 选项 | 简写 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| 无选项 | - | - | - | - | 显示当前版本号 |

**使用示例：**
```bash
markit version
```

---

## 配置文件设置项

配置文件为 JSON 格式，默认文件名为 `markit.json`。

### 基础配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `title` | String | `"Documentation"` | 网站标题 |
| `theme` | String | `"arctic"` | 主题名称 |
| `format` | String | `"website"` | 输出格式：`"website"` 网站；`"pdf"` 单文件 PDF；`"markdown"` 输出 `merged.md` 与各单独 `.md`；`"typst"` 输出 `merged.typ` 与各单独 `.typ` |
| `toc` | Boolean | `false` | 是否启用目录。对于 `pdf` / `typst`，会在 `merged.typ` 中插入目录页；`pdf` 下目录会出现在最终 `merged.pdf` 中 |

**配置示例：**
```json
{
  "title": "My Documentation",
  "theme": "arctic",
  "format": "website",
  "toc": true
}
```

---

### i18n 配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `i18n.default` | String | `"en"` | 默认语言（用于未标记语言的内容） |
| `i18n.target` | String | `"en"` | 目标语言（用于编译时筛选） |
| `i18n.home` | String | `"Home"` | "首页"/"Home"的翻译文本 |
| `i18n.documentation` | String | `"Documentation"` | "文档"/"Documentation"的翻译文本 |

**配置示例：**
```json
{
  "i18n": {
    "default": "zh",
    "target": "zh",
    "home": "首页",
    "documentation": "文档"
  }
}
```

---

### 列表配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `list.orderedList.multiLevel` | Boolean | `true` | 是否启用多层级有序列表样式<br>启用后：第一层显示阿拉伯数字，第二层显示阿拉伯数字，第三层显示英文字母 |

**配置示例：**
```json
{
  "list": {
    "orderedList": {
      "multiLevel": true
    }
  }
}
```

---

### 代码块配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `codeBlock.group` | Boolean | `false` | 是否启用代码块分组功能 |
| `codeBlock.enabled` | Boolean | `true` | 是否启用代码高亮 |
| `codeBlock.theme` | String | `""` | codehl 单主题名称。设置后浅色/深色代码块都使用该主题 |
| `codeBlock.lightTheme` | String | `"light-plus"` | codehl 浅色代码高亮主题名称 |
| `codeBlock.darkTheme` | String | `"dark-plus"` | codehl 深色代码高亮主题名称 |
| `codeBlock.grammarDirs` | Array<String> | `[]` | 用户 TextMate grammar 搜索目录。相对路径按 `markit.json` 所在目录解析，优先级高于内置 grammar 目录 |
| `codeBlock.themeDirs` | Array<String> | `[]` | 额外 codehl 主题搜索目录，按配置顺序优先于内置目录。相对路径按 `markit.json` 所在目录解析 |
| `codeBlock.languages` | Object | `{}` | 注册额外语言到指定 grammar 文件的映射 |
| `codeBlock.aliases` | Object | `{}` | 注册语言别名 |

`codeBlock.theme` 配置代码高亮单主题，设置后浅色/深色代码块都使用同一个高亮主题。

需要分别配置浅色/深色代码高亮时，使用 `codeBlock.lightTheme` / `codeBlock.darkTheme`。

Markit 会扫描用户 `grammarDirs` 和内置 grammar 目录中的 JSON，并按文件名、`name`、`scopeName`、`fileTypes` 自动发现语言。显式 `languages` / `aliases` 优先级最高，其次是用户 grammar 目录，最后是内置 grammar 目录。

`languages` 的值可以直接写 grammar 文件名，也可以写包含 `grammar` 和 `aliases` 的对象。grammar/theme JSON 仅用于渲染 Markdown，生成的网站只包含渲染后的页面资源。

**配置示例：**
```json
{
  "codeBlock": {
    "enabled": true,
    "group": false,
    "grammarDirs": ["./grammars"],
    "themeDirs": ["./code-themes"],
    "lightTheme": "light-plus",
    "darkTheme": "dark-plus",
    "languages": {
      "vue": "vue.tmLanguage.json",
      "astro": {
        "grammar": "astro.tmLanguage.json",
        "aliases": ["astrojs"]
      }
    },
    "aliases": {
      "fish": "bash",
      "zsh": "bash"
    }
  }
}
```

常用内置别名：

| 别名 | 语言 |
|------|------|
| `cj` | `cangjie` |
| `js` / `mjs` / `cjs` | `javascript` |
| `jsx` | `javascriptreact` |
| `ts` | `typescript` |
| `tsx` | `typescriptreact` |
| `md` | `markdown` |
| `sh` / `shell` / `shellscript` / `zsh` / `fish` / `ksh` | `bash` |
| `yml` | `yaml` |

---

### 表格配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `table.threeLine` | Boolean | `false` | 是否启用三线表语法识别。启用后，仅当表格前后都紧邻 Markdown 分割线 `---` 时，该表格会按三线表渲染；否则仍按普通分割线 + 普通表格处理 |

**语法说明：**
- 该能力需要先在配置中开启 `table.threeLine`
- 识别模式为“分割线 + 表格 + 分割线”
- 分割线必须是纯 `-` 组成，且不少于 3 个字符
- 如果未开启配置，同样的写法会回退为普通分割线和普通表格，不改变原有 Markdown 语义

**配置示例：**
```json
{
  "table": {
    "threeLine": true
  }
}
```

**Markdown 示例：**
```markdown
---
| Block | Expectation |
|---|---|
| Paragraph | Reasonable spacing |
| Code | Visually separated |
---
```

---

### 标题编号配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `heading.closable` | Boolean | `true` | 可关闭标题配置<br>当标题以 `##` 结尾时（如 `## Section ##`），该标题及其下所有内容将被移除 |
| `heading.number.enabled` | Boolean | `false` | 是否启用标题编号 |
| `heading.number.resetFor` | String | `"always"` | 标题编号重置策略：<br>- `"never"`: 从不重置，跨所有文件连续编号<br>- `"directory"`: 在切换目录时重置编号<br>- `"always"`: 每个文件都重置编号 |
| `heading.number.startFrom` | Array\<Int\> | `[1, 1, 1, 1, 1, 1]` | 编号起始值（6个级别） |

**配置示例：**
```json
{
  "heading": {
    "closable": true,
    "number": {
      "enabled": true,
      "resetFor": "directory",
      "startFrom": [1, 1, 1, 1, 1, 1]
    }
  }
}
```

---

### Summary 配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `summary.file` | String | `"markit.md"` | Summary 文件名 |
| `summary.showDrafts` | Boolean | `true` | 是否显示草稿章节 |

**`homepage` 行为说明：**
- `markit.md` 中 `<!-- homepage -->` 之后的内容会被识别为 homepage
- 网站模式下，homepage 会作为站点首页内容
- PDF 模式下，`pdf.typst.cover` 会先渲染模板封面；若定义了 homepage，则 homepage 会继续作为封面后的前置页插入在目录页之前
- 如果未定义 `homepage`，则 PDF 直接从目录页或正文开始

**配置示例：**
```json
{
  "summary": {
    "file": "markit.md",
    "showDrafts": false
  }
}
```

---

### 章节导航配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `website.chapter.navigation` | Boolean | `false` | 是否启用章节导航（上一篇/下一篇） |
| `website.chapter.prevText` | String | `"Previous"` | "上一篇"的文本 |
| `website.chapter.nextText` | String | `"Next"` | "下一篇"的文本 |

**配置示例：**
```json
{
  "website": {
    "chapter": {
      "navigation": true,
      "prevText": "上一篇",
      "nextText": "下一篇"
    }
  }
}
```

---

### 文章统计配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `website.statistic.totalTexts` | Boolean | `false` | 是否显示总字数 |
| `website.statistic.totalTextsTemplate` | String | `"{total} words"` | 总字数模板，`{total}` 会被替换为实际字数 |
| `website.statistic.spentTime` | Boolean | `false` | 是否显示预计阅读时间 |
| `website.statistic.spentTimeTemplate` | String | `"{total} {unit} read"` | 预计阅读时间模板<br>`{total}` 会被替换为时间数字<br>`{unit}` 会被替换为单位 |
| `website.statistic.second` | String | `"sec"` | 秒的单位文本 |
| `website.statistic.minute` | String | `"min"` | 分钟的单位文本 |

**配置示例：**
```json
{
  "website": {
    "statistic": {
      "totalTexts": true,
      "totalTextsTemplate": "共 {total} 字",
      "spentTime": true,
      "spentTimeTemplate": "预计阅读 {total} {unit}",
      "second": "秒",
      "minute": "分钟"
    }
  }
}
```

---

### Git 配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `website.git.prefix` | String | `""` | Git 仓库前缀 URL |

**配置示例：**
```json
{
  "website": {
    "git": {
      "prefix": "https://github.com/username/repo"
    }
  }
}
```

---

### 仓库链接配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `website.repos.github` | String | `""` | GitHub 仓库 URL，配置后在导航栏显示 GitHub 图标按钮 |
| `website.repos.gitcode` | String | `""` | GitCode 仓库 URL，配置后在导航栏显示 GitCode 图标按钮 |
| `website.repos.gitee` | String | `""` | Gitee 仓库 URL，配置后在导航栏显示 Gitee 图标按钮 |
| `website.repos.gitlab` | String | `""` | GitLab 仓库 URL，配置后在导航栏显示 GitLab 图标按钮 |

**配置示例：**
```json
{
  "website": {
    "repos": {
      "github": "https://github.com/username/repo",
      "gitcode": "https://gitcode.com/username/repo",
      "gitee": "https://gitee.com/username/repo",
      "gitlab": "https://gitlab.com/username/repo"
    }
  }
}
```

> 可以只配置部分平台，未配置的平台不会显示按钮。

---

### 静态资源配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `website.assets.styles` | Array\<String\> | `[]` | CSS 文件列表，支持 HTTP/HTTPS URL 和相对路径 |
| `website.assets.scripts` | Array\<String\> | `[]` | JavaScript 文件列表，支持 HTTP/HTTPS URL 和相对路径 |

**路径说明：**
- **HTTP/HTTPS URL**：直接使用，如 `https://cdn.example.com/style.css`
- **相对路径**：自动映射到 `public/` 目录，如 `styles/custom.css` 会被解析为 `public/styles/custom.css`

**配置示例：**
```json
{
  "website": {
    "assets": {
      "styles": [
        "https://cdn.jsdelivr.net/npm/package@1.0.0/style.css",
        "styles/custom.css"
      ],
      "scripts": [
        "https://cdn.jsdelivr.net/npm/package@1.0.0/script.js",
        "scripts/analytics.js"
      ]
    }
  }
}
```

**注意事项：**
1. 相对路径的资源文件需要放在输入目录的 `public/` 文件夹中
2. 构建时会自动将 `public/` 目录复制到输出目录
3. 每个页面会根据其深度自动计算正确的相对路径
4. 自定义资源会被注入到所有页面（包括网站页面、PDF页面和索引页面）

---

### 构建期渲染能力

Markit 在渲染 Markdown 时会尽量把可确定的富内容提前生成好，生成的网站页面只负责展示和主题切换：

| 内容 | 构建期实现 | 网站运行时 |
|------|------------|------------|
| 代码块高亮 | `codehl` 读取 TextMate grammar/theme JSON，生成浅色/深色 HTML | 不加载 Shiki |
| Mermaid 图表 | `mermaid4cj` 生成静态 SVG；网站输出可写入双主题 SVG | 不加载 Mermaid JS |
| 数学公式 | `mathtex` 生成 KaTeX-compatible HTML + MathML | 不加载 KaTeX JS |
| PDF/Typst | 先生成 `.typ`，再调用 Typst CLI 编译 PDF | 需要本机可执行 `typst` |

KaTeX CSS 和字体仍作为静态资源复制到网站中，用于样式和字体显示；这不需要浏览器端 KaTeX JS。Mermaid 和代码高亮相关的 grammar/theme JSON 只在 `markit-cli render` 时读取，不会复制到生成的网站。

---

### PDF 生成配置

当前 `format: "pdf"` 默认走 Typst 渲染链路：先生成 `merged.typ`，再编译为 `merged.pdf`。  
因此 PDF 相关配置以 `pdf.typst.*` 为主；`toc: true` 时会在正文前插入目录页，如果 `markit.md` 中存在 `homepage`，则顺序为“封面模板 -> homepage -> 目录 -> 正文”。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `pdf.typst.pageNumber.enabled` | Boolean | `true` | 是否在 PDF 中显示页码 |
| `pdf.typst.pageNumber.position` | String | `"footer"` | 页码位置，可选值：`"header"`、`"footer"` |
| `pdf.typst.pageNumber.align` | String | `"right"` | 页码对齐方式，可选值：`"left"`、`"center"`、`"right"` |
| `pdf.typst.toc.maxLevel` | Int | `3` | PDF 目录页的最大标题级别，可选值：`1-6` |
| `pdf.typst.cover.enabled` | Boolean | `false` | 是否启用 PDF 封面模板 |
| `pdf.typst.cover.logo` | String | `""` | 封面 logo 路径，相对于输出目录解析 |
| `pdf.typst.cover.title` | String | `""` | 封面主标题；为空时回退为顶层 `title` |
| `pdf.typst.cover.subtitle` | String | `""` | 封面副标题 |
| `pdf.typst.cover.authors` | Array\<String\> | `[]` | 封面作者列表 |
| `pdf.typst.cover.version` | String | `""` | 封面 footer 中的版本号 |
| `pdf.typst.cover.organization` | String | `""` | 封面 footer 中的机构名 |
| `pdf.typst.cover.suborganization` | String | `""` | 封面 footer 中的子机构名 |
| `pdf.typst.code.useBundledSyntaxes` | Boolean | `true` | 是否自动加载仓库内置的 Typst syntax 定义（含 `cangjie`、`antlr4`） |
| `pdf.typst.code.useBundledTheme` | Boolean | `true` | 是否自动加载仓库内置的 Typst 代码高亮主题 |
| `pdf.typst.code.syntaxes` | Array\<String\> | `[]` | 额外的 `.sublime-syntax` 路径，相对于输出目录解析 |
| `pdf.typst.code.theme` | String | `""` | 自定义 `.tmTheme` 路径，相对于输出目录解析 |
| `pdf.typst.code.ligatures` | Boolean | `false` | 是否启用代码字体连字。默认关闭，避免部分符号组合为连字 |

### 网站输出设置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `website.code.ligatures` | Boolean | `false` | 网站输出中是否启用代码字体连字。默认关闭，避免部分符号组合为连字 |

**配置示例：**
```json
{
  "website": {
    "code": {
      "ligatures": true
    }
  }
}
```

---

**配置示例：**
```json
{
  "pdf": {
    "typst": {
      "toc": {
        "maxLevel": 4
      },
      "pageNumber": {
        "enabled": true,
        "position": "footer",
        "align": "center"
      },
      "cover": {
        "enabled": true,
        "logo": "assets/sample.svg",
        "title": "Markit Typst Example",
        "subtitle": "Reusable PDF cover template",
        "authors": ["Author A", "Author B"],
        "version": "v1.0.0",
        "organization": "Markit",
        "suborganization": "Docs Team"
      },
      "code": {
        "useBundledSyntaxes": true,
        "useBundledTheme": true,
        "syntaxes": [],
        "theme": "",
        "ligatures": false
      }
    }
  }
}
```

**补充说明：**
- PDF 模式始终生成一份 `merged.pdf`
- 同时会保留 `merged.typ` 以及各单独 `.typ` 文件，便于排查版式问题
- 如果 `toc: true`，目录页会根据最终文档标题结构自动生成
- `pdf.typst.toc.maxLevel` 只影响 PDF 目录页，不影响正文标题输出
- `pdf.typst.cover` 用于渲染模板化封面；如果同时定义了 homepage，则顺序为“封面模板 -> homepage -> 目录 -> 正文”
- 如果 `homepage` 中存在相对链接，在合并 PDF 中会被重写为页内跳转

---

## Summary 文件

Summary 文件用于声明文档站点的目录、章节顺序、侧边栏分组和首页内容。默认文件名是 `markit.md`，位于输入目录根路径下；渲染时该文件会作为控制文件解析，不会被当作普通章节输出。

当存在 Summary 文件时，markit-cli 只会按照 Summary 中引用的非草稿章节收集和渲染文档，输出顺序也以 Summary 为准。如果找不到 Summary 文件、文件为空、解析失败，或没有解析到有效章节，则回退为按文件系统顺序递归收集 Markdown 文件。

### 组织文档结构

推荐把 Summary 文件放在文档根目录，把具体文档按主题放入子目录：

```text
docs/
├── markit.json
├── markit.md
├── README.md
├── getting-started/
│   ├── installation.md
│   └── quick-start.md
├── guides/
│   ├── configuration.md
│   └── deployment.md
└── api/
    └── markit-config.md
```

对应的 `markit.md` 可以这样组织：

```markdown
- [概览](README.md)

# 入门

- [安装](getting-started/installation.md)
- [快速开始](getting-started/quick-start.md)

# 指南

- [配置](guides/configuration.md)
- [部署](guides/deployment.md)

# API

- [MarkitConfig](api/markit-config.md)
- [计划中的 API]()
```

一级标题会成为侧边栏分组，列表链接会成为章节。出现在第一个一级标题之前的链接会作为根级章节显示在分组之前。

**特别注意：Summary 导航只识别一级标题 `#` 作为分组。二级及更深标题（`##`、`###` 等）不会创建子分组，也不会改变后续列表的归属。**

### 指定 Summary 文件

默认情况下，markit-cli 会在输入根目录查找 `markit.md`。可以通过 `markit.json` 的 `summary.file` 改用其他文件名：

```json
{
  "summary": {
    "file": "SUMMARY.md",
    "showDrafts": false
  }
}
```

字段说明：

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `summary.file` | `"markit.md"` | Summary 文件名，相对于当前语言的输入根目录解析 |
| `summary.showDrafts` | `true` | 是否在网站侧边栏中显示草稿章节 |

`summary.file` 始终相对于当前输入目录解析；多语言构建时，则相对于每种语言的输入目录解析。

### 支持的 Summary 内容

Summary 文件本身使用 Markdown 编写，但导航解析只消费其中的目录相关结构：

| 内容 | 写法 | 行为 |
|------|------|------|
| 根级章节 | `[概览](README.md)` 或 `- [概览](README.md)` | 显示在所有分组之前 |
| 分组 | `# 入门` | 创建侧边栏分组 |
| 二级及更深标题 | `## 基础`、`### 安装` | 不参与导航结构解析，不会创建二级分组 |
| 分组章节 | 分组标题后的无序列表链接 | 作为该分组下的章节 |
| 子章节 | 嵌套无序列表 | 生成嵌套导航，并按深度递归收集文件 |
| 草稿章节 | `- [未来章节]()` | 不渲染文件；`summary.showDrafts: true` 时仅在侧边栏显示草稿标题 |
| 首页内容 | `<!-- homepage -->` 后的 Markdown / HTML | 作为网站首页内容；PDF/Typst 合并输出中作为前置页 |
| 多语言内容 | i18n 行内或块级语法 | 根据 `i18n.target` 选择当前语言内容 |

示例：

```markdown
- [:zh{概览}: :en{Overview}:](README.md)
- [路线图]()

# :zh{入门}: :en{Getting Started}:

- [安装](getting-started/installation.md)
- [快速开始](getting-started/quick-start.md)
  - [项目结构](getting-started/project-layout.md)

<!-- homepage -->

# :zh{欢迎使用 Markit}: :en{Welcome to Markit}:

:::zh
这里是中文首页内容。
:::

:::en
This is the English homepage content.
:::
```

注意事项：

1. **只有一级标题 `#` 会创建分组；`##`、`###` 等标题会被导航解析忽略。** 如果这些标题后面跟着列表，列表仍归属于当前一级分组；如果前面没有一级分组，则作为根级章节。
2. 导航列表只支持无序列表；普通段落中的第一个链接也可作为根级章节。
3. 列表项中没有链接，或链接文本为空时会被忽略。
4. Summary 中引用但不存在的文件会打印警告并跳过。
5. `<!-- homepage -->` 之后的内容都属于首页，不再参与导航解析。
6. 如果没有 `homepage` 内容，网站模式会尝试使用第一个非草稿根级章节作为首页后备；分组内章节不会自动成为首页。

### 草稿章节

草稿章节使用空链接编写，也就是链接文本存在，但链接目标为空：

```markdown
- [已发布章节](guides/released.md)
- [计划中的章节]()

# API

- [稳定 API](api/stable.md)
- [实验 API]()
```

草稿章节的行为：

1. `- [计划中的章节]()` 会被识别为草稿章节。
2. 草稿章节不会被收集为输入文件，也不会生成对应页面。
3. `summary.showDrafts: true` 时，草稿会以不可点击的灰色条目显示在网站侧边栏中。
4. `summary.showDrafts: false` 时，草稿不会显示在侧边栏中。
5. 草稿章节不会进入上一篇/下一篇章节导航。
6. 如果把正式章节嵌套在草稿父项下面，整棵子树都不会被收集和渲染。

如果只是想做一个包含多个正式章节的分组，请使用一级标题：

```markdown
# 计划中

- [阶段一](roadmap/phase-1.md)
- [阶段二](roadmap/phase-2.md)
```

### Homepage 内置样式

当 Summary 文件中存在 `<!-- homepage -->` 后的首页内容时，网站模式会给首页的 `<body>` 自动添加 `homepage` 类。该模式会隐藏侧边栏和侧边栏开关，居中首页内容，并应用首页背景和标题装饰。

Arctic 主题还提供了适合 homepage 使用的按钮和卡片样式，可以在 `<!-- homepage -->` 之后直接使用 HTML：

| 类名 | 用途 |
|------|------|
| `.btn` | 基础按钮 |
| `.btn-primary`、`.btn-secondary`、`.btn-danger` | 实心按钮变体 |
| `.btn-outline-primary`、`.btn-outline-secondary`、`.btn-outline-danger` | 描边按钮变体 |
| `.btn-sm`、`.btn-lg`、`.btn-block` | 按钮尺寸和块级按钮 |
| `.card` | 基础卡片 |
| `.card-primary`、`.card-secondary` | 卡片变体 |
| `.card-title`、`.card-body`、`.card-footer` | 卡片内部结构 |
| `.card-grid`、`.card-grid-2`、`.card-grid-3` | 响应式卡片网格 |
| `.card-icon` | 卡片图标区域 |
| `.card-link` | 可点击卡片容器 |

示例：

```markdown
<!-- homepage -->

# 欢迎使用我的文档

这里是首页介绍内容。

<center>
    <a class="btn btn-lg btn-primary" href="./getting-started/quick-start.html">快速开始</a>
    <a class="btn btn-lg btn-outline-secondary" href="https://example.com">项目仓库</a>
</center>

## 特性

<div class="card-grid-2">
    <a class="card-link" href="./getting-started/quick-start.html">
        <div class="card card-primary">
            <div class="card-title">快速上手</div>
            <div class="card-body">从安装到第一个文档站点的完整流程。</div>
        </div>
    </a>

    <a class="card-link" href="./guides/configuration.html">
        <div class="card card-secondary">
            <div class="card-title">配置指南</div>
            <div class="card-body">了解主题、导航、PDF、静态资源等配置。</div>
        </div>
    </a>
</div>
```

这些样式主要面向网站首页。PDF/Typst 输出会保留 homepage 内容，但 HTML 类名不会变成 PDF 专用排版能力；如果需要精细 PDF 封面，优先使用 `pdf.typst.cover`。

### 生成的文档结构

网站模式会保持源文件的相对目录结构，并把 `.md` / `.markdown` 转换为 `.html`。单语言构建也会使用语言目录，目录名来自 `i18n.target`：

```text
dist/
├── index.html              # 语言入口页
├── assets/                 # 主题 CSS、JS、字体、favicon 等共享资源
├── public/                 # 从 docs/public/ 复制的用户静态资源（如果存在）
└── zh/
    ├── index.html          # Summary homepage，或第一个非草稿根级章节后备
    ├── README.html
    ├── getting-started/
    │   ├── index.html      # 文件夹索引页
    │   ├── installation.html
    │   └── quick-start.html
    ├── guides/
    │   ├── index.html
    │   ├── configuration.html
    │   └── deployment.html
    ├── api/
    │   ├── index.html
    │   └── markit-config.html
    └── js/
        └── search-index.js
```

其他输出格式也会遵循 Summary 的章节顺序：

| `format` | 主要输出 |
|----------|----------|
| `"website"` | 每个章节一个 HTML 页面，保留相对目录结构，并生成首页、目录导航和搜索索引 |
| `"markdown"` | 每个章节一个 `.md` 文件，同时生成 `merged.md` |
| `"typst"` | 每个章节一个 `.typ` 文件，同时生成 `merged.typ` |
| `"pdf"` | 先生成 `merged.typ`，再生成 `merged.pdf`；若定义了 homepage，会作为封面模板后的前置页 |

`"markdown"`、`"typst"` 和 `"pdf"` 目前只支持单配置文件构建，输出位于 `<output>/<i18n.target>/`；PDF/Typst 所需的共享字体和 Typst 支持资源会复制到 `<output>/assets/`。

---

## 完整配置示例

```json
{
  "title": "我的文档",
  "theme": "arctic",
  "format": "website",
  "toc": true,
  
  "list": {
    "orderedList": {
      "multiLevel": true
    }
  },
  
  "codeBlock": {
    "group": false,
    "enabled": true,
    "grammarDirs": [],
    "themeDirs": [],
    "lightTheme": "light-plus",
    "darkTheme": "dark-plus",
    "aliases": {
      "fish": "bash"
    }
  },
  
  "i18n": {
    "default": "zh",
    "target": "zh",
    "home": "首页",
    "documentation": "文档"
  },
  
  "heading": {
    "closable": true,
    "number": {
      "enabled": true,
      "resetFor": "directory",
      "startFrom": [1, 1, 1, 1, 1, 1]
    }
  },
  
  "summary": {
    "file": "markit.md",
    "showDrafts": false
  },

  "pdf": {
    "typst": {
      "toc": {
        "maxLevel": 4
      },
      "pageNumber": {
        "enabled": true,
        "position": "footer",
        "align": "center"
      },
      "cover": {
        "enabled": true,
        "logo": "assets/sample.svg",
        "title": "Markit Typst Example",
        "subtitle": "Reusable PDF cover template",
        "authors": ["Author A", "Author B"],
        "version": "v1.0.0",
        "organization": "Markit",
        "suborganization": "Docs Team"
      },
      "code": {
        "useBundledSyntaxes": true,
        "useBundledTheme": true,
        "syntaxes": [],
        "theme": "",
        "ligatures": false
      }
    }
  },

  "website": {
    "code": {
      "ligatures": false
    },
    "chapter": {
      "navigation": true,
      "prevText": "上一篇",
      "nextText": "下一篇"
    },
    "statistic": {
      "totalTexts": true,
      "totalTextsTemplate": "共 {total} 字",
      "spentTime": true,
      "spentTimeTemplate": "预计阅读 {total} {unit}",
      "second": "秒",
      "minute": "分钟"
    },
    "git": {
      "prefix": "https://github.com/username/repo"
    },
    "repos": {
      "github": "https://github.com/username/repo",
      "gitcode": "https://gitcode.com/username/repo",
      "gitee": "https://gitee.com/username/repo",
      "gitlab": "https://gitlab.com/username/repo"
    },
    "assets": {
      "styles": [
        "https://cdn.jsdelivr.net/npm/custom-theme@1.0.0/style.css",
        "styles/custom.css"
      ],
      "scripts": [
        "https://cdn.jsdelivr.net/npm/analytics@1.0.0/script.js",
        "scripts/custom.js"
      ]
    }
  }
  }
}
```

---

## 注意事项

1. **配置文件查找顺序**：
   - 如果使用 `--config` 选项指定了配置文件，则使用指定的文件
   - 否则，在输入目录中自动查找 `markit.json`
   - 如果找不到配置文件，使用默认配置

2. **语言代码验证**：
   - `i18n.default` 和 `i18n.target` 必须是有效的语言标识符
   - 支持的语言代码格式：ISO 639-1 标准（如 `en`, `zh`, `ja` 等）

3. **输出格式限制**：
   - `format` 可为 `"website"`、`"pdf"`、`"markdown"` 或 `"typst"`
   - PDF 模式下某些功能可能不可用（如热重载）

4. **主题名称**：
   - 当前支持的主题：`arctic`
   - 主题文件位于 `markit-kit/assets/themes/` 目录

5. **端口占用**：
   - 如果指定的端口已被占用，serve 命令会失败
   - 建议使用 1024 以上的端口号

6. **文件监听**：
   - 文件监听功能仅在 `serve` 命令中可用
   - 监听范围包括输入目录中的所有 Markdown 文件和配置文件
