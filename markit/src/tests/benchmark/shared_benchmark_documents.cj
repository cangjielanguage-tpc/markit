package markit.tests.benchmark

public class SharedBenchmarkDocuments {
    public static func standardSmall(): String {
        return """
# Shared Standard Small

Paragraph with **bold**, *italic*, `code`, [link](https://example.com), and 中文内容。

- 中文项目
- Second item
- Third item

1. First
2. 第二项
3. Third

> Quote with **formatting**.

```cangjie
let value = 42
println("中文")
```
"""
    }

    public static func gfmMixed(): String {
        return """
# Shared GFM Mixed

| Feature | Status | Notes |
|:--------|:------:|------:|
| Tables | yes | 中文 |
| Math | yes | $a + b$ |

- [x] 完成 task
- [ ] Pending task
- [x] Another task with ~~strike~~

Autolinks: https://example.com and user@example.com

$$
\\sigma = [T_1 \\mapsto T_{i1}, ..., T_p \\mapsto T_{ip}]
$$

Inline math with 中文: $x_i + y_i$.
"""
    }

    public static func commonmarkMixed(): String {
        return """
Heading Level 1
===============

Text with <span>inline HTML</span> and <https://example.com> plus &amp;.

<div>
  <p>HTML content</p>
</div>

Setext level 2
--------------
"""
    }

    public static func i18nMixed(): String {
        return """
# :zh{标题}: :en{Title}:

:::zh
中文 **内容**
:::
:::en
English **content**
:::

Hello :zh{你好}: :en{world}: :{!}:

:::en
- English item
- Another item with `code`
:::
"""
    }

    public static func largeFence(lines: Int64): String {
        let sb = StringBuilder()
        sb.append("```cangjie\n")
        for (i in 0..lines) {
            sb.append("let value")
            sb.append(i.toString())
            sb.append(" = \"中文 ")
            sb.append(i.toString())
            sb.append("\"\n")
        }
        sb.append("```\n")
        return sb.toString()
    }

    public static func deepList(depth: Int64): String {
        let sb = StringBuilder()
        for (i in 0..depth) {
            for (_ in 0..i) {
                sb.append("  ")
            }
            sb.append("- item ")
            sb.append(i.toString())
            sb.append(" 中文\n")
        }
        return sb.toString()
    }

    public static func largeTable(rows: Int64): String {
        let sb = StringBuilder()
        sb.append("| Name | Status | Notes |\n")
        sb.append("|:---|:---:|---:|\n")
        for (i in 0..rows) {
            sb.append("| Item ")
            sb.append(i.toString())
            sb.append(" | ok | 中文 ")
            sb.append(i.toString())
            sb.append(" |\n")
        }
        return sb.toString()
    }

    public static func generatedStandard(blocks: Int64): String {
        let sb = StringBuilder()
        for (i in 0..blocks) {
            match (i % 8) {
                case 0 =>
                    sb.append("# Heading ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case 1 =>
                    sb.append("Paragraph ")
                    sb.append(i.toString())
                    sb.append(" with **bold**, *italic*, `code`, [link](https://example.com/")
                    sb.append(i.toString())
                    sb.append("), and 中文内容。\n\n")
                case 2 =>
                    sb.append("- Item ")
                    sb.append(i.toString())
                    sb.append("\n- 第二项 ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case 3 =>
                    sb.append("1. Ordered ")
                    sb.append(i.toString())
                    sb.append("\n2. 第二项 ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case 4 =>
                    sb.append("> Quote ")
                    sb.append(i.toString())
                    sb.append(" with **formatting**\n\n")
                case 5 =>
                    sb.append("```cangjie\nlet value")
                    sb.append(i.toString())
                    sb.append(" = ")
                    sb.append(i.toString())
                    sb.append("\nprintln(\"中文\")\n```\n\n")
                case 6 =>
                    sb.append("## Subheading ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case _ =>
                    sb.append("Plain text line ")
                    sb.append(i.toString())
                    sb.append(" with `inline ")
                    sb.append(i.toString())
                    sb.append("`.\n\n")
            }
        }
        return sb.toString()
    }

    public static func gfmGenerated(blocks: Int64): String {
        let sb = StringBuilder()
        for (i in 0..blocks) {
            match (i % 10) {
                case 0 =>
                    sb.append("# GFM Section ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case 1 =>
                    sb.append("| Name | Status | Notes |\n|:---|:---:|---:|\n| Item ")
                    sb.append(i.toString())
                    sb.append(" | yes | 中文 |\n\n")
                case 2 =>
                    sb.append("- [x] Done ")
                    sb.append(i.toString())
                    sb.append("\n- [ ] Todo ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case 3 =>
                    sb.append("Text with ~~strike ")
                    sb.append(i.toString())
                    sb.append("~~ and https://example.com/")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case 4 =>
                    sb.append("$$\nx_")
                    sb.append(i.toString())
                    sb.append(" + y_")
                    sb.append(i.toString())
                    sb.append("\n$$\n\n")
                case 5 =>
                    sb.append("Inline math $a_")
                    sb.append(i.toString())
                    sb.append(" + b_")
                    sb.append(i.toString())
                    sb.append("$ with 中文.\n\n")
                case 6 =>
                    sb.append("```cangjie\nlet gfm")
                    sb.append(i.toString())
                    sb.append(" = ")
                    sb.append(i.toString())
                    sb.append("\n```\n\n")
                case 7 =>
                    sb.append("> Quote ")
                    sb.append(i.toString())
                    sb.append(" with **bold**\n\n")
                case 8 =>
                    sb.append("[^note")
                    sb.append(i.toString())
                    sb.append("]\n\n[^note")
                    sb.append(i.toString())
                    sb.append("]: Footnote ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case _ =>
                    sb.append("Plain GFM text ")
                    sb.append(i.toString())
                    sb.append(" with user")
                    sb.append(i.toString())
                    sb.append("@example.com.\n\n")
            }
        }
        return sb.toString()
    }
}
