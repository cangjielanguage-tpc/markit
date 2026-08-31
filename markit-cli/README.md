# Markit CLI

> 基于 Markit v2 的 Markdown 渲染命令行工具，支持文件转换、站点生成、PDF/Typst 输出和 HTTP 预览服务。

## 🚀 功能特性

- **渲染转换**: 支持 Markdown 文件转换为 Website/PDF/Markdown/Typst/... 格式
- **HTTP预览**: 内置HTTP服务器，支持实时预览
- **文件监控/热重载**: 自动检测文件变化并实时渲染
- **multi tab代码块，全网最好的 Cangjie 代码高亮支持**
- **高性能，支持并行转换**
- **新版解析内核**: 使用 Markit v2 session-based parser，不要求 core 兼容旧 CLI API
- **AI Markdown 解析基础**: 底层 parser 支持 chunk feed、byte-safe UTF-8、HTML fragment 和 AST patch，适合后续 watch/serve 中做更细粒度增量预览

## Markit v2 集成方式

CLI 侧通过配置构造 parser，不再伸进 `PluginRegistry` 修改插件实例状态：

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

这让 CLI 可以独立处理 FileTree、HeadingInfo、RenderMode、heading numbering 和 i18n 配置，同时保持 `markit` core 干净可插拔。

## 📖 使用说明

[📖完整命令行选项和配置项文档](documentation.md)

## 预构建二进制文件

可以前往 release 页面进行下载不同平台的可执行文件。

shell:
```bash
export PATH=path/to/markit-cli:$PATH
markit -v
```

## 构建 markit-cli

环境要求：

1. Cangjie SDK 1.1.0+
2. Nodejs 20+

```bash
git clone https://gitcode.com/zichexuelan/markit.git
cd markit-cli
# 构建项目
cjpm build

cp ./target/release/bin/main ./markit

./markit -v
```
> assets 和 scripts 脚本需要和 markit-cli 二进制放在同一目录

### 渲染 markit

将 Markdown 文件转换为各种格式：

```bash
# 转换单个文件
./markit render -i input.md -o output

# 转换目录（会自动读取 markit.json）
./markit render -i ./docs -o ./output

# 多语言
./markit render -i ./docs -o ./output -c=path/to/markit.json,path/to/markit-en.json
```

### serve 命令

启动HTTP预览服务器：

```bash
# 基本用法
./markit serve -i ./docs

# 自定义主机和端口
./markit serve -i ./docs -H 0.0.0.0 -p 3000

# 文件监控默认开启
./markit serve -i ./docs -w false
```

## ⚙️ 命令参数

### render 命令参数

- `-i, --input`: 输入文件或目录 (必需)
- `-o, --output`: 输出路径 (默认: ./processed)
- 输出格式通过 `markit.json` 中的 `format` 指定，支持 `website` / `pdf` / `markdown` / `typst`

### serve 命令参数

- `-i, --input`: 输入文件或目录 (必需)
- `-H, --host`: 服务器主机 (默认: 127.0.0.1)
- `-p, --port`: 服务器端口 (默认: 8080)
- `-w, --watch`: 启用文件监控 (默认: true)
- `serve` 仅用于 `website` 模式

## 📄 许可证

Apache License 2.0
