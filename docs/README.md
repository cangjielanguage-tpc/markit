# Markit 文档

这里是 Markit 项目的用户文档入口。Markit 是一组围绕 Markdown 文档处理构建的仓颉项目，包含解析内核、命令行工具、构建期代码高亮、数学公式、Mermaid 图表、文件监听和 CLI 框架等能力。

本目录可直接由 `markit-cli` 渲染为文档网站：

```bash
markit render -i ./docs -o ./dist
markit serve -i ./docs
```

主要入口：

- [项目组成](libraries/project-map.md)
- [markit-cli](cli/markit-cli.md)
- [markit 内核](libraries/markit-core.md)
- [快速开始](getting-started/quick-start.md)
- [代码高亮](features/code-highlighting.md)
- [数学公式](features/math.md)
- [Mermaid 图表](features/mermaid.md)
