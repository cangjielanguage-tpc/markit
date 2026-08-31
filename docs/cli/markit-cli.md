<a id="markit-cli"></a>
# markit-cli

`markit-cli` 是 Markit 项目的命令行入口，用于把 Markdown 文档渲染为静态网站、PDF、Typst 或合并后的 Markdown。它负责文件扫描、Summary 导航、主题模板、搜索索引、静态资源、预览服务和热重载；底层解析、代码高亮、数学公式和 Mermaid 图表由 Markit 项目中的各个库完成。

## 安装与运行

从 release 下载对应平台的预构建二进制后，把可执行文件所在目录加入 `PATH`：

```bash
export PATH=/path/to/markit-cli:$PATH
markit -v
```

从源码构建：

```bash
git clone https://gitcode.com/zichexuelan/markit.git
cd markit/markit-cli
cjpm build
cp ./target/release/bin/main ./markit
./markit -v
```

二进制文件需要与 `assets`、渲染脚本和主题资源保持同级部署。源码构建后如果要移动可执行文件，请同时移动 `markit-cli/assets` 中的运行资源。

## render

`render` 用于把单个 Markdown 文件或一个文档目录转换为目标格式。目录模式会自动读取输入目录下的 `markit.json`；也可以用 `--config` 指定配置文件。

```bash
markit render -i ./docs -o ./dist
markit render --input ./docs --output ./dist
markit render -i ./docs -o ./dist -c ./docs/markit.json
markit render -i ./docs -o ./dist -j 4
```

常用参数：

| 参数 | 简写 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `--input` | `-i` | 必填 | 输入文件或目录 |
| `--output` | `-o` | `./dist` | 输出目录 |
| `--config` | `-c` | 自动查找 | JSON 配置文件路径 |
| `--jobs` | `-j` | `1` | 并行渲染任务数；`0` 表示自动使用 CPU 核心数 |

输出格式由 `markit.json` 的 `format` 字段控制：

| format | 输出 |
| --- | --- |
| `website` | 静态网站页面、首页、导航、搜索索引和主题资源 |
| `pdf` | `merged.pdf`，并保留 Typst 中间文件 |
| `typst` | 每个章节的 `.typ` 与合并后的 `merged.typ` |
| `markdown` | 每个章节的规范化 Markdown 与合并后的 `merged.md` |

## serve

`serve` 用于本地预览网站输出。启动后会先渲染文档，再提供 HTTP 服务；开启 watch 时，Markdown 和配置文件变化会触发重新渲染。

```bash
markit serve -i ./docs
markit serve -i ./docs -H 0.0.0.0 -p 3000
markit serve -i ./docs --watch false
markit serve -i ./docs -j 4
```

常用参数：

| 参数 | 简写 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `--input` | `-i` | 必填 | 文档源目录 |
| `--output` | `-o` | `./dist` | 临时渲染输出目录 |
| `--config` | `-c` | 自动查找 | JSON 配置文件路径 |
| `--host` | `-H` | `127.0.0.1` | 服务绑定地址 |
| `--port` | `-p` | `8080` | 服务端口 |
| `--watch` | `-w` | `true` | 是否监听文件变化 |
| `--jobs` | `-j` | `1` | 并行渲染任务数 |

`serve` 面向 `website` 输出。PDF、Typst 和 Markdown 合并输出请使用 `render`。

## 文档目录约定

一个典型文档目录包含：

```text
docs/
├── markit.json
├── markit.md
├── getting-started/
│   └── quick-start.md
└── guides/
    └── configuration.md
```

`markit.json` 定义站点标题、主题、输出格式、导航、代码块、PDF、统计信息等配置。`markit.md` 是 Summary 文件，负责侧边栏章节顺序和首页内容。

```json
{
  "title": "My Docs",
  "theme": "arctic",
  "format": "website",
  "toc": true,
  "summary": {
    "file": "markit.md",
    "showDrafts": false
  }
}
```

Summary 使用一级标题作为侧边栏分组，列表链接作为章节：

```markdown
- [概览](README.md)

# 入门

- [快速开始](getting-started/quick-start.md)
- [配置](guides/configuration.md)

<!-- homepage -->

# My Docs

这里是网站首页内容。
```

`<!-- homepage -->` 之后的内容会成为网站首页；它不会作为普通章节出现在侧边栏。

## 配置入口

常用配置项：

| 配置 | 说明 |
| --- | --- |
| `title` | 网站或输出文档标题 |
| `theme` | 网站主题，内置 `arctic` |
| `format` | `website`、`pdf`、`typst`、`markdown` |
| `toc` | 是否生成目录 |
| `i18n.default` / `i18n.target` | 默认语言与目标语言 |
| `heading.number.enabled` | 是否启用标题编号 |
| `codeBlock.enabled` | 是否启用构建期代码高亮 |
| `codeBlock.group` | 是否启用多标签代码块 |
| `list.autoAnchor` / `codeBlock.autoAnchor` | 是否为列表项和代码块生成可复制引用的锚点 |
| `math.autoAnchor` / `table.autoAnchor` | 是否为块级数学公式和表格生成可复制引用的锚点 |
| `table.threeLine` | 是否识别三线表 |
| `website.chapter.navigation` | 是否启用上一篇/下一篇 |
| `website.statistic` | 字数与阅读时间统计 |
| `pdf.typst` | PDF/Typst 封面、页码、目录和代码高亮配置 |

完整配置项见 [markit-cli 配置参考](../reference/markit-cli-config.md)。

## 构建期富内容

markit-cli 在构建阶段处理常见富内容：

- 代码块由 `codehl` 读取 TextMate grammar 和主题生成 HTML，不需要浏览器端 Shiki。
- 数学公式由 `mathtex` 输出 KaTeX-compatible HTML、MathML 或 Typst。
- Mermaid 图表由 `mermaid4cj` 输出静态 SVG，不需要浏览器端 Mermaid JS。
- PDF 通过 Typst 管线生成，网站和 PDF 可以共享同一份 Markdown 源内容。

这些能力让生成的网站更轻，也让 PDF/Typst 输出与网页输出保持同源。
