# :zh{Markit Typst 示例}: :en{Markit Typst Example}:

::{本页用于验证 Typst 导出的基础结构，包括标题、段落、链接、列表和双语内容。}:

:::zh
## 目标

这套示例文档专门用于观察 `.typ` 是否符合预期，而不是追求内容完整。

- 覆盖 i18n 块级和行内语法
- 覆盖相对链接
- 覆盖普通段落、引用、列表与表格
- 为后续代码高亮和 PDF 样式调优提供稳定输入
:::

:::en
## Goal

This small document set is meant to validate the generated `.typ` structure instead of serving as full documentation.

- Cover block and inline i18n syntax
- Cover relative links
- Cover paragraphs, quotes, lists, and tables
- Provide stable input for later code-highlighting and PDF-style tuning
:::

## :zh{快速导航}: :en{Quick Navigation}:

- :zh{查看}: :en{Open}: [代码高亮章节](chapters/code-highlighting.md)
- :zh{查看}: :en{Open}: [Mermaid 图表章节](chapters/mermaid-diagrams.md)
- :zh{查看}: :en{Open}: [版式检查章节](chapters/layout-checks.md)
- :zh{查看}: :en{Open}: [重复标题示例 A](chapters/duplicate-heading-a.md)
- :zh{查看}: :en{Open}: [重复标题示例 B](chapters/duplicate-heading-b.md)

> :zh{这是一段通用引用，会出现在所有语言版本中。}: :en{This is a universal quote that appears in every language build.}:

## :zh{状态表}: :en{Status Table}:

| :zh{项目}: :en{Item}: | :zh{说明}: :en{Description}: | :zh{状态}: :en{Status}: |
|---|---|---|
| Typst | :zh{基础导出}: :en{Base export}: | OK |
| I18n | :zh{中英文同源}: :en{Single-source bilingual content}: | OK |
| Code | :zh{等待高亮细化}: :en{Waiting for highlight refinement}: | TODO |
| Merge | :zh{重复标题作用域验证}: :en{Duplicate heading scope validation}: | OK |

## :zh{如何验证重复标题}: :en{How to Verify Duplicate Headings}:

:::zh
运行 example 后，重点看这两个文件：

- `dist/zh/chapters/duplicate-heading-a.typ`
- `dist/zh/merged.typ`

然后搜索 `Details`。

你应该能看到：

- 两个章节都保留了 `## Details`
- 但在 `merged.typ` 里，它们的 label 不再都是 `<details>`
- 当前页链接和跨页链接都会指向带路径前缀的 label
:::

:::en
After rendering the example, inspect these files:

- `dist/zh/chapters/duplicate-heading-a.typ`
- `dist/zh/merged.typ`

Then search for `Details`.

Expected result:

- Both chapters still render `## Details`
- In `merged.typ`, their labels are no longer both `<details>`
- Both local and cross-file links point to page-scoped labels
:::
