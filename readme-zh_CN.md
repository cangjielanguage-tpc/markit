# Markit

[![许可证](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![语言](https://img.shields.io/badge/language-Cangjie-orange.svg)](https://cangjie-lang.cn/)
[![平台](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)](#预构建二进制)

Markit 是一套使用仓颉编写的 Markdown 解析、渲染与发布工具。它提供基于 session 的 Markdown 内核，以及面向文档站、PDF、Typst 和本地实时预览的命令行工具。

![Markit CLI](https://raw.gitcode.com/zichexuelan/markit/files/main/assets/markit-cli.png)

## 功能特性

- 支持 CommonMark、GFM、国际化、表格、脚注、引用和目录
- 支持 Website、Markdown、Typst 和 PDF 输出
- 构建期完成仓颉/TextMate 代码高亮、TeX 数学公式和 Mermaid SVG 渲染
- `serve` 集成 `live-server`，支持文件监听和热重载
- 支持批量渲染、导航与主题配置、搜索索引和静态资源
- 提供适合流式和 AI 输出 Markdown 的增量/session API

## 项目结构

| 模块 | 说明 |
| --- | --- |
| [`markit`](markit/) | Markdown 解析与渲染内核 |
| [`markit-cli`](markit-cli/) | 渲染、预览服务和构建命令行工具 |
| [`markit-kit`](markit-kit/) | CLI/runtime 共用工具和资源 |
| [`codehl`](codehl/) | 构建期 TextMate 语法高亮 |
| [`mathtex`](mathtex/) | TeX 转 HTML、MathML 和 Typst |
| [`mermaid4cj`](mermaid4cj/) | 构建期 Mermaid 图表渲染 |
| [`commandline`](commandline/) | 声明式仓颉 CLI 框架 |
| [`fswatch`](fswatch/) | 跨平台文件监听 |
| [`live-server`](live-server/) | `markit-cli serve` 使用的本地 HTTP 服务 |
| [`dochir`](dochir/) | 仓颉 API 文档生成器 |

## 快速开始

安装仓颉 SDK（1.3.0-alpha 或更新版本），在仓库根目录执行：

```bash
cd markit-cli
cjpm build
```

可执行文件和运行资源位于 `markit-cli/target/release/bin/`：

```bash
./target/release/bin/main --help
./target/release/bin/main render -i ../docs -o ../target/site
./target/release/bin/main serve -i ../docs
```

命令和配置详见 [`markit-cli/README.md`](markit-cli/README.md) 与 [`markit-cli/documentation.md`](markit-cli/documentation.md)。

## 预构建二进制

带标签的发布版本提供 Linux x64、macOS x64、macOS arm64 和 Windows x64 压缩包。每个压缩包都包含 `markit` 可执行文件及所需的 `assets` 目录，请从 [Releases 页面](https://github.com/zichexuelan/markit/releases) 下载。

## 文档与许可证

- [用户文档](docs/markit.md)
- [库结构说明](docs/libraries/project-map.md)
- [API 参考](docs/api-reference/README.md)
- 本项目采用 [Apache License 2.0 许可证](LICENSE)。
