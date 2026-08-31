package markit.tests.unit.streaming

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.{Markit, ParseOutput}
import markit.bundles.GFMBundle
import markit.core.incremental.IncrementalSession
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

@Test
@Tag[Streaming]
class ChunkBoundaryPropertyTests {
    @TestCase
    func standardMarkdownMatchesDirectAcrossRuneAndByteChunkBoundaries() {
        let markdown = """
# 中文标题

段落 with **bold** and *italic* and [ref][later].

[later]: https://example.com "标题"

```cj {1} [2]
let 中文 = "值"
```

- item one
  - 子项

Line 1   
Line 2\\  
Line 3
"""
        assertAllStreamingModesMatchDirect({ => Markit() }, markdown)
    }

    @TestCase
    func gfmMatchesDirectAcrossRuneAndByteChunkBoundaries() {
        let markdown = """
# Title 中文

[ref]: /target "标题"

Paragraph [link][ref] and ![logo][ref] with ~~strike~~ and $x + 中文$.

| 名称 | 值 |
| --- | ---: |
| 甲 | `代码` |

- [x] 完成
- [ ] 待办

$$
E = mc^2
中文
$$

Footnote here[^一].

[^一]: 脚注 **bold**
"""
        assertAllStreamingModesMatchDirect({ => Markit(GFMBundle()) }, markdown)
    }

    @TestCase
    func i18nGfmMatchesDirectAcrossRuneAndByteChunkBoundaries() {
        let markdown = """
# :zh{中文标题}: :en{English Title}:

:::zh
- 默认中文
:::
:::en
- English
:::
  - Child 中文

:{通用 inline}: :en{Target inline}:

:::en
$$
x = 中文 + y
$$
:::
"""
        assertAllStreamingModesMatchDirect(
            {
                => Markit(GFMBundle()).use(I18nPlugin(
                    config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
                ))
            },
            markdown
        )
    }

    @TestCase
    func crlfUnicodeDocumentMatchesDirectAcrossByteChunkBoundaries() {
        let markdown = "# 标题\r\n\r\n段落一  \r\n段落二\r\n\r\n> 引用中文\r\n\r\n---\r\n"
        let direct = Markit().parse(markdown)
        for (size in [1, 2, 4, 7]) {
            let session = Markit().createSession()
            for (chunk in byteChunks(markdown, size)) {
                session.feedBytes(chunk)
            }
            session.finalize()
            assertSessionMatchesDirect("byte-crlf-${size}", session, direct)
        }
    }
}

private func assertAllStreamingModesMatchDirect(markitFactory: () -> Markit, markdown: String): Unit {
    let direct = markitFactory().parse(markdown)

    for (size in [1, 2, 3, 5]) {
        let session = markitFactory().createSession()
        for (chunk in runeChunks(markdown, size)) {
            session.feed(chunk)
        }
        session.finalize()
        assertSessionMatchesDirect("rune-${size}", session, direct)
    }

    for (size in [1, 2, 3, 5, 8, 13]) {
        let session = markitFactory().createSession()
        for (chunk in byteChunks(markdown, size)) {
            session.feedBytes(chunk)
        }
        session.finalize()
        assertSessionMatchesDirect("byte-${size}", session, direct)
    }
}

private func assertSessionMatchesDirect(mode: String, session: IncrementalSession, direct: ParseOutput): Unit {
    if (session.toHtml() != direct.toHtml()) {
        throw IllegalArgumentException("HTML mismatch in ${mode}")
    }
    if (session.toMarkdown() != direct.toMarkdown()) {
        throw IllegalArgumentException("Markdown mismatch in ${mode}")
    }
    if (session.toTypst() != direct.toTypst()) {
        throw IllegalArgumentException("Typst mismatch in ${mode}")
    }
    if (session.toJson() != direct.toJson()) {
        throw IllegalArgumentException("JSON mismatch in ${mode}")
    }
}

private func runeChunks(markdown: String, chunkRuneSize: Int64): Array<String> {
    let chunks = ArrayList<String>()
    let builder = StringBuilder()
    var count: Int64 = 0

    for (rune in markdown.runes()) {
        builder.append(rune)
        count += 1
        if (count >= chunkRuneSize) {
            chunks.add(builder.toString())
            builder.reset()
            count = 0
        }
    }

    if (builder.size > 0) {
        chunks.add(builder.toString())
    }
    return chunks.toArray()
}

private func byteChunks(markdown: String, chunkByteSize: Int64): Array<Array<Byte>> {
    let bytes = markdown.toArray()
    let chunks = ArrayList<Array<Byte>>()
    var cursor: Int64 = 0

    while (cursor < bytes.size) {
        let end = if (cursor + chunkByteSize > bytes.size) {
            bytes.size
        } else {
            cursor + chunkByteSize
        }
        chunks.add(bytes[cursor..end])
        cursor = end
    }

    return chunks.toArray()
}
