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

## Summary 与导航翻译

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `summary` | 首页和 `markit.md` 栏目 | 按导航顺序排列的首页/栏目数组 |
| `summary[].home` | — | 首页项的开关，与 `file` 互斥 |
| `summary[].file` | — | 当前语言输入根目录下的 Summary 路径 |
| `summary[].showDrafts` | `true` | 是否显示该栏目的草稿条目 |
| `summary[].label` | `Home` 或文件名 | 没有翻译时使用的栏目文案 |
| `i18n.default` | `en` | 未标记内容的默认语言 |
| `i18n.target` | `en` | 当前构建目标语言，也用于选择导航翻译 |
| `i18n.route_prefix` | 空 | 当前语言的输入子目录 |
| `i18n.summary.<语言>` | 未设置 | 与 `summary` 等长的文案数组，允许 `null` 回退 |

`summary` 是按顶部导航顺序排列的数组。首页项使用 `home: true`，栏目项使用 `file` 指定独立的 Markdown Summary；每个栏目拥有自己的侧栏和上一篇/下一篇。`file` 相对于当前语言的输入根目录解析，`showDrafts` 默认为 `true`，仅控制侧栏空链接草稿条目是否显示。

`i18n.summary.<语言>` 是与整个 `summary` 数组按下标对应的文案数组，根据 `i18n.target` 选择。没有对应语言时使用条目的 `label`；数组中的 `null` 回退到该项 `label`。已配置的数组长度必须与 `summary` 完全一致，隐藏的首页项仍占位置；调整栏目顺序时须同步调整翻译数组。未填写 `label` 时，首页使用 `Home`，栏目使用文件名。

最多允许一个首页项，首页项不能同时指定 `file`。省略首页项或设置 `home: false` 时不显示首页链接，语言入口跳转到第一个有效栏目。启用首页时，内容取第一个栏目 Summary 的 `<!-- homepage -->` 部分；没有该内容则跳转到第一个有效章节。没有自定义首页也会显示配置的栏目导航。

栏目入口是其第一个实际参与构建的非草稿章节。页面按规范化后的完整路径匹配栏目；同一页面被多个栏目引用时只构建一次，归属配置中最先引用它的栏目并给出警告。所有配置的 Summary 文件均不作为正文渲染；目录文件缺失或不可解析时报告构建错误，不回退扫描整个输入目录。草稿父项下面的子树不参与构建。

任一 Summary 或配置文件发生变化时，`serve --watch` 重新构建全站导航。PDF、Markdown、Typst 按栏目顺序合并并去重页面，首页前置内容最多插入一次。未配置 `summary` 时默认使用首页项和 `markit.md` 栏目；默认 `markit.md` 不存在时仍可按文件系统收集文档。

这是破坏性变更：不再接受旧 `summary` 对象、顶层 `nav`、`summary.label.home/documentation` 或 `i18n.home/documentation`。请迁移为 `summary[]` 和 `i18n.summary.<语言>`。

```json
{
  "summary": [
    { "home": true, "label": "首页" },
    { "file": "markit.md", "showDrafts": true, "label": "文档" },
    { "file": "demo.md", "showDrafts": true, "label": "示例" },
    { "file": "api-reference.md", "showDrafts": false, "label": "API 参考" }
  ],
  "i18n": {
    "default": "zh",
    "target": "en",
    "summary": {
      "en": ["Home", "Documentation", "Examples", "API Reference"],
      "jp": ["ホーム", "ドキュメント", "サンプル", "API リファレンス"]
    }
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
      "startFrom": [
        1,
        1,
        1,
        1,
        1,
        1
      ]
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
      "gitcode": "https://gitcode.com/Cangjie-TPC/markit"
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
        "authors": [
          "Docs Team"
        ]
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
    "target": "zh"
  },
  "summary": [
    {
      "home": true,
      "label": "首页"
    },
    {
      "file": "markit.md",
      "showDrafts": false,
      "label": "文档"
    }
  ],
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
      "startFrom": [
        1,
        1,
        1,
        1,
        1,
        1
      ]
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
