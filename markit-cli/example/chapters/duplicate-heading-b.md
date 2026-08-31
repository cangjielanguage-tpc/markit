# :zh{重复标题 B}: :en{Duplicate Headings B}:

::{:zh{这一页继续复用同名标题，并反向链接到上一页，方便检查 cross-file anchor 是否也走同一套路径作用域规则。}: :en{This page reuses the same subsection title and links back to the previous page so cross-file anchors can be checked against the same path-scoping rule.}:}:

:::zh
## 说明

跳回 [上一页的 Details](duplicate-heading-a.md#details)，再看本页自己的 [Details](#details)。
:::

:::en
## Notes

Jump back to the [previous page Details](duplicate-heading-a.md#details), then inspect this page's own [Details](#details).
:::

:::zh
## Details

如果路径作用域生效，这一节在 `merged.typ` 中不应该再是裸的 `<details>`。
:::

:::en
## Details

If path scoping works, this section should no longer appear as a bare `<details>` label in `merged.typ`.
:::

:::zh
## Verification

- 观察本页到上一页的链接
- 观察本页自己的同名标题
- 两边都应该解析到不同的 scoped label
:::

:::en
## Verification

- Inspect the link from this page back to the previous page
- Inspect this page's duplicate heading
- Both should resolve to distinct scoped labels
:::
