# Markit

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Language](https://img.shields.io/badge/language-Cangjie-orange.svg)](https://cangjie-lang.cn/)
[![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)](#prebuilt-binaries)

Markit is a Cangjie toolkit for parsing, rendering, and publishing Markdown. It combines a session-based Markdown engine with a production CLI for websites, PDF, Typst, and local live preview workflows.

![Markit CLI](https://raw.gitcode.com/zichexuelan/markit/files/main/assets/markit-cli.png)

## Features

- CommonMark, GFM, i18n, tables, footnotes, references, and TOC support
- Website, Markdown, Typst, and PDF output
- Build-time Cangjie/TextMate code highlighting, TeX math, and Mermaid SVG rendering
- `serve` command with `live-server`, file watching, and hot reload
- Batch rendering, configurable navigation, themes, search indexes, and static assets
- Incremental/session APIs for streaming and AI-generated Markdown

## Project Structure

| Package | Purpose |
| --- | --- |
| [`markit`](markit/) | Markdown parsing and rendering engine |
| [`markit-cli`](markit-cli/) | End-user renderer, preview server, and build tool |
| [`markit-kit`](markit-kit/) | Shared CLI/runtime utilities and bundled assets |
| [`codehl`](codehl/) | Build-time TextMate grammar code highlighting |
| [`mathtex`](mathtex/) | TeX math to HTML, MathML, and Typst |
| [`mermaid4cj`](mermaid4cj/) | Build-time Mermaid diagram renderer |
| [`commandline`](commandline/) | Declarative Cangjie CLI framework |
| [`fswatch`](fswatch/) | Cross-platform file-system watching |
| [`live-server`](live-server/) | Local static HTTP server used by `markit-cli serve` |
| [`dochir`](dochir/) | Cangjie API documentation generator |

## Quick Start

Install a Cangjie SDK (1.3.0-alpha or newer), then build the CLI from the repository root:

```bash
cd markit-cli
cjpm build
```

The executable and its runtime assets are produced under `markit-cli/target/release/bin/`:

```bash
./target/release/bin/main --help
./target/release/bin/main render -i ../docs -o ../target/site
./target/release/bin/main serve -i ../docs
```

See [`markit-cli/README.md`](markit-cli/README.md) and [`markit-cli/documentation.md`](markit-cli/documentation.md) for commands and configuration.

## Prebuilt Binaries

Tagged releases publish archives for Linux x64, macOS x64, macOS arm64, and Windows x64. Each archive contains the `markit` executable and the required `assets` directory. Download them from the [Releases page](https://github.com/zichexuelan/markit/releases).

## Documentation

- [User documentation](docs/markit.md)
- [Library map](docs/libraries/project-map.md)
- [API reference](docs/api-reference/README.md)
- [Chinese README](readme-zh_CN.md)

## License

Markit is released under the [Apache License 2.0](LICENSE).
