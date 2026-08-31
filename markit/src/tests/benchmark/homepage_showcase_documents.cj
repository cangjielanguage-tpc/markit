package markit.tests.benchmark

public class HomepageShowcaseDocuments {
    public static func docsSitePage(sections: Int64): String {
        let sb = StringBuilder()
        sb.append("# Markit AI 文档工作台\n\n")
        sb.append("Markit turns Markdown into HTML, Markdown, Typst and JSON while keeping source ranges, plugin state, and streaming updates available for tools.\n\n")
        sb.append("> This fixture looks like a real documentation page: headings, tables, task lists, code, math, footnotes, HTML, i18n blocks, and Chinese text are all present.\n\n")

        for (i in 0..sections) {
            match (i % 12) {
                case 0 =>
                    sb.append("## Section ")
                    sb.append(i.toString())
                    sb.append(" 中文标题\n\n")
                    sb.append("This section explains **fast parsing**, *structured output*, `feedBytes`, [docs navigation](https://example.com/docs/")
                    sb.append(i.toString())
                    sb.append("), and 中文内容 mixed with emoji 🚀.\n\n")
                case 1 =>
                    sb.append("| Capability | Input | Output |\n")
                    sb.append("|:---|:---:|---:|\n")
                    sb.append("| HTML render ")
                    sb.append(i.toString())
                    sb.append(" | Markdown | fragment |\n")
                    sb.append("| JSON tree ")
                    sb.append(i.toString())
                    sb.append(" | AST | SeaJson |\n")
                    sb.append("| Typst export ")
                    sb.append(i.toString())
                    sb.append(" | docs | PDF-ready |\n\n")
                case 2 =>
                    sb.append("- [x] Parse chunk ")
                    sb.append(i.toString())
                    sb.append(" without breaking UTF-8\n")
                    sb.append("- [ ] Keep the pending tail while the block is still open\n")
                    sb.append("- [x] Emit patches after the block becomes stable\n\n")
                case 3 =>
                    sb.append("```cangjie\n")
                    sb.append("let session = markit.createSession()\n")
                    sb.append("session.feedBytes(bytes[0..64])\n")
                    sb.append("session.feed(\"中文段落 ")
                    sb.append(i.toString())
                    sb.append("\\n\\n\")\n")
                    sb.append("```\n\n")
                case 4 =>
                    sb.append("$$\n")
                    sb.append("throughput_")
                    sb.append(i.toString())
                    sb.append(" = parse + render + stream\n")
                    sb.append("$$\n\n")
                    sb.append("Inline math $x_")
                    sb.append(i.toString())
                    sb.append(" + y_")
                    sb.append(i.toString())
                    sb.append("$ stays inside the same parse tree.\n\n")
                case 5 =>
                    sb.append(":zh{中文 API 描述 ")
                    sb.append(i.toString())
                    sb.append("}: :en{English API description ")
                    sb.append(i.toString())
                    sb.append("}: :{neutral text}:\n\n")
                    sb.append(":::zh\n")
                    sb.append("中文块内容可以包含 **加粗**、`代码` 和列表。\n")
                    sb.append(":::\n")
                    sb.append(":::en\n")
                    sb.append("English block content can include **bold**, `code`, and lists.\n")
                    sb.append(":::\n\n")
                case 6 =>
                    sb.append("> AI 输出不会总是按行切 chunk。\n")
                    sb.append("> Markit keeps the decoder, open blocks, and source offsets in the session.\n\n")
                case 7 =>
                    sb.append("1. Build the AST for page ")
                    sb.append(i.toString())
                    sb.append("\n")
                    sb.append("2. Render HTML, Markdown, Typst, and JSON\n")
                    sb.append("3. Send stable fragments to the preview\n\n")
                    sb.append("   - nested item with 中文\n")
                    sb.append("   - nested item with `inline code`\n\n")
                case 8 =>
                    sb.append("Footnote reference [^showcase")
                    sb.append(i.toString())
                    sb.append("] keeps symbol tables useful for renderers.\n\n")
                    sb.append("[^showcase")
                    sb.append(i.toString())
                    sb.append("]: Footnote body ")
                    sb.append(i.toString())
                    sb.append(" with 中文 and a https://example.com link.\n\n")
                case 9 =>
                    sb.append("<section data-kind=\"callout\">\n")
                    sb.append("  <p>Inline HTML and block HTML can pass through the renderer.</p>\n")
                    sb.append("</section>\n\n")
                case 10 =>
                    sb.append("---\n\n")
                    sb.append("A short paragraph after a divider checks block dispatch and continuation behavior.\n\n")
                case _ =>
                    sb.append("Appendix ")
                    sb.append(i.toString())
                    sb.append("\n")
                    sb.append("----------\n\n")
                    sb.append("Setext headings and normal paragraphs keep the fixture close to everyday docs.\n\n")
            }
        }

        return sb.toString()
    }
}
