# markit_kit

`markit_kit` 是 Markit 的文档构建工具库，供仓颉程序复用配置加载、目录导航、页面渲染和多语言构建流程。包名为 `markit_kit`，源码目录为 `markit-kit`。

支持 Website、Markdown、Typst 和 PDF 输出，集成代码高亮、数学公式和 Mermaid 图表。命令行入口见 [Markit CLI](../markit-cli/README.md)，Markdown 解析内核见 [markit](../markit/README.md)。

## 从源码构建

需要仓颉 SDK 1.1.0 或更新版本，以及 Node.js 20+ 和 npm。在完整仓库中执行：

```bash
git clone https://gitcode.com/Cangjie-TPC/markit.git
cd markit/markit-kit
cjpm build
```

构建前钩子会安装 `ts-render` 的 npm 依赖、构建浏览器脚本，并将同仓库 `codehl/assets` 中的语法和主题资源同步到本库的 `assets` 目录。开发时需要保留仓库的兄弟目录布局；前端构建细节见 [ts-render](ts-render/README.md)。PDF 输出还需要将 Typst 命令行工具加入 `PATH`。

## 在仓颉程序中使用

在调用方的 `cjpm.toml` 中添加源码依赖，将路径替换为本机完整仓库中的目录：

```toml
[dependencies]
markit_kit = { path = "/path/to/markit/markit-kit", output-type = "static" }
```

先完成上面的资源构建，再调用 `BuildCoordinator`：

```cangjie
import markit_kit.builders.BuildCoordinator

main(): Int64 {
    return Int64(BuildCoordinator.build(
        ["docs/markit.json"],
        "docs",
        "dist",
        "/path/to/markit/markit-kit/assets",
        parallelJobs: 2
    ))
}
```

`build` 返回 `0` 表示成功，`1` 表示失败。`assetRoot` 指向构建后的完整 `assets` 目录；部署程序时需要一同分发这些资源，并传入部署后的路径。

示例读取 `docs/markit.json`，以配置所在目录作为输入根目录，输出到 `dist`。完整构建会清理输出目录，因此输入文档和输出产物应放在不同目录。`configPaths` 为空时，会在 `inputPath` 对应位置自动查找 `markit.json`。`parallelJobs` 为 `1` 时串行构建，大于 `1` 时并行构建，`0` 时自动选择 CPU 核心数。

## 配置与导航

创建 `docs/markit.json`：

```json
{
  "title": "项目文档",
  "format": "website",
  "summary": [
    { "home": true, "label": "首页" },
    { "file": "markit.md", "showDrafts": true, "label": "文档" }
  ],
  "i18n": {
    "default": "zh",
    "target": "zh",
    "summary": {
      "en": ["Home", "Documentation"]
    }
  }
}
```

创建目录文件 `docs/markit.md`，并准备它引用的 `docs/intro.md`：

```markdown
- [快速开始](intro.md)
```

`summary` 按数组顺序生成顶部导航，每个 `file` 对应独立的栏目目录。首页内容可通过第一个栏目 Summary 中的 `<!-- homepage -->` 区域定义；未提供首页内容时跳转到首个有效章节。

`i18n.summary.<语言>` 根据 `i18n.target` 选择，与整个 `summary` 数组按下标对应，首页也占一个位置。翻译数组必须等长，元素可用 `null` 回退到对应条目的 `label`。示例目标语言为中文，因此使用条目中的中文文案；切换为英文后使用 `en` 数组。

这是破坏性格式变更：旧的 `summary` 对象及 `i18n.home`、`i18n.documentation` 需要迁移到上述数组结构。完整字段、首页标记和迁移规则见 [配置参考](../docs/reference/markit-cli-config.md)。

## 主要接口

| 接口 | 用途 |
| --- | --- |
| `markit_kit.builders.BuildCoordinator.build` | 执行完整构建，可传入多个网站语言配置 |
| `markit_kit.builders.BuildCoordinator.incrementalBuild` | 在已有输出上处理指定文件的变化 |
| `markit_kit.config.ConfigLoader.loadConfig` | 加载指定配置，返回加载结果及可选配置路径 |
| `markit_kit.utils.KitHooks.install` | 安装调用方实现的日志和进度接收器 |
| `markit_kit.utils.KitHooks.reset` | 恢复默认的空接收器 |

多配置构建仅支持 Website；Markdown、Typst、PDF 每次接收一个配置。多语言网站的目录组织与命令行示例见 [CLI 使用指南](../docs/cli/markit-cli.md)。

库默认使用 `NoopKitHookSink`，不输出日志与进度。需要接收构建信息时，实现 `KitHookSink` 并在构建前安装；可参考 [接口定义](src/utils/kit_hooks.cj) 和 [CLI 接入实现](../markit-cli/src/kit_hooks.cj)。

## 相关资料

- [构建协调器源码](src/builders/build_coordinator.cj)
- [CLI 集成示例](../docs/examples/integration/cli-integration.md)
- [仓库许可证](../LICENSE)
