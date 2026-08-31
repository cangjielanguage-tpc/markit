package markit.tests.benchmark

public class BenchmarkDocuments {
    public static func smallStandard(): String {
        return """
# Small Document

Paragraph with **bold**, *italic*, `code`, and [link](https://example.com).

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
# GFM Mixed Document

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

    public static func i18nMixed(): String {
        return """
# :zh{标题}: :en{Title}:

- 默认语言项目

:::en
- English item
:::

  1. 默认子项

  :::en
  1. English child
  :::

    $$
    \\sigma = [T_1 \\mapsto T_{i1}, ..., T_p \\mapsto T_{ip}]
    $$

中文段落 :en{English inline}: :{shared}:。

:::en
English paragraph with **bold** and `code`.
:::
"""
    }

    public static func generatedStandard(lines: Int64): String {
        let sb = StringBuilder()
        for (i in 0..lines) {
            match (i % 8) {
                case 0 =>
                    sb.append("# Heading ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case 1 =>
                    sb.append("Paragraph ")
                    sb.append(i.toString())
                    sb.append(" with **bold**, *italic*, `code`, and 中文内容。\n\n")
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
                    sb.append("\n```\n\n")
                case 6 =>
                    sb.append("## Subheading ")
                    sb.append(i.toString())
                    sb.append("\n\n")
                case _ =>
                    sb.append("Plain text line ")
                    sb.append(i.toString())
                    sb.append(" with [link](https://example.com/")
                    sb.append(i.toString())
                    sb.append(").\n\n")
            }
        }
        return sb.toString()
    }
}
