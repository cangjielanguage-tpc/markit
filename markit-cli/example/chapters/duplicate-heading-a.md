# :zh{重复标题 A}: :en{Duplicate Headings A}:

::{:zh{本页和下一页故意使用相同的小节标题，用来观察 merged Typst 的路径作用域 label。}: :en{This page and the next one intentionally reuse the same subsection titles to validate path-scoped labels in merged Typst.}:}:

:::zh
## 说明

先看当前页的 [Details](#details)，再跳到 [下一页的 Details](duplicate-heading-b.md#details)。

如果 merged Typst 的标题 label 仍然只用纯 slug，这两页都会生成 `<details>`，最终会在合并文档里冲突。
:::

:::en
## Notes

Open the [current page Details](#details), then jump to the [next page Details](duplicate-heading-b.md#details).

If merged Typst still uses plain slugs for labels, both pages would emit `<details>` and collide in the merged document.
:::

:::zh
## Details

这一节和下一页的同名标题应该在 merged Typst 中拥有不同 label。
:::

:::en
## Details

This section should receive a different merged label from the identically named section on the next page.
:::

:::zh
## Verification

- 查看导出的单页 `duplicate-heading-a.typ`
- 查看合并导出的 `merged.typ`
- 检查这里的 `Details` 是否被改写成带页面路径前缀的 label
:::

:::en
## Verification

- Inspect the single-page `duplicate-heading-a.typ`
- Inspect the merged `merged.typ`
- Verify that this `Details` heading receives a page-scoped label
:::
