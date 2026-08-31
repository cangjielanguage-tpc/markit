<a id="markit-cli-config"></a>
# markit-cli 配置参考

配置文件使用 JSON，默认文件名为 `markit.json`。`markit render` 和 `markit serve` 会在输入目录自动查找，也可以通过 `--config` 指定。

## 基础配置

| 字段 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `title` | String | `Documentation` | 网站或输出文档标题 |
| `theme` | String | `arctic` | 网站主题 |
| `format` | String | `website` | `website`、`pdf`、`markdown`、`typst` |
| `toc` | Bool | `false` | 是否生成目录 |

```json
{
  "title": "My Documentation",
  "theme": "arctic",
  "format": "website",
  "toc": true
}
```

## Summary

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `summary.file` | `markit.md` | Summary 文件名 |
| `summary.showDrafts` | `true` | 是否在侧边栏显示空链接草稿章节 |

Summary 文件声明侧边栏结构。一级标题是分组，无序列表链接是章节；`<!-- homepage -->` 后的内容是首页。

```json
{
  "summary": {
    "file": "markit.md",
    "showDrafts": false
  }
}
```

## i18n

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `i18n.default` | `en` | 默认语言 |
| `i18n.target` | `en` | 当前构建目标语言 |
| `i18n.home` | `Home` | 首页文案 |
| `i18n.documentation` | `Documentation` | 文档页文案 |

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

## 标题

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

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `heading.closable` | `true` | 标题以闭合标记书写时移除该章节内容 |
| `heading.number.enabled` | `false` | 是否启用标题编号 |
| `heading.number.resetFor` | `always` | `never`、`directory`、`always` |
| `heading.number.startFrom` | `[1,1,1,1,1,1]` | 各级标题起始编号 |

## 代码块

```json
{
  "codeBlock": {
    "enabled": true,
    "group": true,
    "autoAnchor": true,
    "lightTheme": "light-plus",
    "darkTheme": "dark-plus",
    "grammarDirs": [],
    "themeDirs": [],
    "aliases": {
      "fish": "bash"
    }
  }
}
```

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `codeBlock.enabled` | `true` | 是否启用代码高亮 |
| `codeBlock.group` | `false` | 是否启用多标签代码块 |
| `codeBlock.autoAnchor` | `false` | 是否为代码块生成可复制引用的锚点 |
| `codeBlock.theme` | `""` | 单主题名称 |
| `codeBlock.lightTheme` | `light-plus` | 浅色主题 |
| `codeBlock.darkTheme` | `dark-plus` | 暗色主题 |
| `codeBlock.grammarDirs` | `[]` | 额外 grammar 目录 |
| `codeBlock.themeDirs` | `[]` | 额外主题目录 |
| `codeBlock.languages` | `{}` | 语言到 grammar 的映射 |
| `codeBlock.aliases` | `{}` | 语言别名 |

## 表格

```json
{
  "table": {
    "threeLine": true,
    "autoAnchor": true
  }
}
```

`table.threeLine` 启用后三线表语法：表格前后都紧邻 Markdown 分割线 `---` 时，该表格按三线表渲染。
`table.autoAnchor` 会把表格引用锚点挂到第一行第一格。

## 自动锚点

```json
{
  "list": {
    "autoAnchor": true
  },
  "codeBlock": {
    "autoAnchor": true
  },
  "math": {
    "autoAnchor": true
  },
  "table": {
    "autoAnchor": true
  }
}
```

启用后，markit 会为列表项、代码块、块级数学公式和表格生成稳定锚点。网站输出会在这些锚点旁显示复制引用按钮；Markdown 输出会写出 `{#...}` 标签；Typst 输出会写出对应 label。

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `list.autoAnchor` | `false` | 为有序、无序和任务列表项生成锚点 |
| `codeBlock.autoAnchor` | `false` | 为 fenced code block 生成锚点 |
| `math.autoAnchor` | `false` | 为块级数学公式生成锚点 |
| `table.autoAnchor` | `false` | 为表格生成锚点，锚点位于第一行第一格 |

## Website

```json
{
  "website": {
    "chapter": {
      "navigation": true,
      "prevText": "上一章节",
      "nextText": "下一章节"
    },
    "statistic": {
      "totalTexts": true,
      "totalTextsTemplate": "本文共 {total} 字",
      "spentTime": true,
      "spentTimeTemplate": "预计耗时 {total}{unit}",
      "second": "秒",
      "minute": "分钟"
    },
    "repos": {
      "gitcode": "https://gitcode.com/zichexuelan/markit"
    }
  }
}
```

常用字段：

| 字段 | 说明 |
| --- | --- |
| `website.chapter.navigation` | 启用上一篇/下一篇导航 |
| `website.statistic` | 显示字数与预计阅读时间 |
| `website.git.prefix` | 当前页源码链接前缀 |
| `website.repos.github/gitcode/gitee/gitlab` | 导航栏仓库入口 |
| `website.assets.styles` | 注入自定义 CSS |
| `website.assets.scripts` | 注入自定义 JS |
| `website.code.ligatures` | 是否启用代码字体连字 |

## PDF / Typst

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
        "title": "My Docs",
        "subtitle": "Reference Manual",
        "authors": ["Docs Team"]
      }
    }
  }
}
```

PDF 输出会先生成 Typst 文件，再调用 Typst 生成 `merged.pdf`。如果 Summary 中定义了 homepage，PDF 顺序为封面模板、homepage、目录、正文。

## 完整示例

```json
{
  "title": "Markit",
  "theme": "arctic",
  "format": "website",
  "toc": true,
  "i18n": {
    "default": "zh",
    "target": "zh",
    "home": "首页",
    "documentation": "文档"
  },
  "summary": {
    "file": "markit.md",
    "showDrafts": false
  },
  "codeBlock": {
    "enabled": true,
    "group": true,
    "lightTheme": "light-plus",
    "darkTheme": "dark-plus"
  },
  "table": {
    "threeLine": true
  },
  "heading": {
    "closable": true,
    "number": {
      "enabled": true,
      "resetFor": "directory",
      "startFrom": [1, 1, 1, 1, 1, 1]
    }
  },
  "website": {
    "chapter": {
      "navigation": true,
      "prevText": "上一章节",
      "nextText": "下一章节"
    }
  }
}
```
